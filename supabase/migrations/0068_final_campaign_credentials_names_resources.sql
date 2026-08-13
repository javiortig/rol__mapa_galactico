update public.factions
set name = case slug
  when 'space-marines' then 'Sombra del Emperador'
  when 'legiones-daemonicas' then 'Legiones Daemonicas'
  when 'cultos-genestealer' then 'Cultos Genestealer'
  when 'adeptus-custodes' then 'Adeptus Custodes'
  when 'necrones' then 'Necrones'
  else name
end
where slug in (
  'space-marines',
  'legiones-daemonicas',
  'cultos-genestealer',
  'adeptus-custodes',
  'necrones'
);

update public.systems
set
  name = case slug
    when 'kharon-prime' then 'Santa Terra'
    when 'sa-cea-gate' then 'Obscura Primus'
    when 'blackglass' then 'Yaracuby77 mina abandonada'
    when 'thokt-vault' then 'Necronpolis'
    when 'mordax' then 'La Espiral de Tzeentch'
    else name
  end,
  updated_at = now()
where slug in ('kharon-prime', 'sa-cea-gate', 'blackglass', 'thokt-vault', 'mordax');

update public.faction_resources
set
  supply = 100,
  minerals = 40,
  industrial_material = 150,
  uridium = 10,
  updated_at = now()
from public.factions
where faction_resources.faction_id = factions.id
  and factions.slug in (
    'legiones-daemonicas',
    'adeptus-custodes',
    'space-marines',
    'cultos-genestealer',
    'necrones'
  );

with initial_barracks as (
  select system_buildings.id, system_buildings.system_id
  from public.system_buildings
  join public.building_templates
    on building_templates.id = system_buildings.building_template_id
  where building_templates.slug = 'barracon-infanteria'
),
cancelled_recruitment as (
  update public.recruitment_queue
  set status = 'cancelled', updated_at = now()
  where status = 'queued'
    and (
      system_building_id in (select id from initial_barracks)
      or origin_system_id in (select system_id from initial_barracks)
    )
  returning id
),
deleted_barracks as (
  delete from public.system_buildings
  where id in (select id from initial_barracks)
  returning id, system_id
)
insert into public.campaign_logs (action_type, payload)
select
  'final_campaign_barracks_removed',
  jsonb_build_object(
    'deleted_count', count(*),
    'building_ids', coalesce(jsonb_agg(deleted_barracks.id), '[]'::jsonb),
    'cancelled_recruitment_count', (select count(*) from cancelled_recruitment)
  )
from deleted_barracks
having count(*) > 0;

select public.refresh_system_production_from_buildings();
