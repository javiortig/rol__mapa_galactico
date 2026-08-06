create unique index if not exists conflicts_single_pending_system_idx
on public.conflicts (system_id)
where status = 'pending';

create unique index if not exists narrative_attacks_single_incoming_system_idx
on public.narrative_attacks (system_id)
where status = 'incoming';

create unique index if not exists movement_orders_single_active_attack_target_idx
on public.movement_orders (to_system_id)
where movement_type = 'attack'
  and status in ('pending_approval', 'moving');

create or replace function public.find_retreat_or_capital_system(
  target_faction_id uuid,
  origin_system_id uuid
)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    public.find_nearest_allied_safe_system(target_faction_id, origin_system_id),
    (
      select systems.id
      from public.systems
      where systems.controller_faction_id = target_faction_id
        and systems.status = 'controlled'
        and systems.is_capital
      order by systems.name
      limit 1
    ),
    (
      select systems.id
      from public.systems
      where systems.controller_faction_id = target_faction_id
        and systems.status = 'controlled'
      order by systems.is_capital desc, systems.name
      limit 1
    )
  );
$$;

create or replace function public.find_retreat_system(
  target_faction_id uuid,
  origin_system_id uuid
)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select public.find_retreat_or_capital_system(target_faction_id, origin_system_id);
$$;

create or replace function public.find_shortest_unblocked_path(
  origin_system_id uuid,
  destination_system_id uuid
)
returns uuid[]
language sql
security definer
stable
set search_path = public
as $$
  with recursive graph(system_id, depth, path) as (
    select origin_system_id, 0, array[origin_system_id]

    union all

    select
      case
        when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
        else system_edges.from_system_id
      end,
      graph.depth + 1,
      graph.path ||
        case
          when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
          else system_edges.from_system_id
        end
    from graph
    join public.system_edges
      on not system_edges.is_blocked
      and (system_edges.from_system_id = graph.system_id or system_edges.to_system_id = graph.system_id)
    where graph.depth < 30
      and not (
        case
          when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
          else system_edges.from_system_id
        end = any(graph.path)
      )
  )
  select graph.path
  from graph
  where graph.system_id = destination_system_id
  order by graph.depth
  limit 1;
$$;

