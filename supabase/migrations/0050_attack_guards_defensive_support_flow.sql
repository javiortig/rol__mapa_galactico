create or replace function public.assert_battle_operation_attack_allowed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status not in ('assembling', 'moving', 'in_battle') then
    return new;
  end if;

  if exists (
    select 1
    from public.battle_operations active_operation
    where active_operation.id <> new.id
      and active_operation.leader_faction_id = new.leader_faction_id
      and active_operation.target_system_id = new.target_system_id
      and active_operation.status in ('assembling', 'moving', 'in_battle')
  ) then
    raise exception 'Ya tienes un ataque activo contra este sistema';
  end if;

  if exists (
    select 1
    from public.battle_operations active_operation
    where active_operation.id <> new.id
      and active_operation.target_system_id = new.target_system_id
      and active_operation.status in ('assembling', 'moving', 'in_battle')
  ) then
    raise exception 'Este sistema ya tiene una operacion activa';
  end if;

  if exists (
    select 1
    from public.battle_operations incoming_operation
    where incoming_operation.id <> new.id
      and incoming_operation.status = 'moving'
      and incoming_operation.leader_faction_id = new.defender_faction_id
      and incoming_operation.defender_faction_id = new.leader_faction_id
      and incoming_operation.origin_system_id = new.target_system_id
      and incoming_operation.target_system_id = new.origin_system_id
  ) then
    raise exception 'No puedes contraatacar al origen mientras el ataque entrante sigue en curso';
  end if;

  if tg_op = 'UPDATE'
    and old.status = 'assembling'
    and new.status = 'moving'
    and new.mode = 'coalition' then
    if exists (
      select 1
      from public.battle_operation_members member
      where member.operation_id = new.id
        and member.side = 'attacker'
        and member.role = 'supporter'
        and member.invitation_status = 'invited'
    ) then
      raise exception 'Aun hay invitaciones atacantes pendientes';
    end if;

    if exists (
      select 1
      from public.battle_operation_members member
      where member.operation_id = new.id
        and member.side = 'attacker'
        and member.role = 'supporter'
        and member.invitation_status = 'accepted'
        and not exists (
          select 1
          from public.battle_unit_commitments commitment
          where commitment.operation_id = new.id
            and commitment.faction_id = member.faction_id
            and commitment.side = 'attacker'
            and commitment.role = 'supporter'
            and commitment.status in ('staged', 'en_route', 'in_battle')
        )
    ) then
      raise exception 'Hay aliados atacantes aceptados sin tropas listas';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists battle_operations_attack_guards on public.battle_operations;
create trigger battle_operations_attack_guards
before insert or update of status, leader_faction_id, defender_faction_id, origin_system_id, target_system_id
on public.battle_operations
for each row
execute function public.assert_battle_operation_attack_allowed();

create or replace function public.has_active_battle_support_staging_access(
  moving_faction_id uuid,
  destination_system_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.battle_operations operation
    join public.battle_operation_members member
      on member.operation_id = operation.id
    where operation.status = 'moving'
      and operation.target_system_id = destination_system_id
      and member.faction_id = moving_faction_id
      and member.side = 'defender'
      and member.role = 'supporter'
      and member.invitation_status = 'accepted'
  )
  or exists (
    select 1
    from public.battle_operations operation
    join public.battle_operation_members member
      on member.operation_id = operation.id
    where operation.status = 'assembling'
      and operation.origin_system_id = destination_system_id
      and member.faction_id = moving_faction_id
      and member.side = 'attacker'
      and member.role = 'supporter'
      and member.invitation_status = 'accepted'
  );
$$;

