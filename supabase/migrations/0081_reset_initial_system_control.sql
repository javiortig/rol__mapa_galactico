delete from public.narrative_attacks;
delete from public.missions;
delete from public.movement_passage_requests;

delete from public.systems
where coalesce(is_temporary_mission, false) = true;

with initial_control(slug, controller_slug) as (
  values
    ('mordax', 'legiones-daemonicas'),
    ('sa-cea-gate', 'space-marines'),
    ('thokt-vault', 'necrones'),
    ('kharon-prime', 'adeptus-custodes'),
    ('blackglass', 'cultos-genestealer'),
    ('nexus-aster', 'orcos'),
    ('goregate', 'orcos'),
    ('drusus', null),
    ('lyra-terminus', null),
    ('novem', null),
    ('helios-drift', null),
    ('red-sabbath', null),
    ('maelstrom-gas', null),
    ('voidmist-basin', null)
)
update public.systems
set
  controller_faction_id = factions.id,
  status = case when factions.id is null then 'neutral' else 'controlled' end,
  blocked_until = null,
  updated_at = now()
from initial_control
left join public.factions on factions.slug = initial_control.controller_slug
where systems.slug = initial_control.slug
  and coalesce(systems.is_temporary_mission, false) = false;

update public.systems
set
  controller_faction_id = null,
  status = 'neutral',
  blocked_until = null,
  updated_at = now()
where coalesce(is_temporary_mission, false) = false
  and slug not in (
    'mordax', 'sa-cea-gate', 'thokt-vault', 'kharon-prime', 'blackglass',
    'nexus-aster', 'goregate', 'drusus', 'lyra-terminus', 'novem',
    'helios-drift', 'red-sabbath', 'maelstrom-gas', 'voidmist-basin'
  );

select public.refresh_system_production_from_buildings();

insert into public.campaign_logs (action_type, payload)
values (
  'initial_system_control_reset',
  jsonb_build_object(
    'playable_capitals', jsonb_build_array('mordax', 'sa-cea-gate', 'thokt-vault', 'kharon-prime', 'blackglass'),
    'narrative_orc_systems', jsonb_build_array('nexus-aster', 'goregate'),
    'neutral_adjacent_systems', jsonb_build_array('drusus', 'lyra-terminus', 'novem', 'helios-drift', 'red-sabbath')
  )
);
