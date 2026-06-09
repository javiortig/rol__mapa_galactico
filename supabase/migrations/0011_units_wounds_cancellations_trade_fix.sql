alter table public.unit_templates
  add column if not exists wounds_per_model integer not null default 1 check (wounds_per_model > 0);

alter table public.campaign_units
  add column if not exists wounds_taken integer not null default 0 check (wounds_taken >= 0);

alter table public.battle_reports
  add column if not exists wounds_remaining jsonb not null default '{}'::jsonb;

alter table public.recruitment_queue
  add column if not exists updated_at timestamptz not null default now();

alter table public.movement_orders
  add column if not exists cancelled_at timestamptz;

alter table public.trade_offers
  add column if not exists is_reserved boolean not null default false;

update public.unit_templates
set wounds_per_model = case slug
  when 'boyz' then 1
  when 'unit-orcos-boyz' then 1
  when 'meganobz' then 3
  when 'unit-orcos-meganobz' then 3
  when 'deff-dread' then 8
  when 'unit-orcos-deff-dread' then 8
  when 'necron-warriors' then 1
  when 'unit-necrones-warriors' then 1
  when 'immortals' then 1
  when 'unit-necrones-immortals' then 1
  when 'skorpekh-destroyers' then 3
  when 'unit-necrones-skorpekh' then 3
  when 'cadian-shock-troops' then 1
  when 'unit-guardia-cadian' then 1
  when 'kasrkin' then 1
  when 'unit-guardia-kasrkin' then 1
  when 'leman-russ-battle-tank' then 13
  when 'unit-guardia-leman-russ' then 13
  when 'neophyte-hybrids' then 1
  when 'unit-culto-neophytes' then 1
  when 'acolyte-hybrids' then 1
  when 'unit-culto-acolytes' then 1
  when 'achilles-ridgerunner' then 8
  when 'unit-culto-ridgerunner' then 8
  when 'intercessor-squad' then 2
  when 'unit-sombra-intercessors' then 2
  when 'terminator-squad' then 3
  when 'unit-sombra-terminators' then 3
  when 'redemptor-dreadnought' then 12
  when 'unit-sombra-redemptor' then 12
  when 'poxwalkers' then 1
  when 'unit-muerte-poxwalkers' then 1
  when 'plague-marines' then 2
  when 'unit-muerte-plague-marines' then 2
  when 'foetid-bloat-drone' then 10
  when 'unit-muerte-bloat-drone' then 10
  else wounds_per_model
end;

update public.campaign_units
set wounds_taken = 0
where quantity <= 0;

create or replace function public.validate_campaign_unit_wounds()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_wounds_per_model integer := 1;
begin
  if new.quantity <= 0 then
    new.wounds_taken := 0;
    return new;
  end if;

  select coalesce(unit_templates.wounds_per_model, 1)
  into v_wounds_per_model
  from public.unit_templates
  where unit_templates.id = new.unit_template_id;

  v_wounds_per_model := coalesce(v_wounds_per_model, 1);

  if new.wounds_taken > new.quantity * v_wounds_per_model then
    raise exception 'Las heridas superan el maximo de la unidad';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_campaign_unit_wounds_trigger on public.campaign_units;
create trigger validate_campaign_unit_wounds_trigger
before insert or update of quantity, wounds_taken, unit_template_id
on public.campaign_units
for each row
execute function public.validate_campaign_unit_wounds();

create index if not exists recruitment_queue_building_status_idx
on public.recruitment_queue (system_building_id, status)
where system_building_id is not null;

create index if not exists unit_recovery_queue_building_status_idx
on public.unit_recovery_queue (system_building_id, status)
where system_building_id is not null;

update public.trade_offers
set
  status = 'cancelled',
  cancelled_at = coalesce(cancelled_at, now()),
  updated_at = now()
where status = 'open'
  and not is_reserved;

update public.trade_offers
set resource_key = public.normalize_trade_resource_key(resource_key)
where public.normalize_trade_resource_key(resource_key) is not null;

update public.trade_offers
set
  resource_key = 'supply',
  status = 'cancelled',
  cancelled_at = coalesce(cancelled_at, now()),
  updated_at = now()
where public.normalize_trade_resource_key(resource_key) is null;

do $$
declare
  v_constraint record;
begin
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
    check (resource_key in ('supply', 'minerals', 'industrial_material', 'uridium'));

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

