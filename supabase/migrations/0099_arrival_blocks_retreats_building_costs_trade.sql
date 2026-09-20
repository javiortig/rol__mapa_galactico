-- Campaign progression, arrival-time battle blocking, fixed retreats and trade scope.

update public.campaign_units
set
  experience = least(10, experience + 1),
  updated_at = now()
where slug in (
  'cult-abominant',
  'sombra-lieutenant',
  'necron-plasmancer',
  'custodes-blade-champion'
)
  and experience < 10;

update public.building_templates
set
  supply_cost = ceil(supply_cost::numeric * 1.25)::integer,
  minerals_cost = ceil(minerals_cost::numeric * 1.25)::integer,
  honor_cost = ceil(honor_cost::numeric * 1.25)::integer,
  gold_cost = ceil(gold_cost::numeric * 1.25)::integer,
  industrial_material_cost = ceil(industrial_material_cost::numeric * 1.25)::integer,
  uridium_cost = ceil(uridium_cost::numeric * 1.25)::integer,
  technology_cost = ceil(technology_cost::numeric * 1.25)::integer,
  updated_at = now();

-- An incoming attack is a threat, but it does not block local activity until arrival.
create or replace function public.system_has_unresolved_battle_block(target_system_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.systems
    where systems.id = $1
      and systems.status = 'war'
  )
  or exists (
    select 1
    from public.conflicts
    where conflicts.system_id = $1
      and conflicts.status = 'pending'
  )
  or exists (
    select 1
    from public.narrative_attacks
    where narrative_attacks.system_id = $1
      and narrative_attacks.status = 'arrived'
      and exists (
        select 1
        from public.conflicts
        where conflicts.id = narrative_attacks.conflict_id
          and conflicts.status = 'pending'
      )
  )
  or exists (
    select 1
    from public.battle_operations
    where battle_operations.target_system_id = $1
      and battle_operations.status = 'in_battle'
  );
$$;

