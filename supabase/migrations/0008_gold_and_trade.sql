alter table public.faction_resources
  add column if not exists gold integer not null default 0 check (gold >= 0);

alter table public.system_production
  add column if not exists gold_per_tick integer not null default 0 check (gold_per_tick >= 0);

alter table public.unit_templates
  add column if not exists gold_cost integer not null default 0 check (gold_cost >= 0);

alter table public.recruitment_queue
  add column if not exists gold_cost integer not null default 0 check (gold_cost >= 0);

create table if not exists public.trade_offers (
  id uuid primary key default gen_random_uuid(),
  creator_faction_id uuid not null references public.factions(id) on delete cascade,
  offer_type text not null check (offer_type in ('buy', 'sell')),
  resource_key text not null check (resource_key in ('supply', 'minerals', 'ancestral_stone', 'uridium')),
  resource_amount integer not null check (resource_amount > 0),
  gold_amount integer not null check (gold_amount > 0),
  fee_gold integer not null check (fee_gold >= 0),
  status text not null default 'open' check (status in ('open', 'accepted', 'cancelled')),
  accepted_by_faction_id uuid references public.factions(id),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  cancelled_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists trade_offers_status_created_idx on public.trade_offers (status, created_at desc);
create index if not exists trade_offers_creator_status_idx on public.trade_offers (creator_faction_id, status);
create index if not exists trade_offers_accepted_by_idx on public.trade_offers (accepted_by_faction_id);

alter table public.trade_offers enable row level security;

grant select on public.trade_offers to authenticated;

drop policy if exists trade_offers_select_open_own_or_admin on public.trade_offers;
create policy trade_offers_select_open_own_or_admin
on public.trade_offers
for select
to authenticated
using (
  public.is_admin()
  or status = 'open'
  or public.is_faction_member(creator_faction_id)
  or (accepted_by_faction_id is not null and public.is_faction_member(accepted_by_faction_id))
);

drop policy if exists trade_offers_admin_all on public.trade_offers;
create policy trade_offers_admin_all
on public.trade_offers
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.normalize_trade_resource_key(resource_key text)
returns text
language sql
immutable
as $$
  select case resource_key
    when 'supply' then 'supply'
    when 'minerals' then 'minerals'
    when 'ancestralStone' then 'ancestral_stone'
    when 'ancestral_stone' then 'ancestral_stone'
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
    when 'uridium' then 2
    when 'ancestral_stone' then 5
    else null
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
      gold,
      uridium,
      technology,
      updated_at
    )
    select
      systems.controller_faction_id,
      coalesce(sum(system_production.supply_per_tick), 0)::integer,
      coalesce(sum(system_production.minerals_per_tick), 0)::integer,
      coalesce(sum(system_production.ancestral_stone_per_tick), 0)::integer,
      coalesce(sum(system_production.gold_per_tick), 0)::integer,
      coalesce(sum(system_production.uridium_per_tick), 0)::integer,
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
      ancestral_stone = public.faction_resources.ancestral_stone + excluded.ancestral_stone,
      gold = public.faction_resources.gold + excluded.gold,
      uridium = public.faction_resources.uridium + excluded.uridium,
      updated_at = now();

    insert into public.campaign_logs (action_type, payload)
    values (
      'resource_tick_applied',
      jsonb_build_object('tick_at', v_tick_at)
    );

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

