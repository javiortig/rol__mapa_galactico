drop trigger if exists cap_faction_resources_trigger on public.faction_resources;

alter table public.faction_resources
  alter column uridium type numeric(12,2) using uridium::numeric(12,2),
  alter column uridium set default 0;

alter table public.system_production
  alter column uridium_per_tick type numeric(12,2) using uridium_per_tick::numeric(12,2),
  alter column uridium_per_tick set default 0;

alter table public.system_resource_capabilities
  alter column production_amount type numeric(12,2) using production_amount::numeric(12,2);

drop function if exists public.rebuild_system_resource_capabilities();
drop function if exists public.base_system_capacity(text, text, boolean, text);

create function public.base_system_capacity(
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
    when 'mordax' then case resource_key when 'supply' then 7 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'drusus' then case resource_key when 'supply' then 2 when 'minerals' then 1 when 'uridium' then 0.3 else 0 end
    when 'sa-cea-gate' then case resource_key when 'minerals' then 3 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'lyra-terminus' then case resource_key when 'supply' then 5 when 'uridium' then 0.3 else 0 end
    when 'thokt-vault' then case resource_key when 'minerals' then 4 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'novem' then case resource_key when 'supply' then 3 when 'uridium' then 0.3 else 0 end
    when 'kharon-prime' then case resource_key when 'minerals' then 3 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'helios-drift' then case resource_key when 'supply' then 5 when 'uridium' then 0.3 else 0 end
    when 'blackglass' then case resource_key when 'supply' then 10 when 'industrial_material' then 5 else 0 end
    when 'red-sabbath' then case resource_key when 'supply' then 4 when 'minerals' then 1 when 'uridium' then 0.3 else 0 end
    when 'nexus-aster' then case resource_key when 'minerals' then 4 when 'gold' then 8 when 'industrial_material' then 6 else 0 end
    when 'goregate' then case resource_key when 'supply' then 4 when 'honor' then 1 when 'gold' then 8 when 'industrial_material' then 6 else 0 end
    else 0
  end;
end;
$$;

create function public.rebuild_system_resource_capabilities()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  delete from public.system_resource_capabilities;

  insert into public.system_resource_capabilities (system_id, resource_key, production_amount)
  select
    systems.id,
    resource_keys.resource_key,
    public.base_system_capacity(systems.slug, systems.system_kind, systems.is_capital, resource_keys.resource_key) as production_amount
  from public.systems
  cross join (
    values
      ('supply'::text),
      ('minerals'::text),
      ('honor'::text),
      ('gold'::text),
      ('industrial_material'::text),
      ('uridium'::text)
  ) as resource_keys(resource_key)
  where public.base_system_capacity(systems.slug, systems.system_kind, systems.is_capital, resource_keys.resource_key) > 0;

  get diagnostics v_count = row_count;

  perform public.refresh_system_production_from_buildings();

  return v_count;
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
      coalesce(sum(system_production.honor_per_tick), 0)::integer,
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

drop function if exists public.can_receive_resource(uuid, text, integer);
drop function if exists public.get_faction_resource_value(uuid, text);
drop function if exists public.get_resource_cap_value(text);

create function public.get_resource_cap_value(resource_key text)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select case public.normalize_trade_resource_key(resource_key)
    when 'supply' then max_supply
    when 'minerals' then max_minerals
    when 'industrial_material' then max_industrial_material
    when 'uridium' then max_uridium
    else case resource_key
      when 'honor' then max_honor
      when 'gold' then max_gold
      when 'technology' then max_technology
      else 0
    end
  end::numeric
  from public.campaign_settings
  where id = 'default';
$$;

create function public.get_faction_resource_value(target_faction_id uuid, resource_key text)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select case public.normalize_trade_resource_key(resource_key)
    when 'supply' then supply
    when 'minerals' then minerals
    when 'industrial_material' then industrial_material
    when 'uridium' then uridium
    else case resource_key
      when 'honor' then honor
      when 'gold' then gold
      when 'technology' then technology
      else 0
    end
  end::numeric
  from public.faction_resources
  where faction_id = target_faction_id;
$$;

create function public.can_receive_resource(target_faction_id uuid, resource_key text, delta integer)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.get_faction_resource_value(target_faction_id, resource_key), 0) + greatest(coalesce(delta, 0), 0)
    <= coalesce(public.get_resource_cap_value(resource_key), 0);