create or replace function public.has_active_defense_support_access(
  moving_faction_id uuid,
  destination_system_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_active_battle_support_staging_access(moving_faction_id, destination_system_id);
$$;

create or replace function public.auto_accept_battle_support_passage()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_destination public.systems%rowtype;
begin
  select *
  into v_order
  from public.movement_orders
  where id = new.movement_order_id
  for update;

  if not found
    or v_order.status <> 'pending_approval'
    or v_order.movement_type <> 'move'
    or v_order.to_system_id <> any(new.traversed_system_ids) then
    return new;
  end if;

  select *
  into v_destination
  from public.systems
  where id = v_order.to_system_id;

  if not found
    or v_destination.controller_faction_id is distinct from new.responder_faction_id
    or not public.has_active_battle_support_staging_access(v_order.faction_id, v_order.to_system_id) then
    return new;
  end if;

  update public.movement_passage_requests
  set
    status = 'accepted',
    response_reason = coalesce(response_reason, 'Apoyo de batalla autorizado'),
    responded_at = coalesce(responded_at, now())
  where id = new.id
    and status = 'pending';

  insert into public.campaign_logs (faction_id, action_type, payload)
  values (
    v_order.faction_id,
    'battle_support_passage_auto_accepted',
    jsonb_build_object(
      'movement_order_id', v_order.id,
      'passage_request_id', new.id,
      'destination_system_id', v_order.to_system_id,
      'responder_faction_id', new.responder_faction_id
    )
  );

  if not exists (
    select 1
    from public.movement_passage_requests
    where movement_order_id = v_order.id
      and status = 'pending'
  ) then
    perform public.start_approved_movement_order(v_order.id);
  end if;

  return new;
end;
$$;

drop trigger if exists movement_passage_auto_accept_defense_support on public.movement_passage_requests;
drop trigger if exists movement_passage_auto_accept_battle_support on public.movement_passage_requests;
drop function if exists public.auto_accept_defense_support_passage();
create constraint trigger movement_passage_auto_accept_battle_support
after insert on public.movement_passage_requests
deferrable initially deferred
for each row
execute function public.auto_accept_battle_support_passage();

create or replace function public.assert_battle_unit_commitment_allowed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_operation public.battle_operations%rowtype;
begin
  select *
  into v_operation
  from public.battle_operations
  where id = new.operation_id;

  if not found then
    return new;
  end if;

  if new.side = 'attacker'
    and new.role = 'supporter'
    and v_operation.status = 'assembling' then
    if tg_op = 'UPDATE'
      and old.status = 'staged'
      and new.status = 'en_route'
      and new.outbound_movement_order_id is not null then
      return new;
    end if;

    if not exists (
      select 1
      from public.battle_operation_members member
      where member.operation_id = new.operation_id
        and member.faction_id = new.faction_id
        and member.side = 'attacker'
        and member.role = 'supporter'
        and member.invitation_status = 'accepted'
    ) then
      raise exception 'Primero debes aceptar la invitacion de coalicion';
    end if;

    if new.staging_system_id is distinct from v_operation.origin_system_id
      or new.status <> 'staged'
      or new.outbound_movement_order_id is not null
      or cardinality(new.outbound_path_system_ids) < 1
      or new.outbound_path_system_ids[cardinality(new.outbound_path_system_ids)] is distinct from v_operation.origin_system_id then
      raise exception 'Las tropas atacantes deben marcarse listas desde el sistema de salida';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists battle_unit_commitments_allowed on public.battle_unit_commitments;
create trigger battle_unit_commitments_allowed
before insert or update of side, role, faction_id, staging_system_id, outbound_movement_order_id, outbound_path_system_ids, status
on public.battle_unit_commitments
for each row
execute function public.assert_battle_unit_commitment_allowed();

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
  v_selection record;
  v_unit public.campaign_units%rowtype;
  v_unit_id uuid;
  v_selected_unit_ids uuid[] := '{}';
  v_last_path uuid[];
  v_home_system_id uuid;
begin
  if v_user_id is null or v_faction_id is null then
    raise exception 'Usuario sin faccion activa';
  end if;

  if unit_selections is null or jsonb_typeof(unit_selections) <> 'array' or jsonb_array_length(unit_selections) = 0 then
    raise exception 'Selecciona al menos una unidad';
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

  if not found then
    raise exception 'No tienes una invitacion activa';
  end if;

  if v_member.side = 'defender' then
    raise exception 'El apoyo defensivo se confirma moviendo tropas al sistema objetivo antes de la llegada';
  end if;

  if v_member.side <> 'attacker' then
    raise exception 'Bando de apoyo no valido';
  end if;

  if v_operation.status <> 'assembling' then
    raise exception 'La coalicion atacante ya ha salido';
  end if;

  if v_member.invitation_status <> 'accepted' then
    raise exception 'Primero debes aceptar la invitacion de coalicion';
  end if;

  if path_system_ids is null
    or cardinality(path_system_ids) <> 1
    or path_system_ids[1] is distinct from v_operation.origin_system_id then
    raise exception 'Marca listo desde el sistema de salida de la coalicion';
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
      or v_unit.current_system_id <> v_operation.origin_system_id
      or v_unit.quantity <= 0 then
      raise exception 'Unidad no disponible en el sistema de salida';
    end if;

    if coalesce(v_selection.quantity, v_unit.quantity) <> v_unit.quantity then
      raise exception 'Las unidades no se pueden dividir';
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

  foreach v_unit_id in array v_selected_unit_ids
  loop
    select *
    into v_unit
    from public.campaign_units
    where id = v_unit_id
    for update;

    select movement_orders.path_system_ids
    into v_last_path
    from public.movement_order_units
    join public.movement_orders
      on movement_orders.id = movement_order_units.movement_order_id
    where movement_order_units.unit_id = v_unit.id
      and movement_orders.faction_id = v_unit.faction_id
      and movement_orders.to_system_id = v_operation.origin_system_id
      and movement_orders.status = 'arrived'
      and movement_orders.movement_type = 'move'
    order by coalesce(movement_orders.resolved_at, movement_orders.arrival_at, movement_orders.created_at) desc
    limit 1;

    v_home_system_id := coalesce(
      case
        when v_last_path is not null and cardinality(v_last_path) >= 2 then v_last_path[1]
        else null
      end,
      public.find_nearest_allied_safe_system(v_unit.faction_id, v_operation.origin_system_id),
      v_operation.origin_system_id
    );

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
      v_operation.id,
      v_unit.id,
      v_unit.faction_id,
      'attacker',
      'supporter',
      v_home_system_id,
      v_operation.origin_system_id,
      case
        when v_last_path is not null then v_last_path
        when v_home_system_id = v_operation.origin_system_id then array[v_operation.origin_system_id]
        else array[v_home_system_id, v_operation.origin_system_id]
      end,
      v_unit.quantity,
      greatest(1, ceil((v_unit.points::numeric * v_unit.quantity) / greatest(v_unit.starting_quantity, 1))::integer),
      'staged'
    );
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'battle_support_ready',
    jsonb_build_object(
      'operation_id', v_operation.id,
      'side', 'attacker',
      'unit_ids', to_jsonb(v_selected_unit_ids)
    )
  );

  return v_operation.id;
