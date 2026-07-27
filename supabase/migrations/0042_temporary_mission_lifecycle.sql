alter table public.systems
  add column if not exists mission_expires_after_battle boolean not null default false,
  add column if not exists temporary_mission_status text not null default 'active',
  add column if not exists temporary_mission_closed_at timestamptz;

alter table public.movement_orders
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'systems_temporary_mission_status_check'
      and conrelid = 'public.systems'::regclass
  ) then
    alter table public.systems
      add constraint systems_temporary_mission_status_check
      check (temporary_mission_status in ('active', 'expired', 'completed', 'removed'));
  end if;
end;
$$;

create or replace function public.distance_point_to_segment(
  px double precision,
  py double precision,
  ax double precision,
  ay double precision,
  bx double precision,
  by double precision
)
returns double precision
language plpgsql
immutable
as $$
declare
  v_dx double precision := bx - ax;
  v_dy double precision := by - ay;
  v_length_squared double precision := v_dx * v_dx + v_dy * v_dy;
  v_t double precision;
  v_closest_x double precision;
  v_closest_y double precision;
begin
  if v_length_squared <= 0 then
    return sqrt(power(px - ax, 2) + power(py - ay, 2));
  end if;

  v_t := greatest(0, least(1, ((px - ax) * v_dx + (py - ay) * v_dy) / v_length_squared));
  v_closest_x := ax + v_t * v_dx;
  v_closest_y := ay + v_t * v_dy;

  return sqrt(power(px - v_closest_x, 2) + power(py - v_closest_y, 2));
end;
$$;

create or replace function public.segments_intersect_or_close(
  ax double precision,
  ay double precision,
  bx double precision,
  by double precision,
  cx double precision,
  cy double precision,
  dx double precision,
  dy double precision
)
returns double precision
language plpgsql
immutable
as $$
declare
  v_epsilon double precision := 0.000001;
  v_o1 double precision := (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
  v_o2 double precision := (bx - ax) * (dy - ay) - (by - ay) * (dx - ax);
  v_o3 double precision := (dx - cx) * (ay - cy) - (dy - cy) * (ax - cx);
  v_o4 double precision := (dx - cx) * (by - cy) - (dy - cy) * (bx - cx);
begin
  if greatest(least(ax, bx), least(cx, dx)) <= least(greatest(ax, bx), greatest(cx, dx)) + v_epsilon
    and greatest(least(ay, by), least(cy, dy)) <= least(greatest(ay, by), greatest(cy, dy)) + v_epsilon
    and (
      (abs(v_o1) <= v_epsilon and public.distance_point_to_segment(cx, cy, ax, ay, bx, by) <= v_epsilon)
      or (abs(v_o2) <= v_epsilon and public.distance_point_to_segment(dx, dy, ax, ay, bx, by) <= v_epsilon)
      or (abs(v_o3) <= v_epsilon and public.distance_point_to_segment(ax, ay, cx, cy, dx, dy) <= v_epsilon)
      or (abs(v_o4) <= v_epsilon and public.distance_point_to_segment(bx, by, cx, cy, dx, dy) <= v_epsilon)
      or ((v_o1 > v_epsilon and v_o2 < -v_epsilon or v_o1 < -v_epsilon and v_o2 > v_epsilon)
        and (v_o3 > v_epsilon and v_o4 < -v_epsilon or v_o3 < -v_epsilon and v_o4 > v_epsilon))
    ) then
    return 0;
  end if;

  return least(
    public.distance_point_to_segment(ax, ay, cx, cy, dx, dy),
    public.distance_point_to_segment(bx, by, cx, cy, dx, dy),
    public.distance_point_to_segment(cx, cy, ax, ay, bx, by),
    public.distance_point_to_segment(dx, dy, ax, ay, bx, by)
  );
end;
$$;

create or replace function public.is_safe_mission_evacuation_system(candidate_system_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.systems
    where systems.id = candidate_system_id
      and not coalesce(systems.is_temporary_mission, false)
      and coalesce(systems.system_kind, 'standard') <> 'gaseous'
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
          and battle_operations.status in ('assembling', 'moving', 'in_battle')
      )
  );
