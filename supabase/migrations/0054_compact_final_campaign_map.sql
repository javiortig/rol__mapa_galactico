create or replace function public.seed_uuid(prefix text, slug text)
returns uuid
language plpgsql
immutable
as $$
declare
  hash text := md5(prefix || ':' || slug);
begin
  return (
    substr(hash, 1, 8) || '-' ||
    substr(hash, 9, 4) || '-' ||
    substr(hash, 13, 4) || '-' ||
    substr(hash, 17, 4) || '-' ||
    substr(hash, 21, 12)
  )::uuid;
end;
$$;

delete from public.battle_reports;
delete from public.narrative_attacks;
delete from public.missions;
delete from public.battle_unit_commitments;
delete from public.battle_operation_members;
delete from public.battle_operations;
delete from public.movement_passage_requests;
delete from public.movement_order_units;
delete from public.movement_orders;
delete from public.conflicts;
delete from public.unit_recovery_queue;
delete from public.recruitment_queue;

with final_capitals(faction_slug, system_slug) as (
  values
    ('legiones-daemonicas', 'mordax'),
    ('space-marines', 'sa-cea-gate'),
    ('necrones', 'thokt-vault'),
    ('adeptus-custodes', 'kharon-prime'),
    ('cultos-genestealer', 'blackglass')
)
update public.factions
set capital_system_id = public.seed_uuid('system', final_capitals.system_slug)
from final_capitals
where factions.slug = final_capitals.faction_slug;

with final_capitals(faction_slug, system_slug) as (
  values
    ('legiones-daemonicas', 'mordax'),
    ('space-marines', 'sa-cea-gate'),
    ('necrones', 'thokt-vault'),
    ('adeptus-custodes', 'kharon-prime'),
    ('cultos-genestealer', 'blackglass')
)
update public.campaign_units
set
  current_system_id = public.seed_uuid('system', final_capitals.system_slug),
  status = case when campaign_units.status = 'destroyed' then 'destroyed' else 'ready' end,
  updated_at = now()
from public.factions
join final_capitals on final_capitals.faction_slug = factions.slug
where campaign_units.faction_id = factions.id;

with final_capitals(faction_slug, system_slug) as (
  values
    ('legiones-daemonicas', 'mordax'),
    ('space-marines', 'sa-cea-gate'),
    ('necrones', 'thokt-vault'),
    ('adeptus-custodes', 'kharon-prime'),
    ('cultos-genestealer', 'blackglass')
)
update public.relics
set system_id = public.seed_uuid('system', final_capitals.system_slug)
from public.factions
join final_capitals on final_capitals.faction_slug = factions.slug
where relics.faction_id = factions.id
  and relics.equipped_unit_id is null;

delete from public.system_special_objects;
delete from public.system_edges;
delete from public.system_buildings
where system_id not in (
  public.seed_uuid('system', 'mordax'),
  public.seed_uuid('system', 'sa-cea-gate'),
  public.seed_uuid('system', 'thokt-vault'),
  public.seed_uuid('system', 'kharon-prime'),
  public.seed_uuid('system', 'blackglass')
);
delete from public.system_resource_capabilities;
delete from public.system_production;

