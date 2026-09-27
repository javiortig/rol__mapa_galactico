-- Softer trade rates with half-gold precision and voluntary movement turnbacks.

drop trigger if exists cap_faction_resources_trigger on public.faction_resources;

alter table public.faction_resources
  alter column gold type numeric(12,2) using round(gold::numeric, 2);

create trigger cap_faction_resources_trigger
before insert or update of supply, minerals, honor, gold, industrial_material, uridium, technology
on public.faction_resources
for each row
execute function public.cap_faction_resources();

alter table public.trade_offers
  alter column gold_amount type numeric(12,2) using round(gold_amount::numeric, 2),
  alter column fee_gold type numeric(12,2) using round(fee_gold::numeric, 2);

update public.technology_effects effects
set payload = '{"buy_multiplier":1.35,"sell_multiplier":0.70}'::jsonb
from public.technology_nodes nodes
where nodes.id = effects.technology_node_id
  and nodes.slug = 'tratos-preferentes'
  and effects.effect_type = 'merchant_rate_modifier';

update public.technology_effects effects
set payload = '{"percent":5,"minimum_gold":0.5}'::jsonb
from public.technology_nodes nodes
where nodes.id = effects.technology_node_id
  and nodes.slug = 'aranceles-privilegiados'
  and effects.effect_type = 'stellar_trade_fee_discount';

update public.technology_nodes
set effect_summary = 'Mejora los precios del Mercader: compras al 135% y vendes al 70% del valor.'
where slug = 'tratos-preferentes';

update public.technology_nodes
set effect_summary = 'Reduce tu comisión de Comercio Estelar al 5%, mínimo 0,5 de Oro.'
where slug = 'aranceles-privilegiados';

create or replace function public.round_gold_up_half(value numeric)
returns numeric
language sql
immutable
set search_path = public
as $$
  select ceil(coalesce(value, 0) * 2) / 2;
$$;

create or replace function public.round_gold_down_half(value numeric)
returns numeric
language sql
immutable
set search_path = public
as $$
  select floor(coalesce(value, 0) * 2) / 2;
$$;

create or replace function public.get_merchant_buy_multiplier(target_faction_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    min(nullif((effects.payload->>'buy_multiplier')::numeric, 0)),
    1.50
  )
  from public.technology_effects effects
  join public.faction_technologies progress
    on progress.technology_node_id = effects.technology_node_id
   and progress.faction_id = target_faction_id
   and progress.status = 'unlocked'
  where effects.effect_type = 'merchant_rate_modifier';
$$;

create or replace function public.get_merchant_sell_multiplier(target_faction_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    max(nullif((effects.payload->>'sell_multiplier')::numeric, 0)),
    0.60
  )
  from public.technology_effects effects
  join public.faction_technologies progress
    on progress.technology_node_id = effects.technology_node_id
   and progress.faction_id = target_faction_id
   and progress.status = 'unlocked'
  where effects.effect_type = 'merchant_rate_modifier';
$$;

create or replace function public.get_stellar_trade_fee_percent(target_faction_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    min(nullif((effects.payload->>'percent')::numeric, 0)),
    15
  )
  from public.technology_effects effects
  join public.faction_technologies progress
    on progress.technology_node_id = effects.technology_node_id
   and progress.faction_id = target_faction_id
   and progress.status = 'unlocked'
  where effects.effect_type = 'stellar_trade_fee_discount';
$$;

drop function if exists public.get_stellar_trade_fee_gold(uuid, integer);

create function public.get_stellar_trade_fee_gold(target_faction_id uuid, gold_amount numeric)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select case
    when gold_amount is null or gold_amount <= 0 then 0
    else greatest(
      0.5,
      public.round_gold_up_half(
        gold_amount * public.get_stellar_trade_fee_percent(target_faction_id) / 100
      )
    )
  end;
$$;

drop function if exists public.can_receive_resource(uuid, text, integer);

