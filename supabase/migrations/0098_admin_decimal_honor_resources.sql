drop function if exists public.admin_set_faction_resources(uuid, integer, integer, integer, integer, integer, numeric, integer);
drop function if exists public.admin_set_faction_resources(uuid, integer, integer, numeric, integer, integer, numeric, integer);

create function public.admin_set_faction_resources(
  target_faction_id uuid,
  supply integer default null,
  minerals integer default null,
  honor numeric default null,
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
    honor = round(greatest(coalesce(admin_set_faction_resources.honor, v_before.honor), 0), 2),
    gold = greatest(coalesce(admin_set_faction_resources.gold, v_before.gold), 0),
    industrial_material = greatest(coalesce(admin_set_faction_resources.industrial_material, v_before.industrial_material), 0),
    uridium = round(greatest(coalesce(admin_set_faction_resources.uridium, v_before.uridium), 0), 2),
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

drop function if exists public.admin_set_system_resource_capabilities(uuid, integer, integer, integer, integer, integer, numeric);
drop function if exists public.admin_set_system_resource_capabilities(uuid, integer, integer, numeric, integer, integer, numeric);

create function public.admin_set_system_resource_capabilities(
  target_system_id uuid,
  supply integer default null,
  minerals integer default null,
  honor numeric default null,
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
    v_value := round(v_values[v_index], 2);

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

revoke execute on function public.admin_set_faction_resources(uuid, integer, integer, numeric, integer, integer, numeric, integer) from public;
revoke execute on function public.admin_set_system_resource_capabilities(uuid, integer, integer, numeric, integer, integer, numeric) from public;

grant execute on function public.admin_set_faction_resources(uuid, integer, integer, numeric, integer, integer, numeric, integer) to authenticated;
grant execute on function public.admin_set_system_resource_capabilities(uuid, integer, integer, numeric, integer, integer, numeric) to authenticated;

notify pgrst, 'reload schema';
