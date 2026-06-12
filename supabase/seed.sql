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
delete from public.missions;
delete from public.system_special_objects;
delete from public.relics;
delete from public.unit_recovery_queue;
delete from public.recruitment_queue;
delete from public.movement_order_units;
delete from public.movement_orders;
delete from public.trade_offers;
delete from public.campaign_units;
delete from public.conflicts;
delete from public.campaign_logs;
delete from public.system_buildings;
delete from public.system_resource_capabilities;
delete from public.system_production;
delete from public.system_edges;
delete from public.faction_resources;
delete from public.unit_templates;
delete from public.faction_technologies;
delete from public.technology_effects;
delete from public.technology_prerequisites;
delete from public.building_templates;
delete from public.technology_nodes;
update public.factions set capital_system_id = null;
delete from public.systems;
delete from public.factions;

insert into public.factions (id, slug, name, color)
values
  (public.seed_uuid('faction', 'orcos'), 'orcos', 'Orcos', '#84cc16'),
  (public.seed_uuid('faction', 'necrones'), 'necrones', 'Necrones', '#2dd4bf'),
  (public.seed_uuid('faction', 'guardia-imperial'), 'guardia-imperial', 'Guardia Imperial', '#38bdf8'),
  (public.seed_uuid('faction', 'culto-genestelar'), 'culto-genestelar', 'Culto Genestelar', '#c084fc'),
  (public.seed_uuid('faction', 'sombra-emperador'), 'sombra-emperador', 'Sombra del Emperador', '#facc15'),
  (public.seed_uuid('faction', 'guardia-muerte'), 'guardia-muerte', 'Guardia de la Muerte', '#b6c35a')
on conflict (slug) do update
set name = excluded.name, color = excluded.color;

insert into public.systems (
  id, slug, name, x, y, size, star_class, type, status, controller_faction_id, blocked_until, public_description, is_capital
)
values
  (public.seed_uuid('system', 'kharon-prime'), 'kharon-prime', 'Kharon Prime', 90, 170, 1.2, 'blue', 'Capital fortificada', 'controlled', public.seed_uuid('faction', 'guardia-imperial'), null, 'Bastion manufactorum y astropuerto militar del frente imperial.', true),
  (public.seed_uuid('system', 'helios-drift'), 'helios-drift', 'Helios Drift', 215, 190, 0.9, 'orange', 'Cinturon minero', 'controlled', public.seed_uuid('faction', 'guardia-imperial'), null, 'Asteroides ricos en mineral defendidos por baterias orbitales.', false),
  (public.seed_uuid('system', 'arx-solum'), 'arx-solum', 'Arx Solum', 315, 255, 0.82, 'white', 'Bastion exterior', 'controlled', public.seed_uuid('faction', 'guardia-imperial'), null, 'Fortaleza avanzada que vigila las rutas hacia la Zanja Azul.', false),
  (public.seed_uuid('system', 'sa-cea-gate'), 'sa-cea-gate', 'Sa''cea Gate', 910, 150, 1.2, 'white', 'Capital orbital', 'controlled', public.seed_uuid('faction', 'sombra-emperador'), null, 'Estacion de paso con matrices de navegacion de largo alcance.', true),
  (public.seed_uuid('system', 'lyra-terminus'), 'lyra-terminus', 'Lyra Terminus', 790, 210, 0.88, 'blue', 'Puerto externo', 'controlled', public.seed_uuid('faction', 'sombra-emperador'), null, 'Puerto orbital en el borde del subsector.', false),
  (public.seed_uuid('system', 'narthex'), 'narthex', 'Narthex', 685, 285, 0.95, 'yellow', 'Santuario sellado', 'controlled', public.seed_uuid('faction', 'sombra-emperador'), null, 'Complejo sacro con rutas de descenso peligrosas.', false),
  (public.seed_uuid('system', 'blackglass'), 'blackglass', 'Blackglass', 930, 440, 1.16, 'white', 'Capital cristalina', 'controlled', public.seed_uuid('faction', 'culto-genestelar'), null, 'Piedra ancestral bajo oceanos de vidrio oscuro.', true),
  (public.seed_uuid('system', 'red-sabbath'), 'red-sabbath', 'Red Sabbath', 805, 485, 0.88, 'red', 'Mundo sermonario', 'controlled', public.seed_uuid('faction', 'culto-genestelar'), null, 'Ciudades santuario infiltradas por redes de culto.', false),
  (public.seed_uuid('system', 'mirrorcoil'), 'mirrorcoil', 'Mirrorcoil', 685, 510, 0.82, 'violet', 'Enjambre orbital', 'controlled', public.seed_uuid('faction', 'culto-genestelar'), null, 'Estaciones gemelas que repiten senales falsas hacia el centro.', false),
  (public.seed_uuid('system', 'thokt-vault'), 'thokt-vault', 'Thokt Vault', 805, 800, 1.2, 'green', 'Capital tumba', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Cripta silenciosa rodeada de energia verdosa.', true),
  (public.seed_uuid('system', 'novem'), 'novem', 'Novem', 725, 700, 0.84, 'white', 'Luna industrial', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Complejo lunar de extraccion automatizada.', false),
  (public.seed_uuid('system', 'ghostlight'), 'ghostlight', 'Ghostlight', 625, 645, 0.8, 'green', 'Faro perdido', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Faro de navegacion que parpadea con luz fria.', false),
  (public.seed_uuid('system', 'mordax'), 'mordax', 'Mordax', 150, 780, 1.18, 'red', 'Capital corrupta', 'controlled', public.seed_uuid('faction', 'guardia-muerte'), null, 'Mundo industrial desgarrado por senales disformes.', true),
  (public.seed_uuid('system', 'drusus'), 'drusus', 'Drusus', 260, 700, 0.86, 'orange', 'Bastion menor', 'controlled', public.seed_uuid('faction', 'guardia-muerte'), null, 'Fortaleza tomada tras una campana sangrienta.', false),
  (public.seed_uuid('system', 'plaguefall-bastion'), 'plaguefall-bastion', 'Plaguefall Bastion', 360, 640, 0.82, 'green', 'Bastion infectado', 'controlled', public.seed_uuid('faction', 'guardia-muerte'), null, 'Plataformas de asedio cubiertas por esporas y ceniza.', false),
  (public.seed_uuid('system', 'cinder-maw'), 'cinder-maw', 'Cinder Maw', 80, 430, 1.15, 'orange', 'Capital volcanica', 'controlled', public.seed_uuid('faction', 'orcos'), null, 'Forjas geotermicas y tormentas de ceniza.', true),
  (public.seed_uuid('system', 'eclipse-forge'), 'eclipse-forge', 'Eclipse Forge', 185, 485, 0.86, 'red', 'Forja abandonada', 'controlled', public.seed_uuid('faction', 'orcos'), null, 'Estructuras de manufactura latentes convertidas en talleres orkos.', false),
  (public.seed_uuid('system', 'rustmaw-run'), 'rustmaw-run', 'Rustmaw Run', 285, 430, 0.82, 'orange', 'Corredor chatarrero', 'controlled', public.seed_uuid('faction', 'orcos'), null, 'Ruta de pecios saqueados que apunta hacia el centro.', false),
  (public.seed_uuid('system', 'azur-trench'), 'azur-trench', 'Azur Trench', 405, 390, 0.86, 'blue', 'Nebulosa navegable', 'war', null, now() + interval '14 days', 'Corredor azul con pozos de gravedad inestables. Orcos e Imperiales han chocado aqui.', false),
  (public.seed_uuid('system', 'ossuary-reach'), 'ossuary-reach', 'Ossuary Reach', 485, 625, 0.84, 'violet', 'Osario orbital', 'war', null, now() + interval '14 days', 'Campos funerarios en orbita baja, disputados por plaga y tecnologia necrona.', false),
  (public.seed_uuid('system', 'saint-veil'), 'saint-veil', 'Saint Veil', 650, 395, 0.86, 'yellow', 'Velo sagrado', 'war', null, now() + interval '14 days', 'Santuario velado donde la Sombra del Emperador combate una revuelta genestelar.', false),
  (public.seed_uuid('system', 'orison'), 'orison', 'Orison', 470, 310, 0.84, 'yellow', 'Colonia agricola', 'neutral', null, null, 'Graneros presurizados y bastiones de defensa civil abandonados.', false),
  (public.seed_uuid('system', 'vesper-halo'), 'vesper-halo', 'Vesper Halo', 560, 220, 0.82, 'violet', 'Anillo orbital', 'neutral', null, null, 'Ruinas orbitales con ecos de tecnologia antigua.', false),
  (public.seed_uuid('system', 'pale-choir'), 'pale-choir', 'Pale Choir', 690, 605, 0.78, 'violet', 'Anomalia psiquica', 'neutral', null, null, 'Un coro de senales imposibles atraviesa el vacio.', false),
  (public.seed_uuid('system', 'ashen-road'), 'ashen-road', 'Ashen Road', 560, 555, 0.78, 'blue', 'Nodo de transito', 'neutral', null, null, 'Rutas estables entre corrientes de polvo orbital.', false),
  (public.seed_uuid('system', 'sepulchre-nine'), 'sepulchre-nine', 'Sepulchre IX', 340, 780, 0.78, 'violet', 'Necropolis', 'neutral', null, null, 'Tumbas y coordenadas contradictorias.', false),
  (public.seed_uuid('system', 'nexus-aster'), 'nexus-aster', 'Nexus Aster', 525, 455, 0.92, 'green', 'Nodo central', 'neutral', null, null, 'Interseccion de corrientes de salto que todas las facciones desean controlar.', false),
  (public.seed_uuid('system', 'argent-rift'), 'argent-rift', 'Argent Rift', 500, 245, 0.76, 'white', 'Fisura plateada', 'neutral', null, null, 'Brecha gravitatoria brillante, estable solo en ventanas cortas.', false),
  (public.seed_uuid('system', 'voidfall-anchor'), 'voidfall-anchor', 'Voidfall Anchor', 510, 735, 0.78, 'blue', 'Ancla de vacio', 'neutral', null, null, 'Macroestructura que estabiliza saltos en el borde inferior del mapa.', false),
  (public.seed_uuid('system', 'goregate'), 'goregate', 'Goregate', 260, 540, 0.78, 'red', 'Paso sangriento', 'neutral', null, null, 'Paso estrecho entre chatarra orka y ruinas funerarias.', false)
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
  blocked_until = excluded.blocked_until,
  public_description = excluded.public_description,
  is_capital = excluded.is_capital,
  updated_at = now();

update public.systems
set building_slots = case when is_capital then 6 else 3 end;

update public.systems
set
  system_kind = 'standard',
  is_conquerable = true,
  allows_shared_occupation = false;

update public.systems
set
  system_kind = 'gaseous',
  is_conquerable = false,
  allows_shared_occupation = true,
  status = 'neutral',
  controller_faction_id = null,
  blocked_until = null,
  updated_at = now()
where slug in ('nexus-aster', 'ashen-road');

update public.factions set capital_system_id = public.seed_uuid('system', 'cinder-maw') where slug = 'orcos';
update public.factions set capital_system_id = public.seed_uuid('system', 'thokt-vault') where slug = 'necrones';
update public.factions set capital_system_id = public.seed_uuid('system', 'kharon-prime') where slug = 'guardia-imperial';
update public.factions set capital_system_id = public.seed_uuid('system', 'blackglass') where slug = 'culto-genestelar';
update public.factions set capital_system_id = public.seed_uuid('system', 'sa-cea-gate') where slug = 'sombra-emperador';
update public.factions set capital_system_id = public.seed_uuid('system', 'mordax') where slug = 'guardia-muerte';

insert into public.system_edges (id, slug, from_system_id, to_system_id, uridium_cost, is_blocked)
values
  (public.seed_uuid('edge', 'route-01'), 'route-01', public.seed_uuid('system', 'kharon-prime'), public.seed_uuid('system', 'helios-drift'), 1, false),
  (public.seed_uuid('edge', 'route-02'), 'route-02', public.seed_uuid('system', 'helios-drift'), public.seed_uuid('system', 'arx-solum'), 1, false),
  (public.seed_uuid('edge', 'route-03'), 'route-03', public.seed_uuid('system', 'arx-solum'), public.seed_uuid('system', 'azur-trench'), 2, false),
  (public.seed_uuid('edge', 'route-04'), 'route-04', public.seed_uuid('system', 'arx-solum'), public.seed_uuid('system', 'orison'), 2, false),
  (public.seed_uuid('edge', 'route-05'), 'route-05', public.seed_uuid('system', 'cinder-maw'), public.seed_uuid('system', 'eclipse-forge'), 1, false),
  (public.seed_uuid('edge', 'route-06'), 'route-06', public.seed_uuid('system', 'eclipse-forge'), public.seed_uuid('system', 'rustmaw-run'), 1, false),
  (public.seed_uuid('edge', 'route-07'), 'route-07', public.seed_uuid('system', 'rustmaw-run'), public.seed_uuid('system', 'azur-trench'), 2, false),
  (public.seed_uuid('edge', 'route-08'), 'route-08', public.seed_uuid('system', 'rustmaw-run'), public.seed_uuid('system', 'goregate'), 1, false),
  (public.seed_uuid('edge', 'route-09'), 'route-09', public.seed_uuid('system', 'sa-cea-gate'), public.seed_uuid('system', 'lyra-terminus'), 1, false),
  (public.seed_uuid('edge', 'route-10'), 'route-10', public.seed_uuid('system', 'lyra-terminus'), public.seed_uuid('system', 'narthex'), 1, false),
  (public.seed_uuid('edge', 'route-11'), 'route-11', public.seed_uuid('system', 'narthex'), public.seed_uuid('system', 'saint-veil'), 2, false),
  (public.seed_uuid('edge', 'route-12'), 'route-12', public.seed_uuid('system', 'narthex'), public.seed_uuid('system', 'vesper-halo'), 1, false),
  (public.seed_uuid('edge', 'route-13'), 'route-13', public.seed_uuid('system', 'blackglass'), public.seed_uuid('system', 'red-sabbath'), 1, false),
  (public.seed_uuid('edge', 'route-14'), 'route-14', public.seed_uuid('system', 'red-sabbath'), public.seed_uuid('system', 'mirrorcoil'), 1, false),
  (public.seed_uuid('edge', 'route-15'), 'route-15', public.seed_uuid('system', 'mirrorcoil'), public.seed_uuid('system', 'saint-veil'), 2, false),
  (public.seed_uuid('edge', 'route-16'), 'route-16', public.seed_uuid('system', 'mirrorcoil'), public.seed_uuid('system', 'pale-choir'), 1, false),
  (public.seed_uuid('edge', 'route-17'), 'route-17', public.seed_uuid('system', 'thokt-vault'), public.seed_uuid('system', 'novem'), 1, false),
  (public.seed_uuid('edge', 'route-18'), 'route-18', public.seed_uuid('system', 'novem'), public.seed_uuid('system', 'ghostlight'), 1, false),
  (public.seed_uuid('edge', 'route-19'), 'route-19', public.seed_uuid('system', 'ghostlight'), public.seed_uuid('system', 'ossuary-reach'), 2, false),
  (public.seed_uuid('edge', 'route-20'), 'route-20', public.seed_uuid('system', 'ghostlight'), public.seed_uuid('system', 'voidfall-anchor'), 1, false),
  (public.seed_uuid('edge', 'route-21'), 'route-21', public.seed_uuid('system', 'mordax'), public.seed_uuid('system', 'drusus'), 1, false),
  (public.seed_uuid('edge', 'route-22'), 'route-22', public.seed_uuid('system', 'drusus'), public.seed_uuid('system', 'plaguefall-bastion'), 1, false),
  (public.seed_uuid('edge', 'route-23'), 'route-23', public.seed_uuid('system', 'plaguefall-bastion'), public.seed_uuid('system', 'ossuary-reach'), 2, false),
  (public.seed_uuid('edge', 'route-24'), 'route-24', public.seed_uuid('system', 'plaguefall-bastion'), public.seed_uuid('system', 'sepulchre-nine'), 1, false),
  (public.seed_uuid('edge', 'route-25'), 'route-25', public.seed_uuid('system', 'azur-trench'), public.seed_uuid('system', 'orison'), 2, false),
  (public.seed_uuid('edge', 'route-26'), 'route-26', public.seed_uuid('system', 'orison'), public.seed_uuid('system', 'argent-rift'), 1, false),
  (public.seed_uuid('edge', 'route-27'), 'route-27', public.seed_uuid('system', 'argent-rift'), public.seed_uuid('system', 'vesper-halo'), 1, false),
  (public.seed_uuid('edge', 'route-28'), 'route-28', public.seed_uuid('system', 'vesper-halo'), public.seed_uuid('system', 'saint-veil'), 2, false),
  (public.seed_uuid('edge', 'route-29'), 'route-29', public.seed_uuid('system', 'saint-veil'), public.seed_uuid('system', 'pale-choir'), 2, false),
  (public.seed_uuid('edge', 'route-30'), 'route-30', public.seed_uuid('system', 'pale-choir'), public.seed_uuid('system', 'ashen-road'), 1, false),
  (public.seed_uuid('edge', 'route-31'), 'route-31', public.seed_uuid('system', 'ashen-road'), public.seed_uuid('system', 'ossuary-reach'), 2, false),
  (public.seed_uuid('edge', 'route-32'), 'route-32', public.seed_uuid('system', 'ossuary-reach'), public.seed_uuid('system', 'voidfall-anchor'), 2, false),
  (public.seed_uuid('edge', 'route-33'), 'route-33', public.seed_uuid('system', 'voidfall-anchor'), public.seed_uuid('system', 'sepulchre-nine'), 1, false),
  (public.seed_uuid('edge', 'route-34'), 'route-34', public.seed_uuid('system', 'sepulchre-nine'), public.seed_uuid('system', 'goregate'), 2, false),
  (public.seed_uuid('edge', 'route-35'), 'route-35', public.seed_uuid('system', 'goregate'), public.seed_uuid('system', 'azur-trench'), 1, false),
  (public.seed_uuid('edge', 'route-36'), 'route-36', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'orison'), 3, false),
  (public.seed_uuid('edge', 'route-37'), 'route-37', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'azur-trench'), 3, false),
  (public.seed_uuid('edge', 'route-38'), 'route-38', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'saint-veil'), 3, false),
  (public.seed_uuid('edge', 'route-39'), 'route-39', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'ashen-road'), 3, false),
  (public.seed_uuid('edge', 'route-40'), 'route-40', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'ossuary-reach'), 3, false)
