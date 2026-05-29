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
delete from public.recruitment_queue;
delete from public.movement_orders;
delete from public.army_units;
delete from public.armies;
delete from public.conflicts;
delete from public.campaign_logs;
delete from public.system_production;
delete from public.system_edges;
delete from public.faction_resources;
delete from public.unit_templates;
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
set
  name = excluded.name,
  color = excluded.color;

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
  is_capital
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
  (public.seed_uuid('system', 'azur-trench'), 'azur-trench', 'Azur Trench', 405, 390, 0.86, 'blue', 'Nebulosa navegable', 'war', null, now() + interval '72 hours', 'Corredor azul con pozos de gravedad inestables. Orcos e Imperiales han chocado aqui.', false),
  (public.seed_uuid('system', 'ossuary-reach'), 'ossuary-reach', 'Ossuary Reach', 485, 625, 0.84, 'violet', 'Osario orbital', 'war', null, now() + interval '72 hours', 'Campos funerarios en orbita baja, disputados por plaga y tecnologia necrona.', false),
  (public.seed_uuid('system', 'saint-veil'), 'saint-veil', 'Saint Veil', 650, 395, 0.86, 'yellow', 'Velo sagrado', 'war', null, now() + interval '72 hours', 'Santuario velado donde la Sombra del Emperador combate una revuelta genestelar.', false),
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
set
  from_system_id = excluded.from_system_id,
  to_system_id = excluded.to_system_id,
  uridium_cost = excluded.uridium_cost,
  is_blocked = excluded.is_blocked;

insert into public.faction_resources (faction_id, supply, minerals, ancestral_stone, uridium, technology)
values
  (public.seed_uuid('faction', 'guardia-imperial'), 180, 130, 12, 24, 2),
  (public.seed_uuid('faction', 'orcos'), 190, 135, 7, 20, 1),
  (public.seed_uuid('faction', 'necrones'), 115, 155, 18, 22, 3),
  (public.seed_uuid('faction', 'culto-genestelar'), 185, 115, 13, 22, 2),
  (public.seed_uuid('faction', 'sombra-emperador'), 135, 130, 18, 26, 4),
  (public.seed_uuid('faction', 'guardia-muerte'), 155, 135, 15, 20, 2)
on conflict (faction_id) do update
set
  supply = excluded.supply,
  minerals = excluded.minerals,
  ancestral_stone = excluded.ancestral_stone,
  uridium = excluded.uridium,
  technology = excluded.technology,
  updated_at = now();

insert into public.system_production (system_id, supply_per_tick, minerals_per_tick, ancestral_stone_per_tick, uridium_per_tick, technology_per_tick)
values
  (public.seed_uuid('system', 'kharon-prime'), 9, 6, 0, 2, 0),
  (public.seed_uuid('system', 'helios-drift'), 1, 7, 0, 1, 0),
  (public.seed_uuid('system', 'arx-solum'), 5, 3, 0, 1, 0),
  (public.seed_uuid('system', 'sa-cea-gate'), 5, 4, 0, 5, 1),
  (public.seed_uuid('system', 'lyra-terminus'), 3, 1, 0, 4, 0),
  (public.seed_uuid('system', 'narthex'), 2, 0, 2, 1, 0),
  (public.seed_uuid('system', 'blackglass'), 3, 4, 2, 1, 0),
  (public.seed_uuid('system', 'red-sabbath'), 5, 2, 1, 1, 0),
  (public.seed_uuid('system', 'mirrorcoil'), 2, 2, 1, 3, 0),
  (public.seed_uuid('system', 'thokt-vault'), 0, 8, 3, 2, 1),
  (public.seed_uuid('system', 'novem'), 0, 7, 0, 1, 0),
  (public.seed_uuid('system', 'ghostlight'), 0, 2, 1, 3, 1),
  (public.seed_uuid('system', 'mordax'), 5, 6, 1, 2, 0),
  (public.seed_uuid('system', 'drusus'), 4, 4, 0, 1, 0),
  (public.seed_uuid('system', 'plaguefall-bastion'), 3, 5, 1, 1, 0),
  (public.seed_uuid('system', 'cinder-maw'), 4, 7, 0, 1, 0),
  (public.seed_uuid('system', 'eclipse-forge'), 1, 6, 0, 1, 1),
  (public.seed_uuid('system', 'rustmaw-run'), 3, 5, 0, 2, 0),
  (public.seed_uuid('system', 'azur-trench'), 0, 0, 0, 5, 0),
  (public.seed_uuid('system', 'ossuary-reach'), 0, 2, 2, 2, 0),
  (public.seed_uuid('system', 'saint-veil'), 2, 0, 2, 2, 1),
  (public.seed_uuid('system', 'orison'), 7, 1, 0, 0, 0),
  (public.seed_uuid('system', 'vesper-halo'), 0, 2, 1, 2, 1),
  (public.seed_uuid('system', 'pale-choir'), 0, 0, 2, 2, 0),
  (public.seed_uuid('system', 'ashen-road'), 1, 1, 0, 4, 0),
  (public.seed_uuid('system', 'sepulchre-nine'), 0, 2, 2, 0, 0),
  (public.seed_uuid('system', 'nexus-aster'), 2, 2, 1, 3, 1),
  (public.seed_uuid('system', 'argent-rift'), 0, 1, 0, 4, 0),
  (public.seed_uuid('system', 'voidfall-anchor'), 1, 2, 0, 3, 1),
  (public.seed_uuid('system', 'goregate'), 2, 3, 0, 2, 0)
