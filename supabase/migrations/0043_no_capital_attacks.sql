create or replace function public.raise_if_capital_attack_target(target_system_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.systems
    where systems.id = target_system_id
      and systems.is_capital
  ) then
    raise exception 'Las capitales no pueden ser atacadas';
  end if;
end;
$$;

create or replace function public.prevent_capital_movement_attack()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.movement_type = 'attack'
    and new.status in ('pending_approval', 'moving', 'in_battle')
    and new.to_system_id is not null then
    perform public.raise_if_capital_attack_target(new.to_system_id);
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_capital_movement_attack_trigger on public.movement_orders;
create trigger prevent_capital_movement_attack_trigger
before insert or update of to_system_id, movement_type, status
on public.movement_orders
for each row
execute function public.prevent_capital_movement_attack();

create or replace function public.prevent_capital_battle_operation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('assembling', 'moving', 'in_battle')
    and new.target_system_id is not null then
    perform public.raise_if_capital_attack_target(new.target_system_id);
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_capital_battle_operation_trigger on public.battle_operations;
create trigger prevent_capital_battle_operation_trigger
before insert or update of target_system_id, status
on public.battle_operations
for each row
execute function public.prevent_capital_battle_operation();

create or replace function public.prevent_capital_pending_conflict()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pending'
    and new.system_id is not null then
    perform public.raise_if_capital_attack_target(new.system_id);
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_capital_pending_conflict_trigger on public.conflicts;
create trigger prevent_capital_pending_conflict_trigger
before insert or update of system_id, status
on public.conflicts
for each row
execute function public.prevent_capital_pending_conflict();

create or replace function public.prevent_capital_narrative_attack()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('incoming', 'arrived')
    and new.system_id is not null then
    perform public.raise_if_capital_attack_target(new.system_id);
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_capital_narrative_attack_trigger on public.narrative_attacks;
create trigger prevent_capital_narrative_attack_trigger
before insert or update of system_id, status
on public.narrative_attacks
for each row
execute function public.prevent_capital_narrative_attack();

revoke execute on function public.raise_if_capital_attack_target(uuid) from public;
grant execute on function public.raise_if_capital_attack_target(uuid) to authenticated;
