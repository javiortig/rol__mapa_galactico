-- A battle that starts after an army crossed a waypoint cannot invalidate that
-- completed segment of its route.
create or replace function public.movement_has_blocked_uncrossed_waypoint(
  target_order public.movement_orders
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from unnest(target_order.path_system_ids) with ordinality as route(system_id, position)
    join public.systems as waypoint on waypoint.id = route.system_id
    cross join lateral (
      select min(started_at) as started_at
      from (
        select conflict.created_at as started_at
        from public.conflicts as conflict
        where conflict.system_id = route.system_id
          and conflict.status = 'pending'
        union all
        select coalesce(operation.attack_arrival_at, operation.updated_at)
        from public.battle_operations as operation
        where operation.target_system_id = route.system_id
          and operation.status = 'in_battle'
        union all
        select waypoint.updated_at
        where waypoint.status = 'war'
      ) as active_blocks
    ) as block
    where route.position > 1
      and route.position < cardinality(target_order.path_system_ids)
      and public.system_has_unresolved_battle_block(route.system_id)
      and block.started_at <= coalesce(target_order.departure_at, target_order.started_at)
        + (target_order.arrival_at - coalesce(target_order.departure_at, target_order.started_at))
          * ((route.position - 1)::numeric / nullif(cardinality(target_order.path_system_ids) - 1, 0))
  );
$$;

do $$
declare
  v_definition text;
  v_old text := $old$if exists (
      select 1
      from unnest(v_order.path_system_ids) with ordinality as route(system_id, position)
      where route.position > 1
        and route.position < cardinality(v_order.path_system_ids)
        and public.system_has_unresolved_battle_block(route.system_id)
    ) then$old$;
begin
  select pg_get_functiondef('public.resolve_movement_orders_core_0107()'::regprocedure)
  into v_definition;

  if position(v_old in v_definition) = 0 then
    raise exception 'No se encontro el validador de puntos intermedios esperado';
  end if;

  execute replace(
    v_definition,
    v_old,
    'if public.movement_has_blocked_uncrossed_waypoint(v_order) then'
  );
end $$;

revoke all on function public.movement_has_blocked_uncrossed_waypoint(public.movement_orders)
  from public, anon, authenticated;