create or replace function public.create_movement_order(unit_selections jsonb, path_system_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_faction_id uuid;
  v_origin_system_id uuid;
  v_destination_system_id uuid;
  v_path_length integer;
  v_index integer;
  v_from uuid;
  v_to uuid;
  v_edge public.system_edges%rowtype;
  v_system public.systems%rowtype;
  v_total_cost integer := 0;
  v_resources public.faction_resources%rowtype;
  v_duration_seconds integer;
  v_order_id uuid;
  v_selection record;
  v_unit public.campaign_units%rowtype;
  v_selected_unit_ids uuid[] := '{}';
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if unit_selections is null or jsonb_typeof(unit_selections) <> 'array' or jsonb_array_length(unit_selections) = 0 then
    raise exception 'Selecciona al menos una unidad';
  end if;

  if path_system_ids is null or cardinality(path_system_ids) < 2 then
    raise exception 'La ruta debe tener origen y destino';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  for v_selection in
    select unit_id, quantity
    from jsonb_to_recordset(unit_selections) as selection(unit_id uuid, quantity integer)
  loop
    if v_selection.unit_id is null then
      raise exception 'Cada seleccion debe tener unidad';
    end if;

    if v_selection.unit_id = any(v_selected_unit_ids) then
      raise exception 'La seleccion contiene unidades duplicadas';
    end if;

    select *
    into v_unit
    from public.campaign_units
    where id = v_selection.unit_id
    for update;

    if not found or v_unit.status <> 'ready' or v_unit.quantity <= 0 then
      raise exception 'Todas las unidades deben existir y estar listas';
    end if;

    if coalesce(v_selection.quantity, v_unit.quantity) <> v_unit.quantity then
      raise exception 'Las unidades no se pueden dividir al mover';
    end if;

    if v_faction_id is null then
      v_faction_id := v_unit.faction_id;
      v_origin_system_id := v_unit.current_system_id;
    elsif v_unit.faction_id is distinct from v_faction_id or v_unit.current_system_id is distinct from v_origin_system_id then
      raise exception 'Todas las unidades deben pertenecer a la misma faccion y origen';
    end if;

    v_selected_unit_ids := array_append(v_selected_unit_ids, v_selection.unit_id);
  end loop;

  if not v_is_admin and not exists (
    select 1
    from public.player_factions
    where user_id = v_user_id
      and faction_id = v_faction_id
  ) then
    raise exception 'No puedes mover unidades de esta faccion';
  end if;

  if path_system_ids[1] is distinct from v_origin_system_id then
    raise exception 'La ruta debe empezar en el sistema de origen de las unidades';
  end if;

  v_path_length := cardinality(path_system_ids);
  v_destination_system_id := path_system_ids[v_path_length];

  for v_index in 1..v_path_length loop
    select *
    into v_system
    from public.systems
    where id = path_system_ids[v_index];

    if not found then
      raise exception 'La ruta contiene un sistema inexistente';
    end if;

    if v_index > 1 and (v_system.status = 'war' or v_system.blocked_until is not null and v_system.blocked_until > now()) then
      raise exception 'La ruta contiene un sistema bloqueado o en guerra';
    end if;
  end loop;

  for v_index in 1..(v_path_length - 1) loop
    v_from := path_system_ids[v_index];
    v_to := path_system_ids[v_index + 1];

    select *
    into v_edge
    from public.system_edges
    where not is_blocked
      and (
        (from_system_id = v_from and to_system_id = v_to)
        or (from_system_id = v_to and to_system_id = v_from)
      )
    limit 1;

    if not found then
      raise exception 'La ruta contiene un tramo no valido';
    end if;

    v_total_cost := v_total_cost + v_edge.uridium_cost;
  end loop;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found or v_resources.uridium < v_total_cost then
    raise exception 'Uridium insuficiente';
  end if;

  select movement_edge_duration_seconds * (v_path_length - 1)
  into v_duration_seconds
  from public.campaign_settings
  where id = 'default';

  v_duration_seconds := coalesce(v_duration_seconds, 120 * (v_path_length - 1));

  update public.faction_resources
  set
    uridium = uridium - v_total_cost,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.movement_orders (
    faction_id,
    from_system_id,
    to_system_id,
    uridium_cost,
    started_at,
    arrival_at,
    status,
    path_system_ids,
    segment_count,
    duration_seconds
  )
  values (
    v_faction_id,
    v_origin_system_id,
    v_destination_system_id,
    v_total_cost,
    now(),
    now() + make_interval(secs => v_duration_seconds),
    'moving',
    path_system_ids,
    v_path_length - 1,
    v_duration_seconds
  )
  returning id into v_order_id;

  for v_index in 1..cardinality(v_selected_unit_ids) loop
    select *
    into v_unit
    from public.campaign_units
    where id = v_selected_unit_ids[v_index]
    for update;

    update public.campaign_units
    set
      status = 'moving',
      updated_at = now()
    where id = v_unit.id;

    insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
    values (v_order_id, v_unit.id, v_unit.quantity);
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'movement_started',
    jsonb_build_object(
      'movement_order_id', v_order_id,
      'unit_ids', to_jsonb(v_selected_unit_ids),
      'path_system_ids', to_jsonb(path_system_ids),
      'uridium_cost', v_total_cost,
      'duration_seconds', v_duration_seconds
    )
  );

  return v_order_id;
