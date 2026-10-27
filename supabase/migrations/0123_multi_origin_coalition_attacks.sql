-- A coalition keeps one battle, but each participating faction may depart from
-- its own adjacent system. Existing operations and commitments are untouched.
alter table public.movement_orders
  add column if not exists is_primary_attack_wave boolean not null default true;

drop index if exists public.movement_orders_single_active_attack_target_idx;
create unique index movement_orders_single_active_attack_target_idx
on public.movement_orders (to_system_id)
where movement_type = 'attack'
  and status in ('pending_approval', 'moving')
  and is_primary_attack_wave;

create unique index movement_orders_operation_faction_active_attack_idx
on public.movement_orders (battle_operation_id, faction_id)
where movement_type = 'attack'
  and status in ('pending_approval', 'moving')
  and battle_operation_id is not null;

alter table public.movement_orders
  add constraint movement_orders_secondary_wave_requires_operation
  check (is_primary_attack_wave or battle_operation_id is not null);

create or replace function public.validate_secondary_attack_wave()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if new.movement_type = 'attack' and not new.is_primary_attack_wave
    and not exists (
      select 1 from public.movement_orders primary_wave
      where primary_wave.battle_operation_id = new.battle_operation_id
        and primary_wave.to_system_id = new.to_system_id
        and primary_wave.movement_type = 'attack'
        and primary_wave.is_primary_attack_wave
        and primary_wave.status in ('pending_approval', 'moving')
    ) then
    raise exception 'La oleada aliada necesita una orden principal activa';
  end if;
  return new;
end;
$$;

create trigger validate_secondary_attack_wave_trigger
before insert or update of is_primary_attack_wave, battle_operation_id, to_system_id, movement_type
on public.movement_orders for each row
execute function public.validate_secondary_attack_wave();

revoke execute on function public.validate_secondary_attack_wave() from public, anon, authenticated;

do $$
declare
  v_definition text;
  v_old text := 'v_expected_destination_id := v_operation.origin_system_id;';
