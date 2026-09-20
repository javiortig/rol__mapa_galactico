-- Existing local queues stop consuming time while their system is in battle.

alter table public.system_buildings
  add column if not exists battle_paused_at timestamptz;

alter table public.recruitment_queue
  add column if not exists battle_paused_at timestamptz;

alter table public.unit_recovery_queue
  add column if not exists battle_paused_at timestamptz;

create or replace function public.pause_system_activity_for_battle(target_system_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.system_buildings
  set battle_paused_at = coalesce(battle_paused_at, now()),
      updated_at = now()
  where system_id = target_system_id
    and status = 'constructing';

  update public.recruitment_queue
  set battle_paused_at = coalesce(battle_paused_at, now()),
      updated_at = now()
  where status = 'queued'
    and (
      origin_system_id = target_system_id
      or system_building_id in (
        select id from public.system_buildings where system_id = target_system_id
      )
    );

  update public.unit_recovery_queue
  set battle_paused_at = coalesce(battle_paused_at, now()),
      updated_at = now()
  where status = 'queued'
    and system_building_id in (
      select id from public.system_buildings where system_id = target_system_id
    );
end;
$$;

create or replace function public.resume_system_activity_after_battle(target_system_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.system_buildings
  set finishes_at = finishes_at + (now() - battle_paused_at),
      battle_paused_at = null,
      updated_at = now()
  where system_id = target_system_id
    and status = 'constructing'
    and battle_paused_at is not null;

  update public.recruitment_queue
  set finishes_at = finishes_at + (now() - battle_paused_at),
      battle_paused_at = null,
      updated_at = now()
  where status = 'queued'
    and battle_paused_at is not null
    and (
      origin_system_id = target_system_id
      or system_building_id in (
        select id from public.system_buildings where system_id = target_system_id
      )
    );

  update public.unit_recovery_queue
  set finishes_at = finishes_at + (now() - battle_paused_at),
      battle_paused_at = null,
      updated_at = now()
  where status = 'queued'
    and battle_paused_at is not null
    and system_building_id in (
      select id from public.system_buildings where system_id = target_system_id
    );
end;
$$;

create or replace function public.sync_system_activity_battle_pause()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'war' and old.status is distinct from 'war' then
    perform public.pause_system_activity_for_battle(new.id);
  elsif old.status = 'war' and new.status is distinct from 'war' then
    perform public.resume_system_activity_after_battle(new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists systems_sync_activity_battle_pause on public.systems;
create trigger systems_sync_activity_battle_pause
after update of status on public.systems
for each row
when (old.status is distinct from new.status)
execute function public.sync_system_activity_battle_pause();

-- If this migration lands during a live battle, freeze its queues from deployment onward.
do $$
declare
  v_system_id uuid;
begin
  for v_system_id in
    select id from public.systems where status = 'war'
  loop
    perform public.pause_system_activity_for_battle(v_system_id);
  end loop;
end;
$$;

-- Winner-support returns still avoid systems with an incoming attack.
do $$
declare
  v_definition text;
begin
  select pg_get_functiondef('public.queue_battle_support_return(uuid)'::regprocedure)
  into v_definition;

  if position('not public.system_has_unresolved_battle_block(systems.id)' in v_definition) = 0 then
    raise exception 'No se pudo endurecer queue_battle_support_return';
  end if;

  execute replace(
    v_definition,
    'not public.system_has_unresolved_battle_block(systems.id)',
    'not public.system_has_incoming_or_battle_pressure(systems.id)'
  );
end;
$$;

revoke execute on function public.pause_system_activity_for_battle(uuid) from public;
revoke execute on function public.resume_system_activity_after_battle(uuid) from public;