on conflict (slug) do update
set from_system_id = excluded.from_system_id, to_system_id = excluded.to_system_id, uridium_cost = excluded.uridium_cost, is_blocked = excluded.is_blocked;

insert into public.faction_resources (faction_id, supply, minerals, ancestral_stone, honor, gold, industrial_material, uridium, technology)
values
  (public.seed_uuid('faction', 'guardia-imperial'), 180, 130, 12, 12, 34, 90, 24, 16),
  (public.seed_uuid('faction', 'orcos'), 190, 135, 7, 7, 26, 90, 20, 16),
  (public.seed_uuid('faction', 'necrones'), 115, 155, 18, 18, 32, 90, 22, 16),
  (public.seed_uuid('faction', 'culto-genestelar'), 185, 115, 13, 13, 30, 90, 22, 16),
  (public.seed_uuid('faction', 'sombra-emperador'), 135, 130, 18, 18, 38, 90, 26, 16),
  (public.seed_uuid('faction', 'guardia-muerte'), 155, 135, 15, 15, 28, 90, 20, 16)
on conflict (faction_id) do update
set supply = excluded.supply, minerals = excluded.minerals, ancestral_stone = excluded.ancestral_stone, honor = excluded.honor, gold = excluded.gold, industrial_material = excluded.industrial_material, uridium = excluded.uridium, technology = excluded.technology, updated_at = now();

insert into public.system_production (system_id, supply_per_tick, minerals_per_tick, ancestral_stone_per_tick, gold_per_tick, uridium_per_tick, technology_per_tick)
values
  (public.seed_uuid('system', 'kharon-prime'), 9, 6, 0, 0, 2, 0),
  (public.seed_uuid('system', 'helios-drift'), 1, 7, 0, 0, 1, 0),
  (public.seed_uuid('system', 'arx-solum'), 5, 3, 0, 0, 1, 0),
  (public.seed_uuid('system', 'sa-cea-gate'), 5, 4, 0, 0, 5, 0),
  (public.seed_uuid('system', 'lyra-terminus'), 3, 1, 0, 0, 4, 0),
  (public.seed_uuid('system', 'narthex'), 2, 0, 2, 0, 1, 0),
  (public.seed_uuid('system', 'blackglass'), 3, 4, 2, 0, 1, 0),
  (public.seed_uuid('system', 'red-sabbath'), 5, 2, 1, 0, 1, 0),
  (public.seed_uuid('system', 'mirrorcoil'), 2, 2, 1, 0, 3, 0),
  (public.seed_uuid('system', 'thokt-vault'), 0, 8, 3, 0, 2, 0),
  (public.seed_uuid('system', 'novem'), 0, 7, 0, 0, 1, 0),
  (public.seed_uuid('system', 'ghostlight'), 0, 2, 1, 0, 3, 0),
  (public.seed_uuid('system', 'mordax'), 5, 6, 1, 0, 2, 0),
  (public.seed_uuid('system', 'drusus'), 4, 4, 0, 0, 1, 0),
  (public.seed_uuid('system', 'plaguefall-bastion'), 3, 5, 1, 0, 1, 0),
  (public.seed_uuid('system', 'cinder-maw'), 4, 7, 0, 0, 1, 0),
  (public.seed_uuid('system', 'eclipse-forge'), 1, 6, 0, 0, 1, 0),
  (public.seed_uuid('system', 'rustmaw-run'), 3, 5, 0, 0, 2, 0),
  (public.seed_uuid('system', 'azur-trench'), 0, 0, 0, 0, 5, 0),
  (public.seed_uuid('system', 'ossuary-reach'), 0, 2, 2, 0, 2, 0),
  (public.seed_uuid('system', 'saint-veil'), 2, 0, 2, 0, 2, 0),
  (public.seed_uuid('system', 'orison'), 7, 1, 0, 0, 0, 0),
  (public.seed_uuid('system', 'vesper-halo'), 0, 2, 1, 0, 2, 0),
  (public.seed_uuid('system', 'pale-choir'), 0, 0, 2, 0, 2, 0),
  (public.seed_uuid('system', 'ashen-road'), 1, 1, 0, 0, 4, 0),
  (public.seed_uuid('system', 'sepulchre-nine'), 0, 2, 2, 0, 0, 0),
  (public.seed_uuid('system', 'nexus-aster'), 2, 2, 1, 0, 3, 0),
  (public.seed_uuid('system', 'argent-rift'), 0, 1, 0, 0, 4, 0),
  (public.seed_uuid('system', 'voidfall-anchor'), 1, 2, 0, 0, 3, 0),
  (public.seed_uuid('system', 'goregate'), 2, 3, 0, 0, 2, 0)
on conflict (system_id) do update
set supply_per_tick = excluded.supply_per_tick, minerals_per_tick = excluded.minerals_per_tick, ancestral_stone_per_tick = excluded.ancestral_stone_per_tick, gold_per_tick = excluded.gold_per_tick, uridium_per_tick = excluded.uridium_per_tick, technology_per_tick = excluded.technology_per_tick;

