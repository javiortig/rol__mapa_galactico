create or replace function public.create_attack_order(
  unit_selections jsonb,
  origin_system_id uuid,
  target_system_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_faction_id uuid;
  v_selected_origin_id uuid;
  v_origin public.systems%rowtype;
  v_target public.systems%rowtype;
  v_operation_id uuid;
  v_order_id uuid;
  v_selection record;
  v_unit public.campaign_units%rowtype;
  v_selected_unit_ids uuid[] := '{}';
  v_duration_seconds integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if unit_selections is null or jsonb_typeof(unit_selections) <> 'array' or jsonb_array_length(unit_selections) = 0 then
    raise exception 'Selecciona al menos una unidad';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_origin
  from public.systems
  where id = origin_system_id
  for update;

  if not found then
    raise exception 'Sistema de origen no encontrado';
  end if;

  select *
  into v_target
  from public.systems
  where id = target_system_id
  for update;

  if not found then
    raise exception 'Sistema objetivo no encontrado';
  end if;

  for v_selection in
    select unit_id, quantity
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    if v_selection.unit_id is null or v_selection.unit_id = any(v_selected_unit_ids) then
      raise exception 'Seleccion de unidades no valida';
    end if;

    select *
    into v_unit
    from public.campaign_units
    where id = v_selection.unit_id
    for update;

    if not found or v_unit.status <> 'ready' or v_unit.quantity <= 0 then
      raise exception 'Unidades no disponibles';
    end if;

    if coalesce(v_selection.quantity, v_unit.quantity) <> v_unit.quantity then
      raise exception 'Las unidades no se pueden dividir al atacar';
    end if;

    if v_faction_id is null then
      v_faction_id := v_unit.faction_id;
      v_selected_origin_id := v_unit.current_system_id;
    elsif v_unit.faction_id is distinct from v_faction_id
      or v_unit.current_system_id is distinct from v_selected_origin_id then
      raise exception 'Todas las unidades deben pertenecer a la misma faccion y origen';
    end if;

    v_selected_unit_ids := array_append(v_selected_unit_ids, v_unit.id);
  end loop;

  if v_selected_origin_id is distinct from origin_system_id then
    raise exception 'Las unidades no estan en el sistema de origen';
  end if;

  if not v_is_admin and not public.is_faction_member(v_faction_id) then
    raise exception 'No puedes atacar con unidades de esta faccion';
  end if;

  if v_origin.status <> 'controlled'
    or v_origin.controller_faction_id <> v_faction_id
    or (v_origin.blocked_until is not null and v_origin.blocked_until > now()) then
    raise exception 'El sistema de origen no esta disponible';
  end if;

  if v_target.status <> 'controlled'
    or v_target.controller_faction_id is null
    or v_target.controller_faction_id = v_faction_id
    or (v_target.blocked_until is not null and v_target.blocked_until > now()) then
    raise exception 'Destino de ataque no disponible';
  end if;

  if not exists (
    select 1
    from public.system_edges
    where not is_blocked
      and (
        (from_system_id = origin_system_id and to_system_id = target_system_id)
        or (from_system_id = target_system_id and to_system_id = origin_system_id)
      )
  ) then
    raise exception 'Sistema no adyacente';
  end if;

  perform public.validate_attack_limits(v_faction_id, v_target.controller_faction_id);

  select attack_duration_seconds
  into v_duration_seconds
  from public.campaign_settings
  where id = 'default';

  v_duration_seconds := coalesce(v_duration_seconds, 518400);

  insert into public.battle_operations (
    mode,
    status,
    leader_faction_id,
    defender_faction_id,
    origin_system_id,
    target_system_id,
    attack_arrival_at,
    launched_at,
    created_by_user_id
  )
  values (
    'solo',
    'moving',
    v_faction_id,
    v_target.controller_faction_id,
    origin_system_id,
    target_system_id,
    now() + make_interval(secs => v_duration_seconds),
    now(),
    v_user_id
  )
  returning id into v_operation_id;

  insert into public.battle_operation_members (
    operation_id,
    faction_id,
    side,
    role,
    invitation_status,
    invited_by_faction_id,
    responded_at
  )
  values
    (v_operation_id, v_faction_id, 'attacker', 'commander', 'accepted', v_faction_id, now()),
    (v_operation_id, v_target.controller_faction_id, 'defender', 'commander', 'accepted', v_faction_id, now());

  insert into public.movement_orders (
    faction_id,
    defender_faction_id,
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
    v_faction_id,
    v_target.controller_faction_id,
    origin_system_id,
    target_system_id,
    'attack',
    'attack',
    v_operation_id,
    0,
    now(),
    now(),
    now() + make_interval(secs => v_duration_seconds),
    'moving',
    array[origin_system_id, target_system_id],
    1,
    v_duration_seconds
  )
  returning id into v_order_id;

  update public.battle_operations
  set attack_movement_order_id = v_order_id
  where id = v_operation_id;

  for v_selection in
    select unit_id
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    select *
    into v_unit
    from public.campaign_units
    where id = v_selection.unit_id
    for update;

    update public.campaign_units
    set status = 'moving', updated_at = now()
    where id = v_unit.id;

    insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
    values (v_order_id, v_unit.id, v_unit.quantity);

    insert into public.battle_unit_commitments (
      operation_id,
      unit_id,
      faction_id,
      side,
      role,
      home_system_id,
      staging_system_id,
      outbound_movement_order_id,
      outbound_path_system_ids,
      quantity_at_commitment,
      points_at_commitment,
      status
    )
    values (
      v_operation_id,
      v_unit.id,
      v_unit.faction_id,
      'attacker',
      'leader',
      origin_system_id,
      origin_system_id,
      v_order_id,
      array[origin_system_id, target_system_id],
      v_unit.quantity,
      greatest(1, ceil((v_unit.points::numeric * v_unit.quantity) / greatest(v_unit.starting_quantity, 1))::integer),
      'en_route'
    );
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'battle_operation_launched',
    jsonb_build_object(
      'operation_id', v_operation_id,
      'movement_order_id', v_order_id,
      'mode', 'solo',
      'arrival_at', now() + make_interval(secs => v_duration_seconds)
    )
  );

  return v_order_id;
