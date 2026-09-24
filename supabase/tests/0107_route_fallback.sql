begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(6);

create temporary table route_fallback_fixture (
  movement_order_id uuid not null,
  faction_id uuid not null,
  origin_system_id uuid not null,
  last_passed_system_id uuid not null,
  changed_destination_system_id uuid not null
) on commit drop;

insert into route_fallback_fixture (
  movement_order_id,
  faction_id,
  origin_system_id,
  last_passed_system_id,
  changed_destination_system_id
)
select
  gen_random_uuid(),
  (select id from public.factions order by id limit 1),
  selected_systems.ids[1],
  selected_systems.ids[2],
  selected_systems.ids[3]
from (
  select array_agg(id order by id) as ids
  from (
    select id
    from public.systems
    order by id
    limit 3
  ) systems
) selected_systems;

insert into public.movement_orders (
  id,
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
select
  movement_order_id,
  faction_id,
  origin_system_id,
  changed_destination_system_id,
  'move',
  'normal',
  0,
  now() - interval '3 days',
  now() - interval '3 days',
  now() - interval '1 second',
  'moving',
  array[origin_system_id, last_passed_system_id, changed_destination_system_id],
  2,
  259200
from route_fallback_fixture;

select public.cancel_reserved_movement_order(
  movement_order_id,
  'El destino cambio a territorio bloqueado antes de la llegada',
  0
)
from route_fallback_fixture;

select ok(
  not exists (
    select 1
    from pg_trigger
    where tgname = 'systems_neutral_conquest_shield_trigger'
      and not tgisinternal
  ),
  'La conquista neutral ya no tiene trigger de escudo'
);

select is(
  (
    select status
    from public.movement_orders
    where id = (select movement_order_id from route_fallback_fixture)
  ),
  'cancelled'::text,
  'La orden original queda cerrada'
);

select is(
  (
    select count(*)::integer
    from public.movement_orders
    where movement_purpose = 'route_fallback'
      and id = (
        select (payload ->> 'return_movement_order_id')::uuid
        from public.campaign_logs
        where action_type = 'movement_route_fallback_started'
          and (payload ->> 'cancelled_movement_order_id')::uuid = (
            select movement_order_id
            from route_fallback_fixture
          )
      )
  ),
  1,
  'Se crea una unica orden de repliegue'
);

select is(
  (
    select from_system_id
    from public.movement_orders
    where id = (
      select (payload ->> 'return_movement_order_id')::uuid
      from public.campaign_logs
      where action_type = 'movement_route_fallback_started'
        and (payload ->> 'cancelled_movement_order_id')::uuid = (
          select movement_order_id
          from route_fallback_fixture
        )
    )
  ),
  (select changed_destination_system_id from route_fallback_fixture),
  'El repliegue parte del destino que cambio'
);

select is(
  (
    select to_system_id
    from public.movement_orders
    where id = (
      select (payload ->> 'return_movement_order_id')::uuid
      from public.campaign_logs
      where action_type = 'movement_route_fallback_started'
        and (payload ->> 'cancelled_movement_order_id')::uuid = (
          select movement_order_id
          from route_fallback_fixture
        )
    )
  ),
  (select last_passed_system_id from route_fallback_fixture),
  'El repliegue termina en el ultimo sistema atravesado'
);

select is(
  (
    select uridium_cost
    from public.movement_orders
    where id = (
      select (payload ->> 'return_movement_order_id')::uuid
      from public.campaign_logs
      where action_type = 'movement_route_fallback_started'
        and (payload ->> 'cancelled_movement_order_id')::uuid = (
          select movement_order_id
          from route_fallback_fixture
        )
    )
  ),
  0,
  'El repliegue no consume Uridium'
);

select * from finish();

rollback;
