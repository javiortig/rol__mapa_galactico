alter table public.movement_orders
  add column if not exists movement_type text not null default 'move',
  add column if not exists departure_at timestamptz,
  add column if not exists defender_faction_id uuid references public.factions(id),
  add column if not exists cancellation_reason text,
  add column if not exists resolved_at timestamptz;

alter table public.movement_orders
  alter column arrival_at drop not null;

alter table public.movement_orders
  drop constraint if exists movement_orders_status_check,
  add constraint movement_orders_status_check
  check (status in ('pending_approval', 'moving', 'arrived', 'in_battle', 'resolved', 'cancelled'));

alter table public.movement_orders
  drop constraint if exists movement_orders_movement_type_check,
  add constraint movement_orders_movement_type_check
  check (movement_type in ('move', 'attack'));

update public.movement_orders
set movement_type = 'move'
where movement_type is null;

update public.movement_orders
set departure_at = started_at
where departure_at is null
  and status in ('moving', 'arrived', 'in_battle', 'resolved');

alter table public.conflicts
  add column if not exists movement_order_id uuid references public.movement_orders(id) on delete set null;

create unique index if not exists conflicts_movement_order_id_key
on public.conflicts (movement_order_id)
where movement_order_id is not null;

create table if not exists public.movement_passage_requests (
  id uuid primary key default gen_random_uuid(),
  movement_order_id uuid not null references public.movement_orders(id) on delete cascade,
  responder_faction_id uuid not null references public.factions(id) on delete cascade,
  traversed_system_ids uuid[] not null check (cardinality(traversed_system_ids) > 0),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  response_reason text,
  responded_by_user_id uuid references public.profiles(id),
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (movement_order_id, responder_faction_id)
);

create index if not exists movement_passage_requests_responder_status_idx
on public.movement_passage_requests (responder_faction_id, status);

create index if not exists movement_passage_requests_movement_order_id_idx
on public.movement_passage_requests (movement_order_id);

alter table public.movement_passage_requests enable row level security;

grant select on public.movement_passage_requests to authenticated;