end;
$$;

create or replace function public.cancel_movement_order(order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_order public.movement_orders%rowtype;
  v_refund integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_order
  from public.movement_orders
  where id = cancel_movement_order.order_id
  for update;

  if not found then
    raise exception 'Movimiento no encontrado';
  end if;

  if v_order.status <> 'moving' then
    raise exception 'El movimiento no esta activo';
  end if;

  if v_order.arrival_at <= now() then
    raise exception 'Movimiento ya resuelto o pendiente de resolucion';
  end if;

  if not v_is_admin and not public.is_faction_member(v_order.faction_id) then
    raise exception 'No puedes cancelar este movimiento';
  end if;

  v_refund := ceil(v_order.uridium_cost::numeric / 2)::integer;

  update public.faction_resources
  set
    uridium = uridium + v_refund,
    updated_at = now()
  where faction_id = v_order.faction_id;

  update public.campaign_units
  set
    current_system_id = v_order.from_system_id,
    status = 'ready',
    updated_at = now()
  where id in (
    select unit_id
    from public.movement_order_units
    where movement_order_id = v_order.id
  );

  update public.movement_orders
  set
    status = 'cancelled',
    cancelled_at = now()
  where id = v_order.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_order.faction_id,
    'movement_cancelled',
    jsonb_build_object('movement_order_id', v_order.id, 'refund_uridium', v_refund)
  );

  return v_order.id;
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
  perform public.resolve_recruitment_queue();
  perform public.resolve_unit_recovery_queue();

  if v_quantity is null or v_quantity < 1 then
    raise exception 'Cantidad invalida';
  end if;

  if v_quantity <> 1 then
    raise exception 'Cada edificio solo puede reclutar una unidad por cola';
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

  if exists (
    select 1 from public.recruitment_queue
    where system_building_id = v_building.id and status = 'queued'
  ) or exists (
    select 1 from public.unit_recovery_queue
    where system_building_id = v_building.id and status = 'queued'
  ) then
    raise exception 'Este edificio ya tiene una cola activa';
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
        wounds_taken,
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

create or replace function public.cancel_recruitment_queue(queue_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_item public.recruitment_queue%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_item
  from public.recruitment_queue
  where id = cancel_recruitment_queue.queue_id
  for update;

  if not found then
    raise exception 'Cola de reclutamiento no encontrada';
  end if;

  if v_item.status <> 'queued' then
    raise exception 'La cola no esta activa';
  end if;

  if not v_is_admin and not public.is_faction_member(v_item.faction_id) then
    raise exception 'No puedes cancelar esta cola';
  end if;

  update public.faction_resources
  set
    supply = supply + ceil(v_item.supply_cost::numeric / 2)::integer,
    minerals = minerals + ceil(v_item.minerals_cost::numeric / 2)::integer,
    honor = honor + ceil(v_item.honor_cost::numeric / 2)::integer,
    gold = gold + ceil(v_item.gold_cost::numeric / 2)::integer,
    industrial_material = industrial_material + ceil(v_item.industrial_material_cost::numeric / 2)::integer,
    uridium = uridium + ceil(v_item.uridium_cost::numeric / 2)::integer,
    technology = technology + ceil(v_item.technology_cost::numeric / 2)::integer,
    updated_at = now()
  where faction_id = v_item.faction_id;

  update public.recruitment_queue
  set
    status = 'cancelled',
    updated_at = now()
  where id = v_item.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_item.faction_id,
    'recruitment_cancelled',
    jsonb_build_object('queue_id', v_item.id)
  );

  return v_item.id;
