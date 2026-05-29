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
  (public.seed_uuid('system', 'kharon-prime'), 'kharon-prime', 'Kharon Prime', 120, 260, 1.2, 'blue', 'Capital fortificada', 'controlled', public.seed_uuid('faction', 'guardia-imperial'), null, 'Bastion manufactorum con astropuerto militar.', true),
  (public.seed_uuid('system', 'sa-cea-gate'), 'sa-cea-gate', 'Sa''cea Gate', 790, 180, 1.2, 'white', 'Capital orbital', 'controlled', public.seed_uuid('faction', 'sombra-emperador'), null, 'Estacion de paso con matrices de navegacion de largo alcance.', true),
  (public.seed_uuid('system', 'thokt-vault'), 'thokt-vault', 'Thokt Vault', 710, 610, 1.2, 'green', 'Capital tumba', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Cripta silenciosa rodeada de energia verdosa.', true),
  (public.seed_uuid('system', 'mordax'), 'mordax', 'Mordax', 285, 690, 1.2, 'red', 'Capital corrupta', 'war', public.seed_uuid('faction', 'guardia-muerte'), now() + interval '36 hours', 'Mundo industrial desgarrado por senales disformes.', true),
  (public.seed_uuid('system', 'helios-drift'), 'helios-drift', 'Helios Drift', 265, 180, 0.9, 'orange', 'Cinturon minero', 'neutral', null, null, 'Asteroides ricos en mineral, mal cartografiados.', false),
  (public.seed_uuid('system', 'vesper-halo'), 'vesper-halo', 'Vesper Halo', 435, 140, 0.85, 'violet', 'Anillo orbital', 'neutral', null, null, 'Ruinas orbitales con ecos de tecnologia antigua.', false),
  (public.seed_uuid('system', 'narthex'), 'narthex', 'Narthex', 590, 245, 0.95, 'yellow', 'Santuario sellado', 'controlled', public.seed_uuid('faction', 'sombra-emperador'), null, 'Complejo sacro con rutas de descenso peligrosas.', false),
  (public.seed_uuid('system', 'cinder-maw'), 'cinder-maw', 'Cinder Maw', 230, 420, 0.8, 'orange', 'Mundo volcanico', 'controlled', public.seed_uuid('faction', 'orcos'), null, 'Forjas geotermicas y tormentas de ceniza.', true),
  (public.seed_uuid('system', 'azur-trench'), 'azur-trench', 'Azur Trench', 395, 355, 0.75, 'blue', 'Nebulosa navegable', 'neutral', null, null, 'Corredor azul con pozos de gravedad inestables.', false),
  (public.seed_uuid('system', 'orison'), 'orison', 'Orison', 555, 390, 0.9, 'yellow', 'Colonia agricola', 'controlled', public.seed_uuid('faction', 'guardia-imperial'), null, 'Graneros presurizados y bastiones de defensa civil.', false),
  (public.seed_uuid('system', 'blackglass'), 'blackglass', 'Blackglass', 715, 395, 0.8, 'white', 'Mundo cristalino', 'controlled', public.seed_uuid('faction', 'culto-genestelar'), null, 'Piedra ancestral bajo oceanos de vidrio oscuro.', true),
  (public.seed_uuid('system', 'eclipse-forge'), 'eclipse-forge', 'Eclipse Forge', 125, 535, 0.85, 'red', 'Forja abandonada', 'controlled', public.seed_uuid('faction', 'orcos'), null, 'Estructuras de manufactura latentes.', false),
  (public.seed_uuid('system', 'ashen-road'), 'ashen-road', 'Ashen Road', 405, 555, 0.72, 'blue', 'Nodo de transito', 'controlled', public.seed_uuid('faction', 'culto-genestelar'), null, 'Rutas estables entre corrientes de polvo orbital.', false),
  (public.seed_uuid('system', 'red-sabbath'), 'red-sabbath', 'Red Sabbath', 560, 535, 0.86, 'red', 'Zona de guerra', 'war', public.seed_uuid('faction', 'culto-genestelar'), now() + interval '18 hours', 'Senales de batalla activas y trafico encriptado.', false),
  (public.seed_uuid('system', 'pale-choir'), 'pale-choir', 'Pale Choir', 835, 520, 0.78, 'violet', 'Anomalia psiquica', 'neutral', null, null, 'Un coro de senales imposibles atraviesa el vacio.', false),
  (public.seed_uuid('system', 'drusus'), 'drusus', 'Drusus', 475, 735, 0.82, 'orange', 'Bastion menor', 'controlled', public.seed_uuid('faction', 'guardia-muerte'), null, 'Fortaleza tomada tras una campana sangrienta.', false),
  (public.seed_uuid('system', 'ghostlight'), 'ghostlight', 'Ghostlight', 640, 760, 0.78, 'green', 'Faro perdido', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Faro de navegacion que parpadea con luz fria.', false),
  (public.seed_uuid('system', 'novem'), 'novem', 'Novem', 860, 690, 0.78, 'white', 'Luna industrial', 'controlled', public.seed_uuid('faction', 'necrones'), null, 'Complejo lunar de extraccion automatizada.', false),
  (public.seed_uuid('system', 'lyra-terminus'), 'lyra-terminus', 'Lyra Terminus', 930, 310, 0.82, 'blue', 'Puerto externo', 'controlled', public.seed_uuid('faction', 'sombra-emperador'), null, 'Puerto orbital en el borde del subsector.', false),
  (public.seed_uuid('system', 'sepulchre-nine'), 'sepulchre-nine', 'Sepulchre IX', 345, 830, 0.76, 'violet', 'Necropolis', 'neutral', null, null, 'Tumbas y coordenadas contradictorias.', false)
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

insert into public.system_edges (id, slug, from_system_id, to_system_id, uridium_cost)
values
  (public.seed_uuid('edge', 'e1'), 'e1', public.seed_uuid('system', 'kharon-prime'), public.seed_uuid('system', 'helios-drift'), 1),
  (public.seed_uuid('edge', 'e2'), 'e2', public.seed_uuid('system', 'kharon-prime'), public.seed_uuid('system', 'cinder-maw'), 1),
  (public.seed_uuid('edge', 'e3'), 'e3', public.seed_uuid('system', 'helios-drift'), public.seed_uuid('system', 'vesper-halo'), 2),
  (public.seed_uuid('edge', 'e4'), 'e4', public.seed_uuid('system', 'vesper-halo'), public.seed_uuid('system', 'narthex'), 1),
  (public.seed_uuid('edge', 'e5'), 'e5', public.seed_uuid('system', 'narthex'), public.seed_uuid('system', 'sa-cea-gate'), 1),
  (public.seed_uuid('edge', 'e6'), 'e6', public.seed_uuid('system', 'sa-cea-gate'), public.seed_uuid('system', 'lyra-terminus'), 1),
  (public.seed_uuid('edge', 'e7'), 'e7', public.seed_uuid('system', 'lyra-terminus'), public.seed_uuid('system', 'pale-choir'), 2),
  (public.seed_uuid('edge', 'e8'), 'e8', public.seed_uuid('system', 'pale-choir'), public.seed_uuid('system', 'novem'), 2),
  (public.seed_uuid('edge', 'e9'), 'e9', public.seed_uuid('system', 'novem'), public.seed_uuid('system', 'thokt-vault'), 1),
  (public.seed_uuid('edge', 'e10'), 'e10', public.seed_uuid('system', 'thokt-vault'), public.seed_uuid('system', 'ghostlight'), 1),
  (public.seed_uuid('edge', 'e11'), 'e11', public.seed_uuid('system', 'ghostlight'), public.seed_uuid('system', 'drusus'), 2),
  (public.seed_uuid('edge', 'e12'), 'e12', public.seed_uuid('system', 'drusus'), public.seed_uuid('system', 'mordax'), 1),
  (public.seed_uuid('edge', 'e13'), 'e13', public.seed_uuid('system', 'mordax'), public.seed_uuid('system', 'sepulchre-nine'), 1),
  (public.seed_uuid('edge', 'e14'), 'e14', public.seed_uuid('system', 'mordax'), public.seed_uuid('system', 'eclipse-forge'), 2),
  (public.seed_uuid('edge', 'e15'), 'e15', public.seed_uuid('system', 'eclipse-forge'), public.seed_uuid('system', 'cinder-maw'), 1),
  (public.seed_uuid('edge', 'e16'), 'e16', public.seed_uuid('system', 'cinder-maw'), public.seed_uuid('system', 'azur-trench'), 1),
  (public.seed_uuid('edge', 'e17'), 'e17', public.seed_uuid('system', 'azur-trench'), public.seed_uuid('system', 'orison'), 1),
  (public.seed_uuid('edge', 'e18'), 'e18', public.seed_uuid('system', 'orison'), public.seed_uuid('system', 'blackglass'), 2),
  (public.seed_uuid('edge', 'e19'), 'e19', public.seed_uuid('system', 'blackglass'), public.seed_uuid('system', 'red-sabbath'), 1),
  (public.seed_uuid('edge', 'e20'), 'e20', public.seed_uuid('system', 'red-sabbath'), public.seed_uuid('system', 'ashen-road'), 1),
  (public.seed_uuid('edge', 'e21'), 'e21', public.seed_uuid('system', 'ashen-road'), public.seed_uuid('system', 'drusus'), 1),
  (public.seed_uuid('edge', 'e22'), 'e22', public.seed_uuid('system', 'orison'), public.seed_uuid('system', 'red-sabbath'), 2),
  (public.seed_uuid('edge', 'e23'), 'e23', public.seed_uuid('system', 'blackglass'), public.seed_uuid('system', 'thokt-vault'), 2),
  (public.seed_uuid('edge', 'e24'), 'e24', public.seed_uuid('system', 'azur-trench'), public.seed_uuid('system', 'vesper-halo'), 2)
on conflict (slug) do update
set
  from_system_id = excluded.from_system_id,
  to_system_id = excluded.to_system_id,
  uridium_cost = excluded.uridium_cost,
  is_blocked = excluded.is_blocked;

insert into public.faction_resources (faction_id, supply, minerals, ancestral_stone, uridium, technology)
values
  (public.seed_uuid('faction', 'guardia-imperial'), 120, 85, 8, 14, 1),
  (public.seed_uuid('faction', 'orcos'), 115, 90, 4, 10, 0),
  (public.seed_uuid('faction', 'necrones'), 65, 100, 12, 12, 2),
  (public.seed_uuid('faction', 'culto-genestelar'), 130, 55, 6, 11, 1),
  (public.seed_uuid('faction', 'sombra-emperador'), 80, 75, 10, 16, 3),
  (public.seed_uuid('faction', 'guardia-muerte'), 95, 80, 9, 9, 1)
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
  (public.seed_uuid('system', 'kharon-prime'), 8, 5, 0, 2, 0),
  (public.seed_uuid('system', 'sa-cea-gate'), 5, 4, 0, 5, 1),
  (public.seed_uuid('system', 'thokt-vault'), 0, 7, 2, 2, 0),
  (public.seed_uuid('system', 'mordax'), 4, 6, 1, 2, 0),
  (public.seed_uuid('system', 'helios-drift'), 0, 6, 0, 1, 0),
  (public.seed_uuid('system', 'vesper-halo'), 0, 2, 0, 1, 1),
  (public.seed_uuid('system', 'narthex'), 2, 0, 1, 0, 0),
  (public.seed_uuid('system', 'cinder-maw'), 1, 5, 0, 0, 0),
  (public.seed_uuid('system', 'azur-trench'), 0, 0, 0, 4, 0),
  (public.seed_uuid('system', 'orison'), 7, 0, 0, 0, 0),
  (public.seed_uuid('system', 'blackglass'), 0, 2, 2, 0, 0),
  (public.seed_uuid('system', 'eclipse-forge'), 0, 4, 0, 0, 1),
  (public.seed_uuid('system', 'ashen-road'), 0, 0, 0, 3, 0),
  (public.seed_uuid('system', 'red-sabbath'), 2, 2, 0, 1, 0),
  (public.seed_uuid('system', 'pale-choir'), 0, 0, 1, 2, 0),
  (public.seed_uuid('system', 'drusus'), 3, 3, 0, 0, 0),
  (public.seed_uuid('system', 'ghostlight'), 0, 0, 0, 3, 1),
  (public.seed_uuid('system', 'novem'), 0, 5, 0, 0, 0),
  (public.seed_uuid('system', 'lyra-terminus'), 2, 0, 0, 3, 0),
  (public.seed_uuid('system', 'sepulchre-nine'), 0, 1, 1, 0, 0)
on conflict (system_id) do update
set
  supply_per_tick = excluded.supply_per_tick,
  minerals_per_tick = excluded.minerals_per_tick,
  ancestral_stone_per_tick = excluded.ancestral_stone_per_tick,
  uridium_per_tick = excluded.uridium_per_tick,
  technology_per_tick = excluded.technology_per_tick;

insert into public.armies (id, slug, faction_id, name, current_system_id, status, points_total, is_visible_publicly)
values
  (public.seed_uuid('army', 'army-guardia-imperial'), 'army-guardia-imperial', public.seed_uuid('faction', 'guardia-imperial'), 'Regimiento de Guardia Imperial', public.seed_uuid('system', 'kharon-prime'), 'moving', 750, false),
  (public.seed_uuid('army', 'army-orcos'), 'army-orcos', public.seed_uuid('faction', 'orcos'), 'Marea Verde', public.seed_uuid('system', 'cinder-maw'), 'ready', 800, false),
  (public.seed_uuid('army', 'army-necrones'), 'army-necrones', public.seed_uuid('faction', 'necrones'), 'Legion de la Cripta', public.seed_uuid('system', 'thokt-vault'), 'ready', 780, false),
  (public.seed_uuid('army', 'army-culto-genestelar'), 'army-culto-genestelar', public.seed_uuid('faction', 'culto-genestelar'), 'Celula del Alzamiento', public.seed_uuid('system', 'blackglass'), 'ready', 720, false),
  (public.seed_uuid('army', 'army-sombra-emperador'), 'army-sombra-emperador', public.seed_uuid('faction', 'sombra-emperador'), 'Sombra del Emperador', public.seed_uuid('system', 'sa-cea-gate'), 'ready', 700, false),
  (public.seed_uuid('army', 'army-guardia-muerte'), 'army-guardia-muerte', public.seed_uuid('faction', 'guardia-muerte'), 'Vector de la Plaga', public.seed_uuid('system', 'mordax'), 'in_war', 760, false)
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
values (
  public.seed_uuid('army_unit', 'unit-1'),
  public.seed_uuid('army', 'army-guardia-imperial'),
  'Veteranos de Kharon',
  180,
  1,
  3,
  'Curtidos',
  'Juramento de venganza'
)
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

insert into public.recruitment_queue (
  id,
  faction_id,
  unit_template_id,
  quantity,
  supply_cost,
  minerals_cost,
  ancestral_stone_cost,
  uridium_cost,
  technology_cost,
  started_at,
  finishes_at,
  status
)
values (
  public.seed_uuid('recruitment_queue', 'queue-1'),
  public.seed_uuid('faction', 'guardia-imperial'),
  public.seed_uuid('unit_template', 'unit-guardia-cadian'),
  1,
  12,
  2,
  0,
  0,
  0,
  now() - interval '3 hours',
  now() + interval '5 hours',
  'queued'
)
on conflict (id) do update
set
  status = excluded.status,
  started_at = excluded.started_at,
  finishes_at = excluded.finishes_at;

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
values (
  public.seed_uuid('movement_order', 'move-1'),
  public.seed_uuid('army', 'army-guardia-imperial'),
  public.seed_uuid('faction', 'guardia-imperial'),
  public.seed_uuid('system', 'kharon-prime'),
  public.seed_uuid('system', 'cinder-maw'),
  1,
  now() - interval '1 hour',
  now() + interval '2 hours',
  'moving'
)
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
values (
  public.seed_uuid('conflict', 'conflict-1'),
  'conflict-1',
  public.seed_uuid('system', 'mordax'),
  public.seed_uuid('faction', 'guardia-imperial'),
  public.seed_uuid('faction', 'guardia-muerte'),
  'pending',
  now() + interval '36 hours',
  'Batalla pendiente de reporte.'
)
on conflict (slug) do update
set
  system_id = excluded.system_id,
  attacker_faction_id = excluded.attacker_faction_id,
  defender_faction_id = excluded.defender_faction_id,
  status = excluded.status,
  blocked_until = excluded.blocked_until,
  notes = excluded.notes;

insert into public.missions (
  id,
  system_id,
  title,
  narrative_description,
  objectives,
  special_rules,
  victory_conditions
)
values (
  public.seed_uuid('mission', 'mission-1'),
  public.seed_uuid('system', 'mordax'),
  'El Puente de Ceniza',
  'Las fuerzas chocan bajo columnas de humo industrial.',
  'Controlar los nodos de carga al final del quinto turno de batalla fisica.',
  'Visibilidad reducida en el primer round.',
  'El ganador decide el control final del sistema.'
)
on conflict (id) do update
set
  system_id = excluded.system_id,
  title = excluded.title,
  narrative_description = excluded.narrative_description,
  objectives = excluded.objectives,
  special_rules = excluded.special_rules,
  victory_conditions = excluded.victory_conditions,
  updated_at = now();

insert into public.system_special_objects (id, system_id, name, type, public_description, is_public)
values (
  public.seed_uuid('system_special_object', 'obj-narthex'),
  public.seed_uuid('system', 'narthex'),
  'Reliquia avistada',
  'relic',
  'Lecturas violetas y doradas bajo el santuario.',
  true
)
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
  next_resource_tick_at = now() + interval '11 hours',
  updated_at = now()
where id = 'default';
