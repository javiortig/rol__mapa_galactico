create or replace function public.user_controls_system(target_system_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.systems
    where systems.id = target_system_id
      and systems.status = 'controlled'
      and systems.controller_faction_id = public.current_user_faction_id()
  );
$$;

create or replace function public.can_select_campaign_unit_for_passage_request(target_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.movement_order_units
    join public.movement_orders
      on movement_orders.id = movement_order_units.movement_order_id
    join public.movement_passage_requests
      on movement_passage_requests.movement_order_id = movement_orders.id
    where movement_order_units.unit_id = target_unit_id
      and movement_passage_requests.status = 'pending'
      and public.is_faction_member(movement_passage_requests.responder_faction_id)
  );
$$;

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
  or public.user_controls_system(current_system_id)
  or public.can_select_campaign_unit_for_operation(id)
  or public.can_select_campaign_unit_for_passage_request(id)
);

revoke execute on function public.user_controls_system(uuid) from public;
revoke execute on function public.can_select_campaign_unit_for_passage_request(uuid) from public;

grant execute on function public.user_controls_system(uuid) to authenticated;
grant execute on function public.can_select_campaign_unit_for_passage_request(uuid) to authenticated;
