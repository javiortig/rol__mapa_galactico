with queued_recruitment as (
  update public.recruitment_queue
  set status = 'cancelled', updated_at = now()
  where status = 'queued'
    and (
      system_building_id is not null
      or origin_system_id in (select distinct system_id from public.system_buildings)
    )
  returning id
),
queued_recovery as (
  select id, campaign_unit_id
  from public.unit_recovery_queue
  where status = 'queued'
),
restored_recovery_units as (
  update public.campaign_units
  set status = 'ready', updated_at = now()
  where id in (select campaign_unit_id from queued_recovery)
    and status = 'recovering'
  returning id
),
deleted_buildings as (
  delete from public.system_buildings
  returning id, system_id
)
insert into public.campaign_logs (action_type, payload)
select
  'final_campaign_starting_buildings_cleared',
  jsonb_build_object(
    'deleted_count', (select count(*) from deleted_buildings),
    'cancelled_recruitment_count', (select count(*) from queued_recruitment),
    'cancelled_recovery_count', (select count(*) from queued_recovery),
    'restored_recovery_units_count', (select count(*) from restored_recovery_units)
  )
where exists (select 1 from deleted_buildings)
   or exists (select 1 from queued_recruitment)
   or exists (select 1 from queued_recovery);

select public.refresh_system_production_from_buildings();
