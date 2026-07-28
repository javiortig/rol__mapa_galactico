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

with final_factions(slug, name, color, is_narrative) as (
  values
    ('legiones-daemonicas', 'Legiones Daemonicas', '#ef4444', false),
    ('cultos-genestealer', 'Cultos Genestealer', '#ec4899', false),
    ('space-marines', 'Space Marines', '#3b82f6', false),
    ('adeptus-custodes', 'Adeptus Custodes', '#d4af37', false),
    ('necrones', 'Necrones', '#2dd4bf', false),
    ('orcos', 'Orcos', '#84cc16', true),
    ('tiranidos', 'Tiranidos', '#8b5cf6', true)
)
insert into public.factions (id, slug, name, color, capital_system_id, is_narrative)
select public.seed_uuid('faction', slug), slug, name, color, null, is_narrative
from final_factions
on conflict (slug) do update
set
  name = excluded.name,
  color = excluded.color,
  is_narrative = excluded.is_narrative,
  capital_system_id = case when excluded.is_narrative then null else public.factions.capital_system_id end;

with final_systems(slug, name, x, y, size, star_class, type, status, controller_slug, public_description, is_capital) as (
  values
    ('kharon-prime', 'Kharon Prime', 90, 150, 1.2, 'blue', 'Capital fortificada', 'controlled', 'adeptus-custodes', 'Bastion aurico y astropuerto militar custodiado por los guardianes del Trono.', true),
    ('helios-drift', 'Helios Drift', 230, 190, 0.9, 'orange', 'Cinturon minero neutral', 'neutral', null, 'Primer corredor desde Kharon: asteroides ricos en mineral y rutas abiertas hacia el centro.', false),
    ('arx-solum', 'Arx Solum', 350, 110, 0.82, 'white', 'Bastion exterior neutral', 'neutral', null, 'Fortaleza avanzada abandonada sobre una ruta alta hacia los nodos centrales.', false),
    ('azur-trench', 'Azur Trench', 360, 270, 0.86, 'blue', 'Nebulosa navegable', 'neutral', null, 'Corredor azul con pozos de gravedad inestables y lecturas de patrullas orkas lejanas.', false),
    ('sa-cea-gate', 'Sa''cea Gate', 910, 150, 1.2, 'white', 'Capital orbital', 'controlled', 'space-marines', 'Estacion de paso con matrices de navegacion de largo alcance.', true),
    ('lyra-terminus', 'Lyra Terminus', 770, 190, 0.88, 'blue', 'Puerto externo neutral', 'neutral', null, 'Puerto orbital sin mando estable, demasiado cercano al frente para ser ignorado.', false),
    ('narthex', 'Narthex', 650, 110, 0.95, 'yellow', 'Santuario sellado neutral', 'neutral', null, 'Complejo sacro con rutas de descenso peligrosas hacia el nucleo del mapa.', false),
    ('vesper-halo', 'Vesper Halo', 640, 270, 0.82, 'violet', 'Anillo orbital neutral', 'neutral', null, 'Ruinas orbitales con ecos de tecnologia antigua y pasos hacia territorio disputado.', false),
    ('blackglass', 'Blackglass', 930, 500, 1.16, 'white', 'Capital cristalina', 'controlled', 'cultos-genestealer', 'Honor bajo oceanos de vidrio oscuro.', true),
    ('red-sabbath', 'Red Sabbath', 785, 500, 0.88, 'red', 'Mundo sermonario neutral', 'neutral', null, 'Ciudades santuario sin autoridad estable, llenas de rutas subterraneas y ruido civil.', false),
    ('mirrorcoil', 'Mirrorcoil', 660, 415, 0.82, 'violet', 'Enjambre orbital neutral', 'neutral', null, 'Estaciones gemelas que repiten senales falsas hacia el centro.', false),
    ('saint-veil', 'Saint Veil', 650, 585, 0.86, 'yellow', 'Velo sagrado neutral', 'neutral', null, 'Santuario velado donde los augurios se confunden con sabotajes y plegarias.', false),
    ('thokt-vault', 'Thokt Vault', 820, 850, 1.2, 'green', 'Capital tumba', 'controlled', 'necrones', 'Cripta silenciosa rodeada de energia verdosa.', true),
    ('novem', 'Novem', 705, 735, 0.84, 'white', 'Luna industrial neutral', 'neutral', null, 'Complejo lunar de extraccion automatizada a la espera de un nuevo amo.', false),
    ('ghostlight', 'Ghostlight', 610, 650, 0.8, 'green', 'Faro perdido neutral', 'neutral', null, 'Faro de navegacion que parpadea con luz fria cerca de los ejes orkos.', false),
    ('ossuary-reach', 'Ossuary Reach', 585, 815, 0.84, 'violet', 'Osario orbital neutral', 'neutral', null, 'Campos funerarios en orbita baja donde la tecnologia antigua sigue respondiendo.', false),
    ('mordax', 'Mordax', 145, 850, 1.18, 'red', 'Capital corrupta', 'controlled', 'legiones-daemonicas', 'Mundo industrial desgarrado por senales disformes.', true),
    ('drusus', 'Drusus', 285, 735, 0.86, 'orange', 'Bastion menor neutral', 'neutral', null, 'Fortaleza abandonada en una ruta baja hacia los fuegos centrales.', false),
    ('plaguefall-bastion', 'Plaguefall Bastion', 395, 650, 0.82, 'green', 'Bastion infectado neutral', 'neutral', null, 'Plataformas de asedio cubiertas por esporas y ceniza.', false),
    ('sepulchre-nine', 'Sepulchre IX', 385, 815, 0.78, 'violet', 'Necropolis neutral', 'neutral', null, 'Tumbas y coordenadas contradictorias en el corredor inferior.', false),
    ('nexus-aster', 'Nexus Aster', 500, 400, 0.96, 'green', 'Enclave orko central', 'controlled', 'orcos', 'Un nudo de rutas tomado por senales de guerra orkas y chatarra militar.', false),
    ('goregate', 'Goregate', 500, 565, 0.96, 'red', 'Portal de guerra orko', 'controlled', 'orcos', 'Paso sangriento convertido en puerta de saqueo para incursiones orkas.', false)
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
  case when final_systems.is_capital then 6 else 3 end,
  'standard',
  true,
  false,
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
  system_kind = 'standard',
  is_conquerable = true,
  allows_shared_occupation = false,
  is_temporary_mission = false,
  mission_threat_faction_id = null,
  mission_enemy_units_visible = false,
  mission_enemy_units = '[]'::jsonb,
  mission_expires_at = null,
  mission_expires_after_battle = false,
  temporary_mission_status = 'active',
  temporary_mission_closed_at = null,
  updated_at = now();

update public.factions set capital_system_id = public.seed_uuid('system', 'thokt-vault') where slug = 'necrones';
update public.factions set capital_system_id = public.seed_uuid('system', 'kharon-prime') where slug = 'adeptus-custodes';
update public.factions set capital_system_id = public.seed_uuid('system', 'blackglass') where slug = 'cultos-genestealer';
update public.factions set capital_system_id = public.seed_uuid('system', 'sa-cea-gate') where slug = 'space-marines';
update public.factions set capital_system_id = public.seed_uuid('system', 'mordax') where slug = 'legiones-daemonicas';
update public.factions set capital_system_id = null where slug in ('orcos', 'tiranidos');

delete from public.battle_reports;
delete from public.battle_unit_commitments;
delete from public.battle_operation_members;
delete from public.battle_operations;
delete from public.movement_passage_requests;
delete from public.movement_order_units;
delete from public.movement_orders;
delete from public.narrative_attacks;
delete from public.conflicts;
delete from public.missions;
delete from public.unit_recovery_queue;
delete from public.recruitment_queue;

update public.campaign_units units
set
  current_system_id = factions.capital_system_id,
  status = 'ready',
  updated_at = now()
from public.factions factions
where units.faction_id = factions.id
  and factions.capital_system_id is not null
  and units.status <> 'destroyed';

update public.relics relics
set system_id = factions.capital_system_id
from public.factions factions
where relics.faction_id = factions.id
  and factions.capital_system_id is not null
  and relics.equipped_unit_id is null
  and (
    relics.system_id is null
    or relics.system_id not in (
      select id
      from public.systems
      where slug in (
        'kharon-prime','helios-drift','arx-solum','azur-trench',
        'sa-cea-gate','lyra-terminus','narthex','vesper-halo',
        'blackglass','red-sabbath','mirrorcoil','saint-veil',
        'thokt-vault','novem','ghostlight','ossuary-reach',
        'mordax','drusus','plaguefall-bastion','sepulchre-nine',
        'nexus-aster','goregate'
      )
    )
  );

delete from public.system_special_objects;
delete from public.system_edges;
delete from public.system_buildings
where system_id in (
  select id
  from public.systems
  where not is_capital
);
delete from public.system_resource_capabilities;
delete from public.system_production;

delete from public.systems
where slug not in (
  'kharon-prime','helios-drift','arx-solum','azur-trench',
  'sa-cea-gate','lyra-terminus','narthex','vesper-halo',
  'blackglass','red-sabbath','mirrorcoil','saint-veil',
  'thokt-vault','novem','ghostlight','ossuary-reach',
  'mordax','drusus','plaguefall-bastion','sepulchre-nine',
  'nexus-aster','goregate'
);

insert into public.system_edges (id, slug, from_system_id, to_system_id, uridium_cost, is_blocked)
values
  (public.seed_uuid('edge', 'route-01'), 'route-01', public.seed_uuid('system', 'kharon-prime'), public.seed_uuid('system', 'helios-drift'), 1, false),
  (public.seed_uuid('edge', 'route-02'), 'route-02', public.seed_uuid('system', 'helios-drift'), public.seed_uuid('system', 'arx-solum'), 1, false),
  (public.seed_uuid('edge', 'route-03'), 'route-03', public.seed_uuid('system', 'helios-drift'), public.seed_uuid('system', 'azur-trench'), 1, false),
  (public.seed_uuid('edge', 'route-04'), 'route-04', public.seed_uuid('system', 'sa-cea-gate'), public.seed_uuid('system', 'lyra-terminus'), 1, false),
  (public.seed_uuid('edge', 'route-05'), 'route-05', public.seed_uuid('system', 'lyra-terminus'), public.seed_uuid('system', 'narthex'), 1, false),
  (public.seed_uuid('edge', 'route-06'), 'route-06', public.seed_uuid('system', 'lyra-terminus'), public.seed_uuid('system', 'vesper-halo'), 1, false),
  (public.seed_uuid('edge', 'route-07'), 'route-07', public.seed_uuid('system', 'blackglass'), public.seed_uuid('system', 'red-sabbath'), 1, false),
  (public.seed_uuid('edge', 'route-08'), 'route-08', public.seed_uuid('system', 'red-sabbath'), public.seed_uuid('system', 'mirrorcoil'), 1, false),
  (public.seed_uuid('edge', 'route-09'), 'route-09', public.seed_uuid('system', 'red-sabbath'), public.seed_uuid('system', 'saint-veil'), 1, false),
  (public.seed_uuid('edge', 'route-10'), 'route-10', public.seed_uuid('system', 'thokt-vault'), public.seed_uuid('system', 'novem'), 1, false),
  (public.seed_uuid('edge', 'route-11'), 'route-11', public.seed_uuid('system', 'novem'), public.seed_uuid('system', 'ghostlight'), 1, false),
  (public.seed_uuid('edge', 'route-12'), 'route-12', public.seed_uuid('system', 'novem'), public.seed_uuid('system', 'ossuary-reach'), 1, false),
  (public.seed_uuid('edge', 'route-13'), 'route-13', public.seed_uuid('system', 'mordax'), public.seed_uuid('system', 'drusus'), 1, false),
  (public.seed_uuid('edge', 'route-14'), 'route-14', public.seed_uuid('system', 'drusus'), public.seed_uuid('system', 'plaguefall-bastion'), 1, false),
  (public.seed_uuid('edge', 'route-15'), 'route-15', public.seed_uuid('system', 'drusus'), public.seed_uuid('system', 'sepulchre-nine'), 1, false),
  (public.seed_uuid('edge', 'route-16'), 'route-16', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'arx-solum'), 2, false),
  (public.seed_uuid('edge', 'route-17'), 'route-17', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'narthex'), 2, false),
  (public.seed_uuid('edge', 'route-18'), 'route-18', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'mirrorcoil'), 2, false),
  (public.seed_uuid('edge', 'route-19'), 'route-19', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'ghostlight'), 2, false),
  (public.seed_uuid('edge', 'route-20'), 'route-20', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'plaguefall-bastion'), 2, false),
  (public.seed_uuid('edge', 'route-21'), 'route-21', public.seed_uuid('system', 'goregate'), public.seed_uuid('system', 'azur-trench'), 2, false),
  (public.seed_uuid('edge', 'route-22'), 'route-22', public.seed_uuid('system', 'goregate'), public.seed_uuid('system', 'vesper-halo'), 2, false),
  (public.seed_uuid('edge', 'route-23'), 'route-23', public.seed_uuid('system', 'goregate'), public.seed_uuid('system', 'saint-veil'), 2, false),
  (public.seed_uuid('edge', 'route-24'), 'route-24', public.seed_uuid('system', 'goregate'), public.seed_uuid('system', 'ossuary-reach'), 2, false),
  (public.seed_uuid('edge', 'route-25'), 'route-25', public.seed_uuid('system', 'goregate'), public.seed_uuid('system', 'sepulchre-nine'), 2, false),
  (public.seed_uuid('edge', 'route-26'), 'route-26', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'goregate'), 1, false)
on conflict (slug) do update
set
  from_system_id = excluded.from_system_id,
  to_system_id = excluded.to_system_id,
  uridium_cost = excluded.uridium_cost,
  is_blocked = excluded.is_blocked;

insert into public.system_special_objects (id, system_id, name, type, public_description, is_public)
values
  (public.seed_uuid('system_special_object', 'obj-nexus-aster'), public.seed_uuid('system', 'nexus-aster'), 'Totem del Nexus', 'anomaly', 'Un enjambre de chatarra, balizas robadas y senales de guerra orkas domina el nodo.', true),
  (public.seed_uuid('system_special_object', 'obj-goregate'), public.seed_uuid('system', 'goregate'), 'Puerta de la Waaagh', 'anomaly', 'La ruta central inferior vibra con motores improvisados y amenazas pintadas en rojo.', true)
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
  'final_campaign_map_applied',
  jsonb_build_object(
    'systems', 22,
    'routes', 26,
    'central_controller', 'orcos',
    'applied_at', now()
  )
);
