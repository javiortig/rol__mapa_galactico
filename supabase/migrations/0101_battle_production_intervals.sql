-- Preserve battle intervals so delayed resource resolution never produces through a war.

create table if not exists public.system_battle_pauses (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  paused_at timestamptz not null default now(),
  resumed_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists system_battle_pauses_one_active_per_system
  on public.system_battle_pauses(system_id)
  where resumed_at is null;

create index if not exists system_battle_pauses_tick_lookup
  on public.system_battle_pauses(system_id, paused_at, resumed_at);

alter table public.system_battle_pauses enable row level security;

create or replace function public.sync_system_activity_battle_pause()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'war' and old.status is distinct from 'war' then
    perform public.pause_system_activity_for_battle(new.id);

    insert into public.system_battle_pauses (system_id, paused_at)
    values (new.id, now())
    on conflict (system_id) where resumed_at is null do nothing;
  elsif old.status = 'war' and new.status is distinct from 'war' then
    update public.system_battle_pauses
    set resumed_at = now()
    where system_id = new.id
      and resumed_at is null;

    perform public.resume_system_activity_after_battle(new.id);
  end if;

  return new;
end;
$$;

insert into public.system_battle_pauses (system_id, paused_at)
select systems.id, now()
from public.systems
where systems.status = 'war'
on conflict (system_id) where resumed_at is null do nothing;

create or replace function public.resolve_resource_ticks()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.campaign_settings%rowtype;
  v_tick_at timestamptz;
  v_last_applied_at timestamptz;
  v_applied integer := 0;
begin
  perform public.resolve_building_construction();
  perform public.refresh_system_production_from_buildings();

  select * into v_settings
  from public.campaign_settings
  where id = 'default'
  for update;

  if not found then
    insert into public.campaign_settings (id, resource_tick_interval_hours, next_resource_tick_at)
    values ('default', 24, now() + interval '24 hours')
    returning * into v_settings;
  end if;

  v_tick_at := coalesce(
    v_settings.next_resource_tick_at,
    now() + make_interval(hours => v_settings.resource_tick_interval_hours)
  );

  while v_tick_at <= now() loop
    insert into public.faction_resources (
      faction_id, supply, minerals, ancestral_stone, honor, gold,
      industrial_material, uridium, technology, updated_at
    )
    select
      systems.controller_faction_id,
      coalesce(sum(system_production.supply_per_tick), 0)::integer,
      coalesce(sum(system_production.minerals_per_tick), 0)::integer,
      0,
      coalesce(sum(system_production.honor_per_tick), 0)::numeric(12,2),
      coalesce(sum(system_production.gold_per_tick), 0)::integer,
      coalesce(sum(system_production.industrial_material_per_tick), 0)::integer,
      coalesce(sum(system_production.uridium_per_tick), 0)::numeric(12,2),
      0,
      now()
    from public.systems
    join public.system_production on system_production.system_id = systems.id
    where systems.status = 'controlled'
      and systems.controller_faction_id is not null
      and not exists (
        select 1
        from public.system_battle_pauses
        where system_battle_pauses.system_id = systems.id
          and system_battle_pauses.paused_at <= v_tick_at
          and (
            system_battle_pauses.resumed_at is null
            or system_battle_pauses.resumed_at > v_tick_at
          )
      )
    group by systems.controller_faction_id
    on conflict (faction_id) do update
    set
      supply = public.faction_resources.supply + excluded.supply,
      minerals = public.faction_resources.minerals + excluded.minerals,
      honor = public.faction_resources.honor + excluded.honor,
      gold = public.faction_resources.gold + excluded.gold,
      industrial_material = public.faction_resources.industrial_material + excluded.industrial_material,
      uridium = public.faction_resources.uridium + excluded.uridium,
      updated_at = now();

    insert into public.campaign_logs (action_type, payload)
    values ('resource_tick_applied', jsonb_build_object('tick_at', v_tick_at, 'source', 'system_buildings'));

    v_last_applied_at := v_tick_at;
    v_tick_at := v_tick_at + make_interval(hours => v_settings.resource_tick_interval_hours);
    v_applied := v_applied + 1;
  end loop;

  if v_applied > 0 then
    update public.campaign_settings
    set last_resource_tick_at = v_last_applied_at,
        next_resource_tick_at = v_tick_at,
        updated_at = now()
    where id = 'default';
  end if;

  return v_applied;
end;
$$;

revoke all on table public.system_battle_pauses from anon, authenticated;
