create or replace function public.admin_set_system_block(
  target_system_id uuid,
  blocked_until timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede bloquear o desbloquear sistemas';
  end if;

  if not exists (select 1 from public.systems where id = target_system_id) then
    raise exception 'Sistema invalido';
  end if;

  update public.systems
  set
    blocked_until = admin_set_system_block.blocked_until,
    updated_at = now()
  where id = target_system_id;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    case when admin_set_system_block.blocked_until is null then 'admin_system_unblocked' else 'admin_system_blocked' end,
    jsonb_build_object(
      'system_id', target_system_id,
      'blocked_until', admin_set_system_block.blocked_until
    )
  );
end;
$$;

create or replace function public.admin_update_campaign_unit(
  target_unit_id uuid,
  target_system_id uuid,
  quantity integer,
  wounds_taken integer,
  status text,
  is_visible_publicly boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_unit public.campaign_units%rowtype;
  v_target_system_id uuid;
  v_quantity integer;
  v_wounds_taken integer;
  v_status text;
  v_is_visible_publicly boolean;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede editar tropas';
  end if;

  select *
  into v_unit
  from public.campaign_units
  where id = target_unit_id
  for update;

  if not found then
    raise exception 'Unidad no encontrada';
  end if;

  v_target_system_id := coalesce(target_system_id, v_unit.current_system_id);
  v_quantity := coalesce(quantity, v_unit.quantity);
  v_wounds_taken := coalesce(wounds_taken, v_unit.wounds_taken);
  v_status := coalesce(nullif(trim(status), ''), v_unit.status);
  v_is_visible_publicly := coalesce(is_visible_publicly, v_unit.is_visible_publicly);

  if v_target_system_id is not null and not exists (select 1 from public.systems where id = v_target_system_id) then
    raise exception 'Sistema destino invalido';
  end if;

  if v_status not in ('ready', 'moving', 'in_war', 'destroyed', 'retreat_pending', 'recovering') then
    raise exception 'Estado de unidad invalido';
  end if;

  if v_quantity < 0 then
    raise exception 'La cantidad no puede ser negativa';
  end if;

  if v_quantity > v_unit.starting_quantity then
    raise exception 'La cantidad no puede superar el tamano completo de la unidad';
  end if;

  if v_wounds_taken < 0 then
    raise exception 'Las heridas no pueden ser negativas';
  end if;

  if v_quantity = 0 or v_status = 'destroyed' then
    v_quantity := 0;
    v_wounds_taken := 0;
    v_status := 'destroyed';
  end if;

  update public.campaign_units
  set
    current_system_id = v_target_system_id,
    quantity = v_quantity,
    wounds_taken = v_wounds_taken,
    status = v_status,
    is_visible_publicly = v_is_visible_publicly,
    destroyed_at = case when v_status = 'destroyed' then coalesce(destroyed_at, now()) else null end,
    updated_at = now()
  where id = v_unit.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_unit.faction_id,
    'admin_unit_updated',
    jsonb_build_object(
      'campaign_unit_id', v_unit.id,
      'system_id', v_target_system_id,
      'quantity', v_quantity,
      'wounds_taken', v_wounds_taken,
      'status', v_status,
      'is_visible_publicly', v_is_visible_publicly
    )
  );

  return v_unit.id;
end;
$$;

create or replace function public.admin_update_system_building(
  target_system_building_id uuid,
  target_system_id uuid,
  target_building_template_id uuid,
  status text,
  finishes_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_building public.system_buildings%rowtype;
  v_target_system_id uuid;
  v_target_building_template_id uuid;
  v_status text;
  v_finishes_at timestamptz;
  v_system_kind text;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede editar edificios';
  end if;

  select *
  into v_building
  from public.system_buildings
  where id = target_system_building_id
  for update;

  if not found then
    raise exception 'Edificio no encontrado';
  end if;

  v_target_system_id := coalesce(target_system_id, v_building.system_id);
  v_target_building_template_id := coalesce(target_building_template_id, v_building.building_template_id);
  v_status := coalesce(nullif(trim(status), ''), v_building.status);

  if v_status not in ('constructing', 'active', 'disabled') then
    raise exception 'Estado de edificio invalido';
  end if;

  select system_kind
  into v_system_kind
  from public.systems
  where id = v_target_system_id;

  if not found then
    raise exception 'Sistema invalido';
  end if;

  if v_system_kind = 'gaseous' then
    raise exception 'Los sistemas gaseosos no pueden tener edificios';
  end if;

  if not exists (select 1 from public.building_templates where id = v_target_building_template_id) then
    raise exception 'Plantilla de edificio invalida';
  end if;

  v_finishes_at := case
    when v_status = 'constructing' then coalesce(finishes_at, v_building.finishes_at, now() + interval '30 seconds')
    else null
  end;

  update public.system_buildings
  set
    system_id = v_target_system_id,
    building_template_id = v_target_building_template_id,
    status = v_status,
    started_at = case when v_status = 'constructing' then coalesce(started_at, now()) else started_at end,
    finishes_at = v_finishes_at,
    constructed_at = case
      when v_status = 'active' then coalesce(constructed_at, now())
      when v_status = 'constructing' then null
      else constructed_at
    end,
    updated_at = now()
  where id = v_building.id;

  perform public.refresh_system_production_from_buildings();

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_building_updated',
    jsonb_build_object(
      'system_building_id', v_building.id,
      'system_id', v_target_system_id,
      'building_template_id', v_target_building_template_id,
      'status', v_status,
      'finishes_at', v_finishes_at
    )
  );

  return v_building.id;
end;
$$;

revoke execute on function public.admin_set_system_block(uuid, timestamptz) from public;
revoke execute on function public.admin_update_campaign_unit(uuid, uuid, integer, integer, text, boolean) from public;
revoke execute on function public.admin_update_system_building(uuid, uuid, uuid, text, timestamptz) from public;

grant execute on function public.admin_set_system_block(uuid, timestamptz) to authenticated;
grant execute on function public.admin_update_campaign_unit(uuid, uuid, integer, integer, text, boolean) to authenticated;
grant execute on function public.admin_update_system_building(uuid, uuid, uuid, text, timestamptz) to authenticated;
