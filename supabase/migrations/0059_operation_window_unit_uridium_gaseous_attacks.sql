create or replace function public.attack_operation_window_days()
returns integer
language sql
immutable
as $$
  select 33;
$$;

create or replace function public.attack_month_start()
returns timestamptz
language sql
stable
as $$
  with params as (
    select
      timestamptz '2026-01-01 00:00:00+00' as anchor_at,
      (public.attack_operation_window_days() * 24 * 60 * 60)::double precision as window_seconds
  )
  select
    anchor_at
    + (
      floor(extract(epoch from (now() - anchor_at)) / window_seconds)::bigint
      * make_interval(days => public.attack_operation_window_days())
    )
  from params;
$$;

create or replace function public.attack_operation_window_end()
returns timestamptz
language sql
stable
as $$
  select public.attack_month_start() + make_interval(days => public.attack_operation_window_days());
$$;

create or replace function public.can_faction_depart_from_system(
  target_system_id uuid,
  target_faction_id uuid,
  allow_foreign_presence boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.systems
    where systems.id = target_system_id
      and systems.status <> 'war'
      and coalesce(systems.is_temporary_mission, false) = false
      and (systems.blocked_until is null or systems.blocked_until <= now())
      and (
        (
          systems.status = 'controlled'
          and systems.controller_faction_id = target_faction_id
        )
        or coalesce(systems.system_kind, 'standard') = 'gaseous'
        or coalesce(systems.allows_shared_occupation, false)
        or not coalesce(systems.is_conquerable, true)
        or allow_foreign_presence
      )
  );
$$;