$$;

create or replace function public.find_nearest_safe_system_for_faction(
  origin_system_id uuid,
  target_faction_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result uuid;
begin
  with recursive graph(system_id, cost, hops, path) as (
    select origin_system_id, 0::integer, 0::integer, array[origin_system_id]
    union all
    select
      next_nodes.next_id,
      graph.cost + system_edges.uridium_cost,
      graph.hops + 1,
      graph.path || next_nodes.next_id
    from graph
    join public.system_edges
      on not system_edges.is_blocked
      and (system_edges.from_system_id = graph.system_id or system_edges.to_system_id = graph.system_id)
    join lateral (
      select case
        when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
        else system_edges.from_system_id
      end as next_id
    ) as next_nodes on true
    join public.systems as next_systems on next_systems.id = next_nodes.next_id
    where graph.hops < 24
      and not next_nodes.next_id = any(graph.path)
      and not (
        coalesce(next_systems.is_temporary_mission, false)
        and next_nodes.next_id <> origin_system_id
      )
  )
  select graph.system_id
  into v_result
  from graph
  join public.systems on systems.id = graph.system_id
  where graph.system_id <> origin_system_id
    and systems.controller_faction_id = target_faction_id
    and public.is_safe_mission_evacuation_system(graph.system_id)
  order by graph.cost, graph.hops, systems.name
  limit 1;

  return v_result;
end;
$$;

create or replace function public.cleanup_temporary_mission(
  target_system_id uuid,
  cleanup_reason text default 'removed'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_system public.systems%rowtype;
  v_reason text := case
    when cleanup_reason in ('expired', 'completed', 'removed') then cleanup_reason
    else 'removed'
  end;
  v_unit public.campaign_units%rowtype;
  v_destination_id uuid;
begin
  select *
  into v_system
  from public.systems
  where id = target_system_id
  for update;

  if not found then
    raise exception 'Mision temporal no encontrada';
  end if;

  if not coalesce(v_system.is_temporary_mission, false) then
    raise exception 'El sistema seleccionado no es una mision temporal';
  end if;

  if coalesce(v_system.temporary_mission_status, 'active') <> 'active' then
    return v_system.id;
  end if;

  for v_unit in
    select *
    from public.campaign_units
    where campaign_units.id in (
      select distinct candidate_units.unit_id
      from (
        select campaign_units.id as unit_id
        from public.campaign_units
        where campaign_units.current_system_id = v_system.id
        union
        select movement_order_units.unit_id
        from public.movement_order_units
        join public.movement_orders
          on movement_orders.id = movement_order_units.movement_order_id
        where (movement_orders.to_system_id = v_system.id or movement_orders.from_system_id = v_system.id)
          and movement_orders.status in ('pending_approval', 'moving', 'in_battle')
        union
        select battle_unit_commitments.unit_id
        from public.battle_unit_commitments
        join public.battle_operations
          on battle_operations.id = battle_unit_commitments.operation_id
        where battle_operations.target_system_id = v_system.id
          and battle_operations.status in ('assembling', 'moving', 'in_battle')
          and battle_unit_commitments.status not in ('destroyed', 'cancelled', 'returned')
      ) as candidate_units
    )
      and campaign_units.quantity > 0
      and campaign_units.status <> 'destroyed'
    order by campaign_units.faction_id, campaign_units.name, campaign_units.id
    for update
  loop
    v_destination_id := public.find_nearest_safe_system_for_faction(v_system.id, v_unit.faction_id);

    if v_destination_id is null then
      update public.campaign_units
      set
        current_system_id = null,
        status = 'retreat_pending',
        updated_at = now()
      where id = v_unit.id;
    else
      update public.campaign_units
      set
        current_system_id = v_destination_id,
        status = 'ready',
        updated_at = now()
      where id = v_unit.id;
    end if;

    insert into public.campaign_logs (faction_id, action_type, payload)
    values (
      v_unit.faction_id,
      'temporary_mission_unit_evacuated',
      jsonb_build_object(
        'mission_system_id', v_system.id,
        'unit_id', v_unit.id,
        'destination_system_id', v_destination_id,
        'reason', v_reason
      )
    );
  end loop;

  update public.movement_orders
  set
    status = 'cancelled',
    cancelled_at = coalesce(cancelled_at, now()),
    cancellation_reason = 'La mision temporal desaparecio: ' || v_reason,
    updated_at = now()
  where (to_system_id = v_system.id or from_system_id = v_system.id)
    and status in ('pending_approval', 'moving', 'in_battle');

  update public.battle_unit_commitments
  set
    status = 'cancelled',
    updated_at = now()
  where operation_id in (
    select id
    from public.battle_operations
    where battle_operations.target_system_id = v_system.id
      and battle_operations.status in ('assembling', 'moving', 'in_battle')
  )
    and status not in ('destroyed', 'returned');

  update public.battle_operations
  set
    status = 'cancelled',
    cancelled_at = coalesce(cancelled_at, now()),
    cancellation_reason = 'La mision temporal desaparecio: ' || v_reason,
    updated_at = now()
  where battle_operations.target_system_id = v_system.id
    and status in ('assembling', 'moving', 'in_battle');

  update public.conflicts
  set
    status = 'cancelled',
    resolved_at = coalesce(resolved_at, now()),
    notes = coalesce(notes, '') || E'\nMision temporal cerrada: ' || v_reason
  where system_id = v_system.id
    and status = 'pending';

  update public.narrative_attacks
  set
    status = 'cancelled',
    updated_at = now()
  where system_id = v_system.id
    and status = 'incoming';

  update public.systems
  set
    status = 'neutral',
    controller_faction_id = null,
    blocked_until = null,
    temporary_mission_status = v_reason,
    temporary_mission_closed_at = now(),
    updated_at = now()
  where id = v_system.id;

  insert into public.campaign_logs (action_type, payload)
  values (
    'temporary_mission_closed',
    jsonb_build_object(
      'system_id', v_system.id,
      'mission_id', v_system.mission_id,
      'reason', v_reason
    )
  );

  return v_system.id;
end;
$$;

create or replace function public.resolve_temporary_missions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_system record;
  v_resolved integer := 0;
begin
  for v_system in
    select id
    from public.systems
    where coalesce(is_temporary_mission, false)
      and temporary_mission_status = 'active'
      and mission_expires_at is not null
      and mission_expires_at <= now()
    order by mission_expires_at, created_at
    for update skip locked
  loop
    perform public.cleanup_temporary_mission(v_system.id, 'expired');
    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

create or replace function public.admin_remove_temporary_mission(target_system_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede eliminar misiones temporales';
  end if;

  return public.cleanup_temporary_mission(target_system_id, 'removed');
end;
$$;

create or replace function public.cleanup_mission_after_conflict_resolution()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_system public.systems%rowtype;
begin
  if tg_op <> 'UPDATE' or new.status <> 'resolved' or old.status is not distinct from new.status then
    return new;
  end if;

  select *
  into v_system
  from public.systems
  where id = new.system_id;

  if found
    and coalesce(v_system.is_temporary_mission, false)
    and v_system.temporary_mission_status = 'active'
    and coalesce(v_system.mission_expires_after_battle, false) then
    perform public.cleanup_temporary_mission(v_system.id, 'completed');
  end if;

  return new;
end;
$$;

drop trigger if exists cleanup_mission_after_conflict_resolution_trigger on public.conflicts;
create trigger cleanup_mission_after_conflict_resolution_trigger
after update of status on public.conflicts
for each row
execute function public.cleanup_mission_after_conflict_resolution();

drop function if exists public.get_visible_systems();

create or replace function public.get_visible_systems()
returns table (
  id uuid,
  slug text,
  name text,
  x numeric,
  y numeric,
  size numeric,
  star_class text,
  type text,
  status text,
  controller_faction_id uuid,
  blocked_until timestamptz,
  public_description text,
  secret_admin_notes text,
  mission_id uuid,
  is_capital boolean,
  created_at timestamptz,
  updated_at timestamptz,
  system_kind text,
  is_conquerable boolean,
  allows_shared_occupation boolean,
  building_slots integer,
  is_temporary_mission boolean,
  mission_threat_faction_id uuid,
  mission_enemy_units_visible boolean,
  mission_enemy_units jsonb,
  mission_expires_at timestamptz,
  mission_expires_after_battle boolean,
  temporary_mission_status text,
  temporary_mission_closed_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    systems.id,
    systems.slug,
    systems.name,
    systems.x,
    systems.y,
    systems.size,
    systems.star_class,
    systems.type,
    systems.status,
    systems.controller_faction_id,
    systems.blocked_until,
    systems.public_description,
    case when public.is_admin() then systems.secret_admin_notes else null::text end as secret_admin_notes,
    systems.mission_id,
    systems.is_capital,
    systems.created_at,
    systems.updated_at,
    systems.system_kind,
    systems.is_conquerable,
    systems.allows_shared_occupation,
    systems.building_slots,
    systems.is_temporary_mission,
    systems.mission_threat_faction_id,
    systems.mission_enemy_units_visible,
    case
      when public.is_admin() or systems.mission_enemy_units_visible
      then systems.mission_enemy_units
      else '[]'::jsonb
    end as mission_enemy_units,
    systems.mission_expires_at,
    systems.mission_expires_after_battle,
    systems.temporary_mission_status,
    systems.temporary_mission_closed_at
  from public.systems
  where not coalesce(systems.is_temporary_mission, false)
    or systems.temporary_mission_status = 'active'
  order by systems.name;
$$;

create or replace function public.admin_create_narrative_mission(
  anchor_system_id uuid,
  narrative_faction_id uuid,
  mission_name text,
  mission_description text,
  enemy_units_visible boolean default false,
  enemy_units jsonb default '[]'::jsonb,
  duration_days integer default 7,
  expires_after_battle boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_anchor public.systems%rowtype;
  v_faction public.factions%rowtype;
  v_system_id uuid := gen_random_uuid();
  v_mission_id uuid := gen_random_uuid();
  v_name text := trim(coalesce(mission_name, ''));
  v_description text := trim(coalesce(mission_description, ''));
  v_enemy_units jsonb := coalesce(enemy_units, '[]'::jsonb);
  v_duration_days integer := greatest(1, coalesce(duration_days, 7));
  v_radius integer;
  v_step integer;
  v_angle double precision;
  v_candidate_x double precision;
  v_candidate_y double precision;
  v_best_x double precision;
  v_best_y double precision;
  v_score double precision;
  v_best_score double precision := -1;
  v_node_clearance double precision;
  v_edge_clearance double precision;
  v_link_node_clearance double precision;
  v_link_edge_clearance double precision;
  v_base_slug text;
  v_system_slug text;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede crear misiones narrativas';
  end if;

  if length(v_name) < 3 then
    raise exception 'El nombre de la mision debe tener al menos 3 caracteres';
  end if;

  if length(v_description) < 8 then
    raise exception 'La descripcion narrativa debe tener al menos 8 caracteres';
  end if;

  if jsonb_typeof(v_enemy_units) <> 'array' then
    raise exception 'La lista de tropas enemigas debe ser un array JSON';
  end if;

  select *
  into v_anchor
  from public.systems
  where id = anchor_system_id
  for update;

  if not found then
    raise exception 'Sistema de anclaje invalido';
  end if;

  if coalesce(v_anchor.system_kind, 'standard') = 'gaseous'
    or coalesce(v_anchor.is_temporary_mission, false) then
    raise exception 'La mision debe conectarse a un sistema normal';
  end if;

  select *
  into v_faction
  from public.factions
  where id = narrative_faction_id
    and is_narrative = true;

  if not found then
    raise exception 'La faccion seleccionada no es una amenaza narrativa valida';
  end if;

  for v_radius in select unnest(array[135, 170, 210, 255, 305])
  loop
    for v_step in 0..47
    loop
      v_angle := (v_step::double precision / 48) * pi() * 2 + (v_radius::double precision * 0.011);
      v_candidate_x := v_anchor.x::double precision + cos(v_angle) * v_radius;
      v_candidate_y := v_anchor.y::double precision + sin(v_angle) * v_radius;

      select coalesce(min(sqrt(power(systems.x::double precision - v_candidate_x, 2) + power(systems.y::double precision - v_candidate_y, 2))), 9999)
      into v_node_clearance
      from public.systems
      where (
        not coalesce(systems.is_temporary_mission, false)
        or systems.temporary_mission_status = 'active'
      );

      select coalesce(min(public.distance_point_to_segment(
        v_candidate_x,
        v_candidate_y,
        from_systems.x::double precision,
        from_systems.y::double precision,
        to_systems.x::double precision,
        to_systems.y::double precision
      )), 9999)
      into v_edge_clearance
      from public.system_edges
      join public.systems as from_systems on from_systems.id = system_edges.from_system_id
      join public.systems as to_systems on to_systems.id = system_edges.to_system_id
      where (
        not coalesce(from_systems.is_temporary_mission, false)
        or from_systems.temporary_mission_status = 'active'
      )
        and (
          not coalesce(to_systems.is_temporary_mission, false)
          or to_systems.temporary_mission_status = 'active'
        );

      select coalesce(min(public.distance_point_to_segment(
        systems.x::double precision,
        systems.y::double precision,
        v_anchor.x::double precision,
        v_anchor.y::double precision,
        v_candidate_x,
        v_candidate_y
      )), 9999)
      into v_link_node_clearance
      from public.systems
      where systems.id <> v_anchor.id
        and (
          not coalesce(systems.is_temporary_mission, false)
          or systems.temporary_mission_status = 'active'
        );

      select coalesce(min(public.segments_intersect_or_close(
        v_anchor.x::double precision,
        v_anchor.y::double precision,
        v_candidate_x,
        v_candidate_y,
        from_systems.x::double precision,
        from_systems.y::double precision,
        to_systems.x::double precision,
        to_systems.y::double precision
      )), 9999)
      into v_link_edge_clearance
      from public.system_edges
      join public.systems as from_systems on from_systems.id = system_edges.from_system_id
      join public.systems as to_systems on to_systems.id = system_edges.to_system_id
      where system_edges.from_system_id <> v_anchor.id
        and system_edges.to_system_id <> v_anchor.id
        and (
          not coalesce(from_systems.is_temporary_mission, false)
          or from_systems.temporary_mission_status = 'active'
        )
        and (
          not coalesce(to_systems.is_temporary_mission, false)
          or to_systems.temporary_mission_status = 'active'
        );

      v_score := least(
        v_node_clearance,
        v_edge_clearance * 1.2,
        v_link_node_clearance * 1.1,
        v_link_edge_clearance * 1.05
      );

      if v_score > v_best_score then
        v_best_score := v_score;
        v_best_x := v_candidate_x;
        v_best_y := v_candidate_y;
      end if;
    end loop;
  end loop;

  v_base_slug := trim(both '-' from regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
  v_system_slug := 'mission-' || coalesce(nullif(v_base_slug, ''), 'objetivo') || '-' || substr(v_system_id::text, 1, 8);

  insert into public.systems (
    id,
    slug,
    name,
    x,
    y,
    size,
    star_class,
    type,
    status,
    controller_faction_id,
    public_description,
    is_capital,
    building_slots,
    system_kind,
    is_conquerable,
    allows_shared_occupation,
    is_temporary_mission,
    mission_threat_faction_id,
    mission_enemy_units_visible,
    mission_enemy_units,
    mission_expires_at,
    mission_expires_after_battle,
    temporary_mission_status
  )
  values (
    v_system_id,
    v_system_slug,
    v_name,
    round(v_best_x::numeric, 2),
    round(v_best_y::numeric, 2),
    1.05,
    case when v_faction.slug = 'tiranidos' then 'violet' else 'green' end,
    'Mision narrativa temporal',
    'controlled',
    v_faction.id,
    v_description,
    false,
    0,
    'standard',
    true,
    false,
    true,
    v_faction.id,
    coalesce(enemy_units_visible, false),
    v_enemy_units,
    now() + make_interval(days => v_duration_days),
    coalesce(expires_after_battle, true),
    'active'
  );

  insert into public.system_edges (
    slug,
    from_system_id,
    to_system_id,
    uridium_cost,
    is_blocked
  )
  values (
    'mission-route-' || substr(v_system_id::text, 1, 8),
    v_anchor.id,
    v_system_id,
    1,
    false
  );

  insert into public.system_production (system_id)
  values (v_system_id)
  on conflict (system_id) do nothing;

  insert into public.missions (
    id,
    system_id,
    title,
    narrative_description,
    recommended_points,
    objectives,
    special_rules,
    victory_conditions,
    admin_notes
  )
  values (
    v_mission_id,
    v_system_id,
    v_name,
    v_description,
    'Evento narrativo',
    'Atacar el sistema temporal y resolver la batalla fisica con el administrador.',
    'La amenaza narrativa esta controlada por el administrador.',
    'El administrador aplica el resultado narrativo tras el reporte.',
    jsonb_build_object(
      'anchor_system_id', v_anchor.id,
      'narrative_faction_id', v_faction.id,
      'enemy_units_visible', coalesce(enemy_units_visible, false),
      'duration_days', v_duration_days,
      'expires_after_battle', coalesce(expires_after_battle, true),
      'placement_score', v_best_score
    )::text
  );

  update public.systems
  set mission_id = v_mission_id
  where id = v_system_id;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_narrative_mission_created',
    jsonb_build_object(
      'system_id', v_system_id,
      'mission_id', v_mission_id,
      'anchor_system_id', v_anchor.id,
      'narrative_faction_id', v_faction.id,
      'enemy_units_visible', coalesce(enemy_units_visible, false),
      'enemy_units', v_enemy_units,
      'mission_expires_at', now() + make_interval(days => v_duration_days),
      'expires_after_battle', coalesce(expires_after_battle, true),
      'placement_score', v_best_score
    )
  );

  return v_system_id;
end;
$$;

create or replace function public.admin_create_narrative_mission(
  anchor_system_id uuid,
  narrative_faction_id uuid,
  mission_name text,
  mission_description text,
  enemy_units_visible boolean default false,
  enemy_units jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.admin_create_narrative_mission(
    anchor_system_id,
    narrative_faction_id,
    mission_name,
    mission_description,
    enemy_units_visible,
    enemy_units,
    7,
    true
  );
end;
$$;

revoke execute on function public.cleanup_temporary_mission(uuid, text) from public;
revoke execute on function public.resolve_temporary_missions() from public;
revoke execute on function public.admin_remove_temporary_mission(uuid) from public;
revoke execute on function public.admin_create_narrative_mission(uuid, uuid, text, text, boolean, jsonb, integer, boolean) from public;
revoke execute on function public.admin_create_narrative_mission(uuid, uuid, text, text, boolean, jsonb) from public;

grant execute on function public.resolve_temporary_missions() to authenticated;
grant execute on function public.admin_remove_temporary_mission(uuid) to authenticated;
grant execute on function public.admin_create_narrative_mission(uuid, uuid, text, text, boolean, jsonb, integer, boolean) to authenticated;
grant execute on function public.admin_create_narrative_mission(uuid, uuid, text, text, boolean, jsonb) to authenticated;
