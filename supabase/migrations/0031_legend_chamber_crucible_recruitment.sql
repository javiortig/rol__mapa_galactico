create or replace function public.apply_legend_chamber_crucible_recruitment()
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
    30,
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
      research_time_seconds = excluded.research_time_seconds,
      icon_key = excluded.icon_key,
      effect_summary = excluded.effect_summary,
      is_starter = excluded.is_starter,
      implementation_status = excluded.implementation_status,
      updated_at = now();

  delete from public.technology_prerequisites
  where technology_node_id = public.seed_uuid('technology_node', 'camara-leyendas');

  insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
  values (
    public.seed_uuid('technology_node', 'camara-leyendas'),
    public.seed_uuid('technology_node', 'asamblea-planetaria'),
    1
  )
  on conflict (technology_node_id, required_node_id) do update
  set prerequisite_group = excluded.prerequisite_group;

  insert into public.technology_effects (id, technology_node_id, effect_type, payload)
  values (
    public.seed_uuid('technology_effect', 'camara-leyendas-building'),
    public.seed_uuid('technology_node', 'camara-leyendas'),
    'unlock_building_template',
    '{"building_template_slugs":["camara-leyendas"]}'::jsonb
  )
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
    12,
    12,
    3,
    2,
    8,
    0,
    0,
    30,
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

  perform public.refresh_available_technologies(factions.id)
  from public.factions;
end;
$$;

revoke execute on function public.apply_legend_chamber_crucible_recruitment() from public;
revoke execute on function public.apply_legend_chamber_crucible_recruitment() from anon;
revoke execute on function public.apply_legend_chamber_crucible_recruitment() from authenticated;

select public.apply_legend_chamber_crucible_recruitment();

create or replace function public.enforce_recruitment_queue_building_compatibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_template record;
  v_building record;
  v_required_building_name text;
begin
  if new.system_building_id is null or new.unit_template_id is null then
    return new;
  end if;

  select
    unit_templates.name,
    unit_templates.category,
    unit_templates.recruitment_building_type
  into v_template
  from public.unit_templates
  where unit_templates.id = new.unit_template_id;

  select
    building_templates.slug,
    building_templates.name,
    building_templates.allowed_unit_categories
  into v_building
  from public.system_buildings
  join public.building_templates on building_templates.id = system_buildings.building_template_id
  where system_buildings.id = new.system_building_id;

  if not found then
    raise exception 'Edificio de reclutamiento no encontrado';
  end if;

  if v_template.recruitment_building_type is not null then
    if v_template.recruitment_building_type <> v_building.slug then
      select name
      into v_required_building_name
      from public.building_templates
      where slug = v_template.recruitment_building_type;

      raise exception 'La unidad % requiere %', v_template.name, coalesce(v_required_building_name, v_template.recruitment_building_type);
    end if;
  elsif not (v_template.category = any(v_building.allowed_unit_categories)) then
    raise exception 'Este edificio no puede reclutar esa categoria';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_recruitment_queue_building_compatibility_trigger on public.recruitment_queue;
create trigger enforce_recruitment_queue_building_compatibility_trigger
before insert or update of system_building_id, unit_template_id
on public.recruitment_queue
for each row
execute function public.enforce_recruitment_queue_building_compatibility();

create or replace function public.enforce_recovery_queue_building_compatibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_unit record;
  v_building record;
  v_required_building_name text;
begin
  if new.system_building_id is null or new.campaign_unit_id is null then
    return new;
  end if;

  select
    campaign_units.name,
    coalesce(unit_templates.category, campaign_units.category) as category,
    unit_templates.recruitment_building_type
  into v_unit
  from public.campaign_units
  left join public.unit_templates on unit_templates.id = campaign_units.unit_template_id
  where campaign_units.id = new.campaign_unit_id;

  select
    building_templates.slug,
    building_templates.name,
    building_templates.allowed_unit_categories
  into v_building
  from public.system_buildings
  join public.building_templates on building_templates.id = system_buildings.building_template_id
  where system_buildings.id = new.system_building_id;

  if not found then
    raise exception 'Edificio de reabastecimiento no encontrado';
  end if;

  if v_unit.recruitment_building_type is not null then
    if v_unit.recruitment_building_type <> v_building.slug then
      select name
      into v_required_building_name
      from public.building_templates
      where slug = v_unit.recruitment_building_type;

      raise exception 'La unidad % debe reabastecerse en %', v_unit.name, coalesce(v_required_building_name, v_unit.recruitment_building_type);
    end if;
  elsif not (v_unit.category = any(v_building.allowed_unit_categories)) then
    raise exception 'Este edificio no puede reabastecer esa categoria';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_recovery_queue_building_compatibility_trigger on public.unit_recovery_queue;
create trigger enforce_recovery_queue_building_compatibility_trigger
before insert or update of system_building_id, campaign_unit_id
on public.unit_recovery_queue
for each row
execute function public.enforce_recovery_queue_building_compatibility();
