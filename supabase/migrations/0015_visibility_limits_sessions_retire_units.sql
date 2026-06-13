alter table public.campaign_settings
  add column if not exists max_supply integer not null default 500 check (max_supply >= 0),
  add column if not exists max_minerals integer not null default 500 check (max_minerals >= 0),
  add column if not exists max_honor integer not null default 500 check (max_honor >= 0),
  add column if not exists max_gold integer not null default 500 check (max_gold >= 0),
  add column if not exists max_industrial_material integer not null default 500 check (max_industrial_material >= 0),
  add column if not exists max_uridium integer not null default 500 check (max_uridium >= 0),
  add column if not exists max_technology integer not null default 500 check (max_technology >= 0),
  add column if not exists max_army_points integer not null default 1000 check (max_army_points >= 0);

insert into public.campaign_settings (id, resource_tick_interval_hours, next_resource_tick_at)
values ('default', 24, now() + interval '24 hours')
on conflict (id) do nothing;

create or replace function public.current_user_faction_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select player_factions.faction_id
  from public.player_factions
  where player_factions.user_id = auth.uid()
  order by player_factions.created_at
  limit 1;
$$;

create or replace function public.user_has_presence_in_system(target_system_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.campaign_units
    where campaign_units.current_system_id = target_system_id
      and campaign_units.faction_id = public.current_user_faction_id()
      and campaign_units.status <> 'destroyed'
      and campaign_units.quantity > 0
  );
$$;

create or replace function public.get_resource_cap_value(resource_key text)
returns integer
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
  end
  from public.campaign_settings
  where id = 'default';
$$;

create or replace function public.get_faction_resource_value(target_faction_id uuid, resource_key text)
returns integer
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
  end
  from public.faction_resources
  where faction_id = target_faction_id;
$$;

create or replace function public.can_receive_resource(target_faction_id uuid, resource_key text, delta integer)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.get_faction_resource_value(target_faction_id, resource_key), 0) + greatest(coalesce(delta, 0), 0)
    <= coalesce(public.get_resource_cap_value(resource_key), 0);
$$;

create or replace function public.cap_faction_resources()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.campaign_settings%rowtype;
begin
  select *
  into v_settings
  from public.campaign_settings
  where id = 'default';

  if not found then
    return new;
  end if;

  new.supply := least(greatest(coalesce(new.supply, 0), 0), v_settings.max_supply);
  new.minerals := least(greatest(coalesce(new.minerals, 0), 0), v_settings.max_minerals);
  new.honor := least(greatest(coalesce(new.honor, 0), 0), v_settings.max_honor);
  new.gold := least(greatest(coalesce(new.gold, 0), 0), v_settings.max_gold);
  new.industrial_material := least(greatest(coalesce(new.industrial_material, 0), 0), v_settings.max_industrial_material);
  new.uridium := least(greatest(coalesce(new.uridium, 0), 0), v_settings.max_uridium);
  new.technology := least(greatest(coalesce(new.technology, 0), 0), v_settings.max_technology);
  return new;
end;
$$;

drop trigger if exists cap_faction_resources_trigger on public.faction_resources;
create trigger cap_faction_resources_trigger
before insert or update of supply, minerals, honor, gold, industrial_material, uridium, technology
on public.faction_resources
for each row
execute function public.cap_faction_resources();

update public.faction_resources
set
  supply = supply,
  minerals = minerals,
  honor = honor,
  gold = gold,
  industrial_material = industrial_material,
  uridium = uridium,
  technology = technology,
  updated_at = now();