on conflict (system_id) do update
set
  supply_per_tick = excluded.supply_per_tick,
  minerals_per_tick = excluded.minerals_per_tick,
  ancestral_stone_per_tick = excluded.ancestral_stone_per_tick,
  uridium_per_tick = excluded.uridium_per_tick,
  technology_per_tick = excluded.technology_per_tick;

insert into public.armies (id, slug, faction_id, name, current_system_id, status, points_total, is_visible_publicly)
values
  (public.seed_uuid('army', 'imperial-kharon-garrison'), 'imperial-kharon-garrison', public.seed_uuid('faction', 'guardia-imperial'), 'Guarnicion de Kharon', public.seed_uuid('system', 'kharon-prime'), 'ready', 510, false),
  (public.seed_uuid('army', 'imperial-arx-front'), 'imperial-arx-front', public.seed_uuid('faction', 'guardia-imperial'), '117o Grupo de Choque', public.seed_uuid('system', 'arx-solum'), 'ready', 760, false),
  (public.seed_uuid('army', 'imperial-helios-column'), 'imperial-helios-column', public.seed_uuid('faction', 'guardia-imperial'), 'Columna Helios', public.seed_uuid('system', 'kharon-prime'), 'moving', 360, false),
  (public.seed_uuid('army', 'imperial-azur-line'), 'imperial-azur-line', public.seed_uuid('faction', 'guardia-imperial'), 'Linea de Azur', public.seed_uuid('system', 'azur-trench'), 'in_war', 690, false),
  (public.seed_uuid('army', 'ork-cinder-garrison'), 'ork-cinder-garrison', public.seed_uuid('faction', 'orcos'), 'Kampamento de Cinder Maw', public.seed_uuid('system', 'cinder-maw'), 'ready', 560, false),
  (public.seed_uuid('army', 'ork-rustmaw-front'), 'ork-rustmaw-front', public.seed_uuid('faction', 'orcos'), 'Peaje de Rustmaw', public.seed_uuid('system', 'rustmaw-run'), 'ready', 790, false),
  (public.seed_uuid('army', 'ork-eclipse-riders'), 'ork-eclipse-riders', public.seed_uuid('faction', 'orcos'), 'Jinetes de Eclipse', public.seed_uuid('system', 'cinder-maw'), 'moving', 380, false),
  (public.seed_uuid('army', 'ork-azur-waaagh'), 'ork-azur-waaagh', public.seed_uuid('faction', 'orcos'), 'Waaagh de la Zanja Azul', public.seed_uuid('system', 'azur-trench'), 'in_war', 720, false),
  (public.seed_uuid('army', 'sombra-gate-watch'), 'sombra-gate-watch', public.seed_uuid('faction', 'sombra-emperador'), 'Guardia de Sa''cea Gate', public.seed_uuid('system', 'sa-cea-gate'), 'ready', 620, false),
  (public.seed_uuid('army', 'sombra-narthex-spear'), 'sombra-narthex-spear', public.seed_uuid('faction', 'sombra-emperador'), 'Punta de Lanza Narthex', public.seed_uuid('system', 'narthex'), 'ready', 830, false),
  (public.seed_uuid('army', 'sombra-lyra-talon'), 'sombra-lyra-talon', public.seed_uuid('faction', 'sombra-emperador'), 'Garra de Lyra', public.seed_uuid('system', 'sa-cea-gate'), 'moving', 430, false),
  (public.seed_uuid('army', 'sombra-saint-veil'), 'sombra-saint-veil', public.seed_uuid('faction', 'sombra-emperador'), 'Escuadra del Velo', public.seed_uuid('system', 'saint-veil'), 'in_war', 760, false),
  (public.seed_uuid('army', 'cult-blackglass-garrison'), 'cult-blackglass-garrison', public.seed_uuid('faction', 'culto-genestelar'), 'Celula de Blackglass', public.seed_uuid('system', 'blackglass'), 'ready', 520, false),
  (public.seed_uuid('army', 'cult-mirrorcoil-front'), 'cult-mirrorcoil-front', public.seed_uuid('faction', 'culto-genestelar'), 'Alzamiento de Mirrorcoil', public.seed_uuid('system', 'mirrorcoil'), 'ready', 740, false),
  (public.seed_uuid('army', 'cult-sabbath-convoy'), 'cult-sabbath-convoy', public.seed_uuid('faction', 'culto-genestelar'), 'Convoy del Sabbath', public.seed_uuid('system', 'blackglass'), 'moving', 340, false),
  (public.seed_uuid('army', 'cult-saint-revolt'), 'cult-saint-revolt', public.seed_uuid('faction', 'culto-genestelar'), 'Revuelta del Velo', public.seed_uuid('system', 'saint-veil'), 'in_war', 700, false),
  (public.seed_uuid('army', 'necron-thokt-phalanx'), 'necron-thokt-phalanx', public.seed_uuid('faction', 'necrones'), 'Falange Thokt', public.seed_uuid('system', 'thokt-vault'), 'ready', 620, false),
  (public.seed_uuid('army', 'necron-ghostlight-front'), 'necron-ghostlight-front', public.seed_uuid('faction', 'necrones'), 'Cohorte Ghostlight', public.seed_uuid('system', 'ghostlight'), 'ready', 810, false),
  (public.seed_uuid('army', 'necron-novem-cohort'), 'necron-novem-cohort', public.seed_uuid('faction', 'necrones'), 'Cohorte Novem', public.seed_uuid('system', 'thokt-vault'), 'moving', 420, false),
  (public.seed_uuid('army', 'necron-ossuary-reclaimers'), 'necron-ossuary-reclaimers', public.seed_uuid('faction', 'necrones'), 'Reclamadores del Osario', public.seed_uuid('system', 'ossuary-reach'), 'in_war', 760, false),
  (public.seed_uuid('army', 'death-mordax-vector'), 'death-mordax-vector', public.seed_uuid('faction', 'guardia-muerte'), 'Vector de Mordax', public.seed_uuid('system', 'mordax'), 'ready', 610, false),
  (public.seed_uuid('army', 'death-plaguefall-front'), 'death-plaguefall-front', public.seed_uuid('faction', 'guardia-muerte'), 'Hueste Plaguefall', public.seed_uuid('system', 'plaguefall-bastion'), 'ready', 830, false),
  (public.seed_uuid('army', 'death-drusus-procession'), 'death-drusus-procession', public.seed_uuid('faction', 'guardia-muerte'), 'Procesion de Drusus', public.seed_uuid('system', 'mordax'), 'moving', 390, false),
  (public.seed_uuid('army', 'death-ossuary-pox'), 'death-ossuary-pox', public.seed_uuid('faction', 'guardia-muerte'), 'Marea Pox del Osario', public.seed_uuid('system', 'ossuary-reach'), 'in_war', 710, false)
