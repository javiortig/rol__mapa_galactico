alter table public.unit_templates
  add column if not exists default_quantity integer not null default 1 check (default_quantity > 0);

alter table public.campaign_units
  add column if not exists starting_quantity integer,
  add column if not exists parent_unit_id uuid references public.campaign_units(id),
  add column if not exists destroyed_at timestamptz;

update public.campaign_units
set starting_quantity = quantity
where starting_quantity is null;

alter table public.campaign_units
  alter column starting_quantity set not null,
  alter column starting_quantity set default 1;

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.campaign_units'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%status%'
  loop
    execute format('alter table public.campaign_units drop constraint %I', v_constraint.conname);
  end loop;

  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.campaign_units'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%quantity%'
      and pg_get_constraintdef(oid) like '%> 0%'
  loop
    execute format('alter table public.campaign_units drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

alter table public.campaign_units
  add constraint campaign_units_quantity_check check (quantity >= 0),
  add constraint campaign_units_starting_quantity_check check (starting_quantity > 0),
  add constraint campaign_units_status_check check (status in ('ready', 'moving', 'in_war', 'destroyed', 'retreat_pending'));

alter table public.movement_order_units
  add column if not exists quantity_at_departure integer not null default 1 check (quantity_at_departure > 0);

drop policy if exists campaign_units_select_visible_member_or_admin on public.campaign_units;
create policy campaign_units_select_visible_member_or_admin
on public.campaign_units
for select
to authenticated
using (
  public.is_admin()
  or is_visible_publicly
  or public.is_faction_member(faction_id)
  or exists (
    select 1
    from public.conflicts
    join public.player_factions on player_factions.user_id = auth.uid()
    where conflicts.status = 'pending'
      and conflicts.system_id = campaign_units.current_system_id
      and campaign_units.status = 'in_war'
      and player_factions.faction_id in (conflicts.attacker_faction_id, conflicts.defender_faction_id)
  )
);

drop function if exists public.create_movement_order(uuid[], uuid[]);
drop function if exists public.create_movement_order(jsonb, uuid[]);
drop function if exists public.merge_campaign_units(uuid[]);
drop function if exists public.calculate_battle_casualties(uuid, jsonb);
drop function if exists public.find_retreat_system(uuid, uuid);
drop function if exists public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, uuid, uuid, text);
drop function if exists public.admin_resolve_battle(uuid, uuid, uuid, timestamptz, text);
drop function if exists public.admin_resolve_battle(uuid, uuid, uuid, jsonb, timestamptz, text);

create or replace function public.resolve_recruitment_queue()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_unit_id uuid;
  v_index integer;
  v_created integer := 0;