create function public.can_receive_resource(target_faction_id uuid, resource_key text, delta numeric)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.get_faction_resource_value(target_faction_id, resource_key), 0)
      + greatest(coalesce(delta, 0), 0)
    <= coalesce(public.get_resource_cap_value(resource_key), 0);
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
  v_resource_key text := case
    when lower(trim(coalesce(resource_key, ''))) in ('honor', 'honour') then 'honor'
    else public.normalize_trade_resource_key(resource_key)
  end;
  v_points integer;
  v_resources public.faction_resources%rowtype;
  v_gold_delta numeric := 0;
  v_resource_delta integer := 0;
  v_price_gold numeric;
  v_payout_gold numeric;
  v_current_resource numeric := 0;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if v_resource_key not in ('supply', 'minerals', 'honor') then
    raise exception 'El Mercader solo comercia Suministro vital, Mineral y Honor';
  end if;

  if direction not in ('buy', 'sell') then
    raise exception 'Dirección de comercio inválida';
  end if;

  if trade_quantity is null or trade_quantity < 1 then
    raise exception 'Cantidad inválida';
  end if;

  select public.current_user_faction_id() into v_faction_id;

  if v_faction_id is null then
    raise exception 'El usuario no tiene facción activa';
  end if;

  if not public.has_active_commerce_building(v_faction_id) then
    raise exception 'Necesitas una Cámara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_faction_id, 'unlock_merchant_trade') then
    raise exception 'Necesitas investigar Contactos Económicos para comerciar con el Mercader';
  end if;

  v_points := case v_resource_key
    when 'supply' then 1
    when 'minerals' then 2
    when 'honor' then 5
  end;

  v_price_gold := public.round_gold_up_half(
    (v_points::numeric * trade_quantity * public.get_merchant_buy_multiplier(v_faction_id)) / 5
  );
  v_payout_gold := public.round_gold_down_half(
    (v_points::numeric * trade_quantity * public.get_merchant_sell_multiplier(v_faction_id)) / 5
  );

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La facción no tiene recursos inicializados';
  end if;

  v_current_resource := case v_resource_key
    when 'supply' then v_resources.supply
    when 'minerals' then v_resources.minerals
    when 'honor' then v_resources.honor
    else 0
  end;

  if direction = 'buy' then
    if v_resources.gold < v_price_gold then
      raise exception 'Oro insuficiente';
    end if;

    if not public.can_receive_resource(v_faction_id, v_resource_key, trade_quantity) then
      raise exception 'Capacidad máxima de recurso alcanzada';
    end if;

    v_gold_delta := -v_price_gold;
    v_resource_delta := trade_quantity;
  else
    if v_payout_gold < 0.5 then
      raise exception 'La venta debe alcanzar al menos 0,5 de Oro';
    end if;

    if v_current_resource < trade_quantity then
      raise exception 'Recurso insuficiente';
    end if;

    if not public.can_receive_resource(v_faction_id, 'gold', v_payout_gold) then
      raise exception 'Capacidad máxima de Oro alcanzada';
    end if;

    v_gold_delta := v_payout_gold;
    v_resource_delta := -trade_quantity;
  end if;

  update public.faction_resources
  set
    supply = supply + case when v_resource_key = 'supply' then v_resource_delta else 0 end,
    minerals = minerals + case when v_resource_key = 'minerals' then v_resource_delta else 0 end,
    honor = honor + case when v_resource_key = 'honor' then v_resource_delta else 0 end,
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

drop function if exists public.create_trade_offer(text, text, integer, integer);

