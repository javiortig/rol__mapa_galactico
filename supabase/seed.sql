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
delete from public.movement_order_units;
delete from public.movement_orders;
delete from public.campaign_units;
delete from public.conflicts;
delete from public.campaign_logs;
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
  (public.seed_uuid('system', 'azur-trench'), 'azur-trench', 'Azur Trench', 405, 390, 0.86, 'blue', 'Nebulosa navegable', 'war', null, now() + interval '30 minutes', 'Corredor azul con pozos de gravedad inestables. Orcos e Imperiales han chocado aqui.', false),
  (public.seed_uuid('system', 'ossuary-reach'), 'ossuary-reach', 'Ossuary Reach', 485, 625, 0.84, 'violet', 'Osario orbital', 'war', null, now() + interval '30 minutes', 'Campos funerarios en orbita baja, disputados por plaga y tecnologia necrona.', false),
  (public.seed_uuid('system', 'saint-veil'), 'saint-veil', 'Saint Veil', 650, 395, 0.86, 'yellow', 'Velo sagrado', 'war', null, now() + interval '30 minutes', 'Santuario velado donde la Sombra del Emperador combate una revuelta genestelar.', false),
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
set from_system_id = excluded.from_system_id, to_system_id = excluded.to_system_id, uridium_cost = excluded.uridium_cost, is_blocked = excluded.is_blocked;

insert into public.faction_resources (faction_id, supply, minerals, ancestral_stone, uridium, technology)
values
  (public.seed_uuid('faction', 'guardia-imperial'), 180, 130, 12, 24, 16),
  (public.seed_uuid('faction', 'orcos'), 190, 135, 7, 20, 16),
  (public.seed_uuid('faction', 'necrones'), 115, 155, 18, 22, 16),
  (public.seed_uuid('faction', 'culto-genestelar'), 185, 115, 13, 22, 16),
  (public.seed_uuid('faction', 'sombra-emperador'), 135, 130, 18, 26, 16),
  (public.seed_uuid('faction', 'guardia-muerte'), 155, 135, 15, 20, 16)
on conflict (faction_id) do update
set supply = excluded.supply, minerals = excluded.minerals, ancestral_stone = excluded.ancestral_stone, uridium = excluded.uridium, technology = excluded.technology, updated_at = now();

insert into public.system_production (system_id, supply_per_tick, minerals_per_tick, ancestral_stone_per_tick, uridium_per_tick, technology_per_tick)
values
  (public.seed_uuid('system', 'kharon-prime'), 9, 6, 0, 2, 0),
  (public.seed_uuid('system', 'helios-drift'), 1, 7, 0, 1, 0),
  (public.seed_uuid('system', 'arx-solum'), 5, 3, 0, 1, 0),
  (public.seed_uuid('system', 'sa-cea-gate'), 5, 4, 0, 5, 0),
  (public.seed_uuid('system', 'lyra-terminus'), 3, 1, 0, 4, 0),
  (public.seed_uuid('system', 'narthex'), 2, 0, 2, 1, 0),
  (public.seed_uuid('system', 'blackglass'), 3, 4, 2, 1, 0),
  (public.seed_uuid('system', 'red-sabbath'), 5, 2, 1, 1, 0),
  (public.seed_uuid('system', 'mirrorcoil'), 2, 2, 1, 3, 0),
  (public.seed_uuid('system', 'thokt-vault'), 0, 8, 3, 2, 0),
  (public.seed_uuid('system', 'novem'), 0, 7, 0, 1, 0),
  (public.seed_uuid('system', 'ghostlight'), 0, 2, 1, 3, 0),
  (public.seed_uuid('system', 'mordax'), 5, 6, 1, 2, 0),
  (public.seed_uuid('system', 'drusus'), 4, 4, 0, 1, 0),
  (public.seed_uuid('system', 'plaguefall-bastion'), 3, 5, 1, 1, 0),
  (public.seed_uuid('system', 'cinder-maw'), 4, 7, 0, 1, 0),
  (public.seed_uuid('system', 'eclipse-forge'), 1, 6, 0, 1, 0),
  (public.seed_uuid('system', 'rustmaw-run'), 3, 5, 0, 2, 0),
  (public.seed_uuid('system', 'azur-trench'), 0, 0, 0, 5, 0),
  (public.seed_uuid('system', 'ossuary-reach'), 0, 2, 2, 2, 0),
  (public.seed_uuid('system', 'saint-veil'), 2, 0, 2, 2, 0),
  (public.seed_uuid('system', 'orison'), 7, 1, 0, 0, 0),
  (public.seed_uuid('system', 'vesper-halo'), 0, 2, 1, 2, 0),
  (public.seed_uuid('system', 'pale-choir'), 0, 0, 2, 2, 0),
  (public.seed_uuid('system', 'ashen-road'), 1, 1, 0, 4, 0),
  (public.seed_uuid('system', 'sepulchre-nine'), 0, 2, 2, 0, 0),
  (public.seed_uuid('system', 'nexus-aster'), 2, 2, 1, 3, 0),
  (public.seed_uuid('system', 'argent-rift'), 0, 1, 0, 4, 0),
  (public.seed_uuid('system', 'voidfall-anchor'), 1, 2, 0, 3, 0),
  (public.seed_uuid('system', 'goregate'), 2, 3, 0, 2, 0)