create or replace function public.can_select_movement_passage_request(
  target_movement_order_id uuid,
  target_responder_faction_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
    or public.is_faction_member(target_responder_faction_id)
    or exists (
      select 1
      from public.movement_orders
      where movement_orders.id = target_movement_order_id
        and public.is_faction_member(movement_orders.faction_id)
    );
$$;

create or replace function public.can_select_movement_order(
  target_movement_order_id uuid,
  target_owner_faction_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
    or public.is_faction_member(target_owner_faction_id)
    or exists (
      select 1
      from public.movement_passage_requests
      where movement_passage_requests.movement_order_id = target_movement_order_id
        and public.is_faction_member(movement_passage_requests.responder_faction_id)
    );
$$;

drop policy if exists movement_passage_requests_select_related on public.movement_passage_requests;
create policy movement_passage_requests_select_related
on public.movement_passage_requests
for select
to authenticated
using (public.can_select_movement_passage_request(movement_order_id, responder_faction_id));

drop policy if exists movement_passage_requests_admin_all on public.movement_passage_requests;
create policy movement_passage_requests_admin_all
on public.movement_passage_requests
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists movement_orders_select_member_or_admin on public.movement_orders;
create policy movement_orders_select_member_or_admin
on public.movement_orders
for select
to authenticated
using (public.can_select_movement_order(id, faction_id));

drop policy if exists movement_order_units_select_member_or_admin on public.movement_order_units;
create policy movement_order_units_select_member_or_admin
on public.movement_order_units
for select
to authenticated
using (
  exists (
    select 1
    from public.movement_orders
    where movement_orders.id = movement_order_units.movement_order_id
      and public.can_select_movement_order(movement_orders.id, movement_orders.faction_id)
  )
);

create or replace function public.current_player_faction_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select player_factions.faction_id
  from public.player_factions
  where player_factions.user_id = auth.uid()
  order by player_factions.created_at, player_factions.id
  limit 1;
$$;

create or replace function public.attack_month_start()
returns timestamptz
language sql
stable
as $$
  select date_trunc('month', now());
$$;

create or replace function public.attack_active_statuses()
returns text[]
language sql
immutable
as $$
  select array['moving', 'in_battle']::text[];
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
  v_month_end timestamptz := public.attack_month_start() + interval '1 month';
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
  v_month_end timestamptz := public.attack_month_start() + interval '1 month';
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
    raise exception 'El defensor ya ha recibido dos ataques este mes';
  end if;

  if coalesce(v_attacker_total, 0) >= 3 then
    raise exception 'Maximo de participaciones mensuales alcanzado para el atacante';
  end if;

  if coalesce(v_defender_total, 0) >= 3 then
    raise exception 'Maximo de participaciones mensuales alcanzado para el defensor';
  end if;

  if coalesce(v_attacker_active, 0) >= 3 then
    raise exception 'Maximo de batallas activas alcanzado para el atacante';
  end if;

  if coalesce(v_defender_active, 0) >= 3 then
    raise exception 'Maximo de batallas activas alcanzado para el defensor';
  end if;
end;
$$;

create or replace function public.cancel_reserved_movement_order(target_order_id uuid, reason text, refund_uridium integer default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_refund integer;
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

  if v_refund > 0 then
    update public.faction_resources
    set
      uridium = uridium + v_refund,
      updated_at = now()
    where faction_id = v_order.faction_id;
  end if;

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
    jsonb_build_object('movement_order_id', v_order.id, 'reason', reason, 'refund_uridium', v_refund)
  );
end;
$$;

create or replace function public.start_approved_movement_order(target_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_path_length integer;
  v_index integer;
  v_from uuid;
  v_to uuid;
  v_system public.systems%rowtype;
  v_destination public.systems%rowtype;
  v_missing_approval boolean := false;
  v_invalid_units boolean := false;
begin
  select *
  into v_order
  from public.movement_orders
  where id = target_order_id
  for update;

  if not found then
    raise exception 'Movimiento no encontrado';
  end if;

  if v_order.status <> 'pending_approval' then
    return v_order.id;
  end if;

  if exists (
    select 1
    from public.movement_passage_requests
    where movement_order_id = v_order.id
      and status <> 'accepted'
  ) then
    return v_order.id;
  end if;

  v_path_length := cardinality(v_order.path_system_ids);

  if v_path_length < 2 then
    perform public.cancel_reserved_movement_order(v_order.id, 'Ruta invalida antes de ejecutar movimiento', v_order.uridium_cost);
    return v_order.id;
  end if;

  if (
    select count(distinct system_id)
    from unnest(v_order.path_system_ids) as route(system_id)
  ) <> v_path_length then
    perform public.cancel_reserved_movement_order(v_order.id, 'Ruta duplicada antes de ejecutar movimiento', v_order.uridium_cost);
    return v_order.id;
  end if;

  for v_index in 1..v_path_length loop
    select *
    into v_system
    from public.systems
    where id = v_order.path_system_ids[v_index]
    for update;

    if not found or (
      v_index = v_path_length
      and (v_system.status = 'war' or v_system.blocked_until is not null and v_system.blocked_until > now())
    ) then
      perform public.cancel_reserved_movement_order(v_order.id, 'La ruta ya no es valida', v_order.uridium_cost);
      return v_order.id;
    end if;
  end loop;

  for v_index in 1..(v_path_length - 1) loop
    v_from := v_order.path_system_ids[v_index];
    v_to := v_order.path_system_ids[v_index + 1];

    if not exists (
      select 1
      from public.system_edges
      where not is_blocked
        and (
          (from_system_id = v_from and to_system_id = v_to)
          or (from_system_id = v_to and to_system_id = v_from)
        )
    ) then
      perform public.cancel_reserved_movement_order(v_order.id, 'La ruta contiene un tramo no valido', v_order.uridium_cost);
      return v_order.id;
    end if;
  end loop;

  select *
  into v_destination
  from public.systems
  where id = v_order.to_system_id
  for update;

  if not found
    or v_destination.status = 'war'
    or (v_destination.blocked_until is not null and v_destination.blocked_until > now())
    or (
      v_destination.status = 'controlled'
      and v_destination.controller_faction_id is not null
      and v_destination.controller_faction_id <> v_order.faction_id
    ) then
    perform public.cancel_reserved_movement_order(v_order.id, 'El destino ya no es propio o neutral', v_order.uridium_cost);
    return v_order.id;
  end if;

  select exists (
    select 1
    from unnest(v_order.path_system_ids) with ordinality as route(system_id, position)
    join public.systems on systems.id = route.system_id
    where route.position > 1
      and route.position < v_path_length
      and systems.status = 'controlled'
      and systems.controller_faction_id is not null
      and systems.controller_faction_id <> v_order.faction_id
      and not exists (
        select 1
        from public.movement_passage_requests
        where movement_passage_requests.movement_order_id = v_order.id
          and movement_passage_requests.responder_faction_id = systems.controller_faction_id
          and movement_passage_requests.status = 'accepted'
      )
  ) into v_missing_approval;

  if v_missing_approval then
    perform public.cancel_reserved_movement_order(v_order.id, 'La ruta atraviesa territorio sin autorizacion vigente', v_order.uridium_cost);
    return v_order.id;
  end if;

  select exists (
    select 1
    from public.movement_order_units
    join public.campaign_units on campaign_units.id = movement_order_units.unit_id
    where movement_order_units.movement_order_id = v_order.id
      and (
        campaign_units.faction_id <> v_order.faction_id
        or campaign_units.current_system_id <> v_order.from_system_id
        or campaign_units.status <> 'moving'
      )
  ) into v_invalid_units;

  if v_invalid_units then
    perform public.cancel_reserved_movement_order(v_order.id, 'Las unidades reservadas ya no son validas', v_order.uridium_cost);
    return v_order.id;
  end if;

  update public.movement_orders
  set
    status = 'moving',
    departure_at = now(),
    started_at = now(),
    arrival_at = now() + make_interval(secs => duration_seconds)
  where id = v_order.id;

  insert into public.campaign_logs (faction_id, action_type, payload)
  values (
    v_order.faction_id,
    'movement_approved_started',
    jsonb_build_object('movement_order_id', v_order.id)
  );

  return v_order.id;
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
  v_origin public.systems%rowtype;
  v_destination public.systems%rowtype;
  v_total_cost integer := 0;
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

  select *
  into v_origin
  from public.systems
  where id = v_origin_system_id
  for update;

  if not found or v_origin.status <> 'controlled' or v_origin.controller_faction_id <> v_faction_id then
    raise exception 'El sistema de origen debe estar controlado por tu faccion';
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
      raise exception 'La ruta contiene un sistema bloqueado o en guerra';
    end if;
  end loop;

  select *
  into v_destination
  from public.systems
  where id = v_destination_system_id
  for update;

  if not found then
    raise exception 'El destino no existe';
  end if;

  if v_destination.status = 'controlled'
    and v_destination.controller_faction_id is not null
    and v_destination.controller_faction_id <> v_faction_id then
    raise exception 'Destino de movimiento enemigo; usa Atacar';
  end if;

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

    v_total_cost := v_total_cost + v_edge.uridium_cost;
  end loop;

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
      and route.position < v_path_length
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
        and route.position < v_path_length
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
      'uridium_cost', v_total_cost,
      'duration_seconds', v_duration_seconds,
      'needs_approval', v_needs_approval
    )
  );

  return v_order_id;
end;
$$;

create or replace function public.create_attack_order(unit_selections jsonb, origin_system_id uuid, target_system_id uuid)
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
  v_order_id uuid;
  v_selection record;
  v_unit public.campaign_units%rowtype;
  v_selected_unit_ids uuid[] := '{}';
  v_duration_seconds integer := 518400;
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
      raise exception 'Las unidades no se pueden dividir al atacar';
    end if;

    if v_faction_id is null then
      v_faction_id := v_unit.faction_id;
      v_selected_origin_id := v_unit.current_system_id;
    elsif v_unit.faction_id is distinct from v_faction_id or v_unit.current_system_id is distinct from v_selected_origin_id then
      raise exception 'Todas las unidades deben pertenecer a la misma faccion y origen';
    end if;

    v_selected_unit_ids := array_append(v_selected_unit_ids, v_selection.unit_id);
  end loop;

  if v_selected_origin_id is distinct from origin_system_id then
    raise exception 'Las unidades seleccionadas no estan en el sistema de origen';
  end if;

  if not v_is_admin and not public.is_faction_member(v_faction_id) then
    raise exception 'No puedes atacar con unidades de esta faccion';
  end if;

  if v_origin.status <> 'controlled' or v_origin.controller_faction_id <> v_faction_id then
    raise exception 'El sistema de origen debe estar controlado por tu faccion';
  end if;

  if v_origin.status = 'war' or v_origin.blocked_until is not null and v_origin.blocked_until > now() then
    raise exception 'El sistema de origen esta bloqueado o en guerra';
  end if;

  if v_target.status <> 'controlled' or v_target.controller_faction_id is null then
    raise exception 'Destino de ataque no enemigo';
  end if;

  if v_target.controller_faction_id = v_faction_id then
    raise exception 'No puedes atacar un sistema propio';
  end if;

  if v_target.status = 'war' or v_target.blocked_until is not null and v_target.blocked_until > now() then
    raise exception 'El sistema objetivo esta bloqueado o en guerra';
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

  insert into public.movement_orders (
    faction_id,
    defender_faction_id,
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
    v_target.controller_faction_id,
    origin_system_id,
    target_system_id,
    'attack',
    0,
    now(),
    now(),
    now() + interval '6 days',
    'moving',
    array[origin_system_id, target_system_id],
    1,
    v_duration_seconds
  )
  returning id into v_order_id;

  for v_selection in
    select unit_id, quantity
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    select *
    into v_unit
    from public.campaign_units
    where id = v_selection.unit_id
    for update;

    update public.campaign_units
    set
      status = 'moving',
      updated_at = now()
    where id = v_unit.id;

    insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
    values (v_order_id, v_unit.id, v_unit.quantity);
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'attack_started',
    jsonb_build_object(
      'movement_order_id', v_order_id,
      'defender_faction_id', v_target.controller_faction_id,
      'origin_system_id', origin_system_id,
      'target_system_id', target_system_id,
      'arrival_at', now() + interval '6 days',
      'unit_ids', to_jsonb(v_selected_unit_ids)
    )
  );

  return v_order_id;
