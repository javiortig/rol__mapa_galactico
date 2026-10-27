begin;
do $$
declare
  v_order public.movement_orders%rowtype;
  v_first uuid;
  v_waypoint uuid;
  v_last uuid;
begin
  select * into v_order from public.movement_orders limit 1;
  select id into v_first from public.systems where slug = 'kharon-prime';
  select id into v_waypoint from public.systems where slug = 'lyra-terminus';
  select id into v_last from public.systems where slug = 'nexus-aster';
  if v_order.id is null or v_first is null or v_waypoint is null or v_last is null then
    raise exception 'Faltan datos para probar el bloqueo de ruta';
  end if;

  v_order.path_system_ids := array[v_first, v_waypoint, v_last];
  v_order.departure_at := now() - interval '8 hours';
  v_order.arrival_at := now() + interval '8 hours';

  update public.systems
  set status = 'war', updated_at = now() + interval '1 hour'
  where id = v_waypoint;
  if public.movement_has_blocked_uncrossed_waypoint(v_order) then
    raise exception 'Un bloqueo posterior al cruce ha cancelado el movimiento';
  end if;

  update public.systems
  set updated_at = now() - interval '1 hour'
  where id = v_waypoint;
  if not public.movement_has_blocked_uncrossed_waypoint(v_order) then
    raise exception 'Un bloqueo anterior al cruce no ha detenido el movimiento';
  end if;
end $$;
rollback;
