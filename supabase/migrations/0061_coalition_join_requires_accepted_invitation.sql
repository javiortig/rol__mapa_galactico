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
  v_edge_cost numeric := 0;
  v_route_cost numeric := 0;
  v_duration_seconds integer;
  v_total_cost numeric := 0;
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

  if v_member.invitation_status <> 'accepted' then
    raise exception 'Debes aceptar la invitacion antes de marcar tropas listas';
  end if;

  if v_member.side = 'attacker' then
    if v_operation.status <> 'assembling' then
      raise exception 'La coalicion atacante ya ha salido';
    end if;
    v_expected_destination_id := v_operation.origin_system_id;
  else
    raise exception 'El apoyo defensivo debe moverse al sistema objetivo antes de la llegada del ataque';
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

  if not public.can_faction_depart_from_system(v_origin_system_id, v_faction_id, true) then
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

      v_route_cost := v_route_cost + v_edge_cost;
    end loop;
  end if;

  v_total_cost := v_route_cost * cardinality(v_selected_unit_ids);

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
      'path_system_ids', to_jsonb(path_system_ids),
      'route_uridium_cost', v_route_cost,
      'moved_unit_count', cardinality(v_selected_unit_ids),
      'uridium_cost', v_total_cost
    )
  );

  return coalesce(v_order_id, v_operation.id);
exception
  when no_data_found then
    raise exception 'La ruta contiene un tramo no valido';
end;
$$;

revoke execute on function public.join_battle_operation(uuid, jsonb, uuid[]) from public;
grant execute on function public.join_battle_operation(uuid, jsonb, uuid[]) to authenticated;
