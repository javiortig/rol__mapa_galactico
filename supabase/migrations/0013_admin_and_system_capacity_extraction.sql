create or replace function public.deterministic_int(seed text, min_value integer, max_value integer)
returns integer
language sql
immutable
as $$
  select case
    when max_value <= min_value then min_value
    else min_value + (((hashtext(seed)::bigint & 2147483647) % (max_value - min_value + 1))::integer)
  end;
$$;

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
  v_profile integer;
  v_slug text := coalesce(system_slug, 'system');
begin
  if coalesce(system_kind, 'standard') = 'gaseous' then
    return 0;
  end if;

  if is_capital then
    return case resource_key
      when 'supply' then 10
      when 'minerals' then 5
      when 'industrial_material' then 20
      when 'uridium' then 5
      when 'honor' then 3
      when 'gold' then 3
      else 0
    end;
  end if;

  v_profile := public.deterministic_int(v_slug || ':profile', 0, 4);

  if v_profile = 0 then
    return case resource_key
      when 'supply' then public.deterministic_int(v_slug || ':supply', 5, 9)
      when 'minerals' then public.deterministic_int(v_slug || ':minerals', 2, 5)
      when 'industrial_material' then public.deterministic_int(v_slug || ':industrial_material', 4, 9)
      when 'uridium' then public.deterministic_int(v_slug || ':uridium', 1, 3)
      when 'honor' then public.deterministic_int(v_slug || ':honor', 1, 3)
      when 'gold' then public.deterministic_int(v_slug || ':gold', 1, 3)
      else 0
    end;
  end if;

  if v_profile = 1 then
    return case resource_key
      when 'supply' then public.deterministic_int(v_slug || ':supply', 2, 5)
      when 'minerals' then public.deterministic_int(v_slug || ':minerals', 6, 10)
      when 'industrial_material' then public.deterministic_int(v_slug || ':industrial_material', 8, 13)
      when 'uridium' then public.deterministic_int(v_slug || ':uridium', 1, 4)
      when 'honor' then public.deterministic_int(v_slug || ':honor', 0, 2)
      when 'gold' then public.deterministic_int(v_slug || ':gold', 1, 3)
      else 0
    end;
  end if;

  if v_profile = 2 then
    return case resource_key
      when 'supply' then public.deterministic_int(v_slug || ':supply', 3, 6)
      when 'minerals' then public.deterministic_int(v_slug || ':minerals', 2, 5)
      when 'industrial_material' then public.deterministic_int(v_slug || ':industrial_material', 3, 7)
      when 'uridium' then public.deterministic_int(v_slug || ':uridium', 5, 9)
      when 'honor' then public.deterministic_int(v_slug || ':honor', 1, 3)
      when 'gold' then public.deterministic_int(v_slug || ':gold', 1, 4)
      else 0
    end;
  end if;

  if v_profile = 3 then
    return case resource_key
      when 'supply' then public.deterministic_int(v_slug || ':supply', 3, 6)
      when 'minerals' then public.deterministic_int(v_slug || ':minerals', 1, 4)
      when 'industrial_material' then public.deterministic_int(v_slug || ':industrial_material', 2, 6)
      when 'uridium' then public.deterministic_int(v_slug || ':uridium', 1, 3)
      when 'honor' then public.deterministic_int(v_slug || ':honor', 4, 7)
      when 'gold' then public.deterministic_int(v_slug || ':gold', 2, 5)
      else 0
    end;
  end if;

  return case resource_key
    when 'supply' then public.deterministic_int(v_slug || ':supply', 4, 7)
    when 'minerals' then public.deterministic_int(v_slug || ':minerals', 3, 6)
    when 'industrial_material' then public.deterministic_int(v_slug || ':industrial_material', 5, 10)
    when 'uridium' then public.deterministic_int(v_slug || ':uridium', 2, 5)
    when 'honor' then public.deterministic_int(v_slug || ':honor', 2, 4)
    when 'gold' then public.deterministic_int(v_slug || ':gold', 2, 4)
    else 0
  end;
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

create or replace function public.rebuild_system_resource_capabilities()
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

create or replace function public.prevent_gaseous_system_buildings()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_system_kind text;
begin
  select systems.system_kind
  into v_system_kind
  from public.systems
  where systems.id = new.system_id;

  if coalesce(v_system_kind, 'standard') = 'gaseous' then
    raise exception 'No se puede construir en sistemas gaseosos';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_gaseous_system_buildings_trigger on public.system_buildings;
create trigger prevent_gaseous_system_buildings_trigger
before insert or update of system_id
on public.system_buildings
for each row
execute function public.prevent_gaseous_system_buildings();