insert into public.technology_nodes (
  id, slug, tree_key, name, description, branch, tier, position_x, position_y, cost_technology, research_time_seconds, icon_key, effect_summary, is_starter
)
values
  (public.seed_uuid('technology_node', 'doctrina-campana'), 'doctrina-campana', 'common-v1', 'Doctrina de campana', 'Protocolos basicos para sostener una campana galactica en tiempo real.', 'Mando y doctrina', 0, 48, 46, 0, 0, 'command', 'Base doctrinal desbloqueada.', true),
  (public.seed_uuid('technology_node', 'logistica-frente'), 'logistica-frente', 'common-v1', 'Logistica de frente', 'Ajusta rutas de suministro, convoyes y reservas para mantener infanteria en movimiento.', 'Mando y doctrina', 1, 30, 34, 4, 120, 'supply', '-10% Suministro al reclutar Infanteria.', false),
  (public.seed_uuid('technology_node', 'cadenas-mando'), 'cadenas-mando', 'common-v1', 'Cadenas de mando', 'Vox, protocolos de enlace y oficiales de enlace reducen demoras de despliegue.', 'Mando y doctrina', 1, 56, 28, 4, 120, 'command', '-10% tiempo al reclutar Infanteria.', false),
  (public.seed_uuid('technology_node', 'estado-mayor-cruzada'), 'estado-mayor-cruzada', 'common-v1', 'Estado mayor de cruzada', 'Permite coordinar instalaciones de mando estables para una campana prolongada.', 'Mando y doctrina', 3, 44, 14, 12, 360, 'command', 'Desbloquea Bastion de mando.', false),

  (public.seed_uuid('technology_node', 'entrenamiento-linea'), 'entrenamiento-linea', 'common-v1', 'Entrenamiento de linea', 'Organizacion minima para reclutar tropas basicas de cada faccion.', 'Infanteria y elite', 0, 42, 56, 0, 0, 'infantry', 'Unidades basicas desbloqueadas.', true),
  (public.seed_uuid('technology_node', 'veteranos-guerra'), 'veteranos-guerra', 'common-v1', 'Veteranos de guerra', 'Permite desplegar cuadros veteranos, elites y tropas endurecidas.', 'Infanteria y elite', 1, 28, 62, 4, 120, 'elite', 'Desbloquea unidades elite actuales.', false),
  (public.seed_uuid('technology_node', 'especializacion-elite'), 'especializacion-elite', 'common-v1', 'Especializacion de elite', 'Cadenas de municion, equipo y entrenamiento para unidades de alto valor.', 'Infanteria y elite', 2, 17, 76, 8, 240, 'elite', '-10% Mineral al reclutar Elite.', false),
  (public.seed_uuid('technology_node', 'honores-batalla'), 'honores-batalla', 'common-v1', 'Honores de batalla', 'Registros, juramentos y marcas de campana para futuras mejoras narrativas.', 'Infanteria y elite', 3, 31, 88, 12, 360, 'honor', 'Reserva para mejoras narrativas.', false),

  (public.seed_uuid('technology_node', 'talleres-campana'), 'talleres-campana', 'common-v1', 'Talleres de campana', 'Instala lineas de mantenimiento para maquinas, vehiculos y andadores.', 'Blindados y maquinas', 1, 61, 60, 4, 120, 'forge', 'Desbloquea Taller de campana.', false),
  (public.seed_uuid('technology_node', 'dominio-bestial'), 'dominio-bestial', 'common-v1', 'Dominio bestial', 'Instalaciones, jaulas y ritos de control para criaturas de guerra.', 'Blindados y maquinas', 2, 66, 74, 8, 240, 'beast', 'Desbloquea Nido de Bestias.', false),
  (public.seed_uuid('technology_node', 'motores-guerra'), 'motores-guerra', 'common-v1', 'Motores de guerra', 'Habilita blindados, dreadnoughts y maquinas de guerra en el teatro activo.', 'Blindados y maquinas', 2, 75, 70, 8, 240, 'vehicle', 'Desbloquea vehiculos actuales.', false),
  (public.seed_uuid('technology_node', 'blindaje-reforzado'), 'blindaje-reforzado', 'common-v1', 'Blindaje reforzado', 'Estandariza placas, chasis, reparaciones y blindajes de campana.', 'Blindados y maquinas', 3, 84, 54, 12, 360, 'vehicle', '-10% Mineral al reclutar Vehiculos.', false),
  (public.seed_uuid('technology_node', 'arsenal-pesado'), 'arsenal-pesado', 'common-v1', 'Arsenal pesado', 'Infraestructura reservada para superpesados y activos de asedio futuros.', 'Blindados y maquinas', 4, 91, 78, 18, 600, 'arsenal', 'Reserva para superpesados futuros.', false),

  (public.seed_uuid('technology_node', 'nodo-logistico'), 'nodo-logistico', 'common-v1', 'Nodo logistico', 'Red de hangares, almacenes y puntos de transferencia orbital.', 'Infraestructura', 1, 68, 40, 4, 120, 'infrastructure', 'Desbloquea Nodo logistico.', false),
  (public.seed_uuid('technology_node', 'manufactorum-local'), 'manufactorum-local', 'common-v1', 'Manufactorum local', 'Convierte sistemas controlados en puntos de fabricacion y ensamblaje.', 'Infraestructura', 2, 80, 30, 8, 240, 'factory', 'Desbloquea Manufactorum.', false),
  (public.seed_uuid('technology_node', 'red-suministro'), 'red-suministro', 'common-v1', 'Red de suministro', 'Futura mejora de produccion y sostenimiento territorial.', 'Infraestructura', 3, 88, 42, 12, 360, 'supply', 'Reserva para bonus de produccion.', false),
  (public.seed_uuid('technology_node', 'puerto-uridium'), 'puerto-uridium', 'common-v1', 'Puerto de Uridium', 'Infraestructura futura para optimizar rutas de salto y gasto de Uridium.', 'Infraestructura', 4, 78, 16, 18, 600, 'uridium', 'Reserva para bonus de movimiento.', false),

  (public.seed_uuid('technology_node', 'auspex-reliquias'), 'auspex-reliquias', 'common-v1', 'Auspex de reliquias', 'Patrones de lectura para detectar senales raras y artefactos antiguos.', 'Arqueotecnologia', 1, 46, 74, 4, 120, 'auspex', 'Reserva para deteccion de reliquias.', false),
  (public.seed_uuid('technology_node', 'nucleos-datos'), 'nucleos-datos', 'common-v1', 'Nucleos de datos', 'Matrices de calculo para exprimir componentes tecnologicos recuperados.', 'Arqueotecnologia', 2, 53, 88, 8, 240, 'data', 'Reserva para bonus de Componentes tecnologicos.', false),
  (public.seed_uuid('technology_node', 'matrices-eficiencia'), 'matrices-eficiencia', 'common-v1', 'Matrices de eficiencia', 'Optimizacion transversal de costes de produccion militar.', 'Arqueotecnologia', 3, 62, 80, 12, 360, 'matrix', '-5% coste general de reclutamiento.', false),
  (public.seed_uuid('technology_node', 'cifra-negra'), 'cifra-negra', 'common-v1', 'Cifra negra', 'Tecnologia avanzada sellada para fases futuras de la campana.', 'Arqueotecnologia', 4, 68, 94, 18, 600, 'cipher', 'Reserva avanzada futura.', false)
on conflict (slug) do update
set tree_key = excluded.tree_key, name = excluded.name, description = excluded.description, branch = excluded.branch, tier = excluded.tier, position_x = excluded.position_x, position_y = excluded.position_y, cost_technology = excluded.cost_technology, research_time_seconds = excluded.research_time_seconds, icon_key = excluded.icon_key, effect_summary = excluded.effect_summary, is_starter = excluded.is_starter, updated_at = now();

insert into public.technology_prerequisites (technology_node_id, required_node_id)
values
  (public.seed_uuid('technology_node', 'logistica-frente'), public.seed_uuid('technology_node', 'doctrina-campana')),
  (public.seed_uuid('technology_node', 'cadenas-mando'), public.seed_uuid('technology_node', 'doctrina-campana')),
  (public.seed_uuid('technology_node', 'estado-mayor-cruzada'), public.seed_uuid('technology_node', 'cadenas-mando')),
  (public.seed_uuid('technology_node', 'veteranos-guerra'), public.seed_uuid('technology_node', 'entrenamiento-linea')),
  (public.seed_uuid('technology_node', 'especializacion-elite'), public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('technology_node', 'honores-batalla'), public.seed_uuid('technology_node', 'especializacion-elite')),
  (public.seed_uuid('technology_node', 'talleres-campana'), public.seed_uuid('technology_node', 'doctrina-campana')),
  (public.seed_uuid('technology_node', 'dominio-bestial'), public.seed_uuid('technology_node', 'talleres-campana')),
  (public.seed_uuid('technology_node', 'motores-guerra'), public.seed_uuid('technology_node', 'talleres-campana')),
  (public.seed_uuid('technology_node', 'blindaje-reforzado'), public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('technology_node', 'arsenal-pesado'), public.seed_uuid('technology_node', 'blindaje-reforzado')),
  (public.seed_uuid('technology_node', 'nodo-logistico'), public.seed_uuid('technology_node', 'doctrina-campana')),
  (public.seed_uuid('technology_node', 'manufactorum-local'), public.seed_uuid('technology_node', 'nodo-logistico')),
  (public.seed_uuid('technology_node', 'red-suministro'), public.seed_uuid('technology_node', 'manufactorum-local')),
  (public.seed_uuid('technology_node', 'puerto-uridium'), public.seed_uuid('technology_node', 'red-suministro')),
  (public.seed_uuid('technology_node', 'auspex-reliquias'), public.seed_uuid('technology_node', 'doctrina-campana')),
  (public.seed_uuid('technology_node', 'nucleos-datos'), public.seed_uuid('technology_node', 'auspex-reliquias')),
  (public.seed_uuid('technology_node', 'matrices-eficiencia'), public.seed_uuid('technology_node', 'nucleos-datos')),
  (public.seed_uuid('technology_node', 'cifra-negra'), public.seed_uuid('technology_node', 'matrices-eficiencia'))
on conflict (technology_node_id, required_node_id) do nothing;

