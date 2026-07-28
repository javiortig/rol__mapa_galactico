create table if not exists public.campaign_events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  content text not null,
  event_type text not null default 'manual' check (event_type in ('manual', 'battle_result', 'system_unblocked', 'movement', 'narrative')),
  system_id uuid references public.systems(id) on delete set null,
  conflict_id uuid references public.conflicts(id) on delete set null,
  created_by_user_id uuid references public.profiles(id) on delete set null,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists campaign_events_created_at_idx on public.campaign_events (created_at desc);
create index if not exists campaign_events_conflict_id_idx on public.campaign_events (conflict_id);

alter table public.campaign_events enable row level security;

drop policy if exists campaign_events_select_public on public.campaign_events;
create policy campaign_events_select_public
on public.campaign_events
for select
to authenticated
using (is_public or public.is_admin());

drop policy if exists campaign_events_admin_all on public.campaign_events;
create policy campaign_events_admin_all
on public.campaign_events
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant select on public.campaign_events to authenticated;

create or replace function public.admin_create_campaign_event(
  event_title text,
  event_content text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_event_id uuid;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede crear eventos';
  end if;

  if length(trim(coalesce(event_title, ''))) < 3 then
    raise exception 'El titulo del evento es demasiado corto';
  end if;

  if length(trim(coalesce(event_content, ''))) < 5 then
    raise exception 'El contenido del evento es demasiado corto';
  end if;

  insert into public.campaign_events (
    slug,
    title,
    content,
    event_type,
    created_by_user_id
  )
  values (
    'manual-' || replace(gen_random_uuid()::text, '-', ''),
    trim(event_title),
    trim(event_content),
    'manual',
    v_user_id
  )
  returning id into v_event_id;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'campaign_event_created',
    jsonb_build_object('event_id', v_event_id, 'title', trim(event_title))
  );

  return v_event_id;
end;
$$;

create or replace function public.create_battle_result_campaign_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_system_name text;
  v_winner_name text;
  v_loser_name text;
  v_side_text text;
begin
  if new.status <> 'resolved' or old.status is not distinct from new.status then
    return new;
  end if;

  select name into v_system_name from public.systems where id = new.system_id;
  select name into v_winner_name from public.factions where id = new.winner_faction_id;

  if new.winner_faction_id is not null and new.winner_faction_id = new.attacker_faction_id then
    select name into v_loser_name from public.factions where id = new.defender_faction_id;
    v_side_text := 'El atacante ha impuesto su voluntad';
  elsif new.winner_faction_id is not null and new.winner_faction_id = new.defender_faction_id then
    select name into v_loser_name from public.factions where id = new.attacker_faction_id;
    v_side_text := 'La defensa ha resistido';
  else
    v_side_text := 'La batalla termina sin vencedor claro';
  end if;

  insert into public.campaign_events (
    slug,
    title,
    content,
    event_type,
    system_id,
    conflict_id
  )
  values (
    'battle-result-' || new.id::text,
    'Comunicado de guerra: ' || coalesce(v_system_name, 'sistema desconocido'),
    case
      when v_winner_name is null then
        v_side_text || ' en ' || coalesce(v_system_name, 'el frente') || '. Las flotas se repliegan entre ceniza, interferencias y juramentos pendientes.'
      else
        v_side_text || ' en ' || coalesce(v_system_name, 'el frente') || ': ' || v_winner_name ||
        ' vence' || case when v_loser_name is null then '.' else ' frente a ' || v_loser_name || '.' end ||
        ' El resultado queda inscrito en los anales de la campana.'
    end,
    'battle_result',
    new.system_id,
    new.id
  )
  on conflict (slug) do nothing;

  return new;
end;
$$;

drop trigger if exists conflicts_create_battle_result_event on public.conflicts;
create trigger conflicts_create_battle_result_event
after update of status on public.conflicts
for each row
execute function public.create_battle_result_campaign_event();

