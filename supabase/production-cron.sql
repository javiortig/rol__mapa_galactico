-- Supabase Cloud operational SQL.
-- Run this once in the linked production project after migrations and seed data.
-- It schedules authoritative campaign resolvers every minute.

create extension if not exists pg_cron with schema extensions;

select cron.unschedule(jobname)
from cron.job
where jobname in (
  'rol40k-resolve-resource-ticks',
  'rol40k-resolve-building-construction',
  'rol40k-resolve-movement-orders',
  'rol40k-resolve-recruitment-queue',
  'rol40k-resolve-unit-recovery-queue',
  'rol40k-resolve-technology-research'
);

select cron.schedule(
  'rol40k-resolve-resource-ticks',
  '* * * * *',
  $$select public.resolve_resource_ticks();$$
);

select cron.schedule(
  'rol40k-resolve-building-construction',
  '* * * * *',
  $$select public.resolve_building_construction();$$
);

select cron.schedule(
  'rol40k-resolve-movement-orders',
  '* * * * *',
  $$select public.resolve_movement_orders();$$
);

select cron.schedule(
  'rol40k-resolve-recruitment-queue',
  '* * * * *',
  $$select public.resolve_recruitment_queue();$$
);

select cron.schedule(
  'rol40k-resolve-unit-recovery-queue',
  '* * * * *',
  $$select public.resolve_unit_recovery_queue();$$
);

select cron.schedule(
  'rol40k-resolve-technology-research',
  '* * * * *',
  $$select public.resolve_technology_research();$$
);