end;
$$;

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
    where system_building_id = v_building.id and status = 'queued'
  ) or exists (
    select 1 from public.unit_recovery_queue
    where system_building_id = v_building.id and status = 'queued'
  ) then
    raise exception 'Este edificio ya tiene una cola activa';
  end if;

  if v_building.status <> 'active' or v_building.building_kind <> 'recruitment' then
    raise exception 'Este edificio no puede reabastecer unidades';
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
  where id = resupply_unit_at_building.campaign_unit_id
    and faction_id = v_faction_id
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

  if not (v_unit.category = any(v_building.allowed_unit_categories)) then
    raise exception 'Este edificio no puede reabastecer esa categoria';
  end if;

  if v_unit.quantity >= v_unit.starting_quantity and v_unit.wounds_taken <= 0 then
    raise exception 'La unidad ya esta completa';
  end if;

  select *
  into v_template
  from public.unit_templates
  where id = v_unit.unit_template_id;

  if not found then
    raise exception 'La unidad no tiene plantilla de coste';
  end if;

  v_supply_cost := case when v_template.supply_cost > 0 then ceil(v_template.supply_cost::numeric / 2)::integer else 0 end;
  v_minerals_cost := case when v_template.minerals_cost > 0 then ceil(v_template.minerals_cost::numeric / 2)::integer else 0 end;
  v_honor_cost := case when v_template.honor_cost > 0 then ceil(v_template.honor_cost::numeric / 2)::integer else 0 end;
  v_gold_cost := case when v_template.gold_cost > 0 then ceil(v_template.gold_cost::numeric / 2)::integer else 0 end;
  v_industrial_material_cost := case when v_template.industrial_material_cost > 0 then ceil(v_template.industrial_material_cost::numeric / 2)::integer else 0 end;
  v_uridium_cost := case when v_template.uridium_cost > 0 then ceil(v_template.uridium_cost::numeric / 2)::integer else 0 end;
  v_technology_cost := case when v_template.technology_cost > 0 then ceil(v_template.technology_cost::numeric / 2)::integer else 0 end;

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
    greatest(1, v_unit.starting_quantity - v_unit.quantity),
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
    'unit_resupply_started',
    jsonb_build_object(
      'unit_recovery_queue_id', v_queue_id,
      'system_building_id', v_building.id,
      'campaign_unit_id', v_unit.id
    )
  );

  return v_queue_id;
end;
$$;

create or replace function public.heal_unit_at_building(system_building_id uuid, campaign_unit_id uuid, heal_quantity integer)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.resupply_unit_at_building(system_building_id, campaign_unit_id);
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
      quantity = starting_quantity,
      wounds_taken = 0,
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
      'unit_resupply_completed',
      jsonb_build_object(
        'unit_recovery_queue_id', v_item.id,
        'campaign_unit_id', v_item.campaign_unit_id,
        'unit_name', v_item.unit_name
      )
    );

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

create or replace function public.cancel_unit_recovery_queue(queue_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_item public.unit_recovery_queue%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_item
  from public.unit_recovery_queue
  where id = cancel_unit_recovery_queue.queue_id
  for update;

  if not found then
    raise exception 'Cola de reabastecimiento no encontrada';
  end if;

  if v_item.status <> 'queued' then
    raise exception 'La cola no esta activa';
  end if;

  if not v_is_admin and not public.is_faction_member(v_item.faction_id) then
    raise exception 'No puedes cancelar esta cola';
  end if;

  update public.faction_resources
  set
    supply = supply + ceil(v_item.supply_cost::numeric / 2)::integer,
    minerals = minerals + ceil(v_item.minerals_cost::numeric / 2)::integer,
    honor = honor + ceil(v_item.honor_cost::numeric / 2)::integer,
    gold = gold + ceil(v_item.gold_cost::numeric / 2)::integer,
    industrial_material = industrial_material + ceil(v_item.industrial_material_cost::numeric / 2)::integer,
    uridium = uridium + ceil(v_item.uridium_cost::numeric / 2)::integer,
    technology = technology + ceil(v_item.technology_cost::numeric / 2)::integer,
    updated_at = now()
  where faction_id = v_item.faction_id;

  update public.campaign_units
  set
    status = 'ready',
    updated_at = now()
  where id = v_item.campaign_unit_id
    and status = 'recovering';

  update public.unit_recovery_queue
  set
    status = 'cancelled',
    updated_at = now()
  where id = v_item.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_item.faction_id,
    'unit_resupply_cancelled',
    jsonb_build_object('unit_recovery_queue_id', v_item.id)
  );

  return v_item.id;
end;
$$;

