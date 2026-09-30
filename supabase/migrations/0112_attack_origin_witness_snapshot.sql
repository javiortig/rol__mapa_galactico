-- Preserve who could inspect an attack when it departed. Current presence must
-- never reveal an attack retroactively to a faction that arrived later.
create table if not exists public.attack_origin_witnesses (
  movement_order_id uuid not null references public.movement_orders(id) on delete cascade,
  faction_id uuid not null references public.factions(id) on delete cascade,
  witnessed_at timestamptz not null,
  primary key (movement_order_id, faction_id)
);

alter table public.attack_origin_witnesses enable row level security;
revoke all on public.attack_origin_witnesses from public, anon, authenticated;

create or replace function public.capture_attack_origin_witnesses()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.movement_type <> 'attack'
    or new.status <> 'moving'
    or new.departure_at is null then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.status = 'moving'
      and old.departure_at is not distinct from new.departure_at
      and old.from_system_id is not distinct from new.from_system_id then
      return new;
    end if;
  end if;

  insert into public.attack_origin_witnesses (movement_order_id, faction_id, witnessed_at)
  select new.id, witnesses.faction_id, new.departure_at
  from (
    select systems.controller_faction_id as faction_id
    from public.systems
    where systems.id = new.from_system_id
    union
    select campaign_units.faction_id
    from public.campaign_units
    where campaign_units.current_system_id = new.from_system_id
      and campaign_units.status in ('ready', 'in_war', 'recovering')
      and campaign_units.quantity > 0
  ) as witnesses
  where witnesses.faction_id is not null
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists capture_attack_origin_witnesses_trigger on public.movement_orders;
create trigger capture_attack_origin_witnesses_trigger
after insert or update of status, departure_at, from_system_id, movement_type
on public.movement_orders
for each row execute function public.capture_attack_origin_witnesses();

create or replace function public.was_attack_origin_witness(target_movement_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.attack_origin_witnesses
    where attack_origin_witnesses.movement_order_id = target_movement_order_id
      and public.is_faction_member(attack_origin_witnesses.faction_id)
  );
$$;

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
        public.was_attack_origin_witness(operation.attack_movement_order_id)
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
            public.was_attack_origin_witness(movement.id)
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
      and public.was_attack_origin_witness(movement.id)
  );
$$;

revoke execute on function public.capture_attack_origin_witnesses() from public, anon, authenticated;
revoke execute on function public.was_attack_origin_witness(uuid) from public, anon;
grant execute on function public.was_attack_origin_witness(uuid) to authenticated;

-- Existing attacks cannot be reconstructed reliably from current unit positions.
-- Attacking participants keep their existing access; no historical witness is
-- guessed or backfilled, which avoids exposing the active Caronte attack.
notify pgrst, 'reload schema';