on conflict (slug) do update
set
  faction_id = excluded.faction_id,
  name = excluded.name,
  current_system_id = excluded.current_system_id,
  status = excluded.status,
  points_total = excluded.points_total,
  is_visible_publicly = excluded.is_visible_publicly,
  updated_at = now();

insert into public.army_units (id, army_id, name, points, quantity, experience, rank, enhancement_text)
values
  (public.seed_uuid('army_unit', 'imperial-kharon-cadians'), public.seed_uuid('army', 'imperial-kharon-garrison'), 'Cadian Shock Troops', 80, 3, 1, 'Linea', null),
  (public.seed_uuid('army_unit', 'imperial-arx-kasrkin'), public.seed_uuid('army', 'imperial-arx-front'), 'Kasrkin', 105, 2, 2, 'Veteranos', 'Doctrina de frontera'),
  (public.seed_uuid('army_unit', 'imperial-helios-sentinels'), public.seed_uuid('army', 'imperial-helios-column'), 'Sentinel Squadron', 180, 1, 0, 'Reconocimiento', null),
  (public.seed_uuid('army_unit', 'imperial-azur-tank'), public.seed_uuid('army', 'imperial-azur-line'), 'Leman Russ Battle Tank', 145, 2, 1, 'Blindados', null),
  (public.seed_uuid('army_unit', 'ork-cinder-boyz'), public.seed_uuid('army', 'ork-cinder-garrison'), 'Boyz', 80, 4, 1, 'Marea', null),
  (public.seed_uuid('army_unit', 'ork-rustmaw-meganobz'), public.seed_uuid('army', 'ork-rustmaw-front'), 'Meganobz', 105, 2, 2, 'Noblez', 'Armaduras remachadas'),
  (public.seed_uuid('army_unit', 'ork-eclipse-buggies'), public.seed_uuid('army', 'ork-eclipse-riders'), 'Warbikers', 140, 1, 0, 'Movil', null),
  (public.seed_uuid('army_unit', 'ork-azur-dread'), public.seed_uuid('army', 'ork-azur-waaagh'), 'Deff Dread', 135, 2, 1, 'Chatarreros', null),
  (public.seed_uuid('army_unit', 'sombra-gate-intercessors'), public.seed_uuid('army', 'sombra-gate-watch'), 'Intercessor Squad', 105, 2, 1, 'Linea', null),
  (public.seed_uuid('army_unit', 'sombra-narthex-terminators'), public.seed_uuid('army', 'sombra-narthex-spear'), 'Terminator Squad', 160, 2, 2, 'Veteranos', 'Juramento del santuario'),
  (public.seed_uuid('army_unit', 'sombra-lyra-inceptors'), public.seed_uuid('army', 'sombra-lyra-talon'), 'Inceptor Squad', 130, 1, 0, 'Asalto', null),
  (public.seed_uuid('army_unit', 'sombra-saint-redemptor'), public.seed_uuid('army', 'sombra-saint-veil'), 'Redemptor Dreadnought', 185, 1, 1, 'Anciano', null),
  (public.seed_uuid('army_unit', 'cult-blackglass-neophytes'), public.seed_uuid('army', 'cult-blackglass-garrison'), 'Neophyte Hybrids', 80, 4, 1, 'Celula', null),
  (public.seed_uuid('army_unit', 'cult-mirrorcoil-acolytes'), public.seed_uuid('army', 'cult-mirrorcoil-front'), 'Acolyte Hybrids', 95, 3, 2, 'Alzados', 'Red de tuneles'),
  (public.seed_uuid('army_unit', 'cult-sabbath-ridgerunner'), public.seed_uuid('army', 'cult-sabbath-convoy'), 'Achilles Ridgerunner', 120, 1, 0, 'Movil', null),
  (public.seed_uuid('army_unit', 'cult-saint-neophytes'), public.seed_uuid('army', 'cult-saint-revolt'), 'Neophyte Hybrids', 80, 5, 1, 'Insurgentes', null),
  (public.seed_uuid('army_unit', 'necron-thokt-warriors'), public.seed_uuid('army', 'necron-thokt-phalanx'), 'Necron Warriors', 80, 3, 1, 'Linea', null),
  (public.seed_uuid('army_unit', 'necron-ghostlight-skorpekh'), public.seed_uuid('army', 'necron-ghostlight-front'), 'Skorpekh Destroyers', 140, 2, 2, 'Destructores', 'Protocolos de cosecha'),
  (public.seed_uuid('army_unit', 'necron-novem-immortals'), public.seed_uuid('army', 'necron-novem-cohort'), 'Immortals', 105, 2, 0, 'Escolta', null),
  (public.seed_uuid('army_unit', 'necron-ossuary-warriors'), public.seed_uuid('army', 'necron-ossuary-reclaimers'), 'Necron Warriors', 80, 4, 1, 'Reclamadores', null),
  (public.seed_uuid('army_unit', 'death-mordax-poxwalkers'), public.seed_uuid('army', 'death-mordax-vector'), 'Poxwalkers', 70, 4, 1, 'Marea', null),
  (public.seed_uuid('army_unit', 'death-plaguefall-marines'), public.seed_uuid('army', 'death-plaguefall-front'), 'Plague Marines', 115, 3, 2, 'Veteranos', 'Nube toxica'),
  (public.seed_uuid('army_unit', 'death-drusus-drone'), public.seed_uuid('army', 'death-drusus-procession'), 'Foetid Bloat-drone', 145, 1, 0, 'Movil', null),
  (public.seed_uuid('army_unit', 'death-ossuary-marines'), public.seed_uuid('army', 'death-ossuary-pox'), 'Plague Marines', 115, 2, 1, 'Plaga', null)
