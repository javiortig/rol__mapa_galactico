create or replace function public.destroy_system_building(system_building_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := public.is_admin();
  v_faction_id uuid := public.current_user_faction_id();
  v_building public.system_buildings%rowtype;
  v_system public.systems%rowtype;
  v_template public.building_templates%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select *
  into v_building
  from public.system_buildings
  where id = destroy_system_building.system_building_id
  for update;

  if not found then
    raise exception 'Edificio no encontrado';
  end if;

  if v_building.status = 'disabled' then
    raise exception 'El edificio ya esta destruido';
  end if;

  select *
  into v_system
  from public.systems
  where id = v_building.system_id
  for update;

  if not found then
    raise exception 'Sistema no encontrado';
  end if;

  if not v_is_admin then
    if v_faction_id is null then
      raise exception 'El usuario no tiene faccion activa';
    end if;

    if v_system.controller_faction_id is distinct from v_faction_id or v_system.status <> 'controlled' then
      raise exception 'Solo puedes destruir edificios en sistemas controlados por tu faccion';
    end if;

    if v_system.blocked_until is not null and v_system.blocked_until > now() then
      raise exception 'No puedes destruir edificios en un sistema bloqueado';
    end if;
  end if;

  if exists (
    select 1
    from public.recruitment_queue
    where recruitment_queue.system_building_id = v_building.id
      and recruitment_queue.status = 'queued'
  ) or exists (
    select 1
    from public.unit_recovery_queue
    where unit_recovery_queue.system_building_id = v_building.id
      and unit_recovery_queue.status = 'queued'
  ) then
    raise exception 'No puedes destruir un edificio con cola activa';
  end if;

  select *
  into v_template
  from public.building_templates
  where id = v_building.building_template_id;

  delete from public.system_buildings
  where id = v_building.id;

  perform public.refresh_system_production_from_buildings();

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    coalesce(v_system.controller_faction_id, v_faction_id),
    'building_destroyed',
    jsonb_build_object(
      'system_building_id', v_building.id,
      'system_id', v_system.id,
      'system_name', v_system.name,
      'building_template_id', v_building.building_template_id,
      'building_name', coalesce(v_template.name, 'Edificio')
    )
  );

  return v_building.id;
end;
$$;

revoke execute on function public.destroy_system_building(uuid) from public;
grant execute on function public.destroy_system_building(uuid) to authenticated;