end;
$$;

create or replace function public.capture_arrived_defense_support_units()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
  join public.battle_operation_members member
    on member.operation_id = new.battle_operation_id
    and member.faction_id = units.faction_id
    and member.side = 'defender'
    and member.role = 'supporter'
    and member.invitation_status = 'accepted'
  left join lateral (
    select movement_orders.path_system_ids
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
  on conflict (operation_id, unit_id) do nothing;

  return new;
end;
$$;

drop trigger if exists conflicts_capture_arrived_defense_support on public.conflicts;
create trigger conflicts_capture_arrived_defense_support
after insert on public.conflicts
for each row
execute function public.capture_arrived_defense_support_units();

create or replace function public.cancel_reserved_movement_order(target_order_id uuid, reason text, refund_uridium integer default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_refund integer;
  v_redirect_system_id uuid;
  v_redirect_late_arrival boolean := false;
begin
  select *
  into v_order
  from public.movement_orders
  where id = target_order_id
  for update;

  if not found or v_order.status in ('cancelled', 'resolved', 'arrived') then
    return;
  end if;

  v_refund := coalesce(refund_uridium, v_order.uridium_cost);
  v_redirect_late_arrival := reason in (
    'La ventana de apoyo ya esta cerrada',
    'El ataque llego antes que el apoyo',
    'El destino cambio a territorio bloqueado antes de la llegada'
  );

  if v_refund > 0 then
    update public.faction_resources
    set
      uridium = uridium + v_refund,
      updated_at = now()
    where faction_id = v_order.faction_id;
  end if;

  if v_redirect_late_arrival then
    v_redirect_system_id := public.find_nearest_allied_safe_system(v_order.faction_id, v_order.to_system_id);

    if v_redirect_system_id is null then
      update public.campaign_units
      set
        status = 'retreat_pending',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      )
        and status = 'moving';
    else
      update public.campaign_units
      set
        current_system_id = v_redirect_system_id,
        status = 'ready',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      )
        and status = 'moving';
    end if;
  else
    update public.campaign_units
    set
      current_system_id = v_order.from_system_id,
      status = 'ready',
      updated_at = now()
    where id in (
      select unit_id
      from public.movement_order_units
      where movement_order_id = v_order.id
    )
      and status = 'moving';
  end if;

  update public.movement_passage_requests
  set
    status = case when status = 'pending' then 'rejected' else status end,
    response_reason = coalesce(response_reason, reason),
    responded_at = coalesce(responded_at, now())
  where movement_order_id = v_order.id;

  update public.movement_orders
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancellation_reason = reason
  where id = v_order.id;

  insert into public.campaign_logs (faction_id, action_type, payload)
  values (
    v_order.faction_id,
    'movement_cancelled',
    jsonb_build_object(
      'movement_order_id', v_order.id,
      'reason', reason,
      'refund_uridium', v_refund,
      'redirect_system_id', v_redirect_system_id
    )
  );
end;
$$;

revoke execute on function public.assert_battle_operation_attack_allowed() from public;
revoke execute on function public.has_active_battle_support_staging_access(uuid, uuid) from public;
revoke execute on function public.has_active_defense_support_access(uuid, uuid) from public;
revoke execute on function public.auto_accept_battle_support_passage() from public;
revoke execute on function public.assert_battle_unit_commitment_allowed() from public;
revoke execute on function public.capture_arrived_defense_support_units() from public;
revoke execute on function public.cancel_reserved_movement_order(uuid, text, integer) from public;

grant execute on function public.has_active_battle_support_staging_access(uuid, uuid) to authenticated;
grant execute on function public.has_active_defense_support_access(uuid, uuid) to authenticated;