on conflict (id) do update
set
  army_id = excluded.army_id,
  name = excluded.name,
  points = excluded.points,
  quantity = excluded.quantity,
  experience = excluded.experience,
  rank = excluded.rank,
  enhancement_text = excluded.enhancement_text,
  updated_at = now();

insert into public.unit_templates (
  id,
  slug,
  faction_id,
  name,
  category,
  points,
  supply_cost,
  minerals_cost,
  ancestral_stone_cost,
  uridium_cost,
  technology_cost,
  recruitment_time_seconds,
  notes,
  is_available
)
values
  (public.seed_uuid('unit_template', 'unit-orcos-boyz'), 'unit-orcos-boyz', public.seed_uuid('faction', 'orcos'), 'Boyz', 'Infanteria', 80, 12, 2, 0, 0, 0, 7200, 'Masa brutal de combate cercano.', true),
  (public.seed_uuid('unit_template', 'unit-orcos-meganobz'), 'unit-orcos-meganobz', public.seed_uuid('faction', 'orcos'), 'Meganobz', 'Elite', 105, 6, 5, 1, 0, 0, 14400, 'Noblez armados con servoarmaduras improvisadas.', true),
  (public.seed_uuid('unit_template', 'unit-orcos-deff-dread'), 'unit-orcos-deff-dread', public.seed_uuid('faction', 'orcos'), 'Deff Dread', 'Vehiculo', 135, 2, 10, 1, 0, 0, 21600, 'Maquina andante de metal, humo y mala intencion.', true),
  (public.seed_uuid('unit_template', 'unit-necrones-warriors'), 'unit-necrones-warriors', public.seed_uuid('faction', 'necrones'), 'Necron Warriors', 'Infanteria', 80, 8, 4, 0, 0, 0, 7200, 'Linea inmortal reanimada desde las criptas.', true),
  (public.seed_uuid('unit_template', 'unit-necrones-immortals'), 'unit-necrones-immortals', public.seed_uuid('faction', 'necrones'), 'Immortals', 'Elite', 105, 6, 5, 1, 0, 0, 14400, 'Guerreros superiores con protocolos de elite.', true),
  (public.seed_uuid('unit_template', 'unit-necrones-skorpekh'), 'unit-necrones-skorpekh', public.seed_uuid('faction', 'necrones'), 'Skorpekh Destroyers', 'Elite', 140, 4, 7, 2, 0, 0, 21600, 'Asesinos de fase con cuerpos disenados para la destruccion.', true),
  (public.seed_uuid('unit_template', 'unit-guardia-cadian'), 'unit-guardia-cadian', public.seed_uuid('faction', 'guardia-imperial'), 'Cadian Shock Troops', 'Infanteria', 80, 12, 2, 0, 0, 0, 7200, 'Infanteria disciplinada lista para sostener la linea.', true),
  (public.seed_uuid('unit_template', 'unit-guardia-kasrkin'), 'unit-guardia-kasrkin', public.seed_uuid('faction', 'guardia-imperial'), 'Kasrkin', 'Elite', 105, 8, 4, 1, 0, 0, 14400, 'Veteranos de asalto con equipo especializado.', true),
  (public.seed_uuid('unit_template', 'unit-guardia-leman-russ'), 'unit-guardia-leman-russ', public.seed_uuid('faction', 'guardia-imperial'), 'Leman Russ Battle Tank', 'Vehiculo', 145, 2, 11, 1, 0, 0, 25200, 'Blindado pesado de batalla para romper frentes.', true),
  (public.seed_uuid('unit_template', 'unit-culto-neophytes'), 'unit-culto-neophytes', public.seed_uuid('faction', 'culto-genestelar'), 'Neophyte Hybrids', 'Infanteria', 80, 12, 2, 0, 0, 0, 7200, 'Celulas insurgentes armadas desde las profundidades.', true),
  (public.seed_uuid('unit_template', 'unit-culto-acolytes'), 'unit-culto-acolytes', public.seed_uuid('faction', 'culto-genestelar'), 'Acolyte Hybrids', 'Elite', 95, 8, 3, 1, 0, 0, 14400, 'Fanaticos hibridos preparados para ataques decisivos.', true),
  (public.seed_uuid('unit_template', 'unit-culto-ridgerunner'), 'unit-culto-ridgerunner', public.seed_uuid('faction', 'culto-genestelar'), 'Achilles Ridgerunner', 'Vehiculo', 120, 3, 8, 1, 0, 0, 21600, 'Vehiculo de incursion y reconocimiento rapido.', true),
  (public.seed_uuid('unit_template', 'unit-sombra-intercessors'), 'unit-sombra-intercessors', public.seed_uuid('faction', 'sombra-emperador'), 'Intercessor Squad', 'Infanteria', 105, 8, 4, 1, 0, 0, 10800, 'Astartes de linea con doctrina flexible.', true),
  (public.seed_uuid('unit_template', 'unit-sombra-terminators'), 'unit-sombra-terminators', public.seed_uuid('faction', 'sombra-emperador'), 'Terminator Squad', 'Elite', 160, 5, 6, 3, 0, 0, 21600, 'Veteranos con armadura tactica dreadnought.', true),
  (public.seed_uuid('unit_template', 'unit-sombra-redemptor'), 'unit-sombra-redemptor', public.seed_uuid('faction', 'sombra-emperador'), 'Redemptor Dreadnought', 'Vehiculo', 185, 2, 10, 3, 0, 0, 28800, 'Dreadnought pesado para rupturas de linea.', true),
  (public.seed_uuid('unit_template', 'unit-muerte-poxwalkers'), 'unit-muerte-poxwalkers', public.seed_uuid('faction', 'guardia-muerte'), 'Poxwalkers', 'Infanteria', 70, 12, 1, 0, 0, 0, 7200, 'Multitud infectada que avanza sin miedo.', true),
  (public.seed_uuid('unit_template', 'unit-muerte-plague-marines'), 'unit-muerte-plague-marines', public.seed_uuid('faction', 'guardia-muerte'), 'Plague Marines', 'Infanteria', 115, 8, 5, 1, 0, 0, 14400, 'Marines de plaga resistentes y metodicos.', true),
  (public.seed_uuid('unit_template', 'unit-muerte-bloat-drone'), 'unit-muerte-bloat-drone', public.seed_uuid('faction', 'guardia-muerte'), 'Foetid Bloat-drone', 'Vehiculo', 145, 3, 8, 2, 0, 0, 25200, 'Dron demoniaco de apoyo y hostigamiento.', true)
