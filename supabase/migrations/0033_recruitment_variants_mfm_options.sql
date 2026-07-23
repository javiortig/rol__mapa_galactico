create table if not exists public.unit_template_model_options (
  id uuid primary key default gen_random_uuid(),
  unit_template_id uuid not null references public.unit_templates(id) on delete cascade,
  slug text not null,
  label text not null,
  models integer not null check (models > 0),
  min_models integer not null check (min_models > 0),
  max_models integer not null check (max_models >= min_models),
  points integer not null check (points >= 0),
  copy_from integer not null default 1 check (copy_from > 0),
  copy_to integer null check (copy_to is null or copy_to >= copy_from),
  source text not null default 'mfm',
  points_change_direction text null,
  points_change_amount integer null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit_template_id, slug)
);

create table if not exists public.unit_template_wargear_options (
  id uuid primary key default gen_random_uuid(),
  unit_template_id uuid not null references public.unit_templates(id) on delete cascade,
  slug text not null,
  name text not null,
  points integer not null check (points >= 0),
  pricing text not null default 'per_option',
  source text not null default 'mfm',
  points_change_direction text null,
  points_change_amount integer null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit_template_id, slug)
);

create index if not exists unit_template_model_options_template_idx
on public.unit_template_model_options (unit_template_id);

create index if not exists unit_template_wargear_options_template_idx
on public.unit_template_wargear_options (unit_template_id);

grant select on public.unit_template_model_options to authenticated;
grant select on public.unit_template_wargear_options to authenticated;

alter table public.unit_template_model_options enable row level security;
alter table public.unit_template_wargear_options enable row level security;

drop policy if exists unit_template_model_options_select_authenticated on public.unit_template_model_options;
create policy unit_template_model_options_select_authenticated
on public.unit_template_model_options
for select
to authenticated
using (true);

drop policy if exists unit_template_wargear_options_select_authenticated on public.unit_template_wargear_options;
create policy unit_template_wargear_options_select_authenticated
on public.unit_template_wargear_options
for select
to authenticated
using (true);

alter table public.recruitment_queue
add column if not exists selected_model_count integer,
add column if not exists selected_points integer,
add column if not exists selected_model_option_id uuid references public.unit_template_model_options(id) on delete set null,
add column if not exists selected_wargear_points integer not null default 0,
add column if not exists selected_wargear_options jsonb not null default '[]'::jsonb,
add column if not exists point_cost_breakdown jsonb not null default '{}'::jsonb;

alter table public.campaign_units
add column if not exists selected_model_option_id uuid references public.unit_template_model_options(id) on delete set null,
add column if not exists selected_wargear_points integer not null default 0,
add column if not exists selected_wargear_options jsonb not null default '[]'::jsonb,
add column if not exists point_cost_breakdown jsonb not null default '{}'::jsonb;

create or replace function public.recruitment_cost_bundle_for_points(
  points integer,
  unit_keywords text[],
  category text
)
returns table (
  supply_cost integer,
  minerals_cost integer,
  honor_cost integer,
  gold_cost integer,
  industrial_material_cost integer,
  uridium_cost integer,
  technology_cost integer
)
language plpgsql
immutable
set search_path = public
as $$
declare
  v_points integer := greatest(coalesce(points, 0), 0);
  v_keywords text[] := coalesce(unit_keywords, array[]::text[]);
  v_category text := coalesce(category, '');
  v_minerals_ratio numeric := 0.2;
  v_honor_ratio numeric := 0.05;
  v_gold_ratio numeric := 0;