with final_systems(slug, name, x, y, size, star_class, type, status, controller_slug, public_description, is_capital, system_kind, is_conquerable, allows_shared_occupation, building_slots) as (
  values
    ('mordax', 'Mordax', 90, 150, 1.18, 'red', 'Capital corrupta', 'controlled', 'legiones-daemonicas', 'Mundo industrial desgarrado por senales disformes.', true, 'standard', true, false, 6),
    ('drusus', 'Drusus', 230, 190, 0.86, 'orange', 'Bastion menor neutral', 'neutral', null, 'Fortaleza abandonada en una ruta alta hacia los fuegos centrales.', false, 'standard', true, false, 3),
    ('sa-cea-gate', 'Sa''cea Gate', 910, 150, 1.2, 'white', 'Capital orbital', 'controlled', 'space-marines', 'Estacion de paso con matrices de navegacion de largo alcance.', true, 'standard', true, false, 6),
    ('lyra-terminus', 'Lyra Terminus', 770, 190, 0.88, 'blue', 'Puerto externo neutral', 'neutral', null, 'Puerto orbital sin mando estable, demasiado cercano al frente para ser ignorado.', false, 'standard', true, false, 3),
    ('thokt-vault', 'Thokt Vault', 930, 500, 1.2, 'green', 'Capital tumba', 'controlled', 'necrones', 'Cripta silenciosa rodeada de energia verdosa.', true, 'standard', true, false, 6),
    ('novem', 'Novem', 785, 500, 0.84, 'white', 'Luna industrial neutral', 'neutral', null, 'Complejo lunar de extraccion automatizada a la espera de un nuevo amo.', false, 'standard', true, false, 3),
    ('kharon-prime', 'Kharon Prime', 145, 850, 1.2, 'blue', 'Capital fortificada', 'controlled', 'adeptus-custodes', 'Bastion aurico y astropuerto militar custodiado por los guardianes del Trono.', true, 'standard', true, false, 6),
    ('helios-drift', 'Helios Drift', 285, 735, 0.9, 'orange', 'Cinturon minero neutral', 'neutral', null, 'Primer corredor desde Kharon: asteroides ricos en mineral y rutas abiertas hacia el centro.', false, 'standard', true, false, 3),
    ('blackglass', 'Blackglass', 820, 850, 1.16, 'white', 'Capital cristalina', 'controlled', 'cultos-genestealer', 'Honor bajo oceanos de vidrio oscuro.', true, 'standard', true, false, 6),
    ('red-sabbath', 'Red Sabbath', 705, 735, 0.88, 'red', 'Mundo sermonario neutral', 'neutral', null, 'Ciudades santuario sin autoridad estable, llenas de rutas subterraneas y ruido civil.', false, 'standard', true, false, 3),
    ('maelstrom-gas', 'Maelstrom Gas', 500, 360, 1.08, 'violet', 'Anomalia gaseosa central', 'neutral', null, 'Una nube de plasma y gases ionizados abre un paso peligroso hacia el nucleo orko.', false, 'gaseous', false, true, 0),
    ('voidmist-basin', 'Voidmist Basin', 500, 640, 1.04, 'blue', 'Cuenca gaseosa central', 'neutral', null, 'Un oceano de niebla estelar permite rodear el centro sin reclamar territorio estable.', false, 'gaseous', false, true, 0),
    ('nexus-aster', 'Nexus Aster', 420, 500, 0.96, 'green', 'Enclave orko central', 'controlled', 'orcos', 'Un nudo de rutas tomado por senales de guerra orkas y chatarra militar.', false, 'standard', true, false, 3),
    ('goregate', 'Goregate', 580, 500, 0.96, 'red', 'Portal de guerra orko', 'controlled', 'orcos', 'Paso sangriento convertido en puerta de saqueo para incursiones orkas.', false, 'standard', true, false, 3)
)
insert into public.systems (
  id,
  slug,
  name,
  x,
  y,
  size,
  star_class,
  type,
  status,
  controller_faction_id,
  blocked_until,
  public_description,
  is_capital,
  building_slots,
  system_kind,
  is_conquerable,
  allows_shared_occupation,
  is_temporary_mission,
  mission_threat_faction_id,
  mission_enemy_units_visible,
  mission_enemy_units,
  mission_expires_at,
  mission_expires_after_battle,
  temporary_mission_status,
  temporary_mission_closed_at
)
select
  public.seed_uuid('system', final_systems.slug),
  final_systems.slug,
  final_systems.name,
  final_systems.x,
  final_systems.y,
  final_systems.size,
  final_systems.star_class,
  final_systems.type,
  final_systems.status,
  factions.id,
  null,
  final_systems.public_description,
  final_systems.is_capital,
  final_systems.building_slots,
  final_systems.system_kind,
  final_systems.is_conquerable,
  final_systems.allows_shared_occupation,
  false,
  null,
  false,
  '[]'::jsonb,
  null,
  false,
  'active',
  null
from final_systems
left join public.factions on factions.slug = final_systems.controller_slug
on conflict (slug) do update
set
  name = excluded.name,
  x = excluded.x,
  y = excluded.y,
  size = excluded.size,
  star_class = excluded.star_class,
  type = excluded.type,
  status = excluded.status,
  controller_faction_id = excluded.controller_faction_id,
  blocked_until = null,
  public_description = excluded.public_description,
  is_capital = excluded.is_capital,
  building_slots = excluded.building_slots,
  system_kind = excluded.system_kind,
  is_conquerable = excluded.is_conquerable,
  allows_shared_occupation = excluded.allows_shared_occupation,
  is_temporary_mission = false,
  mission_threat_faction_id = null,
  mission_enemy_units_visible = false,
  mission_enemy_units = '[]'::jsonb,
  mission_expires_at = null,
  mission_expires_after_battle = false,
  temporary_mission_status = 'active',
  temporary_mission_closed_at = null,
  updated_at = now();

delete from public.systems
where slug not in (
  'mordax','drusus',
  'sa-cea-gate','lyra-terminus',
  'thokt-vault','novem',
  'kharon-prime','helios-drift',
  'blackglass','red-sabbath',
  'maelstrom-gas','voidmist-basin',
  'nexus-aster','goregate'
);

