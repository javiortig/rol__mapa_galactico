create or replace function public.resupply_unit_at_building(system_building_id uuid, campaign_unit_id uuid)
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
  v_costs record;
  v_supply_cost integer;
  v_minerals_cost integer;
  v_honor_cost integer;
  v_gold_cost integer;
  v_industrial_material_cost integer;
  v_uridium_cost integer;
  v_technology_cost integer;
  v_missing_models numeric;
  v_model_damage_ratio numeric;
  v_wound_capacity numeric;
  v_wound_damage_ratio numeric;
  v_damage_ratio numeric;
  v_resupply_ratio numeric;
  v_queue_id uuid;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  perform public.resolve_unit_recovery_queue();
  perform public.resolve_building_construction();
  perform public.resolve_recruitment_queue();

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
    building_templates.slug as building_slug,
    building_templates.building_kind,
    building_templates.allowed_unit_categories,
    building_templates.construction_time_seconds
  into v_building
  from public.system_buildings
  join public.systems on systems.id = system_buildings.system_id
  join public.building_templates on building_templates.id = system_buildings.building_template_id
  where system_buildings.id = resupply_unit_at_building.system_building_id
  for update of system_buildings;

  if not found then
    raise exception 'Edificio no encontrado';
  end if;

  if exists (
    select 1 from public.recruitment_queue
    where recruitment_queue.system_building_id = v_building.id
      and recruitment_queue.status = 'queued'
  ) or exists (
    select 1 from public.unit_recovery_queue
    where unit_recovery_queue.system_building_id = v_building.id
      and unit_recovery_queue.status = 'queued'
  ) then
    raise exception 'Este edificio ya tiene una cola activa';
  end if;

  if v_building.status <> 'active' or v_building.building_kind <> 'recruitment' then
    raise exception 'Este edificio no puede reabastecer unidades';
  end if;

  if v_building.controller_faction_id is distinct from v_faction_id or v_building.system_status <> 'controlled' then
    raise exception 'El edificio no pertenece a un sistema controlado por tu faccion';
  end if;

  if public.system_has_unresolved_battle_block(v_building.system_id) then
    raise exception 'El sistema esta bloqueado';
  end if;

  select *
  into v_unit
  from public.campaign_units
  where campaign_units.id = resupply_unit_at_building.campaign_unit_id
    and campaign_units.faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'Unidad no encontrada';
  end if;

  if v_unit.status <> 'ready' then
    raise exception 'La unidad no esta disponible para reabastecerse';
  end if;

  if v_unit.current_system_id is distinct from v_building.system_id then
    raise exception 'La unidad no esta en el mismo sistema que el edificio';
  end if;

  if v_unit.quantity >= v_unit.starting_quantity and v_unit.wounds_taken <= 0 then
    raise exception 'La unidad ya esta completa';
  end if;

  select *
  into v_template
  from public.unit_templates
  where unit_templates.id = v_unit.unit_template_id;

  if not found then
    raise exception 'La unidad no tiene plantilla de coste';
  end if;

  if v_template.recruitment_building_type is not null then
    if v_template.recruitment_building_type <> v_building.building_slug then
      raise exception 'Este edificio no puede reabastecer esa unidad';
    end if;
  elsif not (v_unit.category = any(v_building.allowed_unit_categories)) then
    raise exception 'Este edificio no puede reabastecer esa categoria';
  end if;

  select *
  into v_costs
  from public.recruitment_cost_bundle_for_template(v_template.id, coalesce(v_unit.points, v_template.points));

  v_missing_models := greatest(coalesce(v_unit.starting_quantity, 1) - coalesce(v_unit.quantity, 0), 0);
  v_model_damage_ratio := least(1, greatest(0, v_missing_models / greatest(coalesce(v_unit.starting_quantity, 1), 1)));
  v_wound_capacity := greatest(coalesce(v_unit.quantity, 0), 0) * greatest(coalesce(v_template.wounds_per_model, 1), 1);
  v_wound_damage_ratio := case
    when v_wound_capacity > 0 then least(1, greatest(0, coalesce(v_unit.wounds_taken, 0)::numeric / v_wound_capacity))
    else 0
  end;
  v_damage_ratio := least(1, greatest(0, v_model_damage_ratio * 0.8 + v_wound_damage_ratio * 0.2));
  v_resupply_ratio := 0.10 + (0.65 * v_damage_ratio);

  v_supply_cost := case when v_costs.supply_cost > 0 then ceil(v_costs.supply_cost::numeric * v_resupply_ratio)::integer else 0 end;
  v_minerals_cost := case when v_costs.minerals_cost > 0 then ceil(v_costs.minerals_cost::numeric * v_resupply_ratio)::integer else 0 end;
  v_honor_cost := case when v_costs.honor_cost > 0 then ceil(v_costs.honor_cost::numeric * v_resupply_ratio)::integer else 0 end;
  v_gold_cost := case when v_costs.gold_cost > 0 then ceil(v_costs.gold_cost::numeric * v_resupply_ratio)::integer else 0 end;
  v_industrial_material_cost := 0;
  v_uridium_cost := 0;
  v_technology_cost := 0;

  select *
  into v_resources
  from public.faction_resources
  where faction_resources.faction_id = v_faction_id
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
  where faction_resources.faction_id = v_faction_id;

  update public.campaign_units
  set status = 'recovering', updated_at = now()
  where campaign_units.id = v_unit.id;

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
    greatest(1, v_unit.starting_quantity - v_unit.quantity),
    v_supply_cost,
    v_minerals_cost,
    v_honor_cost,
    v_gold_cost,
    v_industrial_material_cost,
    v_uridium_cost,
    v_technology_cost,
    now(),
    now() + make_interval(secs => greatest(3, ceil(v_template.recruitment_time_seconds::numeric / 2)::integer)),
    'queued'
  )
  returning id into v_queue_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'unit_resupply_started',
    jsonb_build_object(
      'unit_recovery_queue_id', v_queue_id,
      'campaign_unit_id', v_unit.id,
      'system_building_id', v_building.id,
      'points', coalesce(v_unit.points, v_template.points),
      'target_quantity', v_unit.starting_quantity,
      'wounds_taken', v_unit.wounds_taken,
      'damage_ratio', round(v_damage_ratio, 4),
      'resupply_ratio', round(v_resupply_ratio, 4)
    )
  );

  return v_queue_id;
end;
$$;

revoke execute on function public.resupply_unit_at_building(uuid, uuid) from public;
revoke execute on function public.resupply_unit_at_building(uuid, uuid) from anon;
grant execute on function public.resupply_unit_at_building(uuid, uuid) to authenticated;
