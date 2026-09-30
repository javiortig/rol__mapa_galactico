-- Visibility rules only. No campaign state is changed by this migration.

create or replace function public.can_view_attack_force(target_operation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin() or exists (
    select 1
    from public.battle_operations as operation
    where operation.id = target_operation_id
      and (
        public.user_controls_system(operation.origin_system_id)
        or public.user_has_presence_in_system(operation.origin_system_id)
        or exists (
          select 1
          from public.battle_operation_members as member
          where member.operation_id = operation.id
            and member.side = 'attacker'
            and member.invitation_status = 'accepted'
            and public.is_faction_member(member.faction_id)
        )
        or (
          operation.status in ('in_battle', 'resolved')
          and public.can_select_battle_operation(operation.id)
        )
      )
  );
$$;

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
      from public.movement_passage_requests as request
      where request.movement_order_id = target_movement_order_id
        and request.status = 'pending'
        and public.is_faction_member(request.responder_faction_id)
    )
    or exists (
      select 1
      from public.movement_orders as movement
      where movement.id = target_movement_order_id
        and (
          (movement.movement_type = 'attack' and (
            public.user_controls_system(movement.from_system_id)
            or public.user_has_presence_in_system(movement.from_system_id)
            or (movement.battle_operation_id is not null
              and public.can_view_attack_force(movement.battle_operation_id))
          ))
          or (movement.movement_type <> 'attack'
            and movement.movement_purpose <> 'normal'
            and movement.battle_operation_id is not null
            and public.can_select_battle_operation(movement.battle_operation_id))
        )
    );
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
  select link.movement_order_id, link.unit_id, link.quantity_at_departure
  from public.movement_order_units as link
  join public.movement_orders as movement on movement.id = link.movement_order_id
  where public.can_select_movement_order(movement.id, movement.faction_id);
$$;

drop policy if exists battle_unit_commitments_select_related on public.battle_unit_commitments;
create policy battle_unit_commitments_select_related
on public.battle_unit_commitments
for select
to authenticated
using (
  public.is_faction_member(faction_id)
  or (side = 'attacker' and public.can_view_attack_force(operation_id))
  or (side = 'defender' and public.can_select_battle_operation(operation_id))
);

create or replace function public.can_select_campaign_unit_for_operation(target_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.battle_unit_commitments as commitment
    join public.battle_operations as operation on operation.id = commitment.operation_id
    where commitment.unit_id = target_unit_id
      and operation.status in ('assembling', 'moving', 'in_battle')
      and commitment.status not in ('returned', 'destroyed', 'cancelled')
      and (
        public.is_faction_member(commitment.faction_id)
        or (commitment.side = 'attacker' and public.can_view_attack_force(operation.id))
        or (commitment.side = 'defender' and public.can_select_battle_operation(operation.id))
      )
  );
$$;

create or replace function public.can_select_campaign_unit_for_attack_origin(target_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.movement_order_units as link
    join public.movement_orders as movement on movement.id = link.movement_order_id
    where link.unit_id = target_unit_id
      and movement.movement_type = 'attack'
      and movement.status = 'moving'
      and (
        public.user_controls_system(movement.from_system_id)
        or public.user_has_presence_in_system(movement.from_system_id)
      )
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
  or (
    status <> 'moving'
    and (
      public.user_has_presence_in_system(current_system_id)
      or public.user_controls_system(current_system_id)
    )
  )
  or public.can_select_campaign_unit_for_operation(id)
  or public.can_select_campaign_unit_for_attack_origin(id)
  or public.can_select_campaign_unit_for_passage_request(id)
);

-- Everyone sees the warning; only the system owner/admin receives the attacker list.
create or replace function public.get_public_incoming_attack_alerts()
returns table (system_id uuid, attacker_faction_ids uuid[])
language sql
stable
security definer
set search_path = public
as $$
  with attack_sources as (
    select operation.target_system_id as target_id, operation.leader_faction_id as attacker_id
    from public.battle_operations as operation
    where operation.status = 'moving'
      and operation.attack_arrival_at > now()
    union all
    select operation.target_system_id, member.faction_id
    from public.battle_operations as operation
    join public.battle_operation_members as member on member.operation_id = operation.id
    where operation.status = 'moving'
      and operation.attack_arrival_at > now()
      and member.side = 'attacker'
      and member.invitation_status = 'accepted'
    union all
    select movement.to_system_id, movement.faction_id
    from public.movement_orders as movement
    where movement.movement_type = 'attack'
      and movement.status = 'moving'
      and movement.departure_at <= now()
      and movement.arrival_at > now()
    union all
    select attack.system_id, attack.narrative_faction_id
    from public.narrative_attacks as attack
    where attack.status = 'incoming'
      and attack.arrival_at > now()
  )
  select sources.target_id,
    case when public.is_admin() or public.user_controls_system(sources.target_id)
      then array_agg(distinct sources.attacker_id) filter (where sources.attacker_id is not null)
      else '{}'::uuid[] end
  from attack_sources as sources
  group by sources.target_id;
$$;

revoke execute on function public.can_view_attack_force(uuid) from public;
revoke execute on function public.can_select_campaign_unit_for_attack_origin(uuid) from public;
revoke execute on function public.get_public_incoming_attack_alerts() from public;
grant execute on function public.can_view_attack_force(uuid) to authenticated;
grant execute on function public.can_select_campaign_unit_for_attack_origin(uuid) to authenticated;
grant execute on function public.get_public_incoming_attack_alerts() to authenticated;

notify pgrst, 'reload schema';