insert into public.technology_effects (id, technology_node_id, effect_type, payload)
values
  (public.seed_uuid('technology_effect', 'logistica-frente-supply-infantry'), public.seed_uuid('technology_node', 'logistica-frente'), 'recruitment_cost_discount', '{"category":"Infanteria","resource":"supply","percent":10}'::jsonb),
  (public.seed_uuid('technology_effect', 'cadenas-mando-time-infantry'), public.seed_uuid('technology_node', 'cadenas-mando'), 'recruitment_time_discount', '{"category":"Infanteria","percent":10}'::jsonb),
  (public.seed_uuid('technology_effect', 'veteranos-guerra-units'), public.seed_uuid('technology_node', 'veteranos-guerra'), 'unlock_unit_template', '{"unit_template_slugs":["unit-orcos-meganobz","unit-necrones-immortals","unit-necrones-skorpekh","unit-guardia-kasrkin","unit-culto-acolytes","unit-sombra-terminators","unit-muerte-plague-marines"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'especializacion-elite-minerals'), public.seed_uuid('technology_node', 'especializacion-elite'), 'recruitment_cost_discount', '{"category":"Elite","resource":"minerals","percent":10}'::jsonb),
  (public.seed_uuid('technology_effect', 'talleres-campana-building'), public.seed_uuid('technology_node', 'talleres-campana'), 'unlock_building_template', '{"building_template_slugs":["taller-guerra"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'motores-guerra-units'), public.seed_uuid('technology_node', 'motores-guerra'), 'unlock_unit_template', '{"unit_template_slugs":["unit-orcos-deff-dread","unit-guardia-leman-russ","unit-culto-ridgerunner","unit-sombra-redemptor","unit-muerte-bloat-drone"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'blindaje-reforzado-minerals'), public.seed_uuid('technology_node', 'blindaje-reforzado'), 'recruitment_cost_discount', '{"category":"Vehiculo","resource":"minerals","percent":10}'::jsonb),
  (public.seed_uuid('technology_effect', 'estado-mayor-building'), public.seed_uuid('technology_node', 'estado-mayor-cruzada'), 'unlock_building_template', '{"building_template_slugs":["cuartel-mando"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'auspex-building'), public.seed_uuid('technology_node', 'auspex-reliquias'), 'unlock_building_template', '{"building_template_slugs":["nexo-inteligencia","antenas-reconocimiento"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'puerto-uridium-building'), public.seed_uuid('technology_node', 'puerto-uridium'), 'unlock_building_template', '{"building_template_slugs":["refineria-iridium"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'manufactorum-building'), public.seed_uuid('technology_node', 'manufactorum-local'), 'unlock_building_template', '{"building_template_slugs":["mina-oro"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'dominio-bestial-building'), public.seed_uuid('technology_node', 'dominio-bestial'), 'unlock_building_template', '{"building_template_slugs":["nido-bestias"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'matrices-efficiency-general'), public.seed_uuid('technology_node', 'matrices-eficiencia'), 'recruitment_cost_discount', '{"category":"all","resource":"all","percent":5}'::jsonb)
on conflict (id) do update
set technology_node_id = excluded.technology_node_id, effect_type = excluded.effect_type, payload = excluded.payload;

insert into public.building_templates (
  id, slug, name, description, category, building_kind, supply_cost, minerals_cost, honor_cost, gold_cost, industrial_material_cost, uridium_cost, technology_cost, construction_time_seconds, produced_resource_key, produced_amount, allowed_unit_categories, required_technology_node_id, icon_key, is_available
)
values
  (public.seed_uuid('building_template', 'barracon-infanteria'), 'barracon-infanteria', 'Barracon de Infanteria', 'Centro de instruccion para tropas de linea y cuadros veteranos.', 'Reclutamiento', 'recruitment', 12, 8, 0, 0, 4, 0, 0, 240, null, 0, array['Infanteria','Elite']::text[], null, 'infantry_barracks', true),
  (public.seed_uuid('building_template', 'cuartel-mando'), 'cuartel-mando', 'Cuartel de Mando', 'Instalacion de oficiales, heroes y personajes de mando.', 'Reclutamiento', 'recruitment', 10, 10, 1, 0, 6, 0, 0, 300, null, 0, array['Personaje']::text[], public.seed_uuid('technology_node', 'estado-mayor-cruzada'), 'command_quarters', true),
  (public.seed_uuid('building_template', 'taller-guerra'), 'taller-guerra', 'Taller de Guerra', 'Bahias de reparacion y ensamblaje de vehiculos.', 'Reclutamiento', 'recruitment', 6, 16, 0, 0, 8, 0, 0, 300, null, 0, array['Vehiculo']::text[], public.seed_uuid('technology_node', 'talleres-campana'), 'war_workshop', true),
  (public.seed_uuid('building_template', 'nido-bestias'), 'nido-bestias', 'Nido de Bestias', 'Jaulas y rituales de control para monstruos de guerra.', 'Reclutamiento', 'recruitment', 14, 8, 1, 0, 6, 0, 0, 300, null, 0, array['Monstruo']::text[], public.seed_uuid('technology_node', 'dominio-bestial'), 'beast_lair', true),
  (public.seed_uuid('building_template', 'camara-comercio'), 'camara-comercio', 'Camara de Comercio', 'Mercado orbital y punto de contacto con rutas mercantes.', 'Comercio', 'commerce', 8, 8, 0, 1, 4, 0, 0, 240, null, 0, array[]::text[], null, 'commerce', true),
  (public.seed_uuid('building_template', 'nexo-inteligencia'), 'nexo-inteligencia', 'Nexo de Inteligencia', 'Centro de analisis para operaciones de espionaje futuras.', 'Inteligencia', 'intelligence', 6, 12, 1, 0, 6, 0, 0, 300, null, 0, array[]::text[], public.seed_uuid('technology_node', 'auspex-reliquias'), 'intelligence', true),
  (public.seed_uuid('building_template', 'antenas-reconocimiento'), 'antenas-reconocimiento', 'Antenas de Reconocimiento', 'Matrices de escucha y auspex de largo alcance.', 'Inteligencia', 'intelligence', 4, 8, 0, 0, 5, 2, 0, 240, null, 0, array[]::text[], public.seed_uuid('technology_node', 'auspex-reliquias'), 'recon', true),
  (public.seed_uuid('building_template', 'granja-biologica'), 'granja-biologica', 'Granja Biologica', 'Complejos de biomasa y cultivos adaptados al frente.', 'Produccion', 'production', 4, 4, 0, 0, 3, 0, 0, 180, 'supply', 10, array[]::text[], null, 'biofarm', true),
  (public.seed_uuid('building_template', 'complejo-minero'), 'complejo-minero', 'Complejo Minero', 'Pozos, excavadoras y refinerias de mineral bruto.', 'Produccion', 'production', 4, 6, 0, 0, 4, 0, 0, 180, 'minerals', 6, array[]::text[], null, 'mine', true),
  (public.seed_uuid('building_template', 'refineria-iridium'), 'refineria-iridium', 'Refineria de Iridium', 'Planta especializada para estabilizar cristales de salto.', 'Produccion', 'production', 4, 8, 0, 0, 5, 0, 0, 240, 'uridium', 4, array[]::text[], public.seed_uuid('technology_node', 'puerto-uridium'), 'iridium_refinery', true),
  (public.seed_uuid('building_template', 'mina-oro'), 'mina-oro', 'Mina de Oro', 'Extraccion de metales preciosos para rutas comerciales.', 'Produccion', 'production', 4, 8, 0, 0, 5, 0, 0, 240, 'gold', 3, array[]::text[], public.seed_uuid('technology_node', 'manufactorum-local'), 'gold_mine', true),
  (public.seed_uuid('building_template', 'planta-fundicion'), 'planta-fundicion', 'Planta de Fundicion', 'Produce Material Industrial para nuevas construcciones.', 'Produccion', 'production', 4, 10, 0, 0, 3, 0, 0, 240, 'industrial_material', 5, array[]::text[], null, 'foundry', true),
  (public.seed_uuid('building_template', 'senado'), 'senado', 'Senado', 'Institucion politica que convierte influencia local en Honor.', 'Produccion', 'production', 8, 8, 0, 1, 5, 0, 0, 300, 'honor', 2, array[]::text[], null, 'senate', true)
on conflict (slug) do update
set name = excluded.name, description = excluded.description, category = excluded.category, building_kind = excluded.building_kind, supply_cost = excluded.supply_cost, minerals_cost = excluded.minerals_cost, honor_cost = excluded.honor_cost, gold_cost = excluded.gold_cost, industrial_material_cost = excluded.industrial_material_cost, uridium_cost = excluded.uridium_cost, technology_cost = excluded.technology_cost, construction_time_seconds = excluded.construction_time_seconds, produced_resource_key = excluded.produced_resource_key, produced_amount = excluded.produced_amount, allowed_unit_categories = excluded.allowed_unit_categories, required_technology_node_id = excluded.required_technology_node_id, icon_key = excluded.icon_key, is_available = excluded.is_available, updated_at = now();

select public.rebuild_system_resource_capabilities();

insert into public.system_buildings (
  id, system_id, building_template_id, status, started_at, finishes_at, constructed_at
)
select
  public.seed_uuid('system_building', systems.slug || ':' || building_slug),
  systems.id,
  public.seed_uuid('building_template', building_slug),
  'active',
  now() - interval '30 minutes',
  now() - interval '25 minutes',
  now() - interval '25 minutes'
from public.systems
cross join (
  values
    ('barracon-infanteria'),
    ('camara-comercio'),
    ('planta-fundicion'),
    ('senado')
) as capital_buildings(building_slug)
where systems.is_capital = true
on conflict (system_id, building_template_id) do update
set status = excluded.status, started_at = excluded.started_at, finishes_at = excluded.finishes_at, constructed_at = excluded.constructed_at, updated_at = now();

with preferred_resource as (
  select distinct on (systems.id)
    systems.id as system_id,
    systems.slug as system_slug,
    case capabilities.resource_key
      when 'supply' then 'granja-biologica'
      when 'minerals' then 'complejo-minero'
      when 'industrial_material' then 'planta-fundicion'
      when 'uridium' then 'refineria-iridium'
      when 'gold' then 'mina-oro'
      when 'honor' then 'senado'
    end as building_slug
  from public.systems
  join public.system_resource_capabilities capabilities on capabilities.system_id = systems.id
  where systems.status = 'controlled'
    and systems.is_capital = false
  order by systems.id,
    case capabilities.resource_key
      when 'supply' then 1
      when 'minerals' then 2
      when 'industrial_material' then 3
      when 'uridium' then 4
      when 'gold' then 5
      when 'honor' then 6
      else 99
    end
)
insert into public.system_buildings (
  id, system_id, building_template_id, status, started_at, finishes_at, constructed_at
)
select
  public.seed_uuid('system_building', system_slug || ':' || building_slug),
  system_id,
  public.seed_uuid('building_template', building_slug),
  'active',
  now() - interval '30 minutes',
  now() - interval '25 minutes',
  now() - interval '25 minutes'
from preferred_resource
where building_slug is not null
on conflict (system_id, building_template_id) do update
set status = excluded.status, started_at = excluded.started_at, finishes_at = excluded.finishes_at, constructed_at = excluded.constructed_at, updated_at = now();

select public.refresh_system_production_from_buildings();

insert into public.faction_technologies (faction_id, technology_node_id, status, unlocked_at)
select factions.id, technology_nodes.id, 'unlocked', now()
from public.factions
cross join public.technology_nodes
where technology_nodes.slug in ('doctrina-campana', 'entrenamiento-linea')
on conflict (faction_id, technology_node_id) do update
set status = excluded.status, unlocked_at = excluded.unlocked_at, started_at = null, finishes_at = null, updated_at = now();

insert into public.faction_technologies (faction_id, technology_node_id, status)
select factions.id, technology_nodes.id, 'available'
from public.factions
cross join public.technology_nodes
where technology_nodes.slug in ('logistica-frente', 'cadenas-mando', 'veteranos-guerra', 'talleres-campana', 'nodo-logistico', 'auspex-reliquias')
on conflict (faction_id, technology_node_id) do update
set status = excluded.status, started_at = null, finishes_at = null, unlocked_at = null, updated_at = now();

insert into public.technology_nodes (
  id, slug, tree_key, name, description, branch, tier, position_x, position_y, cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
)
values
  (public.seed_uuid('technology_node', 'fundacion-planetaria'), 'fundacion-planetaria', 'common-v1', 'Fundacion Planetaria', 'Protocolos basicos para levantar infraestructura estable de campana.', 'Progreso', 0, 46, 48, 0, 30, 'foundation', 'Permite construir Barracones de Infanteria y Granjas Biologicas.', true, 'active'),
  (public.seed_uuid('technology_node', 'maquinaria-belica'), 'maquinaria-belica', 'common-v1', 'Maquinaria Belica', 'Talleres, elevadores y servosistemas para fabricar y mantener vehiculos.', 'Progreso', 1, 36, 34, 1, 30, 'war_machine', 'Permite construir Talleres de Guerra.', false, 'active'),
  (public.seed_uuid('technology_node', 'criadero-guerra'), 'criadero-guerra', 'common-v1', 'Criadero de Guerra', 'Jaulas, ritos de control y habitats adaptados para criaturas de guerra.', 'Progreso', 1, 54, 34, 1, 30, 'beast', 'Permite construir Nidos de Bestias.', false, 'active'),
  (public.seed_uuid('technology_node', 'asamblea-planetaria'), 'asamblea-planetaria', 'common-v1', 'Asamblea Planetaria', 'Estructura de mando local para sostener oficiales, personajes y estados mayores.', 'Progreso', 2, 45, 22, 2, 30, 'command', 'Permite construir Cuarteles de Mando.', false, 'active'),
  (public.seed_uuid('technology_node', 'procesado-metalurgico'), 'procesado-metalurgico', 'common-v1', 'Procesado Metalurgico', 'Cadenas industriales para convertir mineral bruto en materiales de construccion.', 'Progreso', 1, 63, 50, 0, 30, 'factory', 'Permite construir Plantas de Fundicion.', false, 'active'),
  (public.seed_uuid('technology_node', 'cristalizacion-combustible-cuantico'), 'cristalizacion-combustible-cuantico', 'common-v1', 'Cristalizacion de Combustible Cuantico', 'Tecnicas de estabilizacion para refinar Iridium util en rutas de salto.', 'Progreso', 2, 73, 39, 0, 30, 'uridium', 'Permite construir Refinerias de Iridium.', false, 'active'),
  (public.seed_uuid('technology_node', 'extraccion-subterranea'), 'extraccion-subterranea', 'common-v1', 'Extraccion Subterranea', 'Sondeos profundos y maquinaria pesada para explotar vetas minerales.', 'Progreso', 2, 73, 55, 1, 30, 'mine', 'Permite construir Complejos Mineros.', false, 'active'),
  (public.seed_uuid('technology_node', 'monumentos-gloria'), 'monumentos-gloria', 'common-v1', 'Monumentos a la Gloria', 'Arquitectura ceremonial para convertir victorias y lealtad en Honor.', 'Progreso', 2, 73, 71, 1, 30, 'honor', 'Permite construir Monumentos.', false, 'active'),
  (public.seed_uuid('technology_node', 'fiebre-oro'), 'fiebre-oro', 'common-v1', 'La Fiebre del Oro', 'Prospeccion avanzada para localizar y explotar yacimientos preciosos.', 'Progreso', 3, 86, 55, 1, 30, 'gold', 'Permite construir Minas de Oro.', false, 'active'),
  (public.seed_uuid('technology_node', 'pactos-mercantiles'), 'pactos-mercantiles', 'common-v1', 'Pactos Mercantiles', 'Acuerdos y garantias para atraer camaras de comercio al frente.', 'Progreso', 4, 91, 40, 1, 30, 'commerce', 'Permite construir Camaras de Comercio.', false, 'active'),
  (public.seed_uuid('technology_node', 'contactos-economicos'), 'contactos-economicos', 'common-v1', 'Contactos Economicos', 'Red de intermediarios y agentes comerciales con acceso al mercader.', 'Progreso', 5, 96, 30, 1, 30, 'merchant', 'Permite comerciar con el Mercader.', false, 'active'),
  (public.seed_uuid('technology_node', 'tratos-preferentes'), 'tratos-preferentes', 'common-v1', 'Tratos Preferentes', 'Credenciales, favores y rutas protegidas que reducen las tasas del mercader.', 'Progreso', 6, 96, 18, 2, 30, 'trade_discount', 'Mejora precios del Mercader: compra a 1.5x y venta a 0.75x del valor.', false, 'active'),
  (public.seed_uuid('technology_node', 'mercado-galactico'), 'mercado-galactico', 'common-v1', 'Mercado Galactico', 'Acceso a tablones de oferta y rutas de intercambio entre jugadores.', 'Progreso', 5, 96, 52, 1, 30, 'market', 'Permite usar el Comercio Estelar.', false, 'active'),
  (public.seed_uuid('technology_node', 'aranceles-privilegiados'), 'aranceles-privilegiados', 'common-v1', 'Aranceles Privilegiados', 'Tratados fiscales que reducen la comision del comercio estelar.', 'Progreso', 6, 96, 64, 2, 30, 'tariff', 'Reduce tu comision de Comercio Estelar al 10%, minimo 1 oro.', false, 'active'),
  (public.seed_uuid('technology_node', 'oficina-inteligencia'), 'oficina-inteligencia', 'common-v1', 'Oficina de Inteligencia', 'Primer nucleo burocratico para futuras operaciones de espionaje.', 'Inteligencia', 1, 18, 58, 0, 30, 'intelligence', 'Proximamente: desbloqueara Nexos de Inteligencia.', false, 'planned'),
  (public.seed_uuid('technology_node', 'celulas-informacion'), 'celulas-informacion', 'common-v1', 'Celulas de Informacion', 'Redes discretas de observadores, informadores y escuchas.', 'Inteligencia', 2, 14, 70, 2, 30, 'cells', 'Proximamente: produccion de espionaje y Antenas de Reconocimiento.', false, 'planned'),
  (public.seed_uuid('technology_node', 'doctrina-clandestina'), 'doctrina-clandestina', 'common-v1', 'Doctrina Clandestina', 'Protocolos de infiltracion sostenida para operaciones encubiertas.', 'Inteligencia', 3, 8, 82, 1, 30, 'cloak', 'Proximamente: mejora de produccion de espionaje.', false, 'planned'),
  (public.seed_uuid('technology_node', 'doble-agente'), 'doble-agente', 'common-v1', 'Doble Agente', 'Contramedidas para detectar redes enemigas y operaciones infiltradas.', 'Inteligencia', 3, 18, 86, 1, 30, 'agent', 'Proximamente: probabilidad de detectar espionaje enemigo.', false, 'planned'),
  (public.seed_uuid('technology_node', 'tecnologia-sar'), 'tecnologia-sar', 'common-v1', 'Tecnologia SAR', 'Lectura de largo alcance para reconocimiento y triangulacion avanzada.', 'Inteligencia', 3, 28, 82, 1, 30, 'radar', 'Proximamente: duplicara alcance de Antenas de Reconocimiento.', false, 'planned')
on conflict (slug) do update
set tree_key = excluded.tree_key, name = excluded.name, description = excluded.description, branch = excluded.branch, tier = excluded.tier, position_x = excluded.position_x, position_y = excluded.position_y, cost_technology = excluded.cost_technology, research_time_seconds = excluded.research_time_seconds, icon_key = excluded.icon_key, effect_summary = excluded.effect_summary, is_starter = excluded.is_starter, implementation_status = excluded.implementation_status, updated_at = now();

update public.technology_nodes
set
  research_time_seconds = 30,
  implementation_status = case
    when slug in ('doctrina-campana','estado-mayor-cruzada','honores-batalla','talleres-campana','dominio-bestial','arsenal-pesado','nodo-logistico','manufactorum-local','red-suministro','puerto-uridium','auspex-reliquias','nucleos-datos','cifra-negra') then 'deprecated'
    else implementation_status
  end,
  updated_at = now()
where tree_key = 'common-v1';

update public.technology_nodes
set branch = 'Mando militar', position_x = case slug when 'entrenamiento-linea' then 22 when 'logistica-frente' then 10 when 'cadenas-mando' then 25 else position_x end, position_y = case slug when 'entrenamiento-linea' then 32 when 'logistica-frente' then 22 when 'cadenas-mando' then 18 else position_y end, implementation_status = 'active', research_time_seconds = 30, updated_at = now()
where slug in ('entrenamiento-linea', 'logistica-frente', 'cadenas-mando');

update public.technology_nodes
set branch = 'Infanteria y elite', position_x = case slug when 'veteranos-guerra' then 30 when 'especializacion-elite' then 18 else position_x end, position_y = case slug when 'veteranos-guerra' then 42 when 'especializacion-elite' then 48 else position_y end, implementation_status = 'active', research_time_seconds = 30, updated_at = now()
where slug in ('veteranos-guerra', 'especializacion-elite');

update public.technology_nodes
set branch = 'Blindados y maquinas', position_x = case slug when 'motores-guerra' then 42 when 'blindaje-reforzado' then 55 else position_x end, position_y = case slug when 'motores-guerra' then 15 when 'blindaje-reforzado' then 16 else position_y end, implementation_status = 'active', research_time_seconds = 30, updated_at = now()
where slug in ('motores-guerra', 'blindaje-reforzado');

update public.technology_nodes
set branch = 'Arqueotecnologia', position_x = 36, position_y = 62, implementation_status = 'active', research_time_seconds = 30, updated_at = now()
where slug = 'matrices-eficiencia';

delete from public.technology_prerequisites
where technology_node_id in (select id from public.technology_nodes where tree_key = 'common-v1');

insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
select tech.id, req.id, data.prerequisite_group
from (
  values
    ('maquinaria-belica', 'fundacion-planetaria', 1),
    ('criadero-guerra', 'fundacion-planetaria', 1),
    ('asamblea-planetaria', 'maquinaria-belica', 1),
    ('asamblea-planetaria', 'criadero-guerra', 1),
    ('procesado-metalurgico', 'fundacion-planetaria', 1),
    ('cristalizacion-combustible-cuantico', 'procesado-metalurgico', 1),
    ('extraccion-subterranea', 'procesado-metalurgico', 1),
    ('monumentos-gloria', 'procesado-metalurgico', 1),
    ('fiebre-oro', 'cristalizacion-combustible-cuantico', 1),
    ('fiebre-oro', 'extraccion-subterranea', 2),
    ('fiebre-oro', 'monumentos-gloria', 3),
    ('pactos-mercantiles', 'fiebre-oro', 1),
    ('contactos-economicos', 'pactos-mercantiles', 1),
    ('tratos-preferentes', 'contactos-economicos', 1),
    ('mercado-galactico', 'pactos-mercantiles', 1),
    ('aranceles-privilegiados', 'mercado-galactico', 1),
    ('celulas-informacion', 'oficina-inteligencia', 1),
    ('doctrina-clandestina', 'celulas-informacion', 1),
    ('doble-agente', 'celulas-informacion', 1),
    ('tecnologia-sar', 'celulas-informacion', 1),
    ('logistica-frente', 'entrenamiento-linea', 1),
    ('cadenas-mando', 'entrenamiento-linea', 1),
    ('veteranos-guerra', 'entrenamiento-linea', 1),
    ('especializacion-elite', 'veteranos-guerra', 1),
    ('motores-guerra', 'maquinaria-belica', 1),
    ('blindaje-reforzado', 'motores-guerra', 1),
    ('matrices-eficiencia', 'procesado-metalurgico', 1)
) as data(technology_slug, required_slug, prerequisite_group)
join public.technology_nodes tech on tech.slug = data.technology_slug
join public.technology_nodes req on req.slug = data.required_slug
on conflict (technology_node_id, required_node_id) do update
set prerequisite_group = excluded.prerequisite_group;

delete from public.technology_effects
where technology_node_id in (select id from public.technology_nodes where tree_key = 'common-v1')
  and effect_type in (
    'unlock_unit_template',
    'recruitment_cost_discount',
    'recruitment_time_discount',
    'unlock_building_template',
    'unlock_building',
    'unlock_merchant_trade',
    'merchant_rate_modifier',
    'unlock_stellar_trade',
    'stellar_trade_fee_discount'
  );

insert into public.technology_effects (id, technology_node_id, effect_type, payload)
select public.seed_uuid('technology_effect', data.effect_slug), nodes.id, data.effect_type, data.payload::jsonb
from (
  values
    ('logistica-frente-supply-infantry-v2', 'logistica-frente', 'recruitment_cost_discount', '{"category":"Infanteria","resource":"supply","percent":10}'),
    ('cadenas-mando-time-infantry-v2', 'cadenas-mando', 'recruitment_time_discount', '{"category":"Infanteria","percent":10}'),
    ('veteranos-guerra-units-v2', 'veteranos-guerra', 'unlock_unit_template', '{"unit_template_slugs":["unit-orcos-meganobz","unit-necrones-immortals","unit-necrones-skorpekh","unit-guardia-kasrkin","unit-culto-acolytes","unit-sombra-terminators","unit-muerte-plague-marines"]}'),
    ('especializacion-elite-minerals-v2', 'especializacion-elite', 'recruitment_cost_discount', '{"category":"Elite","resource":"minerals","percent":10}'),
    ('motores-guerra-units-v2', 'motores-guerra', 'unlock_unit_template', '{"unit_template_slugs":["unit-orcos-deff-dread","unit-guardia-leman-russ","unit-culto-ridgerunner","unit-sombra-redemptor","unit-muerte-bloat-drone"]}'),
    ('blindaje-reforzado-minerals-v2', 'blindaje-reforzado', 'recruitment_cost_discount', '{"category":"Vehiculo","resource":"minerals","percent":10}'),
    ('matrices-efficiency-general-v2', 'matrices-eficiencia', 'recruitment_cost_discount', '{"category":"all","resource":"all","percent":5}'),
    ('fundacion-planetaria-buildings', 'fundacion-planetaria', 'unlock_building_template', '{"building_template_slugs":["barracon-infanteria","granja-biologica"]}'),
    ('maquinaria-belica-building', 'maquinaria-belica', 'unlock_building_template', '{"building_template_slugs":["taller-guerra"]}'),
    ('criadero-guerra-building', 'criadero-guerra', 'unlock_building_template', '{"building_template_slugs":["nido-bestias"]}'),
    ('asamblea-planetaria-building', 'asamblea-planetaria', 'unlock_building_template', '{"building_template_slugs":["cuartel-mando"]}'),
    ('procesado-metalurgico-building', 'procesado-metalurgico', 'unlock_building_template', '{"building_template_slugs":["planta-fundicion"]}'),
    ('cristalizacion-building', 'cristalizacion-combustible-cuantico', 'unlock_building_template', '{"building_template_slugs":["refineria-iridium"]}'),
    ('extraccion-building', 'extraccion-subterranea', 'unlock_building_template', '{"building_template_slugs":["complejo-minero"]}'),
    ('monumentos-building', 'monumentos-gloria', 'unlock_building_template', '{"building_template_slugs":["monumento"]}'),
    ('fiebre-oro-building', 'fiebre-oro', 'unlock_building_template', '{"building_template_slugs":["mina-oro"]}'),
    ('pactos-building', 'pactos-mercantiles', 'unlock_building_template', '{"building_template_slugs":["camara-comercio"]}'),
    ('contactos-merchant', 'contactos-economicos', 'unlock_merchant_trade', '{}'),
    ('tratos-merchant-rates', 'tratos-preferentes', 'merchant_rate_modifier', '{"buy_multiplier":1.5,"sell_multiplier":0.75}'),
    ('mercado-stellar', 'mercado-galactico', 'unlock_stellar_trade', '{}'),
    ('aranceles-fee', 'aranceles-privilegiados', 'stellar_trade_fee_discount', '{"percent":10,"minimum_gold":1}')
) as data(effect_slug, technology_slug, effect_type, payload)
join public.technology_nodes nodes on nodes.slug = data.technology_slug
on conflict (id) do update
set technology_node_id = excluded.technology_node_id, effect_type = excluded.effect_type, payload = excluded.payload;

update public.building_templates
set slug = 'monumento'
where slug = 'senado'
  and not exists (select 1 from public.building_templates existing where existing.slug = 'monumento');

insert into public.building_templates (
  id, slug, name, description, category, building_kind, supply_cost, minerals_cost, honor_cost, gold_cost, industrial_material_cost, uridium_cost, technology_cost, construction_time_seconds, produced_resource_key, produced_amount, allowed_unit_categories, required_technology_node_id, icon_key, is_available
)
values
  (coalesce((select id from public.building_templates where slug = 'barracon-infanteria'), public.seed_uuid('building_template', 'barracon-infanteria')), 'barracon-infanteria', 'Barracon de Infanteria', 'Centro de instruccion para tropas de linea y cuadros veteranos.', 'Reclutamiento', 'recruitment', 12, 8, 0, 0, 4, 0, 0, 240, null, 0, array['Infanteria','Elite']::text[], public.seed_uuid('technology_node', 'fundacion-planetaria'), 'infantry_barracks', true),
  (coalesce((select id from public.building_templates where slug = 'cuartel-mando'), public.seed_uuid('building_template', 'cuartel-mando')), 'cuartel-mando', 'Cuartel de Mando', 'Instalacion de oficiales, heroes y personajes de mando.', 'Reclutamiento', 'recruitment', 10, 10, 1, 0, 6, 0, 0, 300, null, 0, array['Personaje']::text[], public.seed_uuid('technology_node', 'asamblea-planetaria'), 'command_quarters', true),
  (coalesce((select id from public.building_templates where slug = 'taller-guerra'), public.seed_uuid('building_template', 'taller-guerra')), 'taller-guerra', 'Taller de Guerra', 'Bahias de reparacion y ensamblaje de vehiculos.', 'Reclutamiento', 'recruitment', 6, 16, 0, 0, 8, 0, 0, 300, null, 0, array['Vehiculo']::text[], public.seed_uuid('technology_node', 'maquinaria-belica'), 'war_workshop', true),
  (coalesce((select id from public.building_templates where slug = 'nido-bestias'), public.seed_uuid('building_template', 'nido-bestias')), 'nido-bestias', 'Nido de Bestias', 'Jaulas y rituales de control para monstruos de guerra.', 'Reclutamiento', 'recruitment', 14, 8, 1, 0, 6, 0, 0, 300, null, 0, array['Monstruo']::text[], public.seed_uuid('technology_node', 'criadero-guerra'), 'beast_lair', true),
  (coalesce((select id from public.building_templates where slug = 'camara-comercio'), public.seed_uuid('building_template', 'camara-comercio')), 'camara-comercio', 'Camara de Comercio', 'Mercado orbital y punto de contacto con rutas mercantes.', 'Comercio', 'commerce', 8, 8, 0, 1, 4, 0, 0, 240, null, 0, array[]::text[], public.seed_uuid('technology_node', 'pactos-mercantiles'), 'commerce', true),
  (coalesce((select id from public.building_templates where slug = 'nexo-inteligencia'), public.seed_uuid('building_template', 'nexo-inteligencia')), 'nexo-inteligencia', 'Nexo de Inteligencia', 'Centro de analisis para operaciones de espionaje futuras.', 'Inteligencia', 'intelligence', 6, 12, 1, 0, 6, 0, 0, 300, null, 0, array[]::text[], public.seed_uuid('technology_node', 'oficina-inteligencia'), 'intelligence', true),
  (coalesce((select id from public.building_templates where slug = 'antenas-reconocimiento'), public.seed_uuid('building_template', 'antenas-reconocimiento')), 'antenas-reconocimiento', 'Antenas de Reconocimiento', 'Matrices de escucha y auspex de largo alcance.', 'Inteligencia', 'intelligence', 4, 8, 0, 0, 5, 2, 0, 240, null, 0, array[]::text[], public.seed_uuid('technology_node', 'celulas-informacion'), 'recon', true),
  (coalesce((select id from public.building_templates where slug = 'granja-biologica'), public.seed_uuid('building_template', 'granja-biologica')), 'granja-biologica', 'Granja Biologica', 'Complejos de biomasa y cultivos adaptados al frente.', 'Produccion', 'production', 4, 4, 0, 0, 3, 0, 0, 180, 'supply', 10, array[]::text[], public.seed_uuid('technology_node', 'fundacion-planetaria'), 'biofarm', true),
  (coalesce((select id from public.building_templates where slug = 'complejo-minero'), public.seed_uuid('building_template', 'complejo-minero')), 'complejo-minero', 'Complejo Minero', 'Pozos, excavadoras y refinerias de mineral bruto.', 'Produccion', 'production', 4, 6, 0, 0, 4, 0, 0, 180, 'minerals', 6, array[]::text[], public.seed_uuid('technology_node', 'extraccion-subterranea'), 'mine', true),
  (coalesce((select id from public.building_templates where slug = 'refineria-iridium'), public.seed_uuid('building_template', 'refineria-iridium')), 'refineria-iridium', 'Refineria de Iridium', 'Planta especializada para estabilizar cristales de salto.', 'Produccion', 'production', 4, 8, 0, 0, 5, 0, 0, 240, 'uridium', 4, array[]::text[], public.seed_uuid('technology_node', 'cristalizacion-combustible-cuantico'), 'iridium_refinery', true),
  (coalesce((select id from public.building_templates where slug = 'mina-oro'), public.seed_uuid('building_template', 'mina-oro')), 'mina-oro', 'Mina de Oro', 'Extraccion de metales preciosos para rutas comerciales.', 'Produccion', 'production', 4, 8, 0, 0, 5, 0, 0, 240, 'gold', 3, array[]::text[], public.seed_uuid('technology_node', 'fiebre-oro'), 'gold_mine', true),
  (coalesce((select id from public.building_templates where slug = 'planta-fundicion'), public.seed_uuid('building_template', 'planta-fundicion')), 'planta-fundicion', 'Planta de Fundicion', 'Produce Material Industrial para nuevas construcciones.', 'Produccion', 'production', 4, 10, 0, 0, 3, 0, 0, 240, 'industrial_material', 5, array[]::text[], public.seed_uuid('technology_node', 'procesado-metalurgico'), 'foundry', true),
  (coalesce((select id from public.building_templates where slug = 'monumento'), public.seed_uuid('building_template', 'monumento')), 'monumento', 'Monumento', 'Estructura ceremonial que transforma gloria local en Honor.', 'Produccion', 'production', 8, 8, 0, 1, 5, 0, 0, 300, 'honor', 2, array[]::text[], public.seed_uuid('technology_node', 'monumentos-gloria'), 'monument', true)
on conflict (slug) do update
set name = excluded.name, description = excluded.description, category = excluded.category, building_kind = excluded.building_kind, supply_cost = excluded.supply_cost, minerals_cost = excluded.minerals_cost, honor_cost = excluded.honor_cost, gold_cost = excluded.gold_cost, industrial_material_cost = excluded.industrial_material_cost, uridium_cost = excluded.uridium_cost, technology_cost = excluded.technology_cost, construction_time_seconds = excluded.construction_time_seconds, produced_resource_key = excluded.produced_resource_key, produced_amount = excluded.produced_amount, allowed_unit_categories = excluded.allowed_unit_categories, required_technology_node_id = excluded.required_technology_node_id, icon_key = excluded.icon_key, is_available = excluded.is_available, updated_at = now();

update public.system_buildings
set building_template_id = (select id from public.building_templates where slug = 'monumento')
where building_template_id in (select id from public.building_templates where slug = 'senado')
  and exists (select 1 from public.building_templates where slug = 'monumento');

delete from public.building_templates
where slug in ('senado', 'nodo-logistico', 'bastion-mando', 'manufactorum-local');

delete from public.faction_technologies progress
using public.technology_nodes nodes
where progress.technology_node_id = nodes.id
  and nodes.tree_key = 'common-v1'
  and (progress.status = 'available' or nodes.implementation_status in ('deprecated', 'planned'));

insert into public.faction_technologies (faction_id, technology_node_id, status, unlocked_at)
select factions.id, nodes.id, 'unlocked', now()
from public.factions
cross join public.technology_nodes nodes
where nodes.slug in ('fundacion-planetaria', 'entrenamiento-linea')
on conflict (faction_id, technology_node_id) do update
set status = excluded.status, unlocked_at = excluded.unlocked_at, started_at = null, finishes_at = null, updated_at = now();

do $$
declare
  v_faction_id uuid;
begin
  for v_faction_id in select id from public.factions loop
    perform public.refresh_available_technologies(v_faction_id);
  end loop;
end;
$$;

select public.refresh_system_production_from_buildings();

insert into public.unit_templates (
  id, slug, faction_id, name, category, points, default_quantity, supply_cost, minerals_cost, ancestral_stone_cost, gold_cost, uridium_cost, technology_cost, recruitment_time_seconds, notes, is_available, required_technology_node_id
)
values
  (public.seed_uuid('unit_template', 'unit-orcos-boyz'), 'unit-orcos-boyz', public.seed_uuid('faction', 'orcos'), 'Boyz', 'Infanteria', 80, 10, 12, 2, 0, 0, 0, 0, 120, 'Masa brutal de combate cercano.', true, null),
  (public.seed_uuid('unit_template', 'unit-orcos-meganobz'), 'unit-orcos-meganobz', public.seed_uuid('faction', 'orcos'), 'Meganobz', 'Elite', 105, 3, 6, 5, 1, 1, 0, 0, 240, 'Noblez armados con servoarmaduras improvisadas.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-orcos-deff-dread'), 'unit-orcos-deff-dread', public.seed_uuid('faction', 'orcos'), 'Deff Dread', 'Vehiculo', 135, 1, 2, 10, 1, 0, 0, 0, 360, 'Maquina andante de metal, humo y mala intencion.', true, public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('unit_template', 'unit-necrones-warriors'), 'unit-necrones-warriors', public.seed_uuid('faction', 'necrones'), 'Necron Warriors', 'Infanteria', 80, 10, 8, 4, 0, 0, 0, 0, 120, 'Linea inmortal reanimada desde las criptas.', true, null),
  (public.seed_uuid('unit_template', 'unit-necrones-immortals'), 'unit-necrones-immortals', public.seed_uuid('faction', 'necrones'), 'Immortals', 'Elite', 105, 5, 6, 5, 1, 0, 0, 0, 240, 'Guerreros superiores con protocolos de elite.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-necrones-skorpekh'), 'unit-necrones-skorpekh', public.seed_uuid('faction', 'necrones'), 'Skorpekh Destroyers', 'Elite', 140, 3, 4, 7, 2, 1, 0, 0, 360, 'Asesinos de fase con cuerpos disenados para la destruccion.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-guardia-cadian'), 'unit-guardia-cadian', public.seed_uuid('faction', 'guardia-imperial'), 'Cadian Shock Troops', 'Infanteria', 80, 10, 12, 2, 0, 0, 0, 0, 120, 'Infanteria disciplinada lista para sostener la linea.', true, null),
  (public.seed_uuid('unit_template', 'unit-guardia-kasrkin'), 'unit-guardia-kasrkin', public.seed_uuid('faction', 'guardia-imperial'), 'Kasrkin', 'Elite', 105, 10, 8, 4, 1, 1, 0, 0, 240, 'Veteranos de asalto con equipo especializado.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-guardia-leman-russ'), 'unit-guardia-leman-russ', public.seed_uuid('faction', 'guardia-imperial'), 'Leman Russ Battle Tank', 'Vehiculo', 145, 1, 2, 11, 1, 0, 0, 0, 420, 'Blindado pesado de batalla para romper frentes.', true, public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('unit_template', 'unit-culto-neophytes'), 'unit-culto-neophytes', public.seed_uuid('faction', 'culto-genestelar'), 'Neophyte Hybrids', 'Infanteria', 80, 10, 12, 2, 0, 0, 0, 0, 120, 'Celulas insurgentes armadas desde las profundidades.', true, null),
  (public.seed_uuid('unit_template', 'unit-culto-acolytes'), 'unit-culto-acolytes', public.seed_uuid('faction', 'culto-genestelar'), 'Acolyte Hybrids', 'Elite', 95, 5, 8, 3, 1, 0, 0, 0, 240, 'Fanaticos hibridos preparados para ataques decisivos.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-culto-ridgerunner'), 'unit-culto-ridgerunner', public.seed_uuid('faction', 'culto-genestelar'), 'Achilles Ridgerunner', 'Vehiculo', 120, 1, 3, 8, 1, 0, 0, 0, 360, 'Vehiculo de incursion y reconocimiento rapido.', true, public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('unit_template', 'unit-sombra-intercessors'), 'unit-sombra-intercessors', public.seed_uuid('faction', 'sombra-emperador'), 'Intercessor Squad', 'Infanteria', 105, 5, 8, 4, 1, 0, 0, 0, 180, 'Astartes de linea con doctrina flexible.', true, null),
  (public.seed_uuid('unit_template', 'unit-sombra-terminators'), 'unit-sombra-terminators', public.seed_uuid('faction', 'sombra-emperador'), 'Terminator Squad', 'Elite', 160, 5, 5, 6, 3, 2, 0, 0, 360, 'Veteranos con armadura tactica dreadnought.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-sombra-redemptor'), 'unit-sombra-redemptor', public.seed_uuid('faction', 'sombra-emperador'), 'Redemptor Dreadnought', 'Vehiculo', 185, 1, 2, 10, 3, 0, 0, 0, 480, 'Dreadnought pesado para rupturas de linea.', true, public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('unit_template', 'unit-muerte-poxwalkers'), 'unit-muerte-poxwalkers', public.seed_uuid('faction', 'guardia-muerte'), 'Poxwalkers', 'Infanteria', 70, 10, 12, 1, 0, 0, 0, 0, 120, 'Multitud infectada que avanza sin miedo.', true, null),
  (public.seed_uuid('unit_template', 'unit-muerte-plague-marines'), 'unit-muerte-plague-marines', public.seed_uuid('faction', 'guardia-muerte'), 'Plague Marines', 'Infanteria', 115, 7, 8, 5, 1, 1, 0, 0, 240, 'Marines de plaga resistentes y metodicos.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-muerte-bloat-drone'), 'unit-muerte-bloat-drone', public.seed_uuid('faction', 'guardia-muerte'), 'Foetid Bloat-drone', 'Vehiculo', 145, 1, 3, 8, 2, 0, 0, 0, 420, 'Dron demoniaco de apoyo y hostigamiento.', true, public.seed_uuid('technology_node', 'motores-guerra'))