create function public.create_trade_offer(
  offer_type text,
  resource_key text,
  resource_amount integer,
  gold_amount numeric
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
  v_fee_gold numeric;
  v_current_resource numeric;
  v_offer_id uuid;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if offer_type not in ('buy', 'sell') then
    raise exception 'Tipo de oferta inválido';
  end if;

  if v_resource_key is null then
    raise exception 'Recurso no comerciable';
  end if;

  if resource_amount is null or resource_amount < 1
    or gold_amount is null or gold_amount < 0.5
    or mod(gold_amount * 2, 1) <> 0 then
    raise exception 'La oferta debe usar cantidades positivas y Oro en pasos de 0,5';
  end if;

  select public.current_user_faction_id() into v_faction_id;

  if v_faction_id is null then
    raise exception 'El usuario no tiene facción activa';
  end if;

  if not public.has_active_commerce_building(v_faction_id) then
    raise exception 'Necesitas una Cámara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_faction_id, 'unlock_stellar_trade') then
    raise exception 'Necesitas investigar Mercado Galáctico para publicar ofertas';
  end if;

  v_fee_gold := public.get_stellar_trade_fee_gold(v_faction_id, gold_amount);

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La facción no tiene recursos inicializados';
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
  v_acceptor_current_resource numeric;
  v_acceptor_fee_gold numeric;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select public.current_user_faction_id() into v_acceptor_faction_id;

  if v_acceptor_faction_id is null then
    raise exception 'El usuario no tiene facción activa';
  end if;

  if not public.has_active_commerce_building(v_acceptor_faction_id) then
    raise exception 'Necesitas una Cámara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_acceptor_faction_id, 'unlock_stellar_trade') then
    raise exception 'Necesitas investigar Mercado Galáctico para aceptar ofertas';
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
      raise exception 'No tienes recursos u Oro suficiente para aceptar esta venta';
    end if;

    if not public.can_receive_resource(v_offer.creator_faction_id, v_resource_key, v_offer.resource_amount) then
      raise exception 'El comprador supera la capacidad máxima del recurso';
    end if;

    if not public.can_receive_resource(v_acceptor_faction_id, 'gold', v_offer.gold_amount - v_acceptor_fee_gold) then
      raise exception 'Superas la capacidad máxima de Oro';
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
      raise exception 'El vendedor supera la capacidad máxima de Oro';
    end if;

    if not public.can_receive_resource(v_acceptor_faction_id, v_resource_key, v_offer.resource_amount) then
      raise exception 'Superas la capacidad máxima del recurso';
    end if;

    update public.faction_resources
    set gold = gold + v_offer.gold_amount, updated_at = now()
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

drop function if exists public.admin_set_faction_resources(uuid, integer, integer, numeric, integer, integer, numeric, integer);

create function public.admin_set_faction_resources(
  target_faction_id uuid,
  supply integer default null,
  minerals integer default null,
  honor numeric default null,
  gold numeric default null,
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
    raise exception 'Solo admin puede modificar recursos de facción';
  end if;

  select *
  into v_before
  from public.faction_resources
  where faction_id = target_faction_id
  for update;

  if not found then
    raise exception 'Facción inválida o sin recursos inicializados';
  end if;

  update public.faction_resources
  set
    supply = greatest(coalesce(admin_set_faction_resources.supply, v_before.supply), 0),
    minerals = greatest(coalesce(admin_set_faction_resources.minerals, v_before.minerals), 0),
    honor = round(greatest(coalesce(admin_set_faction_resources.honor, v_before.honor), 0), 2),
    gold = public.round_gold_down_half(greatest(coalesce(admin_set_faction_resources.gold, v_before.gold), 0)),
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

alter table public.movement_orders
  drop constraint if exists movement_orders_movement_purpose_check,
  add constraint movement_orders_movement_purpose_check
  check (
    movement_purpose in (
      'normal',
      'attack',
      'coalition_staging',
      'defense_support',
      'battle_return',
      'route_fallback',
      'cancel_return'
    )
  );

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
  v_path_length integer;
  v_edge_count integer;
  v_total_seconds numeric;
  v_edge_seconds numeric;
  v_elapsed_seconds numeric;
  v_edge_index integer;
  v_elapsed_in_edge numeric;
  v_last_system_id uuid;
  v_next_system_id uuid;
  v_refund integer := 0;
  v_return_order_id uuid;
  v_return_departure_at timestamptz;
  v_return_arrival_at timestamptz;
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

  if not v_is_admin and not public.is_faction_member(v_order.faction_id) then
    raise exception 'No puedes cancelar este movimiento';
  end if;

  if v_order.movement_type <> 'move' or v_order.movement_purpose <> 'normal' then
    raise exception 'Solo se pueden cancelar movimientos normales';
  end if;

  if v_order.status not in ('pending_approval', 'moving') then
    raise exception 'El movimiento no está activo';
  end if;

  if v_order.status = 'pending_approval' then
    perform public.cancel_reserved_movement_order(
      v_order.id,
      'Movimiento cancelado antes de partir',
      v_order.uridium_cost
    );
    return v_order.id;
  end if;

  if v_order.departure_at is null or v_order.arrival_at is null then
    raise exception 'El movimiento no tiene un trayecto activo';
  end if;

  if v_order.arrival_at <= now() then
    raise exception 'El movimiento ya ha llegado y debe resolverse';
  end if;

  v_path_length := cardinality(v_order.path_system_ids);
  v_edge_count := greatest(v_path_length - 1, 1);

  if v_path_length < 2 then
    raise exception 'El movimiento no tiene una ruta válida';
  end if;

  v_total_seconds := greatest(extract(epoch from (v_order.arrival_at - v_order.departure_at)), 1);
  v_edge_seconds := v_total_seconds / v_edge_count;
  v_elapsed_seconds := least(
    greatest(extract(epoch from (now() - v_order.departure_at)), 0),
    v_total_seconds
  );
  v_edge_index := least(floor(v_elapsed_seconds / v_edge_seconds)::integer, v_edge_count - 1);
  v_elapsed_in_edge := greatest(v_elapsed_seconds - (v_edge_index * v_edge_seconds), 0);
  v_last_system_id := v_order.path_system_ids[v_edge_index + 1];
  v_next_system_id := v_order.path_system_ids[v_edge_index + 2];

  if now() <= v_order.departure_at + interval '1 hour' then
    v_refund := v_order.uridium_cost;
  end if;

  if v_refund > 0 then
    update public.faction_resources
    set uridium = uridium + v_refund, updated_at = now()
    where faction_id = v_order.faction_id;
  end if;

  update public.movement_passage_requests
  set
    status = case when status = 'pending' then 'rejected' else status end,
    response_reason = coalesce(response_reason, 'Movimiento cancelado por su propietario'),
    responded_at = coalesce(responded_at, now())
  where movement_order_id = v_order.id;

  update public.movement_orders
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancellation_reason = 'Movimiento cancelado por su propietario',
    resolved_at = now(),
    updated_at = now()
  where id = v_order.id;

  if v_elapsed_in_edge < 1 then
    update public.campaign_units
    set current_system_id = v_last_system_id, status = 'ready', updated_at = now()
    where id in (
      select unit_id
      from public.movement_order_units
      where movement_order_id = v_order.id
    )
      and status = 'moving';
  else
    v_return_departure_at := now() - make_interval(secs => ceil(v_edge_seconds - v_elapsed_in_edge)::integer);
    v_return_arrival_at := now() + make_interval(secs => ceil(v_elapsed_in_edge)::integer);

    insert into public.movement_orders (
      faction_id,
      from_system_id,
      to_system_id,
      movement_type,
      movement_purpose,
      uridium_cost,
      started_at,
      departure_at,
      arrival_at,
      status,
      path_system_ids,
      segment_count,
      duration_seconds
    )
    values (
      v_order.faction_id,
      v_next_system_id,
      v_last_system_id,
      'move',
      'cancel_return',
      0,
      now(),
      v_return_departure_at,
      v_return_arrival_at,
      'moving',
      array[v_next_system_id, v_last_system_id],
      1,
      ceil(v_edge_seconds)::integer
    )
    returning id into v_return_order_id;

    insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
    select v_return_order_id, unit_id, quantity_at_departure
    from public.movement_order_units
    where movement_order_id = v_order.id;

    update public.campaign_units
    set current_system_id = v_next_system_id, status = 'moving', updated_at = now()
    where id in (
      select unit_id
      from public.movement_order_units
      where movement_order_id = v_order.id
    )
      and status = 'moving';
  end if;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_order.faction_id,
    'movement_turnback_started',
    jsonb_build_object(
      'cancelled_movement_order_id', v_order.id,
      'return_movement_order_id', v_return_order_id,
      'last_system_id', v_last_system_id,
      'next_system_id', v_next_system_id,
      'return_seconds', ceil(v_elapsed_in_edge)::integer,
      'refund_uridium', v_refund
    )
  );

  return v_order.id;
end;
$$;

create or replace function public.resolve_cancelled_return_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_resolved integer := 0;
begin
  for v_order in
    select *
    from public.movement_orders
    where status = 'moving'
      and movement_type = 'move'
      and movement_purpose = 'cancel_return'
      and arrival_at is not null
      and arrival_at <= now()
    order by arrival_at, created_at, id
    for update
  loop
    if not exists (select 1 from public.systems where id = v_order.to_system_id) then
      update public.campaign_units
      set status = 'retreat_pending', updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      )
        and status = 'moving';

      update public.movement_orders
      set
        status = 'cancelled',
        cancelled_at = now(),
        cancellation_reason = 'El sistema de regreso ya no existe',
        resolved_at = now(),
        updated_at = now()
      where id = v_order.id;
    else
      update public.campaign_units
      set current_system_id = v_order.to_system_id, status = 'ready', updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      )
        and status = 'moving';

      update public.movement_orders
      set status = 'arrived', resolved_at = now(), updated_at = now()
      where id = v_order.id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'movement_turnback_arrived',
        jsonb_build_object('movement_order_id', v_order.id, 'system_id', v_order.to_system_id)
      );
    end if;

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