create or replace function public.get_battle_limit_summary(target_faction_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid := coalesce(target_faction_id, public.current_player_faction_id());
  v_month_start timestamptz := public.attack_month_start();
  v_month_end timestamptz := public.attack_operation_window_end();
  v_started integer := 0;
  v_received integer := 0;
  v_total integer := 0;
  v_active integer := 0;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if v_faction_id is null then
    raise exception 'No hay faccion de jugador disponible';
  end if;

  if not public.is_admin() and not public.is_faction_member(v_faction_id) then
    raise exception 'No puedes consultar los limites de esta faccion';
  end if;

  select
    count(*) filter (where source.role = 'started'),
    count(*) filter (where source.role = 'received'),
    count(*)
  into v_started, v_received, v_total
  from (
    select 'started'::text as role
    from public.movement_orders
    where movement_type = 'attack'
      and status <> 'cancelled'
      and faction_id = v_faction_id
      and created_at >= v_month_start
      and created_at < v_month_end
    union all
    select 'received'::text as role
    from public.movement_orders
    where movement_type = 'attack'
      and status <> 'cancelled'
      and defender_faction_id = v_faction_id
      and created_at >= v_month_start
      and created_at < v_month_end
    union all
    select 'started'::text as role
    from public.conflicts
    where movement_order_id is null
      and status <> 'cancelled'
      and attacker_faction_id = v_faction_id
      and created_at >= v_month_start
      and created_at < v_month_end
    union all
    select 'received'::text as role
    from public.conflicts
    where movement_order_id is null
      and status <> 'cancelled'
      and defender_faction_id = v_faction_id
      and created_at >= v_month_start
      and created_at < v_month_end
  ) as source;

  select count(*)
  into v_active
  from (
    select id
    from public.movement_orders
    where movement_type = 'attack'
      and status = any(public.attack_active_statuses())
      and (faction_id = v_faction_id or defender_faction_id = v_faction_id)
    union all
    select id
    from public.conflicts
    where movement_order_id is null
      and status = 'pending'
      and (attacker_faction_id = v_faction_id or defender_faction_id = v_faction_id)
  ) as active_items;

  return jsonb_build_object(
    'faction_id', v_faction_id,
    'month_start', v_month_start,
    'month_end', v_month_end,
    'started_attacks', coalesce(v_started, 0),
    'received_attacks', coalesce(v_received, 0),
    'total_participations', coalesce(v_total, 0),
    'active_battles', coalesce(v_active, 0),
    'max_started_attacks', 2,
    'max_received_attacks', 2,
    'max_total_participations', 3,
    'max_active_battles', 3
  );
end;
$$;

create or replace function public.validate_attack_limits(target_attacker_faction_id uuid, target_defender_faction_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month_start timestamptz := public.attack_month_start();
  v_month_end timestamptz := public.attack_operation_window_end();
  v_attacker_started integer := 0;
  v_attacker_received integer := 0;
  v_attacker_total integer := 0;
  v_defender_started integer := 0;
  v_defender_received integer := 0;
  v_defender_total integer := 0;
  v_attacker_active integer := 0;
  v_defender_active integer := 0;
  v_first_lock bigint;
  v_second_lock bigint;
begin
  if target_attacker_faction_id is null or target_defender_faction_id is null then
    raise exception 'Atacante y defensor son obligatorios';
  end if;

  if target_attacker_faction_id = target_defender_faction_id then
    raise exception 'No puedes atacar a tu propia faccion';
  end if;

  v_first_lock := least(
    hashtextextended(target_attacker_faction_id::text, 40),
    hashtextextended(target_defender_faction_id::text, 40)
  );
  v_second_lock := greatest(
    hashtextextended(target_attacker_faction_id::text, 40),
    hashtextextended(target_defender_faction_id::text, 40)
  );
  perform pg_advisory_xact_lock(v_first_lock);
  if v_second_lock <> v_first_lock then
    perform pg_advisory_xact_lock(v_second_lock);
  end if;

  select
    count(*) filter (where source.faction_id = target_attacker_faction_id and source.role = 'started'),
    count(*) filter (where source.faction_id = target_attacker_faction_id and source.role = 'received'),
    count(*) filter (where source.faction_id = target_attacker_faction_id),
    count(*) filter (where source.faction_id = target_defender_faction_id and source.role = 'started'),
    count(*) filter (where source.faction_id = target_defender_faction_id and source.role = 'received'),
    count(*) filter (where source.faction_id = target_defender_faction_id)
  into
    v_attacker_started,
    v_attacker_received,
    v_attacker_total,
    v_defender_started,
    v_defender_received,
    v_defender_total
  from (
    select faction_id, 'started'::text as role
    from public.movement_orders
    where movement_type = 'attack'
      and status <> 'cancelled'
      and created_at >= v_month_start
      and created_at < v_month_end
    union all
    select defender_faction_id as faction_id, 'received'::text as role
    from public.movement_orders
    where movement_type = 'attack'
      and status <> 'cancelled'
      and defender_faction_id is not null
      and created_at >= v_month_start
      and created_at < v_month_end
    union all
    select attacker_faction_id as faction_id, 'started'::text as role
    from public.conflicts
    where movement_order_id is null
      and status <> 'cancelled'
      and created_at >= v_month_start
      and created_at < v_month_end
    union all
    select defender_faction_id as faction_id, 'received'::text as role
    from public.conflicts
    where movement_order_id is null
      and status <> 'cancelled'
      and defender_faction_id is not null
      and created_at >= v_month_start
      and created_at < v_month_end
  ) as source
  where source.faction_id in (target_attacker_faction_id, target_defender_faction_id);

  select
    count(*) filter (where active_items.faction_id = target_attacker_faction_id),
    count(*) filter (where active_items.faction_id = target_defender_faction_id)
  into v_attacker_active, v_defender_active
  from (
    select faction_id
    from public.movement_orders
    where movement_type = 'attack'
      and status = any(public.attack_active_statuses())
    union all
    select defender_faction_id as faction_id
    from public.movement_orders
    where movement_type = 'attack'
      and status = any(public.attack_active_statuses())
      and defender_faction_id is not null
    union all
    select attacker_faction_id as faction_id
    from public.conflicts
    where movement_order_id is null
      and status = 'pending'
    union all
    select defender_faction_id as faction_id
    from public.conflicts
    where movement_order_id is null
      and status = 'pending'
      and defender_faction_id is not null
  ) as active_items
  where active_items.faction_id in (target_attacker_faction_id, target_defender_faction_id);

  if coalesce(v_attacker_started, 0) >= 2 then
    raise exception 'Limite de ataques iniciados alcanzado';
  end if;

  if coalesce(v_defender_received, 0) >= 2 then
    raise exception 'El defensor ya ha recibido dos ataques en esta ventana';
  end if;

  if coalesce(v_attacker_total, 0) >= 3 then
    raise exception 'Maximo de participaciones alcanzado para el atacante';
  end if;

  if coalesce(v_defender_total, 0) >= 3 then
    raise exception 'Maximo de participaciones alcanzado para el defensor';
  end if;

  if coalesce(v_attacker_active, 0) >= 3 then
    raise exception 'Maximo de batallas activas alcanzado para el atacante';
  end if;

  if coalesce(v_defender_active, 0) >= 3 then
    raise exception 'Maximo de batallas activas alcanzado para el defensor';
  end if;
end;
$$;

create or replace function public.create_movement_order(unit_selections jsonb, path_system_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_faction_id uuid;
  v_origin_system_id uuid;
  v_destination_system_id uuid;
  v_path_length integer;
  v_index integer;
  v_from uuid;
  v_to uuid;
  v_edge public.system_edges%rowtype;
  v_system public.systems%rowtype;
  v_route_cost integer := 0;
  v_total_cost integer := 0;
  v_unit_count integer := 0;
  v_resources public.faction_resources%rowtype;
  v_duration_seconds integer;
  v_order_id uuid;
  v_selection record;
  v_unit public.campaign_units%rowtype;
  v_selected_unit_ids uuid[] := '{}';
  v_needs_approval boolean := false;
  v_passage record;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if unit_selections is null or jsonb_typeof(unit_selections) <> 'array' or jsonb_array_length(unit_selections) = 0 then
    raise exception 'Selecciona al menos una unidad';
  end if;

  if path_system_ids is null or cardinality(path_system_ids) < 2 then
    raise exception 'La ruta debe tener origen y destino';
  end if;

  v_path_length := cardinality(path_system_ids);

  if (
    select count(distinct system_id)
    from unnest(path_system_ids) as route(system_id)
  ) <> v_path_length then
    raise exception 'La ruta contiene sistemas duplicados';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  for v_selection in
    select unit_id, quantity
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    if v_selection.unit_id is null then
      raise exception 'Cada seleccion debe tener unidad';
    end if;

    if v_selection.unit_id = any(v_selected_unit_ids) then
      raise exception 'La seleccion contiene unidades duplicadas';
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
      raise exception 'Las unidades no se pueden dividir al mover';
    end if;

    if v_faction_id is null then
      v_faction_id := v_unit.faction_id;
      v_origin_system_id := v_unit.current_system_id;
    elsif v_unit.faction_id is distinct from v_faction_id or v_unit.current_system_id is distinct from v_origin_system_id then
      raise exception 'Todas las unidades deben pertenecer a la misma faccion y origen';
    end if;

    v_selected_unit_ids := array_append(v_selected_unit_ids, v_selection.unit_id);
  end loop;

  if not v_is_admin and not public.is_faction_member(v_faction_id) then
    raise exception 'No puedes mover unidades de esta faccion';
  end if;

  if path_system_ids[1] is distinct from v_origin_system_id then
    raise exception 'La ruta debe empezar en el sistema de origen de las unidades';
  end if;

  if not public.can_faction_depart_from_system(v_origin_system_id, v_faction_id, true) then
    raise exception 'El sistema de origen no esta disponible';
  end if;

  v_destination_system_id := path_system_ids[v_path_length];

  for v_index in 1..v_path_length loop
    select *
    into v_system
    from public.systems
    where id = path_system_ids[v_index]
    for update;

    if not found then
      raise exception 'La ruta contiene un sistema inexistente';
    end if;

    if v_index = v_path_length
      and (v_system.status = 'war' or v_system.blocked_until is not null and v_system.blocked_until > now()) then
      raise exception 'El destino esta bloqueado o en guerra';
    end if;
  end loop;

  for v_index in 1..(v_path_length - 1) loop
    v_from := path_system_ids[v_index];
    v_to := path_system_ids[v_index + 1];

    select *
    into v_edge
    from public.system_edges
    where not is_blocked
      and (
        (from_system_id = v_from and to_system_id = v_to)
        or (from_system_id = v_to and to_system_id = v_from)
      )
    limit 1;

    if not found then
      raise exception 'Ruta no valida: sistema no adyacente';
    end if;

    v_route_cost := v_route_cost + v_edge.uridium_cost;
  end loop;

  v_unit_count := cardinality(v_selected_unit_ids);
  v_total_cost := v_route_cost * v_unit_count;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found or v_resources.uridium < v_total_cost then
    raise exception 'Uridium insuficiente';
  end if;

  select movement_edge_duration_seconds * (v_path_length - 1)
  into v_duration_seconds
  from public.campaign_settings
  where id = 'default';

  v_duration_seconds := coalesce(v_duration_seconds, 120 * (v_path_length - 1));

  select exists (
    select 1
    from unnest(path_system_ids) with ordinality as route(system_id, position)
    join public.systems on systems.id = route.system_id
    where route.position > 1
      and systems.status = 'controlled'
      and systems.controller_faction_id is not null
      and systems.controller_faction_id <> v_faction_id
  ) into v_needs_approval;

  update public.faction_resources
  set
    uridium = uridium - v_total_cost,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.movement_orders (
    faction_id,
    from_system_id,
    to_system_id,
    movement_type,
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
    v_origin_system_id,
    v_destination_system_id,
    'move',
    v_total_cost,
    now(),
    case when v_needs_approval then null else now() end,
    case when v_needs_approval then null else now() + make_interval(secs => v_duration_seconds) end,
    case when v_needs_approval then 'pending_approval' else 'moving' end,
    path_system_ids,
    v_path_length - 1,
    v_duration_seconds
  )
  returning id into v_order_id;

  for v_index in 1..cardinality(v_selected_unit_ids) loop
    select *
    into v_unit
    from public.campaign_units
    where id = v_selected_unit_ids[v_index]
    for update;

    update public.campaign_units
    set
      status = 'moving',
      updated_at = now()
    where id = v_unit.id;

    insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
    values (v_order_id, v_unit.id, v_unit.quantity);
  end loop;

  if v_needs_approval then
    for v_passage in
      select
        systems.controller_faction_id as responder_faction_id,
        array_agg(systems.id order by route.position) as traversed_system_ids
      from unnest(path_system_ids) with ordinality as route(system_id, position)
      join public.systems on systems.id = route.system_id
      where route.position > 1
        and systems.status = 'controlled'
        and systems.controller_faction_id is not null
        and systems.controller_faction_id <> v_faction_id
      group by systems.controller_faction_id
    loop
      insert into public.movement_passage_requests (
        movement_order_id,
        responder_faction_id,
        traversed_system_ids
      )
      values (
        v_order_id,
        v_passage.responder_faction_id,
        v_passage.traversed_system_ids
      )
      on conflict (movement_order_id, responder_faction_id) do nothing;
    end loop;
  end if;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    case when v_needs_approval then 'movement_pending_approval' else 'movement_started' end,
    jsonb_build_object(
      'movement_order_id', v_order_id,
      'unit_ids', to_jsonb(v_selected_unit_ids),
      'path_system_ids', to_jsonb(path_system_ids),
      'route_uridium_cost', v_route_cost,
      'moved_unit_count', v_unit_count,
      'uridium_cost', v_total_cost,
      'duration_seconds', v_duration_seconds,
      'needs_approval', v_needs_approval
    )
  );

  return v_order_id;
end;
$$;

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

  if not public.can_faction_depart_from_system(origin_system_id, v_faction_id, true) then
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

  if not public.can_faction_depart_from_system(origin_system_id, v_faction_id, true) then
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
  v_route_cost integer := 0;
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

  if not public.can_faction_depart_from_system(v_operation.origin_system_id, v_operation.leader_faction_id, true) then
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

grant execute on function public.get_battle_limit_summary(uuid) to authenticated;
grant execute on function public.create_movement_order(jsonb, uuid[]) to authenticated;
grant execute on function public.create_attack_order(jsonb, uuid, uuid) to authenticated;
grant execute on function public.create_coalition_attack_draft(jsonb, uuid, uuid, uuid[]) to authenticated;
grant execute on function public.join_battle_operation(uuid, jsonb, uuid[]) to authenticated;
grant execute on function public.launch_coalition_attack(uuid) to authenticated;