on conflict (slug) do update
set faction_id = excluded.faction_id, name = excluded.name, category = excluded.category, points = excluded.points, default_quantity = excluded.default_quantity, supply_cost = excluded.supply_cost, minerals_cost = excluded.minerals_cost, ancestral_stone_cost = excluded.ancestral_stone_cost, gold_cost = excluded.gold_cost, uridium_cost = excluded.uridium_cost, technology_cost = excluded.technology_cost, recruitment_time_seconds = excluded.recruitment_time_seconds, notes = excluded.notes, is_available = excluded.is_available, required_technology_node_id = excluded.required_technology_node_id;

update public.unit_templates
set
  honor_cost = ancestral_stone_cost,
  industrial_material_cost = 0,
  wounds_per_model = case slug
    when 'unit-orcos-boyz' then 1
    when 'unit-orcos-meganobz' then 3
    when 'unit-orcos-deff-dread' then 8
    when 'unit-necrones-warriors' then 1
    when 'unit-necrones-immortals' then 1
    when 'unit-necrones-skorpekh' then 3
    when 'unit-guardia-cadian' then 1
    when 'unit-guardia-kasrkin' then 1
    when 'unit-guardia-leman-russ' then 13
    when 'unit-culto-neophytes' then 1
    when 'unit-culto-acolytes' then 1
    when 'unit-culto-ridgerunner' then 8
    when 'unit-sombra-intercessors' then 2
    when 'unit-sombra-terminators' then 3
    when 'unit-sombra-redemptor' then 12
    when 'unit-muerte-poxwalkers' then 1
    when 'unit-muerte-plague-marines' then 2
    when 'unit-muerte-bloat-drone' then 10
    else wounds_per_model
  end,
  recruitment_building_type = case
    when category = 'Vehiculo' then 'taller-guerra'
    when category = 'Personaje' then 'cuartel-mando'
    when category = 'Monstruo' then 'nido-bestias'
    else 'barracon-infanteria'
  end;