create or replace function public.admin_create_unit(
  target_faction_id uuid,
  target_system_id uuid,
  target_unit_template_id uuid,
  quantity integer default 1,
  custom_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_template public.unit_templates%rowtype;
  v_unit_id uuid;
  v_quantity integer := greatest(coalesce(quantity, 1), 1);
  v_name text;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede crear tropas';
  end if;

  if not exists (select 1 from public.factions where id = target_faction_id) then
    raise exception 'Faccion invalida';
  end if;

  if not exists (select 1 from public.systems where id = target_system_id) then
    raise exception 'Sistema invalido';
  end if;

  select *
  into v_template
  from public.unit_templates
  where id = target_unit_template_id
    and faction_id = target_faction_id;

  if not found then
    raise exception 'Plantilla de unidad invalida para la faccion seleccionada';
  end if;

  v_name := coalesce(nullif(trim(custom_name), ''), v_template.name);

  insert into public.campaign_units (
    faction_id,
    unit_template_id,
    name,
    category,
    points,
    quantity,
    starting_quantity,
    wounds_taken,
    experience,
    current_system_id,
    status,
    is_visible_publicly,
    created_at,
    updated_at
  )
  values (
    target_faction_id,
    v_template.id,
    v_name,
    v_template.category,
    coalesce(v_template.points, 0),
    v_quantity,
    v_quantity,
    0,
    0,
    target_system_id,
    'ready',
    true,
    now(),
    now()
  )
  returning id into v_unit_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    target_faction_id,
    'admin_unit_created',
    jsonb_build_object(
      'campaign_unit_id', v_unit_id,
      'target_system_id', target_system_id,
      'target_faction_id', target_faction_id,
      'unit_template_id', v_template.id,
      'quantity', v_quantity
    )
  );

  return v_unit_id;
end;
$$;

create or replace function public.admin_construct_building(
  target_system_id uuid,
  target_building_template_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_system public.systems%rowtype;
  v_template public.building_templates%rowtype;
  v_building_id uuid;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede construir edificios';
  end if;

  select *
  into v_system
  from public.systems
  where id = target_system_id;

  if not found then
    raise exception 'Sistema invalido';
  end if;

  if coalesce(v_system.system_kind, 'standard') = 'gaseous' then
    raise exception 'No se puede construir en sistemas gaseosos';
  end if;

  select *
  into v_template
  from public.building_templates
  where id = target_building_template_id;

  if not found then
    raise exception 'Plantilla de edificio invalida';
  end if;

  insert into public.system_buildings (
    system_id,
    building_template_id,
    status,
    started_at,
    finishes_at,
    constructed_at,
    updated_at
  )
  values (
    target_system_id,
    target_building_template_id,
    'active',
    now(),
    now(),
    now(),
    now()
  )
  on conflict (system_id, building_template_id) do update
  set
    status = 'active',
    started_at = now(),
    finishes_at = now(),
    constructed_at = now(),
    updated_at = now()
  returning id into v_building_id;

  perform public.refresh_system_production_from_buildings();

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_building_constructed',
    jsonb_build_object(
      'system_building_id', v_building_id,
      'target_system_id', target_system_id,
      'building_template_id', target_building_template_id
    )
  );

  return v_building_id;
end;
$$;

create or replace function public.admin_set_faction_resources(
  target_faction_id uuid,
  supply integer default null,
  minerals integer default null,
  honor integer default null,
  gold integer default null,
  industrial_material integer default null,
  uridium integer default null,
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

create or replace function public.admin_set_system_resource_capabilities(
  target_system_id uuid,
  supply integer default null,
  minerals integer default null,
  honor integer default null,
  gold integer default null,
  industrial_material integer default null,
  uridium integer default null
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
  v_values integer[] := array[
    admin_set_system_resource_capabilities.supply,
    admin_set_system_resource_capabilities.minerals,
    admin_set_system_resource_capabilities.honor,
    admin_set_system_resource_capabilities.gold,
    admin_set_system_resource_capabilities.industrial_material,
    admin_set_system_resource_capabilities.uridium
  ];
  v_index integer;
  v_value integer;
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

revoke execute on function public.admin_create_unit(uuid, uuid, uuid, integer, text) from public;
revoke execute on function public.admin_construct_building(uuid, uuid) from public;
revoke execute on function public.admin_set_faction_resources(uuid, integer, integer, integer, integer, integer, integer, integer) from public;
revoke execute on function public.admin_set_system_resource_capabilities(uuid, integer, integer, integer, integer, integer, integer) from public;

grant execute on function public.admin_create_unit(uuid, uuid, uuid, integer, text) to authenticated;
grant execute on function public.admin_construct_building(uuid, uuid) to authenticated;
grant execute on function public.admin_set_faction_resources(uuid, integer, integer, integer, integer, integer, integer, integer) to authenticated;
grant execute on function public.admin_set_system_resource_capabilities(uuid, integer, integer, integer, integer, integer, integer) to authenticated;

select public.rebuild_system_resource_capabilities();
