alter table public.campaign_settings
  alter column movement_edge_duration_seconds set default 259200,
  add column if not exists attack_duration_seconds integer not null default 518400
    check (attack_duration_seconds > 0);

update public.campaign_settings
set
  movement_edge_duration_seconds = 259200,
  attack_duration_seconds = 518400,
  updated_at = now()
where id = 'default';

create table public.battle_operations (
  id uuid primary key default gen_random_uuid(),
  mode text not null check (mode in ('solo', 'coalition')),
  status text not null check (status in ('assembling', 'moving', 'in_battle', 'resolved', 'cancelled')),
  leader_faction_id uuid not null references public.factions(id) on delete cascade,
  defender_faction_id uuid not null references public.factions(id) on delete cascade,
  origin_system_id uuid not null references public.systems(id),
  target_system_id uuid not null references public.systems(id),
  attack_movement_order_id uuid references public.movement_orders(id) on delete set null,
  conflict_id uuid references public.conflicts(id) on delete set null,
  attack_arrival_at timestamptz,
  roster_locked_at timestamptz,
  launched_at timestamptz,
  resolved_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_by_user_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (leader_faction_id <> defender_faction_id),
  check (origin_system_id <> target_system_id)
);

create unique index battle_operations_active_target_key
on public.battle_operations (target_system_id)
where status in ('assembling', 'moving', 'in_battle');

create index battle_operations_leader_status_idx
on public.battle_operations (leader_faction_id, status);

create index battle_operations_defender_status_idx
on public.battle_operations (defender_faction_id, status);

create table public.battle_operation_members (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.battle_operations(id) on delete cascade,
  faction_id uuid not null references public.factions(id) on delete cascade,
  side text not null check (side in ('attacker', 'defender')),
  role text not null check (role in ('commander', 'supporter')),
  invitation_status text not null default 'invited'
    check (invitation_status in ('invited', 'accepted', 'rejected', 'closed')),
  invited_by_faction_id uuid references public.factions(id),
  invited_at timestamptz not null default now(),
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (operation_id, faction_id)
);

create index battle_operation_members_faction_status_idx
on public.battle_operation_members (faction_id, invitation_status);

create table public.battle_unit_commitments (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.battle_operations(id) on delete cascade,
  unit_id uuid not null references public.campaign_units(id) on delete cascade,
  faction_id uuid not null references public.factions(id) on delete cascade,
  side text not null check (side in ('attacker', 'defender')),
  role text not null check (role in ('leader', 'supporter')),
  home_system_id uuid not null references public.systems(id),
  staging_system_id uuid not null references public.systems(id),
  outbound_movement_order_id uuid references public.movement_orders(id) on delete set null,
  return_movement_order_id uuid references public.movement_orders(id) on delete set null,
  outbound_path_system_ids uuid[] not null,
  return_path_system_ids uuid[],
  quantity_at_commitment integer not null check (quantity_at_commitment > 0),
  points_at_commitment integer not null check (points_at_commitment >= 0),
  status text not null
    check (status in ('staged', 'en_route', 'in_battle', 'returning', 'returned', 'destroyed', 'cancelled', 'return_pending')),
  joined_at timestamptz not null default now(),
  returned_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (operation_id, unit_id)
);

create index battle_unit_commitments_operation_side_idx
on public.battle_unit_commitments (operation_id, side, status);

create index battle_unit_commitments_unit_status_idx
on public.battle_unit_commitments (unit_id, status);

alter table public.movement_orders
  add column if not exists battle_operation_id uuid references public.battle_operations(id) on delete set null,
  add column if not exists movement_purpose text not null default 'normal';

alter table public.movement_orders
  drop constraint if exists movement_orders_movement_purpose_check,
  add constraint movement_orders_movement_purpose_check
  check (movement_purpose in ('normal', 'attack', 'coalition_staging', 'defense_support', 'battle_return'));

create index movement_orders_battle_operation_idx
on public.movement_orders (battle_operation_id, movement_purpose, status);

alter table public.conflicts
  add column if not exists battle_operation_id uuid references public.battle_operations(id) on delete set null;

create unique index conflicts_battle_operation_id_key
on public.conflicts (battle_operation_id)
where battle_operation_id is not null;

alter table public.battle_operations enable row level security;
alter table public.battle_operation_members enable row level security;
alter table public.battle_unit_commitments enable row level security;

create or replace function public.can_select_battle_operation(target_operation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
    or exists (
      select 1
      from public.battle_operation_members
      where battle_operation_members.operation_id = target_operation_id
        and public.is_faction_member(battle_operation_members.faction_id)
    );
$$;

create or replace function public.can_select_campaign_unit_for_operation(target_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.battle_unit_commitments
    join public.battle_operation_members
      on battle_operation_members.operation_id = battle_unit_commitments.operation_id
    where battle_unit_commitments.unit_id = target_unit_id
      and battle_operation_members.invitation_status = 'accepted'
      and public.is_faction_member(battle_operation_members.faction_id)
  );
$$;

drop policy if exists battle_operations_select_related on public.battle_operations;
create policy battle_operations_select_related
on public.battle_operations
for select
to authenticated
using (public.can_select_battle_operation(id));

drop policy if exists battle_operations_admin_all on public.battle_operations;
create policy battle_operations_admin_all
on public.battle_operations
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists battle_operation_members_select_related on public.battle_operation_members;
create policy battle_operation_members_select_related
on public.battle_operation_members
for select
to authenticated
using (public.can_select_battle_operation(operation_id));

drop policy if exists battle_operation_members_admin_all on public.battle_operation_members;
create policy battle_operation_members_admin_all
on public.battle_operation_members
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists battle_unit_commitments_select_related on public.battle_unit_commitments;
create policy battle_unit_commitments_select_related
on public.battle_unit_commitments
for select
to authenticated
using (public.can_select_battle_operation(operation_id));

drop policy if exists battle_unit_commitments_admin_all on public.battle_unit_commitments;
create policy battle_unit_commitments_admin_all
on public.battle_unit_commitments
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists campaign_units_select_visible_member_or_admin on public.campaign_units;
create policy campaign_units_select_visible_member_or_admin
on public.campaign_units
for select
to authenticated
using (
  public.is_admin()
  or is_visible_publicly
  or public.is_faction_member(faction_id)
  or public.can_select_campaign_unit_for_operation(id)
);

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

grant select on public.battle_operations to authenticated;
grant select on public.battle_operation_members to authenticated;
grant select on public.battle_unit_commitments to authenticated;
grant execute on function public.can_select_battle_operation(uuid) to authenticated;
grant execute on function public.can_select_campaign_unit_for_operation(uuid) to authenticated;

grant all on public.battle_operations to service_role;
grant all on public.battle_operation_members to service_role;
grant all on public.battle_unit_commitments to service_role;