insert into public.campaign_units (
  id, slug, faction_id, unit_template_id, name, category, points, quantity, starting_quantity, experience, rank, enhancement_text, current_system_id, status, is_visible_publicly
)
values
  (public.seed_uuid('campaign_unit', 'imperial-kharon-cadians'), 'imperial-kharon-cadians', public.seed_uuid('faction', 'guardia-imperial'), public.seed_uuid('unit_template', 'unit-guardia-cadian'), 'Cadian Shock Troops', 'Infanteria', 80, 10, 10, 1, 'Linea', null, public.seed_uuid('system', 'kharon-prime'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'imperial-arx-kasrkin'), 'imperial-arx-kasrkin', public.seed_uuid('faction', 'guardia-imperial'), public.seed_uuid('unit_template', 'unit-guardia-kasrkin'), 'Kasrkin', 'Elite', 105, 10, 10, 2, 'Veteranos', 'Doctrina de frontera', public.seed_uuid('system', 'arx-solum'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'imperial-helios-leman'), 'imperial-helios-leman', public.seed_uuid('faction', 'guardia-imperial'), public.seed_uuid('unit_template', 'unit-guardia-leman-russ'), 'Leman Russ Battle Tank', 'Vehiculo', 145, 1, 1, 0, 'Blindado', null, public.seed_uuid('system', 'kharon-prime'), 'moving', false),
  (public.seed_uuid('campaign_unit', 'imperial-azur-cadians'), 'imperial-azur-cadians', public.seed_uuid('faction', 'guardia-imperial'), public.seed_uuid('unit_template', 'unit-guardia-cadian'), 'Cadian Shock Troops', 'Infanteria', 80, 10, 10, 1, 'Linea de Azur', null, public.seed_uuid('system', 'azur-trench'), 'in_war', false),
  (public.seed_uuid('campaign_unit', 'ork-cinder-boyz'), 'ork-cinder-boyz', public.seed_uuid('faction', 'orcos'), public.seed_uuid('unit_template', 'unit-orcos-boyz'), 'Boyz', 'Infanteria', 80, 10, 10, 1, 'Marea', null, public.seed_uuid('system', 'cinder-maw'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'ork-rustmaw-meganobz'), 'ork-rustmaw-meganobz', public.seed_uuid('faction', 'orcos'), public.seed_uuid('unit_template', 'unit-orcos-meganobz'), 'Meganobz', 'Elite', 105, 3, 3, 2, 'Noblez', 'Armaduras remachadas', public.seed_uuid('system', 'rustmaw-run'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'ork-eclipse-dread'), 'ork-eclipse-dread', public.seed_uuid('faction', 'orcos'), public.seed_uuid('unit_template', 'unit-orcos-deff-dread'), 'Deff Dread', 'Vehiculo', 135, 1, 1, 0, 'Chatarrero', null, public.seed_uuid('system', 'cinder-maw'), 'moving', false),
  (public.seed_uuid('campaign_unit', 'ork-azur-boyz'), 'ork-azur-boyz', public.seed_uuid('faction', 'orcos'), public.seed_uuid('unit_template', 'unit-orcos-boyz'), 'Boyz', 'Infanteria', 80, 10, 10, 1, 'Waaagh', null, public.seed_uuid('system', 'azur-trench'), 'in_war', false),
  (public.seed_uuid('campaign_unit', 'sombra-gate-intercessors'), 'sombra-gate-intercessors', public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('unit_template', 'unit-sombra-intercessors'), 'Intercessor Squad', 'Infanteria', 105, 5, 5, 1, 'Linea', null, public.seed_uuid('system', 'sa-cea-gate'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'sombra-narthex-terminators'), 'sombra-narthex-terminators', public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('unit_template', 'unit-sombra-terminators'), 'Terminator Squad', 'Elite', 160, 5, 5, 2, 'Veteranos', 'Juramento del santuario', public.seed_uuid('system', 'narthex'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'sombra-lyra-redemptor'), 'sombra-lyra-redemptor', public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('unit_template', 'unit-sombra-redemptor'), 'Redemptor Dreadnought', 'Vehiculo', 185, 1, 1, 0, 'Anciano', null, public.seed_uuid('system', 'sa-cea-gate'), 'moving', false),
  (public.seed_uuid('campaign_unit', 'sombra-saint-intercessors'), 'sombra-saint-intercessors', public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('unit_template', 'unit-sombra-intercessors'), 'Intercessor Squad', 'Infanteria', 105, 5, 5, 1, 'Purga del Velo', null, public.seed_uuid('system', 'saint-veil'), 'in_war', false),
  (public.seed_uuid('campaign_unit', 'cult-blackglass-neophytes'), 'cult-blackglass-neophytes', public.seed_uuid('faction', 'culto-genestelar'), public.seed_uuid('unit_template', 'unit-culto-neophytes'), 'Neophyte Hybrids', 'Infanteria', 80, 10, 10, 1, 'Celula', null, public.seed_uuid('system', 'blackglass'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'cult-mirrorcoil-acolytes'), 'cult-mirrorcoil-acolytes', public.seed_uuid('faction', 'culto-genestelar'), public.seed_uuid('unit_template', 'unit-culto-acolytes'), 'Acolyte Hybrids', 'Elite', 95, 5, 5, 2, 'Alzados', 'Red de tuneles', public.seed_uuid('system', 'mirrorcoil'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'cult-sabbath-ridgerunner'), 'cult-sabbath-ridgerunner', public.seed_uuid('faction', 'culto-genestelar'), public.seed_uuid('unit_template', 'unit-culto-ridgerunner'), 'Achilles Ridgerunner', 'Vehiculo', 120, 1, 1, 0, 'Movil', null, public.seed_uuid('system', 'blackglass'), 'moving', false),
  (public.seed_uuid('campaign_unit', 'cult-saint-neophytes'), 'cult-saint-neophytes', public.seed_uuid('faction', 'culto-genestelar'), public.seed_uuid('unit_template', 'unit-culto-neophytes'), 'Neophyte Hybrids', 'Infanteria', 80, 10, 10, 1, 'Insurgentes', null, public.seed_uuid('system', 'saint-veil'), 'in_war', false),
  (public.seed_uuid('campaign_unit', 'necron-thokt-warriors'), 'necron-thokt-warriors', public.seed_uuid('faction', 'necrones'), public.seed_uuid('unit_template', 'unit-necrones-warriors'), 'Necron Warriors', 'Infanteria', 80, 10, 10, 1, 'Linea', null, public.seed_uuid('system', 'thokt-vault'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'necron-ghostlight-skorpekh'), 'necron-ghostlight-skorpekh', public.seed_uuid('faction', 'necrones'), public.seed_uuid('unit_template', 'unit-necrones-skorpekh'), 'Skorpekh Destroyers', 'Elite', 140, 3, 3, 2, 'Destructores', 'Protocolos de cosecha', public.seed_uuid('system', 'ghostlight'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'necron-novem-immortals'), 'necron-novem-immortals', public.seed_uuid('faction', 'necrones'), public.seed_uuid('unit_template', 'unit-necrones-immortals'), 'Immortals', 'Elite', 105, 5, 5, 0, 'Escolta', null, public.seed_uuid('system', 'thokt-vault'), 'moving', false),
  (public.seed_uuid('campaign_unit', 'necron-ossuary-warriors'), 'necron-ossuary-warriors', public.seed_uuid('faction', 'necrones'), public.seed_uuid('unit_template', 'unit-necrones-warriors'), 'Necron Warriors', 'Infanteria', 80, 10, 10, 1, 'Reclamadores', null, public.seed_uuid('system', 'ossuary-reach'), 'in_war', false),
  (public.seed_uuid('campaign_unit', 'death-mordax-poxwalkers'), 'death-mordax-poxwalkers', public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('unit_template', 'unit-muerte-poxwalkers'), 'Poxwalkers', 'Infanteria', 70, 10, 10, 1, 'Marea', null, public.seed_uuid('system', 'mordax'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'death-plaguefall-marines'), 'death-plaguefall-marines', public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('unit_template', 'unit-muerte-plague-marines'), 'Plague Marines', 'Infanteria', 115, 7, 7, 2, 'Veteranos', 'Nube toxica', public.seed_uuid('system', 'plaguefall-bastion'), 'ready', false),
  (public.seed_uuid('campaign_unit', 'death-drusus-drone'), 'death-drusus-drone', public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('unit_template', 'unit-muerte-bloat-drone'), 'Foetid Bloat-drone', 'Vehiculo', 145, 1, 1, 0, 'Movil', null, public.seed_uuid('system', 'mordax'), 'moving', false),
  (public.seed_uuid('campaign_unit', 'death-ossuary-marines'), 'death-ossuary-marines', public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('unit_template', 'unit-muerte-plague-marines'), 'Plague Marines', 'Infanteria', 115, 7, 7, 1, 'Plaga', null, public.seed_uuid('system', 'ossuary-reach'), 'in_war', false)