create or replace function public.validate_battle_survivors_and_wounds(
  target_conflict_id uuid,
  survivors jsonb,
  wounds_remaining jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conflict public.conflicts%rowtype;
  v_unit record;
  v_survivors integer;
  v_wounds integer;
  v_casualties jsonb := '{}'::jsonb;
begin
  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  if survivors is null or jsonb_typeof(survivors) <> 'object' then
    raise exception 'El reporte debe indicar supervivientes por unidad';
  end if;

  if wounds_remaining is null or jsonb_typeof(wounds_remaining) <> 'object' then
    raise exception 'El reporte debe indicar heridas por unidad';
  end if;

  for v_unit in
    select
      campaign_units.*,
      coalesce(unit_templates.wounds_per_model, 1) as wounds_per_model
    from public.campaign_units
    left join public.unit_templates on unit_templates.id = campaign_units.unit_template_id
    where campaign_units.current_system_id = v_conflict.system_id
      and campaign_units.status = 'in_war'
    order by campaign_units.created_at, campaign_units.id
  loop
    if not (survivors ? v_unit.id::text) then
      raise exception 'Faltan supervivientes para una unidad en guerra';
    end if;

    if not (wounds_remaining ? v_unit.id::text) then
      raise exception 'Faltan heridas restantes para una unidad en guerra';
    end if;

    v_survivors := nullif(survivors->>v_unit.id::text, '')::integer;
    v_wounds := nullif(wounds_remaining->>v_unit.id::text, '')::integer;

    if v_survivors is null or v_survivors < 0 or v_survivors > v_unit.quantity then
      raise exception 'Cantidad de supervivientes no valida';
    end if;

    if v_wounds is null or v_wounds < 0 or v_wounds > v_survivors * v_unit.wounds_per_model then
      raise exception 'Cantidad de heridas no valida';
    end if;

    if v_survivors = 0 and v_wounds <> 0 then
      raise exception 'Una unidad destruida no puede conservar heridas';
    end if;

    v_casualties := v_casualties || jsonb_build_object(v_unit.id::text, v_unit.quantity - v_survivors);
  end loop;

  return v_casualties;
end;
$$;

create or replace function public.calculate_battle_casualties(target_conflict_id uuid, survivors jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wounds jsonb := '{}'::jsonb;
  v_unit record;
begin
  for v_unit in
    select campaign_units.id
    from public.conflicts
    join public.campaign_units on campaign_units.current_system_id = conflicts.system_id
    where conflicts.id = target_conflict_id
      and campaign_units.status = 'in_war'
  loop
    v_wounds := v_wounds || jsonb_build_object(v_unit.id::text, 0);
  end loop;

  return public.validate_battle_survivors_and_wounds(target_conflict_id, survivors, v_wounds);
end;
$$;

create or replace function public.apply_battle_outcome(
  target_conflict_id uuid,
  winner_faction_id uuid,
  final_controller_faction_id uuid,
  post_battle_blocked_until timestamptz,
  survivors jsonb,
  wounds_remaining jsonb,
  actor_user_id uuid,
  actor_faction_id uuid,
  narrative_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conflict public.conflicts%rowtype;
  v_unit public.campaign_units%rowtype;
  v_survivors integer;
  v_wounds integer;
  v_retreat_system_id uuid;
begin
  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id
  for update;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  perform public.validate_battle_survivors_and_wounds(target_conflict_id, survivors, wounds_remaining);

  update public.conflicts
  set
    status = 'resolved',
    winner_faction_id = apply_battle_outcome.winner_faction_id,
    blocked_until = apply_battle_outcome.post_battle_blocked_until,
    resolved_at = now(),
    notes = coalesce(apply_battle_outcome.narrative_notes, notes)
  where id = target_conflict_id;

  update public.systems
  set
    status = case when apply_battle_outcome.final_controller_faction_id is null then 'neutral' else 'controlled' end,
    controller_faction_id = apply_battle_outcome.final_controller_faction_id,
    blocked_until = apply_battle_outcome.post_battle_blocked_until,
    updated_at = now()
  where id = v_conflict.system_id;

  for v_unit in
    select *
    from public.campaign_units
    where current_system_id = v_conflict.system_id
      and status = 'in_war'
    order by created_at, id
    for update
  loop
    v_survivors := (survivors->>v_unit.id::text)::integer;
    v_wounds := (wounds_remaining->>v_unit.id::text)::integer;

    if v_survivors = 0 then
      update public.campaign_units
      set
        quantity = 0,
        wounds_taken = 0,
        status = 'destroyed',
        destroyed_at = now(),
        updated_at = now()
      where id = v_unit.id;
    elsif apply_battle_outcome.final_controller_faction_id is null
      or v_unit.faction_id is not distinct from apply_battle_outcome.final_controller_faction_id then
      update public.campaign_units
      set
        quantity = v_survivors,
        wounds_taken = v_wounds,
        status = 'ready',
        updated_at = now()
      where id = v_unit.id;
    else
      v_retreat_system_id := public.find_retreat_system(v_unit.faction_id, v_conflict.system_id);

      if v_retreat_system_id is null then
        update public.campaign_units
        set
          quantity = v_survivors,
          wounds_taken = v_wounds,
          status = 'retreat_pending',
          updated_at = now()
        where id = v_unit.id;
      else
        update public.campaign_units
        set
          quantity = v_survivors,
          wounds_taken = v_wounds,
          current_system_id = v_retreat_system_id,
          status = 'ready',
          updated_at = now()
        where id = v_unit.id;
      end if;
    end if;
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    apply_battle_outcome.actor_user_id,
    apply_battle_outcome.actor_faction_id,
    'battle_outcome_applied',
    jsonb_build_object(
      'conflict_id', target_conflict_id,
      'winner_faction_id', apply_battle_outcome.winner_faction_id,
      'final_controller_faction_id', apply_battle_outcome.final_controller_faction_id,
      'survivors', survivors,
      'wounds_remaining', wounds_remaining
    )
  );
end;
$$;

create or replace function public.submit_battle_report(conflict_id uuid, report_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.conflicts%rowtype;
  v_reporter_faction_id uuid;
  v_is_admin boolean := false;
  v_report_id uuid;
  v_other public.battle_reports%rowtype;
  v_winner_faction_id uuid;
  v_final_controller_faction_id uuid;
  v_post_battle_blocked_until timestamptz;
  v_casualties jsonb;
  v_survivors jsonb;
  v_wounds_remaining jsonb;
  v_xp_awards jsonb;
  v_enhancements jsonb;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_conflict
  from public.conflicts
  where id = $1
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Conflicto pendiente no encontrado';
  end if;

  select player_factions.faction_id
  into v_reporter_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
    and player_factions.faction_id in (v_conflict.attacker_faction_id, v_conflict.defender_faction_id)
  order by player_factions.created_at
  limit 1;

  if not v_is_admin and v_reporter_faction_id is null then
    raise exception 'Solo participantes o admin pueden reportar esta batalla';
  end if;

  v_winner_faction_id := nullif(report_payload->>'winner_faction_id', '')::uuid;
  v_final_controller_faction_id := nullif(report_payload->>'final_controller_faction_id', '')::uuid;
  v_post_battle_blocked_until := nullif(report_payload->>'post_battle_blocked_until', '')::timestamptz;
  v_survivors := coalesce(report_payload->'survivors', '{}'::jsonb);
  v_wounds_remaining := coalesce(report_payload->'wounds_remaining', '{}'::jsonb);
  v_casualties := public.validate_battle_survivors_and_wounds(v_conflict.id, v_survivors, v_wounds_remaining);
  v_xp_awards := coalesce(report_payload->'xp_awards', '{}'::jsonb);
  v_enhancements := coalesce(report_payload->'enhancements', '{}'::jsonb);

  insert into public.battle_reports (
    conflict_id,
    reporter_user_id,
    reporter_faction_id,
    winner_faction_id,
    final_controller_faction_id,
    casualties,
    survivors,
    wounds_remaining,
    xp_awards,
    enhancements,
    post_battle_blocked_until,
    narrative_notes,
    status
  )
  values (
    v_conflict.id,
    v_user_id,
    v_reporter_faction_id,
    v_winner_faction_id,
    v_final_controller_faction_id,
    v_casualties,
    v_survivors,
    v_wounds_remaining,
    v_xp_awards,
    v_enhancements,
    v_post_battle_blocked_until,
    report_payload->>'narrative_notes',
    'submitted'
  )
  returning id into v_report_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_reporter_faction_id,
    'battle_report_submitted',
    jsonb_build_object('report_id', v_report_id, 'conflict_id', v_conflict.id)
  );

  select *
  into v_other
  from public.battle_reports
  where battle_reports.conflict_id = v_conflict.id
    and battle_reports.id <> v_report_id
    and battle_reports.status = 'submitted'
    and (
      v_reporter_faction_id is null
      or battle_reports.reporter_faction_id is distinct from v_reporter_faction_id
    )
  order by battle_reports.created_at
  limit 1;

  if found then
    if v_other.winner_faction_id is not distinct from v_winner_faction_id
      and v_other.final_controller_faction_id is not distinct from v_final_controller_faction_id
      and v_other.post_battle_blocked_until is not distinct from v_post_battle_blocked_until
      and coalesce(v_other.survivors, '{}'::jsonb) = v_survivors
      and coalesce(v_other.wounds_remaining, '{}'::jsonb) = v_wounds_remaining
      and coalesce(v_other.xp_awards, '{}'::jsonb) = v_xp_awards
      and coalesce(v_other.enhancements, '{}'::jsonb) = v_enhancements then
      update public.battle_reports
      set
        status = 'auto_confirmed',
        resolved_at = now()
      where id in (v_report_id, v_other.id);

      perform public.apply_battle_outcome(
        v_conflict.id,
        v_winner_faction_id,
        v_final_controller_faction_id,
        v_post_battle_blocked_until,
        v_survivors,
        v_wounds_remaining,
        v_user_id,
        v_reporter_faction_id,
        report_payload->>'narrative_notes'
      );

      insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
      values (
        v_user_id,
        v_reporter_faction_id,
        'battle_report_auto_confirmed',
        jsonb_build_object('conflict_id', v_conflict.id, 'report_ids', jsonb_build_array(v_report_id, v_other.id))
      );
    else
      update public.battle_reports
      set status = 'disputed'
      where id in (v_report_id, v_other.id);

      insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
      values (
        v_user_id,
        v_reporter_faction_id,
        'battle_report_disputed',
        jsonb_build_object('conflict_id', v_conflict.id, 'report_ids', jsonb_build_array(v_report_id, v_other.id))
      );
    end if;
  end if;

  return v_report_id;
end;
$$;

drop function if exists public.admin_resolve_battle(uuid, uuid, uuid, jsonb, timestamptz, text);
create or replace function public.admin_resolve_battle(
  target_conflict_id uuid,
  winner_faction_id uuid,
  final_controller_faction_id uuid,
  survivors jsonb default '{}'::jsonb,
  post_battle_blocked_until timestamptz default null,
  narrative_notes text default null,
  wounds_remaining jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_casualties jsonb;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede resolver batallas manualmente';
  end if;

  v_casualties := public.validate_battle_survivors_and_wounds(target_conflict_id, survivors, wounds_remaining);

  perform public.apply_battle_outcome(
    target_conflict_id,
    admin_resolve_battle.winner_faction_id,
    admin_resolve_battle.final_controller_faction_id,
    admin_resolve_battle.post_battle_blocked_until,
    admin_resolve_battle.survivors,
    admin_resolve_battle.wounds_remaining,
    v_user_id,
    admin_resolve_battle.final_controller_faction_id,
    admin_resolve_battle.narrative_notes
  );

  insert into public.battle_reports (
    conflict_id,
    reporter_user_id,
    winner_faction_id,
    final_controller_faction_id,
    casualties,
    survivors,
    wounds_remaining,
    post_battle_blocked_until,
    narrative_notes,
    status,
    resolved_at
  )
  values (
    target_conflict_id,
    v_user_id,
    admin_resolve_battle.winner_faction_id,
    admin_resolve_battle.final_controller_faction_id,
    v_casualties,
    admin_resolve_battle.survivors,
    admin_resolve_battle.wounds_remaining,
    admin_resolve_battle.post_battle_blocked_until,
    admin_resolve_battle.narrative_notes,
    'admin_confirmed',
    now()
  );
end;
$$;

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

  if offer_type = 'buy' then
    if v_resources.gold < gold_amount + v_fee_gold then
      raise exception 'Oro insuficiente para publicar esta compra';
    end if;

    update public.faction_resources
    set gold = gold - (gold_amount + v_fee_gold), updated_at = now()
    where faction_id = v_faction_id;
  else
    if v_current_resource < resource_amount or v_resources.gold < v_fee_gold then
      raise exception 'Recursos insuficientes para publicar esta venta';
    end if;

    update public.faction_resources
    set
      supply = supply - case when v_resource_key = 'supply' then resource_amount else 0 end,
      minerals = minerals - case when v_resource_key = 'minerals' then resource_amount else 0 end,
      industrial_material = industrial_material - case when v_resource_key = 'industrial_material' then resource_amount else 0 end,
      uridium = uridium - case when v_resource_key = 'uridium' then resource_amount else 0 end,
      gold = gold - v_fee_gold,
      updated_at = now()
    where faction_id = v_faction_id;
  end if;

  insert into public.trade_offers (
    creator_faction_id,
    offer_type,
    resource_key,
    resource_amount,
    gold_amount,
    fee_gold,
    status,
    is_reserved
  )
  values (
    v_faction_id,
    offer_type,
    v_resource_key,
    resource_amount,
    gold_amount,
    v_fee_gold,
    'open',
    true
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
      'fee_gold', v_fee_gold,
      'reserved', true
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
  v_resource_key text;
  v_acceptor_resources public.faction_resources%rowtype;
  v_acceptor_current_resource integer;
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

  v_resource_key := public.normalize_trade_resource_key(v_offer.resource_key);

  if v_resource_key is null then
    raise exception 'Oferta con recurso no comerciable';
  end if;

  if not v_offer.is_reserved then
    raise exception 'Oferta antigua sin reserva; debe cancelarse y crearse de nuevo';
  end if;

  if v_offer.creator_faction_id = v_acceptor_faction_id then
    raise exception 'No puedes aceptar tu propia oferta';
  end if;

  select *
  into v_acceptor_resources
  from public.faction_resources
  where faction_id = v_acceptor_faction_id
  for update;

  if not found then
    raise exception 'Faltan recursos inicializados';
  end if;

  v_acceptor_current_resource := case v_resource_key
    when 'supply' then v_acceptor_resources.supply
    when 'minerals' then v_acceptor_resources.minerals
    when 'industrial_material' then v_acceptor_resources.industrial_material
    when 'uridium' then v_acceptor_resources.uridium
    else 0
  end;

  if v_offer.offer_type = 'buy' then
    if v_acceptor_current_resource < v_offer.resource_amount or v_acceptor_resources.gold < v_offer.fee_gold then
      raise exception 'No tienes recursos u oro suficiente para aceptar esta venta';
    end if;

    update public.faction_resources
    set
      supply = supply + case when v_resource_key = 'supply' then v_offer.resource_amount else 0 end,
      minerals = minerals + case when v_resource_key = 'minerals' then v_offer.resource_amount else 0 end,
      industrial_material = industrial_material + case when v_resource_key = 'industrial_material' then v_offer.resource_amount else 0 end,
      uridium = uridium + case when v_resource_key = 'uridium' then v_offer.resource_amount else 0 end,
      updated_at = now()
    where faction_id = v_offer.creator_faction_id;

    update public.faction_resources
    set
      supply = supply - case when v_resource_key = 'supply' then v_offer.resource_amount else 0 end,
      minerals = minerals - case when v_resource_key = 'minerals' then v_offer.resource_amount else 0 end,
      industrial_material = industrial_material - case when v_resource_key = 'industrial_material' then v_offer.resource_amount else 0 end,
      uridium = uridium - case when v_resource_key = 'uridium' then v_offer.resource_amount else 0 end,
      gold = gold + v_offer.gold_amount - v_offer.fee_gold,
      updated_at = now()
    where faction_id = v_acceptor_faction_id;
  else
    if v_acceptor_resources.gold < v_offer.gold_amount + v_offer.fee_gold then
      raise exception 'Oro insuficiente para aceptar esta compra';
    end if;

    update public.faction_resources
    set
      gold = gold + v_offer.gold_amount,
      updated_at = now()
    where faction_id = v_offer.creator_faction_id;

    update public.faction_resources
    set
      supply = supply + case when v_resource_key = 'supply' then v_offer.resource_amount else 0 end,
      minerals = minerals + case when v_resource_key = 'minerals' then v_offer.resource_amount else 0 end,
      industrial_material = industrial_material + case when v_resource_key = 'industrial_material' then v_offer.resource_amount else 0 end,
      uridium = uridium + case when v_resource_key = 'uridium' then v_offer.resource_amount else 0 end,
      gold = gold - (v_offer.gold_amount + v_offer.fee_gold),
      updated_at = now()
    where faction_id = v_acceptor_faction_id;
  end if;

  update public.trade_offers
  set
    resource_key = v_resource_key,
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
      'resource_key', v_resource_key,
      'resource_amount', v_offer.resource_amount,
      'gold_amount', v_offer.gold_amount,
      'fee_gold_each', v_offer.fee_gold
    )
  );

  return v_offer.id;
end;
$$;

create or replace function public.cancel_trade_offer(offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_offer public.trade_offers%rowtype;
  v_resource_key text;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select *
  into v_offer
  from public.trade_offers
  where id = cancel_trade_offer.offer_id
    and status = 'open'
  for update;

  if not found then
    raise exception 'Oferta no disponible';
  end if;

  if not public.is_faction_member(v_offer.creator_faction_id) and not public.is_admin() then
    raise exception 'No puedes cancelar esta oferta';
  end if;

  v_resource_key := public.normalize_trade_resource_key(v_offer.resource_key);

  if v_offer.is_reserved then
    if v_offer.offer_type = 'buy' then
      update public.faction_resources
      set
        gold = gold + v_offer.gold_amount + v_offer.fee_gold,
        updated_at = now()
      where faction_id = v_offer.creator_faction_id;
    elsif v_resource_key is not null then
      update public.faction_resources
      set
        supply = supply + case when v_resource_key = 'supply' then v_offer.resource_amount else 0 end,
        minerals = minerals + case when v_resource_key = 'minerals' then v_offer.resource_amount else 0 end,
        industrial_material = industrial_material + case when v_resource_key = 'industrial_material' then v_offer.resource_amount else 0 end,
        uridium = uridium + case when v_resource_key = 'uridium' then v_offer.resource_amount else 0 end,
        gold = gold + v_offer.fee_gold,
        updated_at = now()
      where faction_id = v_offer.creator_faction_id;
    end if;
  end if;

  update public.trade_offers
  set
    resource_key = coalesce(v_resource_key, resource_key),
    status = 'cancelled',
    cancelled_at = now(),
    updated_at = now()
  where id = v_offer.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_offer.creator_faction_id,
    'trade_offer_cancelled',
    jsonb_build_object('trade_offer_id', v_offer.id, 'reserved_refunded', v_offer.is_reserved)
  );

  return v_offer.id;
end;
$$;

revoke execute on function public.cancel_movement_order(uuid) from public;
revoke execute on function public.cancel_recruitment_queue(uuid) from public;
revoke execute on function public.cancel_unit_recovery_queue(uuid) from public;
revoke execute on function public.resupply_unit_at_building(uuid, uuid) from public;
revoke execute on function public.validate_battle_survivors_and_wounds(uuid, jsonb, jsonb) from public;

grant execute on function public.cancel_movement_order(uuid) to authenticated;
grant execute on function public.cancel_recruitment_queue(uuid) to authenticated;
grant execute on function public.cancel_unit_recovery_queue(uuid) to authenticated;
grant execute on function public.resupply_unit_at_building(uuid, uuid) to authenticated;
