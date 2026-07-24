create or replace function public.apply_building_capacity_production_and_industrial_costs()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.technology_nodes (
    id,
    slug,
    tree_key,
    name,
    description,
    branch,
    tier,
    position_x,
    position_y,
    cost_technology,
    research_time_seconds,
    icon_key,
    effect_summary,
    is_starter,
    implementation_status
  )
  values (
    public.seed_uuid('technology_node', 'camara-leyendas'),
    'camara-leyendas',
    'common-v1',
    'Camara de Leyendas',
    'Archivo sellado de gestas imposibles y protocolos excepcionales para reclutar unidades [Crucible]. Bloqueada por ahora.',
    'Progreso',
    3,
    55,
    22,
    2,
    3,
    'legend_chamber',
    'Permitira construir Camaras de Leyendas para reclutar unidades [Crucible].',
    false,
    'planned'
  )
  on conflict (slug) do update
  set tree_key = excluded.tree_key,
      name = excluded.name,
      description = excluded.description,
      branch = excluded.branch,
      tier = excluded.tier,
      position_x = excluded.position_x,
      position_y = excluded.position_y,
      cost_technology = excluded.cost_technology,
      research_time_seconds = 3,
      icon_key = excluded.icon_key,
      effect_summary = excluded.effect_summary,
      is_starter = excluded.is_starter,
      implementation_status = 'planned',
      updated_at = now();

  insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
  select tech.id, required.id, 1
  from public.technology_nodes tech
  join public.technology_nodes required on required.slug = 'asamblea-planetaria'
  where tech.slug = 'camara-leyendas'
  on conflict (technology_node_id, required_node_id) do update
  set prerequisite_group = excluded.prerequisite_group;

  insert into public.technology_effects (id, technology_node_id, effect_type, payload)
  select
    public.seed_uuid('technology_effect', 'camara-leyendas-building'),
    technology_nodes.id,
    'unlock_building_template',
    '{"building_template_slugs":["camara-leyendas"]}'::jsonb
  from public.technology_nodes
  where technology_nodes.slug = 'camara-leyendas'
  on conflict (id) do update
  set technology_node_id = excluded.technology_node_id,
      effect_type = excluded.effect_type,
      payload = excluded.payload;

  insert into public.building_templates (
    id,
    slug,
    name,
    description,
    category,
    building_kind,
    supply_cost,
    minerals_cost,
    honor_cost,
    gold_cost,
    industrial_material_cost,
    uridium_cost,
    technology_cost,
    construction_time_seconds,
    produced_resource_key,
    produced_amount,
    allowed_unit_categories,
    required_technology_node_id,
    icon_key,
    is_available
  )
  values (
    coalesce((select id from public.building_templates where slug = 'camara-leyendas'), public.seed_uuid('building_template', 'camara-leyendas')),
    'camara-leyendas',
    'Camara de Leyendas',
    'Camara sellada para reclutar unidades [Crucible] cuando su tecnologia deje de estar bloqueada.',
    'Reclutamiento',
    'recruitment',
    0,
    0,
    0,
    0,
    37,
    0,
    0,
    3,
    null,
    0,
    array[
      'Personaje',
      'Linea de batalla',
      'Transporte',
      'Otras hojas de datos',
      'Aliada',
      'Infanteria',
      'Elite',
      'Vehiculo',
      'Monstruo',
      'Hoja de datos',
      'Otro',
      'Superpesado'
    ]::text[],
    public.seed_uuid('technology_node', 'camara-leyendas'),
    'legend_chamber',
    true
  )
  on conflict (slug) do update
  set name = excluded.name,
      description = excluded.description,
      category = excluded.category,
      building_kind = excluded.building_kind,
      supply_cost = excluded.supply_cost,
      minerals_cost = excluded.minerals_cost,
      honor_cost = excluded.honor_cost,
      gold_cost = excluded.gold_cost,
      industrial_material_cost = excluded.industrial_material_cost,
      uridium_cost = excluded.uridium_cost,
      technology_cost = excluded.technology_cost,
      construction_time_seconds = excluded.construction_time_seconds,
      produced_resource_key = excluded.produced_resource_key,
      produced_amount = excluded.produced_amount,
      allowed_unit_categories = excluded.allowed_unit_categories,
      required_technology_node_id = excluded.required_technology_node_id,
      icon_key = excluded.icon_key,
      is_available = excluded.is_available,
      updated_at = now();

  update public.unit_templates
  set recruitment_building_type = 'camara-leyendas'
  where name ilike '%[Crucible]%'
     or slug ilike '%crucible%';

  with building_costs(slug, industrial_material_cost) as (
    values
      ('barracon-infanteria', 24),
      ('cuartel-mando', 27),
      ('camara-leyendas', 37),
      ('taller-guerra', 30),
      ('nido-bestias', 29),
      ('camara-comercio', 21),
      ('nexo-inteligencia', 25),
      ('antenas-reconocimiento', 19),
      ('granja-biologica', 11),
      ('complejo-minero', 14),
      ('refineria-iridium', 17),
      ('mina-oro', 17),
      ('planta-fundicion', 17),
      ('monumento', 22),
      ('santuario-reliquias', 24)
  )
  update public.building_templates
  set supply_cost = 0,
      minerals_cost = 0,
      honor_cost = 0,
      gold_cost = 0,
      industrial_material_cost = building_costs.industrial_material_cost,
      uridium_cost = 0,
      technology_cost = 0,
      produced_amount = case when building_templates.building_kind = 'production' then 0 else building_templates.produced_amount end,
      construction_time_seconds = 3,
      updated_at = now()
  from building_costs
  where building_templates.slug = building_costs.slug;

  perform public.refresh_system_production_from_buildings();