on conflict (slug) do update
set faction_id = excluded.faction_id, unit_template_id = excluded.unit_template_id, name = excluded.name, category = excluded.category, points = excluded.points, quantity = excluded.quantity, starting_quantity = excluded.starting_quantity, experience = excluded.experience, rank = excluded.rank, enhancement_text = excluded.enhancement_text, current_system_id = excluded.current_system_id, status = excluded.status, is_visible_publicly = excluded.is_visible_publicly, updated_at = now();

update public.campaign_units
set wounds_taken = 0;

update public.campaign_units
set quantity = 7, wounds_taken = 2
where slug = 'imperial-kharon-cadians';

insert into public.movement_orders (
  id, faction_id, from_system_id, to_system_id, uridium_cost, started_at, arrival_at, status, path_system_ids, segment_count, duration_seconds
)
values
  (public.seed_uuid('movement_order', 'move-imperial-helios'), public.seed_uuid('faction', 'guardia-imperial'), public.seed_uuid('system', 'kharon-prime'), public.seed_uuid('system', 'helios-drift'), 1, now() - interval '30 seconds', now() + interval '90 seconds', 'moving', array[public.seed_uuid('system', 'kharon-prime'), public.seed_uuid('system', 'helios-drift')]::uuid[], 1, 120),
  (public.seed_uuid('movement_order', 'move-ork-eclipse'), public.seed_uuid('faction', 'orcos'), public.seed_uuid('system', 'cinder-maw'), public.seed_uuid('system', 'eclipse-forge'), 1, now() - interval '30 seconds', now() + interval '90 seconds', 'moving', array[public.seed_uuid('system', 'cinder-maw'), public.seed_uuid('system', 'eclipse-forge')]::uuid[], 1, 120),
  (public.seed_uuid('movement_order', 'move-sombra-lyra'), public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('system', 'sa-cea-gate'), public.seed_uuid('system', 'lyra-terminus'), 1, now() - interval '30 seconds', now() + interval '90 seconds', 'moving', array[public.seed_uuid('system', 'sa-cea-gate'), public.seed_uuid('system', 'lyra-terminus')]::uuid[], 1, 120),
  (public.seed_uuid('movement_order', 'move-cult-sabbath'), public.seed_uuid('faction', 'culto-genestelar'), public.seed_uuid('system', 'blackglass'), public.seed_uuid('system', 'red-sabbath'), 1, now() - interval '30 seconds', now() + interval '90 seconds', 'moving', array[public.seed_uuid('system', 'blackglass'), public.seed_uuid('system', 'red-sabbath')]::uuid[], 1, 120),
  (public.seed_uuid('movement_order', 'move-necron-novem'), public.seed_uuid('faction', 'necrones'), public.seed_uuid('system', 'thokt-vault'), public.seed_uuid('system', 'novem'), 1, now() - interval '30 seconds', now() + interval '90 seconds', 'moving', array[public.seed_uuid('system', 'thokt-vault'), public.seed_uuid('system', 'novem')]::uuid[], 1, 120),
  (public.seed_uuid('movement_order', 'move-death-drusus'), public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('system', 'mordax'), public.seed_uuid('system', 'drusus'), 1, now() - interval '30 seconds', now() + interval '90 seconds', 'moving', array[public.seed_uuid('system', 'mordax'), public.seed_uuid('system', 'drusus')]::uuid[], 1, 120)