end;
$$;

create or replace function public.create_coalition_attack_draft(
  unit_selections jsonb,
  origin_system_id uuid,
  target_system_id uuid,
  invited_faction_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_faction_id uuid;
  v_selected_origin_id uuid;
  v_origin public.systems%rowtype;
  v_target public.systems%rowtype;
  v_operation_id uuid;
  v_selection record;
  v_invited_faction_id uuid;
  v_unit public.campaign_units%rowtype;
  v_selected_unit_ids uuid[] := '{}';
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if unit_selections is null or jsonb_typeof(unit_selections) <> 'array' or jsonb_array_length(unit_selections) = 0 then
    raise exception 'Selecciona al menos una unidad propia';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_origin
  from public.systems
  where id = origin_system_id
  for update;

  select *
  into v_target
  from public.systems
  where id = target_system_id
  for update;

  if v_origin.id is null or v_target.id is null then
    raise exception 'Origen u objetivo no encontrado';
  end if;

  for v_selection in
    select unit_id, quantity
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    if v_selection.unit_id is null or v_selection.unit_id = any(v_selected_unit_ids) then
      raise exception 'Seleccion de unidades no valida';
    end if;

    select *
    into v_unit
    from public.campaign_units
    where id = v_selection.unit_id
    for update;

    if not found or v_unit.status <> 'ready' or v_unit.quantity <= 0 then
      raise exception 'Unidades no disponibles';
    end if;

    if coalesce(v_selection.quantity, v_unit.quantity) <> v_unit.quantity then
      raise exception 'Las unidades no se pueden dividir';
    end if;

    if v_faction_id is null then
      v_faction_id := v_unit.faction_id;
      v_selected_origin_id := v_unit.current_system_id;
    elsif v_unit.faction_id is distinct from v_faction_id
      or v_unit.current_system_id is distinct from v_selected_origin_id then
      raise exception 'Todas las unidades deben pertenecer a la misma faccion y origen';
    end if;

    v_selected_unit_ids := array_append(v_selected_unit_ids, v_unit.id);
  end loop;

  if v_selected_origin_id is distinct from origin_system_id then
    raise exception 'Las unidades no estan en el sistema de reunion';
  end if;

  if not v_is_admin and not public.is_faction_member(v_faction_id) then
    raise exception 'No puedes preparar esta coalicion';
  end if;

  if v_origin.status <> 'controlled'
    or v_origin.controller_faction_id <> v_faction_id
    or (v_origin.blocked_until is not null and v_origin.blocked_until > now()) then
    raise exception 'El sistema de reunion no esta disponible';
  end if;

  if v_target.status <> 'controlled'
    or v_target.controller_faction_id is null
    or v_target.controller_faction_id = v_faction_id
    or (v_target.blocked_until is not null and v_target.blocked_until > now()) then
    raise exception 'Destino de ataque no disponible';
  end if;

  if not exists (
    select 1
    from public.system_edges
    where not is_blocked
      and (
        (from_system_id = origin_system_id and to_system_id = target_system_id)
        or (from_system_id = target_system_id and to_system_id = origin_system_id)
      )
  ) then
    raise exception 'Sistema no adyacente';
  end if;

  insert into public.battle_operations (
    mode,
    status,
    leader_faction_id,
    defender_faction_id,
    origin_system_id,
    target_system_id,
    created_by_user_id
  )
  values (
    'coalition',
    'assembling',
    v_faction_id,
    v_target.controller_faction_id,
    origin_system_id,
    target_system_id,
    v_user_id
  )
  returning id into v_operation_id;

  insert into public.battle_operation_members (
    operation_id,
    faction_id,
    side,
    role,
    invitation_status,
    invited_by_faction_id,
    responded_at
  )
  values (
    v_operation_id,
    v_faction_id,
    'attacker',
    'commander',
    'accepted',
    v_faction_id,
    now()
  );

  if invited_faction_ids is not null then
    foreach v_invited_faction_id in array invited_faction_ids
    loop
      if v_invited_faction_id is null
        or v_invited_faction_id in (v_faction_id, v_target.controller_faction_id) then
        continue;
      end if;

      insert into public.battle_operation_members (
        operation_id,
        faction_id,
        side,
        role,
        invitation_status,
        invited_by_faction_id
      )
      values (
        v_operation_id,
        v_invited_faction_id,
        'attacker',
        'supporter',
        'invited',
        v_faction_id
      )
      on conflict (operation_id, faction_id) do nothing;
    end loop;
  end if;

  for v_selection in
    select unit_id
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    select *
    into v_unit
    from public.campaign_units
    where id = v_selection.unit_id
    for update;

    update public.campaign_units
    set status = 'moving', updated_at = now()
    where id = v_unit.id;

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
    values (
      v_operation_id,
      v_unit.id,
      v_unit.faction_id,
      'attacker',
      'leader',
      origin_system_id,
      origin_system_id,
      array[origin_system_id],
      v_unit.quantity,
      greatest(1, ceil((v_unit.points::numeric * v_unit.quantity) / greatest(v_unit.starting_quantity, 1))::integer),
      'staged'
    );
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'coalition_attack_draft_created',
    jsonb_build_object('operation_id', v_operation_id, 'target_system_id', target_system_id)
  );

  return v_operation_id;
end;
$$;