-- Retreat destinations must also avoid attacks which have not arrived yet.
create or replace function public.system_has_incoming_or_battle_pressure(target_system_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.system_has_unresolved_battle_block($1)
  or exists (
    select 1
    from public.narrative_attacks
    where narrative_attacks.system_id = $1
      and narrative_attacks.status = 'incoming'
  )
  or exists (
    select 1
    from public.movement_orders
    where movement_orders.to_system_id = $1
      and movement_orders.movement_type = 'attack'
      and movement_orders.status in ('pending_approval', 'moving')
  )
  or exists (
    select 1
    from public.battle_operations
    where battle_operations.target_system_id = $1
      and battle_operations.status in ('assembling', 'moving')
  );
$$;

create or replace function public.find_nearest_allied_safe_system(target_faction_id uuid, origin_system_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  with recursive graph(system_id, depth, path) as (
    select
      case
        when system_edges.from_system_id = origin_system_id then system_edges.to_system_id
        else system_edges.from_system_id
      end,
      1,
      array[
        origin_system_id,
        case
          when system_edges.from_system_id = origin_system_id then system_edges.to_system_id
          else system_edges.from_system_id
        end
      ]
    from public.system_edges
    where not system_edges.is_blocked
      and (system_edges.from_system_id = origin_system_id or system_edges.to_system_id = origin_system_id)

    union all

    select
      case
        when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
        else system_edges.from_system_id
      end,
      graph.depth + 1,
      graph.path || case
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
    and not public.system_has_incoming_or_battle_pressure(systems.id)
  order by graph.depth, systems.name
  limit 1;
$$;

-- Moving and pending-retreat units no longer grant local intelligence.
create or replace function public.user_has_presence_in_system(target_system_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.campaign_units
    where campaign_units.current_system_id = target_system_id
      and campaign_units.faction_id = public.current_user_faction_id()
      and campaign_units.status in ('ready', 'in_war', 'recovering')
      and campaign_units.quantity > 0
  );
$$;

create or replace function public.resolve_resource_ticks()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.campaign_settings%rowtype;
  v_tick_at timestamptz;
  v_last_applied_at timestamptz;
  v_applied integer := 0;
begin
  perform public.resolve_building_construction();
  perform public.refresh_system_production_from_buildings();

  select * into v_settings
  from public.campaign_settings
  where id = 'default'
  for update;

  if not found then
    insert into public.campaign_settings (id, resource_tick_interval_hours, next_resource_tick_at)
    values ('default', 24, now() + interval '24 hours')
    returning * into v_settings;
  end if;

  v_tick_at := coalesce(
    v_settings.next_resource_tick_at,
    now() + make_interval(hours => v_settings.resource_tick_interval_hours)
  );

  while v_tick_at <= now() loop
    insert into public.faction_resources (
      faction_id, supply, minerals, ancestral_stone, honor, gold,
      industrial_material, uridium, technology, updated_at
    )
    select
      systems.controller_faction_id,
      coalesce(sum(system_production.supply_per_tick), 0)::integer,
      coalesce(sum(system_production.minerals_per_tick), 0)::integer,
      0,
      coalesce(sum(system_production.honor_per_tick), 0)::numeric(12,2),
      coalesce(sum(system_production.gold_per_tick), 0)::integer,
      coalesce(sum(system_production.industrial_material_per_tick), 0)::integer,
      coalesce(sum(system_production.uridium_per_tick), 0)::numeric(12,2),
      0,
      now()
    from public.systems
    join public.system_production on system_production.system_id = systems.id
    where systems.status = 'controlled'
      and systems.controller_faction_id is not null
      and not public.system_has_unresolved_battle_block(systems.id)
    group by systems.controller_faction_id
    on conflict (faction_id) do update
    set
      supply = public.faction_resources.supply + excluded.supply,
      minerals = public.faction_resources.minerals + excluded.minerals,
      honor = public.faction_resources.honor + excluded.honor,
      gold = public.faction_resources.gold + excluded.gold,
      industrial_material = public.faction_resources.industrial_material + excluded.industrial_material,
      uridium = public.faction_resources.uridium + excluded.uridium,
      updated_at = now();

    insert into public.campaign_logs (action_type, payload)
    values ('resource_tick_applied', jsonb_build_object('tick_at', v_tick_at, 'source', 'system_buildings'));

    v_last_applied_at := v_tick_at;
    v_tick_at := v_tick_at + make_interval(hours => v_settings.resource_tick_interval_hours);
    v_applied := v_applied + 1;
  end loop;

  if v_applied > 0 then
    update public.campaign_settings
    set last_resource_tick_at = v_last_applied_at,
        next_resource_tick_at = v_tick_at,
        updated_at = now()
    where id = 'default';
  end if;

  return v_applied;
end;
$$;

create or replace function public.resolve_building_construction()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_building record;
  v_resolved integer := 0;
begin
  for v_building in
    select system_buildings.*
    from public.system_buildings
    where system_buildings.status = 'constructing'
      and system_buildings.finishes_at <= now()
      and not public.system_has_unresolved_battle_block(system_buildings.system_id)
    order by system_buildings.finishes_at
    for update
  loop
    update public.system_buildings
    set status = 'active', constructed_at = now(), updated_at = now()
    where id = v_building.id;

    insert into public.campaign_logs (action_type, payload)
    values ('building_construction_completed', jsonb_build_object(
      'system_building_id', v_building.id,
      'system_id', v_building.system_id,
      'building_template_id', v_building.building_template_id
    ));

    v_resolved := v_resolved + 1;
  end loop;

  if v_resolved > 0 then
    perform public.refresh_system_production_from_buildings();
  end if;

  return v_resolved;
end;
$$;

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
  v_unit_points integer;
  v_unit_models integer;
begin
  for v_item in
    select
      recruitment_queue.*,
      unit_templates.name as unit_name,
      unit_templates.category,
      unit_templates.unit_type,
      unit_templates.unit_keywords,
      unit_templates.points,
      unit_templates.default_quantity,
      factions.capital_system_id
    from public.recruitment_queue
    join public.unit_templates on unit_templates.id = recruitment_queue.unit_template_id
    join public.factions on factions.id = recruitment_queue.faction_id
    where recruitment_queue.status = 'queued'
      and recruitment_queue.finishes_at <= now()
      and not public.system_has_unresolved_battle_block(
        coalesce(recruitment_queue.origin_system_id, factions.capital_system_id)
      )
    order by recruitment_queue.finishes_at
    for update of recruitment_queue
  loop
    v_unit_points := coalesce(v_item.selected_points, v_item.points);
    v_unit_models := coalesce(v_item.selected_model_count, v_item.default_quantity);

    for v_index in 1..v_item.quantity loop
      insert into public.campaign_units (
        slug, faction_id, unit_template_id, name, category, unit_type, unit_keywords,
        points, quantity, starting_quantity, wounds_taken, experience,
        current_system_id, status, is_visible_publicly, selected_model_option_id,
        selected_wargear_points, selected_wargear_options, point_cost_breakdown
      )
      values (
        'recruited-' || v_item.id::text || '-' || v_index::text,
        v_item.faction_id, v_item.unit_template_id, v_item.unit_name, v_item.category,
        v_item.unit_type, v_item.unit_keywords, v_unit_points, v_unit_models,
        v_unit_models, 0, 0,
        coalesce(v_item.origin_system_id, v_item.capital_system_id),
        'ready', false, v_item.selected_model_option_id, v_item.selected_wargear_points,
        v_item.selected_wargear_options, v_item.point_cost_breakdown
      )
      returning id into v_unit_id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (v_item.faction_id, 'recruitment_completed', jsonb_build_object(
        'queue_id', v_item.id,
        'unit_id', v_unit_id,
        'unit_template_id', v_item.unit_template_id,
        'unit_name', v_item.unit_name,
        'quantity', v_unit_models,
        'points', v_unit_points,
        'origin_system_id', coalesce(v_item.origin_system_id, v_item.capital_system_id)
      ));

      v_created := v_created + 1;
    end loop;

    update public.recruitment_queue
    set status = 'completed', updated_at = now()
    where id = v_item.id;
  end loop;

  return v_created;
end;
$$;

create or replace function public.resolve_unit_recovery_queue()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_resolved integer := 0;
begin
  for v_item in
    select unit_recovery_queue.*, campaign_units.name as unit_name
    from public.unit_recovery_queue
    join public.campaign_units on campaign_units.id = unit_recovery_queue.campaign_unit_id
    join public.system_buildings on system_buildings.id = unit_recovery_queue.system_building_id
    where unit_recovery_queue.status = 'queued'
      and unit_recovery_queue.finishes_at <= now()
      and not public.system_has_unresolved_battle_block(system_buildings.system_id)
    order by unit_recovery_queue.finishes_at
    for update of unit_recovery_queue
  loop
    update public.campaign_units
    set quantity = starting_quantity,
        wounds_taken = 0,
        status = case when destroyed_at is null then 'ready' else status end,
        updated_at = now()
    where id = v_item.campaign_unit_id;

    update public.unit_recovery_queue
    set status = 'completed', updated_at = now()
    where id = v_item.id;

    insert into public.campaign_logs (faction_id, action_type, payload)
    values (v_item.faction_id, 'unit_resupply_completed', jsonb_build_object(
      'unit_recovery_queue_id', v_item.id,
      'campaign_unit_id', v_item.campaign_unit_id,
      'unit_name', v_item.unit_name
    ));

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

create or replace function public.queue_losing_battle_retreat(
  target_conflict_id uuid,
  target_unit_id uuid,
  target_commitment_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conflict public.conflicts%rowtype;
  v_operation public.battle_operations%rowtype;
  v_unit public.campaign_units%rowtype;
  v_destination_id uuid;
  v_path uuid[];
  v_path_length integer;
  v_order_id uuid;
  v_duration_seconds constant integer := 86400;
begin
  select * into v_conflict
  from public.conflicts
  where id = target_conflict_id;

  select * into v_unit
  from public.campaign_units
  where id = target_unit_id
  for update;

  if v_conflict.id is null or v_unit.id is null or v_unit.quantity <= 0 then
    return null;
  end if;

  if v_conflict.battle_operation_id is not null then
    select * into v_operation
    from public.battle_operations
    where id = v_conflict.battle_operation_id;

    select systems.id into v_destination_id
    from public.systems
    where systems.id = v_operation.origin_system_id
      and coalesce(systems.is_temporary_mission, false) = false
      and (
        systems.system_kind = 'gaseous'
        or (
          systems.status = 'controlled'
          and systems.controller_faction_id = v_unit.faction_id
        )
      )
      and not public.system_has_incoming_or_battle_pressure(systems.id)
    limit 1;
  end if;

  if v_destination_id is not null then
    v_path := public.find_shortest_unblocked_path(v_conflict.system_id, v_destination_id);
    v_path_length := cardinality(v_path);

    if v_path_length < 2
      or v_path[1] is distinct from v_conflict.system_id
      or v_path[v_path_length] is distinct from v_destination_id then
      v_destination_id := null;
      v_path := null;
    end if;
  end if;

  if v_destination_id is null then
    v_destination_id := public.find_retreat_or_capital_system(v_unit.faction_id, v_conflict.system_id);

    if v_destination_id is not null then
      v_path := public.find_shortest_unblocked_path(v_conflict.system_id, v_destination_id);
      v_path_length := cardinality(v_path);
    end if;
  end if;

  if v_destination_id is null
    or v_path_length < 2
    or v_path[1] is distinct from v_conflict.system_id
    or v_path[v_path_length] is distinct from v_destination_id then
    update public.campaign_units
    set status = 'retreat_pending', updated_at = now()
    where id = v_unit.id;

    if target_commitment_id is not null then
      update public.battle_unit_commitments
      set status = 'return_pending', updated_at = now()
      where id = target_commitment_id;
    end if;

    return null;
  end if;

  insert into public.movement_orders (
    faction_id, from_system_id, to_system_id, movement_type, movement_purpose,
    battle_operation_id, uridium_cost, started_at, departure_at, arrival_at,
    status, path_system_ids, segment_count, duration_seconds
  )
  values (
    v_unit.faction_id, v_conflict.system_id, v_destination_id, 'move', 'battle_return',
    v_conflict.battle_operation_id, 0, now(), now(), now() + interval '1 day',
    'moving', v_path, v_path_length - 1, v_duration_seconds
  )
  returning id into v_order_id;

  insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
  values (v_order_id, v_unit.id, v_unit.quantity);

  update public.campaign_units
  set status = 'moving', updated_at = now()
  where id = v_unit.id;

  if target_commitment_id is not null then
    update public.battle_unit_commitments
    set return_movement_order_id = v_order_id,
        return_path_system_ids = v_path,
        status = 'returning',
        updated_at = now()
    where id = target_commitment_id;
  end if;

  insert into public.campaign_logs (faction_id, action_type, payload)
  values (v_unit.faction_id, 'battle_retreat_started', jsonb_build_object(
    'conflict_id', v_conflict.id,
    'movement_order_id', v_order_id,
    'unit_id', v_unit.id,
    'from_system_id', v_conflict.system_id,
    'to_system_id', v_destination_id,
    'duration_seconds', v_duration_seconds
  ));

  return v_order_id;
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
  v_retreat_order_id uuid;
  v_supporter_side_lost boolean;
begin
  select * into v_conflict
  from public.conflicts
  where id = target_conflict_id
  for update;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  perform public.validate_battle_survivors_and_wounds(target_conflict_id, survivors, wounds_remaining);

  update public.conflicts
  set status = 'resolved',
      winner_faction_id = apply_battle_outcome.winner_faction_id,
      blocked_until = apply_battle_outcome.post_battle_blocked_until,
      resolved_at = now(),
      notes = coalesce(apply_battle_outcome.narrative_notes, notes)
  where id = target_conflict_id;

  update public.systems
  set status = case when apply_battle_outcome.final_controller_faction_id is null then 'neutral' else 'controlled' end,
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

    select * into v_commitment
    from public.battle_unit_commitments
    where operation_id = v_conflict.battle_operation_id
      and unit_id = v_unit.id;

    v_supporter_side_lost :=
      v_commitment.id is not null
      and v_commitment.role = 'supporter'
      and apply_battle_outcome.winner_faction_id is not null
      and (
        (v_commitment.side = 'attacker' and v_conflict.attacker_faction_id is distinct from apply_battle_outcome.winner_faction_id)
        or
        (v_commitment.side = 'defender' and v_conflict.defender_faction_id is distinct from apply_battle_outcome.winner_faction_id)
      );

    if v_survivors = 0 then
      update public.campaign_units
      set quantity = 0, wounds_taken = 0, status = 'destroyed', destroyed_at = now(), updated_at = now()
      where id = v_unit.id;

      if v_commitment.id is not null then
        update public.battle_unit_commitments
        set status = 'destroyed', updated_at = now()
        where id = v_commitment.id;
      end if;
    elsif v_commitment.id is not null and v_commitment.role = 'supporter' and not v_supporter_side_lost then
      update public.campaign_units
      set quantity = v_survivors, wounds_taken = v_wounds, status = 'moving', updated_at = now()
      where id = v_unit.id;

      perform public.queue_battle_support_return(v_commitment.id);
    elsif apply_battle_outcome.final_controller_faction_id is null
      or v_unit.faction_id is not distinct from apply_battle_outcome.final_controller_faction_id then
      update public.campaign_units
      set quantity = v_survivors, wounds_taken = v_wounds, status = 'ready', updated_at = now()
      where id = v_unit.id;
    else
      update public.campaign_units
      set quantity = v_survivors, wounds_taken = v_wounds, status = 'moving', updated_at = now()
      where id = v_unit.id;

      v_retreat_order_id := public.queue_losing_battle_retreat(
        target_conflict_id,
        v_unit.id,
        v_commitment.id
      );

      if v_retreat_order_id is null then
        update public.campaign_units
        set status = 'retreat_pending', updated_at = now()
        where id = v_unit.id;
      end if;
    end if;
  end loop;

  if apply_battle_outcome.final_controller_faction_id is not null then
    for v_unit in
      select *
      from public.campaign_units
      where current_system_id = v_conflict.system_id
        and faction_id is distinct from apply_battle_outcome.final_controller_faction_id
        and status = 'ready'
        and quantity > 0
      order by created_at, id
      for update
    loop
      v_retreat_order_id := public.queue_losing_battle_retreat(target_conflict_id, v_unit.id, null);

      if v_retreat_order_id is null then
        update public.campaign_units
        set status = 'retreat_pending', updated_at = now()
        where id = v_unit.id;
      end if;
    end loop;
  end if;

  if apply_battle_outcome.final_controller_faction_id is not null
    and v_conflict.attacker_faction_id is not null
    and apply_battle_outcome.final_controller_faction_id = v_conflict.attacker_faction_id then
    update public.recruitment_queue
    set status = 'cancelled', updated_at = now()
    where status = 'queued'
      and (
        origin_system_id = v_conflict.system_id
        or system_building_id in (
          select id from public.system_buildings where system_id = v_conflict.system_id
        )
      );

    update public.unit_recovery_queue
    set status = 'cancelled', updated_at = now()
    where status = 'queued'
      and system_building_id in (
        select id from public.system_buildings where system_id = v_conflict.system_id
      );

    with destroyed_buildings as (
      delete from public.system_buildings
      where system_id = v_conflict.system_id
      returning id, building_template_id, status
    )
    insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
    select
      apply_battle_outcome.actor_user_id,
      apply_battle_outcome.actor_faction_id,
      'system_buildings_destroyed_by_conquest',
      jsonb_build_object(
        'conflict_id', target_conflict_id,
        'system_id', v_conflict.system_id,
        'attacker_faction_id', v_conflict.attacker_faction_id,
        'final_controller_faction_id', apply_battle_outcome.final_controller_faction_id,
        'destroyed_count', count(*),
        'building_ids', coalesce(jsonb_agg(destroyed_buildings.id), '[]'::jsonb),
        'building_template_ids', coalesce(jsonb_agg(destroyed_buildings.building_template_id), '[]'::jsonb)
      )
    from destroyed_buildings
    having count(*) > 0;

    perform public.refresh_system_production_from_buildings();
  end if;

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

-- Gaseous systems are valid return destinations for the fixed retreat movement.
do $$
declare
  v_definition text;
  v_old text := $needle$if v_system.status = 'controlled'
        and v_system.controller_faction_id = v_order.faction_id then$needle$;
  v_new text := $replacement$if (
        v_system.status = 'controlled'
        and v_system.controller_faction_id = v_order.faction_id
      ) or v_system.system_kind = 'gaseous' then$replacement$;
begin
  select pg_get_functiondef('public.resolve_movement_orders()'::regprocedure)
  into v_definition;

  if position(v_old in v_definition) = 0 then
    raise exception 'No se pudo actualizar resolve_movement_orders para retiradas gaseosas';
  end if;

  execute replace(v_definition, v_old, v_new);
end;
$$;

-- The merchant remains limited to basic recruitment resources.
do $$
declare
  v_definition text;
  v_old text := $needle$if v_resource_key is null then
    raise exception 'Recurso no comerciable';
  end if;$needle$;
  v_new text := $replacement$if v_resource_key is null then
    raise exception 'Recurso no comerciable';
  end if;

  if v_resource_key not in ('supply', 'minerals') then
    raise exception 'El Mercader solo comercia Suministro vital y Mineral';
  end if;$replacement$;
begin
  select pg_get_functiondef('public.merchant_trade(text,text,integer)'::regprocedure)
  into v_definition;

  if position(v_old in v_definition) = 0 then
    raise exception 'No se pudo limitar merchant_trade a recursos basicos';
  end if;

  execute replace(v_definition, v_old, v_new);
end;
$$;

revoke execute on function public.system_has_incoming_or_battle_pressure(uuid) from public;
revoke execute on function public.queue_losing_battle_retreat(uuid, uuid, uuid) from public;
grant execute on function public.system_has_incoming_or_battle_pressure(uuid) to authenticated;