on conflict (slug) do update
set
  faction_id = excluded.faction_id,
  name = excluded.name,
  category = excluded.category,
  points = excluded.points,
  supply_cost = excluded.supply_cost,
  minerals_cost = excluded.minerals_cost,
  ancestral_stone_cost = excluded.ancestral_stone_cost,
  uridium_cost = excluded.uridium_cost,
  technology_cost = excluded.technology_cost,
  recruitment_time_seconds = excluded.recruitment_time_seconds,
  notes = excluded.notes,
  is_available = excluded.is_available;

insert into public.movement_orders (
  id,
  army_id,
  faction_id,
  from_system_id,
  to_system_id,
  uridium_cost,
  started_at,
  arrival_at,
  status
)
values
  (public.seed_uuid('movement_order', 'move-imperial-helios'), public.seed_uuid('army', 'imperial-helios-column'), public.seed_uuid('faction', 'guardia-imperial'), public.seed_uuid('system', 'kharon-prime'), public.seed_uuid('system', 'helios-drift'), 1, now() - interval '1 hour', now() + interval '5 hours', 'moving'),
  (public.seed_uuid('movement_order', 'move-ork-eclipse'), public.seed_uuid('army', 'ork-eclipse-riders'), public.seed_uuid('faction', 'orcos'), public.seed_uuid('system', 'cinder-maw'), public.seed_uuid('system', 'eclipse-forge'), 1, now() - interval '2 hours', now() + interval '3 hours', 'moving'),
  (public.seed_uuid('movement_order', 'move-sombra-lyra'), public.seed_uuid('army', 'sombra-lyra-talon'), public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('system', 'sa-cea-gate'), public.seed_uuid('system', 'lyra-terminus'), 1, now() - interval '45 minutes', now() + interval '4 hours', 'moving'),
  (public.seed_uuid('movement_order', 'move-cult-sabbath'), public.seed_uuid('army', 'cult-sabbath-convoy'), public.seed_uuid('faction', 'culto-genestelar'), public.seed_uuid('system', 'blackglass'), public.seed_uuid('system', 'red-sabbath'), 1, now() - interval '90 minutes', now() + interval '6 hours', 'moving'),
  (public.seed_uuid('movement_order', 'move-necron-novem'), public.seed_uuid('army', 'necron-novem-cohort'), public.seed_uuid('faction', 'necrones'), public.seed_uuid('system', 'thokt-vault'), public.seed_uuid('system', 'novem'), 1, now() - interval '30 minutes', now() + interval '7 hours', 'moving'),
  (public.seed_uuid('movement_order', 'move-death-drusus'), public.seed_uuid('army', 'death-drusus-procession'), public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('system', 'mordax'), public.seed_uuid('system', 'drusus'), 1, now() - interval '75 minutes', now() + interval '5 hours', 'moving')