$$;

create trigger cap_faction_resources_trigger
before insert or update of supply, minerals, honor, gold, industrial_material, uridium, technology
on public.faction_resources
for each row
execute function public.cap_faction_resources();

drop function if exists public.admin_set_faction_resources(uuid, integer, integer, integer, integer, integer, integer, integer);

create function public.admin_set_faction_resources(
  target_faction_id uuid,
  supply integer default null,
  minerals integer default null,
  honor integer default null,
  gold integer default null,
  industrial_material integer default null,
  uridium numeric default null,
  technology integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_before public.faction_resources%rowtype;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede modificar recursos de faccion';
  end if;

  select *
  into v_before
  from public.faction_resources
  where faction_id = target_faction_id
  for update;

  if not found then
    raise exception 'Faccion invalida o sin recursos inicializados';
  end if;

  update public.faction_resources
  set
    supply = greatest(coalesce(admin_set_faction_resources.supply, v_before.supply), 0),
    minerals = greatest(coalesce(admin_set_faction_resources.minerals, v_before.minerals), 0),
    honor = greatest(coalesce(admin_set_faction_resources.honor, v_before.honor), 0),
    gold = greatest(coalesce(admin_set_faction_resources.gold, v_before.gold), 0),
    industrial_material = greatest(coalesce(admin_set_faction_resources.industrial_material, v_before.industrial_material), 0),
    uridium = greatest(coalesce(admin_set_faction_resources.uridium, v_before.uridium), 0),
    technology = greatest(coalesce(admin_set_faction_resources.technology, v_before.technology), 0),
    updated_at = now()
  where faction_id = target_faction_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    target_faction_id,
    'admin_faction_resources_updated',
    jsonb_build_object(
      'target_faction_id', target_faction_id,
      'supply', admin_set_faction_resources.supply,
      'minerals', admin_set_faction_resources.minerals,
      'honor', admin_set_faction_resources.honor,
      'gold', admin_set_faction_resources.gold,
      'industrial_material', admin_set_faction_resources.industrial_material,
      'uridium', admin_set_faction_resources.uridium,
      'technology', admin_set_faction_resources.technology
    )
  );
end;
$$;

drop function if exists public.admin_set_system_resource_capabilities(uuid, integer, integer, integer, integer, integer, integer);