create or replace function public.find_nearest_allied_safe_system(
  target_faction_id uuid,
  origin_system_id uuid
)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  with recursive graph(system_id, depth, path) as (
    select
      case
        when system_edges.from_system_id = origin_system_id then system_edges.to_system_id
        else system_edges.from_system_id
      end as system_id,
      1 as depth,
      array[
        origin_system_id,
        case
          when system_edges.from_system_id = origin_system_id then system_edges.to_system_id
          else system_edges.from_system_id
        end
      ] as path
    from public.system_edges
    where not system_edges.is_blocked
      and (system_edges.from_system_id = origin_system_id or system_edges.to_system_id = origin_system_id)

    union all

    select
      case
        when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
        else system_edges.from_system_id
      end as system_id,
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
  select systems.id
  from graph
  join public.systems on systems.id = graph.system_id
  where systems.controller_faction_id = target_faction_id
    and systems.status = 'controlled'
    and (systems.blocked_until is null or systems.blocked_until <= now())
    and not exists (
      select 1
      from public.conflicts
      where conflicts.system_id = systems.id
        and conflicts.status = 'pending'
    )
    and not exists (
      select 1
      from public.narrative_attacks
      where narrative_attacks.system_id = systems.id
        and narrative_attacks.status = 'incoming'
    )
    and not exists (
      select 1
      from public.movement_orders
      where movement_orders.to_system_id = systems.id
        and movement_orders.movement_type = 'attack'
        and movement_orders.status in ('pending_approval', 'moving')
    )
    and not exists (
      select 1
      from public.battle_operations
      where battle_operations.target_system_id = systems.id
        and battle_operations.status in ('moving', 'in_battle')
    )
  order by graph.depth, systems.name
  limit 1;
$$;

create or replace function public.return_conflict_units_to_nearest_allied_system(target_system_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_unit record;
  v_retreat_system_id uuid;
  v_count integer := 0;
begin
  for v_unit in
    select id, faction_id
    from public.campaign_units
    where current_system_id = target_system_id
      and status = 'in_war'
      and quantity > 0
    for update
  loop
    v_retreat_system_id := public.find_nearest_allied_safe_system(v_unit.faction_id, target_system_id);

    if v_retreat_system_id is null then
      update public.campaign_units
      set status = 'retreat_pending', updated_at = now()
      where id = v_unit.id;
    else
      update public.campaign_units
      set
        current_system_id = v_retreat_system_id,
        status = 'ready',
        updated_at = now()
      where id = v_unit.id;
    end if;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.admin_set_system_block(
  target_system_id uuid,
  blocked_until timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_system public.systems%rowtype;
  v_returned_units integer := 0;
  v_cancelled_conflicts integer := 0;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede bloquear o desbloquear sistemas';
  end if;

  select *
  into v_system
  from public.systems
  where id = target_system_id
  for update;

  if not found then
    raise exception 'Sistema invalido';
  end if;

  if admin_set_system_block.blocked_until is null then
    v_returned_units := public.return_conflict_units_to_nearest_allied_system(target_system_id);

    update public.conflicts
    set
      status = 'cancelled',
      blocked_until = null,
      resolved_at = now(),
      notes = concat_ws(E'\n', notes, 'Conflicto retirado por desbloqueo administrativo del sistema.')
    where system_id = target_system_id
      and status = 'pending';

    get diagnostics v_cancelled_conflicts = row_count;

    update public.systems
    set
      status = case when controller_faction_id is null then 'neutral' else 'controlled' end,
      blocked_until = null,
      updated_at = now()
    where id = target_system_id;

    insert into public.campaign_events (
      slug,
      title,
      content,
      event_type,
      system_id,
      created_by_user_id
    )
    values (
      'system-unblocked-' || target_system_id::text || '-' || extract(epoch from now())::bigint::text,
      'Sistema desbloqueado: ' || v_system.name,
      'Por decreto del mando de campana, ' || v_system.name || ' vuelve a abrir sus rutas. Las tropas atrapadas en el conflicto han sido evacuadas al territorio aliado seguro mas cercano.',
      'system_unblocked',
      target_system_id,
      v_user_id
    );
  else
    update public.systems
    set
      blocked_until = admin_set_system_block.blocked_until,
      updated_at = now()
    where id = target_system_id;
  end if;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    case when admin_set_system_block.blocked_until is null then 'admin_system_unblocked' else 'admin_system_blocked' end,
    jsonb_build_object(
      'system_id', target_system_id,
      'blocked_until', admin_set_system_block.blocked_until,
      'cancelled_conflicts', v_cancelled_conflicts,
      'returned_units', v_returned_units
    )
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
    or (v_destination.blocked_until is not null and v_destination.blocked_until > now()) then
    perform public.cancel_reserved_movement_order(v_order.id, 'El destino ya no esta disponible', v_order.uridium_cost);
    return v_order.id;
  end if;

  select exists (
    select 1
    from unnest(v_order.path_system_ids) with ordinality as route(system_id, position)
    join public.systems on systems.id = route.system_id
    where route.position > 1
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
    perform public.cancel_reserved_movement_order(v_order.id, 'La ruta atraviesa o termina en territorio sin autorizacion vigente', v_order.uridium_cost);
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
      'uridium_cost', v_total_cost,
      'duration_seconds', v_duration_seconds,
      'needs_approval', v_needs_approval
    )
  );

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
  v_destination_requires_approval boolean := false;
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
        or (v_system.blocked_until is not null and v_system.blocked_until > now()) then
        perform public.cancel_reserved_movement_order(
          v_order.id,
          'El destino cambio a territorio bloqueado antes de la llegada',
          v_order.uridium_cost
        );
        v_resolved := v_resolved + 1;
        continue;
      end if;

      select exists (
        select 1
        from public.movement_passage_requests
        where movement_order_id = v_order.id
          and responder_faction_id = v_system.controller_faction_id
          and status = 'accepted'
      )
      into v_destination_requires_approval;

      if v_system.status = 'controlled'
        and v_system.controller_faction_id is not null
        and v_system.controller_faction_id <> v_order.faction_id
        and not v_destination_requires_approval then
        perform public.cancel_reserved_movement_order(
          v_order.id,
          'El destino cambio a territorio aliado no autorizado antes de la llegada',
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

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        case
          when v_system.status = 'controlled'
            and v_system.controller_faction_id is not null
            and v_system.controller_faction_id <> v_order.faction_id
          then 'movement_arrived_foreign_system'
          else 'movement_arrived'
        end,
        jsonb_build_object(
          'movement_order_id', v_order.id,
          'to_system_id', v_order.to_system_id,
          'host_faction_id', v_system.controller_faction_id
        )
      );
    end if;

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

revoke execute on function public.admin_create_campaign_event(text, text) from public;
revoke execute on function public.find_nearest_allied_safe_system(uuid, uuid) from public;
revoke execute on function public.return_conflict_units_to_nearest_allied_system(uuid) from public;
revoke execute on function public.admin_set_system_block(uuid, timestamptz) from public;
revoke execute on function public.start_approved_movement_order(uuid) from public;
revoke execute on function public.create_movement_order(jsonb, uuid[]) from public;
revoke execute on function public.resolve_movement_orders() from public;

grant execute on function public.admin_create_campaign_event(text, text) to authenticated;
grant execute on function public.admin_set_system_block(uuid, timestamptz) to authenticated;
grant execute on function public.create_movement_order(jsonb, uuid[]) to authenticated;
grant execute on function public.resolve_movement_orders() to authenticated;