create or replace function public.invite_battle_support(
  operation_id uuid,
  target_faction_id uuid,
  support_side text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_faction_id uuid := public.current_player_faction_id();
  v_is_admin boolean := public.is_admin();
  v_operation public.battle_operations%rowtype;
  v_invitation_id uuid;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if support_side not in ('attacker', 'defender') then
    raise exception 'Bando no valido';
  end if;

  select *
  into v_operation
  from public.battle_operations
  where id = invite_battle_support.operation_id
  for update;

  if not found then
    raise exception 'Operacion no encontrada';
  end if;

  if not v_is_admin and not exists (
    select 1
    from public.battle_operation_members
    where battle_operation_members.operation_id = v_operation.id
      and faction_id = v_actor_faction_id
      and side = support_side
      and role = 'commander'
      and invitation_status = 'accepted'
  ) then
    raise exception 'Solo el comandante del bando puede invitar apoyos';
  end if;

  if support_side = 'attacker' and v_operation.status <> 'assembling' then
    raise exception 'La coalicion atacante ya ha salido';
  end if;

  if support_side = 'defender' and v_operation.status <> 'moving' then
    raise exception 'Los apoyos defensivos solo llegan antes del ataque';
  end if;

  if target_faction_id in (v_operation.leader_faction_id, v_operation.defender_faction_id) then
    raise exception 'La faccion ya es comandante de un bando';
  end if;

  insert into public.battle_operation_members (
    operation_id,
    faction_id,
    side,
    role,
    invitation_status,
    invited_by_faction_id
  )
  values (
    v_operation.id,
    target_faction_id,
    support_side,
    'supporter',
    'invited',
    coalesce(v_actor_faction_id, v_operation.leader_faction_id)
  )
  on conflict on constraint battle_operation_members_operation_id_faction_id_key do update
  set
    side = excluded.side,
    role = 'supporter',
    invitation_status = 'invited',
    invited_by_faction_id = excluded.invited_by_faction_id,
    invited_at = now(),
    responded_at = null
  where battle_operation_members.invitation_status in ('rejected', 'closed')
  returning id into v_invitation_id;

  if v_invitation_id is null then
    raise exception 'La faccion ya participa o tiene una invitacion activa';
  end if;

  return v_invitation_id;
end;
$$;

create or replace function public.respond_battle_support_invitation(
  operation_id uuid,
  decision text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_faction_id uuid := public.current_player_faction_id();
  v_member public.battle_operation_members%rowtype;
begin
  if auth.uid() is null or v_faction_id is null then
    raise exception 'Usuario sin faccion activa';
  end if;

  if decision not in ('accepted', 'rejected') then
    raise exception 'Decision no valida';
  end if;

  select *
  into v_member
  from public.battle_operation_members
  where battle_operation_members.operation_id = respond_battle_support_invitation.operation_id
    and faction_id = v_faction_id
    and role = 'supporter'
  for update;

  if not found or v_member.invitation_status <> 'invited' then
    raise exception 'Invitacion no disponible';
  end if;

  update public.battle_operation_members
  set invitation_status = decision, responded_at = now()
  where id = v_member.id;

  return v_member.id;
end;
$$;

create or replace function public.join_battle_operation(
  operation_id uuid,
  unit_selections jsonb,
  path_system_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid := public.current_player_faction_id();
  v_operation public.battle_operations%rowtype;
  v_member public.battle_operation_members%rowtype;
  v_expected_destination_id uuid;
  v_origin_system_id uuid;
  v_path_length integer;
  v_index integer;
  v_from uuid;
  v_to uuid;
  v_edge_cost integer;
  v_duration_seconds integer;
  v_total_cost integer := 0;
  v_order_id uuid;
  v_selection record;
  v_unit public.campaign_units%rowtype;
  v_resources public.faction_resources%rowtype;
  v_selected_unit_ids uuid[] := '{}';
  v_commitment_status text;
begin
  if v_user_id is null or v_faction_id is null then
    raise exception 'Usuario sin faccion activa';
  end if;

  if unit_selections is null or jsonb_typeof(unit_selections) <> 'array' or jsonb_array_length(unit_selections) = 0 then
    raise exception 'Selecciona al menos una unidad';
  end if;

  if path_system_ids is null or cardinality(path_system_ids) < 1 then
    raise exception 'Ruta no valida';
  end if;

  select *
  into v_operation
  from public.battle_operations
  where id = join_battle_operation.operation_id
  for update;

  if not found then
    raise exception 'Operacion no encontrada';
  end if;

  select *
  into v_member
  from public.battle_operation_members
  where battle_operation_members.operation_id = v_operation.id
    and faction_id = v_faction_id
    and role = 'supporter'
  for update;

  if not found or v_member.invitation_status not in ('invited', 'accepted') then
    raise exception 'No tienes una invitacion activa';
  end if;

  if v_member.side = 'attacker' then
    if v_operation.status <> 'assembling' then
      raise exception 'La coalicion atacante ya ha salido';
    end if;
    v_expected_destination_id := v_operation.origin_system_id;
  else
    if v_operation.status <> 'moving' or v_operation.attack_arrival_at is null then
      raise exception 'La ventana de apoyo defensivo esta cerrada';
    end if;
    v_expected_destination_id := v_operation.target_system_id;
  end if;

  v_path_length := cardinality(path_system_ids);

  if path_system_ids[v_path_length] is distinct from v_expected_destination_id then
    raise exception 'La ruta no termina en el punto de reunion del bando';
  end if;

  if (
    select count(distinct system_id)
    from unnest(path_system_ids) as route(system_id)
  ) <> v_path_length then
    raise exception 'La ruta contiene sistemas duplicados';
  end if;

  for v_selection in
    select unit_id, quantity
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    if v_selection.unit_id is null or v_selection.unit_id = any(v_selected_unit_ids) then
      raise exception 'Seleccion de unidades no valida';
    end if;

    select *
    into v_unit
    from public.campaign_units
    where id = v_selection.unit_id
    for update;

    if not found
      or v_unit.faction_id <> v_faction_id
      or v_unit.status <> 'ready'
      or v_unit.quantity <= 0 then
      raise exception 'Unidad no disponible';
    end if;

    if coalesce(v_selection.quantity, v_unit.quantity) <> v_unit.quantity then
      raise exception 'Las unidades no se pueden dividir';
    end if;

    if v_origin_system_id is null then
      v_origin_system_id := v_unit.current_system_id;
    elsif v_unit.current_system_id is distinct from v_origin_system_id then
      raise exception 'Todas las unidades deben salir del mismo sistema';
    end if;

    if exists (
      select 1
      from public.battle_unit_commitments
      join public.battle_operations active_operation
        on active_operation.id = battle_unit_commitments.operation_id
      where battle_unit_commitments.unit_id = v_unit.id
        and active_operation.status in ('assembling', 'moving', 'in_battle')
        and battle_unit_commitments.status not in ('returned', 'destroyed', 'cancelled')
    ) then
      raise exception 'La unidad ya esta comprometida en otra operacion';
    end if;

    v_selected_unit_ids := array_append(v_selected_unit_ids, v_unit.id);
  end loop;

  if path_system_ids[1] is distinct from v_origin_system_id then
    raise exception 'La ruta no empieza en el origen de las unidades';
  end if;

  if not exists (
    select 1
    from public.systems
    where id = v_origin_system_id
      and status = 'controlled'
      and controller_faction_id = v_faction_id
      and (blocked_until is null or blocked_until <= now())
  ) then
    raise exception 'El sistema de origen no esta disponible';
  end if;

  for v_index in 1..v_path_length loop
    if not exists (select 1 from public.systems where id = path_system_ids[v_index]) then
      raise exception 'La ruta contiene un sistema inexistente';
    end if;

    if v_index > 1 and v_index < v_path_length and exists (
      select 1
      from public.systems
      where id = path_system_ids[v_index]
        and controller_faction_id is not null
        and controller_faction_id <> v_faction_id
        and not exists (
          select 1
          from public.battle_operation_members
          where battle_operation_members.operation_id = v_operation.id
            and faction_id = systems.controller_faction_id
            and invitation_status = 'accepted'
        )
    ) then
      raise exception 'La ruta atraviesa territorio ajeno a la operacion';
    end if;
  end loop;

  if v_path_length > 1 then
    for v_index in 1..(v_path_length - 1) loop
      v_from := path_system_ids[v_index];
      v_to := path_system_ids[v_index + 1];

      select uridium_cost
      into strict v_edge_cost
      from public.system_edges
      where not is_blocked
        and (
          (from_system_id = v_from and to_system_id = v_to)
          or (from_system_id = v_to and to_system_id = v_from)
      )
      limit 1;

      v_total_cost := v_total_cost + v_edge_cost;
    end loop;
  end if;

  select movement_edge_duration_seconds * greatest(v_path_length - 1, 0)
  into v_duration_seconds
  from public.campaign_settings
  where id = 'default';

  v_duration_seconds := coalesce(v_duration_seconds, 259200 * greatest(v_path_length - 1, 0));

  if v_member.side = 'defender'
    and now() + make_interval(secs => v_duration_seconds) > v_operation.attack_arrival_at then
    raise exception 'Estas tropas no llegan antes de que el ataque cierre el plantel';
  end if;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found or v_resources.uridium < v_total_cost then
    raise exception 'Uridium insuficiente';
  end if;

  update public.faction_resources
  set uridium = uridium - v_total_cost, updated_at = now()
  where faction_id = v_faction_id;

  v_commitment_status := case when v_path_length = 1 then 'staged' else 'en_route' end;

  if v_path_length > 1 then
    insert into public.movement_orders (
      faction_id,
      defender_faction_id,
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
      v_faction_id,
      v_operation.defender_faction_id,
      v_origin_system_id,
      v_expected_destination_id,
      'move',
      case when v_member.side = 'attacker' then 'coalition_staging' else 'defense_support' end,
      v_operation.id,
      v_total_cost,
      now(),
      now(),
      now() + make_interval(secs => v_duration_seconds),
      'moving',
      path_system_ids,
      v_path_length - 1,
      v_duration_seconds
    )
    returning id into v_order_id;
  end if;

  foreach v_from in array v_selected_unit_ids
  loop
    select *
    into v_unit
    from public.campaign_units
    where id = v_from
    for update;

    update public.campaign_units
    set status = 'moving', updated_at = now()
    where id = v_unit.id;

    if v_order_id is not null then
      insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
      values (v_order_id, v_unit.id, v_unit.quantity);
    end if;

    insert into public.battle_unit_commitments (
      operation_id,
      unit_id,
      faction_id,
      side,
      role,
      home_system_id,
      staging_system_id,
      outbound_movement_order_id,
      outbound_path_system_ids,
      quantity_at_commitment,
      points_at_commitment,
      status
    )
    values (
      v_operation.id,
      v_unit.id,
      v_unit.faction_id,
      v_member.side,
      'supporter',
      v_origin_system_id,
      v_expected_destination_id,
      v_order_id,
      path_system_ids,
      v_unit.quantity,
      greatest(1, ceil((v_unit.points::numeric * v_unit.quantity) / greatest(v_unit.starting_quantity, 1))::integer),
      v_commitment_status
    );
  end loop;

  update public.battle_operation_members
  set invitation_status = 'accepted', responded_at = coalesce(responded_at, now())
  where id = v_member.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'battle_support_committed',
    jsonb_build_object(
      'operation_id', v_operation.id,
      'side', v_member.side,
      'movement_order_id', v_order_id,
      'path_system_ids', to_jsonb(path_system_ids)
    )
  );

  return coalesce(v_order_id, v_operation.id);
exception
  when no_data_found then
    raise exception 'La ruta contiene un tramo no valido';
end;
$$;

create or replace function public.launch_coalition_attack(operation_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid := public.current_player_faction_id();
  v_operation public.battle_operations%rowtype;
  v_origin public.systems%rowtype;
  v_target public.systems%rowtype;
  v_commitment public.battle_unit_commitments%rowtype;
  v_unit public.campaign_units%rowtype;
  v_order_id uuid;
  v_duration_seconds integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select *
  into v_operation
  from public.battle_operations
  where id = launch_coalition_attack.operation_id
  for update;

  if not found or v_operation.mode <> 'coalition' or v_operation.status <> 'assembling' then
    raise exception 'La coalicion no esta disponible para lanzar';
  end if;

  if not public.is_admin() and v_faction_id <> v_operation.leader_faction_id then
    raise exception 'Solo el comandante atacante puede lanzar la coalicion';
  end if;

  if not exists (
    select 1
    from public.battle_unit_commitments
    where battle_unit_commitments.operation_id = v_operation.id
      and side = 'attacker'
  ) then
    raise exception 'La coalicion no tiene unidades';
  end if;

  if exists (
    select 1
    from public.battle_unit_commitments
    where battle_unit_commitments.operation_id = v_operation.id
      and side = 'attacker'
      and status <> 'staged'
  ) then
    raise exception 'Aun hay tropas aliadas viajando al punto de reunion';
  end if;

  select *
  into v_origin
  from public.systems
  where id = v_operation.origin_system_id
  for update;

  select *
  into v_target
  from public.systems
  where id = v_operation.target_system_id
  for update;

  if v_origin.status <> 'controlled'
    or v_origin.controller_faction_id <> v_operation.leader_faction_id
    or (v_origin.blocked_until is not null and v_origin.blocked_until > now()) then
    raise exception 'El punto de reunion ya no esta disponible';
  end if;

  if v_target.status <> 'controlled'
    or v_target.controller_faction_id <> v_operation.defender_faction_id
    or (v_target.blocked_until is not null and v_target.blocked_until > now()) then
    raise exception 'El objetivo ya no esta disponible';
  end if;

  perform public.validate_attack_limits(v_operation.leader_faction_id, v_operation.defender_faction_id);

  select attack_duration_seconds
  into v_duration_seconds
  from public.campaign_settings
  where id = 'default';

  v_duration_seconds := coalesce(v_duration_seconds, 518400);

  insert into public.movement_orders (
    faction_id,
    defender_faction_id,
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
    v_operation.leader_faction_id,
    v_operation.defender_faction_id,
    v_operation.origin_system_id,
    v_operation.target_system_id,
    'attack',
    'attack',
    v_operation.id,
    0,
    now(),
    now(),
    now() + make_interval(secs => v_duration_seconds),
    'moving',
    array[v_operation.origin_system_id, v_operation.target_system_id],
    1,
    v_duration_seconds
  )
  returning id into v_order_id;

  for v_commitment in
    select *
    from public.battle_unit_commitments
    where battle_unit_commitments.operation_id = v_operation.id
      and side = 'attacker'
    order by joined_at, id
    for update
  loop
    select *
    into v_unit
    from public.campaign_units
    where id = v_commitment.unit_id
    for update;

    if v_unit.status <> 'moving'
      or v_unit.current_system_id <> v_operation.origin_system_id
      or v_unit.quantity <= 0 then
      raise exception 'Una unidad comprometida ya no esta disponible';
    end if;

    insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
    values (v_order_id, v_unit.id, v_unit.quantity);
  end loop;

  update public.battle_unit_commitments
  set
    outbound_movement_order_id = v_order_id,
    status = 'en_route',
    updated_at = now()
  where battle_unit_commitments.operation_id = v_operation.id
    and side = 'attacker';

  update public.battle_operations
  set
    status = 'moving',
    attack_movement_order_id = v_order_id,
    attack_arrival_at = now() + make_interval(secs => v_duration_seconds),
    launched_at = now(),
    updated_at = now()
  where id = v_operation.id;

  insert into public.battle_operation_members (
    operation_id,
    faction_id,
    side,
    role,
    invitation_status,
    invited_by_faction_id,
    responded_at
  )
  values (
    v_operation.id,
    v_operation.defender_faction_id,
    'defender',
    'commander',
    'accepted',
    v_operation.leader_faction_id,
    now()
  )
  on conflict on constraint battle_operation_members_operation_id_faction_id_key do nothing;

  update public.battle_operation_members
  set invitation_status = 'closed', responded_at = coalesce(responded_at, now())
  where battle_operation_members.operation_id = v_operation.id
    and side = 'attacker'
    and role = 'supporter'
    and invitation_status = 'invited';

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_operation.leader_faction_id,
    'battle_operation_launched',
    jsonb_build_object(
      'operation_id', v_operation.id,
      'movement_order_id', v_order_id,
      'mode', 'coalition',
      'arrival_at', now() + make_interval(secs => v_duration_seconds)
    )
  );

  return v_order_id;
end;
$$;

create or replace function public.cancel_battle_operation(operation_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_faction_id uuid := public.current_player_faction_id();
  v_operation public.battle_operations%rowtype;
  v_commitment public.battle_unit_commitments%rowtype;
begin
  select *
  into v_operation
  from public.battle_operations
  where id = cancel_battle_operation.operation_id
  for update;

  if not found or v_operation.status <> 'assembling' then
    raise exception 'Solo se puede cancelar una coalicion antes de lanzarla';
  end if;

  if not public.is_admin() and v_faction_id <> v_operation.leader_faction_id then
    raise exception 'Solo el comandante puede cancelar la coalicion';
  end if;

  for v_commitment in
    select *
    from public.battle_unit_commitments
    where battle_unit_commitments.operation_id = v_operation.id
    for update
  loop
    if v_commitment.outbound_movement_order_id is not null then
      perform public.cancel_reserved_movement_order(
        v_commitment.outbound_movement_order_id,
        'Coalicion cancelada antes del lanzamiento',
        (
          select uridium_cost
          from public.movement_orders
          where id = v_commitment.outbound_movement_order_id
        )
      );
    end if;

    update public.campaign_units
    set
      current_system_id = v_commitment.home_system_id,
      status = 'ready',
      updated_at = now()
    where id = v_commitment.unit_id
      and quantity > 0;
  end loop;

  update public.battle_unit_commitments
  set status = 'cancelled', updated_at = now()
  where battle_unit_commitments.operation_id = v_operation.id;

  update public.battle_operation_members
  set invitation_status = 'closed', responded_at = coalesce(responded_at, now())
  where battle_operation_members.operation_id = v_operation.id
    and role = 'supporter'
    and invitation_status = 'invited';

  update public.battle_operations
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancellation_reason = 'Cancelada por el comandante antes del lanzamiento',
    updated_at = now()
  where id = v_operation.id;

  return v_operation.id;
end;
$$;

create or replace function public.reverse_uuid_array(values_to_reverse uuid[])
returns uuid[]
language sql
immutable
as $$
  select coalesce(array_agg(item order by position desc), '{}'::uuid[])
  from unnest(values_to_reverse) with ordinality as source(item, position);
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

  if not exists (
    select 1
    from public.systems
    where id = v_commitment.home_system_id
      and status = 'controlled'
      and controller_faction_id = v_commitment.faction_id
  ) then
    update public.campaign_units
    set status = 'retreat_pending', updated_at = now()
    where id = v_unit.id;

    update public.battle_unit_commitments
    set status = 'return_pending', updated_at = now()
    where id = v_commitment.id;

    return null;
  end if;

  if v_commitment.side = 'attacker' then
    v_path := array[v_operation.target_system_id] || public.reverse_uuid_array(v_commitment.outbound_path_system_ids);
  else
    v_path := public.reverse_uuid_array(v_commitment.outbound_path_system_ids);
  end if;

  v_path_length := cardinality(v_path);

  if v_path_length < 2
    or v_path[1] is distinct from v_operation.target_system_id
    or v_path[v_path_length] is distinct from v_commitment.home_system_id then
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
    v_commitment.home_system_id,
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

create or replace function public.resolve_movement_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_system public.systems%rowtype;
  v_operation public.battle_operations%rowtype;
  v_commitment public.battle_unit_commitments%rowtype;
  v_conflict_id uuid;
  v_blocked_until timestamptz;
  v_resolved integer := 0;
begin
  for v_order in
    select *
    from public.movement_orders
    where status = 'moving'
      and arrival_at is not null
      and arrival_at <= now()
    order by
      arrival_at,
      case when movement_purpose = 'attack' then 1 else 0 end,
      created_at,
      id
    for update
  loop
    select *
    into v_system
    from public.systems
    where id = v_order.to_system_id
    for update;

    if not found then
      perform public.cancel_reserved_movement_order(v_order.id, 'Sistema de destino no encontrado', v_order.uridium_cost);
      v_resolved := v_resolved + 1;
      continue;
    end if;

    if v_order.movement_purpose in ('coalition_staging', 'defense_support') then
      select *
      into v_operation
      from public.battle_operations
      where id = v_order.battle_operation_id
      for update;

      if not found
        or (v_order.movement_purpose = 'coalition_staging' and v_operation.status <> 'assembling')
        or (
          v_order.movement_purpose = 'defense_support'
          and (
            v_operation.status <> 'moving'
            or v_operation.attack_arrival_at is null
            or v_order.arrival_at > v_operation.attack_arrival_at
          )
        ) then
        perform public.cancel_reserved_movement_order(v_order.id, 'La ventana de apoyo ya esta cerrada', 0);

        update public.battle_unit_commitments
        set status = 'cancelled', updated_at = now()
        where outbound_movement_order_id = v_order.id;

        v_resolved := v_resolved + 1;
        continue;
      end if;

      update public.movement_orders
      set status = 'arrived', resolved_at = now()
      where id = v_order.id;

      update public.campaign_units
      set
        current_system_id = v_order.to_system_id,
        status = 'moving',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );

      update public.battle_unit_commitments
      set status = 'staged', updated_at = now()
      where outbound_movement_order_id = v_order.id;

      v_resolved := v_resolved + 1;
      continue;
    end if;

    if v_order.movement_purpose = 'battle_return' then
      if v_system.status = 'controlled'
        and v_system.controller_faction_id = v_order.faction_id then
        update public.campaign_units
        set
          current_system_id = v_order.to_system_id,
          status = 'ready',
          updated_at = now()
        where id in (
          select unit_id
          from public.movement_order_units
          where movement_order_id = v_order.id
        );

        update public.movement_orders
        set status = 'arrived', resolved_at = now()
        where id = v_order.id;

        update public.battle_unit_commitments
        set status = 'returned', returned_at = now(), updated_at = now()
        where return_movement_order_id = v_order.id;
      else
        update public.campaign_units
        set status = 'retreat_pending', updated_at = now()
        where id in (
          select unit_id
          from public.movement_order_units
          where movement_order_id = v_order.id
        );

        update public.movement_orders
        set
          status = 'cancelled',
          cancelled_at = now(),
          cancellation_reason = 'El planeta de origen ya no pertenece a la faccion',
          resolved_at = now()
        where id = v_order.id;

        update public.battle_unit_commitments
        set status = 'return_pending', updated_at = now()
        where return_movement_order_id = v_order.id;
      end if;

      v_resolved := v_resolved + 1;
      continue;
    end if;

    if v_order.movement_type = 'attack' and v_order.battle_operation_id is not null then
      select *
      into v_operation
      from public.battle_operations
      where id = v_order.battle_operation_id
      for update;

      if not found
        or v_operation.status <> 'moving'
        or v_system.status <> 'controlled'
        or v_system.controller_faction_id is distinct from v_operation.defender_faction_id then
        perform public.cancel_reserved_movement_order(v_order.id, 'El objetivo ya no es enemigo', 0);

        update public.campaign_units units
        set
          current_system_id = commitments.home_system_id,
          status = 'ready',
          updated_at = now()
        from public.battle_unit_commitments commitments
        where commitments.operation_id = v_order.battle_operation_id
          and commitments.unit_id = units.id
          and commitments.role = 'supporter'
          and units.quantity > 0;

        update public.battle_unit_commitments
        set status = 'cancelled', updated_at = now()
        where operation_id = v_order.battle_operation_id;

        update public.battle_operations
        set
          status = 'cancelled',
          cancelled_at = now(),
          cancellation_reason = 'El objetivo cambio antes de la llegada',
          updated_at = now()
        where id = v_order.battle_operation_id;

        v_resolved := v_resolved + 1;
        continue;
      end if;

      for v_commitment in
        select *
        from public.battle_unit_commitments
        where operation_id = v_operation.id
          and side = 'defender'
          and status = 'en_route'
        for update
      loop
        if v_commitment.outbound_movement_order_id is not null then
          perform public.cancel_reserved_movement_order(
            v_commitment.outbound_movement_order_id,
            'El ataque llego antes que el apoyo',
            0
          );
        end if;

        update public.battle_unit_commitments
        set status = 'cancelled', updated_at = now()
        where id = v_commitment.id;
      end loop;

      select now() + make_interval(mins => conflict_block_duration_minutes)
      into v_blocked_until
      from public.campaign_settings
      where id = 'default';

      v_blocked_until := coalesce(v_blocked_until, now() + interval '14 days');

      insert into public.conflicts (
        slug,
        movement_order_id,
        battle_operation_id,
        system_id,
        attacker_faction_id,
        defender_faction_id,
        status,
        blocked_until,
        notes
      )
      values (
        'attack-' || v_order.id::text,
        v_order.id,
        v_operation.id,
        v_order.to_system_id,
        v_operation.leader_faction_id,
        v_operation.defender_faction_id,
        'pending',
        v_blocked_until,
        case
          when v_operation.mode = 'coalition' then 'Conflicto generado por ataque de coalicion.'
          else 'Conflicto generado por llegada de ataque.'
        end
      )
      on conflict (movement_order_id) where movement_order_id is not null do update
      set
        battle_operation_id = excluded.battle_operation_id,
        blocked_until = excluded.blocked_until
      returning id into v_conflict_id;

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
        v_operation.id,
        campaign_units.id,
        campaign_units.faction_id,
        'defender',
        'leader',
        v_operation.target_system_id,
        v_operation.target_system_id,
        array[v_operation.target_system_id],
        campaign_units.quantity,
        greatest(
          1,
          ceil(
            (campaign_units.points::numeric * campaign_units.quantity)
            / greatest(campaign_units.starting_quantity, 1)
          )::integer
        ),
        'in_battle'
      from public.campaign_units
      where current_system_id = v_operation.target_system_id
        and faction_id = v_operation.defender_faction_id
        and status = 'ready'
        and quantity > 0
      on conflict (operation_id, unit_id) do nothing;

      update public.systems
      set status = 'war', blocked_until = v_blocked_until, updated_at = now()
      where id = v_operation.target_system_id;

      update public.campaign_units
      set
        current_system_id = v_operation.target_system_id,
        status = 'in_war',
        updated_at = now()
      where id in (
        select unit_id
        from public.battle_unit_commitments
        where operation_id = v_operation.id
          and status in ('en_route', 'staged', 'in_battle')
      );

      update public.battle_unit_commitments
      set status = 'in_battle', updated_at = now()
      where operation_id = v_operation.id
        and status in ('en_route', 'staged');

      update public.movement_orders
      set status = 'in_battle', resolved_at = now()
      where id = v_order.id;

      update public.battle_operations
      set
        status = 'in_battle',
        conflict_id = v_conflict_id,
        roster_locked_at = now(),
        updated_at = now()
      where id = v_operation.id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_operation.leader_faction_id,
        'battle_roster_locked',
        jsonb_build_object(
          'operation_id', v_operation.id,
          'conflict_id', v_conflict_id,
          'locked_at', now()
        )
      );

      v_resolved := v_resolved + 1;
      continue;
    end if;

    if v_order.movement_type = 'attack' then
      if v_system.status <> 'controlled'
        or v_system.controller_faction_id is null
        or v_system.controller_faction_id = v_order.faction_id then
        perform public.cancel_reserved_movement_order(v_order.id, 'El objetivo ya no es enemigo', 0);
        v_resolved := v_resolved + 1;
        continue;
      end if;

      select now() + make_interval(mins => conflict_block_duration_minutes)
      into v_blocked_until
      from public.campaign_settings
      where id = 'default';

      v_blocked_until := coalesce(v_blocked_until, now() + interval '14 days');

      insert into public.conflicts (
        slug,
        movement_order_id,
        system_id,
        attacker_faction_id,
        defender_faction_id,
        status,
        blocked_until,
        notes
      )
      values (
        'attack-' || v_order.id::text,
        v_order.id,
        v_order.to_system_id,
        v_order.faction_id,
        v_system.controller_faction_id,
        'pending',
        v_blocked_until,
        'Conflicto legado generado por llegada de ataque.'
      )
      on conflict (movement_order_id) where movement_order_id is not null do update
      set blocked_until = excluded.blocked_until
      returning id into v_conflict_id;

      update public.systems
      set status = 'war', blocked_until = v_blocked_until, updated_at = now()
      where id = v_order.to_system_id;

      update public.campaign_units
      set current_system_id = v_order.to_system_id, status = 'in_war', updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );

      update public.campaign_units
      set status = 'in_war', updated_at = now()
      where current_system_id = v_order.to_system_id
        and status = 'ready'
        and quantity > 0
        and faction_id = v_system.controller_faction_id;

      update public.movement_orders
      set status = 'in_battle', resolved_at = now()
      where id = v_order.id;
    else
      if v_system.status = 'war'
        or (v_system.blocked_until is not null and v_system.blocked_until > now())
        or (
          v_system.status = 'controlled'
          and v_system.controller_faction_id is not null
          and v_system.controller_faction_id <> v_order.faction_id
        ) then
        perform public.cancel_reserved_movement_order(
          v_order.id,
          'El destino cambio a territorio bloqueado o enemigo antes de la llegada',
          v_order.uridium_cost
        );
        v_resolved := v_resolved + 1;
        continue;
      end if;

      update public.movement_orders
      set status = 'arrived', resolved_at = now()
      where id = v_order.id;

      if coalesce(v_system.allows_shared_occupation, false)
        or not coalesce(v_system.is_conquerable, true) then
        update public.systems
        set status = 'neutral', controller_faction_id = null, blocked_until = null, updated_at = now()
        where id = v_order.to_system_id;
      elsif v_system.status = 'neutral' or v_system.controller_faction_id is null then
        update public.systems
        set
          status = 'controlled',
          controller_faction_id = v_order.faction_id,
          blocked_until = null,
          updated_at = now()
        where id = v_order.to_system_id;
      end if;

      update public.campaign_units
      set current_system_id = v_order.to_system_id, status = 'ready', updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );
    end if;

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