end;
$$;

create or replace function public.respond_movement_passage_request(passage_request_id uuid, decision text, response_reason text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_request public.movement_passage_requests%rowtype;
  v_order public.movement_orders%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if decision not in ('accepted', 'rejected') then
    raise exception 'Respuesta de autorizacion no valida';
  end if;

  select *
  into v_request
  from public.movement_passage_requests
  where id = passage_request_id
  for update;

  if not found then
    raise exception 'Solicitud de paso no encontrada';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'Solicitud ya resuelta';
  end if;

  if not public.is_admin() and not public.is_faction_member(v_request.responder_faction_id) then
    raise exception 'Usuario no autorizado';
  end if;

  select *
  into v_order
  from public.movement_orders
  where id = v_request.movement_order_id
  for update;

  if not found or v_order.status <> 'pending_approval' then
    raise exception 'Movimiento pendiente no disponible';
  end if;

  update public.movement_passage_requests
  set
    status = decision,
    response_reason = respond_movement_passage_request.response_reason,
    responded_by_user_id = v_user_id,
    responded_at = now()
  where id = v_request.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_order.faction_id,
    'movement_passage_' || decision,
    jsonb_build_object(
      'movement_order_id', v_order.id,
      'passage_request_id', v_request.id,
      'responder_faction_id', v_request.responder_faction_id
    )
  );

  if decision = 'rejected' then
    perform public.cancel_reserved_movement_order(
      v_order.id,
      coalesce(respond_movement_passage_request.response_reason, 'Solicitud de paso rechazada'),
      v_order.uridium_cost
    );
    return v_order.id;
  end if;

  if not exists (
    select 1
    from public.movement_passage_requests
    where movement_order_id = v_order.id
      and status = 'pending'
  ) then
    perform public.start_approved_movement_order(v_order.id);
  end if;

  return v_order.id;