on conflict (system_id) do update
set supply_per_tick = excluded.supply_per_tick, minerals_per_tick = excluded.minerals_per_tick, ancestral_stone_per_tick = excluded.ancestral_stone_per_tick, uridium_per_tick = excluded.uridium_per_tick, technology_per_tick = excluded.technology_per_tick;

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
  (public.seed_uuid('technology_effect', 'talleres-campana-building'), public.seed_uuid('technology_node', 'talleres-campana'), 'unlock_building_template', '{"building_template_slugs":["taller-campana"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'motores-guerra-units'), public.seed_uuid('technology_node', 'motores-guerra'), 'unlock_unit_template', '{"unit_template_slugs":["unit-orcos-deff-dread","unit-guardia-leman-russ","unit-culto-ridgerunner","unit-sombra-redemptor","unit-muerte-bloat-drone"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'blindaje-reforzado-minerals'), public.seed_uuid('technology_node', 'blindaje-reforzado'), 'recruitment_cost_discount', '{"category":"Vehiculo","resource":"minerals","percent":10}'::jsonb),
  (public.seed_uuid('technology_effect', 'estado-mayor-building'), public.seed_uuid('technology_node', 'estado-mayor-cruzada'), 'unlock_building_template', '{"building_template_slugs":["bastion-mando"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'nodo-logistico-building'), public.seed_uuid('technology_node', 'nodo-logistico'), 'unlock_building_template', '{"building_template_slugs":["nodo-logistico"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'manufactorum-building'), public.seed_uuid('technology_node', 'manufactorum-local'), 'unlock_building_template', '{"building_template_slugs":["manufactorum"]}'::jsonb),
  (public.seed_uuid('technology_effect', 'matrices-efficiency-general'), public.seed_uuid('technology_node', 'matrices-eficiencia'), 'recruitment_cost_discount', '{"category":"all","resource":"all","percent":5}'::jsonb)
on conflict (id) do update
set technology_node_id = excluded.technology_node_id, effect_type = excluded.effect_type, payload = excluded.payload;

insert into public.building_templates (id, slug, name, description, category, required_technology_node_id, is_available)
values
  (public.seed_uuid('building_template', 'bastion-mando'), 'bastion-mando', 'Bastion de mando', 'Centro de coordinacion militar para futuras acciones administrativas y mejoras de mando.', 'Mando', public.seed_uuid('technology_node', 'estado-mayor-cruzada'), true),
  (public.seed_uuid('building_template', 'taller-campana'), 'taller-campana', 'Taller de campana', 'Instalacion de mantenimiento para vehiculos, andadores y maquinas de guerra.', 'Militar', public.seed_uuid('technology_node', 'talleres-campana'), true),
  (public.seed_uuid('building_template', 'nodo-logistico'), 'nodo-logistico', 'Nodo logistico', 'Red de almacenaje y transferencia orbital para sostener conquistas.', 'Infraestructura', public.seed_uuid('technology_node', 'nodo-logistico'), true),
  (public.seed_uuid('building_template', 'manufactorum'), 'manufactorum', 'Manufactorum', 'Complejo industrial futuro para acelerar produccion y construccion.', 'Industrial', public.seed_uuid('technology_node', 'manufactorum-local'), true)
on conflict (slug) do update
set name = excluded.name, description = excluded.description, category = excluded.category, required_technology_node_id = excluded.required_technology_node_id, is_available = excluded.is_available, updated_at = now();

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

insert into public.unit_templates (
  id, slug, faction_id, name, category, points, default_quantity, supply_cost, minerals_cost, ancestral_stone_cost, uridium_cost, technology_cost, recruitment_time_seconds, notes, is_available, required_technology_node_id
)
values
  (public.seed_uuid('unit_template', 'unit-orcos-boyz'), 'unit-orcos-boyz', public.seed_uuid('faction', 'orcos'), 'Boyz', 'Infanteria', 80, 10, 12, 2, 0, 0, 0, 120, 'Masa brutal de combate cercano.', true, null),
  (public.seed_uuid('unit_template', 'unit-orcos-meganobz'), 'unit-orcos-meganobz', public.seed_uuid('faction', 'orcos'), 'Meganobz', 'Elite', 105, 3, 6, 5, 1, 0, 0, 240, 'Noblez armados con servoarmaduras improvisadas.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-orcos-deff-dread'), 'unit-orcos-deff-dread', public.seed_uuid('faction', 'orcos'), 'Deff Dread', 'Vehiculo', 135, 1, 2, 10, 1, 0, 0, 360, 'Maquina andante de metal, humo y mala intencion.', true, public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('unit_template', 'unit-necrones-warriors'), 'unit-necrones-warriors', public.seed_uuid('faction', 'necrones'), 'Necron Warriors', 'Infanteria', 80, 10, 8, 4, 0, 0, 0, 120, 'Linea inmortal reanimada desde las criptas.', true, null),
  (public.seed_uuid('unit_template', 'unit-necrones-immortals'), 'unit-necrones-immortals', public.seed_uuid('faction', 'necrones'), 'Immortals', 'Elite', 105, 5, 6, 5, 1, 0, 0, 240, 'Guerreros superiores con protocolos de elite.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-necrones-skorpekh'), 'unit-necrones-skorpekh', public.seed_uuid('faction', 'necrones'), 'Skorpekh Destroyers', 'Elite', 140, 3, 4, 7, 2, 0, 0, 360, 'Asesinos de fase con cuerpos disenados para la destruccion.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-guardia-cadian'), 'unit-guardia-cadian', public.seed_uuid('faction', 'guardia-imperial'), 'Cadian Shock Troops', 'Infanteria', 80, 10, 12, 2, 0, 0, 0, 120, 'Infanteria disciplinada lista para sostener la linea.', true, null),
  (public.seed_uuid('unit_template', 'unit-guardia-kasrkin'), 'unit-guardia-kasrkin', public.seed_uuid('faction', 'guardia-imperial'), 'Kasrkin', 'Elite', 105, 10, 8, 4, 1, 0, 0, 240, 'Veteranos de asalto con equipo especializado.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-guardia-leman-russ'), 'unit-guardia-leman-russ', public.seed_uuid('faction', 'guardia-imperial'), 'Leman Russ Battle Tank', 'Vehiculo', 145, 1, 2, 11, 1, 0, 0, 420, 'Blindado pesado de batalla para romper frentes.', true, public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('unit_template', 'unit-culto-neophytes'), 'unit-culto-neophytes', public.seed_uuid('faction', 'culto-genestelar'), 'Neophyte Hybrids', 'Infanteria', 80, 10, 12, 2, 0, 0, 0, 120, 'Celulas insurgentes armadas desde las profundidades.', true, null),
  (public.seed_uuid('unit_template', 'unit-culto-acolytes'), 'unit-culto-acolytes', public.seed_uuid('faction', 'culto-genestelar'), 'Acolyte Hybrids', 'Elite', 95, 5, 8, 3, 1, 0, 0, 240, 'Fanaticos hibridos preparados para ataques decisivos.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-culto-ridgerunner'), 'unit-culto-ridgerunner', public.seed_uuid('faction', 'culto-genestelar'), 'Achilles Ridgerunner', 'Vehiculo', 120, 1, 3, 8, 1, 0, 0, 360, 'Vehiculo de incursion y reconocimiento rapido.', true, public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('unit_template', 'unit-sombra-intercessors'), 'unit-sombra-intercessors', public.seed_uuid('faction', 'sombra-emperador'), 'Intercessor Squad', 'Infanteria', 105, 5, 8, 4, 1, 0, 0, 180, 'Astartes de linea con doctrina flexible.', true, null),
  (public.seed_uuid('unit_template', 'unit-sombra-terminators'), 'unit-sombra-terminators', public.seed_uuid('faction', 'sombra-emperador'), 'Terminator Squad', 'Elite', 160, 5, 5, 6, 3, 0, 0, 360, 'Veteranos con armadura tactica dreadnought.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-sombra-redemptor'), 'unit-sombra-redemptor', public.seed_uuid('faction', 'sombra-emperador'), 'Redemptor Dreadnought', 'Vehiculo', 185, 1, 2, 10, 3, 0, 0, 480, 'Dreadnought pesado para rupturas de linea.', true, public.seed_uuid('technology_node', 'motores-guerra')),
  (public.seed_uuid('unit_template', 'unit-muerte-poxwalkers'), 'unit-muerte-poxwalkers', public.seed_uuid('faction', 'guardia-muerte'), 'Poxwalkers', 'Infanteria', 70, 10, 12, 1, 0, 0, 0, 120, 'Multitud infectada que avanza sin miedo.', true, null),
  (public.seed_uuid('unit_template', 'unit-muerte-plague-marines'), 'unit-muerte-plague-marines', public.seed_uuid('faction', 'guardia-muerte'), 'Plague Marines', 'Infanteria', 115, 7, 8, 5, 1, 0, 0, 240, 'Marines de plaga resistentes y metodicos.', true, public.seed_uuid('technology_node', 'veteranos-guerra')),
  (public.seed_uuid('unit_template', 'unit-muerte-bloat-drone'), 'unit-muerte-bloat-drone', public.seed_uuid('faction', 'guardia-muerte'), 'Foetid Bloat-drone', 'Vehiculo', 145, 1, 3, 8, 2, 0, 0, 420, 'Dron demoniaco de apoyo y hostigamiento.', true, public.seed_uuid('technology_node', 'motores-guerra'))