create or replace function public.apply_battle_outcome(
  target_conflict_id uuid,
  winner_faction_id uuid,
  final_controller_faction_id uuid,
  post_battle_blocked_until timestamptz,
  survivors jsonb,
  wounds_remaining jsonb,
  actor_user_id uuid,
  actor_faction_id uuid,
  narrative_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conflict public.conflicts%rowtype;
  v_unit public.campaign_units%rowtype;
  v_commitment public.battle_unit_commitments%rowtype;
  v_survivors integer;
  v_wounds integer;
  v_retreat_system_id uuid;
begin
  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id
  for update;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  perform public.validate_battle_survivors_and_wounds(target_conflict_id, survivors, wounds_remaining);

  update public.conflicts
  set
    status = 'resolved',
    winner_faction_id = apply_battle_outcome.winner_faction_id,
    blocked_until = apply_battle_outcome.post_battle_blocked_until,
    resolved_at = now(),
    notes = coalesce(apply_battle_outcome.narrative_notes, notes)
  where id = target_conflict_id;

  update public.systems
  set
    status = case when apply_battle_outcome.final_controller_faction_id is null then 'neutral' else 'controlled' end,
    controller_faction_id = apply_battle_outcome.final_controller_faction_id,
    blocked_until = apply_battle_outcome.post_battle_blocked_until,
    updated_at = now()
  where id = v_conflict.system_id;

  for v_unit in
    select *
    from public.campaign_units
    where current_system_id = v_conflict.system_id
      and status = 'in_war'
    order by created_at, id
    for update
  loop
    v_survivors := (survivors->>v_unit.id::text)::integer;
    v_wounds := (wounds_remaining->>v_unit.id::text)::integer;

    select *
    into v_commitment
    from public.battle_unit_commitments
    where operation_id = v_conflict.battle_operation_id
      and unit_id = v_unit.id;

    if v_survivors = 0 then
      update public.campaign_units
      set
        quantity = 0,
        wounds_taken = 0,
        status = 'destroyed',
        destroyed_at = now(),
        updated_at = now()
      where id = v_unit.id;

      if v_commitment.id is not null then
        update public.battle_unit_commitments
        set status = 'destroyed', updated_at = now()
        where id = v_commitment.id;
      end if;
    elsif v_commitment.id is not null and v_commitment.role = 'supporter' then
      update public.campaign_units
      set
        quantity = v_survivors,
        wounds_taken = v_wounds,
        status = 'moving',
        updated_at = now()
      where id = v_unit.id;

      perform public.queue_battle_support_return(v_commitment.id);
    elsif apply_battle_outcome.final_controller_faction_id is null
      or v_unit.faction_id is not distinct from apply_battle_outcome.final_controller_faction_id then
      update public.campaign_units
      set
        quantity = v_survivors,
        wounds_taken = v_wounds,
        status = 'ready',
        updated_at = now()
      where id = v_unit.id;
    else
      v_retreat_system_id := public.find_retreat_system(v_unit.faction_id, v_conflict.system_id);

      if v_retreat_system_id is null then
        update public.campaign_units
        set
          quantity = v_survivors,
          wounds_taken = v_wounds,
          status = 'retreat_pending',
          updated_at = now()
        where id = v_unit.id;
      else
        update public.campaign_units
        set
          quantity = v_survivors,
          wounds_taken = v_wounds,
          current_system_id = v_retreat_system_id,
          status = 'ready',
          updated_at = now()
        where id = v_unit.id;
      end if;
    end if;
  end loop;

  if v_conflict.battle_operation_id is not null then
    update public.battle_operations
    set status = 'resolved', resolved_at = now(), updated_at = now()
    where id = v_conflict.battle_operation_id;
  end if;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    apply_battle_outcome.actor_user_id,
    apply_battle_outcome.actor_faction_id,
    'battle_outcome_applied',
    jsonb_build_object(
      'conflict_id', target_conflict_id,
      'operation_id', v_conflict.battle_operation_id,
      'winner_faction_id', apply_battle_outcome.winner_faction_id,
      'final_controller_faction_id', apply_battle_outcome.final_controller_faction_id,
      'survivors', survivors,
      'wounds_remaining', wounds_remaining
    )
  );