end;
$$;

create or replace function public.cancel_movement_order(order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_order public.movement_orders%rowtype;
  v_refund integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_order
  from public.movement_orders
  where id = cancel_movement_order.order_id
  for update;

  if not found then
    raise exception 'Movimiento no encontrado';
  end if;

  if v_order.status not in ('pending_approval', 'moving') then
    raise exception 'El movimiento no esta activo';
  end if;

  if v_order.arrival_at is not null and v_order.arrival_at <= now() then
    raise exception 'Movimiento ya resuelto o pendiente de resolucion';
  end if;

  if not v_is_admin and not public.is_faction_member(v_order.faction_id) then
    raise exception 'No puedes cancelar este movimiento';
  end if;

  v_refund := case
    when v_order.status = 'pending_approval' then v_order.uridium_cost
    else ceil(v_order.uridium_cost::numeric / 2)::integer
  end;

  perform public.cancel_reserved_movement_order(v_order.id, 'Cancelado por el jugador', v_refund);

  return v_order.id;
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
    order by arrival_at
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

      v_blocked_until := coalesce(v_blocked_until, now() + interval '30 minutes');

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
        'Conflicto generado por llegada de ataque.'
      )
      on conflict (movement_order_id) where movement_order_id is not null do update
      set blocked_until = excluded.blocked_until
      returning id into v_conflict_id;

      update public.systems
      set
        status = 'war',
        blocked_until = v_blocked_until,
        updated_at = now()
      where id = v_order.to_system_id;

      update public.campaign_units
      set
        current_system_id = v_order.to_system_id,
        status = 'in_war',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );

      update public.campaign_units
      set
        status = 'in_war',
        updated_at = now()
      where current_system_id = v_order.to_system_id
        and status = 'ready'
        and quantity > 0
        and faction_id = v_system.controller_faction_id;

      update public.movement_orders
      set
        status = 'in_battle',
        resolved_at = now()
      where id = v_order.id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'attack_arrived_conflict_created',
        jsonb_build_object(
          'conflict_id', v_conflict_id,
          'movement_order_id', v_order.id,
          'system_id', v_order.to_system_id,
          'blocked_until', v_blocked_until
        )
      );
    else
      if v_system.status = 'war'
        or (v_system.blocked_until is not null and v_system.blocked_until > now())
        or (
          v_system.status = 'controlled'
        and v_system.controller_faction_id is not null
        and v_system.controller_faction_id <> v_order.faction_id
        ) then
        perform public.cancel_reserved_movement_order(v_order.id, 'El destino cambio a territorio enemigo antes de la llegada', v_order.uridium_cost);
        v_resolved := v_resolved + 1;
        continue;
      end if;

      update public.movement_orders
      set
        status = 'arrived',
        resolved_at = now()
      where id = v_order.id;

      if coalesce(v_system.allows_shared_occupation, false) or not coalesce(v_system.is_conquerable, true) then
        update public.systems
        set
          status = 'neutral',
          controller_faction_id = null,
          blocked_until = null,
          updated_at = now()
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
      set
        current_system_id = v_order.to_system_id,
        status = 'ready',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'movement_completed',
        jsonb_build_object('movement_order_id', v_order.id, 'system_id', v_order.to_system_id)
      );
    end if;

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
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
      cancellation_reason = case when new.status = 'cancelled' then coalesce(new.notes, cancellation_reason) else cancellation_reason end
    where id = new.movement_order_id
      and movement_type = 'attack'
      and status = 'in_battle';
  end if;

  return new;