create or replace function public.faction_army_points(target_faction_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((
      select sum(campaign_units.points)
      from public.campaign_units
      where campaign_units.faction_id = target_faction_id
        and campaign_units.status <> 'destroyed'
        and campaign_units.quantity > 0
    ), 0)::integer
    +
    coalesce((
      select sum(unit_templates.points * recruitment_queue.quantity)
      from public.recruitment_queue
      join public.unit_templates on unit_templates.id = recruitment_queue.unit_template_id
      where recruitment_queue.faction_id = target_faction_id
        and recruitment_queue.status = 'queued'
    ), 0)::integer;
$$;

create or replace function public.max_army_points()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select max_army_points
  from public.campaign_settings
  where id = 'default';
$$;

create or replace function public.enforce_recruitment_points_cap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_points integer;
  v_new_points integer;
  v_max_points integer;
begin
  if new.status <> 'queued' then
    return new;
  end if;

  select coalesce(max_army_points, 1000)
  into v_max_points
  from public.campaign_settings
  where id = 'default';

  select public.faction_army_points(new.faction_id)
  into v_current_points;

  select coalesce(unit_templates.points, 0) * greatest(coalesce(new.quantity, 1), 1)
  into v_new_points
  from public.unit_templates
  where id = new.unit_template_id;

  if coalesce(v_current_points, 0) + coalesce(v_new_points, 0) > coalesce(v_max_points, 1000) then
    raise exception 'Limite de puntos de ejercito superado (%/% pts)', coalesce(v_current_points, 0) + coalesce(v_new_points, 0), coalesce(v_max_points, 1000);
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_recruitment_points_cap_trigger on public.recruitment_queue;
create trigger enforce_recruitment_points_cap_trigger
before insert on public.recruitment_queue
for each row
execute function public.enforce_recruitment_points_cap();

drop policy if exists campaign_units_select_visible_member_or_admin on public.campaign_units;
create policy campaign_units_select_visible_member_or_admin
on public.campaign_units
for select
to authenticated
using (
  public.is_admin()
  or is_visible_publicly
  or public.is_faction_member(faction_id)
  or public.user_has_presence_in_system(current_system_id)
);

revoke select on public.system_buildings from anon, authenticated;

drop policy if exists system_buildings_select_public on public.system_buildings;
drop policy if exists system_buildings_select_admin_only on public.system_buildings;
create policy system_buildings_select_admin_only
on public.system_buildings
for select
to authenticated
using (public.is_admin());

create or replace function public.get_visible_system_buildings()
returns table (
  id uuid,
  system_id uuid,
  building_template_id uuid,
  status text,
  started_at timestamptz,
  finishes_at timestamptz,
  constructed_at timestamptz,
  details_visible boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    system_buildings.id,
    system_buildings.system_id,
    case
      when public.is_admin()
        or systems.controller_faction_id = public.current_user_faction_id()
        or public.user_has_presence_in_system(system_buildings.system_id)
      then system_buildings.building_template_id
      else null::uuid
    end as building_template_id,
    system_buildings.status,
    system_buildings.started_at,
    system_buildings.finishes_at,
    system_buildings.constructed_at,
    (
      public.is_admin()
      or systems.controller_faction_id = public.current_user_faction_id()
      or public.user_has_presence_in_system(system_buildings.system_id)
    ) as details_visible
  from public.system_buildings
  join public.systems on systems.id = system_buildings.system_id
  where system_buildings.status <> 'disabled'
  order by system_buildings.created_at;
$$;

create or replace function public.retire_campaign_unit(campaign_unit_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_unit public.campaign_units%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select *
  into v_unit
  from public.campaign_units
  where id = retire_campaign_unit.campaign_unit_id
  for update;

  if not found then
    raise exception 'Unidad no encontrada';
  end if;

  if not public.is_admin() and not public.is_faction_member(v_unit.faction_id) then
    raise exception 'No puedes retirar esta unidad';
  end if;

  if v_unit.status <> 'ready' then
    raise exception 'Solo puedes retirar unidades listas';
  end if;

  update public.campaign_units
  set
    status = 'destroyed',
    quantity = 0,
    wounds_taken = 0,
    destroyed_at = now(),
    updated_at = now()
  where id = v_unit.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_unit.faction_id,
    'unit_retired',
    jsonb_build_object(
      'campaign_unit_id', v_unit.id,
      'system_id', v_unit.current_system_id,
      'points', v_unit.points
    )
  );

  return v_unit.id;
end;
$$;

create or replace function public.admin_set_campaign_limits(
  max_supply integer,
  max_minerals integer,
  max_honor integer,
  max_gold integer,
  max_industrial_material integer,
  max_uridium integer,
  max_technology integer,
  max_army_points integer
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
    raise exception 'Solo admin puede modificar limites de campana';
  end if;

  update public.campaign_settings
  set
    max_supply = greatest(coalesce(admin_set_campaign_limits.max_supply, public.campaign_settings.max_supply), 0),
    max_minerals = greatest(coalesce(admin_set_campaign_limits.max_minerals, public.campaign_settings.max_minerals), 0),
    max_honor = greatest(coalesce(admin_set_campaign_limits.max_honor, public.campaign_settings.max_honor), 0),
    max_gold = greatest(coalesce(admin_set_campaign_limits.max_gold, public.campaign_settings.max_gold), 0),
    max_industrial_material = greatest(coalesce(admin_set_campaign_limits.max_industrial_material, public.campaign_settings.max_industrial_material), 0),
    max_uridium = greatest(coalesce(admin_set_campaign_limits.max_uridium, public.campaign_settings.max_uridium), 0),
    max_technology = greatest(coalesce(admin_set_campaign_limits.max_technology, public.campaign_settings.max_technology), 0),
    max_army_points = greatest(coalesce(admin_set_campaign_limits.max_army_points, public.campaign_settings.max_army_points), 0),
    updated_at = now()
  where id = 'default';

  update public.faction_resources
  set
    supply = supply,
    minerals = minerals,
    honor = honor,
    gold = gold,
    industrial_material = industrial_material,
    uridium = uridium,
    technology = technology,
    updated_at = now();

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_campaign_limits_updated',
    jsonb_build_object(
      'max_supply', admin_set_campaign_limits.max_supply,
      'max_minerals', admin_set_campaign_limits.max_minerals,
      'max_honor', admin_set_campaign_limits.max_honor,
      'max_gold', admin_set_campaign_limits.max_gold,
      'max_industrial_material', admin_set_campaign_limits.max_industrial_material,
      'max_uridium', admin_set_campaign_limits.max_uridium,
      'max_technology', admin_set_campaign_limits.max_technology,
      'max_army_points', admin_set_campaign_limits.max_army_points
    )
  );
end;
$$;

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
  v_current_points integer;
  v_max_points integer;
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

  select public.faction_army_points(target_faction_id), public.max_army_points()
  into v_current_points, v_max_points;

  if coalesce(v_current_points, 0) + coalesce(v_template.points, 0) > coalesce(v_max_points, 1000) then
    raise exception 'Limite de puntos de ejercito superado (%/% pts)', coalesce(v_current_points, 0) + coalesce(v_template.points, 0), coalesce(v_max_points, 1000);
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

  select public.current_user_faction_id() into v_faction_id;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  if not public.has_active_commerce_building(v_faction_id) then
    raise exception 'Necesitas una Camara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_faction_id, 'unlock_merchant_trade') then
    raise exception 'Necesitas investigar Contactos Economicos para comerciar con el Mercader';
  end if;

  v_points := public.trade_resource_points(v_resource_key);
  v_price_gold := ceil((v_points::numeric * trade_quantity * public.get_merchant_buy_multiplier(v_faction_id)) / 5)::integer;
  v_payout_gold := ceil((v_points::numeric * trade_quantity * public.get_merchant_sell_multiplier(v_faction_id)) / 5)::integer;

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

    if not public.can_receive_resource(v_faction_id, v_resource_key, trade_quantity) then
      raise exception 'Capacidad maxima de recurso alcanzada';
    end if;

    v_gold_delta := -v_price_gold;
    v_resource_delta := trade_quantity;
  else
    if v_current_resource < trade_quantity then
      raise exception 'Recurso insuficiente';
    end if;

    if not public.can_receive_resource(v_faction_id, 'gold', v_payout_gold) then
      raise exception 'Capacidad maxima de oro alcanzada';
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
  v_acceptor_fee_gold integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select public.current_user_faction_id() into v_acceptor_faction_id;

  if v_acceptor_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  if not public.has_active_commerce_building(v_acceptor_faction_id) then
    raise exception 'Necesitas una Camara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_acceptor_faction_id, 'unlock_stellar_trade') then
    raise exception 'Necesitas investigar Mercado Galactico para aceptar ofertas';
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

  v_acceptor_fee_gold := public.get_stellar_trade_fee_gold(v_acceptor_faction_id, v_offer.gold_amount);

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
    if v_acceptor_current_resource < v_offer.resource_amount or v_acceptor_resources.gold < v_acceptor_fee_gold then
      raise exception 'No tienes recursos u oro suficiente para aceptar esta venta';
    end if;

    if not public.can_receive_resource(v_offer.creator_faction_id, v_resource_key, v_offer.resource_amount) then
      raise exception 'El comprador supera la capacidad maxima del recurso';
    end if;

    if not public.can_receive_resource(v_acceptor_faction_id, 'gold', v_offer.gold_amount - v_acceptor_fee_gold) then
      raise exception 'Superas la capacidad maxima de oro';
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
      gold = gold + v_offer.gold_amount - v_acceptor_fee_gold,
      updated_at = now()
    where faction_id = v_acceptor_faction_id;
  else
    if v_acceptor_resources.gold < v_offer.gold_amount + v_acceptor_fee_gold then
      raise exception 'Oro insuficiente para aceptar esta compra';
    end if;

    if not public.can_receive_resource(v_offer.creator_faction_id, 'gold', v_offer.gold_amount) then
      raise exception 'El vendedor supera la capacidad maxima de oro';
    end if;

    if not public.can_receive_resource(v_acceptor_faction_id, v_resource_key, v_offer.resource_amount) then
      raise exception 'Superas la capacidad maxima del recurso';
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
      gold = gold - (v_offer.gold_amount + v_acceptor_fee_gold),
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
      'creator_fee_gold', v_offer.fee_gold,
      'acceptor_fee_gold', v_acceptor_fee_gold
    )
  );

  return v_offer.id;
end;
$$;

revoke execute on function public.current_user_faction_id() from public;
revoke execute on function public.user_has_presence_in_system(uuid) from public;
revoke execute on function public.get_resource_cap_value(text) from public;
revoke execute on function public.get_faction_resource_value(uuid, text) from public;
revoke execute on function public.can_receive_resource(uuid, text, integer) from public;
revoke execute on function public.faction_army_points(uuid) from public;
revoke execute on function public.max_army_points() from public;
revoke execute on function public.get_visible_system_buildings() from public;
revoke execute on function public.retire_campaign_unit(uuid) from public;
revoke execute on function public.admin_set_campaign_limits(integer, integer, integer, integer, integer, integer, integer, integer) from public;

grant execute on function public.get_visible_system_buildings() to authenticated;
grant execute on function public.current_user_faction_id() to authenticated;
grant execute on function public.user_has_presence_in_system(uuid) to authenticated;
grant execute on function public.retire_campaign_unit(uuid) to authenticated;
grant execute on function public.admin_set_campaign_limits(integer, integer, integer, integer, integer, integer, integer, integer) to authenticated;
grant execute on function public.merchant_trade(text, text, integer) to authenticated;
grant execute on function public.accept_trade_offer(uuid) to authenticated;