begin
  if v_keywords @> array['Caracter']::text[] and v_keywords @> array['Vehiculo']::text[] then
    v_minerals_ratio := 0.45;
    v_honor_ratio := 0.3;
    v_gold_ratio := 0.1;
  elsif v_keywords @> array['Caracter']::text[] then
    v_minerals_ratio := 0.25;
    v_honor_ratio := 0.35;
    v_gold_ratio := 0.15;
  elsif v_keywords @> array['Vehiculo']::text[]
     or v_keywords @> array['Aeronave']::text[]
     or v_keywords @> array['Fortificacion']::text[] then
    v_minerals_ratio := 0.7;
    v_honor_ratio := 0.1;
    v_gold_ratio := case when v_category = 'Aliada' then 0.1 else 0.05 end;
  elsif v_keywords @> array['Bestia']::text[] then
    v_minerals_ratio := 0.15;
    v_honor_ratio := 0.3;
    v_gold_ratio := case when v_category = 'Aliada' then 0.05 else 0 end;
  elsif v_keywords @> array['Montado']::text[] then
    v_minerals_ratio := 0.45;
    v_honor_ratio := 0.1;
    v_gold_ratio := case when v_category = 'Aliada' then 0.05 else 0 end;
  elsif v_category = 'Aliada' then
    v_minerals_ratio := 0.25;
    v_honor_ratio := 0.15;
    v_gold_ratio := 0.1;
  end if;

  minerals_cost := floor((v_points::numeric * v_minerals_ratio) / 2)::integer;
  honor_cost := floor((v_points::numeric * v_honor_ratio) / 5)::integer;
  gold_cost := floor((v_points::numeric * v_gold_ratio) / 5)::integer;
  supply_cost := v_points - minerals_cost * 2 - honor_cost * 5 - gold_cost * 5;
  industrial_material_cost := 0;
  uridium_cost := 0;
  technology_cost := 0;

  return next;
end;
$$;

