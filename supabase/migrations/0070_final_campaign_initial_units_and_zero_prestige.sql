delete from public.battle_operations;
delete from public.movement_orders;
delete from public.conflicts;
delete from public.recruitment_queue;
delete from public.unit_recovery_queue;
delete from public.campaign_units;

update public.systems
set
  status = case when controller_faction_id is null then 'neutral' else 'controlled' end,
  blocked_until = null,
  updated_at = now()
where is_temporary_mission = false;

update public.faction_resources
set
  supply = 100,
  minerals = 40,
  ancestral_stone = 0,
  honor = 0,
  gold = 0,
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

insert into public.campaign_units (
  id, slug, faction_id, unit_template_id, name, category, unit_type, unit_keywords,
  points, quantity, starting_quantity, wounds_taken, experience, rank,
  current_system_id, status, is_visible_publicly
)
select
  public.seed_uuid('campaign_unit', data.slug),
  data.slug,
  factions.id,
  unit_templates.id,
  unit_templates.name,
  unit_templates.category,
  unit_templates.unit_type,
  unit_templates.unit_keywords,
  data.points,
  data.quantity,
  data.starting_quantity,
  data.wounds_taken,
  data.experience,
  case
    when unit_templates.unit_keywords @> array['Caracter']::text[] then public.character_rank_for_level(data.experience)
    else null
  end,
  systems.id,
  'ready',
  false
from (
  values
    ('necron-plasmancer', 'necrones', 'unit-necrones-plasmancer', 'thokt-vault', 55, 1, 1, 0, 1),
    ('necron-immortals-damaged', 'necrones', 'unit-necrones-immortals', 'thokt-vault', 70, 4, 5, 0, 1),
    ('necron-warriors', 'necrones', 'unit-necrones-necron-warriors', 'thokt-vault', 90, 10, 10, 0, 1),
    ('necron-tomb-blades-damaged', 'necrones', 'unit-necrones-tomb-blades', 'thokt-vault', 75, 2, 3, 0, 1),
    ('daemon-flamers-damaged', 'legiones-daemonicas', 'unit-legiones-daemonicas-flamers', 'mordax', 65, 1, 3, 0, 1),
    ('daemon-burning-chariot', 'legiones-daemonicas', 'unit-legiones-daemonicas-burning-chariot', 'mordax', 115, 1, 1, 0, 1),
    ('daemon-pink-horrors-damaged', 'legiones-daemonicas', 'unit-legiones-daemonicas-pink-horrors', 'mordax', 140, 7, 10, 0, 1),
    ('sombra-intercessors-damaged', 'space-marines', 'unit-space-marines-intercessor-squad', 'sa-cea-gate', 80, 4, 5, 0, 1),
    ('sombra-intercessors-large-damaged', 'space-marines', 'unit-space-marines-intercessor-squad', 'sa-cea-gate', 150, 7, 10, 0, 1),
    ('sombra-lieutenant', 'space-marines', 'unit-space-marines-lieutenant', 'sa-cea-gate', 55, 1, 1, 0, 1),
    ('sombra-bladeguard-damaged', 'space-marines', 'unit-space-marines-bladeguard-veteran-squad', 'sa-cea-gate', 80, 1, 3, 0, 1),
    ('custodes-blade-champion', 'adeptus-custodes', 'unit-adeptus-custodes-blade-champion', 'kharon-prime', 120, 1, 1, 0, 1),
    ('custodes-guard-damaged', 'adeptus-custodes', 'unit-adeptus-custodes-custodian-guard', 'kharon-prime', 160, 3, 4, 0, 1),
    ('custodes-prosecutor-damaged', 'adeptus-custodes', 'unit-adeptus-custodes-prosecutors', 'kharon-prime', 40, 1, 4, 0, 1)
) as data(slug, faction_slug, template_slug, system_slug, points, quantity, starting_quantity, wounds_taken, experience)
join public.factions on factions.slug = data.faction_slug
join public.unit_templates on unit_templates.slug = data.template_slug
join public.systems on systems.slug = data.system_slug;

insert into public.campaign_logs (action_type, payload)
values (
  'final_campaign_initial_state_applied',
  jsonb_build_object(
    'initial_units_count', 14,
    'resources', jsonb_build_object(
      'supply', 100,
      'minerals', 40,
      'honor', 0,
      'gold', 0,
      'industrial_material', 150,
      'uridium', 10
    )
  )
);
