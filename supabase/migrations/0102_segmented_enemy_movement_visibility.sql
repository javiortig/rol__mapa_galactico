-- Enemy intelligence for ordinary movements is limited to the edge currently
-- being traversed. Attack operations keep their existing participant visibility.

create or replace function public.can_select_movement_order(
  target_movement_order_id uuid,
  target_owner_faction_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
    or public.is_faction_member(target_owner_faction_id)
    or exists (
      select 1
      from public.movement_passage_requests
      where movement_passage_requests.movement_order_id = target_movement_order_id
        and movement_passage_requests.status = 'pending'
        and public.is_faction_member(movement_passage_requests.responder_faction_id)
    )
    or exists (
      select 1
      from public.movement_orders
      where movement_orders.id = target_movement_order_id
        and movement_orders.battle_operation_id is not null
        and public.can_select_battle_operation(movement_orders.battle_operation_id)
    );
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
  moving_normal_orders as (
    select
      movement_orders.*,
      greatest(cardinality(movement_orders.path_system_ids) - 1, 1) as edge_count,
      greatest(extract(epoch from (movement_orders.arrival_at - movement_orders.departure_at)), 1) as total_seconds
    from public.movement_orders
    where movement_orders.status = 'moving'
      and movement_orders.movement_type = 'move'
      and movement_orders.movement_purpose = 'normal'
      and movement_orders.departure_at is not null
      and movement_orders.arrival_at is not null
      and movement_orders.departure_at <= now()
      and movement_orders.arrival_at > now()
      and cardinality(movement_orders.path_system_ids) >= 2
      and not public.can_select_movement_order(movement_orders.id, movement_orders.faction_id)
  ),
  current_segments as (
    select
      moving_normal_orders.*,
      least(
        greatest(
          floor(
            extract(epoch from (now() - moving_normal_orders.departure_at))
              / (moving_normal_orders.total_seconds / moving_normal_orders.edge_count)
          )::integer,
          0
        ),
        moving_normal_orders.edge_count - 1
      ) as edge_index
    from moving_normal_orders
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
    'normal'::text,
    visible_segments.updated_at
  from visible_segments
  order by arrival_at nulls last;
$$;

create or replace function public.get_visible_movement_order_units()
returns table (
  movement_order_id uuid,
  unit_id uuid,
  quantity_at_departure integer
)
language sql
stable
security definer
set search_path = public
as $$
  with visible_order_ids as (
    select visible_orders.id
    from public.get_visible_movement_orders() as visible_orders
  )
  select
    movement_order_units.movement_order_id,
    movement_order_units.unit_id,
    movement_order_units.quantity_at_departure
  from public.movement_order_units
  join visible_order_ids on visible_order_ids.id = movement_order_units.movement_order_id;
$$;

-- Foreign units that already departed must not remain listed in their old system.
drop policy if exists campaign_units_select_visible_member_or_admin on public.campaign_units;
create policy campaign_units_select_visible_member_or_admin
on public.campaign_units
for select
to authenticated
using (
  public.is_admin()
  or is_visible_publicly
  or public.is_faction_member(faction_id)
  or (
    status <> 'moving'
    and (
      public.user_has_presence_in_system(current_system_id)
      or public.user_controls_system(current_system_id)
    )
  )
  or public.can_select_campaign_unit_for_operation(id)
  or public.can_select_campaign_unit_for_passage_request(id)
);

revoke execute on function public.get_visible_movement_orders() from public;
revoke execute on function public.get_visible_movement_order_units() from public;
grant execute on function public.get_visible_movement_orders() to authenticated;
grant execute on function public.get_visible_movement_order_units() to authenticated;

-- One-time campaign correction requested on 2026-09-20: finish every active
-- journey belonging to these four factions at the indicated gaseous system.
do $$
declare
  v_external_units integer;
begin
  create temporary table relocated_campaign_units on commit drop as
  select
    campaign_units.id as unit_id,
    campaign_units.faction_id,
    destinations.id as destination_system_id
  from public.campaign_units
  join public.factions on factions.id = campaign_units.faction_id
  join lateral (
    select systems.id
    from public.systems
    where systems.slug = case
      when factions.slug in ('necrones', 'adeptus-custodes') then 'voidmist-basin'
      else 'maelstrom-gas'
    end
    limit 1
  ) as destinations on true
  where campaign_units.status = 'moving'
    and campaign_units.quantity > 0
    and factions.slug in (
      'necrones',
      'adeptus-custodes',
      'cultos-genestealer',
      'legiones-daemonicas'
    );

  create temporary table relocated_movement_orders on commit drop as
  select distinct movement_orders.id as movement_order_id
  from public.movement_orders
  join public.movement_order_units
    on movement_order_units.movement_order_id = movement_orders.id
  join relocated_campaign_units
    on relocated_campaign_units.unit_id = movement_order_units.unit_id
  where movement_orders.status in ('pending_approval', 'moving');

  select count(*)
  into v_external_units
  from public.movement_order_units
  join relocated_movement_orders
    on relocated_movement_orders.movement_order_id = movement_order_units.movement_order_id
  left join relocated_campaign_units
    on relocated_campaign_units.unit_id = movement_order_units.unit_id
  where relocated_campaign_units.unit_id is null;

  if v_external_units > 0 then
    raise exception 'La reubicacion administrativa encontro una orden activa con unidades ajenas al traslado';
  end if;

  update public.movement_passage_requests
  set
    status = 'rejected',
    response_reason = 'Orden cerrada por reubicacion administrativa.',
    responded_at = now()
  where status = 'pending'
    and movement_order_id in (
      select relocated_movement_orders.movement_order_id
      from relocated_movement_orders
    );

  update public.movement_orders
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancellation_reason = 'Reubicacion administrativa al sistema gaseoso.',
    resolved_at = now(),
    updated_at = now()
  where id in (
    select relocated_movement_orders.movement_order_id
    from relocated_movement_orders
  );

  update public.battle_unit_commitments
  set
    status = 'returned',
    returned_at = coalesce(returned_at, now()),
    updated_at = now()
  where unit_id in (
      select relocated_campaign_units.unit_id
      from relocated_campaign_units
    )
    and status = 'returning';

  update public.campaign_units
  set
    current_system_id = relocated_campaign_units.destination_system_id,
    status = 'ready',
    updated_at = now()
  from relocated_campaign_units
  where campaign_units.id = relocated_campaign_units.unit_id;

  insert into public.campaign_logs (faction_id, action_type, payload)
  select
    relocated_campaign_units.faction_id,
    'units_relocated_by_admin',
    jsonb_build_object(
      'destination_system_id', min(relocated_campaign_units.destination_system_id::text),
      'unit_count', count(*),
      'reason', 'Cierre administrativo de movimientos activos'
    )
  from relocated_campaign_units
  group by relocated_campaign_units.faction_id;
end;
$$;