on conflict (id) do update
set
  army_id = excluded.army_id,
  faction_id = excluded.faction_id,
  from_system_id = excluded.from_system_id,
  to_system_id = excluded.to_system_id,
  uridium_cost = excluded.uridium_cost,
  started_at = excluded.started_at,
  arrival_at = excluded.arrival_at,
  status = excluded.status;

insert into public.conflicts (
  id,
  slug,
  system_id,
  attacker_faction_id,
  defender_faction_id,
  status,
  blocked_until,
  notes
)
values
  (public.seed_uuid('conflict', 'conflict-azur-trench'), 'conflict-azur-trench', public.seed_uuid('system', 'azur-trench'), public.seed_uuid('faction', 'orcos'), public.seed_uuid('faction', 'guardia-imperial'), 'pending', now() + interval '72 hours', 'Orcos e Imperiales han colisionado en la ruta central de la Zanja Azul. Pendiente de batalla fisica.'),
  (public.seed_uuid('conflict', 'conflict-ossuary-reach'), 'conflict-ossuary-reach', public.seed_uuid('system', 'ossuary-reach'), public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('faction', 'necrones'), 'pending', now() + interval '72 hours', 'La Guardia de la Muerte intenta profanar criptas que los Necrones estan reactivando. Pendiente de batalla fisica.'),
  (public.seed_uuid('conflict', 'conflict-saint-veil'), 'conflict-saint-veil', public.seed_uuid('system', 'saint-veil'), public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('faction', 'culto-genestelar'), 'pending', now() + interval '72 hours', 'La Sombra del Emperador ha descubierto una insurreccion genestelar en el santuario. Pendiente de batalla fisica.')
