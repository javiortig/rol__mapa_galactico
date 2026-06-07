alter table public.faction_resources
  add column if not exists honor integer not null default 0 check (honor >= 0),
  add column if not exists industrial_material integer not null default 0 check (industrial_material >= 0);

update public.faction_resources
set
  honor = greatest(honor, ancestral_stone),
  industrial_material = greatest(industrial_material, 80)
where honor = 0
   or industrial_material = 0;

alter table public.systems
  add column if not exists building_slots integer not null default 3 check (building_slots > 0);

update public.systems
set building_slots = case when is_capital then 6 else 3 end;

alter table public.system_production
  add column if not exists honor_per_tick integer not null default 0 check (honor_per_tick >= 0),
  add column if not exists industrial_material_per_tick integer not null default 0 check (industrial_material_per_tick >= 0);

update public.system_production
set honor_per_tick = greatest(honor_per_tick, ancestral_stone_per_tick)
where honor_per_tick = 0;

alter table public.unit_templates
  add column if not exists honor_cost integer not null default 0 check (honor_cost >= 0),
  add column if not exists industrial_material_cost integer not null default 0 check (industrial_material_cost >= 0),
  add column if not exists recruitment_building_type text;

update public.unit_templates
set
  honor_cost = greatest(honor_cost, ancestral_stone_cost),
  recruitment_building_type = coalesce(
    recruitment_building_type,
    case
      when category in ('Vehiculo', 'Vehículo') then 'war_workshop'
      when category in ('Personaje', 'Character', 'Characters') then 'command_quarters'
      when category in ('Monstruo', 'Monster', 'Monsters') then 'beast_lair'
      else 'infantry_barracks'
    end
  );

alter table public.recruitment_queue
  add column if not exists honor_cost integer not null default 0 check (honor_cost >= 0),
  add column if not exists industrial_material_cost integer not null default 0 check (industrial_material_cost >= 0),
  add column if not exists system_building_id uuid,
  add column if not exists origin_system_id uuid references public.systems(id);

update public.recruitment_queue
set honor_cost = greatest(honor_cost, ancestral_stone_cost)
where honor_cost = 0;

