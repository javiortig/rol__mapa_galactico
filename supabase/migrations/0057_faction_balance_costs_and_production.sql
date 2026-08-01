create or replace function public.base_system_capacity(
  system_slug text,
  system_kind text,
  is_capital boolean,
  resource_key text
)
returns integer
language plpgsql
immutable
as $$
declare
  v_slug text := coalesce(system_slug, '');
begin
  if coalesce(system_kind, 'standard') = 'gaseous' then
    return 0;
  end if;

  return case v_slug
    when 'mordax' then case resource_key when 'supply' then 13 when 'honor' then 1 when 'industrial_material' then 20 when 'uridium' then 2 else 0 end
    when 'drusus' then case resource_key when 'supply' then 3 when 'minerals' then 5 when 'honor' then 1 when 'industrial_material' then 8 when 'uridium' then 2 else 0 end
    when 'sa-cea-gate' then case resource_key when 'minerals' then 7 when 'honor' then 1 when 'industrial_material' then 20 when 'uridium' then 2 else 0 end
    when 'lyra-terminus' then case resource_key when 'supply' then 12 when 'honor' then 1 when 'industrial_material' then 8 when 'uridium' then 2 else 0 end
    when 'thokt-vault' then case resource_key when 'minerals' then 7 when 'honor' then 1 when 'industrial_material' then 20 when 'uridium' then 2 else 0 end
    when 'novem' then case resource_key when 'supply' then 8 when 'minerals' then 2 when 'honor' then 1 when 'industrial_material' then 8 when 'uridium' then 2 else 0 end
    when 'kharon-prime' then case resource_key when 'minerals' then 7 when 'honor' then 1 when 'industrial_material' then 20 when 'uridium' then 2 else 0 end
    when 'helios-drift' then case resource_key when 'supply' then 10 when 'minerals' then 1 when 'honor' then 1 when 'industrial_material' then 8 when 'uridium' then 2 else 0 end
    when 'blackglass' then case resource_key when 'supply' then 13 when 'honor' then 1 when 'industrial_material' then 20 when 'uridium' then 2 else 0 end
    when 'red-sabbath' then case resource_key when 'supply' then 5 when 'minerals' then 4 when 'honor' then 1 when 'industrial_material' then 8 when 'uridium' then 2 else 0 end
    when 'nexus-aster' then case resource_key when 'minerals' then 4 when 'gold' then 8 when 'industrial_material' then 12 when 'uridium' then 3 else 0 end
    when 'goregate' then case resource_key when 'supply' then 4 when 'honor' then 1 when 'gold' then 8 when 'industrial_material' then 12 when 'uridium' then 3 else 0 end
    else 0
  end;
end;
$$;