update public.factions set capital_system_id = public.seed_uuid('system', 'mordax') where slug = 'legiones-daemonicas';
update public.factions set capital_system_id = public.seed_uuid('system', 'sa-cea-gate') where slug = 'space-marines';
update public.factions set capital_system_id = public.seed_uuid('system', 'thokt-vault') where slug = 'necrones';
update public.factions set capital_system_id = public.seed_uuid('system', 'kharon-prime') where slug = 'adeptus-custodes';
update public.factions set capital_system_id = public.seed_uuid('system', 'blackglass') where slug = 'cultos-genestealer';
update public.factions set capital_system_id = null where slug in ('orcos', 'tiranidos');

insert into public.system_edges (id, slug, from_system_id, to_system_id, uridium_cost, is_blocked)
values
  (public.seed_uuid('edge', 'route-01'), 'route-01', public.seed_uuid('system', 'mordax'), public.seed_uuid('system', 'drusus'), 1, false),
  (public.seed_uuid('edge', 'route-02'), 'route-02', public.seed_uuid('system', 'drusus'), public.seed_uuid('system', 'maelstrom-gas'), 1, false),
  (public.seed_uuid('edge', 'route-03'), 'route-03', public.seed_uuid('system', 'sa-cea-gate'), public.seed_uuid('system', 'lyra-terminus'), 1, false),
  (public.seed_uuid('edge', 'route-04'), 'route-04', public.seed_uuid('system', 'lyra-terminus'), public.seed_uuid('system', 'maelstrom-gas'), 1, false),
  (public.seed_uuid('edge', 'route-05'), 'route-05', public.seed_uuid('system', 'thokt-vault'), public.seed_uuid('system', 'novem'), 1, false),
  (public.seed_uuid('edge', 'route-06'), 'route-06', public.seed_uuid('system', 'novem'), public.seed_uuid('system', 'maelstrom-gas'), 1, false),
  (public.seed_uuid('edge', 'route-07'), 'route-07', public.seed_uuid('system', 'kharon-prime'), public.seed_uuid('system', 'helios-drift'), 1, false),
  (public.seed_uuid('edge', 'route-08'), 'route-08', public.seed_uuid('system', 'helios-drift'), public.seed_uuid('system', 'voidmist-basin'), 1, false),
  (public.seed_uuid('edge', 'route-09'), 'route-09', public.seed_uuid('system', 'blackglass'), public.seed_uuid('system', 'red-sabbath'), 1, false),
  (public.seed_uuid('edge', 'route-10'), 'route-10', public.seed_uuid('system', 'red-sabbath'), public.seed_uuid('system', 'voidmist-basin'), 1, false),
  (public.seed_uuid('edge', 'route-11'), 'route-11', public.seed_uuid('system', 'maelstrom-gas'), public.seed_uuid('system', 'nexus-aster'), 1, false),
  (public.seed_uuid('edge', 'route-12'), 'route-12', public.seed_uuid('system', 'maelstrom-gas'), public.seed_uuid('system', 'goregate'), 1, false),
  (public.seed_uuid('edge', 'route-13'), 'route-13', public.seed_uuid('system', 'voidmist-basin'), public.seed_uuid('system', 'nexus-aster'), 1, false),
  (public.seed_uuid('edge', 'route-14'), 'route-14', public.seed_uuid('system', 'voidmist-basin'), public.seed_uuid('system', 'goregate'), 1, false);

insert into public.system_special_objects (id, system_id, name, type, public_description, is_public)
values
  (public.seed_uuid('system_special_object', 'obj-nexus-aster'), public.seed_uuid('system', 'nexus-aster'), 'Totem del Nexus', 'anomaly', 'Un enjambre de chatarra, balizas robadas y senales de guerra orkas domina el nodo.', true),
  (public.seed_uuid('system_special_object', 'obj-goregate'), public.seed_uuid('system', 'goregate'), 'Puerta de la Waaagh', 'anomaly', 'La ruta central inferior vibra con motores improvisados y amenazas pintadas en rojo.', true),
  (public.seed_uuid('system_special_object', 'obj-maelstrom-gas'), public.seed_uuid('system', 'maelstrom-gas'), 'Marea ionizada', 'anomaly', 'Tormentas de plasma velan el corredor superior del centro.', true),
  (public.seed_uuid('system_special_object', 'obj-voidmist-basin'), public.seed_uuid('system', 'voidmist-basin'), 'Cuenca de vacio', 'anomaly', 'Nubes frias de gas estelar cubren el corredor inferior del nucleo orko.', true)
on conflict (id) do update
set
  system_id = excluded.system_id,
  name = excluded.name,
  type = excluded.type,
  public_description = excluded.public_description,
  is_public = excluded.is_public;

select public.rebuild_system_resource_capabilities();
select public.refresh_system_production_from_buildings();

insert into public.campaign_logs (faction_id, action_type, payload)
values (
  null,
  'compact_final_campaign_map_applied',
  jsonb_build_object(
    'systems', 14,
    'routes', 14,
    'gaseous_systems', jsonb_build_array('maelstrom-gas', 'voidmist-basin'),
    'central_controller', 'orcos',
    'applied_at', now()
  )
);