create function public.admin_set_system_resource_capabilities(
  target_system_id uuid,
  supply integer default null,
  minerals integer default null,
  honor integer default null,
  gold integer default null,
  industrial_material integer default null,
  uridium numeric default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_system public.systems%rowtype;
  v_keys text[] := array['supply', 'minerals', 'honor', 'gold', 'industrial_material', 'uridium'];
  v_values numeric[] := array[
    admin_set_system_resource_capabilities.supply,
    admin_set_system_resource_capabilities.minerals,
    admin_set_system_resource_capabilities.honor,
    admin_set_system_resource_capabilities.gold,
    admin_set_system_resource_capabilities.industrial_material,
    admin_set_system_resource_capabilities.uridium
  ];
  v_index integer;
  v_value numeric;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede modificar capacidades de sistema';
  end if;

  select *
  into v_system
  from public.systems
  where id = target_system_id;

  if not found then
    raise exception 'Sistema invalido';
  end if;

  if coalesce(v_system.system_kind, 'standard') = 'gaseous' then
    delete from public.system_resource_capabilities
    where system_id = target_system_id;

    perform public.refresh_system_production_from_buildings();

    insert into public.campaign_logs (actor_user_id, action_type, payload)
    values (
      v_user_id,
      'admin_system_capabilities_cleared_for_gaseous',
      jsonb_build_object('target_system_id', target_system_id)
    );

    return;
  end if;

  for v_index in 1..array_length(v_keys, 1) loop
    v_value := v_values[v_index];

    if v_value is null then
      continue;
    end if;

    if v_value <= 0 then
      delete from public.system_resource_capabilities
      where system_id = target_system_id
        and resource_key = v_keys[v_index];
    else
      insert into public.system_resource_capabilities (system_id, resource_key, production_amount)
      values (target_system_id, v_keys[v_index], v_value)
      on conflict (system_id, resource_key) do update
      set production_amount = excluded.production_amount;
    end if;
  end loop;

  perform public.refresh_system_production_from_buildings();

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_system_capabilities_updated',
    jsonb_build_object(
      'target_system_id', target_system_id,
      'supply', admin_set_system_resource_capabilities.supply,
      'minerals', admin_set_system_resource_capabilities.minerals,
      'honor', admin_set_system_resource_capabilities.honor,
      'gold', admin_set_system_resource_capabilities.gold,
      'industrial_material', admin_set_system_resource_capabilities.industrial_material,
      'uridium', admin_set_system_resource_capabilities.uridium
    )
  );
end;
$$;

with building_costs(slug, industrial_material_cost) as (
  values
    ('granja-biologica', 20),
    ('complejo-minero', 20),
    ('planta-fundicion', 20),
    ('barracon-infanteria', 20),
    ('monumento', 24),
    ('refineria-iridium', 26),
    ('camara-comercio', 30),
    ('antenas-reconocimiento', 30),
    ('mina-oro', 34),
    ('taller-guerra', 38),
    ('nido-bestias', 38),
    ('nexo-inteligencia', 38),
    ('cuartel-mando', 42),
    ('santuario-reliquias', 44),
    ('camara-leyendas', 56)
)
update public.building_templates
set
  supply_cost = 0,
  minerals_cost = 0,
  honor_cost = 0,
  gold_cost = 0,
  industrial_material_cost = building_costs.industrial_material_cost,
  uridium_cost = 0,
  technology_cost = 0,
  updated_at = now()
from building_costs
where building_templates.slug = building_costs.slug;

delete from public.system_buildings;

select public.rebuild_system_resource_capabilities();
select public.refresh_system_production_from_buildings();

update public.faction_resources
set
  industrial_material = 80,
  uridium = 3,
  updated_at = now()
from public.factions
where faction_resources.faction_id = factions.id
  and factions.slug in ('legiones-daemonicas', 'adeptus-custodes', 'space-marines', 'cultos-genestealer', 'necrones');

insert into public.campaign_logs (action_type, payload)
values (
  'rebalance_16pts_decimal_uridium_empty_start_applied',
  jsonb_build_object(
    'daily_initial_pair_recruitment_points', 16,
    'adjacent_uridium_per_day', 0.3,
    'capital_industrial_material_per_day', 5,
    'initial_buildings', 'none'
  )
);

revoke execute on function public.get_resource_cap_value(text) from public;
revoke execute on function public.get_faction_resource_value(uuid, text) from public;
revoke execute on function public.can_receive_resource(uuid, text, integer) from public;
revoke execute on function public.admin_set_faction_resources(uuid, integer, integer, integer, integer, integer, numeric, integer) from public;
revoke execute on function public.admin_set_system_resource_capabilities(uuid, integer, integer, integer, integer, integer, numeric) from public;

grant execute on function public.can_receive_resource(uuid, text, integer) to authenticated;
grant execute on function public.admin_set_faction_resources(uuid, integer, integer, integer, integer, integer, numeric, integer) to authenticated;
grant execute on function public.admin_set_system_resource_capabilities(uuid, integer, integer, integer, integer, integer, numeric) to authenticated;