create or replace function public.campaign_balance_cost_bundle(
  points integer,
  unit_keywords text[],
  category text,
  unit_name text,
  is_allied_unit boolean,
  tier integer,
  is_branch_final boolean,
  has_gold boolean
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
  v_tier integer := coalesce(tier, 3);
  v_is_advanced boolean := coalesce(tier, 3) >= 3 or coalesce(is_branch_final, false) or greatest(coalesce(points, 0), 0) >= 200;
  v_is_allied boolean := coalesce(is_allied_unit, false) or coalesce(category, '') = 'Aliada';
  v_is_crucible boolean := coalesce(unit_name, '') like '%[Crucible]%';
  v_minerals_ratio numeric := 0.2;
  v_honor_ratio numeric := 0.05;
  v_gold_ratio numeric := 0;
  v_total_ratio numeric;
  v_factor numeric := 1;
begin
  if v_tier = 1
    and v_keywords @> array['Infanteria']::text[]
    and not (v_keywords && array['Caracter','Vehiculo','Aeronave','Fortificacion','Bestia','Montado']::text[]) then
    supply_cost := v_points;
    minerals_cost := 0;
    honor_cost := 0;
    gold_cost := 0;
    industrial_material_cost := 0;
    uridium_cost := 0;
    technology_cost := 0;
    return next;
    return;
  end if;

  if v_keywords @> array['Caracter','Vehiculo']::text[] then
    v_minerals_ratio := 0.35;
    v_honor_ratio := case when v_is_advanced then 0.35 else 0.3 end;
  elsif v_keywords @> array['Caracter']::text[] then
    v_minerals_ratio := case when v_is_advanced then 0.15 else 0.1 end;
    v_honor_ratio := case when v_is_advanced or v_is_crucible then 0.45 else 0.35 end;
  elsif v_keywords @> array['Vehiculo']::text[]
     or v_keywords @> array['Aeronave']::text[]
     or v_keywords @> array['Fortificacion']::text[] then
    v_minerals_ratio := case when v_is_advanced then 0.75 else 0.65 end;
    v_honor_ratio := case when v_is_allied or v_is_advanced then 0.1 else 0.05 end;
  elsif v_keywords @> array['Bestia']::text[] then
    v_minerals_ratio := 0.1;
    v_honor_ratio := case when v_is_advanced then 0.35 else 0.25 end;
  elsif v_keywords @> array['Montado']::text[] then
    v_minerals_ratio := case when v_is_advanced then 0.45 else 0.35 end;
    v_honor_ratio := case when v_is_advanced then 0.1 else 0.05 end;
  elsif v_keywords @> array['Infanteria']::text[] then
    v_minerals_ratio := case when v_tier <= 2 then 0.2 else 0.25 end;
    v_honor_ratio := case when v_tier >= 3 or v_category = 'Otras hojas de datos' then 0.05 else 0 end;
  elsif v_is_allied then
    v_minerals_ratio := 0.25;
    v_honor_ratio := 0.1;
  end if;

  if coalesce(has_gold, false) then
    if v_is_allied or coalesce(is_branch_final, false) or lower(coalesce(unit_name, '')) ~ '(titan|warlord|knight|silent king|c''tan|ctan|be''lakor|kairos)' then
      v_gold_ratio := 0.15;
    elsif v_keywords @> array['Caracter']::text[] then
      v_gold_ratio := 0.1;
    elsif v_keywords @> array['Vehiculo']::text[] or v_keywords @> array['Aeronave']::text[] or v_keywords @> array['Fortificacion']::text[] then
      v_gold_ratio := 0.08;
    else
      v_gold_ratio := 0.05;
    end if;
  end if;

  v_total_ratio := v_minerals_ratio + v_honor_ratio + v_gold_ratio;
  if v_total_ratio > 0.9 then
    v_factor := 0.9 / v_total_ratio;
  end if;

  minerals_cost := floor((v_points::numeric * v_minerals_ratio * v_factor) / 2)::integer;
  honor_cost := floor((v_points::numeric * v_honor_ratio * v_factor) / 5)::integer;
  gold_cost := floor((v_points::numeric * v_gold_ratio * v_factor) / 5)::integer;

  if coalesce(has_gold, false) and v_points >= 5 then
    gold_cost := greatest(1, gold_cost);
  end if;

  while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and gold_cost > 0 loop
    gold_cost := gold_cost - 1;
  end loop;
  while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and honor_cost > 0 loop
    honor_cost := honor_cost - 1;
  end loop;
  while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and minerals_cost > 0 loop
    minerals_cost := minerals_cost - 1;
  end loop;

  supply_cost := v_points - minerals_cost * 2 - honor_cost * 5 - gold_cost * 5;
  industrial_material_cost := 0;
  uridium_cost := 0;
  technology_cost := 0;

  return next;
end;
$$;

create or replace function public.recruitment_cost_bundle_for_template(
  target_unit_template_id uuid,
  selected_points integer
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
stable
security definer
set search_path = public
as $$
declare
  v_template public.unit_templates%rowtype;
  v_points integer;
  v_base_points integer;
begin
  select *
  into v_template
  from public.unit_templates
  where id = target_unit_template_id;

  if not found then
    raise exception 'Unidad no encontrada';
  end if;

  v_points := greatest(coalesce(selected_points, v_template.points, 0), 0);
  v_base_points := greatest(coalesce(v_template.points, 0), 0);

  if v_base_points <= 0 or v_points = v_base_points then
    supply_cost := coalesce(v_template.supply_cost, 0);
    minerals_cost := coalesce(v_template.minerals_cost, 0);
    honor_cost := coalesce(v_template.honor_cost, 0);
    gold_cost := coalesce(v_template.gold_cost, 0);
  else
    minerals_cost := floor(((v_points::numeric * coalesce(v_template.minerals_cost, 0) * 2) / v_base_points) / 2)::integer;
    honor_cost := floor(((v_points::numeric * coalesce(v_template.honor_cost, 0) * 5) / v_base_points) / 5)::integer;
    gold_cost := floor(((v_points::numeric * coalesce(v_template.gold_cost, 0) * 5) / v_base_points) / 5)::integer;

    if coalesce(v_template.gold_cost, 0) > 0 and v_points >= 5 then
      gold_cost := greatest(1, gold_cost);
    end if;

    while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and gold_cost > 0 loop
      gold_cost := gold_cost - 1;
    end loop;
    while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and honor_cost > 0 loop
      honor_cost := honor_cost - 1;
    end loop;
    while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and minerals_cost > 0 loop
      minerals_cost := minerals_cost - 1;
    end loop;

    supply_cost := v_points - minerals_cost * 2 - honor_cost * 5 - gold_cost * 5;
  end if;

  industrial_material_cost := 0;
  uridium_cost := 0;
  technology_cost := 0;

  return next;
end;
$$;

do $$
declare
  v_definition text;
  v_updated text;
begin
  v_definition := pg_get_functiondef('public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb)'::regprocedure);
  v_updated := replace(
    v_definition,
    'from public.recruitment_cost_bundle_for_points(v_total_points, v_template.unit_keywords, v_template.category);',
    'from public.recruitment_cost_bundle_for_template(v_template.id, v_total_points);'
  );

  if v_definition = v_updated then
    raise exception 'No se pudo actualizar recruit_unit_variant_at_building para costes por plantilla';
  end if;

  execute v_updated;

  v_definition := pg_get_functiondef('public.resupply_unit_at_building(uuid, uuid)'::regprocedure);
  v_updated := replace(
    v_definition,
    'from public.recruitment_cost_bundle_for_points(coalesce(v_unit.points, v_template.points), v_unit.unit_keywords, v_unit.category);',
    'from public.recruitment_cost_bundle_for_template(v_template.id, coalesce(v_unit.points, v_template.points));'
  );

  if v_definition = v_updated then
    raise exception 'No se pudo actualizar resupply_unit_at_building para costes por plantilla';
  end if;

  execute v_updated;
end;
$$;

with branch_final_nodes as (
  select id
  from (
    select
      technology_nodes.id,
      row_number() over (
        partition by technology_nodes.tree_key, technology_nodes.branch
        order by technology_nodes.tier desc, technology_nodes.position_y desc, technology_nodes.position_x desc, technology_nodes.name desc
      ) as final_rank
    from public.technology_nodes
    where technology_nodes.tree_key like 'troops-%'
  ) ranked
  where final_rank = 1
),
candidates as (
  select
    unit_templates.id,
    unit_templates.points,
    unit_templates.name,
    unit_templates.category,
    unit_templates.unit_keywords,
    coalesce(unit_templates.is_allied_unit, false) as is_allied_unit,
    coalesce(technology_nodes.tier,
      case
        when unit_templates.category = 'Linea de batalla' and unit_templates.unit_keywords @> array['Infanteria']::text[] then 1
        when unit_templates.unit_keywords && array['Caracter','Vehiculo','Aeronave','Fortificacion']::text[] then 3
        when unit_templates.unit_keywords && array['Bestia','Montado']::text[] then 2
        else 2
      end
    ) as tier,
    branch_final_nodes.id is not null as is_branch_final,
    (
      coalesce(technology_nodes.tier,
        case
          when unit_templates.category = 'Linea de batalla' and unit_templates.unit_keywords @> array['Infanteria']::text[] then 1
          when unit_templates.unit_keywords && array['Caracter','Vehiculo','Aeronave','Fortificacion']::text[] then 3
          when unit_templates.unit_keywords && array['Bestia','Montado']::text[] then 2
          else 2
        end
      ) = 1
      and unit_templates.unit_keywords @> array['Infanteria']::text[]
      and not (unit_templates.unit_keywords && array['Caracter','Vehiculo','Aeronave','Fortificacion','Bestia','Montado']::text[])
    ) as is_initial_basic,
    (
      case when unit_templates.category = 'Aliada' or coalesce(unit_templates.is_allied_unit, false) then 120 else 0 end
      + case when unit_templates.name like '%[Crucible]%' then 95 else 0 end
      + case when branch_final_nodes.id is not null then 85 else 0 end
      + case when lower(unit_templates.name) ~ '(titan|warlord|knight|silent king|c''tan|ctan|be''lakor|kairos|primarch|trajann)' then 70 else 0 end
      + case when unit_templates.points >= 300 then 55 when unit_templates.points >= 200 then 35 else 0 end
      + case when unit_templates.unit_keywords @> array['Caracter']::text[] then 35 else 0 end
      + case when unit_templates.unit_keywords && array['Vehiculo','Aeronave','Fortificacion']::text[] then 30 else 0 end
      + case when unit_templates.unit_keywords @> array['Bestia']::text[] then 20 else 0 end
      + greatest(0, coalesce(technology_nodes.tier, 1) - 1) * 10
    ) as gold_score,
    factions.id as faction_id
  from public.unit_templates
  join public.factions on factions.id = unit_templates.faction_id
  left join public.technology_nodes on technology_nodes.id = unit_templates.required_technology_node_id
  left join branch_final_nodes on branch_final_nodes.id = technology_nodes.id
  where coalesce(factions.is_narrative, false) = false
),
ranked as (
  select
    candidates.*,
    round(count(*) over (partition by faction_id)::numeric * 0.4)::integer as target_gold_units,
    row_number() over (
      partition by faction_id
      order by
        case when is_initial_basic then -1000000 else gold_score end desc,
        tier desc,
        points desc,
        id
    ) as gold_rank
  from candidates
),
balanced as (
  select
    ranked.id,
    costs.*
  from ranked
  cross join lateral public.campaign_balance_cost_bundle(
    ranked.points,
    ranked.unit_keywords,
    ranked.category,
    ranked.name,
    ranked.is_allied_unit,
    ranked.tier,
    ranked.is_branch_final,
    ranked.gold_rank <= ranked.target_gold_units and not ranked.is_initial_basic
  ) costs
)
update public.unit_templates
set
  supply_cost = balanced.supply_cost,
  minerals_cost = balanced.minerals_cost,
  ancestral_stone_cost = 0,
  honor_cost = balanced.honor_cost,
  gold_cost = balanced.gold_cost,
  industrial_material_cost = 0,
  uridium_cost = 0,
  technology_cost = 0
from balanced
where unit_templates.id = balanced.id;

select public.rebuild_system_resource_capabilities();

with managed_systems(slug) as (
  values
    ('mordax'), ('drusus'),
    ('sa-cea-gate'), ('lyra-terminus'),
    ('thokt-vault'), ('novem'),
    ('kharon-prime'), ('helios-drift'),
    ('blackglass'), ('red-sabbath'),
    ('nexus-aster'), ('goregate')
),
deleted as (
  delete from public.system_buildings
  using public.systems, public.building_templates, managed_systems
  where system_buildings.system_id = systems.id
    and system_buildings.building_template_id = building_templates.id
    and systems.slug = managed_systems.slug
    and building_templates.building_kind = 'production'
  returning system_buildings.id
),
desired(system_slug, building_slug) as (
  values
    ('mordax', 'planta-fundicion'), ('mordax', 'monumento'), ('mordax', 'granja-biologica'),
    ('sa-cea-gate', 'planta-fundicion'), ('sa-cea-gate', 'monumento'), ('sa-cea-gate', 'complejo-minero'),
    ('thokt-vault', 'planta-fundicion'), ('thokt-vault', 'monumento'), ('thokt-vault', 'complejo-minero'),
    ('kharon-prime', 'planta-fundicion'), ('kharon-prime', 'monumento'), ('kharon-prime', 'complejo-minero'),
    ('blackglass', 'planta-fundicion'), ('blackglass', 'monumento'), ('blackglass', 'granja-biologica'),
    ('drusus', 'granja-biologica'), ('drusus', 'complejo-minero'), ('drusus', 'monumento'),
    ('lyra-terminus', 'granja-biologica'), ('lyra-terminus', 'monumento'),
    ('novem', 'granja-biologica'), ('novem', 'complejo-minero'), ('novem', 'monumento'),
    ('helios-drift', 'granja-biologica'), ('helios-drift', 'complejo-minero'), ('helios-drift', 'monumento'),
    ('red-sabbath', 'granja-biologica'), ('red-sabbath', 'complejo-minero'), ('red-sabbath', 'monumento'),
    ('nexus-aster', 'complejo-minero'), ('nexus-aster', 'mina-oro'), ('nexus-aster', 'planta-fundicion'),
    ('goregate', 'granja-biologica'), ('goregate', 'mina-oro'), ('goregate', 'monumento')
)
insert into public.system_buildings (
  id,
  system_id,
  building_template_id,
  status,
  started_at,
  finishes_at,
  constructed_at
)
select
  public.seed_uuid('system_building', desired.system_slug || ':' || desired.building_slug),
  systems.id,
  building_templates.id,
  'active',
  now() - interval '30 minutes',
  now() - interval '25 minutes',
  now() - interval '25 minutes'
from desired
join public.systems on systems.slug = desired.system_slug
join public.building_templates on building_templates.slug = desired.building_slug
on conflict (system_id, building_template_id) do update
set
  status = excluded.status,
  started_at = excluded.started_at,
  finishes_at = excluded.finishes_at,
  constructed_at = excluded.constructed_at,
  updated_at = now();

select public.refresh_system_production_from_buildings();

insert into public.campaign_logs (action_type, payload)
values (
  'faction_balance_costs_and_production_applied',
  jsonb_build_object(
    'daily_initial_pair_points', 36,
    'weekly_initial_pair_points', 252,
    'gold_systems', jsonb_build_array('nexus-aster', 'goregate'),
    'applied_at', now()
  )
);

revoke execute on function public.campaign_balance_cost_bundle(integer, text[], text, text, boolean, integer, boolean, boolean) from public;
revoke execute on function public.recruitment_cost_bundle_for_template(uuid, integer) from public;
revoke execute on function public.recruitment_cost_bundle_for_template(uuid, integer) from anon;