alter function public.resolve_movement_orders()
  rename to resolve_movement_orders_core_0110;

create function public.resolve_movement_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_turnbacks integer;
  v_other_movements integer;
begin
  v_turnbacks := public.resolve_cancelled_return_orders();
  v_other_movements := public.resolve_movement_orders_core_0110();
  return coalesce(v_turnbacks, 0) + coalesce(v_other_movements, 0);
end;
$$;

create or replace function public.get_visible_movement_orders()
returns table (
  id uuid,
  faction_id uuid,
  from_system_id uuid,
  to_system_id uuid,
  uridium_cost integer,
  started_at timestamptz,
  arrival_at timestamptz,
  status text,
  created_at timestamptz,
  path_system_ids uuid[],
  segment_count integer,
  duration_seconds integer,
  cancelled_at timestamptz,
  movement_type text,
  departure_at timestamptz,
  defender_faction_id uuid,
  cancellation_reason text,
  resolved_at timestamptz,
  battle_operation_id uuid,
  movement_purpose text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with full_orders as (
    select movement_orders.*
    from public.movement_orders
    where public.can_select_movement_order(movement_orders.id, movement_orders.faction_id)
  ),
  moving_segmented_orders as (
    select
      movement_orders.*,
      greatest(cardinality(movement_orders.path_system_ids) - 1, 1) as edge_count,
      greatest(extract(epoch from (movement_orders.arrival_at - movement_orders.departure_at)), 1) as total_seconds
    from public.movement_orders
    where movement_orders.status = 'moving'
      and movement_orders.movement_type = 'move'
      and movement_orders.movement_purpose in ('normal', 'route_fallback', 'cancel_return')
      and movement_orders.departure_at is not null
      and movement_orders.arrival_at is not null
      and movement_orders.departure_at <= now()
      and movement_orders.arrival_at > now()
      and cardinality(movement_orders.path_system_ids) >= 2
      and not public.can_select_movement_order(movement_orders.id, movement_orders.faction_id)
  ),
  current_segments as (
    select
      moving_segmented_orders.*,
      least(
        greatest(
          floor(
            extract(epoch from (now() - moving_segmented_orders.departure_at))
              / (moving_segmented_orders.total_seconds / moving_segmented_orders.edge_count)
          )::integer,
          0
        ),
        moving_segmented_orders.edge_count - 1
      ) as edge_index
    from moving_segmented_orders
  ),
  observable_segments as (
    select
      current_segments.*,
      current_segments.path_system_ids[current_segments.edge_index + 1] as edge_from_system_id,
      current_segments.path_system_ids[current_segments.edge_index + 2] as edge_to_system_id,
      current_segments.departure_at
        + (current_segments.arrival_at - current_segments.departure_at)
          * (current_segments.edge_index::double precision / current_segments.edge_count) as edge_started_at,
      current_segments.departure_at
        + (current_segments.arrival_at - current_segments.departure_at)
          * ((current_segments.edge_index + 1)::double precision / current_segments.edge_count) as edge_arrival_at
    from current_segments
  ),
  visible_segments as (
    select observable_segments.*
    from observable_segments
    where exists (
      select 1
      from public.systems
      where systems.id in (
        observable_segments.edge_from_system_id,
        observable_segments.edge_to_system_id
      )
        and systems.controller_faction_id = public.current_user_faction_id()
    )
    or public.user_has_presence_in_system(observable_segments.edge_from_system_id)
  )
  select
    full_orders.id,
    full_orders.faction_id,
    full_orders.from_system_id,
    full_orders.to_system_id,
    full_orders.uridium_cost,
    full_orders.started_at,
    full_orders.arrival_at,
    full_orders.status,
    full_orders.created_at,
    full_orders.path_system_ids,
    full_orders.segment_count,
    full_orders.duration_seconds,
    full_orders.cancelled_at,
    full_orders.movement_type,
    full_orders.departure_at,
    full_orders.defender_faction_id,
    full_orders.cancellation_reason,
    full_orders.resolved_at,
    full_orders.battle_operation_id,
    full_orders.movement_purpose,
    full_orders.updated_at
  from full_orders

  union all

  select
    visible_segments.id,
    visible_segments.faction_id,
    visible_segments.edge_from_system_id,
    visible_segments.edge_to_system_id,
    0,
    visible_segments.edge_started_at,
    visible_segments.edge_arrival_at,
    'moving'::text,
    visible_segments.created_at,
    array[visible_segments.edge_from_system_id, visible_segments.edge_to_system_id],
    1,
    greatest(round(extract(epoch from (visible_segments.edge_arrival_at - visible_segments.edge_started_at)))::integer, 1),
    null::timestamptz,
    'move'::text,
    visible_segments.edge_started_at,
    null::uuid,
    null::text,
    null::timestamptz,
    null::uuid,
    visible_segments.movement_purpose,
    visible_segments.updated_at
  from visible_segments
  order by arrival_at nulls last;
$$;

revoke all on function public.round_gold_up_half(numeric) from public, anon, authenticated;
revoke all on function public.round_gold_down_half(numeric) from public, anon, authenticated;
revoke all on function public.get_merchant_buy_multiplier(uuid) from public, anon, authenticated;
revoke all on function public.get_merchant_sell_multiplier(uuid) from public, anon, authenticated;
revoke all on function public.get_stellar_trade_fee_percent(uuid) from public, anon, authenticated;
revoke all on function public.get_stellar_trade_fee_gold(uuid, numeric) from public, anon, authenticated;
revoke all on function public.can_receive_resource(uuid, text, numeric) from public, anon, authenticated;
revoke all on function public.resolve_cancelled_return_orders() from public, anon, authenticated;
revoke all on function public.resolve_movement_orders_core_0110() from public, anon, authenticated;

revoke execute on function public.merchant_trade(text, text, integer) from public;
revoke execute on function public.create_trade_offer(text, text, integer, numeric) from public;
revoke execute on function public.accept_trade_offer(uuid) from public;
revoke execute on function public.cancel_movement_order(uuid) from public;
revoke execute on function public.admin_set_faction_resources(uuid, integer, integer, numeric, numeric, integer, numeric, integer) from public;
revoke execute on function public.get_visible_movement_orders() from public;
revoke execute on function public.resolve_movement_orders() from public;

grant execute on function public.can_receive_resource(uuid, text, numeric) to authenticated;
grant execute on function public.merchant_trade(text, text, integer) to authenticated;
grant execute on function public.create_trade_offer(text, text, integer, numeric) to authenticated;
grant execute on function public.accept_trade_offer(uuid) to authenticated;
grant execute on function public.cancel_movement_order(uuid) to authenticated;
grant execute on function public.admin_set_faction_resources(uuid, integer, integer, numeric, numeric, integer, numeric, integer) to authenticated;
grant execute on function public.get_visible_movement_orders() to authenticated;
grant execute on function public.resolve_movement_orders() to authenticated;

notify pgrst, 'reload schema';