create or replace function public.faction_army_points(target_faction_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((
      select sum(campaign_units.points)
      from public.campaign_units
      where campaign_units.faction_id = target_faction_id
        and campaign_units.status <> 'destroyed'
        and campaign_units.quantity > 0
    ), 0)::integer
    +
    coalesce((
      select sum(coalesce(recruitment_queue.selected_points, unit_templates.points) * greatest(coalesce(recruitment_queue.quantity, 1), 1))
      from public.recruitment_queue
      join public.unit_templates on unit_templates.id = recruitment_queue.unit_template_id
      where recruitment_queue.faction_id = target_faction_id
        and recruitment_queue.status = 'queued'
    ), 0)::integer;
$$;

create or replace function public.enforce_recruitment_points_cap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_points integer;
  v_new_points integer;
  v_max_points integer;
begin
  if new.status <> 'queued' then
    return new;
  end if;

  select coalesce(max_army_points, 1000)
  into v_max_points
  from public.campaign_settings
  where id = 'default';

  select public.faction_army_points(new.faction_id)
  into v_current_points;

  select coalesce(new.selected_points, unit_templates.points, 0) * greatest(coalesce(new.quantity, 1), 1)
  into v_new_points
  from public.unit_templates
  where id = new.unit_template_id;

  if coalesce(v_current_points, 0) + coalesce(v_new_points, 0) > coalesce(v_max_points, 1000) then
    raise exception 'Limite de puntos de ejercito superado (%/% pts)', coalesce(v_current_points, 0) + coalesce(v_new_points, 0), coalesce(v_max_points, 1000);
  end if;

  return new;
end;
$$;

create or replace function public.recruit_unit_variant_at_building(
  system_building_id uuid,
  unit_template_id uuid,
  model_count integer default null,
  wargear_selections jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_template public.unit_templates%rowtype;
  v_resources public.faction_resources%rowtype;
  v_building record;
  v_model_option public.unit_template_model_options%rowtype;
  v_queue_id uuid;
  v_model_count integer;
  v_copy_index integer;
  v_base_points integer;
  v_wargear_points integer := 0;
  v_total_points integer;
  v_selected_wargear jsonb := '[]'::jsonb;
  v_seen_wargear jsonb := '{}'::jsonb;
  v_selection jsonb;
  v_wargear_slug text;
  v_wargear_quantity integer;
  v_wargear public.unit_template_wargear_options%rowtype;
  v_costs record;
  v_supply_cost integer;
  v_minerals_cost integer;
  v_honor_cost integer;
  v_gold_cost integer;
  v_industrial_material_cost integer;
  v_uridium_cost integer;
  v_technology_cost integer;
  v_recruitment_seconds integer;
  v_effect record;
  v_percent integer;
  v_category text;
  v_resource text;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  perform public.resolve_building_construction();
  perform public.resolve_technology_research();
  perform public.resolve_recruitment_queue();
  perform public.resolve_unit_recovery_queue();

  if wargear_selections is null then
    wargear_selections := '[]'::jsonb;
  end if;

  if jsonb_typeof(wargear_selections) <> 'array' then
    raise exception 'Las opciones de equipo deben enviarse como lista';
  end if;

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  select
    system_buildings.*,
    systems.controller_faction_id,
    systems.status as system_status,
    systems.blocked_until,
    building_templates.slug as building_slug,
    building_templates.building_kind,
    building_templates.allowed_unit_categories
  into v_building
  from public.system_buildings
  join public.systems on systems.id = system_buildings.system_id
  join public.building_templates on building_templates.id = system_buildings.building_template_id
  where system_buildings.id = recruit_unit_variant_at_building.system_building_id
  for update of system_buildings;

  if not found then
    raise exception 'Edificio no encontrado';
  end if;

  if exists (
    select 1 from public.recruitment_queue
    where recruitment_queue.system_building_id = v_building.id and recruitment_queue.status = 'queued'
  ) or exists (
    select 1 from public.unit_recovery_queue
    where unit_recovery_queue.system_building_id = v_building.id and unit_recovery_queue.status = 'queued'
  ) then
    raise exception 'Este edificio ya tiene una cola activa';
  end if;

  if v_building.status <> 'active' then
    raise exception 'El edificio no esta activo';
  end if;

  if v_building.building_kind <> 'recruitment' then
    raise exception 'Este edificio no recluta unidades';
  end if;

  if v_building.controller_faction_id is distinct from v_faction_id or v_building.system_status <> 'controlled' then
    raise exception 'El edificio no pertenece a un sistema controlado por tu faccion';
  end if;

  if v_building.blocked_until is not null and v_building.blocked_until > now() then
    raise exception 'El sistema esta bloqueado';
  end if;

  select *
  into v_template
  from public.unit_templates
  where id = recruit_unit_variant_at_building.unit_template_id
    and faction_id = v_faction_id
    and is_available = true;

  if not found then
    raise exception 'Unidad no disponible';
  end if;

  if v_template.recruitment_building_type is not null then
    if v_template.recruitment_building_type <> v_building.building_slug then
      raise exception 'Esta unidad requiere otro edificio de reclutamiento';
    end if;
  elsif not (v_template.category = any(v_building.allowed_unit_categories)) then
    raise exception 'Este edificio no puede reclutar esa categoria';
  end if;

  if v_template.required_technology_node_id is not null
    and not exists (
      select 1
      from public.faction_technologies
      where faction_id = v_faction_id
        and technology_node_id = v_template.required_technology_node_id
        and status = 'unlocked'
    ) then
    raise exception 'Esta unidad requiere tecnologia desbloqueada';
  end if;

  v_model_count := coalesce(model_count, v_template.default_quantity);

  if v_model_count is null or v_model_count < 1 then
    raise exception 'Numero de miniaturas invalido';
  end if;

  select
    coalesce((
      select count(*)
      from public.campaign_units
      where faction_id = v_faction_id
        and unit_template_id = v_template.id
        and status <> 'destroyed'
        and quantity > 0
    ), 0)
    +
    coalesce((
      select sum(greatest(coalesce(quantity, 1), 1))
      from public.recruitment_queue
      where faction_id = v_faction_id
        and unit_template_id = v_template.id
        and status = 'queued'
    ), 0)
    + 1
  into v_copy_index;

  select *
  into v_model_option
  from public.unit_template_model_options
  where unit_template_id = v_template.id
    and min_models <= v_model_count
    and max_models >= v_model_count
    and copy_from <= v_copy_index
    and (copy_to is null or v_copy_index <= copy_to)
  order by copy_from desc, max_models asc, min_models desc
  limit 1;

  if found then
    v_base_points := v_model_option.points;
  elsif exists (select 1 from public.unit_template_model_options where unit_template_id = v_template.id) then
    raise exception 'Tamano de unidad no permitido por MFM para esta unidad';
  else
    if v_model_count <> v_template.default_quantity then
      raise exception 'Esta unidad no tiene tamanos alternativos registrados';
    end if;
    v_base_points := v_template.points;
  end if;

  for v_selection in select value from jsonb_array_elements(wargear_selections)
  loop
    v_wargear_slug := nullif(trim(coalesce(v_selection->>'slug', '')), '');
    v_wargear_quantity := coalesce((v_selection->>'quantity')::integer, 1);

    if v_wargear_slug is null or v_wargear_quantity <= 0 then
      continue;
    end if;

    if v_seen_wargear ? v_wargear_slug then
      raise exception 'Opcion de equipo duplicada: %', v_wargear_slug;
    end if;

    if v_wargear_quantity > greatest(1, v_model_count) then
      raise exception 'Demasiadas opciones de equipo para %', v_wargear_slug;
    end if;

    select *
    into v_wargear
    from public.unit_template_wargear_options
    where unit_template_id = v_template.id
      and slug = v_wargear_slug;

    if not found then
      raise exception 'Opcion de equipo no valida para esta unidad: %', v_wargear_slug;
    end if;

    v_seen_wargear := v_seen_wargear || jsonb_build_object(v_wargear_slug, true);
    v_wargear_points := v_wargear_points + v_wargear.points * v_wargear_quantity;
    v_selected_wargear := v_selected_wargear || jsonb_build_array(jsonb_build_object(
      'slug', v_wargear.slug,
      'name', v_wargear.name,
      'points', v_wargear.points,
      'quantity', v_wargear_quantity,
      'totalPoints', v_wargear.points * v_wargear_quantity
    ));
  end loop;

  v_total_points := v_base_points + v_wargear_points;

  select *
  into v_costs
  from public.recruitment_cost_bundle_for_points(v_total_points, v_template.unit_keywords, v_template.category);

  v_supply_cost := v_costs.supply_cost;
  v_minerals_cost := v_costs.minerals_cost;
  v_honor_cost := v_costs.honor_cost;
  v_gold_cost := v_costs.gold_cost;
  v_industrial_material_cost := v_costs.industrial_material_cost;
  v_uridium_cost := v_costs.uridium_cost;
  v_technology_cost := v_costs.technology_cost;
  v_recruitment_seconds := v_template.recruitment_time_seconds;

  for v_effect in
    select technology_effects.*
    from public.technology_effects
    join public.faction_technologies
      on faction_technologies.technology_node_id = technology_effects.technology_node_id
    where faction_technologies.faction_id = v_faction_id
      and faction_technologies.status = 'unlocked'
      and technology_effects.effect_type in ('recruitment_cost_discount', 'recruitment_time_discount')
    order by technology_effects.created_at, technology_effects.id
  loop
    v_percent := greatest(0, least(90, coalesce((v_effect.payload->>'percent')::integer, 0)));
    v_category := coalesce(v_effect.payload->>'category', 'all');
    v_resource := coalesce(v_effect.payload->>'resource', 'all');

    if v_percent <= 0 or (v_category <> 'all' and v_category <> v_template.category) then
      continue;
    end if;

    if v_effect.effect_type = 'recruitment_time_discount' then
      v_recruitment_seconds := greatest(1, ceil((v_recruitment_seconds::numeric * (100 - v_percent)) / 100)::integer);
    elsif v_effect.effect_type = 'recruitment_cost_discount' then
      if v_resource in ('all', 'supply') and v_supply_cost > 0 then
        v_supply_cost := greatest(1, floor((v_supply_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'minerals') and v_minerals_cost > 0 then
        v_minerals_cost := greatest(1, floor((v_minerals_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'honor', 'ancestralStone', 'ancestral_stone') and v_honor_cost > 0 then
        v_honor_cost := greatest(1, floor((v_honor_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'gold') and v_gold_cost > 0 then
        v_gold_cost := greatest(1, floor((v_gold_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
    end if;
  end loop;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
  end if;

  if v_resources.supply < v_supply_cost
    or v_resources.minerals < v_minerals_cost
    or v_resources.honor < v_honor_cost
    or v_resources.gold < v_gold_cost
    or v_resources.industrial_material < v_industrial_material_cost
    or v_resources.uridium < v_uridium_cost
    or v_resources.technology < v_technology_cost then
    raise exception 'Recursos insuficientes';
  end if;

  update public.faction_resources
  set
    supply = supply - v_supply_cost,
    minerals = minerals - v_minerals_cost,
    honor = honor - v_honor_cost,
    gold = gold - v_gold_cost,
    industrial_material = industrial_material - v_industrial_material_cost,
    uridium = uridium - v_uridium_cost,
    technology = technology - v_technology_cost,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.recruitment_queue (
    faction_id,
    unit_template_id,
    quantity,
    supply_cost,
    minerals_cost,
    ancestral_stone_cost,
    honor_cost,
    gold_cost,
    industrial_material_cost,
    uridium_cost,
    technology_cost,
    system_building_id,
    origin_system_id,
    selected_model_count,
    selected_points,
    selected_model_option_id,
    selected_wargear_points,
    selected_wargear_options,
    point_cost_breakdown,
    started_at,
    finishes_at,
    status
  )
  values (
    v_faction_id,
    v_template.id,
    1,
    v_supply_cost,
    v_minerals_cost,
    0,
    v_honor_cost,
    v_gold_cost,
    v_industrial_material_cost,
    v_uridium_cost,
    v_technology_cost,
    v_building.id,
    v_building.system_id,
    v_model_count,
    v_total_points,
    case when v_model_option.id is null then null else v_model_option.id end,
    v_wargear_points,
    v_selected_wargear,
    jsonb_build_object('basePoints', v_base_points, 'wargearPoints', v_wargear_points, 'copyIndex', v_copy_index),
    now(),
    now() + make_interval(secs => v_recruitment_seconds),
    'queued'
  )
  returning id into v_queue_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'recruitment_started',
    jsonb_build_object(
      'queue_id', v_queue_id,
      'system_building_id', v_building.id,
      'origin_system_id', v_building.system_id,
      'unit_template_id', v_template.id,
      'unit_name', v_template.name,
      'model_count', v_model_count,
      'points', v_total_points,
      'wargear', v_selected_wargear,
      'duration_seconds', v_recruitment_seconds
    )
  );

  return v_queue_id;
end;
$$;

create or replace function public.recruit_unit_at_building(system_building_id uuid, unit_template_id uuid, quantity integer)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if quantity is null or quantity < 1 then
    raise exception 'Cantidad invalida';
  end if;

  if quantity <> 1 then
    raise exception 'Cada edificio solo puede reclutar una unidad por cola';
  end if;

  return public.recruit_unit_variant_at_building(system_building_id, unit_template_id, null, '[]'::jsonb);
end;
$$;

create or replace function public.resupply_unit_at_building(system_building_id uuid, campaign_unit_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_building record;
  v_unit public.campaign_units%rowtype;
  v_template public.unit_templates%rowtype;
  v_resources public.faction_resources%rowtype;
  v_costs record;
  v_supply_cost integer;
  v_minerals_cost integer;
  v_honor_cost integer;
  v_gold_cost integer;
  v_industrial_material_cost integer;
  v_uridium_cost integer;
  v_technology_cost integer;
  v_queue_id uuid;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  perform public.resolve_unit_recovery_queue();
  perform public.resolve_building_construction();
  perform public.resolve_recruitment_queue();

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  select
    system_buildings.*,
    systems.controller_faction_id,
    systems.status as system_status,
    systems.blocked_until,
    building_templates.slug as building_slug,
    building_templates.building_kind,
    building_templates.allowed_unit_categories,
    building_templates.construction_time_seconds
  into v_building
  from public.system_buildings
  join public.systems on systems.id = system_buildings.system_id
  join public.building_templates on building_templates.id = system_buildings.building_template_id
  where system_buildings.id = resupply_unit_at_building.system_building_id
  for update of system_buildings;

  if not found then
    raise exception 'Edificio no encontrado';
  end if;

  if exists (
    select 1 from public.recruitment_queue
    where system_building_id = v_building.id and status = 'queued'
  ) or exists (
    select 1 from public.unit_recovery_queue
    where system_building_id = v_building.id and status = 'queued'
  ) then
    raise exception 'Este edificio ya tiene una cola activa';
  end if;

  if v_building.status <> 'active' or v_building.building_kind <> 'recruitment' then
    raise exception 'Este edificio no puede reabastecer unidades';
  end if;

  if v_building.controller_faction_id is distinct from v_faction_id or v_building.system_status <> 'controlled' then
    raise exception 'El edificio no pertenece a un sistema controlado por tu faccion';
  end if;

  if v_building.blocked_until is not null and v_building.blocked_until > now() then
    raise exception 'El sistema esta bloqueado';
  end if;

  select *
  into v_unit
  from public.campaign_units
  where id = resupply_unit_at_building.campaign_unit_id
    and faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'Unidad no encontrada';
  end if;

  if v_unit.status <> 'ready' then
    raise exception 'La unidad no esta disponible para reabastecerse';
  end if;

  if v_unit.current_system_id is distinct from v_building.system_id then
    raise exception 'La unidad no esta en el mismo sistema que el edificio';
  end if;

  if v_unit.quantity >= v_unit.starting_quantity and v_unit.wounds_taken <= 0 then
    raise exception 'La unidad ya esta completa';
  end if;

  select *
  into v_template
  from public.unit_templates
  where id = v_unit.unit_template_id;

  if not found then
    raise exception 'La unidad no tiene plantilla de coste';
  end if;

  if v_template.recruitment_building_type is not null then
    if v_template.recruitment_building_type <> v_building.building_slug then
      raise exception 'Este edificio no puede reabastecer esa unidad';
    end if;
  elsif not (v_unit.category = any(v_building.allowed_unit_categories)) then
    raise exception 'Este edificio no puede reabastecer esa categoria';
  end if;

  select *
  into v_costs
  from public.recruitment_cost_bundle_for_points(coalesce(v_unit.points, v_template.points), v_unit.unit_keywords, v_unit.category);

  v_supply_cost := case when v_costs.supply_cost > 0 then ceil(v_costs.supply_cost::numeric / 2)::integer else 0 end;
  v_minerals_cost := case when v_costs.minerals_cost > 0 then ceil(v_costs.minerals_cost::numeric / 2)::integer else 0 end;
  v_honor_cost := case when v_costs.honor_cost > 0 then ceil(v_costs.honor_cost::numeric / 2)::integer else 0 end;
  v_gold_cost := case when v_costs.gold_cost > 0 then ceil(v_costs.gold_cost::numeric / 2)::integer else 0 end;
  v_industrial_material_cost := 0;
  v_uridium_cost := 0;
  v_technology_cost := 0;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if v_resources.supply < v_supply_cost
    or v_resources.minerals < v_minerals_cost
    or v_resources.honor < v_honor_cost
    or v_resources.gold < v_gold_cost
    or v_resources.industrial_material < v_industrial_material_cost
    or v_resources.uridium < v_uridium_cost
    or v_resources.technology < v_technology_cost then
    raise exception 'Recursos insuficientes';
  end if;

  update public.faction_resources
  set
    supply = supply - v_supply_cost,
    minerals = minerals - v_minerals_cost,
    honor = honor - v_honor_cost,
    gold = gold - v_gold_cost,
    industrial_material = industrial_material - v_industrial_material_cost,
    uridium = uridium - v_uridium_cost,
    technology = technology - v_technology_cost,
    updated_at = now()
  where faction_id = v_faction_id;

  update public.campaign_units
  set status = 'recovering', updated_at = now()
  where id = v_unit.id;

  insert into public.unit_recovery_queue (
    faction_id,
    system_building_id,
    campaign_unit_id,
    heal_quantity,
    supply_cost,
    minerals_cost,
    honor_cost,
    gold_cost,
    industrial_material_cost,
    uridium_cost,
    technology_cost,
    started_at,
    finishes_at,
    status
  )
  values (
    v_faction_id,
    v_building.id,
    v_unit.id,
    greatest(1, v_unit.starting_quantity - v_unit.quantity),
    v_supply_cost,
    v_minerals_cost,
    v_honor_cost,
    v_gold_cost,
    v_industrial_material_cost,
    v_uridium_cost,
    v_technology_cost,
    now(),
    now() + make_interval(secs => greatest(3, ceil(v_template.recruitment_time_seconds::numeric / 2)::integer)),
    'queued'
  )
  returning id into v_queue_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'unit_resupply_started',
    jsonb_build_object(
      'unit_recovery_queue_id', v_queue_id,
      'campaign_unit_id', v_unit.id,
      'system_building_id', v_building.id,
      'points', coalesce(v_unit.points, v_template.points),
      'target_quantity', v_unit.starting_quantity,
      'wounds_taken', v_unit.wounds_taken
    )
  );

  return v_queue_id;
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
    order by recruitment_queue.finishes_at
    for update of recruitment_queue
  loop
    v_unit_points := coalesce(v_item.selected_points, v_item.points);
    v_unit_models := coalesce(v_item.selected_model_count, v_item.default_quantity);

    for v_index in 1..v_item.quantity loop
      insert into public.campaign_units (
        slug,
        faction_id,
        unit_template_id,
        name,
        category,
        unit_type,
        unit_keywords,
        points,
        quantity,
        starting_quantity,
        wounds_taken,
        experience,
        current_system_id,
        status,
        is_visible_publicly,
        selected_model_option_id,
        selected_wargear_points,
        selected_wargear_options,
        point_cost_breakdown
      )
      values (
        'recruited-' || v_item.id::text || '-' || v_index::text,
        v_item.faction_id,
        v_item.unit_template_id,
        v_item.unit_name,
        v_item.category,
        v_item.unit_type,
        v_item.unit_keywords,
        v_unit_points,
        v_unit_models,
        v_unit_models,
        0,
        0,
        coalesce(v_item.origin_system_id, v_item.capital_system_id),
        'ready',
        false,
        v_item.selected_model_option_id,
        v_item.selected_wargear_points,
        v_item.selected_wargear_options,
        v_item.point_cost_breakdown
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
          'quantity', v_unit_models,
          'points', v_unit_points,
          'origin_system_id', coalesce(v_item.origin_system_id, v_item.capital_system_id)
        )
      );

      v_created := v_created + 1;
    end loop;

    update public.recruitment_queue
    set status = 'completed',
        updated_at = now()
    where id = v_item.id;
  end loop;

  return v_created;
end;
$$;

revoke execute on function public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb) from public;
revoke execute on function public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb) from anon;
grant execute on function public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb) to authenticated;

revoke execute on function public.resupply_unit_at_building(uuid, uuid) from public;
revoke execute on function public.resupply_unit_at_building(uuid, uuid) from anon;
grant execute on function public.resupply_unit_at_building(uuid, uuid) to authenticated;