create or replace function public.queue_battle_support_return(target_commitment_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_commitment public.battle_unit_commitments%rowtype;
  v_operation public.battle_operations%rowtype;
  v_unit public.campaign_units%rowtype;
  v_destination_id uuid;
  v_path uuid[];
  v_path_length integer;
  v_index integer;
  v_duration_seconds integer;
  v_order_id uuid;
begin
  select *
  into v_commitment
  from public.battle_unit_commitments
  where id = target_commitment_id
  for update;

  if not found or v_commitment.role <> 'supporter' then
    return null;
  end if;

  select *
  into v_operation
  from public.battle_operations
  where id = v_commitment.operation_id;

  select *
  into v_unit
  from public.campaign_units
  where id = v_commitment.unit_id
  for update;

  if not found or v_unit.quantity <= 0 then
    update public.battle_unit_commitments
    set status = 'destroyed', updated_at = now()
    where id = v_commitment.id;
    return null;
  end if;

  select systems.id
  into v_destination_id
  from public.systems
  where systems.id = v_commitment.home_system_id
    and systems.status = 'controlled'
    and systems.controller_faction_id = v_commitment.faction_id
    and coalesce(systems.is_temporary_mission, false) = false
    and not public.system_has_unresolved_battle_block(systems.id)
  limit 1;

  v_destination_id := coalesce(
    v_destination_id,
    public.find_retreat_or_capital_system(v_commitment.faction_id, v_operation.target_system_id)
  );

  if v_destination_id is null then
    update public.campaign_units
    set status = 'retreat_pending', updated_at = now()
    where id = v_unit.id;

    update public.battle_unit_commitments
    set status = 'return_pending', updated_at = now()
    where id = v_commitment.id;

    return null;
  end if;

  if v_destination_id = v_commitment.home_system_id then
    if v_commitment.side = 'attacker' then
      v_path := array[v_operation.target_system_id] || public.reverse_uuid_array(v_commitment.outbound_path_system_ids);
    else
      v_path := public.reverse_uuid_array(v_commitment.outbound_path_system_ids);
    end if;
  end if;

  v_path_length := cardinality(v_path);

  if v_path_length < 2
    or v_path[1] is distinct from v_operation.target_system_id
    or v_path[v_path_length] is distinct from v_destination_id then
    v_path := public.find_shortest_unblocked_path(v_operation.target_system_id, v_destination_id);
    v_path_length := cardinality(v_path);
  end if;

  if v_path_length < 2
    or v_path[1] is distinct from v_operation.target_system_id
    or v_path[v_path_length] is distinct from v_destination_id then
    update public.campaign_units
    set status = 'retreat_pending', updated_at = now()
    where id = v_unit.id;

    update public.battle_unit_commitments
    set status = 'return_pending', updated_at = now()
    where id = v_commitment.id;

    return null;
  end if;

  for v_index in 1..(v_path_length - 1) loop
    if not exists (
      select 1
      from public.system_edges
      where not is_blocked
        and (
          (from_system_id = v_path[v_index] and to_system_id = v_path[v_index + 1])
          or (from_system_id = v_path[v_index + 1] and to_system_id = v_path[v_index])
        )
    ) then
      update public.campaign_units
      set status = 'retreat_pending', updated_at = now()
      where id = v_unit.id;

      update public.battle_unit_commitments
      set status = 'return_pending', updated_at = now()
      where id = v_commitment.id;

      return null;
    end if;
  end loop;

  select movement_edge_duration_seconds * (v_path_length - 1)
  into v_duration_seconds
  from public.campaign_settings
  where id = 'default';

  v_duration_seconds := coalesce(v_duration_seconds, 259200 * (v_path_length - 1));

  insert into public.movement_orders (
    faction_id,
    from_system_id,
    to_system_id,
    movement_type,
    movement_purpose,
    battle_operation_id,
    uridium_cost,
    started_at,
    departure_at,
    arrival_at,
    status,
    path_system_ids,
    segment_count,
    duration_seconds
  )
  values (
    v_commitment.faction_id,
    v_operation.target_system_id,
    v_destination_id,
    'move',
    'battle_return',
    v_operation.id,
    0,
    now(),
    now(),
    now() + make_interval(secs => v_duration_seconds),
    'moving',
    v_path,
    v_path_length - 1,
    v_duration_seconds
  )
  returning id into v_order_id;

  insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
  values (v_order_id, v_unit.id, v_unit.quantity);

  update public.campaign_units
  set status = 'moving', updated_at = now()
  where id = v_unit.id;

  update public.battle_unit_commitments
  set
    return_movement_order_id = v_order_id,
    return_path_system_ids = v_path,
    status = 'returning',
    updated_at = now()
  where id = v_commitment.id;

  return v_order_id;
end;
$$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.resolve_movement_orders()'::regprocedure)
  into v_definition;

  v_patched := regexp_replace(
    v_definition,
    'or\s+v_order\.arrival_at\s+>\s+v_operation\.attack_arrival_at',
    'or v_order.arrival_at >= v_operation.attack_arrival_at',
    'g'
  );

  v_patched := regexp_replace(
    v_patched,
    '(if not found then\s+perform public\.cancel_reserved_movement_order\(v_order\.id, ''Sistema de destino no encontrado'', v_order\.uridium_cost\);\s+v_resolved := v_resolved \+ 1;\s+continue;\s+end if;\s+)(if v_order\.movement_purpose in \(''coalition_staging'', ''defense_support''\) then)',
    '\1
    if exists (
      select 1
      from unnest(v_order.path_system_ids) with ordinality as route(system_id, position)
      where route.position > 1
        and route.position < cardinality(v_order.path_system_ids)
        and public.system_has_unresolved_battle_block(route.system_id)
    ) then
      perform public.cancel_reserved_movement_order(
        v_order.id,
        ''La ruta quedo bloqueada antes de la llegada'',
        v_order.uridium_cost
      );

      update public.battle_unit_commitments
      set status = ''cancelled'', updated_at = now()
      where outbound_movement_order_id = v_order.id
        and status = ''en_route'';

      v_resolved := v_resolved + 1;
      continue;
    end if;

    \2',
    'm'
  );

  if v_patched = v_definition
    or position('v_order.arrival_at >= v_operation.attack_arrival_at' in v_patched) = 0
    or position('La ruta quedo bloqueada antes de la llegada' in v_patched) = 0 then
    raise exception 'No se pudo parchear resolve_movement_orders';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.start_approved_movement_order(uuid)'::regprocedure)
  into v_definition;

  v_patched := regexp_replace(
    v_definition,
    '(if not found or \(\s+v_index = v_path_length\s+and \(v_system\.status = ''war'' or v_system\.blocked_until is not null and v_system\.blocked_until > now\(\)\)\s+\) then\s+perform public\.cancel_reserved_movement_order\(v_order\.id, ''La ruta ya no es valida'', v_order\.uridium_cost\);\s+return v_order\.id;\s+end if;)',
    '\1

    if v_index > 1
      and v_index < v_path_length
      and public.system_has_unresolved_battle_block(v_system.id) then
      perform public.cancel_reserved_movement_order(v_order.id, ''La ruta quedo bloqueada antes de la salida'', v_order.uridium_cost);
      return v_order.id;
    end if;',
    'm'
  );

  if v_patched = v_definition
    or position('La ruta quedo bloqueada antes de la salida' in v_patched) = 0 then
    raise exception 'No se pudo parchear start_approved_movement_order';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.cancel_reserved_movement_order(uuid, text, integer)'::regprocedure)
  into v_definition;

  v_patched := regexp_replace(
    v_definition,
    'v_redirect_late_arrival := reason in \(\s*''La ventana de apoyo ya esta cerrada'',\s*''El ataque llego antes que el apoyo'',\s*''El destino cambio a territorio bloqueado antes de la llegada''\s*\);',
    'v_redirect_late_arrival := reason in (
    ''La ventana de apoyo ya esta cerrada'',
    ''El ataque llego antes que el apoyo'',
    ''El destino cambio a territorio bloqueado antes de la llegada'',
    ''La ruta quedo bloqueada antes de la llegada'',
    ''La ruta quedo bloqueada antes de la salida''
  );',
    'm'
  );

  v_patched := replace(
    v_patched,
    'v_redirect_system_id := public.find_nearest_allied_safe_system(v_order.faction_id, v_order.to_system_id);',
    'v_redirect_system_id := public.find_retreat_or_capital_system(v_order.faction_id, v_order.to_system_id);'
  );

  if v_patched = v_definition
    or position('find_retreat_or_capital_system' in v_patched) = 0
    or position('La ruta quedo bloqueada antes de la llegada' in v_patched) = 0 then
    raise exception 'No se pudo parchear cancel_reserved_movement_order';
  end if;

  execute v_patched;
