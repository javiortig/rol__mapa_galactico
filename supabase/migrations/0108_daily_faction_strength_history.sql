-- Daily, immutable strength components for future campaign comparison charts.
-- The final combined score is intentionally not stored: it can be calculated
-- later from the historical components without losing information.

create table if not exists public.faction_daily_strength_snapshots (
  id uuid primary key default gen_random_uuid(),
  captured_on date not null,
  captured_at timestamptz not null default now(),
  faction_id uuid not null references public.factions(id) on delete cascade,
  faction_name text not null,
  supply numeric(14,2) not null default 0 check (supply >= 0),
  minerals numeric(14,2) not null default 0 check (minerals >= 0),
  honor numeric(14,2) not null default 0 check (honor >= 0),
  gold numeric(14,2) not null default 0 check (gold >= 0),
  recruitment_resource_points numeric(16,2) not null default 0 check (recruitment_resource_points >= 0),
  fielded_army_points integer not null default 0 check (fielded_army_points >= 0),
  queued_army_points integer not null default 0 check (queued_army_points >= 0),
  army_points integer not null default 0 check (army_points >= 0),
  spent_technology_points integer not null default 0 check (spent_technology_points >= 0),
  available_technology_points numeric(14,2) not null default 0 check (available_technology_points >= 0),
  technology_power numeric(16,2) not null default 0 check (technology_power >= 0),
  formula_version text not null default 'components-v1',
  unique (faction_id, captured_on)
);

create index if not exists faction_daily_strength_snapshots_date_idx
  on public.faction_daily_strength_snapshots (captured_on, faction_id);

comment on table public.faction_daily_strength_snapshots is
  'One immutable daily strength snapshot per playable faction, using the Europe/Madrid campaign date.';

comment on column public.faction_daily_strength_snapshots.recruitment_resource_points is
  'Supply + 2*minerals + 5*honor + 5*gold. Industrial Material and Uridium are intentionally excluded.';

alter table public.faction_daily_strength_snapshots enable row level security;

revoke all on table public.faction_daily_strength_snapshots from public, anon, authenticated;
grant select on table public.faction_daily_strength_snapshots to authenticated;

drop policy if exists faction_daily_strength_snapshots_admin_read
  on public.faction_daily_strength_snapshots;

create policy faction_daily_strength_snapshots_admin_read
on public.faction_daily_strength_snapshots
for select
to authenticated
using (public.is_admin());

create or replace function public.capture_daily_faction_strength_snapshot(
  target_date date default ((now() at time zone 'Europe/Madrid')::date)
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer := 0;
begin
  if target_date is null then
    raise exception 'La fecha de la instantanea no puede ser nula';
  end if;

  insert into public.faction_daily_strength_snapshots (
    captured_on,
    captured_at,
    faction_id,
    faction_name,
    supply,
    minerals,
    honor,
    gold,
    recruitment_resource_points,
    fielded_army_points,
    queued_army_points,
    army_points,
    spent_technology_points,
    available_technology_points,
    technology_power,
    formula_version
  )
  select
    target_date,
    now(),
    factions.id,
    factions.name,
    coalesce(resources.supply, 0)::numeric(14,2),
    coalesce(resources.minerals, 0)::numeric(14,2),
    coalesce(resources.honor, 0)::numeric(14,2),
    coalesce(resources.gold, 0)::numeric(14,2),
    (
      coalesce(resources.supply, 0)::numeric
      + coalesce(resources.minerals, 0)::numeric * 2
      + coalesce(resources.honor, 0)::numeric * 5
      + coalesce(resources.gold, 0)::numeric * 5
    )::numeric(16,2),
    army.fielded_points,
    recruitment.queued_points,
    army.fielded_points + recruitment.queued_points,
    technology.spent_points,
    coalesce(resources.technology, 0)::numeric(14,2),
    (
      technology.spent_points::numeric
      + coalesce(resources.technology, 0)::numeric
    )::numeric(16,2),
    'components-v1'
  from public.factions
  left join public.faction_resources resources
    on resources.faction_id = factions.id
  cross join lateral (
    select coalesce(sum(campaign_units.points), 0)::integer as fielded_points
    from public.campaign_units
    where campaign_units.faction_id = factions.id
      and campaign_units.status <> 'destroyed'
      and campaign_units.quantity > 0
  ) army
  cross join lateral (
    select coalesce(sum(
      coalesce(recruitment_queue.selected_points, unit_templates.points)
      * greatest(coalesce(recruitment_queue.quantity, 1), 1)
    ), 0)::integer as queued_points
    from public.recruitment_queue
    join public.unit_templates
      on unit_templates.id = recruitment_queue.unit_template_id
    where recruitment_queue.faction_id = factions.id
      and recruitment_queue.status = 'queued'
  ) recruitment
  cross join lateral (
    select coalesce(sum(technology_nodes.cost_technology), 0)::integer as spent_points
    from public.faction_technologies
    join public.technology_nodes
      on technology_nodes.id = faction_technologies.technology_node_id
    where faction_technologies.faction_id = factions.id
      and faction_technologies.status in ('researching', 'unlocked')
  ) technology
  where not coalesce(factions.is_narrative, false)
  on conflict (faction_id, captured_on) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

revoke all on function public.capture_daily_faction_strength_snapshot(date)
  from public, anon, authenticated;

-- Capture a baseline immediately when this migration reaches production.
select public.capture_daily_faction_strength_snapshot();

-- pg_cron already exists in the production project. Keeping this guarded
-- means a local database without pg_cron receives the schema but no job.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'rol40k-capture-daily-faction-strength';

    perform cron.schedule(
      'rol40k-capture-daily-faction-strength',
      '15 0 * * *',
      $cron$select public.capture_daily_faction_strength_snapshot();$cron$
    );
  end if;
end;
$$;