begin
  for v_item in
    select
      recruitment_queue.*,
      unit_templates.name as unit_name,
      unit_templates.category,
      unit_templates.points,
      unit_templates.default_quantity,
      factions.capital_system_id
    from public.recruitment_queue
    join public.unit_templates on unit_templates.id = recruitment_queue.unit_template_id
    join public.factions on factions.id = recruitment_queue.faction_id
    where recruitment_queue.status = 'queued'
      and recruitment_queue.finishes_at <= now()
    order by recruitment_queue.finishes_at
    for update of recruitment_queue
  loop
    for v_index in 1..v_item.quantity loop
      insert into public.campaign_units (
        slug,
        faction_id,
        unit_template_id,
        name,
        category,
        points,
        quantity,
        starting_quantity,
        experience,
        current_system_id,
        status,
        is_visible_publicly
      )
      values (
        'recruited-' || v_item.id::text || '-' || v_index::text,
        v_item.faction_id,
        v_item.unit_template_id,
        v_item.unit_name,
        v_item.category,
        v_item.points,
        v_item.default_quantity,
        v_item.default_quantity,
        0,
        v_item.capital_system_id,
        'ready',
        false
      )
      returning id into v_unit_id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_item.faction_id,
        'recruitment_completed',
        jsonb_build_object(
          'queue_id', v_item.id,
          'unit_id', v_unit_id,
          'unit_template_id', v_item.unit_template_id,
          'unit_name', v_item.unit_name,
          'quantity', v_item.default_quantity
        )
      );

      v_created := v_created + 1;
    end loop;

    update public.recruitment_queue
    set status = 'completed'
    where id = v_item.id;
  end loop;

  return v_created;
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
  v_total_cost integer := 0;
  v_resources public.faction_resources%rowtype;
  v_duration_seconds integer;
  v_order_id uuid;
  v_selection record;
  v_unit public.campaign_units%rowtype;
  v_selected_unit_ids uuid[] := '{}';
  v_selected_quantities integer[] := '{}';
  v_moving_unit_ids uuid[] := '{}';
  v_moving_unit_id uuid;
  v_split_points integer;
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

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  for v_selection in
    select unit_id, quantity
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    if v_selection.unit_id is null or v_selection.quantity is null or v_selection.quantity < 1 then
      raise exception 'Cada seleccion debe tener unidad y cantidad mayor que cero';
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
      raise exception 'Todas las unidades deben existir y estar listas';
    end if;

    if v_selection.quantity > v_unit.quantity then
      raise exception 'No puedes mover mas miniaturas de las disponibles';
    end if;

    if v_faction_id is null then
      v_faction_id := v_unit.faction_id;
      v_origin_system_id := v_unit.current_system_id;
    elsif v_unit.faction_id is distinct from v_faction_id or v_unit.current_system_id is distinct from v_origin_system_id then
      raise exception 'Todas las unidades deben pertenecer a la misma faccion y origen';
    end if;

    v_selected_unit_ids := array_append(v_selected_unit_ids, v_selection.unit_id);
    v_selected_quantities := array_append(v_selected_quantities, v_selection.quantity);
  end loop;

  if not v_is_admin and not exists (
    select 1
    from public.player_factions
    where user_id = v_user_id
      and faction_id = v_faction_id
  ) then
    raise exception 'No puedes mover unidades de esta faccion';
  end if;

  if path_system_ids[1] is distinct from v_origin_system_id then
    raise exception 'La ruta debe empezar en el sistema de origen de las unidades';
  end if;

  v_path_length := cardinality(path_system_ids);
  v_destination_system_id := path_system_ids[v_path_length];

  for v_index in 1..v_path_length loop
    select *
    into v_system
    from public.systems
    where id = path_system_ids[v_index];

    if not found then
      raise exception 'La ruta contiene un sistema inexistente';
    end if;

    if v_index > 1 and (v_system.status = 'war' or v_system.blocked_until is not null and v_system.blocked_until > now()) then
      raise exception 'La ruta contiene un sistema bloqueado o en guerra';
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
      raise exception 'La ruta contiene un tramo no valido';
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

  update public.faction_resources
  set
    uridium = uridium - v_total_cost,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.movement_orders (
    faction_id,
    from_system_id,
    to_system_id,
    uridium_cost,
    started_at,
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
    v_total_cost,
    now(),
    now() + make_interval(secs => v_duration_seconds),
    'moving',
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

    if v_selected_quantities[v_index] = v_unit.quantity then
      v_moving_unit_id := v_unit.id;

      update public.campaign_units
      set
        status = 'moving',
        updated_at = now()
      where id = v_unit.id;
    else
      v_split_points := greatest(1, ceil((v_unit.points::numeric * v_selected_quantities[v_index]) / greatest(v_unit.starting_quantity, 1))::integer);

      update public.campaign_units
      set
        quantity = quantity - v_selected_quantities[v_index],
        updated_at = now()
      where id = v_unit.id;

      insert into public.campaign_units (
        slug,
        faction_id,
        unit_template_id,
        name,
        category,
        points,
        quantity,
        starting_quantity,
        experience,
        rank,
        enhancement_text,
        notes,
        current_system_id,
        status,
        is_visible_publicly,
        parent_unit_id
      )
      values (
        'split-' || gen_random_uuid()::text,
        v_unit.faction_id,
        v_unit.unit_template_id,
        v_unit.name,
        v_unit.category,
        v_split_points,
        v_selected_quantities[v_index],
        v_selected_quantities[v_index],
        v_unit.experience,
        v_unit.rank,
        v_unit.enhancement_text,
        v_unit.notes,
        v_unit.current_system_id,
        'moving',
        v_unit.is_visible_publicly,
        v_unit.id
      )
      returning id into v_moving_unit_id;
    end if;

    insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
    values (v_order_id, v_moving_unit_id, v_selected_quantities[v_index]);

    v_moving_unit_ids := array_append(v_moving_unit_ids, v_moving_unit_id);
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'movement_started',
    jsonb_build_object(
      'movement_order_id', v_order_id,
      'unit_ids', to_jsonb(v_moving_unit_ids),
      'path_system_ids', to_jsonb(path_system_ids),
      'uridium_cost', v_total_cost,
      'duration_seconds', v_duration_seconds
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
  v_conflict_id uuid;
  v_blocked_until timestamptz;
  v_resolved integer := 0;
begin
  for v_order in
    select *
    from public.movement_orders
    where status = 'moving'
      and arrival_at <= now()
    order by arrival_at
    for update
  loop
    select *
    into v_system
    from public.systems
    where id = v_order.to_system_id
    for update;

    update public.movement_orders
    set status = 'arrived'
    where id = v_order.id;

    if v_system.status = 'war' then
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

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'movement_arrived_locked',
        jsonb_build_object('movement_order_id', v_order.id, 'system_id', v_order.to_system_id)
      );
    elsif v_system.controller_faction_id is null
      or v_system.controller_faction_id is distinct from v_order.faction_id then
      select now() + make_interval(mins => conflict_block_duration_minutes)
      into v_blocked_until
      from public.campaign_settings
      where id = 'default';

      v_blocked_until := coalesce(v_blocked_until, now() + interval '30 minutes');

      insert into public.conflicts (
        slug,
        system_id,
        attacker_faction_id,
        defender_faction_id,
        status,
        blocked_until,
        notes
      )
      values (
        'conflict-' || v_order.id::text,
        v_order.to_system_id,
        v_order.faction_id,
        v_system.controller_faction_id,
        'pending',
        v_blocked_until,
        'Conflicto generado por llegada de movimiento.'
      )
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
        and v_system.controller_faction_id is not null
        and faction_id = v_system.controller_faction_id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values
        (
          v_order.faction_id,
          'conflict_created',
          jsonb_build_object(
            'conflict_id', v_conflict_id,
            'movement_order_id', v_order.id,
            'system_id', v_order.to_system_id,
            'blocked_until', v_blocked_until
          )
        ),
        (
          v_order.faction_id,
          'system_locked',
          jsonb_build_object('system_id', v_order.to_system_id, 'blocked_until', v_blocked_until)
        );
    else
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

create or replace function public.merge_campaign_units(unit_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_distinct_unit_ids uuid[];
  v_target public.campaign_units%rowtype;
  v_unit public.campaign_units%rowtype;
  v_total_quantity integer := 0;
  v_total_starting_quantity integer := 0;
  v_total_points integer := 0;
  v_max_experience integer := 0;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select array_agg(unit_id)
  into v_distinct_unit_ids
  from (
    select distinct unnest(unit_ids) as unit_id
  ) distinct_units;

  if v_distinct_unit_ids is null or cardinality(v_distinct_unit_ids) < 2 then
    raise exception 'Selecciona al menos dos unidades compatibles';
  end if;

  if cardinality(v_distinct_unit_ids) <> cardinality(unit_ids) then
    raise exception 'La seleccion contiene unidades duplicadas';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_target
  from public.campaign_units
  where id = any(v_distinct_unit_ids)
  order by created_at, id
  limit 1
  for update;

  if not found then
    raise exception 'Unidades no encontradas';
  end if;

  if not v_is_admin and not public.is_faction_member(v_target.faction_id) then
    raise exception 'No puedes fusionar unidades de esta faccion';
  end if;

  for v_unit in
    select *
    from public.campaign_units
    where id = any(v_distinct_unit_ids)
    order by created_at, id
    for update
  loop
    if v_unit.status <> 'ready' or v_unit.quantity <= 0 then
      raise exception 'Solo se pueden fusionar unidades listas';
    end if;

    if v_unit.faction_id is distinct from v_target.faction_id
      or v_unit.current_system_id is distinct from v_target.current_system_id
      or v_unit.unit_template_id is distinct from v_target.unit_template_id
      or v_unit.name is distinct from v_target.name
      or v_unit.category is distinct from v_target.category
      or v_unit.rank is distinct from v_target.rank
      or v_unit.enhancement_text is distinct from v_target.enhancement_text then
      raise exception 'Las unidades seleccionadas no son compatibles';
    end if;

    v_total_quantity := v_total_quantity + v_unit.quantity;
    v_total_starting_quantity := v_total_starting_quantity + v_unit.starting_quantity;
    v_total_points := v_total_points + v_unit.points;
    v_max_experience := greatest(v_max_experience, v_unit.experience);
  end loop;

  update public.campaign_units
  set
    quantity = v_total_quantity,
    starting_quantity = v_total_starting_quantity,
    points = v_total_points,
    experience = v_max_experience,
    updated_at = now()
  where id = v_target.id;

  update public.campaign_units
  set
    quantity = 0,
    status = 'destroyed',
    destroyed_at = now(),
    updated_at = now(),
    parent_unit_id = v_target.id
  where id = any(v_distinct_unit_ids)
    and id <> v_target.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_target.faction_id,
    'units_merged',
    jsonb_build_object('target_unit_id', v_target.id, 'merged_unit_ids', to_jsonb(v_distinct_unit_ids))
  );

  return v_target.id;
end;
$$;

create or replace function public.find_retreat_system(target_faction_id uuid, origin_system_id uuid)
returns uuid
language sql
stable
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
  order by graph.depth, systems.name
  limit 1;
$$;

create or replace function public.calculate_battle_casualties(target_conflict_id uuid, survivors jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conflict public.conflicts%rowtype;
  v_unit public.campaign_units%rowtype;
  v_survivors integer;
  v_casualties jsonb := '{}'::jsonb;
begin
  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  if survivors is null or jsonb_typeof(survivors) <> 'object' then
    raise exception 'El reporte debe indicar supervivientes por unidad';
  end if;

  for v_unit in
    select *
    from public.campaign_units
    where current_system_id = v_conflict.system_id
      and status = 'in_war'
    order by created_at, id
  loop
    if not (survivors ? v_unit.id::text) then
      raise exception 'Faltan supervivientes para una unidad en guerra';
    end if;

    v_survivors := nullif(survivors->>v_unit.id::text, '')::integer;

    if v_survivors is null or v_survivors < 0 or v_survivors > v_unit.quantity then
      raise exception 'Cantidad de supervivientes no valida';
    end if;

    v_casualties := v_casualties || jsonb_build_object(v_unit.id::text, v_unit.quantity - v_survivors);
  end loop;

  return v_casualties;
end;
$$;

create or replace function public.apply_battle_outcome(
  target_conflict_id uuid,
  winner_faction_id uuid,
  final_controller_faction_id uuid,
  post_battle_blocked_until timestamptz,
  survivors jsonb,
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
  v_survivors integer;
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

  perform public.calculate_battle_casualties(target_conflict_id, survivors);

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

    if v_survivors = 0 then
      update public.campaign_units
      set
        quantity = 0,
        status = 'destroyed',
        destroyed_at = now(),
        updated_at = now()
      where id = v_unit.id;
    elsif apply_battle_outcome.final_controller_faction_id is null
      or v_unit.faction_id is not distinct from apply_battle_outcome.final_controller_faction_id then
      update public.campaign_units
      set
        quantity = v_survivors,
        status = 'ready',
        updated_at = now()
      where id = v_unit.id;
    else
      v_retreat_system_id := public.find_retreat_system(v_unit.faction_id, v_conflict.system_id);

      if v_retreat_system_id is null then
        update public.campaign_units
        set
          quantity = v_survivors,
          status = 'retreat_pending',
          updated_at = now()
        where id = v_unit.id;
      else
        update public.campaign_units
        set
          quantity = v_survivors,
          current_system_id = v_retreat_system_id,
          status = 'ready',
          updated_at = now()
        where id = v_unit.id;
      end if;
    end if;
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    apply_battle_outcome.actor_user_id,
    apply_battle_outcome.actor_faction_id,
    'battle_outcome_applied',
    jsonb_build_object(
      'conflict_id', target_conflict_id,
      'winner_faction_id', apply_battle_outcome.winner_faction_id,
      'final_controller_faction_id', apply_battle_outcome.final_controller_faction_id,
      'survivors', survivors
    )
  );
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
  v_reporter_faction_id uuid;
  v_is_admin boolean := false;
  v_report_id uuid;
  v_other public.battle_reports%rowtype;
  v_winner_faction_id uuid;
  v_final_controller_faction_id uuid;
  v_post_battle_blocked_until timestamptz;
  v_casualties jsonb;
  v_survivors jsonb;
  v_xp_awards jsonb;
  v_enhancements jsonb;
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

  select player_factions.faction_id
  into v_reporter_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
    and player_factions.faction_id in (v_conflict.attacker_faction_id, v_conflict.defender_faction_id)
  order by player_factions.created_at
  limit 1;

  if not v_is_admin and v_reporter_faction_id is null then
    raise exception 'Solo participantes o admin pueden reportar esta batalla';
  end if;

  v_winner_faction_id := nullif(report_payload->>'winner_faction_id', '')::uuid;
  v_final_controller_faction_id := nullif(report_payload->>'final_controller_faction_id', '')::uuid;
  v_post_battle_blocked_until := nullif(report_payload->>'post_battle_blocked_until', '')::timestamptz;
  v_survivors := coalesce(report_payload->'survivors', '{}'::jsonb);
  v_casualties := public.calculate_battle_casualties(v_conflict.id, v_survivors);
  v_xp_awards := coalesce(report_payload->'xp_awards', '{}'::jsonb);
  v_enhancements := coalesce(report_payload->'enhancements', '{}'::jsonb);

  insert into public.battle_reports (
    conflict_id,
    reporter_user_id,
    reporter_faction_id,
    winner_faction_id,
    final_controller_faction_id,
    casualties,
    survivors,
    xp_awards,
    enhancements,
    post_battle_blocked_until,
    narrative_notes,
    status
  )
  values (
    v_conflict.id,
    v_user_id,
    v_reporter_faction_id,
    v_winner_faction_id,
    v_final_controller_faction_id,
    v_casualties,
    v_survivors,
    v_xp_awards,
    v_enhancements,
    v_post_battle_blocked_until,
    report_payload->>'narrative_notes',
    'submitted'
  )
  returning id into v_report_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_reporter_faction_id,
    'battle_report_submitted',
    jsonb_build_object('report_id', v_report_id, 'conflict_id', v_conflict.id)
  );

  select *
  into v_other
  from public.battle_reports
  where battle_reports.conflict_id = v_conflict.id
    and battle_reports.id <> v_report_id
    and battle_reports.status = 'submitted'
    and (
      v_reporter_faction_id is null
      or battle_reports.reporter_faction_id is distinct from v_reporter_faction_id
    )
  order by battle_reports.created_at
  limit 1;

  if found then
    if v_other.winner_faction_id is not distinct from v_winner_faction_id
      and v_other.final_controller_faction_id is not distinct from v_final_controller_faction_id
      and v_other.post_battle_blocked_until is not distinct from v_post_battle_blocked_until
      and coalesce(v_other.survivors, '{}'::jsonb) = v_survivors
      and coalesce(v_other.xp_awards, '{}'::jsonb) = v_xp_awards
      and coalesce(v_other.enhancements, '{}'::jsonb) = v_enhancements then
      update public.battle_reports
      set
        status = 'auto_confirmed',
        resolved_at = now()
      where id in (v_report_id, v_other.id);

      perform public.apply_battle_outcome(
        v_conflict.id,
        v_winner_faction_id,
        v_final_controller_faction_id,
        v_post_battle_blocked_until,
        v_survivors,
        v_user_id,
        v_reporter_faction_id,
        report_payload->>'narrative_notes'
      );

      insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
      values (
        v_user_id,
        v_reporter_faction_id,
        'battle_report_auto_confirmed',
        jsonb_build_object('conflict_id', v_conflict.id, 'report_ids', jsonb_build_array(v_report_id, v_other.id))
      );
    else
      update public.battle_reports
      set status = 'disputed'
      where id in (v_report_id, v_other.id);

      insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
      values (
        v_user_id,
        v_reporter_faction_id,
        'battle_report_disputed',
        jsonb_build_object('conflict_id', v_conflict.id, 'report_ids', jsonb_build_array(v_report_id, v_other.id))
      );
    end if;
  end if;

  return v_report_id;
end;
$$;

create or replace function public.admin_resolve_battle(
  target_conflict_id uuid,
  winner_faction_id uuid,
  final_controller_faction_id uuid,
  survivors jsonb default '{}'::jsonb,
  post_battle_blocked_until timestamptz default null,
  narrative_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.conflicts%rowtype;
  v_casualties jsonb;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede resolver batallas manualmente';
  end if;

  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id
  for update;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  v_casualties := public.calculate_battle_casualties(target_conflict_id, survivors);

  perform public.apply_battle_outcome(
    target_conflict_id,
    admin_resolve_battle.winner_faction_id,
    admin_resolve_battle.final_controller_faction_id,
    admin_resolve_battle.post_battle_blocked_until,
    admin_resolve_battle.survivors,
    v_user_id,
    admin_resolve_battle.final_controller_faction_id,
    admin_resolve_battle.narrative_notes
  );

  insert into public.battle_reports (
    conflict_id,
    reporter_user_id,
    winner_faction_id,
    final_controller_faction_id,
    casualties,
    survivors,
    post_battle_blocked_until,
    narrative_notes,
    status,
    resolved_at
  )
  values (
    target_conflict_id,
    v_user_id,
    admin_resolve_battle.winner_faction_id,
    admin_resolve_battle.final_controller_faction_id,
    v_casualties,
    admin_resolve_battle.survivors,
    admin_resolve_battle.post_battle_blocked_until,
    admin_resolve_battle.narrative_notes,
    'admin_confirmed',
    now()
  );

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    admin_resolve_battle.final_controller_faction_id,
    'battle_report_admin_resolved',
    jsonb_build_object(
      'conflict_id', target_conflict_id,
      'winner_faction_id', admin_resolve_battle.winner_faction_id,
      'final_controller_faction_id', admin_resolve_battle.final_controller_faction_id,
      'survivors', admin_resolve_battle.survivors
    )
  );
end;
$$;

grant execute on function public.create_movement_order(jsonb, uuid[]) to authenticated;
grant execute on function public.merge_campaign_units(uuid[]) to authenticated;
grant execute on function public.admin_resolve_battle(uuid, uuid, uuid, jsonb, timestamptz, text) to authenticated;