on conflict (id) do update
set faction_id = excluded.faction_id, from_system_id = excluded.from_system_id, to_system_id = excluded.to_system_id, uridium_cost = excluded.uridium_cost, started_at = excluded.started_at, arrival_at = excluded.arrival_at, status = excluded.status, path_system_ids = excluded.path_system_ids, segment_count = excluded.segment_count, duration_seconds = excluded.duration_seconds;

insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
values
  (public.seed_uuid('movement_order', 'move-imperial-helios'), public.seed_uuid('campaign_unit', 'imperial-helios-leman'), 1),
  (public.seed_uuid('movement_order', 'move-ork-eclipse'), public.seed_uuid('campaign_unit', 'ork-eclipse-dread'), 1),
  (public.seed_uuid('movement_order', 'move-sombra-lyra'), public.seed_uuid('campaign_unit', 'sombra-lyra-redemptor'), 1),
  (public.seed_uuid('movement_order', 'move-cult-sabbath'), public.seed_uuid('campaign_unit', 'cult-sabbath-ridgerunner'), 1),
  (public.seed_uuid('movement_order', 'move-necron-novem'), public.seed_uuid('campaign_unit', 'necron-novem-immortals'), 5),
  (public.seed_uuid('movement_order', 'move-death-drusus'), public.seed_uuid('campaign_unit', 'death-drusus-drone'), 1)
on conflict (movement_order_id, unit_id) do update
set quantity_at_departure = excluded.quantity_at_departure;

insert into public.trade_offers (
  id, creator_faction_id, offer_type, resource_key, resource_amount, gold_amount, fee_gold, status, is_reserved, created_at, updated_at
)
values
  (public.seed_uuid('trade_offer', 'imperial-sell-minerals'), public.seed_uuid('faction', 'guardia-imperial'), 'sell', 'minerals', 15, 8, 3, 'open', true, now() - interval '8 minutes', now() - interval '8 minutes'),
  (public.seed_uuid('trade_offer', 'orcos-buy-supply'), public.seed_uuid('faction', 'orcos'), 'buy', 'supply', 20, 5, 2, 'open', true, now() - interval '4 minutes', now() - interval '4 minutes')
on conflict (id) do update
set
  creator_faction_id = excluded.creator_faction_id,
  offer_type = excluded.offer_type,
  resource_key = excluded.resource_key,
  resource_amount = excluded.resource_amount,
  gold_amount = excluded.gold_amount,
  fee_gold = excluded.fee_gold,
  status = excluded.status,
  is_reserved = excluded.is_reserved,
  accepted_by_faction_id = null,
  accepted_at = null,
  cancelled_at = null,
  updated_at = excluded.updated_at;

update public.faction_resources
set minerals = greatest(0, minerals - 15), gold = greatest(0, gold - 3)
where faction_id = public.seed_uuid('faction', 'guardia-imperial');

update public.faction_resources
set gold = greatest(0, gold - 7)
where faction_id = public.seed_uuid('faction', 'orcos');

insert into public.conflicts (id, slug, system_id, attacker_faction_id, defender_faction_id, status, blocked_until, notes)
values
  (public.seed_uuid('conflict', 'conflict-azur-trench'), 'conflict-azur-trench', public.seed_uuid('system', 'azur-trench'), public.seed_uuid('faction', 'orcos'), public.seed_uuid('faction', 'guardia-imperial'), 'pending', now() + interval '14 days', 'Orcos e Imperiales han colisionado en la ruta central de la Zanja Azul. Pendiente de batalla fisica.'),
  (public.seed_uuid('conflict', 'conflict-ossuary-reach'), 'conflict-ossuary-reach', public.seed_uuid('system', 'ossuary-reach'), public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('faction', 'necrones'), 'pending', now() + interval '14 days', 'La Guardia de la Muerte intenta profanar criptas que los Necrones estan reactivando. Pendiente de batalla fisica.'),
  (public.seed_uuid('conflict', 'conflict-saint-veil'), 'conflict-saint-veil', public.seed_uuid('system', 'saint-veil'), public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('faction', 'culto-genestelar'), 'pending', now() + interval '14 days', 'La Sombra del Emperador ha descubierto una insurreccion genestelar en el santuario. Pendiente de batalla fisica.')
on conflict (slug) do update
set system_id = excluded.system_id, attacker_faction_id = excluded.attacker_faction_id, defender_faction_id = excluded.defender_faction_id, status = excluded.status, winner_faction_id = null, blocked_until = excluded.blocked_until, notes = excluded.notes, resolved_at = null;

insert into public.missions (id, system_id, title, narrative_description, recommended_points, objectives, special_rules, victory_conditions)
values
  (public.seed_uuid('mission', 'mission-azur-trench'), public.seed_uuid('system', 'azur-trench'), 'La Zanja Azul', 'Una nebulosa de gases ionizados parte el campo de batalla en corredores estrechos.', '1000-1500 pts', 'Controlar las balizas de navegacion al final de la batalla fisica.', 'Las unidades que avancen por el centro cuentan como expuestas por la luz azul.', 'El ganador decide el control final de Azur Trench.'),
  (public.seed_uuid('mission', 'mission-ossuary-reach'), public.seed_uuid('system', 'ossuary-reach'), 'Ecos del Osario', 'Criptas rotas y fosas contaminadas hacen que cada metro sea una amenaza.', '1000-1500 pts', 'Asegurar tres criptas antes del final de la partida.', 'El terreno central se considera peligroso por emanaciones toxicas y energia necrodermis.', 'El ganador decide el control final de Ossuary Reach.'),
  (public.seed_uuid('mission', 'mission-saint-veil'), public.seed_uuid('system', 'saint-veil'), 'El Velo Sagrado', 'Un santuario en sombra se convierte en campo de purga e insurreccion.', '1000-1500 pts', 'Mantener el altar central y dos accesos laterales.', 'La primera ronda usa visibilidad reducida por incienso, humo y apagones.', 'El ganador decide el control final de Saint Veil.')
on conflict (id) do update
set system_id = excluded.system_id, title = excluded.title, narrative_description = excluded.narrative_description, recommended_points = excluded.recommended_points, objectives = excluded.objectives, special_rules = excluded.special_rules, victory_conditions = excluded.victory_conditions, updated_at = now();

insert into public.system_special_objects (id, system_id, name, type, public_description, is_public)
values
  (public.seed_uuid('system_special_object', 'obj-nexus-aster'), public.seed_uuid('system', 'nexus-aster'), 'Baliza del Nexus', 'technology', 'Lecturas verdes y doradas en el nodo central.', true),
  (public.seed_uuid('system_special_object', 'obj-saint-veil'), public.seed_uuid('system', 'saint-veil'), 'Reliquia velada', 'relic', 'Un relicario emite pulsos violetas bajo el santuario.', true),
  (public.seed_uuid('system_special_object', 'obj-ossuary-reach'), public.seed_uuid('system', 'ossuary-reach'), 'Cripta fracturada', 'anomaly', 'Senales intermitentes salen de tumbas orbitales abiertas.', true)
on conflict (id) do update
set system_id = excluded.system_id, name = excluded.name, type = excluded.type, public_description = excluded.public_description, is_public = excluded.is_public;

update public.campaign_settings
set
  resource_tick_interval_hours = 24,
  movement_edge_duration_seconds = 120,
  conflict_block_duration_minutes = 20160,
  next_resource_tick_at = now() + interval '24 hours',
  updated_at = now()
where id = 'default';