end;
$$;

drop trigger if exists sync_movement_order_from_conflict_trigger on public.conflicts;
create trigger sync_movement_order_from_conflict_trigger
after update of status on public.conflicts
for each row
execute function public.sync_movement_order_from_conflict();

grant execute on function public.current_player_faction_id() to authenticated;
grant execute on function public.can_select_movement_passage_request(uuid, uuid) to authenticated;
grant execute on function public.can_select_movement_order(uuid, uuid) to authenticated;
grant execute on function public.get_battle_limit_summary(uuid) to authenticated;
grant execute on function public.create_movement_order(jsonb, uuid[]) to authenticated;
grant execute on function public.create_attack_order(jsonb, uuid, uuid) to authenticated;
grant execute on function public.respond_movement_passage_request(uuid, text, text) to authenticated;
grant execute on function public.cancel_movement_order(uuid) to authenticated;
grant execute on function public.resolve_movement_orders() to authenticated;

grant select on
  public.profiles,
  public.player_factions,
  public.factions,
  public.systems,
  public.system_edges,
  public.system_production,
  public.system_special_objects,
  public.faction_resources,
  public.campaign_units,
  public.movement_orders,
  public.movement_order_units,
  public.movement_passage_requests,
  public.unit_templates,
  public.recruitment_queue,
  public.technology_nodes,
  public.technology_prerequisites,
  public.faction_technologies,
  public.technology_effects,
  public.building_templates,
  public.system_buildings,
  public.system_resource_capabilities,
  public.unit_recovery_queue,
  public.relics,
  public.trade_offers,
  public.conflicts,
  public.battle_reports,
  public.missions,
  public.campaign_settings
to authenticated;

grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

revoke all on function public.validate_attack_limits(uuid, uuid) from public;
revoke all on function public.cancel_reserved_movement_order(uuid, text, integer) from public;
revoke all on function public.start_approved_movement_order(uuid) from public;