end $$;

create or replace function public.capture_arrived_defense_support_units()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_late_unit record;
  v_retreat_system_id uuid;
begin
  if new.battle_operation_id is null or new.status <> 'pending' then
    return new;
  end if;

  insert into public.battle_unit_commitments (
    operation_id,
    unit_id,
    faction_id,
    side,
    role,
    home_system_id,
    staging_system_id,
    outbound_path_system_ids,
    quantity_at_commitment,
    points_at_commitment,
    status
  )
  select
    new.battle_operation_id,
    units.id,
    units.faction_id,
    'defender',
    'supporter',
    home.home_system_id,
    new.system_id,
    support_path.outbound_path_system_ids,
    units.quantity,
    greatest(
      1,
      ceil((units.points::numeric * units.quantity) / greatest(units.starting_quantity, 1))::integer
    ),
    'in_battle'
  from public.campaign_units units
  join public.battle_operations operation
    on operation.id = new.battle_operation_id
  join public.battle_operation_members member
    on member.operation_id = new.battle_operation_id
    and member.faction_id = units.faction_id
    and member.side = 'defender'
    and member.role = 'supporter'
    and member.invitation_status = 'accepted'
  left join lateral (
    select
      movement_orders.path_system_ids,
      movement_orders.arrival_at
    from public.movement_order_units
    join public.movement_orders
      on movement_orders.id = movement_order_units.movement_order_id
    where movement_order_units.unit_id = units.id
      and movement_orders.faction_id = units.faction_id
      and movement_orders.to_system_id = new.system_id
      and movement_orders.status = 'arrived'
      and movement_orders.movement_type = 'move'
    order by coalesce(movement_orders.resolved_at, movement_orders.arrival_at, movement_orders.created_at) desc
    limit 1
  ) last_arrival on true
  cross join lateral (
    select coalesce(
      case
        when last_arrival.path_system_ids is not null and cardinality(last_arrival.path_system_ids) >= 2
        then last_arrival.path_system_ids[1]
        else null
      end,
      public.find_nearest_allied_safe_system(units.faction_id, new.system_id),
      new.system_id
    ) as home_system_id
  ) home
  cross join lateral (
    select case
      when last_arrival.path_system_ids is not null and cardinality(last_arrival.path_system_ids) >= 2
      then last_arrival.path_system_ids
      else array[home.home_system_id, new.system_id]
    end as outbound_path_system_ids
  ) support_path
  where units.current_system_id = new.system_id
    and units.status = 'ready'
    and units.quantity > 0
    and (
      last_arrival.arrival_at is null
      or (
        operation.attack_arrival_at is not null
        and last_arrival.arrival_at < operation.attack_arrival_at
      )
    )
  on conflict (operation_id, unit_id) do nothing;

  for v_late_unit in
    select units.id, units.faction_id
    from public.campaign_units units
    join public.battle_operations operation
      on operation.id = new.battle_operation_id
    join public.battle_operation_members member
      on member.operation_id = new.battle_operation_id
      and member.faction_id = units.faction_id
      and member.side = 'defender'
      and member.role = 'supporter'
      and member.invitation_status = 'accepted'
    join lateral (
      select movement_orders.arrival_at
      from public.movement_order_units
      join public.movement_orders
        on movement_orders.id = movement_order_units.movement_order_id
      where movement_order_units.unit_id = units.id
        and movement_orders.faction_id = units.faction_id
        and movement_orders.to_system_id = new.system_id
        and movement_orders.status = 'arrived'
        and movement_orders.movement_type = 'move'
      order by coalesce(movement_orders.resolved_at, movement_orders.arrival_at, movement_orders.created_at) desc
      limit 1
    ) last_arrival on true
    where units.current_system_id = new.system_id
      and units.status = 'ready'
      and units.quantity > 0
      and operation.attack_arrival_at is not null
      and last_arrival.arrival_at >= operation.attack_arrival_at
      and not exists (
        select 1
        from public.battle_unit_commitments commitment
        where commitment.operation_id = new.battle_operation_id
          and commitment.unit_id = units.id
          and commitment.status = 'in_battle'
      )
    for update of units
  loop
    v_retreat_system_id := public.find_retreat_or_capital_system(v_late_unit.faction_id, new.system_id);

    if v_retreat_system_id is null then
      update public.campaign_units
      set status = 'retreat_pending', updated_at = now()
      where id = v_late_unit.id;
    else
      update public.campaign_units
      set
        current_system_id = v_retreat_system_id,
        status = 'ready',
        updated_at = now()
      where id = v_late_unit.id;
    end if;
  end loop;

  return new;
