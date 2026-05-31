update public.system_production
set technology_per_tick = 0
where technology_per_tick <> 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'system_production_no_technology_per_tick'
      and conrelid = 'public.system_production'::regclass
  ) then
    alter table public.system_production
      add constraint system_production_no_technology_per_tick
      check (technology_per_tick = 0);
  end if;
end $$;

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
  select *
  into v_settings
  from public.campaign_settings
  where id = 'default'
  for update;

  if not found then
    insert into public.campaign_settings (id, resource_tick_interval_hours, next_resource_tick_at)
    values ('default', 24, now() + interval '24 hours')
    returning * into v_settings;
  end if;

  v_tick_at := coalesce(v_settings.next_resource_tick_at, now() + make_interval(hours => v_settings.resource_tick_interval_hours));

  while v_tick_at <= now() loop
    insert into public.faction_resources (
      faction_id,
      supply,
      minerals,
      ancestral_stone,
      uridium,
      technology,
      updated_at
    )
    select
      systems.controller_faction_id,
      coalesce(sum(system_production.supply_per_tick), 0)::integer,
      coalesce(sum(system_production.minerals_per_tick), 0)::integer,
      coalesce(sum(system_production.ancestral_stone_per_tick), 0)::integer,
      coalesce(sum(system_production.uridium_per_tick), 0)::integer,
      0,
      now()
    from public.systems
    join public.system_production on system_production.system_id = systems.id
    where systems.status = 'controlled'
      and systems.controller_faction_id is not null
    group by systems.controller_faction_id
    on conflict (faction_id) do update
    set
      supply = public.faction_resources.supply + excluded.supply,
      minerals = public.faction_resources.minerals + excluded.minerals,
      ancestral_stone = public.faction_resources.ancestral_stone + excluded.ancestral_stone,
      uridium = public.faction_resources.uridium + excluded.uridium,
      updated_at = now();

    insert into public.campaign_logs (action_type, payload)
    values (
      'resource_tick_applied',
      jsonb_build_object('tick_at', v_tick_at)
    );

    v_last_applied_at := v_tick_at;
    v_tick_at := v_tick_at + make_interval(hours => v_settings.resource_tick_interval_hours);
    v_applied := v_applied + 1;
  end loop;

  if v_applied > 0 then
    update public.campaign_settings
    set
      last_resource_tick_at = v_last_applied_at,
      next_resource_tick_at = v_tick_at,
      updated_at = now()
    where id = 'default';
  end if;

  return v_applied;
end;
$$;

revoke execute on function public.resolve_resource_ticks() from public;
grant execute on function public.resolve_resource_ticks() to authenticated;
