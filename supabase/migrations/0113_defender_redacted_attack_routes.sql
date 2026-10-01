-- The defender can track an incoming attack without receiving its order,
-- roster, points or movement-order unit links.
create or replace function public.get_defender_incoming_attack_routes()
returns table (
  from_system_id uuid,
  to_system_id uuid,
  departure_at timestamptz,
  arrival_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select movement.from_system_id,
    movement.to_system_id,
    movement.departure_at,
    movement.arrival_at
  from public.movement_orders as movement
  where movement.movement_type = 'attack'
    and movement.status = 'moving'
    and movement.departure_at <= now()
    and movement.arrival_at > now()
    and public.user_controls_system(movement.to_system_id);
$$;

revoke execute on function public.get_defender_incoming_attack_routes() from public, anon;
grant execute on function public.get_defender_incoming_attack_routes() to authenticated;

notify pgrst, 'reload schema';
