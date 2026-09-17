drop trigger if exists cap_faction_resources_trigger on public.faction_resources;

alter table public.faction_resources
  alter column honor type numeric(12,2) using honor::numeric(12,2),
  alter column honor set default 0;

alter table public.system_production
  alter column honor_per_tick type numeric(12,2) using honor_per_tick::numeric(12,2),
  alter column honor_per_tick set default 0;

create trigger cap_faction_resources_trigger
before insert or update of supply, minerals, honor, gold, industrial_material, uridium, technology
on public.faction_resources
for each row
execute function public.cap_faction_resources();

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
    coalesce(max(case when building_templates.produced_resource_key = 'honor' then capabilities.production_amount end), 0)::numeric(12,2),
    coalesce(max(case when building_templates.produced_resource_key = 'gold' then capabilities.production_amount end), 0)::integer,
    coalesce(max(case when building_templates.produced_resource_key = 'industrial_material' then capabilities.production_amount end), 0)::integer,
    coalesce(max(case when building_templates.produced_resource_key = 'uridium' then capabilities.production_amount end), 0)::numeric(12,2),
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

create or replace function public.base_system_capacity(
  system_slug text,
  system_kind text,
  is_capital boolean,
  resource_key text
)
returns numeric
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
    when 'mordax' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'drusus' then case resource_key when 'minerals' then 3 when 'uridium' then 0.6 else 0 end
    when 'sa-cea-gate' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'lyra-terminus' then case resource_key when 'minerals' then 3 when 'uridium' then 0.6 else 0 end
    when 'thokt-vault' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'novem' then case resource_key when 'minerals' then 3 when 'uridium' then 0.6 else 0 end
    when 'kharon-prime' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'helios-drift' then case resource_key when 'minerals' then 3 when 'uridium' then 0.6 else 0 end
    when 'blackglass' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'red-sabbath' then case resource_key when 'minerals' then 3 when 'uridium' then 0.6 else 0 end
    when 'nexus-aster' then case resource_key when 'supply' then 10 when 'minerals' then 3 when 'industrial_material' then 5 when 'uridium' then 0.6 else 0 end
    when 'goregate' then case resource_key when 'supply' then 5 when 'minerals' then 5 when 'industrial_material' then 6 when 'uridium' then 0.6 else 0 end
    else 0
  end;
end;
$$;

select public.rebuild_system_resource_capabilities();
select public.refresh_system_production_from_buildings();

insert into public.campaign_logs (action_type, payload)
values (
  'capital_resource_capacity_rebalanced',
  jsonb_build_object(
    'systems', jsonb_build_array('mordax', 'sa-cea-gate', 'thokt-vault', 'kharon-prime', 'blackglass'),
    'supply_per_day', 11,
    'honor_per_day', 0.5
  )
);