alter table public.building_templates
  add column if not exists building_kind text not null default 'production',
  add column if not exists supply_cost integer not null default 0 check (supply_cost >= 0),
  add column if not exists minerals_cost integer not null default 0 check (minerals_cost >= 0),
  add column if not exists honor_cost integer not null default 0 check (honor_cost >= 0),
  add column if not exists gold_cost integer not null default 0 check (gold_cost >= 0),
  add column if not exists industrial_material_cost integer not null default 0 check (industrial_material_cost >= 0),
  add column if not exists uridium_cost integer not null default 0 check (uridium_cost >= 0),
  add column if not exists technology_cost integer not null default 0 check (technology_cost >= 0),
  add column if not exists construction_time_seconds integer not null default 180 check (construction_time_seconds >= 0),
  add column if not exists produced_resource_key text,
  add column if not exists produced_amount integer not null default 0 check (produced_amount >= 0),
  add column if not exists allowed_unit_categories text[] not null default '{}',
  add column if not exists icon_key text;

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.building_templates'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%building_kind%'
  loop
    execute format('alter table public.building_templates drop constraint %I', v_constraint.conname);
  end loop;

  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.building_templates'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%produced_resource_key%'
  loop
    execute format('alter table public.building_templates drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

alter table public.building_templates
  add constraint building_templates_kind_check
    check (building_kind in ('recruitment', 'commerce', 'intelligence', 'production')),
  add constraint building_templates_produced_resource_check
    check (produced_resource_key is null or produced_resource_key in ('supply', 'minerals', 'honor', 'gold', 'industrial_material', 'uridium'));

create table if not exists public.system_resource_capabilities (
  system_id uuid not null references public.systems(id) on delete cascade,
  resource_key text not null check (resource_key in ('supply', 'minerals', 'honor', 'gold', 'industrial_material', 'uridium')),
  production_amount integer not null check (production_amount > 0),
  created_at timestamptz not null default now(),
  primary key (system_id, resource_key)
);

create table if not exists public.system_buildings (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  building_template_id uuid not null references public.building_templates(id) on delete restrict,
  status text not null default 'constructing' check (status in ('constructing', 'active', 'disabled')),
  started_at timestamptz,
  finishes_at timestamptz,
  constructed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (system_id, building_template_id)
);

create table if not exists public.unit_recovery_queue (
  id uuid primary key default gen_random_uuid(),
  faction_id uuid not null references public.factions(id) on delete cascade,
  system_building_id uuid not null references public.system_buildings(id) on delete cascade,
  campaign_unit_id uuid not null references public.campaign_units(id) on delete cascade,
  heal_quantity integer not null check (heal_quantity > 0),
  supply_cost integer not null default 0 check (supply_cost >= 0),
  minerals_cost integer not null default 0 check (minerals_cost >= 0),
  honor_cost integer not null default 0 check (honor_cost >= 0),
  gold_cost integer not null default 0 check (gold_cost >= 0),
  industrial_material_cost integer not null default 0 check (industrial_material_cost >= 0),
  uridium_cost integer not null default 0 check (uridium_cost >= 0),
  technology_cost integer not null default 0 check (technology_cost >= 0),
  started_at timestamptz not null default now(),
  finishes_at timestamptz not null,
  status text not null default 'queued' check (status in ('queued', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists system_buildings_system_status_idx on public.system_buildings (system_id, status);
create index if not exists system_buildings_template_idx on public.system_buildings (building_template_id);
create index if not exists unit_recovery_queue_faction_status_idx on public.unit_recovery_queue (faction_id, status);
create index if not exists unit_recovery_queue_finishes_at_idx on public.unit_recovery_queue (finishes_at);
create index if not exists unit_recovery_queue_unit_status_idx on public.unit_recovery_queue (campaign_unit_id, status);

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
end;
$$;

alter table public.campaign_units
  add constraint campaign_units_status_check
    check (status in ('ready', 'moving', 'in_war', 'destroyed', 'retreat_pending', 'recovering'));

alter table public.system_resource_capabilities enable row level security;
alter table public.system_buildings enable row level security;
alter table public.unit_recovery_queue enable row level security;

grant select on public.system_resource_capabilities, public.system_buildings to anon, authenticated;
grant select on public.unit_recovery_queue to authenticated;

drop policy if exists system_resource_capabilities_select_public on public.system_resource_capabilities;
create policy system_resource_capabilities_select_public
on public.system_resource_capabilities
for select
to anon, authenticated
using (true);

drop policy if exists system_resource_capabilities_admin_all on public.system_resource_capabilities;
create policy system_resource_capabilities_admin_all
on public.system_resource_capabilities
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists system_buildings_select_public on public.system_buildings;
create policy system_buildings_select_public
on public.system_buildings
for select
to anon, authenticated
using (true);

drop policy if exists system_buildings_admin_all on public.system_buildings;
create policy system_buildings_admin_all
on public.system_buildings
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists unit_recovery_queue_select_member_or_admin on public.unit_recovery_queue;
create policy unit_recovery_queue_select_member_or_admin
on public.unit_recovery_queue
for select
to authenticated
using (public.is_admin() or public.is_faction_member(faction_id));

drop policy if exists unit_recovery_queue_admin_all on public.unit_recovery_queue;
create policy unit_recovery_queue_admin_all
on public.unit_recovery_queue
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

insert into public.technology_nodes (
  id, slug, tree_key, name, description, branch, tier, position_x, position_y, cost_technology, research_time_seconds, icon_key, effect_summary, is_starter
)
values (
  public.seed_uuid('technology_node', 'dominio-bestial'),
  'dominio-bestial',
  'common-v1',
  'Dominio bestial',
  'Jaulas, protocolos biologicos y rituales de control para desplegar monstruos de guerra.',
  'Blindados y maquinas',
  2,
  69,
  84,
  8,
  240,
  'beast',
  'Desbloquea Nido de Bestias.',
  false
)
on conflict (slug) do update
set
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
  updated_at = now();

insert into public.technology_prerequisites (technology_node_id, required_node_id)
select beast.id, workshop.id
from public.technology_nodes beast
join public.technology_nodes workshop on workshop.slug = 'talleres-campana'
where beast.slug = 'dominio-bestial'
on conflict (technology_node_id, required_node_id) do nothing;

insert into public.building_templates (
  id, slug, name, description, category, required_technology_node_id, is_available,
  building_kind, supply_cost, minerals_cost, honor_cost, gold_cost, industrial_material_cost, uridium_cost, technology_cost,
  construction_time_seconds, produced_resource_key, produced_amount, allowed_unit_categories, icon_key
)
values
  (public.seed_uuid('building_template', 'barracon-infanteria'), 'barracon-infanteria', 'Barracon de Infanteria', 'Centro de instruccion para tropas de linea y cuadros veteranos.', 'Reclutamiento', null, true, 'recruitment', 12, 8, 0, 0, 4, 0, 0, 240, null, 0, array['Infanteria','Infantería','Elite','Élite'], 'infantry_barracks'),
  (public.seed_uuid('building_template', 'cuartel-mando'), 'cuartel-mando', 'Cuartel de Mando', 'Instalacion de oficiales, heroes y personajes de mando.', 'Reclutamiento', (select id from public.technology_nodes where slug = 'estado-mayor-cruzada'), true, 'recruitment', 10, 10, 1, 0, 6, 0, 0, 300, null, 0, array['Personaje','Character','Characters'], 'command_quarters'),
  (public.seed_uuid('building_template', 'taller-guerra'), 'taller-guerra', 'Taller de Guerra', 'Bahias de reparacion y ensamblaje de vehiculos.', 'Reclutamiento', (select id from public.technology_nodes where slug = 'talleres-campana'), true, 'recruitment', 6, 16, 0, 0, 8, 0, 0, 300, null, 0, array['Vehiculo','Vehículo'], 'war_workshop'),
  (public.seed_uuid('building_template', 'nido-bestias'), 'nido-bestias', 'Nido de Bestias', 'Jaulas y rituales de control para monstruos de guerra.', 'Reclutamiento', (select id from public.technology_nodes where slug = 'dominio-bestial'), true, 'recruitment', 14, 8, 1, 0, 6, 0, 0, 300, null, 0, array['Monstruo','Monster','Monsters'], 'beast_lair'),
  (public.seed_uuid('building_template', 'camara-comercio'), 'camara-comercio', 'Camara de Comercio', 'Mercado orbital y punto de contacto con rutas mercantes.', 'Comercio', null, true, 'commerce', 8, 8, 0, 1, 4, 0, 0, 240, null, 0, '{}', 'commerce'),
  (public.seed_uuid('building_template', 'nexo-inteligencia'), 'nexo-inteligencia', 'Nexo de Inteligencia', 'Centro de analisis para operaciones de espionaje futuras.', 'Inteligencia', (select id from public.technology_nodes where slug = 'auspex-reliquias'), true, 'intelligence', 6, 12, 1, 0, 6, 0, 0, 300, null, 0, '{}', 'intelligence'),
  (public.seed_uuid('building_template', 'antenas-reconocimiento'), 'antenas-reconocimiento', 'Antenas de Reconocimiento', 'Matrices de escucha y auspex de largo alcance.', 'Inteligencia', (select id from public.technology_nodes where slug = 'auspex-reliquias'), true, 'intelligence', 4, 8, 0, 0, 5, 2, 0, 240, null, 0, '{}', 'recon'),
  (public.seed_uuid('building_template', 'granja-biologica'), 'granja-biologica', 'Granja Biologica', 'Complejos de biomasa y cultivos adaptados al frente.', 'Produccion', null, true, 'production', 4, 4, 0, 0, 3, 0, 0, 180, 'supply', 10, '{}', 'biofarm'),
  (public.seed_uuid('building_template', 'complejo-minero'), 'complejo-minero', 'Complejo Minero', 'Pozos, excavadoras y refinerias de mineral bruto.', 'Produccion', null, true, 'production', 4, 6, 0, 0, 4, 0, 0, 180, 'minerals', 6, '{}', 'mine'),
  (public.seed_uuid('building_template', 'refineria-iridium'), 'refineria-iridium', 'Refineria de Iridium', 'Planta especializada para estabilizar cristales de salto.', 'Produccion', (select id from public.technology_nodes where slug = 'puerto-uridium'), true, 'production', 4, 8, 0, 0, 5, 0, 0, 240, 'uridium', 4, '{}', 'iridium_refinery'),
  (public.seed_uuid('building_template', 'mina-oro'), 'mina-oro', 'Mina de Oro', 'Extraccion de metales preciosos para rutas comerciales.', 'Produccion', (select id from public.technology_nodes where slug = 'manufactorum-local'), true, 'production', 4, 8, 0, 0, 5, 0, 0, 240, 'gold', 3, '{}', 'gold_mine'),
  (public.seed_uuid('building_template', 'planta-fundicion'), 'planta-fundicion', 'Planta de Fundicion', 'Produce Material Industrial para nuevas construcciones.', 'Produccion', null, true, 'production', 4, 10, 0, 0, 3, 0, 0, 240, 'industrial_material', 5, '{}', 'foundry'),
  (public.seed_uuid('building_template', 'senado'), 'senado', 'Senado', 'Institucion politica que convierte influencia local en Honor.', 'Produccion', null, true, 'production', 8, 8, 0, 1, 5, 0, 0, 300, 'honor', 2, '{}', 'senate')
on conflict (slug) do update
set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  required_technology_node_id = excluded.required_technology_node_id,
  is_available = excluded.is_available,
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
  icon_key = excluded.icon_key,
  updated_at = now();

insert into public.technology_effects (id, technology_node_id, effect_type, payload)
select public.seed_uuid('technology_effect', 'starter-buildings'), id, 'unlock_building_template', '{"building_template_slugs":["barracon-infanteria","camara-comercio","granja-biologica","complejo-minero","planta-fundicion","senado"]}'::jsonb
from public.technology_nodes
where slug = 'doctrina-campana'
union all
select public.seed_uuid('technology_effect', 'cuartel-mando-building'), id, 'unlock_building_template', '{"building_template_slugs":["cuartel-mando"]}'::jsonb
from public.technology_nodes
where slug = 'estado-mayor-cruzada'
union all
select public.seed_uuid('technology_effect', 'taller-guerra-building'), id, 'unlock_building_template', '{"building_template_slugs":["taller-guerra"]}'::jsonb
from public.technology_nodes
where slug = 'talleres-campana'
union all
select public.seed_uuid('technology_effect', 'nido-bestias-building'), id, 'unlock_building_template', '{"building_template_slugs":["nido-bestias"]}'::jsonb
from public.technology_nodes
where slug = 'dominio-bestial'
union all
select public.seed_uuid('technology_effect', 'intelligence-buildings'), id, 'unlock_building_template', '{"building_template_slugs":["nexo-inteligencia","antenas-reconocimiento"]}'::jsonb
from public.technology_nodes
where slug = 'auspex-reliquias'
union all
select public.seed_uuid('technology_effect', 'refineria-iridium-building'), id, 'unlock_building_template', '{"building_template_slugs":["refineria-iridium"]}'::jsonb
from public.technology_nodes
where slug = 'puerto-uridium'
union all
select public.seed_uuid('technology_effect', 'mina-oro-building'), id, 'unlock_building_template', '{"building_template_slugs":["mina-oro"]}'::jsonb
from public.technology_nodes
where slug = 'manufactorum-local'
on conflict (id) do update
set technology_node_id = excluded.technology_node_id, effect_type = excluded.effect_type, payload = excluded.payload;

insert into public.system_resource_capabilities (system_id, resource_key, production_amount)
select system_id, resource_key, production_amount
from (
  select system_id, 'supply'::text as resource_key, 10 as production_amount from public.system_production where supply_per_tick > 0
  union all
  select system_id, 'minerals', 6 from public.system_production where minerals_per_tick > 0
  union all
  select system_id, 'uridium', 4 from public.system_production where uridium_per_tick > 0
  union all
  select system_id, 'honor', 2 from public.system_production where ancestral_stone_per_tick > 0 or honor_per_tick > 0
  union all
  select system_id, 'industrial_material', 5 from public.system_production where minerals_per_tick >= 4
  union all
  select systems.id, 'gold', 3
  from public.systems
  where systems.slug in ('red-sabbath', 'nexus-aster', 'pale-choir', 'lyra-terminus', 'novem')
) capabilities
on conflict (system_id, resource_key) do update
set production_amount = excluded.production_amount;

insert into public.system_buildings (id, system_id, building_template_id, status, started_at, finishes_at, constructed_at)
select
  public.seed_uuid('system_building', systems.slug || '-' || template_slug),
  systems.id,
  public.seed_uuid('building_template', template_slug),
  'active',
  now(),
  now(),
  now()
from public.systems
cross join (
  values
    ('barracon-infanteria'),
    ('camara-comercio'),
    ('planta-fundicion'),
    ('senado')
) as templates(template_slug)
where systems.is_capital
on conflict (system_id, building_template_id) do nothing;

insert into public.system_buildings (id, system_id, building_template_id, status, started_at, finishes_at, constructed_at)
select
  public.seed_uuid('system_building', systems.slug || '-' || resource_template.template_slug),
  systems.id,
  public.seed_uuid('building_template', resource_template.template_slug),
  'active',
  now(),
  now(),
  now()
from public.systems
join lateral (
  select case system_resource_capabilities.resource_key
    when 'supply' then 'granja-biologica'
    when 'minerals' then 'complejo-minero'
    when 'uridium' then 'refineria-iridium'
    when 'gold' then 'mina-oro'
    when 'industrial_material' then 'planta-fundicion'
    when 'honor' then 'senado'
  end as template_slug
  from public.system_resource_capabilities
  where system_resource_capabilities.system_id = systems.id
  order by case system_resource_capabilities.resource_key
    when 'minerals' then 1
    when 'supply' then 2
    when 'industrial_material' then 3
    when 'uridium' then 4
    when 'gold' then 5
    when 'honor' then 6
    else 9
  end
  limit 1
) resource_template on true
where not systems.is_capital
  and systems.status = 'controlled'
  and systems.controller_faction_id is not null
  and resource_template.template_slug is not null
on conflict (system_id, building_template_id) do nothing;

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
    coalesce(sum(case when building_templates.produced_resource_key = 'supply' then building_templates.produced_amount else 0 end), 0)::integer,
    coalesce(sum(case when building_templates.produced_resource_key = 'minerals' then building_templates.produced_amount else 0 end), 0)::integer,
    0,
    coalesce(sum(case when building_templates.produced_resource_key = 'honor' then building_templates.produced_amount else 0 end), 0)::integer,
    coalesce(sum(case when building_templates.produced_resource_key = 'gold' then building_templates.produced_amount else 0 end), 0)::integer,
    coalesce(sum(case when building_templates.produced_resource_key = 'industrial_material' then building_templates.produced_amount else 0 end), 0)::integer,
    coalesce(sum(case when building_templates.produced_resource_key = 'uridium' then building_templates.produced_amount else 0 end), 0)::integer,
    0
  from public.systems
  left join public.system_buildings
    on system_buildings.system_id = systems.id
    and system_buildings.status = 'active'
  left join public.building_templates
    on building_templates.id = system_buildings.building_template_id
    and building_templates.building_kind = 'production'
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

select public.refresh_system_production_from_buildings();

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
    select *
    from public.system_buildings
    where status = 'constructing'
      and finishes_at <= now()
    order by finishes_at
    for update
  loop
    update public.system_buildings
    set
      status = 'active',
      constructed_at = now(),
      updated_at = now()
    where id = v_building.id;

    insert into public.campaign_logs (action_type, payload)
    values (
      'building_construction_completed',
      jsonb_build_object(
        'system_building_id', v_building.id,
        'system_id', v_building.system_id,
        'building_template_id', v_building.building_template_id
      )
    );

    v_resolved := v_resolved + 1;
  end loop;

  if v_resolved > 0 then
    perform public.refresh_system_production_from_buildings();
  end if;

  return v_resolved;
end;
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

  select *
  into v_settings
  from public.campaign_settings
  where id = 'default'
  for update;

  if not found then
    insert into public.campaign_settings (id, resource_tick_interval_hours, next_resource_tick_at)
    values ('default', 24, now() + interval '24 hours')
    returning * into v_settings;
  end if;

  v_tick_at := coalesce(v_settings.next_resource_tick_at, now() + make_interval(hours => v_settings.resource_tick_interval_hours));

  while v_tick_at <= now() loop
    insert into public.faction_resources (
      faction_id,
      supply,
      minerals,
      ancestral_stone,
      honor,
      gold,
      industrial_material,
      uridium,
      technology,
      updated_at
    )
    select
      systems.controller_faction_id,
      coalesce(sum(system_production.supply_per_tick), 0)::integer,
      coalesce(sum(system_production.minerals_per_tick), 0)::integer,
      0,
      coalesce(sum(system_production.honor_per_tick), 0)::integer,
      coalesce(sum(system_production.gold_per_tick), 0)::integer,
      coalesce(sum(system_production.industrial_material_per_tick), 0)::integer,
      coalesce(sum(system_production.uridium_per_tick), 0)::integer,
      0,
      now()
    from public.systems
    join public.system_production on system_production.system_id = systems.id
    where systems.status = 'controlled'
      and systems.controller_faction_id is not null
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
    set
      last_resource_tick_at = v_last_applied_at,
      next_resource_tick_at = v_tick_at,
      updated_at = now()
    where id = 'default';
  end if;

  return v_applied;
end;
$$;

create or replace function public.normalize_trade_resource_key(resource_key text)
returns text
language sql
immutable
as $$
  select case resource_key
    when 'supply' then 'supply'
    when 'minerals' then 'minerals'
    when 'industrialMaterial' then 'industrial_material'
    when 'industrial_material' then 'industrial_material'
    when 'uridium' then 'uridium'
    else null
  end;
$$;

create or replace function public.trade_resource_points(resource_key text)
returns integer
language sql
immutable
as $$
  select case public.normalize_trade_resource_key(resource_key)
    when 'supply' then 1
    when 'minerals' then 2
    when 'industrial_material' then 2
    when 'uridium' then 2
    else null
  end;
$$;

create or replace function public.start_building_construction(system_id uuid, building_template_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_system public.systems%rowtype;
  v_template public.building_templates%rowtype;
  v_resources public.faction_resources%rowtype;
  v_existing_count integer;
  v_building_id uuid;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  perform public.resolve_building_construction();
  perform public.resolve_technology_research();

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  select *
  into v_system
  from public.systems
  where id = start_building_construction.system_id
  for update;

  if not found then
    raise exception 'Sistema no encontrado';
  end if;

  if v_system.controller_faction_id is distinct from v_faction_id or v_system.status <> 'controlled' then
    raise exception 'Solo puedes construir en sistemas controlados por tu faccion';
  end if;

  if v_system.blocked_until is not null and v_system.blocked_until > now() then
    raise exception 'El sistema esta bloqueado';
  end if;

  select *
  into v_template
  from public.building_templates
  where id = start_building_construction.building_template_id
    and is_available = true;

  if not found then
    raise exception 'Edificio no disponible';
  end if;

  if v_template.required_technology_node_id is not null
    and not exists (
      select 1
      from public.faction_technologies
      where faction_id = v_faction_id
        and technology_node_id = v_template.required_technology_node_id
        and status = 'unlocked'
    ) then
    raise exception 'Falta tecnologia para este edificio';
  end if;

  if exists (
    select 1
    from public.system_buildings
    where system_buildings.system_id = v_system.id
      and system_buildings.building_template_id = v_template.id
      and system_buildings.status <> 'disabled'
  ) then
    raise exception 'Este sistema ya tiene ese edificio';
  end if;

  select count(*)
  into v_existing_count
  from public.system_buildings
  where system_buildings.system_id = v_system.id
    and system_buildings.status <> 'disabled';

  if v_existing_count >= v_system.building_slots then
    raise exception 'No quedan slots de construccion';
  end if;

  if v_template.building_kind = 'production'
    and v_template.produced_resource_key is not null
    and not v_system.is_capital
    and not exists (
      select 1
      from public.system_resource_capabilities
      where system_resource_capabilities.system_id = v_system.id
        and system_resource_capabilities.resource_key = v_template.produced_resource_key
        and system_resource_capabilities.production_amount > 0
    ) then
    raise exception 'Este sistema no permite ese edificio de recurso';
  end if;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
  end if;

  if v_resources.supply < v_template.supply_cost
    or v_resources.minerals < v_template.minerals_cost
    or v_resources.honor < v_template.honor_cost
    or v_resources.gold < v_template.gold_cost
    or v_resources.industrial_material < v_template.industrial_material_cost
    or v_resources.uridium < v_template.uridium_cost
    or v_resources.technology < v_template.technology_cost then
    raise exception 'Recursos insuficientes';
  end if;

  update public.faction_resources
  set
    supply = supply - v_template.supply_cost,
    minerals = minerals - v_template.minerals_cost,
    honor = honor - v_template.honor_cost,
    gold = gold - v_template.gold_cost,
    industrial_material = industrial_material - v_template.industrial_material_cost,
    uridium = uridium - v_template.uridium_cost,
    technology = technology - v_template.technology_cost,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.system_buildings (
    system_id,
    building_template_id,
    status,
    started_at,
    finishes_at,
    constructed_at
  )
  values (
    v_system.id,
    v_template.id,
    case when v_template.construction_time_seconds <= 0 then 'active' else 'constructing' end,
    now(),
    now() + make_interval(secs => v_template.construction_time_seconds),
    case when v_template.construction_time_seconds <= 0 then now() else null end
  )
  returning id into v_building_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'building_construction_started',
    jsonb_build_object(
      'system_building_id', v_building_id,
      'system_id', v_system.id,
      'building_template_id', v_template.id,
      'building_name', v_template.name,
      'finishes_at', now() + make_interval(secs => v_template.construction_time_seconds)
    )
  );

  perform public.refresh_system_production_from_buildings();
  return v_building_id;
end;
$$;

create or replace function public.recruit_unit(unit_template_id uuid, quantity integer)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'El reclutamiento ahora requiere seleccionar un edificio activo';
end;
$$;

create or replace function public.recruit_unit_at_building(system_building_id uuid, unit_template_id uuid, quantity integer)
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
  v_queue_id uuid;
  v_quantity integer := quantity;
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

  if v_quantity is null or v_quantity < 1 then
    raise exception 'Cantidad invalida';
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
    building_templates.building_kind,
    building_templates.allowed_unit_categories
  into v_building
  from public.system_buildings
  join public.systems on systems.id = system_buildings.system_id
  join public.building_templates on building_templates.id = system_buildings.building_template_id
  where system_buildings.id = recruit_unit_at_building.system_building_id
  for update of system_buildings;

  if not found then
    raise exception 'Edificio no encontrado';
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
  where id = recruit_unit_at_building.unit_template_id
    and faction_id = v_faction_id
    and is_available = true;

  if not found then
    raise exception 'Unidad no disponible';
  end if;

  if not (v_template.category = any(v_building.allowed_unit_categories)) then
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

  v_supply_cost := v_template.supply_cost * v_quantity;
  v_minerals_cost := v_template.minerals_cost * v_quantity;
  v_honor_cost := v_template.honor_cost * v_quantity;
  v_gold_cost := v_template.gold_cost * v_quantity;
  v_industrial_material_cost := v_template.industrial_material_cost * v_quantity;
  v_uridium_cost := v_template.uridium_cost * v_quantity;
  v_technology_cost := v_template.technology_cost * v_quantity;
  v_recruitment_seconds := v_template.recruitment_time_seconds * v_quantity;

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
      v_recruitment_seconds := greatest(v_quantity, ceil((v_recruitment_seconds::numeric * (100 - v_percent)) / 100)::integer);
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
      if v_resource in ('all', 'industrialMaterial', 'industrial_material') and v_industrial_material_cost > 0 then
        v_industrial_material_cost := greatest(1, floor((v_industrial_material_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'uridium') and v_uridium_cost > 0 then
        v_uridium_cost := greatest(1, floor((v_uridium_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'technology') and v_technology_cost > 0 then
        v_technology_cost := greatest(1, floor((v_technology_cost::numeric * (100 - v_percent)) / 100)::integer);
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
    started_at,
    finishes_at,
    status
  )
  values (
    v_faction_id,
    v_template.id,
    v_quantity,
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
      'quantity', v_quantity,
      'duration_seconds', v_recruitment_seconds
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
        coalesce(v_item.origin_system_id, v_item.capital_system_id),
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
          'quantity', v_item.default_quantity,
          'origin_system_id', coalesce(v_item.origin_system_id, v_item.capital_system_id)
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

create or replace function public.heal_unit_at_building(system_building_id uuid, campaign_unit_id uuid, heal_quantity integer)
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
  v_missing integer;
  v_heal_quantity integer := heal_quantity;
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
    building_templates.building_kind,
    building_templates.allowed_unit_categories,
    building_templates.construction_time_seconds
  into v_building
  from public.system_buildings
  join public.systems on systems.id = system_buildings.system_id
  join public.building_templates on building_templates.id = system_buildings.building_template_id
  where system_buildings.id = heal_unit_at_building.system_building_id
  for update of system_buildings;

  if not found then
    raise exception 'Edificio no encontrado';
  end if;

  if v_building.status <> 'active' or v_building.building_kind <> 'recruitment' then
    raise exception 'Este edificio no puede curar unidades';
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
  where id = heal_unit_at_building.campaign_unit_id
    and faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'Unidad no encontrada';
  end if;

  if v_unit.status <> 'ready' then
    raise exception 'La unidad no esta disponible para curarse';
  end if;

  if v_unit.current_system_id is distinct from v_building.system_id then
    raise exception 'La unidad no esta en el mismo sistema que el edificio';
  end if;

  if not (v_unit.category = any(v_building.allowed_unit_categories)) then
    raise exception 'Este edificio no puede curar esa categoria';
  end if;

  v_missing := greatest(0, v_unit.starting_quantity - v_unit.quantity);

  if v_missing <= 0 then
    raise exception 'La unidad ya esta completa';
  end if;

  if v_heal_quantity is null or v_heal_quantity < 1 or v_heal_quantity > v_missing then
    raise exception 'Cantidad de curacion invalida';
  end if;

  select *
  into v_template
  from public.unit_templates
  where id = v_unit.unit_template_id;

  if not found then
    raise exception 'La unidad no tiene plantilla de coste';
  end if;

  v_supply_cost := case when v_template.supply_cost > 0 then ceil((v_template.supply_cost::numeric * v_heal_quantity) / greatest(v_template.default_quantity, 1) / 2)::integer else 0 end;
  v_minerals_cost := case when v_template.minerals_cost > 0 then ceil((v_template.minerals_cost::numeric * v_heal_quantity) / greatest(v_template.default_quantity, 1) / 2)::integer else 0 end;
  v_honor_cost := case when v_template.honor_cost > 0 then ceil((v_template.honor_cost::numeric * v_heal_quantity) / greatest(v_template.default_quantity, 1) / 2)::integer else 0 end;
  v_gold_cost := case when v_template.gold_cost > 0 then ceil((v_template.gold_cost::numeric * v_heal_quantity) / greatest(v_template.default_quantity, 1) / 2)::integer else 0 end;
  v_industrial_material_cost := case when v_template.industrial_material_cost > 0 then ceil((v_template.industrial_material_cost::numeric * v_heal_quantity) / greatest(v_template.default_quantity, 1) / 2)::integer else 0 end;
  v_uridium_cost := case when v_template.uridium_cost > 0 then ceil((v_template.uridium_cost::numeric * v_heal_quantity) / greatest(v_template.default_quantity, 1) / 2)::integer else 0 end;
  v_technology_cost := case when v_template.technology_cost > 0 then ceil((v_template.technology_cost::numeric * v_heal_quantity) / greatest(v_template.default_quantity, 1) / 2)::integer else 0 end;

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
    v_heal_quantity,
    v_supply_cost,
    v_minerals_cost,
    v_honor_cost,
    v_gold_cost,
    v_industrial_material_cost,
    v_uridium_cost,
    v_technology_cost,
    now(),
    now() + make_interval(secs => greatest(60, v_template.recruitment_time_seconds / 2)),
    'queued'
  )
  returning id into v_queue_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'unit_recovery_started',
    jsonb_build_object(
      'unit_recovery_queue_id', v_queue_id,
      'system_building_id', v_building.id,
      'campaign_unit_id', v_unit.id,
      'heal_quantity', v_heal_quantity
    )
  );

  return v_queue_id;
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
    select
      unit_recovery_queue.*,
      campaign_units.name as unit_name
    from public.unit_recovery_queue
    join public.campaign_units on campaign_units.id = unit_recovery_queue.campaign_unit_id
    where unit_recovery_queue.status = 'queued'
      and unit_recovery_queue.finishes_at <= now()
    order by unit_recovery_queue.finishes_at
    for update of unit_recovery_queue
  loop
    update public.campaign_units
    set
      quantity = least(starting_quantity, quantity + v_item.heal_quantity),
      status = case when destroyed_at is null then 'ready' else status end,
      updated_at = now()
    where id = v_item.campaign_unit_id;

    update public.unit_recovery_queue
    set
      status = 'completed',
      updated_at = now()
    where id = v_item.id;

    insert into public.campaign_logs (faction_id, action_type, payload)
    values (
      v_item.faction_id,
      'unit_recovery_completed',
      jsonb_build_object(
        'unit_recovery_queue_id', v_item.id,
        'campaign_unit_id', v_item.campaign_unit_id,
        'unit_name', v_item.unit_name,
        'heal_quantity', v_item.heal_quantity
      )
    );

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

create or replace function public.merchant_trade(resource_key text, direction text, trade_quantity integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_resource_key text := public.normalize_trade_resource_key(resource_key);
  v_points integer;
  v_resources public.faction_resources%rowtype;
  v_gold_delta integer := 0;
  v_resource_delta integer := 0;
  v_price_gold integer;
  v_payout_gold integer;
  v_current_resource integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if v_resource_key is null then
    raise exception 'Recurso no comerciable';
  end if;

  if direction not in ('buy', 'sell') then
    raise exception 'Direccion de comercio invalida';
  end if;

  if trade_quantity is null or trade_quantity < 1 then
    raise exception 'Cantidad invalida';
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

  if not exists (
    select 1
    from public.systems
    join public.system_buildings on system_buildings.system_id = systems.id
    join public.building_templates on building_templates.id = system_buildings.building_template_id
    where systems.controller_faction_id = v_faction_id
      and systems.status = 'controlled'
      and system_buildings.status = 'active'
      and building_templates.slug = 'camara-comercio'
  ) then
    raise exception 'Necesitas una Camara de Comercio activa';
  end if;

  v_points := public.trade_resource_points(v_resource_key);
  v_price_gold := ceil((v_points::numeric * trade_quantity * 2) / 5)::integer;
  v_payout_gold := ceil((v_points::numeric * trade_quantity * 0.5) / 5)::integer;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
  end if;

  v_current_resource := case v_resource_key
    when 'supply' then v_resources.supply
    when 'minerals' then v_resources.minerals
    when 'industrial_material' then v_resources.industrial_material
    when 'uridium' then v_resources.uridium
    else 0
  end;

  if direction = 'buy' then
    if v_resources.gold < v_price_gold then
      raise exception 'Oro insuficiente';
    end if;

    v_gold_delta := -v_price_gold;
    v_resource_delta := trade_quantity;
  else
    if v_current_resource < trade_quantity then
      raise exception 'Recurso insuficiente';
    end if;

    v_gold_delta := v_payout_gold;
    v_resource_delta := -trade_quantity;
  end if;

  update public.faction_resources
  set
    supply = supply + case when v_resource_key = 'supply' then v_resource_delta else 0 end,
    minerals = minerals + case when v_resource_key = 'minerals' then v_resource_delta else 0 end,
    industrial_material = industrial_material + case when v_resource_key = 'industrial_material' then v_resource_delta else 0 end,
    uridium = uridium + case when v_resource_key = 'uridium' then v_resource_delta else 0 end,
    gold = gold + v_gold_delta,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'merchant_trade',
    jsonb_build_object(
      'resource_key', v_resource_key,
      'direction', direction,
      'quantity', trade_quantity,
      'gold_delta', v_gold_delta,
      'resource_delta', v_resource_delta
    )
  );

  return jsonb_build_object(
    'resource_key', v_resource_key,
    'direction', direction,
    'quantity', trade_quantity,
    'gold_delta', v_gold_delta,
    'resource_delta', v_resource_delta
  );
end;
$$;

do $$
declare
  v_constraint record;
begin
  update public.trade_offers
  set status = 'cancelled', cancelled_at = coalesce(cancelled_at, now()), updated_at = now()
  where resource_key = 'ancestral_stone'
    and status = 'open';

  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.trade_offers'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%resource_key%'
  loop
    execute format('alter table public.trade_offers drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

alter table public.trade_offers
  add constraint trade_offers_resource_key_check
    check (resource_key in ('supply', 'minerals', 'industrial_material', 'uridium', 'ancestral_stone'));

create or replace function public.create_trade_offer(
  offer_type text,
  resource_key text,
  resource_amount integer,
  gold_amount integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_resource_key text := public.normalize_trade_resource_key(resource_key);
  v_resources public.faction_resources%rowtype;
  v_fee_gold integer;
  v_current_resource integer;
  v_offer_id uuid;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if offer_type not in ('buy', 'sell') then
    raise exception 'Tipo de oferta invalido';
  end if;

  if v_resource_key is null then
    raise exception 'Recurso no comerciable';
  end if;

  if resource_amount is null or resource_amount < 1 or gold_amount is null or gold_amount < 1 then
    raise exception 'Oferta invalida';
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

  if not exists (
    select 1
    from public.systems
    join public.system_buildings on system_buildings.system_id = systems.id
    join public.building_templates on building_templates.id = system_buildings.building_template_id
    where systems.controller_faction_id = v_faction_id
      and systems.status = 'controlled'
      and system_buildings.status = 'active'
      and building_templates.slug = 'camara-comercio'
  ) then
    raise exception 'Necesitas una Camara de Comercio activa';
  end if;

  v_fee_gold := ceil(gold_amount::numeric * 0.30)::integer;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
  end if;

  v_current_resource := case v_resource_key
    when 'supply' then v_resources.supply
    when 'minerals' then v_resources.minerals
    when 'industrial_material' then v_resources.industrial_material
    when 'uridium' then v_resources.uridium
    else 0
  end;

  if offer_type = 'buy' and v_resources.gold < gold_amount + v_fee_gold then
    raise exception 'Oro insuficiente para publicar esta compra';
  end if;

  if offer_type = 'sell' and (v_current_resource < resource_amount or v_resources.gold < v_fee_gold) then
    raise exception 'Recursos insuficientes para publicar esta venta';
  end if;

  insert into public.trade_offers (
    creator_faction_id,
    offer_type,
    resource_key,
    resource_amount,
    gold_amount,
    fee_gold,
    status
  )
  values (
    v_faction_id,
    offer_type,
    v_resource_key,
    resource_amount,
    gold_amount,
    v_fee_gold,
    'open'
  )
  returning id into v_offer_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'trade_offer_created',
    jsonb_build_object(
      'trade_offer_id', v_offer_id,
      'offer_type', offer_type,
      'resource_key', v_resource_key,
      'resource_amount', resource_amount,
      'gold_amount', gold_amount,
      'fee_gold', v_fee_gold
    )
  );

  return v_offer_id;
end;
$$;

create or replace function public.accept_trade_offer(offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_acceptor_faction_id uuid;
  v_offer public.trade_offers%rowtype;
  v_creator_resources public.faction_resources%rowtype;
  v_acceptor_resources public.faction_resources%rowtype;
  v_creator_current_resource integer;
  v_acceptor_current_resource integer;
  v_creator_resource_delta integer := 0;
  v_acceptor_resource_delta integer := 0;
  v_creator_gold_delta integer := 0;
  v_acceptor_gold_delta integer := 0;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select player_factions.faction_id
  into v_acceptor_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_acceptor_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  if not exists (
    select 1
    from public.systems
    join public.system_buildings on system_buildings.system_id = systems.id
    join public.building_templates on building_templates.id = system_buildings.building_template_id
    where systems.controller_faction_id = v_acceptor_faction_id
      and systems.status = 'controlled'
      and system_buildings.status = 'active'
      and building_templates.slug = 'camara-comercio'
  ) then
    raise exception 'Necesitas una Camara de Comercio activa';
  end if;

  select *
  into v_offer
  from public.trade_offers
  where id = accept_trade_offer.offer_id
    and status = 'open'
  for update;

  if not found then
    raise exception 'Oferta no disponible';
  end if;

  if public.normalize_trade_resource_key(v_offer.resource_key) is null then
    raise exception 'Oferta con recurso no comerciable';
  end if;

  if v_offer.creator_faction_id = v_acceptor_faction_id then
    raise exception 'No puedes aceptar tu propia oferta';
  end if;

  select *
  into v_creator_resources
  from public.faction_resources
  where faction_id = v_offer.creator_faction_id
  for update;

  select *
  into v_acceptor_resources
  from public.faction_resources
  where faction_id = v_acceptor_faction_id
  for update;

  if not found then
    raise exception 'Faltan recursos inicializados';
  end if;

  v_creator_current_resource := case v_offer.resource_key
    when 'supply' then v_creator_resources.supply
    when 'minerals' then v_creator_resources.minerals
    when 'industrial_material' then v_creator_resources.industrial_material
    when 'uridium' then v_creator_resources.uridium
    else 0
  end;

  v_acceptor_current_resource := case v_offer.resource_key
    when 'supply' then v_acceptor_resources.supply
    when 'minerals' then v_acceptor_resources.minerals
    when 'industrial_material' then v_acceptor_resources.industrial_material
    when 'uridium' then v_acceptor_resources.uridium
    else 0
  end;

  if v_offer.offer_type = 'buy' then
    if v_creator_resources.gold < v_offer.gold_amount + v_offer.fee_gold then
      raise exception 'El comprador ya no tiene oro suficiente';
    end if;

    if v_acceptor_current_resource < v_offer.resource_amount or v_acceptor_resources.gold < v_offer.fee_gold then
      raise exception 'El vendedor no tiene recursos u oro para la comision';
    end if;

    v_creator_resource_delta := v_offer.resource_amount;
    v_creator_gold_delta := -(v_offer.gold_amount + v_offer.fee_gold);
    v_acceptor_resource_delta := -v_offer.resource_amount;
    v_acceptor_gold_delta := v_offer.gold_amount - v_offer.fee_gold;
  else
    if v_creator_current_resource < v_offer.resource_amount or v_creator_resources.gold < v_offer.fee_gold then
      raise exception 'El vendedor ya no tiene recursos u oro para la comision';
    end if;

    if v_acceptor_resources.gold < v_offer.gold_amount + v_offer.fee_gold then
      raise exception 'El comprador no tiene oro suficiente';
    end if;

    v_creator_resource_delta := -v_offer.resource_amount;
    v_creator_gold_delta := v_offer.gold_amount - v_offer.fee_gold;
    v_acceptor_resource_delta := v_offer.resource_amount;
    v_acceptor_gold_delta := -(v_offer.gold_amount + v_offer.fee_gold);
  end if;

  update public.faction_resources
  set
    supply = supply + case when v_offer.resource_key = 'supply' then v_creator_resource_delta else 0 end,
    minerals = minerals + case when v_offer.resource_key = 'minerals' then v_creator_resource_delta else 0 end,
    industrial_material = industrial_material + case when v_offer.resource_key = 'industrial_material' then v_creator_resource_delta else 0 end,
    uridium = uridium + case when v_offer.resource_key = 'uridium' then v_creator_resource_delta else 0 end,
    gold = gold + v_creator_gold_delta,
    updated_at = now()
  where faction_id = v_offer.creator_faction_id;

  update public.faction_resources
  set
    supply = supply + case when v_offer.resource_key = 'supply' then v_acceptor_resource_delta else 0 end,
    minerals = minerals + case when v_offer.resource_key = 'minerals' then v_acceptor_resource_delta else 0 end,
    industrial_material = industrial_material + case when v_offer.resource_key = 'industrial_material' then v_acceptor_resource_delta else 0 end,
    uridium = uridium + case when v_offer.resource_key = 'uridium' then v_acceptor_resource_delta else 0 end,
    gold = gold + v_acceptor_gold_delta,
    updated_at = now()
  where faction_id = v_acceptor_faction_id;

  update public.trade_offers
  set
    status = 'accepted',
    accepted_by_faction_id = v_acceptor_faction_id,
    accepted_at = now(),
    updated_at = now()
  where id = v_offer.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_acceptor_faction_id,
    'trade_offer_accepted',
    jsonb_build_object(
      'trade_offer_id', v_offer.id,
      'creator_faction_id', v_offer.creator_faction_id,
      'acceptor_faction_id', v_acceptor_faction_id,
      'offer_type', v_offer.offer_type,
      'resource_key', v_offer.resource_key,
      'resource_amount', v_offer.resource_amount,
      'gold_amount', v_offer.gold_amount,
      'fee_gold_each', v_offer.fee_gold
    )
  );

  return v_offer.id;
end;
$$;

revoke execute on function public.refresh_system_production_from_buildings() from public;
revoke execute on function public.resolve_building_construction() from public;
revoke execute on function public.resolve_unit_recovery_queue() from public;
revoke execute on function public.start_building_construction(uuid, uuid) from public;
revoke execute on function public.recruit_unit_at_building(uuid, uuid, integer) from public;
revoke execute on function public.heal_unit_at_building(uuid, uuid, integer) from public;

grant execute on function public.resolve_resource_ticks() to authenticated;
grant execute on function public.resolve_building_construction() to authenticated;
grant execute on function public.resolve_unit_recovery_queue() to authenticated;
grant execute on function public.start_building_construction(uuid, uuid) to authenticated;
grant execute on function public.recruit_unit_at_building(uuid, uuid, integer) to authenticated;
grant execute on function public.heal_unit_at_building(uuid, uuid, integer) to authenticated;