end;
$$;

create or replace function public.submit_battle_report(conflict_id uuid, report_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.conflicts%rowtype;
  v_existing public.battle_reports%rowtype;
  v_reporter_faction_id uuid;
  v_is_admin boolean := false;
  v_is_conquerable_system boolean := true;
  v_report_id uuid;
  v_winner_faction_id uuid;
  v_final_controller_faction_id uuid;
  v_post_battle_blocked_until timestamptz;
  v_casualties jsonb;
  v_survivors jsonb;
  v_wounds_remaining jsonb;
  v_battle_mode text;
  v_revision integer;
  v_expected_revision integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_conflict
  from public.conflicts
  where id = $1
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Conflicto pendiente no encontrado';
  end if;

  select coalesce(systems.is_conquerable, true)
  into v_is_conquerable_system
  from public.systems
  where systems.id = v_conflict.system_id;

  select player_factions.faction_id
  into v_reporter_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
    and exists (
      select 1
      from public.get_battle_report_required_faction_ids(v_conflict.id) required_factions
      where required_factions.faction_id = player_factions.faction_id
    )
  order by player_factions.created_at
  limit 1;

  if not v_is_admin and v_reporter_faction_id is null then
    raise exception 'Solo participantes o admin pueden editar esta batalla';
  end if;

  v_expected_revision := nullif(report_payload->>'expected_revision', '')::integer;
  v_battle_mode := coalesce(nullif(report_payload->>'battle_mode', ''), 'tabletop');

  if v_battle_mode not in ('tabletop', 'autoresolve') then
    raise exception 'Modo de batalla no valido';
  end if;

  v_winner_faction_id := nullif(report_payload->>'winner_faction_id', '')::uuid;
  v_survivors := coalesce(report_payload->'survivors', '{}'::jsonb);
  v_wounds_remaining := coalesce(report_payload->'wounds_remaining', '{}'::jsonb);

  if v_winner_faction_id is not null
    and v_winner_faction_id not in (v_conflict.attacker_faction_id, v_conflict.defender_faction_id) then
    raise exception 'La faccion ganadora debe participar en el conflicto';
  end if;

  v_final_controller_faction_id := case
    when v_is_conquerable_system then v_winner_faction_id
    else null
  end;
  v_post_battle_blocked_until := now() + interval '14 days';

  v_casualties := public.validate_battle_survivors_and_wounds(
    v_conflict.id,
    v_survivors,
    v_wounds_remaining
  );

  select *
  into v_existing
  from public.battle_reports
  where battle_reports.conflict_id = v_conflict.id
    and battle_reports.status in (
      'draft',
      'awaiting_validation',
      'players_confirmed',
      'submitted',
      'auto_confirmed',
      'disputed'
    )
  order by battle_reports.updated_at desc, battle_reports.created_at desc
  limit 1
  for update;

  if found then
    if v_expected_revision is not null and v_expected_revision <> coalesce(v_existing.revision, 1) then
      raise exception 'El informe ha cambiado; recarga la revision actual';
    end if;

    v_revision := coalesce(v_existing.revision, 1) + 1;

    update public.battle_reports
    set
      reporter_user_id = v_user_id,
      reporter_faction_id = v_reporter_faction_id,
      winner_faction_id = v_winner_faction_id,
      final_controller_faction_id = v_final_controller_faction_id,
      casualties = v_casualties,
      survivors = v_survivors,
      wounds_remaining = v_wounds_remaining,
      xp_awards = '{}'::jsonb,
      enhancements = '{}'::jsonb,
      post_battle_blocked_until = v_post_battle_blocked_until,
      narrative_notes = report_payload->>'narrative_notes',
      battle_mode = v_battle_mode,
      revision = v_revision,
      participant_validations = '{}'::jsonb,
      status = 'awaiting_validation',
      resolved_at = null,
      updated_at = now()
    where id = v_existing.id
    returning id into v_report_id;
  else
    if v_expected_revision is not null and v_expected_revision <> 0 then
      raise exception 'El informe ha cambiado; recarga la revision actual';
    end if;

    insert into public.battle_reports (
      conflict_id,
      reporter_user_id,
      reporter_faction_id,
      winner_faction_id,
      final_controller_faction_id,
      casualties,
      survivors,
      wounds_remaining,
      xp_awards,
      enhancements,
      post_battle_blocked_until,
      narrative_notes,
      battle_mode,
      revision,
      participant_validations,
      status,
      updated_at
    )
    values (
      v_conflict.id,
      v_user_id,
      v_reporter_faction_id,
      v_winner_faction_id,
      v_final_controller_faction_id,
      v_casualties,
      v_survivors,
      v_wounds_remaining,
      '{}'::jsonb,
      '{}'::jsonb,
      v_post_battle_blocked_until,
      report_payload->>'narrative_notes',
      v_battle_mode,
      1,
      '{}'::jsonb,
      'awaiting_validation',
      now()
    )
    returning id into v_report_id;
  end if;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_reporter_faction_id,
    'battle_report_shared_saved',
    jsonb_build_object(
      'report_id', v_report_id,
      'conflict_id', v_conflict.id,
      'battle_mode', v_battle_mode,
      'expected_revision', v_expected_revision
    )
  );

  return v_report_id;
end;
$$;

revoke execute on function public.find_retreat_or_capital_system(uuid, uuid) from public;
revoke execute on function public.find_shortest_unblocked_path(uuid, uuid) from public;
revoke execute on function public.queue_battle_support_return(uuid) from public;
revoke execute on function public.submit_battle_report(uuid, jsonb) from public;

grant execute on function public.submit_battle_report(uuid, jsonb) to authenticated;