on conflict (slug) do update
set
  system_id = excluded.system_id,
  attacker_faction_id = excluded.attacker_faction_id,
  defender_faction_id = excluded.defender_faction_id,
  status = excluded.status,
  winner_faction_id = null,
  blocked_until = excluded.blocked_until,
  notes = excluded.notes,
  resolved_at = null;

insert into public.missions (
  id,
  system_id,
  title,
  narrative_description,
  recommended_points,
  objectives,
  special_rules,
  victory_conditions
)
values
  (public.seed_uuid('mission', 'mission-azur-trench'), public.seed_uuid('system', 'azur-trench'), 'La Zanja Azul', 'Una nebulosa de gases ionizados parte el campo de batalla en corredores estrechos.', '1000-1500 pts', 'Controlar las balizas de navegacion al final de la batalla fisica.', 'Las unidades que avancen por el centro cuentan como expuestas por la luz azul.', 'El ganador decide el control final de Azur Trench.'),
  (public.seed_uuid('mission', 'mission-ossuary-reach'), public.seed_uuid('system', 'ossuary-reach'), 'Ecos del Osario', 'Criptas rotas y fosas contaminadas hacen que cada metro sea una amenaza.', '1000-1500 pts', 'Asegurar tres criptas antes del final de la partida.', 'El terreno central se considera peligroso por emanaciones toxicas y energia necrodermis.', 'El ganador decide el control final de Ossuary Reach.'),
  (public.seed_uuid('mission', 'mission-saint-veil'), public.seed_uuid('system', 'saint-veil'), 'El Velo Sagrado', 'Un santuario en sombra se convierte en campo de purga e insurreccion.', '1000-1500 pts', 'Mantener el altar central y dos accesos laterales.', 'La primera ronda usa visibilidad reducida por incienso, humo y apagones.', 'El ganador decide el control final de Saint Veil.')