begin
  select pg_get_functiondef('public.join_battle_operation(uuid,jsonb,uuid[])'::regprocedure)
  into v_definition;

  if (length(v_definition) - length(replace(v_definition, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'Unexpected join_battle_operation definition';
  end if;

  v_definition := replace(v_definition, v_old, $replacement$
    v_expected_destination_id := path_system_ids[cardinality(path_system_ids)];
    if not exists (
      select 1 from public.system_edges edge
      where not edge.is_blocked
        and ((edge.from_system_id = v_expected_destination_id and edge.to_system_id = v_operation.target_system_id)
          or (edge.to_system_id = v_expected_destination_id and edge.from_system_id = v_operation.target_system_id))
    ) then
      raise exception 'El punto de salida debe ser adyacente al objetivo';
    end if;
    if exists (
      select 1 from public.battle_unit_commitments commitment
      where commitment.operation_id = v_operation.id
        and commitment.faction_id = v_faction_id
        and commitment.side = 'attacker'
        and commitment.status not in ('cancelled', 'returned', 'destroyed')
    ) then
      raise exception 'Ya has marcado tus tropas listas para esta coalicion';
    end if;
    $replacement$);
  execute v_definition;
end $$;

create or replace function public.assert_battle_unit_commitment_allowed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_operation public.battle_operations%rowtype;
begin
  select * into v_operation from public.battle_operations where id = new.operation_id;
  if not found then
    return new;
  end if;

  if new.side = 'attacker' and new.role = 'supporter' and v_operation.status = 'assembling' then
    if tg_op = 'UPDATE' and old.status = 'staged' and new.status = 'en_route'
      and new.outbound_movement_order_id is not null then
      return new;
    end if;

    if not exists (
      select 1 from public.battle_operation_members member
      where member.operation_id = new.operation_id
        and member.faction_id = new.faction_id
        and member.side = 'attacker'
        and member.role = 'supporter'
        and member.invitation_status = 'accepted'
    ) then
      raise exception 'Primero debes aceptar la invitacion de coalicion';
    end if;

    if new.status <> 'staged' or new.outbound_movement_order_id is not null
      or cardinality(new.outbound_path_system_ids) < 1
      or new.outbound_path_system_ids[cardinality(new.outbound_path_system_ids)] is distinct from new.staging_system_id
      or not exists (
        select 1 from public.system_edges edge
        where not edge.is_blocked
          and ((edge.from_system_id = new.staging_system_id and edge.to_system_id = v_operation.target_system_id)
            or (edge.to_system_id = new.staging_system_id and edge.from_system_id = v_operation.target_system_id))
      ) then
      raise exception 'Las tropas atacantes deben estar listas en un sistema adyacente al objetivo';
    end if;
  end if;

  return new;
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
  v_target public.systems%rowtype;
  v_origin public.systems%rowtype;
  v_group record;
  v_order_id uuid;
  v_leader_order_id uuid;
  v_duration_seconds integer;
  v_launch_at timestamptz := now();
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select * into v_operation from public.battle_operations
  where id = launch_coalition_attack.operation_id for update;
  if not found or v_operation.mode <> 'coalition' or v_operation.status <> 'assembling' then
    raise exception 'La coalicion no esta disponible para lanzar';
  end if;
  if not public.is_admin() and v_faction_id <> v_operation.leader_faction_id then
    raise exception 'Solo el comandante atacante puede lanzar la coalicion';
  end if;
  if not exists (
    select 1 from public.battle_unit_commitments commitment
    where commitment.operation_id = v_operation.id and commitment.side = 'attacker'
  ) then
    raise exception 'La coalicion no tiene unidades';
  end if;
  if exists (
    select 1 from public.battle_unit_commitments commitment
    where commitment.operation_id = v_operation.id and commitment.side = 'attacker'
      and commitment.status <> 'staged'
  ) then
    raise exception 'Aun hay tropas aliadas viajando al punto de salida';
  end if;
  if exists (
    select 1 from public.battle_operation_members member
    where member.operation_id = v_operation.id and member.side = 'attacker'
      and member.role = 'supporter' and member.invitation_status = 'invited'
  ) then
    raise exception 'Aun hay invitaciones pendientes';
  end if;
  if exists (
    select 1 from public.battle_operation_members member
    where member.operation_id = v_operation.id and member.side = 'attacker'
      and member.role = 'supporter' and member.invitation_status = 'accepted'
      and not exists (
        select 1 from public.battle_unit_commitments commitment
        where commitment.operation_id = member.operation_id
          and commitment.faction_id = member.faction_id
          and commitment.side = 'attacker' and commitment.status = 'staged'
      )
  ) then
    raise exception 'Faltan aliados por marcar tropas listas';
  end if;

  select * into v_target from public.systems
  where id = v_operation.target_system_id for update;
  if v_target.status <> 'controlled'
    or v_target.controller_faction_id <> v_operation.defender_faction_id
    or (v_target.blocked_until is not null and v_target.blocked_until > v_launch_at) then
    raise exception 'El objetivo ya no esta disponible';
  end if;
  perform public.validate_attack_limits(v_operation.leader_faction_id, v_operation.defender_faction_id);
  perform public.validate_system_battle_side_points(
    v_operation.target_system_id, v_operation.leader_faction_id, v_operation.defender_faction_id,
    coalesce((select sum(points_at_commitment) from public.battle_unit_commitments commitment
      where commitment.operation_id = v_operation.id and commitment.side = 'attacker'
        and commitment.status not in ('returned', 'destroyed', 'cancelled')), 0)::integer,
    'bando atacante'
  );

  select attack_duration_seconds into v_duration_seconds
  from public.campaign_settings where id = 'default';
  v_duration_seconds := coalesce(v_duration_seconds, 604800);

  for v_group in
    select commitment.faction_id, commitment.staging_system_id
    from public.battle_unit_commitments commitment
    where commitment.operation_id = v_operation.id and commitment.side = 'attacker'
    group by commitment.faction_id, commitment.staging_system_id
    order by (commitment.faction_id <> v_operation.leader_faction_id), commitment.faction_id
  loop
    select * into v_origin from public.systems
    where id = v_group.staging_system_id for update;
    if not public.can_faction_depart_from_system(v_group.staging_system_id, v_group.faction_id, true)
      or not exists (
        select 1 from public.system_edges edge
        where not edge.is_blocked
          and ((edge.from_system_id = v_group.staging_system_id and edge.to_system_id = v_target.id)
            or (edge.to_system_id = v_group.staging_system_id and edge.from_system_id = v_target.id))
      ) then
      raise exception 'Un punto de salida ya no esta disponible';
    end if;

    if exists (
      select 1 from public.battle_unit_commitments commitment
      join public.campaign_units unit on unit.id = commitment.unit_id
      where commitment.operation_id = v_operation.id and commitment.side = 'attacker'
        and commitment.faction_id = v_group.faction_id
        and commitment.staging_system_id = v_group.staging_system_id
        and (unit.status <> 'moving' or unit.current_system_id <> v_group.staging_system_id or unit.quantity <= 0)
    ) then
      raise exception 'Una unidad comprometida ya no esta disponible';
    end if;

    insert into public.movement_orders (
      faction_id, defender_faction_id, from_system_id, to_system_id,
      movement_type, movement_purpose, battle_operation_id, is_primary_attack_wave, uridium_cost,
      started_at, departure_at, arrival_at, status, path_system_ids,
      segment_count, duration_seconds
    ) values (
      v_group.faction_id, v_operation.defender_faction_id, v_group.staging_system_id, v_target.id,
      'attack', 'attack', v_operation.id, v_group.faction_id = v_operation.leader_faction_id, 0,
      v_launch_at, v_launch_at, v_launch_at + make_interval(secs => v_duration_seconds),
      'moving', array[v_group.staging_system_id, v_target.id], 1, v_duration_seconds
    ) returning id into v_order_id;

    insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
    select v_order_id, unit.id, unit.quantity
    from public.battle_unit_commitments commitment
    join public.campaign_units unit on unit.id = commitment.unit_id
    where commitment.operation_id = v_operation.id and commitment.side = 'attacker'
      and commitment.faction_id = v_group.faction_id
      and commitment.staging_system_id = v_group.staging_system_id;

    update public.battle_unit_commitments commitment
    set outbound_movement_order_id = v_order_id,
      outbound_path_system_ids = array[v_group.staging_system_id, v_target.id],
      status = 'en_route', updated_at = v_launch_at
    where commitment.operation_id = v_operation.id and commitment.side = 'attacker'
      and commitment.faction_id = v_group.faction_id
      and commitment.staging_system_id = v_group.staging_system_id;

    if v_group.faction_id = v_operation.leader_faction_id then
      v_leader_order_id := v_order_id;
    end if;
  end loop;

  if v_leader_order_id is null then
    raise exception 'La fuerza del comandante no esta lista';
  end if;
  update public.battle_operations
  set status = 'moving', attack_movement_order_id = v_leader_order_id,
    attack_arrival_at = v_launch_at + make_interval(secs => v_duration_seconds),
    launched_at = v_launch_at, updated_at = v_launch_at
  where id = v_operation.id;

  insert into public.battle_operation_members (
    operation_id, faction_id, side, role, invitation_status,
    invited_by_faction_id, responded_at
  ) values (
    v_operation.id, v_operation.defender_faction_id, 'defender', 'commander',
    'accepted', v_operation.leader_faction_id, v_launch_at
  ) on conflict on constraint battle_operation_members_operation_id_faction_id_key do nothing;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (v_user_id, v_operation.leader_faction_id, 'battle_operation_launched',
    jsonb_build_object('operation_id', v_operation.id, 'movement_order_id', v_leader_order_id,
      'mode', 'coalition', 'arrival_at', v_launch_at + make_interval(secs => v_duration_seconds)));

  return v_leader_order_id;
end;
$$;

-- All attack waves lock the same roster and resolve into one conflict.
do $$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('public.resolve_movement_orders_core_0107()'::regprocedure)
  into v_definition;

  v_old := $old$  loop
    select *
    into v_system
    from public.systems
    where id = v_order.to_system_id
    for update;$old$;
  v_new := $new$  loop
    if not exists (
      select 1 from public.movement_orders current_order
      where current_order.id = v_order.id and current_order.status = 'moving'
    ) then
      continue;
    end if;

    select *
    into v_system
    from public.systems
    where id = v_order.to_system_id
    for update;$new$;
  if position(v_old in v_definition) = 0 then
    raise exception 'Unexpected movement resolver loop';
  end if;
  v_definition := replace(v_definition, v_old, v_new);

  v_old := $old$perform public.cancel_reserved_movement_order(v_order.id, 'El objetivo ya no es enemigo', 0);

        update public.campaign_units units$old$;
  v_new := $new$perform public.cancel_reserved_movement_order(v_order.id, 'El objetivo ya no es enemigo', 0);
        perform public.cancel_reserved_movement_order(sibling.id, 'El objetivo ya no es enemigo', 0)
        from public.movement_orders sibling
        where sibling.battle_operation_id = v_order.battle_operation_id
          and sibling.movement_type = 'attack'
          and sibling.status = 'moving'
          and sibling.id <> v_order.id;

        update public.campaign_units units$new$;
  if (length(v_definition) - length(replace(v_definition, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'Unexpected coalition cancellation branch';
  end if;
  v_definition := replace(v_definition, v_old, v_new);

  v_old := $old$update public.movement_orders
      set status = 'in_battle', resolved_at = now()
      where id = v_order.id;

      update public.battle_operations$old$;
  v_new := $new$update public.movement_orders
      set status = 'in_battle', resolved_at = now()
      where battle_operation_id = v_operation.id
        and movement_type = 'attack'
        and status = 'moving';

      update public.battle_operations$new$;
  if position(v_old in v_definition) = 0 then
    raise exception 'Unexpected coalition arrival branch';
  end if;
  execute replace(v_definition, v_old, v_new);
end $$;

-- Witnessing any coalition departure reveals the force. A defender with no
-- origin witness continues to receive only redacted incoming routes.
create or replace function public.can_view_attack_force(target_operation_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_admin() or exists (
    select 1 from public.battle_operations operation
    where operation.id = target_operation_id
      and (
        exists (
          select 1 from public.movement_orders movement
          where movement.battle_operation_id = operation.id
            and movement.movement_type = 'attack'
            and public.was_attack_origin_witness(movement.id)
        )
        or exists (
          select 1 from public.battle_operation_members member
          where member.operation_id = operation.id
            and member.side = 'attacker'
            and member.invitation_status = 'accepted'
            and public.is_faction_member(member.faction_id)
        )
        or (operation.status in ('in_battle', 'resolved')
          and public.can_select_battle_operation(operation.id))
      )
  );
$$;

create or replace function public.sync_movement_order_from_conflict()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status in ('resolved', 'cancelled') then
    update public.movement_orders
    set status = case when new.status = 'resolved' then 'resolved' else 'cancelled' end,
      resolved_at = coalesce(new.resolved_at, now()),
      cancellation_reason = case when new.status = 'cancelled'
        then coalesce(new.notes, cancellation_reason) else cancellation_reason end
    where movement_type = 'attack' and status = 'in_battle'
      and (id = new.movement_order_id
        or (new.battle_operation_id is not null and battle_operation_id = new.battle_operation_id));
  end if;

  if new.battle_operation_id is not null and new.status in ('resolved', 'cancelled') then
    update public.battle_operations
    set status = new.status,
      resolved_at = case when new.status = 'resolved' then coalesce(new.resolved_at, now()) else resolved_at end,
      cancelled_at = case when new.status = 'cancelled' then now() else cancelled_at end,
      cancellation_reason = case when new.status = 'cancelled' then coalesce(new.notes, cancellation_reason) else cancellation_reason end,
      updated_at = now()
    where id = new.battle_operation_id;
  end if;

  return new;
end;
$$;

revoke execute on function public.launch_coalition_attack(uuid) from public, anon;
grant execute on function public.launch_coalition_attack(uuid) to authenticated;
notify pgrst, 'reload schema';