end;
$$;

create or replace function public.refresh_system_production_from_buildings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  insert into public.system_production (
    system_id,
    supply_per_tick,
    minerals_per_tick,
    ancestral_stone_per_tick,
    honor_per_tick,
    gold_per_tick,
    industrial_material_per_tick,
    uridium_per_tick,
    technology_per_tick
  )
  select
    systems.id,
    coalesce(max(case when building_templates.produced_resource_key = 'supply' then capabilities.production_amount end), 0)::integer,
    coalesce(max(case when building_templates.produced_resource_key = 'minerals' then capabilities.production_amount end), 0)::integer,
    0,
    coalesce(max(case when building_templates.produced_resource_key = 'honor' then capabilities.production_amount end), 0)::integer,
    coalesce(max(case when building_templates.produced_resource_key = 'gold' then capabilities.production_amount end), 0)::integer,
    coalesce(max(case when building_templates.produced_resource_key = 'industrial_material' then capabilities.production_amount end), 0)::integer,
    coalesce(max(case when building_templates.produced_resource_key = 'uridium' then capabilities.production_amount end), 0)::integer,
    0
  from public.systems
  left join public.system_buildings
    on system_buildings.system_id = systems.id
    and system_buildings.status = 'active'
  left join public.building_templates
    on building_templates.id = system_buildings.building_template_id
    and building_templates.building_kind = 'production'
    and building_templates.produced_resource_key is not null
  left join public.system_resource_capabilities capabilities
    on capabilities.system_id = systems.id
    and capabilities.resource_key = building_templates.produced_resource_key
  group by systems.id
  on conflict (system_id) do update
  set
    supply_per_tick = excluded.supply_per_tick,
    minerals_per_tick = excluded.minerals_per_tick,
    ancestral_stone_per_tick = 0,
    honor_per_tick = excluded.honor_per_tick,
    gold_per_tick = excluded.gold_per_tick,
    industrial_material_per_tick = excluded.industrial_material_per_tick,
    uridium_per_tick = excluded.uridium_per_tick,
    technology_per_tick = 0;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.refresh_system_production_from_buildings() from public;
revoke execute on function public.refresh_system_production_from_buildings() from anon;
revoke execute on function public.refresh_system_production_from_buildings() from authenticated;

select public.apply_building_capacity_production_and_industrial_costs();

drop function public.apply_building_capacity_production_and_industrial_costs();
