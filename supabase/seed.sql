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
  (public.seed_uuid('faction', 'legiones-daemonicas'), 'legiones-daemonicas', 'Legiones Daemonicas', '#ef4444'),
  (public.seed_uuid('faction', 'agentes-imperium'), 'agentes-imperium', 'Agentes del Imperium', '#f59e0b'),
  (public.seed_uuid('faction', 'cultos-genestealer'), 'cultos-genestealer', 'Cultos Genestealer', '#c084fc'),
  (public.seed_uuid('faction', 'aeldari'), 'aeldari', 'Aeldari', '#fb7185'),
  (public.seed_uuid('faction', 'space-marines'), 'space-marines', 'Space Marines', '#facc15'),
  (public.seed_uuid('faction', 'adeptus-custodes'), 'adeptus-custodes', 'Adeptus Custodes', '#d4af37'),
  (public.seed_uuid('faction', 'necrones'), 'necrones', 'Necrones', '#2dd4bf')
on conflict (slug) do update
set name = excluded.name, color = excluded.color;

insert into public.systems (
  id, slug, name, x, y, size, star_class, type, status, controller_faction_id, blocked_until, public_description, is_capital
)
values
  (public.seed_uuid('system', 'kharon-prime'), 'kharon-prime', 'Kharon Prime', 90, 170, 1.2, 'blue', 'Capital fortificada', 'controlled', public.seed_uuid('faction', 'adeptus-custodes'), null, 'Bastion aurico y astropuerto militar custodiado por los guardianes del Trono.', true),
  (public.seed_uuid('system', 'helios-drift'), 'helios-drift', 'Helios Drift', 215, 190, 0.9, 'orange', 'Cinturon minero', 'controlled', public.seed_uuid('faction', 'adeptus-custodes'), null, 'Asteroides ricos en mineral defendidos por baterias orbitales custodes.', false),
  (public.seed_uuid('system', 'arx-solum'), 'arx-solum', 'Arx Solum', 315, 255, 0.82, 'white', 'Bastion exterior', 'controlled', public.seed_uuid('faction', 'adeptus-custodes'), null, 'Fortaleza avanzada que vigila las rutas hacia la Zanja Azul.', false),
  (public.seed_uuid('system', 'sa-cea-gate'), 'sa-cea-gate', 'Sa''cea Gate', 910, 150, 1.2, 'white', 'Capital orbital', 'controlled', public.seed_uuid('faction', 'space-marines'), null, 'Estacion de paso con matrices de navegacion de largo alcance.', true),
  (public.seed_uuid('system', 'lyra-terminus'), 'lyra-terminus', 'Lyra Terminus', 790, 210, 0.88, 'blue', 'Puerto externo', 'controlled', public.seed_uuid('faction', 'space-marines'), null, 'Puerto orbital en el borde del subsector.', false),
  (public.seed_uuid('system', 'narthex'), 'narthex', 'Narthex', 685, 285, 0.95, 'yellow', 'Santuario sellado', 'controlled', public.seed_uuid('faction', 'space-marines'), null, 'Complejo sacro con rutas de descenso peligrosas.', false),
  (public.seed_uuid('system', 'blackglass'), 'blackglass', 'Blackglass', 930, 440, 1.16, 'white', 'Capital cristalina', 'controlled', public.seed_uuid('faction', 'cultos-genestealer'), null, 'Honor bajo oceanos de vidrio oscuro.', true),
  (public.seed_uuid('system', 'red-sabbath'), 'red-sabbath', 'Red Sabbath', 805, 485, 0.88, 'red', 'Mundo sermonario', 'controlled', public.seed_uuid('faction', 'cultos-genestealer'), null, 'Ciudades santuario infiltradas por redes de culto.', false),
  (public.seed_uuid('system', 'mirrorcoil'), 'mirrorcoil', 'Mirrorcoil', 685, 510, 0.82, 'violet', 'Enjambre orbital', 'controlled', public.seed_uuid('faction', 'cultos-genestealer'), null, 'Estaciones gemelas que repiten senales falsas hacia el centro.', false),
  (public.seed_uuid('system', 'thokt-vault'), 'thokt-vault', 'Thokt Vault', 805, 800, 1.2, 'green', 'Capital tumba', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Cripta silenciosa rodeada de energia verdosa.', true),
  (public.seed_uuid('system', 'novem'), 'novem', 'Novem', 725, 700, 0.84, 'white', 'Luna industrial', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Complejo lunar de extraccion automatizada.', false),
  (public.seed_uuid('system', 'ghostlight'), 'ghostlight', 'Ghostlight', 625, 645, 0.8, 'green', 'Faro perdido', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Faro de navegacion que parpadea con luz fria.', false),
  (public.seed_uuid('system', 'mordax'), 'mordax', 'Mordax', 150, 780, 1.18, 'red', 'Capital corrupta', 'controlled', public.seed_uuid('faction', 'legiones-daemonicas'), null, 'Mundo industrial desgarrado por senales disformes.', true),
  (public.seed_uuid('system', 'drusus'), 'drusus', 'Drusus', 260, 700, 0.86, 'orange', 'Bastion menor', 'controlled', public.seed_uuid('faction', 'legiones-daemonicas'), null, 'Fortaleza tomada tras una campana sangrienta.', false),
  (public.seed_uuid('system', 'plaguefall-bastion'), 'plaguefall-bastion', 'Plaguefall Bastion', 360, 640, 0.82, 'green', 'Bastion infectado', 'controlled', public.seed_uuid('faction', 'legiones-daemonicas'), null, 'Plataformas de asedio cubiertas por esporas y ceniza.', false),
  (public.seed_uuid('system', 'cinder-maw'), 'cinder-maw', 'Cinder Maw', 80, 430, 1.15, 'orange', 'Capital volcanica', 'controlled', public.seed_uuid('faction', 'aeldari'), null, 'Forjas geotermicas y tormentas de ceniza.', true),
  (public.seed_uuid('system', 'eclipse-forge'), 'eclipse-forge', 'Eclipse Forge', 185, 485, 0.86, 'red', 'Forja abandonada', 'controlled', public.seed_uuid('faction', 'aeldari'), null, 'Estructuras de manufactura latentes convertidas en talleres orkos.', false),
  (public.seed_uuid('system', 'rustmaw-run'), 'rustmaw-run', 'Rustmaw Run', 285, 430, 0.82, 'orange', 'Corredor chatarrero', 'controlled', public.seed_uuid('faction', 'aeldari'), null, 'Ruta de pecios saqueados que apunta hacia el centro.', false),
  (public.seed_uuid('system', 'azur-trench'), 'azur-trench', 'Azur Trench', 405, 390, 0.86, 'blue', 'Nebulosa navegable', 'war', null, now() + interval '14 days', 'Corredor azul con pozos de gravedad inestables. Aeldari y Adeptus Custodes han chocado aqui.', false),
  (public.seed_uuid('system', 'ossuary-reach'), 'ossuary-reach', 'Ossuary Reach', 485, 625, 0.84, 'violet', 'Osario orbital', 'war', null, now() + interval '14 days', 'Campos funerarios en orbita baja, disputados por plaga y tecnologia necrona.', false),
  (public.seed_uuid('system', 'saint-veil'), 'saint-veil', 'Saint Veil', 650, 395, 0.86, 'yellow', 'Velo sagrado', 'war', null, now() + interval '14 days', 'Santuario velado donde Space Marines combaten una revuelta genestelar.', false),
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

update public.factions set capital_system_id = public.seed_uuid('system', 'cinder-maw') where slug = 'aeldari';
update public.factions set capital_system_id = public.seed_uuid('system', 'thokt-vault') where slug = 'necrones';
update public.factions set capital_system_id = public.seed_uuid('system', 'kharon-prime') where slug = 'adeptus-custodes';
update public.factions set capital_system_id = public.seed_uuid('system', 'blackglass') where slug = 'cultos-genestealer';
update public.factions set capital_system_id = public.seed_uuid('system', 'sa-cea-gate') where slug = 'space-marines';
update public.factions set capital_system_id = public.seed_uuid('system', 'mordax') where slug = 'legiones-daemonicas';
update public.factions set capital_system_id = public.seed_uuid('system', 'argent-rift') where slug = 'agentes-imperium';

update public.systems
set
  status = 'controlled',
  controller_faction_id = public.seed_uuid('faction', 'agentes-imperium'),
  is_capital = slug = 'argent-rift',
  blocked_until = null,
  updated_at = now()
where slug in ('argent-rift', 'orison', 'vesper-halo');

update public.systems
set building_slots = case when is_capital then 6 else 3 end;

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
  (public.seed_uuid('faction', 'adeptus-custodes'), 180, 130, 12, 12, 34, 90, 24, 16),
  (public.seed_uuid('faction', 'aeldari'), 190, 135, 7, 7, 26, 90, 20, 16),
  (public.seed_uuid('faction', 'necrones'), 115, 155, 18, 18, 32, 90, 22, 16),
  (public.seed_uuid('faction', 'cultos-genestealer'), 185, 115, 13, 13, 30, 90, 22, 16),
  (public.seed_uuid('faction', 'space-marines'), 135, 130, 18, 18, 38, 90, 26, 16),
  (public.seed_uuid('faction', 'legiones-daemonicas'), 155, 135, 15, 15, 28, 90, 20, 16),
  (public.seed_uuid('faction', 'agentes-imperium'), 160, 125, 14, 14, 42, 90, 24, 16)
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
  (public.seed_uuid('technology_effect', 'veteranos-guerra-units'), public.seed_uuid('technology_node', 'veteranos-guerra'), 'unlock_unit_template', '{"unit_template_slugs":["unit-aeldari-meganobz","unit-necrones-immortals","unit-necrones-skorpekh","unit-guardia-kasrkin","unit-culto-acolytes","unit-sombra-terminators","unit-muerte-plague-marines"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'especializacion-elite-minerals'), public.seed_uuid('technology_node', 'especializacion-elite'), 'recruitment_cost_discount', '{"category":"Elite","resource":"minerals","percent":10}'::jsonb),
  (public.seed_uuid('technology_effect', 'talleres-campana-building'), public.seed_uuid('technology_node', 'talleres-campana'), 'unlock_building_template', '{"building_template_slugs":["taller-guerra"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'motores-guerra-units'), public.seed_uuid('technology_node', 'motores-guerra'), 'unlock_unit_template', '{"unit_template_slugs":["unit-aeldari-deff-dread","unit-guardia-leman-russ","unit-culto-ridgerunner","unit-sombra-redemptor","unit-muerte-bloat-drone"]}'::jsonb),
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
    ('veteranos-guerra-units-v2', 'veteranos-guerra', 'unlock_unit_template', '{"unit_template_slugs":["unit-aeldari-meganobz","unit-necrones-immortals","unit-necrones-skorpekh","unit-guardia-kasrkin","unit-culto-acolytes","unit-sombra-terminators","unit-muerte-plague-marines"]}'),
    ('especializacion-elite-minerals-v2', 'especializacion-elite', 'recruitment_cost_discount', '{"category":"Elite","resource":"minerals","percent":10}'),
    ('motores-guerra-units-v2', 'motores-guerra', 'unlock_unit_template', '{"unit_template_slugs":["unit-aeldari-deff-dread","unit-guardia-leman-russ","unit-culto-ridgerunner","unit-sombra-redemptor","unit-muerte-bloat-drone"]}'),
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
    ('monumentos-relic-sanctuary', 'monumentos-gloria', 'unlock_building_template', '{"building_template_slugs":["santuario-reliquias"]}'),
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
  (coalesce((select id from public.building_templates where slug = 'monumento'), public.seed_uuid('building_template', 'monumento')), 'monumento', 'Monumento', 'Estructura ceremonial que transforma gloria local en Honor.', 'Produccion', 'production', 8, 8, 0, 1, 5, 0, 0, 300, 'honor', 2, array[]::text[], public.seed_uuid('technology_node', 'monumentos-gloria'), 'monument', true),
  (coalesce((select id from public.building_templates where slug = 'santuario-reliquias'), public.seed_uuid('building_template', 'santuario-reliquias')), 'santuario-reliquias', 'Santuario de Reliquias', 'Camara sellada donde se custodian reliquias narrativas y se equipan a Caracteres veteranos.', 'Reliquias', 'relic', 8, 8, 2, 1, 5, 0, 0, 30, null, 0, array[]::text[], public.seed_uuid('technology_node', 'monumentos-gloria'), 'relic_sanctuary', true)
on conflict (slug) do update
set name = excluded.name, description = excluded.description, category = excluded.category, building_kind = excluded.building_kind, supply_cost = excluded.supply_cost, minerals_cost = excluded.minerals_cost, honor_cost = excluded.honor_cost, gold_cost = excluded.gold_cost, industrial_material_cost = excluded.industrial_material_cost, uridium_cost = excluded.uridium_cost, technology_cost = excluded.technology_cost, construction_time_seconds = excluded.construction_time_seconds, produced_resource_key = excluded.produced_resource_key, produced_amount = excluded.produced_amount, allowed_unit_categories = excluded.allowed_unit_categories, required_technology_node_id = excluded.required_technology_node_id, icon_key = excluded.icon_key, is_available = excluded.is_available, updated_at = now();

update public.system_buildings
set building_template_id = (select id from public.building_templates where slug = 'monumento')
where building_template_id in (select id from public.building_templates where slug = 'senado')
  and exists (select 1 from public.building_templates where slug = 'monumento');

delete from public.building_templates
where slug in ('senado', 'nodo-logistico', 'bastion-mando', 'manufactorum-local');

insert into public.system_buildings (
  id, system_id, building_template_id, status, started_at, finishes_at, constructed_at
)
select
  public.seed_uuid('system_building', systems.slug || ':santuario-reliquias'),
  systems.id,
  (select id from public.building_templates where slug = 'santuario-reliquias'),
  'active',
  now() - interval '30 minutes',
  now() - interval '25 minutes',
  now() - interval '25 minutes'
from public.systems
where systems.is_capital = true
  and exists (select 1 from public.building_templates where slug = 'santuario-reliquias')
on conflict (system_id, building_template_id) do update
set status = excluded.status, started_at = excluded.started_at, finishes_at = excluded.finishes_at, constructed_at = excluded.constructed_at, updated_at = now();

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

update public.technology_nodes
set implementation_status = 'deprecated',
    updated_at = now()
where tree_key = 'common-v1'
  and slug in (
    'entrenamiento-linea',
    'logistica-frente',
    'cadenas-mando',
    'veteranos-guerra',
    'especializacion-elite',
    'motores-guerra',
    'blindaje-reforzado',
    'matrices-eficiencia'
  );

delete from public.technology_effects
where technology_node_id in (
  select id
  from public.technology_nodes
  where tree_key = 'common-v1'
    and slug in (
      'entrenamiento-linea',
      'logistica-frente',
      'cadenas-mando',
      'veteranos-guerra',
      'especializacion-elite',
      'motores-guerra',
      'blindaje-reforzado',
      'matrices-eficiencia'
    )
)
and effect_type in ('unlock_unit_template', 'recruitment_cost_discount', 'recruitment_time_discount');

delete from public.faction_technologies progress
using public.technology_nodes nodes
where progress.technology_node_id = nodes.id
  and nodes.tree_key = 'common-v1'
  and nodes.implementation_status = 'deprecated';

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

-- BEGIN GENERATED 40K UNIT CATALOG
insert into public.unit_templates (
  id, slug, faction_id, name, category, unit_type, unit_keywords, points, default_quantity, wounds_per_model, supply_cost, minerals_cost, ancestral_stone_cost, honor_cost, gold_cost, industrial_material_cost, uridium_cost, technology_cost, recruitment_time_seconds, recruitment_building_type, notes, is_available, required_technology_node_id, source_section, source_faction_name, is_allied_unit
)
select
  public.seed_uuid('unit_template', data.slug),
  data.slug,
  factions.id,
  data.name,
  data.category,
  data.unit_type,
  data.unit_keywords,
  data.points,
  data.default_quantity,
  data.wounds_per_model,
  data.supply_cost,
  data.minerals_cost,
  data.ancestral_stone_cost,
  data.honor_cost,
  data.gold_cost,
  data.industrial_material_cost,
  data.uridium_cost,
  data.technology_cost,
  data.recruitment_time_seconds,
  data.recruitment_building_type,
  data.notes,
  data.is_available,
  data.required_technology_node_id::uuid,
  data.source_section,
  data.source_faction_name,
  data.is_allied_unit
from (
  values
    ('unit-necrones-ctan-shard-of-the-deceiver', 'necrones', 'C''tan Shard of the Deceiver', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 310, 1, 8, 84, 38, 0, 21, 9, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-ctan-shard-of-the-nightbringer', 'necrones', 'C''tan Shard of the Nightbringer', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 340, 1, 8, 91, 42, 0, 23, 10, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-ctan-shard-of-the-void-dragon', 'necrones', 'C''tan Shard of the Void Dragon', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 330, 1, 8, 88, 41, 0, 23, 9, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-catacomb-command-barge', 'necrones', 'Catacomb Command Barge', 'Personaje', 'character', array['Vehiculo', 'Caracter']::text[], 120, 1, 10, 21, 27, 0, 7, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-chronomancer', 'necrones', 'Chronomancer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-dynastic-conqueror-crucible', 'necrones', 'Dynastic Conqueror [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 5, 30, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-geomancer', 'necrones', 'Geomancer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-hexmark-destroyer', 'necrones', 'Hexmark Destroyer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-hyperscientist-crucible', 'necrones', 'Hyperscientist [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 5, 30, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-illuminor-szeras', 'necrones', 'Illuminor Szeras', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 165, 1, 5, 50, 20, 0, 11, 4, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-imotekh-the-stormlord', 'necrones', 'Imotekh the Stormlord', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 100, 1, 5, 26, 12, 0, 7, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-lokhust-lord', 'necrones', 'Lokhust Lord', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 80, 1, 3, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-nekrosor-ammentar', 'necrones', 'Nekrosor Ammentar', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 185, 1, 5, 54, 23, 0, 12, 5, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-orikan-the-diviner', 'necrones', 'Orikan the Diviner', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 80, 1, 5, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-overlord', 'necrones', 'Overlord', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 5, 30, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-overlord-with-translocation-shroud', 'necrones', 'Overlord with Translocation Shroud', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 5, 30, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-plasmancer', 'necrones', 'Plasmancer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 5, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-psychomancer', 'necrones', 'Psychomancer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 5, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-royal-warden', 'necrones', 'Royal Warden', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 50, 1, 5, 18, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-skorpekh-lord', 'necrones', 'Skorpekh Lord', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 90, 1, 5, 28, 11, 0, 6, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-technomancer', 'necrones', 'Technomancer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 80, 1, 5, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-the-silent-king', 'necrones', 'The Silent King', 'Personaje', 'character', array['Vehiculo', 'Caracter']::text[], 400, 3, 10, 60, 90, 0, 24, 8, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-transcendent-ctan', 'necrones', 'Transcendent C''tan', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 325, 1, 8, 90, 40, 0, 22, 9, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-trazyn-the-infinite', 'necrones', 'Trazyn the Infinite', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-triarchal-overseer-crucible', 'necrones', 'Triarchal Overseer [Crucible]', 'Personaje', 'character', array['Vehiculo', 'Caracter']::text[], 120, 1, 10, 21, 27, 0, 7, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Necrons', false),
    ('unit-necrones-immortals', 'necrones', 'Immortals', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 70, 5, 1, 49, 8, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Xenos - Necrons', false),
    ('unit-necrones-necron-warriors', 'necrones', 'Necron Warriors', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 90, 10, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Xenos - Necrons', false),
    ('unit-necrones-annihilation-barge', 'necrones', 'Annihilation Barge', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 105, 1, 10, 18, 36, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-canoptek-doomstalker', 'necrones', 'Canoptek Doomstalker', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 140, 1, 10, 27, 49, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-canoptek-macrocytes', 'necrones', 'Canoptek Macrocytes', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 85, 5, 3, 48, 6, 0, 5, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-canoptek-reanimator', 'necrones', 'Canoptek Reanimator', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 75, 1, 10, 18, 26, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-canoptek-scarab-swarms', 'necrones', 'Canoptek Scarab Swarms', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 40, 3, 3, 24, 3, 0, 2, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-canoptek-spyders', 'necrones', 'Canoptek Spyders', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 75, 1, 10, 18, 26, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-canoptek-tomb-crawlers', 'necrones', 'Canoptek Tomb Crawlers', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 50, 2, 3, 29, 3, 0, 3, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-canoptek-wraiths', 'necrones', 'Canoptek Wraiths', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 110, 3, 3, 64, 8, 0, 6, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-convergence-of-dominion', 'necrones', 'Convergence of Dominion', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Fortificacion']::text[], 60, 1, 12, 13, 21, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-cryptothralls', 'necrones', 'Cryptothralls', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 60, 2, 1, 41, 7, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-deathmarks', 'necrones', 'Deathmarks', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 60, 5, 1, 41, 7, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-doom-scythe', 'necrones', 'Doom Scythe', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 230, 1, 10, 40, 80, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-doomsday-ark', 'necrones', 'Doomsday Ark', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 200, 1, 10, 30, 70, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-flayed-ones', 'necrones', 'Flayed Ones', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 60, 5, 1, 41, 7, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-ghost-ark', 'necrones', 'Ghost Ark', 'Transporte', 'vehicle', array['Vehiculo']::text[], 115, 1, 10, 20, 40, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Xenos - Necrons', false),
    ('unit-necrones-lokhust-destroyers', 'necrones', 'Lokhust Destroyers', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 40, 1, 3, 22, 9, 0, 0, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-lokhust-heavy-destroyers', 'necrones', 'Lokhust Heavy Destroyers', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 55, 1, 3, 26, 12, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-lychguard', 'necrones', 'Lychguard', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 85, 5, 1, 60, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-monolith', 'necrones', 'Monolith', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 400, 1, 10, 60, 140, 0, 8, 4, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-night-scythe', 'necrones', 'Night Scythe', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 145, 1, 10, 30, 50, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-obelisk', 'necrones', 'Obelisk', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 300, 1, 10, 45, 105, 0, 6, 3, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-ophydian-destroyers', 'necrones', 'Ophydian Destroyers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 80, 3, 1, 55, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-seraptek-heavy-construct', 'necrones', 'Seraptek Heavy Construct', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 540, 1, 10, 87, 189, 0, 10, 5, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-skorpekh-destroyers', 'necrones', 'Skorpekh Destroyers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 90, 3, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-tesseract-vault', 'necrones', 'Tesseract Vault', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 425, 1, 10, 69, 148, 0, 8, 4, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-tomb-blades', 'necrones', 'Tomb Blades', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 75, 3, 3, 38, 16, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-triarch-praetorians', 'necrones', 'Triarch Praetorians', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 90, 5, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-necrones-triarch-stalker', 'necrones', 'Triarch Stalker', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 110, 1, 10, 19, 38, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Necrons', false),
    ('unit-legiones-daemonicas-belakor', 'legiones-daemonicas', 'Be''lakor', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 375, 1, 8, 98, 46, 0, 26, 11, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-changecaster', 'legiones-daemonicas', 'Changecaster', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-daemon-prince-of-chaos', 'legiones-daemonicas', 'Daemon Prince of Chaos', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 190, 1, 8, 54, 23, 0, 13, 5, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-daemon-prince-of-chaos-with-wings', 'legiones-daemonicas', 'Daemon Prince of Chaos with wings', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 180, 1, 8, 51, 22, 0, 12, 5, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-daemonic-charioteer-crucible', 'legiones-daemonicas', 'Daemonic Charioteer [Crucible]', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 120, 1, 3, 35, 15, 0, 8, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-daemonic-herald-crucible', 'legiones-daemonicas', 'Daemonic Herald [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-exalted-flamer', 'legiones-daemonicas', 'Exalted Flamer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-fateskimmer', 'legiones-daemonicas', 'Fateskimmer', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 95, 1, 3, 33, 11, 0, 6, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-fluxmaster', 'legiones-daemonicas', 'Fluxmaster', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 60, 1, 3, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-kairos-fateweaver', 'legiones-daemonicas', 'Kairos Fateweaver', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 295, 1, 8, 83, 36, 0, 20, 8, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-lord-of-change', 'legiones-daemonicas', 'Lord of Change', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 285, 1, 8, 80, 35, 0, 19, 8, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-the-blue-scribes', 'legiones-daemonicas', 'The Blue Scribes', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 75, 1, 3, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-the-changeling', 'legiones-daemonicas', 'The Changeling', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 90, 1, 5, 28, 11, 0, 6, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-blue-horrors', 'legiones-daemonicas', 'Blue Horrors', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 125, 10, 1, 85, 15, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-pink-horrors', 'legiones-daemonicas', 'Pink Horrors', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 140, 10, 1, 96, 17, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-burning-chariot', 'legiones-daemonicas', 'Burning Chariot', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 115, 1, 3, 55, 25, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-flamers', 'legiones-daemonicas', 'Flamers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 65, 3, 1, 44, 8, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-screamers', 'legiones-daemonicas', 'Screamers', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 80, 3, 3, 48, 6, 0, 4, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Chaos - Chaos Daemons', false),
    ('unit-legiones-daemonicas-tzeentch-soul-grinder', 'legiones-daemonicas', 'Tzeentch Soul Grinder', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 180, 1, 10, 36, 62, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Chaos - Chaos Daemons', false),
    ('unit-agentes-imperium-callidus-assassin', 'agentes-imperium', 'Callidus Assassin', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 100, 1, 5, 26, 12, 0, 7, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-culexus-assassin', 'agentes-imperium', 'Culexus Assassin', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 5, 30, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-deathwatch-agent-crucible', 'agentes-imperium', 'Deathwatch Agent [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 105, 1, 5, 29, 13, 0, 7, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-enthroned-agent-crucible', 'agentes-imperium', 'Enthroned Agent [Crucible]', 'Personaje', 'character', array['Vehiculo', 'Caracter']::text[], 120, 1, 10, 21, 27, 0, 7, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-eversor-assassin', 'agentes-imperium', 'Eversor Assassin', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 110, 1, 5, 34, 13, 0, 7, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-inquisitor', 'agentes-imperium', 'Inquisitor', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 5, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-inquisitor-coteaz', 'agentes-imperium', 'Inquisitor Coteaz', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-inquisitor-draxus', 'agentes-imperium', 'Inquisitor Draxus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-inquisitor-greyfax', 'agentes-imperium', 'Inquisitor Greyfax', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-inquisitor-kroyle', 'agentes-imperium', 'Inquisitor Kroyle', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 100, 1, 3, 26, 12, 0, 7, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-martial-agent-crucible', 'agentes-imperium', 'Martial Agent [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-ministorum-priest', 'agentes-imperium', 'Ministorum Priest', 'Aliada', 'character', array['Infanteria', 'Caracter']::text[], 40, 1, 5, 15, 5, 0, 2, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Agents of the Imperium', true),
    ('unit-agentes-imperium-navigator', 'agentes-imperium', 'Navigator', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-rogue-trader-entourage', 'agentes-imperium', 'Rogue Trader Entourage', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 4, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-vindicare-assassin', 'agentes-imperium', 'Vindicare Assassin', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 110, 1, 5, 34, 13, 0, 7, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-watch-captain-artemis', 'agentes-imperium', 'Watch Captain Artemis', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-watch-master', 'agentes-imperium', 'Watch Master', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 95, 1, 5, 33, 11, 0, 6, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-aquila-kill-team', 'agentes-imperium', 'Aquila Kill Team', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 100, 5, 1, 66, 12, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-deathwatch-kill-team', 'agentes-imperium', 'Deathwatch Kill Team', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 100, 5, 1, 66, 12, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-imperial-navy-breachers', 'agentes-imperium', 'Imperial Navy Breachers', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 90, 10, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-vigilant-squad', 'agentes-imperium', 'Vigilant Squad', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 85, 11, 1, 60, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-corvus-blackstar', 'agentes-imperium', 'Corvus Blackstar', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 180, 1, 10, 36, 62, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-exaction-squad', 'agentes-imperium', 'Exaction Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 90, 11, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-grey-knights-terminator-squad', 'agentes-imperium', 'Grey Knights Terminator Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 190, 5, 3, 129, 23, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-imperial-rhino', 'agentes-imperium', 'Imperial Rhino', 'Transporte', 'vehicle', array['Vehiculo']::text[], 75, 1, 10, 18, 26, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-inquisitorial-agents', 'agentes-imperium', 'Inquisitorial Agents', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 50, 5, 1, 33, 6, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-inquisitorial-chimera', 'agentes-imperium', 'Inquisitorial Chimera', 'Transporte', 'vehicle', array['Vehiculo']::text[], 70, 1, 10, 17, 24, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-sanctifiers', 'agentes-imperium', 'Sanctifiers', 'Aliada', 'infantry', array['Infanteria']::text[], 100, 9, 1, 51, 12, 0, 3, 2, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Agents of the Imperium', true),
    ('unit-agentes-imperium-sisters-of-battle-immolator', 'agentes-imperium', 'Sisters of Battle Immolator', 'Transporte', 'vehicle', array['Vehiculo']::text[], 100, 1, 10, 15, 35, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-sisters-of-battle-squad', 'agentes-imperium', 'Sisters of Battle Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 100, 10, 1, 66, 12, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-subductor-squad', 'agentes-imperium', 'Subductor Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 85, 11, 1, 60, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Agents of the Imperium', false),
    ('unit-agentes-imperium-voidsmen-at-arms', 'agentes-imperium', 'Voidsmen-at-Arms', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 50, 6, 1, 33, 6, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Agents of the Imperium', false),
    ('unit-aeldari-asurmen', 'aeldari', 'Asurmen', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 135, 1, 5, 38, 16, 0, 9, 4, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-autarch', 'aeldari', 'Autarch', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 5, 30, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-autarch-wayleaper', 'aeldari', 'Autarch Wayleaper', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 80, 1, 5, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-avatar-of-khaine', 'aeldari', 'Avatar of Khaine', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 280, 1, 8, 75, 35, 0, 19, 8, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-baharroth', 'aeldari', 'Baharroth', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 115, 1, 5, 32, 14, 0, 8, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-craftworld-warleader-crucible', 'aeldari', 'Craftworld Warleader [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-death-jester', 'aeldari', 'Death Jester', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 90, 1, 5, 28, 11, 0, 6, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-eldrad-ulthran', 'aeldari', 'Eldrad Ulthran', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 120, 1, 5, 35, 15, 0, 8, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-farseer', 'aeldari', 'Farseer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-farseer-skyrunner', 'aeldari', 'Farseer Skyrunner', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 80, 1, 3, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-fuegan', 'aeldari', 'Fuegan', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 120, 1, 5, 35, 15, 0, 8, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-ghost-warrior-crucible', 'aeldari', 'Ghost Warrior [Crucible]', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 160, 1, 8, 45, 20, 0, 11, 4, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-jain-zar', 'aeldari', 'Jain Zar', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 120, 1, 5, 35, 15, 0, 8, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-kharseth', 'aeldari', 'Kharseth', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 95, 1, 5, 33, 11, 0, 6, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-lhykhis', 'aeldari', 'Lhykhis', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 135, 1, 5, 38, 16, 0, 9, 4, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-maugan-ra', 'aeldari', 'Maugan Ra', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 100, 1, 5, 26, 12, 0, 7, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-prince-yriel', 'aeldari', 'Prince Yriel', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 95, 1, 5, 33, 11, 0, 6, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-shadowseer', 'aeldari', 'Shadowseer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-skyrunner-crucible', 'aeldari', 'Skyrunner [Crucible]', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 80, 1, 3, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-solitaire', 'aeldari', 'Solitaire', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 115, 1, 5, 32, 14, 0, 8, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-spiritseer', 'aeldari', 'Spiritseer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-troupe-master', 'aeldari', 'Troupe Master', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-warlock', 'aeldari', 'Warlock', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 45, 1, 5, 15, 5, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Aeldari', false),
    ('unit-aeldari-corsair-voidreavers', 'aeldari', 'Corsair Voidreavers', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 65, 5, 1, 44, 8, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Xenos - Aeldari', false),
    ('unit-aeldari-guardian-defenders', 'aeldari', 'Guardian Defenders', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 100, 11, 1, 66, 12, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Xenos - Aeldari', false),
    ('unit-aeldari-storm-guardians', 'aeldari', 'Storm Guardians', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 110, 11, 1, 74, 13, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Xenos - Aeldari', false),
    ('unit-aeldari-corsair-skyreavers', 'aeldari', 'Corsair Skyreavers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 75, 5, 1, 52, 9, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-corsair-voidscarred', 'aeldari', 'Corsair Voidscarred', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 80, 5, 1, 55, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-crimson-hunter', 'aeldari', 'Crimson Hunter', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 160, 1, 10, 28, 56, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-d-cannon-platform', 'aeldari', 'D-Cannon Platform', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 125, 1, 1, 85, 15, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-dark-reapers', 'aeldari', 'Dark Reapers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 90, 5, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-dire-avengers', 'aeldari', 'Dire Avengers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 75, 5, 1, 52, 9, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-falcon', 'aeldari', 'Falcon', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 130, 1, 10, 25, 45, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-fire-dragons', 'aeldari', 'Fire Dragons', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 120, 5, 1, 80, 15, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-fire-prism', 'aeldari', 'Fire Prism', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 150, 1, 10, 26, 52, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-hemlock-wraithfighter', 'aeldari', 'Hemlock Wraithfighter', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 155, 1, 10, 27, 54, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-howling-banshees', 'aeldari', 'Howling Banshees', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 95, 5, 1, 68, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-night-spinner', 'aeldari', 'Night Spinner', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 190, 1, 10, 38, 66, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-phantom-titan', 'aeldari', 'Phantom Titan', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 2100, 1, 3, 1156, 157, 0, 126, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-rangers', 'aeldari', 'Rangers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 55, 5, 1, 38, 6, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-revenant-titan', 'aeldari', 'Revenant Titan', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 1100, 1, 3, 606, 82, 0, 66, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-shadow-weaver-platform', 'aeldari', 'Shadow Weaver Platform', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 75, 1, 1, 52, 9, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-shining-spears', 'aeldari', 'Shining Spears', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 110, 3, 3, 52, 24, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-shroud-runners', 'aeldari', 'Shroud Runners', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 80, 3, 3, 39, 18, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-skyweavers', 'aeldari', 'Skyweavers', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 95, 2, 3, 48, 21, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-starfangs', 'aeldari', 'Starfangs', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 75, 1, 10, 18, 26, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-starweaver', 'aeldari', 'Starweaver', 'Transporte', 'vehicle', array['Vehiculo']::text[], 80, 1, 10, 19, 28, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Xenos - Aeldari', false),
    ('unit-aeldari-striking-scorpions', 'aeldari', 'Striking Scorpions', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 85, 5, 1, 60, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-swooping-hawks', 'aeldari', 'Swooping Hawks', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 95, 5, 1, 68, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-troupe', 'aeldari', 'Troupe', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 85, 5, 1, 60, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-vibro-cannon-platform', 'aeldari', 'Vibro Cannon Platform', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 60, 1, 1, 41, 7, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-voidweaver', 'aeldari', 'Voidweaver', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 125, 1, 10, 24, 43, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-vypers', 'aeldari', 'Vypers', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 75, 1, 10, 18, 26, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-war-walkers', 'aeldari', 'War Walkers', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 85, 1, 10, 22, 29, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-warlock-conclave', 'aeldari', 'Warlock Conclave', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 55, 2, 1, 38, 6, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-warlock-skyrunners', 'aeldari', 'Warlock Skyrunners', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 45, 1, 3, 25, 10, 0, 0, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-warp-spiders', 'aeldari', 'Warp Spiders', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 105, 5, 1, 69, 13, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-wave-serpent', 'aeldari', 'Wave Serpent', 'Transporte', 'vehicle', array['Vehiculo']::text[], 125, 1, 10, 24, 43, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Xenos - Aeldari', false),
    ('unit-aeldari-windriders', 'aeldari', 'Windriders', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 80, 3, 3, 39, 18, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-wraithblades', 'aeldari', 'Wraithblades', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 150, 5, 1, 99, 18, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-wraithguard', 'aeldari', 'Wraithguard', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 160, 5, 1, 105, 20, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-wraithknight', 'aeldari', 'Wraithknight', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 435, 1, 3, 241, 32, 0, 26, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-wraithknight-with-ghostglaive', 'aeldari', 'Wraithknight with Ghostglaive', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 420, 1, 3, 233, 31, 0, 25, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-aeldari-wraithlord', 'aeldari', 'Wraithlord', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 130, 1, 3, 77, 9, 0, 7, 0, 0, 0, 0, 30, 'nido-bestias', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Aeldari', false),
    ('unit-cultos-genestealer-abominant', 'cultos-genestealer', 'Abominant', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 5, 30, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-acolyte-iconward', 'cultos-genestealer', 'Acolyte Iconward', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 50, 1, 5, 18, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-benefictus', 'cultos-genestealer', 'Benefictus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-biophagus', 'cultos-genestealer', 'Biophagus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 50, 1, 5, 18, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-clamavus', 'cultos-genestealer', 'Clamavus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 50, 1, 5, 18, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-cult-guerrilla-crucible', 'cultos-genestealer', 'Cult Guerrilla [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-cult-insurrectionist-crucible', 'cultos-genestealer', 'Cult Insurrectionist [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 80, 1, 5, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-jackal-alphus', 'cultos-genestealer', 'Jackal Alphus', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 55, 1, 3, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-kelermorph', 'cultos-genestealer', 'Kelermorph', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-locus', 'cultos-genestealer', 'Locus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 45, 1, 5, 15, 5, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-magus', 'cultos-genestealer', 'Magus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 50, 1, 5, 18, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-nexos', 'cultos-genestealer', 'Nexos', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-patriarch', 'cultos-genestealer', 'Patriarch', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-primus', 'cultos-genestealer', 'Primus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-reductus-saboteur', 'cultos-genestealer', 'Reductus Saboteur', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-sanctus', 'cultos-genestealer', 'Sanctus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 50, 1, 5, 18, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-voice-of-the-patriarch-crucible', 'cultos-genestealer', 'Voice of the Patriarch [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-acolyte-hybrids-with-autopistols', 'cultos-genestealer', 'Acolyte Hybrids with Autopistols', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 65, 5, 1, 44, 8, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-acolyte-hybrids-with-hand-flamers', 'cultos-genestealer', 'Acolyte Hybrids with Hand Flamers', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 70, 5, 1, 49, 8, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-neophyte-hybrids', 'cultos-genestealer', 'Neophyte Hybrids', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 65, 10, 1, 44, 8, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-aberrants', 'cultos-genestealer', 'Aberrants', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 135, 5, 1, 93, 16, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-achilles-ridgerunners', 'cultos-genestealer', 'Achilles Ridgerunners', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 95, 1, 10, 24, 33, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-atalan-jackals', 'cultos-genestealer', 'Atalan Jackals', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 85, 5, 3, 42, 19, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-goliath-rockgrinder', 'cultos-genestealer', 'Goliath Rockgrinder', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 120, 1, 10, 21, 42, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-goliath-truck', 'cultos-genestealer', 'Goliath Truck', 'Transporte', 'vehicle', array['Vehiculo']::text[], 85, 1, 10, 22, 29, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-hybrid-metamorphs', 'cultos-genestealer', 'Hybrid Metamorphs', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 70, 5, 1, 49, 8, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Genestealer Cults', false),
    ('unit-cultos-genestealer-purestrain-genestealers', 'cultos-genestealer', 'Purestrain Genestealers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 75, 5, 1, 52, 9, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Xenos - Genestealer Cults', false),
    ('unit-space-marines-ancient', 'space-marines', 'Ancient', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 50, 1, 5, 18, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-ancient-in-terminator-armor', 'space-marines', 'Ancient in Terminator Armor', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-apothecary', 'space-marines', 'Apothecary', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 50, 1, 5, 18, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-apothecary-biologis', 'space-marines', 'Apothecary Biologis', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-bladeguard-ancient', 'space-marines', 'Bladeguard Ancient', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 45, 1, 5, 15, 5, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-captain', 'space-marines', 'Captain', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 80, 1, 5, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-captain-in-gravis-armour', 'space-marines', 'Captain in Gravis Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 80, 1, 5, 25, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-captain-in-phobos-armour', 'space-marines', 'Captain in Phobos Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-captain-in-terminator-armour', 'space-marines', 'Captain in Terminator Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 95, 1, 5, 33, 11, 0, 6, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-captain-with-jump-pack', 'space-marines', 'Captain with Jump Pack', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-champion-of-the-chapter-crucible', 'space-marines', 'Champion of the Chapter [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-chaplain', 'space-marines', 'Chaplain', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 60, 1, 5, 21, 7, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-chaplain-in-terminator-armour', 'space-marines', 'Chaplain in Terminator Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-chaplain-on-bike', 'space-marines', 'Chaplain on Bike', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 75, 1, 3, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-chaplain-with-jump-pack', 'space-marines', 'Chaplain with Jump Pack', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-judiciar', 'space-marines', 'Judiciar', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-librarian', 'space-marines', 'Librarian', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-librarian-in-phobos-armour', 'space-marines', 'Librarian in Phobos Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-librarian-in-terminator-armour', 'space-marines', 'Librarian in Terminator Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 75, 1, 5, 22, 9, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-librarius-adept-crucible', 'space-marines', 'Librarius Adept [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 5, 24, 8, 0, 4, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-lieutenant', 'space-marines', 'Lieutenant', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 5, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-lieutenant-in-phobos-armour', 'space-marines', 'Lieutenant in Phobos Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 5, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-lieutenant-in-reiver-armour', 'space-marines', 'Lieutenant in Reiver Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 5, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-lieutenant-with-combi-weapon', 'space-marines', 'Lieutenant with Combi-weapon', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 5, 30, 10, 0, 5, 2, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-techmarine', 'space-marines', 'Techmarine', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 5, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-venerable-battle-brother-crucible', 'space-marines', 'Venerable Battle-Brother [Crucible]', 'Personaje', 'character', array['Vehiculo', 'Caracter']::text[], 160, 1, 10, 28, 36, 0, 9, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-assault-intercessor-squad', 'space-marines', 'Assault Intercessor Squad', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 75, 5, 2, 52, 9, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-heavy-intercessor-squad', 'space-marines', 'Heavy Intercessor Squad', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 100, 5, 2, 66, 12, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-intercessor-squad', 'space-marines', 'Intercessor Squad', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 80, 5, 2, 55, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-tactical-squad', 'space-marines', 'Tactical Squad', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 140, 10, 1, 96, 17, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-aggressor-squad', 'space-marines', 'Aggressor Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 95, 3, 1, 68, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-assault-intercessors-with-jump-packs', 'space-marines', 'Assault Intercessors with Jump Packs', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 90, 5, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-astraeus', 'space-marines', 'Astraeus', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 525, 1, 10, 84, 183, 0, 10, 5, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-ballistus-dreadnought', 'space-marines', 'Ballistus Dreadnought', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 150, 1, 10, 26, 52, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-bladeguard-veteran-squad', 'space-marines', 'Bladeguard Veteran Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 80, 3, 1, 55, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-brutalis-dreadnought', 'space-marines', 'Brutalis Dreadnought', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 160, 1, 10, 28, 56, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-centurion-assault-squad', 'space-marines', 'Centurion Assault Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 150, 3, 1, 99, 18, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-centurion-devastator-squad', 'space-marines', 'Centurion Devastator Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 175, 3, 1, 118, 21, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-company-heroes', 'space-marines', 'Company Heroes', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 105, 4, 1, 69, 13, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-desolation-squad', 'space-marines', 'Desolation Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 200, 5, 1, 130, 25, 0, 4, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-devastator-squad', 'space-marines', 'Devastator Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 120, 5, 1, 80, 15, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-dreadnought', 'space-marines', 'Dreadnought', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 135, 1, 10, 26, 47, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-drop-pod', 'space-marines', 'Drop Pod', 'Transporte', 'vehicle', array['Vehiculo']::text[], 70, 1, 10, 17, 24, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-eliminator-squad', 'space-marines', 'Eliminator Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 85, 3, 1, 60, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-eradicator-squad', 'space-marines', 'Eradicator Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 90, 3, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-firestrike-servo-turrets', 'space-marines', 'Firestrike Servo-Turrets', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 75, 1, 10, 18, 26, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-gladiator-lancer', 'space-marines', 'Gladiator Lancer', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 160, 1, 10, 28, 56, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-gladiator-reaper', 'space-marines', 'Gladiator Reaper', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 160, 1, 10, 28, 56, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-gladiator-valiant', 'space-marines', 'Gladiator Valiant', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 150, 1, 10, 26, 52, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-hammerfall-bunker', 'space-marines', 'Hammerfall Bunker', 'Otras hojas de datos', 'vehicle', array['Fortificacion']::text[], 175, 1, 12, 33, 61, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-hellblaster-squad', 'space-marines', 'Hellblaster Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 110, 5, 1, 74, 13, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-impulsor', 'space-marines', 'Impulsor', 'Transporte', 'vehicle', array['Vehiculo']::text[], 80, 1, 10, 19, 28, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-inceptor-squad', 'space-marines', 'Inceptor Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 120, 3, 1, 80, 15, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-incursor-squad', 'space-marines', 'Incursor Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 80, 5, 1, 55, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-infernus-squad', 'space-marines', 'Infernus Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 90, 5, 1, 63, 11, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-infiltrator-squad', 'space-marines', 'Infiltrator Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 100, 5, 1, 66, 12, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-invader-atv', 'space-marines', 'Invader ATV', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 60, 1, 3, 29, 13, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-invictor-tactical-warsuit', 'space-marines', 'Invictor Tactical Warsuit', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 125, 1, 10, 24, 43, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-land-raider', 'space-marines', 'Land Raider', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 220, 1, 10, 36, 77, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-land-raider-crusader', 'space-marines', 'Land Raider Crusader', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 220, 1, 10, 36, 77, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-land-raider-redeemer', 'space-marines', 'Land Raider Redeemer', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 270, 1, 10, 47, 94, 0, 5, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-outrider-squad', 'space-marines', 'Outrider Squad', 'Otras hojas de datos', 'mounted', array['Montado']::text[], 80, 3, 3, 39, 18, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-predator-annihilator', 'space-marines', 'Predator Annihilator', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 135, 1, 10, 26, 47, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-predator-destructor', 'space-marines', 'Predator Destructor', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 140, 1, 10, 27, 49, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-razorback', 'space-marines', 'Razorback', 'Transporte', 'vehicle', array['Vehiculo']::text[], 95, 1, 10, 24, 33, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-redemptor-dreadnought', 'space-marines', 'Redemptor Dreadnought', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 205, 1, 10, 33, 71, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-reiver-squad', 'space-marines', 'Reiver Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 80, 5, 1, 55, 10, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-repulsor', 'space-marines', 'Repulsor', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 180, 1, 10, 36, 62, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-repulsor-executioner', 'space-marines', 'Repulsor Executioner', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 230, 1, 10, 40, 80, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-rhino', 'space-marines', 'Rhino', 'Transporte', 'vehicle', array['Vehiculo']::text[], 75, 1, 10, 18, 26, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-scout-squad', 'space-marines', 'Scout Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 70, 5, 1, 49, 8, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-sternguard-veteran-squad', 'space-marines', 'Sternguard Veteran Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 100, 5, 1, 66, 12, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-storm-speeder-hailstrike', 'space-marines', 'Storm Speeder Hailstrike', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 115, 1, 10, 20, 40, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-storm-speeder-hammerstrike', 'space-marines', 'Storm Speeder Hammerstrike', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 125, 1, 10, 24, 43, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-storm-speeder-thunderstrike', 'space-marines', 'Storm Speeder Thunderstrike', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 135, 1, 10, 26, 47, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-stormhawk-interceptor', 'space-marines', 'Stormhawk Interceptor', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 155, 1, 10, 27, 54, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-stormraven-gunship', 'space-marines', 'Stormraven Gunship', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 280, 1, 10, 49, 98, 0, 5, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-stormtalon-gunship', 'space-marines', 'Stormtalon Gunship', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 165, 1, 10, 31, 57, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-suppressor-squad', 'space-marines', 'Suppressor Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 75, 3, 1, 52, 9, 0, 1, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-terminator-assault-squad', 'space-marines', 'Terminator Assault Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 180, 5, 3, 121, 22, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-terminator-squad', 'space-marines', 'Terminator Squad', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 170, 5, 3, 113, 21, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-thunderhawk-gunship', 'space-marines', 'Thunderhawk Gunship', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 840, 1, 10, 132, 294, 0, 16, 8, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-vanguard-veteran-squad-with-jump-packs', 'space-marines', 'Vanguard Veteran Squad with Jump Packs', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 100, 5, 1, 66, 12, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-vindicator', 'space-marines', 'Vindicator', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 185, 1, 10, 37, 64, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-space-marines-whirlwind', 'space-marines', 'Whirlwind', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 190, 1, 10, 38, 66, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Astartes - Space Marines', false),
    ('unit-adeptus-custodes-aleya', 'adeptus-custodes', 'Aleya', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-blade-champion', 'adeptus-custodes', 'Blade Champion', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 120, 1, 5, 35, 15, 0, 8, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-guardian-of-the-throne-crucible', 'adeptus-custodes', 'Guardian of the Throne [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 130, 1, 5, 38, 16, 0, 9, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-kataphraktoi-exemplar-crucible', 'adeptus-custodes', 'Kataphraktoi Exemplar [Crucible]', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 150, 1, 3, 44, 18, 0, 10, 4, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-knight-centura', 'adeptus-custodes', 'Knight-Centura', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 5, 23, 6, 0, 3, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-null-maiden-crucible', 'adeptus-custodes', 'Null Maiden [Crucible]', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 65, 1, 5, 24, 8, 0, 4, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-shield-captain', 'adeptus-custodes', 'Shield-Captain', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 120, 1, 5, 35, 15, 0, 8, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-shield-captain-in-allarus-terminator-armour', 'adeptus-custodes', 'Shield-Captain in Allarus Terminator Armour', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 130, 1, 5, 38, 16, 0, 9, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-shield-captain-on-dawneagle-jetbike', 'adeptus-custodes', 'Shield-Captain on Dawneagle Jetbike', 'Personaje', 'character', array['Montado', 'Caracter']::text[], 150, 1, 3, 44, 18, 0, 10, 4, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-trajann-valoris', 'adeptus-custodes', 'Trajann Valoris', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 140, 1, 5, 41, 17, 0, 9, 4, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-valerian', 'adeptus-custodes', 'Valerian', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 110, 1, 5, 34, 13, 0, 7, 3, 0, 0, 0, 30, 'cuartel-mando', 'Unidad importada desde data/11th40kPoints.txt (CHARACTERS).', false, null, 'CHARACTERS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-custodian-guard', 'adeptus-custodes', 'Custodian Guard', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 160, 4, 1, 105, 20, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (BATTLELINE).', false, null, 'BATTLELINE', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-allarus-custodians', 'adeptus-custodes', 'Allarus Custodians', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 110, 2, 1, 74, 13, 0, 2, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-anathema-psykana-rhino', 'adeptus-custodes', 'Anathema Psykana Rhino', 'Transporte', 'vehicle', array['Vehiculo']::text[], 75, 1, 10, 18, 26, 0, 1, 0, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (DEDICATED TRANSPORTS).', false, null, 'DEDICATED TRANSPORTS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-aquilon-custodians', 'adeptus-custodes', 'Aquilon Custodians', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 195, 3, 1, 132, 24, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-ares-gunship', 'adeptus-custodes', 'Ares Gunship', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 580, 1, 10, 94, 203, 0, 11, 5, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-caladius-grav-tank', 'adeptus-custodes', 'Caladius Grav-tank', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 215, 1, 10, 35, 75, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-contemptor-achillus-dreadnought', 'adeptus-custodes', 'Contemptor-Achillus Dreadnought', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 155, 1, 10, 27, 54, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-contemptor-galatus-dreadnought', 'adeptus-custodes', 'Contemptor-Galatus Dreadnought', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 165, 1, 10, 31, 57, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-coronus-grav-carrier', 'adeptus-custodes', 'Coronus Grav-carrier', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 200, 1, 10, 30, 70, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-custodian-guard-with-adrasite-and-pyrithite-spears', 'adeptus-custodes', 'Custodian Guard with Adrasite and Pyrithite spears', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 250, 5, 1, 163, 31, 0, 5, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-custodian-wardens', 'adeptus-custodes', 'Custodian Wardens', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 210, 4, 1, 138, 26, 0, 4, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-orion-assault-dropship', 'adeptus-custodes', 'Orion Assault Dropship', 'Otras hojas de datos', 'vehicle', array['Vehiculo', 'Aeronave']::text[], 690, 1, 10, 113, 241, 0, 13, 6, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-pallas-grav-attack', 'adeptus-custodes', 'Pallas Grav-attack', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 105, 1, 10, 18, 36, 0, 2, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-prosecutors', 'adeptus-custodes', 'Prosecutors', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 40, 4, 1, 30, 5, 0, 0, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-sagittarum-custodians', 'adeptus-custodes', 'Sagittarum Custodians', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 225, 5, 1, 149, 28, 0, 4, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-telemon-heavy-dreadnought', 'adeptus-custodes', 'Telemon Heavy Dreadnought', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 225, 1, 10, 39, 78, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-venatari-custodians', 'adeptus-custodes', 'Venatari Custodians', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 165, 3, 1, 110, 20, 0, 3, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-venerable-contemptor-dreadnought', 'adeptus-custodes', 'Venerable Contemptor Dreadnought', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 170, 1, 10, 32, 59, 0, 3, 1, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-venerable-land-raider', 'adeptus-custodes', 'Venerable Land Raider', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 220, 1, 10, 36, 77, 0, 4, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-vigilators', 'adeptus-custodes', 'Vigilators', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 45, 4, 1, 35, 5, 0, 0, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-witchseekers', 'adeptus-custodes', 'Witchseekers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 45, 4, 1, 35, 5, 0, 0, 0, 0, 0, 0, 30, 'barracon-infanteria', 'Unidad importada desde data/11th40kPoints.txt (OTHER DATASHEETS).', false, null, 'OTHER DATASHEETS', 'Imperium - Adeptus Custodes', false),
    ('unit-adeptus-custodes-acastus-knight-asterius', 'adeptus-custodes', 'Acastus Knight Asterius', 'Aliada', 'vehicle', array['Vehiculo']::text[], 765, 1, 24, 81, 267, 0, 15, 15, 0, 0, 0, 30, 'taller-guerra', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-acastus-knight-porphyrion', 'adeptus-custodes', 'Acastus Knight Porphyrion', 'Aliada', 'vehicle', array['Vehiculo']::text[], 700, 1, 24, 72, 244, 0, 14, 14, 0, 0, 0, 30, 'taller-guerra', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-armiger-helverin', 'adeptus-custodes', 'Armiger Helverin', 'Aliada', 'vehicle', array['Vehiculo']::text[], 135, 1, 10, 21, 47, 0, 2, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-armiger-moirax', 'adeptus-custodes', 'Armiger Moirax', 'Aliada', 'vehicle', array['Vehiculo']::text[], 150, 1, 10, 16, 52, 0, 3, 3, 0, 0, 0, 30, 'taller-guerra', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-armiger-warglaive', 'adeptus-custodes', 'Armiger Warglaive', 'Aliada', 'vehicle', array['Vehiculo']::text[], 140, 1, 10, 22, 49, 0, 2, 2, 0, 0, 0, 30, 'taller-guerra', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-canis-rex', 'adeptus-custodes', 'Canis Rex', 'Aliada', 'character', array['Infanteria', 'Caracter']::text[], 415, 2, 5, 108, 51, 0, 29, 12, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-cerastus-knight-lancer', 'adeptus-custodes', 'Cerastus Knight Lancer', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 395, 1, 24, 69, 88, 0, 23, 7, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-castellan', 'adeptus-custodes', 'Knight Castellan', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 410, 1, 24, 66, 92, 0, 24, 8, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-crusader', 'adeptus-custodes', 'Knight Crusader', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 385, 1, 24, 63, 86, 0, 23, 7, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-defender', 'adeptus-custodes', 'Knight Defender', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 415, 1, 24, 69, 93, 0, 24, 8, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-destrier', 'adeptus-custodes', 'Knight Destrier', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 250, 1, 24, 38, 56, 0, 15, 5, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-gallant', 'adeptus-custodes', 'Knight Gallant', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 355, 1, 24, 57, 79, 0, 21, 7, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-paladin', 'adeptus-custodes', 'Knight Paladin', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 375, 1, 24, 62, 84, 0, 22, 7, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-preceptor', 'adeptus-custodes', 'Knight Preceptor', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 365, 1, 24, 61, 82, 0, 21, 7, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-valiant', 'adeptus-custodes', 'Knight Valiant', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 410, 1, 24, 66, 92, 0, 24, 8, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-knight-warden', 'adeptus-custodes', 'Knight Warden', 'Aliada', 'character', array['Vehiculo', 'Caracter']::text[], 375, 1, 24, 62, 84, 0, 22, 7, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-ministorum-priest', 'adeptus-custodes', 'Ministorum Priest', 'Aliada', 'character', array['Infanteria', 'Caracter']::text[], 40, 1, 5, 15, 5, 0, 2, 1, 0, 0, 0, 30, 'cuartel-mando', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-warhound-titan', 'adeptus-custodes', 'Warhound Titan', 'Aliada', 'vehicle', array['Vehiculo']::text[], 1100, 1, 10, 110, 385, 0, 22, 22, 0, 0, 0, 30, 'taller-guerra', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true),
    ('unit-adeptus-custodes-warlord-titan', 'adeptus-custodes', 'Warlord Titan', 'Aliada', 'vehicle', array['Vehiculo']::text[], 3500, 1, 10, 350, 1225, 0, 70, 70, 0, 0, 0, 30, 'taller-guerra', 'Unidad aliada importada desde data/11th40kPoints.txt (UNIDADES ALIADAS).', false, null, 'UNIDADES ALIADAS', 'Imperium - Adeptus Custodes', true)
) as data(slug, faction_slug, name, category, unit_type, unit_keywords, points, default_quantity, wounds_per_model, supply_cost, minerals_cost, ancestral_stone_cost, honor_cost, gold_cost, industrial_material_cost, uridium_cost, technology_cost, recruitment_time_seconds, recruitment_building_type, notes, is_available, required_technology_node_id, source_section, source_faction_name, is_allied_unit)
join public.factions on factions.slug = data.faction_slug
on conflict (slug) do update
set faction_id = excluded.faction_id, name = excluded.name, category = excluded.category, unit_type = excluded.unit_type, unit_keywords = excluded.unit_keywords, points = excluded.points, default_quantity = excluded.default_quantity, wounds_per_model = excluded.wounds_per_model, supply_cost = excluded.supply_cost, minerals_cost = excluded.minerals_cost, ancestral_stone_cost = excluded.ancestral_stone_cost, honor_cost = excluded.honor_cost, gold_cost = excluded.gold_cost, industrial_material_cost = excluded.industrial_material_cost, uridium_cost = excluded.uridium_cost, technology_cost = excluded.technology_cost, recruitment_time_seconds = excluded.recruitment_time_seconds, recruitment_building_type = excluded.recruitment_building_type, notes = excluded.notes, is_available = excluded.is_available, required_technology_node_id = excluded.required_technology_node_id, source_section = excluded.source_section, source_faction_name = excluded.source_faction_name, is_allied_unit = excluded.is_allied_unit;

insert into public.campaign_units (
  id, slug, faction_id, unit_template_id, name, category, unit_type, unit_keywords, points, quantity, starting_quantity, wounds_taken, experience, rank, current_system_id, status, is_visible_publicly
)
select
  public.seed_uuid('campaign_unit', data.slug),
  data.slug,
  factions.id,
  unit_templates.id,
  data.name,
  data.category,
  data.unit_type,
  data.unit_keywords,
  data.points,
  data.quantity,
  data.starting_quantity,
  data.wounds_taken,
  data.experience,
  case when data.unit_keywords @> array['Caracter']::text[] then public.character_rank_for_level(data.experience) else data.rank end,
  public.seed_uuid('system', data.system_slug),
  data.status,
  false
from (
  values
    ('custodes-kharon-guard', 'adeptus-custodes', 'unit-adeptus-custodes-custodian-guard', 'Custodian Guard', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 160, 4, 4, 0, 1, null, 'kharon-prime', 'ready'),
    ('custodes-arx-caladius', 'adeptus-custodes', 'unit-adeptus-custodes-caladius-grav-tank', 'Caladius Grav-tank', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 215, 1, 1, 0, 1, null, 'arx-solum', 'moving'),
    ('custodes-shield-captain', 'adeptus-custodes', 'unit-adeptus-custodes-shield-captain', 'Shield-Captain', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 120, 1, 1, 0, 3, null, 'kharon-prime', 'ready'),
    ('custodes-azur-guard', 'adeptus-custodes', 'unit-adeptus-custodes-custodian-guard', 'Custodian Guard', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 160, 4, 4, 0, 1, null, 'azur-trench', 'in_war'),
    ('aeldari-cinder-guardians', 'aeldari', 'unit-aeldari-guardian-defenders', 'Guardian Defenders', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 100, 11, 11, 0, 1, null, 'cinder-maw', 'ready'),
    ('aeldari-rust-dire-avengers', 'aeldari', 'unit-aeldari-dire-avengers', 'Dire Avengers', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 75, 5, 5, 0, 1, null, 'rustmaw-run', 'moving'),
    ('aeldari-farseer', 'aeldari', 'unit-aeldari-farseer', 'Farseer', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 1, 0, 3, null, 'cinder-maw', 'ready'),
    ('aeldari-azur-guardians', 'aeldari', 'unit-aeldari-guardian-defenders', 'Guardian Defenders', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 100, 11, 11, 0, 1, null, 'azur-trench', 'in_war'),
    ('space-gate-intercessors', 'space-marines', 'unit-space-marines-intercessor-squad', 'Intercessor Squad', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 80, 5, 5, 0, 1, null, 'sa-cea-gate', 'ready'),
    ('space-narthex-rhino', 'space-marines', 'unit-space-marines-rhino', 'Rhino', 'Transporte', 'vehicle', array['Vehiculo']::text[], 75, 1, 1, 0, 1, null, 'narthex', 'moving'),
    ('space-captain', 'space-marines', 'unit-space-marines-captain', 'Captain', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 80, 1, 1, 0, 3, null, 'sa-cea-gate', 'ready'),
    ('space-saint-intercessors', 'space-marines', 'unit-space-marines-intercessor-squad', 'Intercessor Squad', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 80, 5, 5, 0, 1, null, 'saint-veil', 'in_war'),
    ('cult-blackglass-neophytes', 'cultos-genestealer', 'unit-cultos-genestealer-neophyte-hybrids', 'Neophyte Hybrids', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 65, 10, 10, 0, 1, null, 'blackglass', 'ready'),
    ('cult-mirror-ridgerunner', 'cultos-genestealer', 'unit-cultos-genestealer-achilles-ridgerunners', 'Achilles Ridgerunners', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 95, 1, 1, 0, 1, null, 'mirrorcoil', 'moving'),
    ('cult-primus', 'cultos-genestealer', 'unit-cultos-genestealer-primus', 'Primus', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 70, 1, 1, 0, 3, null, 'blackglass', 'ready'),
    ('cult-saint-neophytes', 'cultos-genestealer', 'unit-cultos-genestealer-neophyte-hybrids', 'Neophyte Hybrids', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 65, 10, 10, 0, 1, null, 'saint-veil', 'in_war'),
    ('necron-thokt-warriors', 'necrones', 'unit-necrones-necron-warriors', 'Necron Warriors', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 90, 10, 10, 0, 1, null, 'thokt-vault', 'ready'),
    ('necron-ghost-wraiths', 'necrones', 'unit-necrones-canoptek-wraiths', 'Canoptek Wraiths', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 110, 3, 3, 0, 1, null, 'ghostlight', 'moving'),
    ('necron-overlord', 'necrones', 'unit-necrones-overlord', 'Overlord', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 85, 1, 1, 0, 3, null, 'thokt-vault', 'ready'),
    ('necron-ossuary-warriors', 'necrones', 'unit-necrones-necron-warriors', 'Necron Warriors', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 90, 10, 10, 0, 1, null, 'ossuary-reach', 'in_war'),
    ('daemon-mordax-horrors', 'legiones-daemonicas', 'unit-legiones-daemonicas-pink-horrors', 'Pink Horrors', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 140, 10, 10, 0, 1, null, 'mordax', 'ready'),
    ('daemon-plaguefall-screamers', 'legiones-daemonicas', 'unit-legiones-daemonicas-screamers', 'Screamers', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 80, 3, 3, 0, 1, null, 'plaguefall-bastion', 'moving'),
    ('daemon-lord-change', 'legiones-daemonicas', 'unit-legiones-daemonicas-lord-of-change', 'Lord of Change', 'Personaje', 'character', array['Bestia', 'Caracter']::text[], 285, 1, 1, 0, 3, null, 'mordax', 'ready'),
    ('daemon-ossuary-horrors', 'legiones-daemonicas', 'unit-legiones-daemonicas-blue-horrors', 'Blue Horrors', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 125, 10, 10, 0, 1, null, 'ossuary-reach', 'in_war'),
    ('agents-argent-breachers', 'agentes-imperium', 'unit-agentes-imperium-imperial-navy-breachers', 'Imperial Navy Breachers', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 90, 10, 10, 0, 1, null, 'argent-rift', 'ready'),
    ('agents-orison-deathwatch', 'agentes-imperium', 'unit-agentes-imperium-deathwatch-kill-team', 'Deathwatch Kill Team', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 100, 5, 5, 0, 1, null, 'orison', 'moving'),
    ('agents-inquisitor', 'agentes-imperium', 'unit-agentes-imperium-inquisitor', 'Inquisitor', 'Personaje', 'character', array['Infanteria', 'Caracter']::text[], 55, 1, 1, 0, 3, null, 'argent-rift', 'ready')
) as data(slug, faction_slug, template_slug, name, category, unit_type, unit_keywords, points, quantity, starting_quantity, wounds_taken, experience, rank, system_slug, status)
join public.factions on factions.slug = data.faction_slug
join public.unit_templates on unit_templates.slug = data.template_slug
on conflict (slug) do update
set faction_id = excluded.faction_id, unit_template_id = excluded.unit_template_id, name = excluded.name, category = excluded.category, unit_type = excluded.unit_type, unit_keywords = excluded.unit_keywords, points = excluded.points, quantity = excluded.quantity, starting_quantity = excluded.starting_quantity, wounds_taken = excluded.wounds_taken, experience = excluded.experience, rank = excluded.rank, current_system_id = excluded.current_system_id, status = excluded.status, is_visible_publicly = excluded.is_visible_publicly, updated_at = now();
-- END GENERATED 40K UNIT CATALOG

-- BEGIN NECRON TROOP TECHNOLOGY TREE
select public.seed_necron_troop_technology_tree();
select public.seed_genestealer_cult_troop_technology_tree();
select public.seed_space_marines_troop_technology_tree();
select public.seed_daemonic_legions_troop_technology_tree();
select public.seed_adeptus_custodes_troop_technology_tree();
select public.apply_troop_technology_cost_rebalance();
select public.apply_daemonic_legions_horror_tree_adjustment();
/*
drop table if exists public._seed_necron_troop_technology_nodes;

create table public._seed_necron_troop_technology_nodes (
  slug text primary key,
  name text not null,
  description text not null,
  branch text not null,
  tier integer not null,
  position_x numeric not null,
  position_y numeric not null,
  cost_technology integer not null,
  research_time_seconds integer not null,
  icon_key text not null,
  effect_summary text not null,
  prerequisite_slugs text[] not null,
  unit_template_slugs text[] not null
);

insert into public._seed_necron_troop_technology_nodes (
  slug, name, description, branch, tier, position_x, position_y, cost_technology, research_time_seconds,
  icon_key, effect_summary, prerequisite_slugs, unit_template_slugs
)
values
  ('necrones-protocolos-reanimacion', 'Protocolos de Reanimacion', 'Las cohortes basicas despiertan en masa y sostienen la primera linea de conquista.', 'Falange Dinastica', 1, 1, 1, 1, 30, 'necron_phalanx', 'Desbloquea Warriors e Immortals.', array['fundacion-planetaria'], array['unit-necrones-immortals','unit-necrones-necron-warriors']),
  ('necrones-camaras-acecho', 'Camaras de Acecho', 'Asesinos, custodios cripticos y horrores desollados preparan emboscadas desde tumbas ocultas.', 'Falange Dinastica', 2, 1, 2, 1, 30, 'necron_ambush', 'Desbloquea Cryptothralls, Deathmarks y Flayed Ones.', array['necrones-protocolos-reanimacion'], array['unit-necrones-cryptothralls','unit-necrones-deathmarks','unit-necrones-flayed-ones']),
  ('necrones-guardia-triarca', 'Guardia del Triarca', 'Las castas juramentadas recuperan su funcion: custodiar nobles y ejecutar la voluntad del Triarca.', 'Falange Dinastica', 3, 1, 3, 2, 30, 'necron_guard', 'Desbloquea Lychguard y Triarch Praetorians.', array['necrones-camaras-acecho'], array['unit-necrones-lychguard','unit-necrones-triarch-praetorians']),
  ('necrones-cultos-destructores', 'Cultos Destructores', 'La obsesion por la aniquilacion toma forma en cazadores, filos hiperfase y plataformas antigraviticas.', 'Falange Dinastica', 4, 1, 4, 2, 30, 'necron_destroyer', 'Desbloquea Destroyers y Tomb Blades.', array['necrones-guardia-triarca'], array['unit-necrones-lokhust-destroyers','unit-necrones-lokhust-heavy-destroyers','unit-necrones-ophydian-destroyers','unit-necrones-skorpekh-destroyers','unit-necrones-tomb-blades']),
  ('necrones-nobleza-dinastica', 'Nobleza Dinastica', 'Los mandos de batalla imponen jerarquia sobre cohortes, guardias y asesinos de la dinastia.', 'Falange Dinastica', 5, 1, 5, 3, 30, 'necron_nobility', 'Desbloquea mandos comunes de la dinastia.', array['necrones-cultos-destructores'], array['unit-necrones-royal-warden','unit-necrones-overlord','unit-necrones-overlord-with-translocation-shroud','unit-necrones-skorpekh-lord']),
  ('necrones-concilio-cryptek', 'Concilio Cryptek', 'Los tecnosabios de la tumba reactivan chronometria, geomancia, tecnologia viva y energia plasmica.', 'Corte Criptecnica', 1, 2, 1, 1, 30, 'necron_cryptek', 'Desbloquea Crypteks basicos.', array['asamblea-planetaria'], array['unit-necrones-plasmancer','unit-necrones-psychomancer','unit-necrones-chronomancer','unit-necrones-geomancer','unit-necrones-technomancer']),
  ('necrones-oraculos-eternidad', 'Oraculos de Eternidad', 'Profetas, senescales y asesinos independientes manipulan el destino de la cruzada.', 'Corte Criptecnica', 2, 2, 2, 1, 30, 'necron_oracle', 'Desbloquea personajes de apoyo y cazadores singulares.', array['necrones-concilio-cryptek'], array['unit-necrones-trazyn-the-infinite','unit-necrones-orikan-the-diviner','unit-necrones-hexmark-destroyer','unit-necrones-lokhust-lord']),
  ('necrones-senores-tormenta', 'Senores de la Tormenta', 'La corte despierta a sus figuras de autoridad mas temidas para reclamar mundos perdidos.', 'Corte Criptecnica', 3, 2, 3, 2, 30, 'necron_lord', 'Desbloquea heroes dinasticos mayores.', array['necrones-oraculos-eternidad'], array['unit-necrones-imotekh-the-stormlord','unit-necrones-illuminor-szeras','unit-necrones-nekrosor-ammentar']),
  ('necrones-protocolos-crucible', 'Protocolos Crucible', 'Protocolos experimentales permiten desplegar activos [Crucible] y mandos de plataforma.', 'Corte Criptecnica', 4, 2, 4, 2, 30, 'necron_crucible', 'Desbloquea mandos Crucible y Catacomb Command Barge.', array['necrones-senores-tormenta'], array['unit-necrones-dynastic-conqueror-crucible','unit-necrones-hyperscientist-crucible','unit-necrones-triarchal-overseer-crucible','unit-necrones-catacomb-command-barge']),
  ('necrones-dioses-fragmentados', 'Dioses Fragmentados', 'La dinastia rompe sellos imposibles y conduce fragmentos C''tan y al Rey Silente al tablero.', 'Corte Criptecnica', 5, 2, 5, 3, 30, 'necron_ctan', 'Desbloquea C''tan y The Silent King.', array['necrones-protocolos-crucible'], array['unit-necrones-ctan-shard-of-the-deceiver','unit-necrones-transcendent-ctan','unit-necrones-ctan-shard-of-the-void-dragon','unit-necrones-ctan-shard-of-the-nightbringer','unit-necrones-the-silent-king']),
  ('necrones-enjambres-canoptek', 'Enjambres Canoptek', 'La maquinaria de mantenimiento despierta en masas menores para limpiar, devorar y cartografiar mundos tumba.', 'Constructos Eternos', 1, 3, 1, 1, 30, 'necron_canoptek', 'Desbloquea enjambres y constructos menores.', array['criadero-guerra','maquinaria-belica'], array['unit-necrones-canoptek-scarab-swarms','unit-necrones-canoptek-tomb-crawlers','unit-necrones-canoptek-macrocytes']),
  ('necrones-matrices-reparacion', 'Matrices de Reparacion', 'Constructos canoptek avanzados mantienen la ofensiva, reparan necrodermis y cazan intrusos.', 'Constructos Eternos', 2, 3, 2, 1, 30, 'necron_repair', 'Desbloquea Reanimator, Spyders, Wraiths y Doomstalker.', array['necrones-enjambres-canoptek'], array['unit-necrones-canoptek-reanimator','unit-necrones-canoptek-spyders','unit-necrones-canoptek-wraiths','unit-necrones-canoptek-doomstalker']),
  ('necrones-arcas-tumba', 'Arcas de la Tumba', 'Transportes, plataformas de supresion y fortificaciones moviles conectan las criptas reactivadas.', 'Constructos Eternos', 3, 3, 3, 2, 30, 'necron_ark', 'Desbloquea arcas y plataformas de apoyo.', array['necrones-matrices-reparacion'], array['unit-necrones-ghost-ark','unit-necrones-annihilation-barge','unit-necrones-triarch-stalker','unit-necrones-convergence-of-dominion']),
  ('necrones-guadanas-noche', 'Guadanas de la Noche', 'Aeronaves y arcas de exterminio abren corredores de terror sobre el frente central.', 'Constructos Eternos', 4, 3, 4, 2, 30, 'necron_air', 'Desbloquea Night Scythe, Doom Scythe, Doomsday Ark y Obelisk.', array['necrones-arcas-tumba'], array['unit-necrones-night-scythe','unit-necrones-doom-scythe','unit-necrones-doomsday-ark','unit-necrones-obelisk']),
  ('necrones-megaestructuras-vivientes', 'Megaestructuras Vivientes', 'La necrodermis titanica vuelve a caminar: portales, bovedas y constructos pesados de final de campana.', 'Constructos Eternos', 5, 3, 5, 3, 30, 'necron_monolith', 'Desbloquea Monolith, Tesseract Vault y Seraptek Heavy Construct.', array['necrones-guadanas-noche'], array['unit-necrones-monolith','unit-necrones-tesseract-vault','unit-necrones-seraptek-heavy-construct']);

insert into public.technology_nodes (
  id, slug, tree_key, name, description, branch, tier, position_x, position_y,
  cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
)
select
  public.seed_uuid('technology_node', nodes.slug),
  nodes.slug,
  'troops-necrones-v1',
  nodes.name,
  nodes.description,
  nodes.branch,
  nodes.tier,
  nodes.position_x,
  nodes.position_y,
  nodes.cost_technology,
  nodes.research_time_seconds,
  nodes.icon_key,
  nodes.effect_summary,
  false,
  'active'
from public._seed_necron_troop_technology_nodes nodes
on conflict (slug) do update
set tree_key = excluded.tree_key, name = excluded.name, description = excluded.description, branch = excluded.branch, tier = excluded.tier, position_x = excluded.position_x, position_y = excluded.position_y, cost_technology = excluded.cost_technology, research_time_seconds = excluded.research_time_seconds, icon_key = excluded.icon_key, effect_summary = excluded.effect_summary, is_starter = excluded.is_starter, implementation_status = excluded.implementation_status, updated_at = now();

delete from public.technology_prerequisites prerequisites
using public.technology_nodes nodes
where prerequisites.technology_node_id = nodes.id
  and nodes.tree_key = 'troops-necrones-v1';

insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
select tech.id, required.id, prerequisite.ordinality::integer
from public._seed_necron_troop_technology_nodes nodes
cross join lateral unnest(nodes.prerequisite_slugs) with ordinality as prerequisite(required_slug, ordinality)
join public.technology_nodes tech on tech.slug = nodes.slug
join public.technology_nodes required on required.slug = prerequisite.required_slug
on conflict (technology_node_id, required_node_id) do update
set prerequisite_group = excluded.prerequisite_group;

delete from public.technology_effects effects
using public.technology_nodes nodes
where effects.technology_node_id = nodes.id
  and nodes.tree_key = 'troops-necrones-v1'
  and effects.effect_type = 'unlock_unit_template';

insert into public.technology_effects (id, technology_node_id, effect_type, payload)
select
  public.seed_uuid('technology_effect', nodes.slug || '-units'),
  technology_nodes.id,
  'unlock_unit_template',
  jsonb_build_object('unit_template_slugs', nodes.unit_template_slugs)
from public._seed_necron_troop_technology_nodes nodes
join public.technology_nodes on technology_nodes.slug = nodes.slug
on conflict (id) do update
set technology_node_id = excluded.technology_node_id, effect_type = excluded.effect_type, payload = excluded.payload;
*/
-- END NECRON TROOP TECHNOLOGY TREE

-- BEGIN NECRON TROOP TECHNOLOGY ASSIGNMENTS
with assignments(unit_slug, technology_slug) as (
  values
    ('unit-necrones-immortals', 'necrones-protocolos-reanimacion'),
    ('unit-necrones-necron-warriors', 'necrones-protocolos-reanimacion'),
    ('unit-necrones-cryptothralls', 'necrones-camaras-acecho'),
    ('unit-necrones-deathmarks', 'necrones-camaras-acecho'),
    ('unit-necrones-flayed-ones', 'necrones-camaras-acecho'),
    ('unit-necrones-lychguard', 'necrones-guardia-triarca'),
    ('unit-necrones-triarch-praetorians', 'necrones-guardia-triarca'),
    ('unit-necrones-lokhust-destroyers', 'necrones-cultos-destructores'),
    ('unit-necrones-lokhust-heavy-destroyers', 'necrones-cultos-destructores'),
    ('unit-necrones-ophydian-destroyers', 'necrones-cultos-destructores'),
    ('unit-necrones-skorpekh-destroyers', 'necrones-cultos-destructores'),
    ('unit-necrones-tomb-blades', 'necrones-cultos-destructores'),
    ('unit-necrones-royal-warden', 'necrones-nobleza-dinastica'),
    ('unit-necrones-overlord', 'necrones-nobleza-dinastica'),
    ('unit-necrones-overlord-with-translocation-shroud', 'necrones-nobleza-dinastica'),
    ('unit-necrones-skorpekh-lord', 'necrones-nobles-exterminio'),
    ('unit-necrones-plasmancer', 'necrones-concilio-cryptek'),
    ('unit-necrones-psychomancer', 'necrones-concilio-cryptek'),
    ('unit-necrones-chronomancer', 'necrones-concilio-cryptek'),
    ('unit-necrones-geomancer', 'necrones-concilio-cryptek'),
    ('unit-necrones-technomancer', 'necrones-concilio-cryptek'),
    ('unit-necrones-trazyn-the-infinite', 'necrones-oraculos-eternidad'),
    ('unit-necrones-orikan-the-diviner', 'necrones-oraculos-eternidad'),
    ('unit-necrones-hexmark-destroyer', 'necrones-oraculos-eternidad'),
    ('unit-necrones-lokhust-lord', 'necrones-nobles-exterminio'),
    ('unit-necrones-imotekh-the-stormlord', 'necrones-senores-tormenta'),
    ('unit-necrones-illuminor-szeras', 'necrones-senores-tormenta'),
    ('unit-necrones-nekrosor-ammentar', 'necrones-senores-tormenta'),
    ('unit-necrones-dynastic-conqueror-crucible', 'necrones-senores-tormenta'),
    ('unit-necrones-hyperscientist-crucible', 'necrones-senores-tormenta'),
    ('unit-necrones-triarchal-overseer-crucible', 'necrones-nobles-exterminio'),
    ('unit-necrones-catacomb-command-barge', 'necrones-nobles-exterminio'),
    ('unit-necrones-ctan-shard-of-the-deceiver', 'necrones-dioses-fragmentados'),
    ('unit-necrones-transcendent-ctan', 'necrones-dioses-fragmentados'),
    ('unit-necrones-ctan-shard-of-the-void-dragon', 'necrones-dioses-fragmentados'),
    ('unit-necrones-ctan-shard-of-the-nightbringer', 'necrones-dioses-fragmentados'),
    ('unit-necrones-the-silent-king', 'necrones-dioses-fragmentados'),
    ('unit-necrones-canoptek-scarab-swarms', 'necrones-enjambres-canoptek'),
    ('unit-necrones-canoptek-tomb-crawlers', 'necrones-enjambres-canoptek'),
    ('unit-necrones-canoptek-macrocytes', 'necrones-enjambres-canoptek'),
    ('unit-necrones-canoptek-reanimator', 'necrones-matrices-reparacion'),
    ('unit-necrones-canoptek-spyders', 'necrones-matrices-reparacion'),
    ('unit-necrones-canoptek-wraiths', 'necrones-matrices-reparacion'),
    ('unit-necrones-canoptek-doomstalker', 'necrones-matrices-reparacion'),
    ('unit-necrones-ghost-ark', 'necrones-arcas-tumba'),
    ('unit-necrones-annihilation-barge', 'necrones-arcas-tumba'),
    ('unit-necrones-triarch-stalker', 'necrones-arcas-tumba'),
    ('unit-necrones-convergence-of-dominion', 'necrones-arcas-tumba'),
    ('unit-necrones-night-scythe', 'necrones-guadanas-noche'),
    ('unit-necrones-doom-scythe', 'necrones-guadanas-noche'),
    ('unit-necrones-doomsday-ark', 'necrones-guadanas-noche'),
    ('unit-necrones-obelisk', 'necrones-guadanas-noche'),
    ('unit-necrones-monolith', 'necrones-megaestructuras-vivientes'),
    ('unit-necrones-tesseract-vault', 'necrones-megaestructuras-vivientes'),
    ('unit-necrones-seraptek-heavy-construct', 'necrones-megaestructuras-vivientes')
)
update public.unit_templates templates
set
  is_available = true,
  required_technology_node_id = technology_nodes.id
from assignments
join public.technology_nodes on technology_nodes.slug = assignments.technology_slug
where templates.slug = assignments.unit_slug
  and templates.faction_id = (select id from public.factions where slug = 'necrones');

do $$
declare
  v_faction_id uuid;
begin
  select id into v_faction_id from public.factions where slug = 'necrones';

  if v_faction_id is not null then
    perform public.refresh_available_technologies(v_faction_id);
  end if;
end;
$$;
-- END NECRON TROOP TECHNOLOGY ASSIGNMENTS

insert into public.relics (
  id, slug, faction_id, system_id, name, description, effect_text, icon_key, rarity, is_public
)
select
  public.seed_uuid('relic', data.slug),
  data.slug,
  factions.id,
  factions.capital_system_id,
  data.name,
  data.description,
  data.effect_text,
  data.icon_key,
  data.rarity,
  false
from (
  values
    ('relic-aeldari-krozius-chatarra', 'aeldari', 'Krozius de Chatarra Sagrada', 'Trofeo brutal cubierto de sellos arrancados a enemigos imperiales.', 'Reliquia narrativa: simboliza autoridad brutal y victorias de abordaje.', 'hammer', 'rare'),
    ('relic-aeldari-diente-gorko', 'aeldari', 'Diente de Gorko', 'Colmillo enorme engarzado en hierro candente.', 'Reliquia narrativa: inspira cargas temerarias y duelos de jefes.', 'tooth', 'common'),
    ('relic-necrones-orbe-hekatep', 'necrones', 'Orbe de Hekatep', 'Esfera de mando que pulsa con codigo dinastico verde.', 'Reliquia narrativa: ancla protocolos de reanimacion y autoridad de tumba.', 'orb', 'rare'),
    ('relic-necrones-cetro-fase', 'necrones', 'Cetro de Fase', 'Baston de nobleza con filo que vibra entre realidades.', 'Reliquia narrativa: marca derecho de conquista sobre mundos dormidos.', 'scepter', 'common'),
    ('relic-custodes-aquila-aurica', 'adeptus-custodes', 'Aquila Aurica', 'Fragmento dorado de una camara de juramento sellada.', 'Reliquia narrativa: representa vigilancia, pureza y autoridad del Trono.', 'aquila', 'rare'),
    ('relic-custodes-sello-auramita', 'adeptus-custodes', 'Sello de Auramita', 'Placa votiva marcada con juramentos de defensa imposibles.', 'Reliquia narrativa: inspira duelos ceremoniales y defensa inquebrantable.', 'shield', 'common'),
    ('relic-culto-garra-patriarca', 'cultos-genestealer', 'Garra del Patriarca', 'Taliman oseo oculto en un relicario de manufactorum.', 'Reliquia narrativa: refuerza la fe de celulas insurgentes.', 'claw', 'rare'),
    ('relic-culto-mascara-vidrio', 'cultos-genestealer', 'Mascara de Vidrio Negro', 'Mascara ritual usada por predicadores de la cuarta generacion.', 'Reliquia narrativa: simboliza infiltracion y control de masas.', 'mask', 'common'),
    ('relic-sombra-crux-eclipsada', 'space-marines', 'Crux Eclipsada', 'Insignia de honor ennegrecida por la luz de un sol muerto.', 'Reliquia narrativa: recuerda juramentos de purga y defensa del sector.', 'crux', 'rare'),
    ('relic-sombra-fragmento-narthex', 'space-marines', 'Fragmento del Narthex', 'Pieza de un altar sellado antes de la guerra actual.', 'Reliquia narrativa: legitima campanas de recuperacion sagrada.', 'reliquary', 'common'),
    ('relic-muerte-campana-putrida', 'legiones-daemonicas', 'Campana Putrida', 'Campana menor cubierta de oxido y letanias enfermas.', 'Reliquia narrativa: anuncia avances inevitables de la plaga.', 'bell', 'rare'),
    ('relic-muerte-incensario-morbus', 'legiones-daemonicas', 'Incensario de Morbus', 'Artefacto que exhala niebla toxica en susurros.', 'Reliquia narrativa: acompana procesiones de corrupcion y asedio.', 'censer', 'common')
) as data(slug, faction_slug, name, description, effect_text, icon_key, rarity)
join public.factions on factions.slug = data.faction_slug
where factions.capital_system_id is not null
on conflict (slug) do update
set faction_id = excluded.faction_id, system_id = coalesce(public.relics.system_id, excluded.system_id), name = excluded.name, description = excluded.description, effect_text = excluded.effect_text, icon_key = excluded.icon_key, rarity = excluded.rarity, is_public = excluded.is_public;

-- BEGIN GENERATED 40K MOVEMENTS
insert into public.movement_orders (
  id, faction_id, from_system_id, to_system_id, uridium_cost, started_at, arrival_at, status, path_system_ids, segment_count, duration_seconds
)
values
  (public.seed_uuid('movement_order', 'move-custodes-helios'), public.seed_uuid('faction', 'adeptus-custodes'), public.seed_uuid('system', 'arx-solum'), public.seed_uuid('system', 'helios-drift'), 1, now() - interval '10 seconds', now() + interval '30 seconds', 'moving', array[public.seed_uuid('system', 'arx-solum'), public.seed_uuid('system', 'helios-drift')]::uuid[], 1, 30),
  (public.seed_uuid('movement_order', 'move-aeldari-eclipse'), public.seed_uuid('faction', 'aeldari'), public.seed_uuid('system', 'rustmaw-run'), public.seed_uuid('system', 'eclipse-forge'), 1, now() - interval '10 seconds', now() + interval '30 seconds', 'moving', array[public.seed_uuid('system', 'rustmaw-run'), public.seed_uuid('system', 'eclipse-forge')]::uuid[], 1, 30),
  (public.seed_uuid('movement_order', 'move-space-lyra'), public.seed_uuid('faction', 'space-marines'), public.seed_uuid('system', 'narthex'), public.seed_uuid('system', 'lyra-terminus'), 1, now() - interval '10 seconds', now() + interval '30 seconds', 'moving', array[public.seed_uuid('system', 'narthex'), public.seed_uuid('system', 'lyra-terminus')]::uuid[], 1, 30),
  (public.seed_uuid('movement_order', 'move-cult-red-sabbath'), public.seed_uuid('faction', 'cultos-genestealer'), public.seed_uuid('system', 'mirrorcoil'), public.seed_uuid('system', 'red-sabbath'), 1, now() - interval '10 seconds', now() + interval '30 seconds', 'moving', array[public.seed_uuid('system', 'mirrorcoil'), public.seed_uuid('system', 'red-sabbath')]::uuid[], 1, 30),
  (public.seed_uuid('movement_order', 'move-necron-novem'), public.seed_uuid('faction', 'necrones'), public.seed_uuid('system', 'ghostlight'), public.seed_uuid('system', 'novem'), 1, now() - interval '10 seconds', now() + interval '30 seconds', 'moving', array[public.seed_uuid('system', 'ghostlight'), public.seed_uuid('system', 'novem')]::uuid[], 1, 30),
  (public.seed_uuid('movement_order', 'move-daemon-drusus'), public.seed_uuid('faction', 'legiones-daemonicas'), public.seed_uuid('system', 'plaguefall-bastion'), public.seed_uuid('system', 'drusus'), 1, now() - interval '10 seconds', now() + interval '30 seconds', 'moving', array[public.seed_uuid('system', 'plaguefall-bastion'), public.seed_uuid('system', 'drusus')]::uuid[], 1, 30),
  (public.seed_uuid('movement_order', 'move-agents-vesper'), public.seed_uuid('faction', 'agentes-imperium'), public.seed_uuid('system', 'orison'), public.seed_uuid('system', 'vesper-halo'), 1, now() - interval '10 seconds', now() + interval '30 seconds', 'moving', array[public.seed_uuid('system', 'orison'), public.seed_uuid('system', 'vesper-halo')]::uuid[], 1, 30)
on conflict (id) do update
set faction_id = excluded.faction_id, from_system_id = excluded.from_system_id, to_system_id = excluded.to_system_id, uridium_cost = excluded.uridium_cost, started_at = excluded.started_at, arrival_at = excluded.arrival_at, status = excluded.status, path_system_ids = excluded.path_system_ids, segment_count = excluded.segment_count, duration_seconds = excluded.duration_seconds;

insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
values
  (public.seed_uuid('movement_order', 'move-custodes-helios'), public.seed_uuid('campaign_unit', 'custodes-arx-caladius'), (select quantity from public.campaign_units where slug = 'custodes-arx-caladius')),
  (public.seed_uuid('movement_order', 'move-aeldari-eclipse'), public.seed_uuid('campaign_unit', 'aeldari-rust-dire-avengers'), (select quantity from public.campaign_units where slug = 'aeldari-rust-dire-avengers')),
  (public.seed_uuid('movement_order', 'move-space-lyra'), public.seed_uuid('campaign_unit', 'space-narthex-rhino'), (select quantity from public.campaign_units where slug = 'space-narthex-rhino')),
  (public.seed_uuid('movement_order', 'move-cult-red-sabbath'), public.seed_uuid('campaign_unit', 'cult-mirror-ridgerunner'), (select quantity from public.campaign_units where slug = 'cult-mirror-ridgerunner')),
  (public.seed_uuid('movement_order', 'move-necron-novem'), public.seed_uuid('campaign_unit', 'necron-ghost-wraiths'), (select quantity from public.campaign_units where slug = 'necron-ghost-wraiths')),
  (public.seed_uuid('movement_order', 'move-daemon-drusus'), public.seed_uuid('campaign_unit', 'daemon-plaguefall-screamers'), (select quantity from public.campaign_units where slug = 'daemon-plaguefall-screamers')),
  (public.seed_uuid('movement_order', 'move-agents-vesper'), public.seed_uuid('campaign_unit', 'agents-orison-deathwatch'), (select quantity from public.campaign_units where slug = 'agents-orison-deathwatch'))
on conflict (movement_order_id, unit_id) do update
set quantity_at_departure = excluded.quantity_at_departure;
-- END GENERATED 40K MOVEMENTS
insert into public.trade_offers (
  id, creator_faction_id, offer_type, resource_key, resource_amount, gold_amount, fee_gold, status, is_reserved, created_at, updated_at
)
values
  (public.seed_uuid('trade_offer', 'custodes-sell-minerals'), public.seed_uuid('faction', 'adeptus-custodes'), 'sell', 'minerals', 15, 8, 3, 'open', true, now() - interval '8 minutes', now() - interval '8 minutes'),
  (public.seed_uuid('trade_offer', 'aeldari-buy-supply'), public.seed_uuid('faction', 'aeldari'), 'buy', 'supply', 20, 5, 2, 'open', true, now() - interval '4 minutes', now() - interval '4 minutes')
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
where faction_id = public.seed_uuid('faction', 'adeptus-custodes');

update public.faction_resources
set gold = greatest(0, gold - 7)
where faction_id = public.seed_uuid('faction', 'aeldari');

insert into public.conflicts (id, slug, system_id, attacker_faction_id, defender_faction_id, status, blocked_until, notes)
values
  (public.seed_uuid('conflict', 'conflict-azur-trench'), 'conflict-azur-trench', public.seed_uuid('system', 'azur-trench'), public.seed_uuid('faction', 'aeldari'), public.seed_uuid('faction', 'adeptus-custodes'), 'pending', now() + interval '14 days', 'Aeldari y Adeptus Custodes han colisionado en la ruta central de la Zanja Azul. Pendiente de batalla fisica.'),
  (public.seed_uuid('conflict', 'conflict-ossuary-reach'), 'conflict-ossuary-reach', public.seed_uuid('system', 'ossuary-reach'), public.seed_uuid('faction', 'legiones-daemonicas'), public.seed_uuid('faction', 'necrones'), 'pending', now() + interval '14 days', 'Las Legiones Daemonicas intentan profanar criptas que los Necrones estan reactivando. Pendiente de batalla fisica.'),
  (public.seed_uuid('conflict', 'conflict-saint-veil'), 'conflict-saint-veil', public.seed_uuid('system', 'saint-veil'), public.seed_uuid('faction', 'space-marines'), public.seed_uuid('faction', 'cultos-genestealer'), 'pending', now() + interval '14 days', 'Los Space Marines han descubierto una insurreccion genestelar en el santuario. Pendiente de batalla fisica.')
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