on conflict (id) do update
set
  system_id = excluded.system_id,
  title = excluded.title,
  narrative_description = excluded.narrative_description,
  recommended_points = excluded.recommended_points,
  objectives = excluded.objectives,
  special_rules = excluded.special_rules,
  victory_conditions = excluded.victory_conditions,
  updated_at = now();

insert into public.system_special_objects (id, system_id, name, type, public_description, is_public)
values
  (public.seed_uuid('system_special_object', 'obj-nexus-aster'), public.seed_uuid('system', 'nexus-aster'), 'Baliza del Nexus', 'technology', 'Lecturas verdes y doradas en el nodo central.', true),
  (public.seed_uuid('system_special_object', 'obj-saint-veil'), public.seed_uuid('system', 'saint-veil'), 'Reliquia velada', 'relic', 'Un relicario emite pulsos violetas bajo el santuario.', true),
  (public.seed_uuid('system_special_object', 'obj-ossuary-reach'), public.seed_uuid('system', 'ossuary-reach'), 'Cripta fracturada', 'anomaly', 'Senales intermitentes salen de tumbas orbitales abiertas.', true)
on conflict (id) do update
set
  system_id = excluded.system_id,
  name = excluded.name,
  type = excluded.type,
  public_description = excluded.public_description,
  is_public = excluded.is_public;

update public.campaign_settings
set
  resource_tick_interval_hours = 24,
  next_resource_tick_at = now() + interval '24 hours',
  updated_at = now()
where id = 'default';