create or replace function public.recruit_unit(unit_template_id uuid, quantity integer)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_template public.unit_templates%rowtype;
  v_resources public.faction_resources%rowtype;
  v_is_admin boolean := false;
  v_queue_id uuid;
  v_quantity integer := quantity;
  v_supply_cost integer;
  v_minerals_cost integer;
  v_ancestral_stone_cost integer;
  v_gold_cost integer;
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

  perform public.resolve_technology_research();

  if v_quantity is null or v_quantity < 1 then
    raise exception 'Cantidad invalida';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_template
  from public.unit_templates
  where id = $1
    and is_available = true;

  if not found then
    raise exception 'Unidad no disponible';
  end if;

  if not v_is_admin and not exists (
    select 1
    from public.player_factions
    where user_id = v_user_id
      and faction_id = v_template.faction_id
  ) then
    raise exception 'No puedes reclutar unidades de esta faccion';
  end if;

  if v_template.required_technology_node_id is not null
    and not exists (
      select 1
      from public.faction_technologies
      where faction_id = v_template.faction_id
        and technology_node_id = v_template.required_technology_node_id
        and status = 'unlocked'
    ) then
    raise exception 'Esta unidad requiere tecnologia desbloqueada';
  end if;

  v_supply_cost := v_template.supply_cost * v_quantity;
  v_minerals_cost := v_template.minerals_cost * v_quantity;
  v_ancestral_stone_cost := v_template.ancestral_stone_cost * v_quantity;
  v_gold_cost := v_template.gold_cost * v_quantity;
  v_uridium_cost := v_template.uridium_cost * v_quantity;
  v_technology_cost := v_template.technology_cost * v_quantity;
  v_recruitment_seconds := v_template.recruitment_time_seconds * v_quantity;

  for v_effect in
    select technology_effects.*
    from public.technology_effects
    join public.faction_technologies
      on faction_technologies.technology_node_id = technology_effects.technology_node_id
    where faction_technologies.faction_id = v_template.faction_id
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
      if v_resource in ('all', 'ancestralStone', 'ancestral_stone') and v_ancestral_stone_cost > 0 then
        v_ancestral_stone_cost := greatest(1, floor((v_ancestral_stone_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'gold') and v_gold_cost > 0 then
        v_gold_cost := greatest(1, floor((v_gold_cost::numeric * (100 - v_percent)) / 100)::integer);
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
  where faction_id = v_template.faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
  end if;

  if v_resources.supply < v_supply_cost
    or v_resources.minerals < v_minerals_cost
    or v_resources.ancestral_stone < v_ancestral_stone_cost
    or v_resources.gold < v_gold_cost
    or v_resources.uridium < v_uridium_cost
    or v_resources.technology < v_technology_cost then
    raise exception 'Recursos insuficientes';
  end if;

  update public.faction_resources
  set
    supply = supply - v_supply_cost,
    minerals = minerals - v_minerals_cost,
    ancestral_stone = ancestral_stone - v_ancestral_stone_cost,
    gold = gold - v_gold_cost,
    uridium = uridium - v_uridium_cost,
    technology = technology - v_technology_cost,
    updated_at = now()
  where faction_id = v_template.faction_id;

  insert into public.recruitment_queue (
    faction_id,
    unit_template_id,
    quantity,
    supply_cost,
    minerals_cost,
    ancestral_stone_cost,
    gold_cost,
    uridium_cost,
    technology_cost,
    started_at,
    finishes_at,
    status
  )
  values (
    v_template.faction_id,
    v_template.id,
    v_quantity,
    v_supply_cost,
    v_minerals_cost,
    v_ancestral_stone_cost,
    v_gold_cost,
    v_uridium_cost,
    v_technology_cost,
    now(),
    now() + make_interval(secs => v_recruitment_seconds),
    'queued'
  )
  returning id into v_queue_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_template.faction_id,
    'recruitment_started',
    jsonb_build_object(
      'queue_id', v_queue_id,
      'unit_template_id', v_template.id,
      'unit_name', v_template.name,
      'quantity', v_quantity,
      'supply_cost', v_supply_cost,
      'minerals_cost', v_minerals_cost,
      'ancestral_stone_cost', v_ancestral_stone_cost,
      'gold_cost', v_gold_cost,
      'uridium_cost', v_uridium_cost,
      'technology_cost', v_technology_cost,
      'duration_seconds', v_recruitment_seconds
    )
  );

  return v_queue_id;
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

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  v_points := public.trade_resource_points(v_resource_key);
  v_price_gold := ceil((v_points::numeric * trade_quantity * 2) / 5)::integer;
  v_payout_gold := ceil((v_points::numeric * trade_quantity * 0.5) / 5)::integer;

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
    when 'ancestral_stone' then v_resources.ancestral_stone
    when 'uridium' then v_resources.uridium
    else 0
  end;

  if direction = 'buy' then
    if v_resources.gold < v_price_gold then
      raise exception 'Oro insuficiente';
    end if;

    v_gold_delta := -v_price_gold;
    v_resource_delta := trade_quantity;
  else
    if v_current_resource < trade_quantity then
      raise exception 'Recurso insuficiente';
    end if;

    v_gold_delta := v_payout_gold;
    v_resource_delta := -trade_quantity;
  end if;

  update public.faction_resources
  set
    supply = supply + case when v_resource_key = 'supply' then v_resource_delta else 0 end,
    minerals = minerals + case when v_resource_key = 'minerals' then v_resource_delta else 0 end,
    ancestral_stone = ancestral_stone + case when v_resource_key = 'ancestral_stone' then v_resource_delta else 0 end,
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
    when 'ancestral_stone' then v_resources.ancestral_stone
    when 'uridium' then v_resources.uridium
    else 0
  end;

  if offer_type = 'buy' and v_resources.gold < gold_amount + v_fee_gold then
    raise exception 'Oro insuficiente para publicar esta compra';
  end if;

  if offer_type = 'sell' and (v_current_resource < resource_amount or v_resources.gold < v_fee_gold) then
    raise exception 'Recursos insuficientes para publicar esta venta';
  end if;

  insert into public.trade_offers (
    creator_faction_id,
    offer_type,
    resource_key,
    resource_amount,
    gold_amount,
    fee_gold,
    status
  )
  values (
    v_faction_id,
    offer_type,
    v_resource_key,
    resource_amount,
    gold_amount,
    v_fee_gold,
    'open'
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
      'fee_gold', v_fee_gold
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
  v_creator_resources public.faction_resources%rowtype;
  v_acceptor_resources public.faction_resources%rowtype;
  v_creator_current_resource integer;
  v_acceptor_current_resource integer;
  v_creator_resource_delta integer := 0;
  v_acceptor_resource_delta integer := 0;
  v_creator_gold_delta integer := 0;
  v_acceptor_gold_delta integer := 0;
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

  select *
  into v_offer
  from public.trade_offers
  where id = accept_trade_offer.offer_id
    and status = 'open'
  for update;

  if not found then
    raise exception 'Oferta no disponible';
  end if;

  if v_offer.creator_faction_id = v_acceptor_faction_id then
    raise exception 'No puedes aceptar tu propia oferta';
  end if;

  select *
  into v_creator_resources
  from public.faction_resources
  where faction_id = v_offer.creator_faction_id
  for update;

  select *
  into v_acceptor_resources
  from public.faction_resources
  where faction_id = v_acceptor_faction_id
  for update;

  if not found then
    raise exception 'Faltan recursos inicializados';
  end if;

  v_creator_current_resource := case v_offer.resource_key
    when 'supply' then v_creator_resources.supply
    when 'minerals' then v_creator_resources.minerals
    when 'ancestral_stone' then v_creator_resources.ancestral_stone
    when 'uridium' then v_creator_resources.uridium
    else 0
  end;

  v_acceptor_current_resource := case v_offer.resource_key
    when 'supply' then v_acceptor_resources.supply
    when 'minerals' then v_acceptor_resources.minerals
    when 'ancestral_stone' then v_acceptor_resources.ancestral_stone
    when 'uridium' then v_acceptor_resources.uridium
    else 0
  end;

  if v_offer.offer_type = 'buy' then
    if v_creator_resources.gold < v_offer.gold_amount + v_offer.fee_gold then
      raise exception 'El comprador ya no tiene oro suficiente';
    end if;

    if v_acceptor_current_resource < v_offer.resource_amount or v_acceptor_resources.gold < v_offer.fee_gold then
      raise exception 'El vendedor no tiene recursos u oro para la comision';
    end if;

    v_creator_resource_delta := v_offer.resource_amount;
    v_creator_gold_delta := -(v_offer.gold_amount + v_offer.fee_gold);
    v_acceptor_resource_delta := -v_offer.resource_amount;
    v_acceptor_gold_delta := v_offer.gold_amount - v_offer.fee_gold;
  else
    if v_creator_current_resource < v_offer.resource_amount or v_creator_resources.gold < v_offer.fee_gold then
      raise exception 'El vendedor ya no tiene recursos u oro para la comision';
    end if;

    if v_acceptor_resources.gold < v_offer.gold_amount + v_offer.fee_gold then
      raise exception 'El comprador no tiene oro suficiente';
    end if;

    v_creator_resource_delta := -v_offer.resource_amount;
    v_creator_gold_delta := v_offer.gold_amount - v_offer.fee_gold;
    v_acceptor_resource_delta := v_offer.resource_amount;
    v_acceptor_gold_delta := -(v_offer.gold_amount + v_offer.fee_gold);
  end if;

  update public.faction_resources
  set
    supply = supply + case when v_offer.resource_key = 'supply' then v_creator_resource_delta else 0 end,
    minerals = minerals + case when v_offer.resource_key = 'minerals' then v_creator_resource_delta else 0 end,
    ancestral_stone = ancestral_stone + case when v_offer.resource_key = 'ancestral_stone' then v_creator_resource_delta else 0 end,
    uridium = uridium + case when v_offer.resource_key = 'uridium' then v_creator_resource_delta else 0 end,
    gold = gold + v_creator_gold_delta,
    updated_at = now()
  where faction_id = v_offer.creator_faction_id;

  update public.faction_resources
  set
    supply = supply + case when v_offer.resource_key = 'supply' then v_acceptor_resource_delta else 0 end,
    minerals = minerals + case when v_offer.resource_key = 'minerals' then v_acceptor_resource_delta else 0 end,
    ancestral_stone = ancestral_stone + case when v_offer.resource_key = 'ancestral_stone' then v_acceptor_resource_delta else 0 end,
    uridium = uridium + case when v_offer.resource_key = 'uridium' then v_acceptor_resource_delta else 0 end,
    gold = gold + v_acceptor_gold_delta,
    updated_at = now()
  where faction_id = v_acceptor_faction_id;

  update public.trade_offers
  set
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
      'resource_key', v_offer.resource_key,
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
  v_faction_id uuid;
  v_offer public.trade_offers%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  select *
  into v_offer
  from public.trade_offers
  where id = cancel_trade_offer.offer_id
    and status = 'open'
  for update;

  if not found then
    raise exception 'Oferta no disponible';
  end if;

  if not public.is_admin() and v_offer.creator_faction_id is distinct from v_faction_id then
    raise exception 'Solo puedes cancelar tus propias ofertas';
  end if;

  update public.trade_offers
  set
    status = 'cancelled',
    cancelled_at = now(),
    updated_at = now()
  where id = v_offer.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_offer.creator_faction_id,
    'trade_offer_cancelled',
    jsonb_build_object('trade_offer_id', v_offer.id)
  );

  return v_offer.id;
end;
$$;

revoke execute on function public.normalize_trade_resource_key(text) from public;
revoke execute on function public.trade_resource_points(text) from public;
revoke execute on function public.merchant_trade(text, text, integer) from public;
revoke execute on function public.create_trade_offer(text, text, integer, integer) from public;
revoke execute on function public.accept_trade_offer(uuid) from public;
revoke execute on function public.cancel_trade_offer(uuid) from public;

grant execute on function public.resolve_resource_ticks() to authenticated;
grant execute on function public.recruit_unit(uuid, integer) to authenticated;
grant execute on function public.merchant_trade(text, text, integer) to authenticated;
grant execute on function public.create_trade_offer(text, text, integer, integer) to authenticated;
grant execute on function public.accept_trade_offer(uuid) to authenticated;
grant execute on function public.cancel_trade_offer(uuid) to authenticated;