on conflict (slug) do update
set faction_id = excluded.faction_id, name = excluded.name, category = excluded.category, points = excluded.points, default_quantity = excluded.default_quantity, supply_cost = excluded.supply_cost, minerals_cost = excluded.minerals_cost, ancestral_stone_cost = excluded.ancestral_stone_cost, uridium_cost = excluded.uridium_cost, technology_cost = excluded.technology_cost, recruitment_time_seconds = excluded.recruitment_time_seconds, notes = excluded.notes, is_available = excluded.is_available, required_technology_node_id = excluded.required_technology_node_id;

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

insert into public.conflicts (id, slug, system_id, attacker_faction_id, defender_faction_id, status, blocked_until, notes)
values
  (public.seed_uuid('conflict', 'conflict-azur-trench'), 'conflict-azur-trench', public.seed_uuid('system', 'azur-trench'), public.seed_uuid('faction', 'orcos'), public.seed_uuid('faction', 'guardia-imperial'), 'pending', now() + interval '30 minutes', 'Orcos e Imperiales han colisionado en la ruta central de la Zanja Azul. Pendiente de batalla fisica.'),
  (public.seed_uuid('conflict', 'conflict-ossuary-reach'), 'conflict-ossuary-reach', public.seed_uuid('system', 'ossuary-reach'), public.seed_uuid('faction', 'guardia-muerte'), public.seed_uuid('faction', 'necrones'), 'pending', now() + interval '30 minutes', 'La Guardia de la Muerte intenta profanar criptas que los Necrones estan reactivando. Pendiente de batalla fisica.'),
  (public.seed_uuid('conflict', 'conflict-saint-veil'), 'conflict-saint-veil', public.seed_uuid('system', 'saint-veil'), public.seed_uuid('faction', 'sombra-emperador'), public.seed_uuid('faction', 'culto-genestelar'), 'pending', now() + interval '30 minutes', 'La Sombra del Emperador ha descubierto una insurreccion genestelar en el santuario. Pendiente de batalla fisica.')
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
  conflict_block_duration_minutes = 30,
  next_resource_tick_at = now() + interval '24 hours',
  updated_at = now()
where id = 'default';