end;
$$;

create or replace function public.sync_movement_order_from_conflict()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.movement_order_id is not null and new.status in ('resolved', 'cancelled') then
    update public.movement_orders
    set
      status = case when new.status = 'resolved' then 'resolved' else 'cancelled' end,
      resolved_at = coalesce(new.resolved_at, now()),
      cancellation_reason = case
        when new.status = 'cancelled' then coalesce(new.notes, cancellation_reason)
        else cancellation_reason
      end
    where id = new.movement_order_id
      and movement_type = 'attack'
      and status = 'in_battle';
  end if;

  if new.battle_operation_id is not null and new.status in ('resolved', 'cancelled') then
    update public.battle_operations
    set
      status = new.status,
      resolved_at = case when new.status = 'resolved' then coalesce(new.resolved_at, now()) else resolved_at end,
      cancelled_at = case when new.status = 'cancelled' then now() else cancelled_at end,
      cancellation_reason = case when new.status = 'cancelled' then coalesce(new.notes, cancellation_reason) else cancellation_reason end,
      updated_at = now()
    where id = new.battle_operation_id;
  end if;

  return new;
end;
$$;

grant execute on function public.create_coalition_attack_draft(jsonb, uuid, uuid, uuid[]) to authenticated;
grant execute on function public.invite_battle_support(uuid, uuid, text) to authenticated;
grant execute on function public.respond_battle_support_invitation(uuid, text) to authenticated;
grant execute on function public.join_battle_operation(uuid, jsonb, uuid[]) to authenticated;
grant execute on function public.launch_coalition_attack(uuid) to authenticated;
grant execute on function public.cancel_battle_operation(uuid) to authenticated;
grant execute on function public.resolve_movement_orders() to authenticated;

revoke all on function public.reverse_uuid_array(uuid[]) from public;
revoke all on function public.queue_battle_support_return(uuid) from public;
