create or replace function public.seed_space_marines_troop_technology_tree()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space_faction_id uuid;
begin
  insert into public.technology_nodes (
    id, slug, tree_key, name, description, branch, tier, position_x, position_y,
    cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
  )
  values
    (public.seed_uuid('technology_node', 'marines-escuadras-batalla'), 'marines-escuadras-batalla', 'troops-space-marines-v1', 'Escuadras de Batalla', 'El nucleo doctrinal del capitulo despliega lineas flexibles para tomar y mantener terreno. Desbloquea: Assault Intercessor Squad, Intercessor Squad, Heavy Intercessor Squad y Tactical Squad.', 'Doctrina del Capitulo', 1, 1, 2, 1, 30, 'marine_battleline', 'Desbloquea: Assault Intercessor Squad, Intercessor Squad, Heavy Intercessor Squad, Tactical Squad.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-oficiales-compania'), 'marines-oficiales-compania', 'troops-space-marines-v1', 'Oficiales de Compania', 'La estructura de mando del capitulo activa capitanes, tenientes, apotecarios, capellanes y bibliotecarios de campana. Desbloquea: Captain, Lieutenant, Ancient, Apothecary, Chaplain, Librarian y Librarius Adept [Crucible].', 'Doctrina del Capitulo', 2, 1, 1, 1, 30, 'marine_command', 'Desbloquea: Captain, Lieutenant, Ancient, Apothecary, Chaplain, Librarian, Librarius Adept [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-veteranos-capitulo'), 'marines-veteranos-capitulo', 'troops-space-marines-v1', 'Veteranos del Capitulo', 'Los hermanos con honores de batalla forman la punta noble de la ofensiva y protegen el estandarte de la campana. Desbloquea: Bladeguard Veteran Squad, Sternguard Veteran Squad, Company Heroes, Bladeguard Ancient, Champion of the Chapter [Crucible] y Judiciar.', 'Doctrina del Capitulo', 3, 1, 1, 2, 30, 'marine_veterans', 'Desbloquea: Bladeguard Veteran Squad, Sternguard Veteran Squad, Company Heroes, Bladeguard Ancient, Champion of the Chapter [Crucible], Judiciar.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-gravis-fuego-pesado'), 'marines-gravis-fuego-pesado', 'troops-space-marines-v1', 'Gravis y Fuego Pesado', 'Armaduras pesadas, armas de ruptura y doctrina de saturacion preparan al capitulo para romper posiciones fortificadas. Desbloquea: Aggressor Squad, Eradicator Squad, Infernus Squad, Hellblaster Squad, Devastator Squad, Desolation Squad, Apothecary Biologis y Captain in Gravis Armour.', 'Doctrina del Capitulo', 3, 1, 3, 2, 30, 'marine_heavy_fire', 'Desbloquea: Aggressor Squad, Eradicator Squad, Infernus Squad, Hellblaster Squad, Devastator Squad, Desolation Squad, Apothecary Biologis, Captain in Gravis Armour.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-primera-compania'), 'marines-primera-compania', 'troops-space-marines-v1', 'Primera Compania', 'La reserva mas sagrada del capitulo entra en guerra con exterminadores, centuriones y oficiales de armadura reliquia. Desbloquea: Terminator Squad, Terminator Assault Squad, Ancient in Terminator Armor, Chaplain in Terminator Armour, Librarian in Terminator Armour, Captain in Terminator Armour, Centurion Assault Squad y Centurion Devastator Squad.', 'Doctrina del Capitulo', 4, 1, 2, 3, 30, 'marine_first_company', 'Desbloquea: Terminator Squad, Terminator Assault Squad, Ancient in Terminator Armor, Chaplain in Terminator Armour, Librarian in Terminator Armour, Captain in Terminator Armour, Centurion Assault Squad, Centurion Devastator Squad.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-patrullas-phobos'), 'marines-patrullas-phobos', 'troops-space-marines-v1', 'Patrullas Phobos', 'Exploradores y armaduras Phobos aseguran balizas, niegan infiltraciones y preparan zonas de aterrizaje. Desbloquea: Scout Squad, Incursor Squad, Infiltrator Squad, Captain in Phobos Armour, Lieutenant in Phobos Armour y Librarian in Phobos Armour.', 'Vanguardia y Asalto', 1, 2, 2, 1, 30, 'marine_phobos', 'Desbloquea: Scout Squad, Incursor Squad, Infiltrator Squad, Captain in Phobos Armour, Lieutenant in Phobos Armour, Librarian in Phobos Armour.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-eliminacion-silenciosa'), 'marines-eliminacion-silenciosa', 'troops-space-marines-v1', 'Eliminacion Silenciosa', 'Los equipos de terror y francotiradores cortan mandos enemigos antes de la llegada del grueso del capitulo. Desbloquea: Reiver Squad, Eliminator Squad, Lieutenant in Reiver Armour y Lieutenant with Combi-weapon.', 'Vanguardia y Asalto', 2, 2, 1, 1, 30, 'marine_elimination', 'Desbloquea: Reiver Squad, Eliminator Squad, Lieutenant in Reiver Armour, Lieutenant with Combi-weapon.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-asalto-orbital'), 'marines-asalto-orbital', 'troops-space-marines-v1', 'Asalto Orbital', 'Retrojets, reactores y escuadras de descenso convierten cualquier frente en una zona de ruptura vertical. Desbloquea: Assault Intercessors with Jump Packs, Vanguard Veteran Squad with Jump Packs, Inceptor Squad, Suppressor Squad, Captain with Jump Pack y Chaplain with Jump Pack.', 'Vanguardia y Asalto', 3, 2, 2, 2, 30, 'marine_jump', 'Desbloquea: Assault Intercessors with Jump Packs, Vanguard Veteran Squad with Jump Packs, Inceptor Squad, Suppressor Squad, Captain with Jump Pack, Chaplain with Jump Pack.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-cazadores-motorizados'), 'marines-cazadores-motorizados', 'troops-space-marines-v1', 'Cazadores Motorizados', 'Escuadras de persecucion, motos de mando y vehiculos ligeros rodean al enemigo antes del golpe acorazado. Desbloquea: Outrider Squad, Invader ATV y Chaplain on Bike.', 'Vanguardia y Asalto', 4, 2, 2, 2, 30, 'marine_bike', 'Desbloquea: Outrider Squad, Invader ATV, Chaplain on Bike.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-despliegue-mecanizado'), 'marines-despliegue-mecanizado', 'troops-space-marines-v1', 'Despliegue Mecanizado', 'El capitulo abre corredores de despliegue con capsulas, transportes Rhino y chasis de reaccion rapida. Desbloquea: Drop Pod, Rhino, Impulsor y Razorback.', 'Arsenal de Cruzada', 1, 3, 2, 1, 30, 'marine_transport', 'Desbloquea: Drop Pod, Rhino, Impulsor, Razorback.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-bastiones-apoyo'), 'marines-bastiones-apoyo', 'troops-space-marines-v1', 'Bastiones de Apoyo', 'Sistemas de fuego estacionario, bunkeres orbitales, warsuits y techmarines aseguran la infraestructura de batalla. Desbloquea: Firestrike Servo-Turrets, Hammerfall Bunker, Invictor Tactical Warsuit y Techmarine.', 'Arsenal de Cruzada', 2, 3, 1, 1, 30, 'marine_bastion', 'Desbloquea: Firestrike Servo-Turrets, Hammerfall Bunker, Invictor Tactical Warsuit, Techmarine.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-alas-tormenta'), 'marines-alas-tormenta', 'troops-space-marines-v1', 'Alas Tormenta', 'Speeders de reaccion rapida cazan blindados, saturan infanteria y marcan objetivos para el avance principal. Desbloquea: Storm Speeder Hailstrike, Storm Speeder Hammerstrike y Storm Speeder Thunderstrike.', 'Arsenal de Cruzada', 2, 3, 3, 1, 30, 'marine_speeder', 'Desbloquea: Storm Speeder Hailstrike, Storm Speeder Hammerstrike, Storm Speeder Thunderstrike.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-sarcofagos-guerra'), 'marines-sarcofagos-guerra', 'troops-space-marines-v1', 'Sarcofagos de Guerra', 'Hermanos venerables y chasis dreadnought convierten reliquias vivientes en martillos de avance. Desbloquea: Dreadnought, Ballistus Dreadnought, Brutalis Dreadnought, Redemptor Dreadnought y Venerable Battle-Brother [Crucible].', 'Arsenal de Cruzada', 3, 3, 1, 2, 30, 'marine_dreadnought', 'Desbloquea: Dreadnought, Ballistus Dreadnought, Brutalis Dreadnought, Redemptor Dreadnought, Venerable Battle-Brother [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-lanzas-blindadas'), 'marines-lanzas-blindadas', 'troops-space-marines-v1', 'Lanzas Blindadas', 'Predators, Gladiators, artilleria y grav-tanques pesados forman columnas acorazadas de ruptura. Desbloquea: Predator Annihilator, Predator Destructor, Gladiator Valiant, Gladiator Lancer, Gladiator Reaper, Vindicator, Whirlwind, Repulsor y Repulsor Executioner.', 'Arsenal de Cruzada', 4, 3, 1, 2, 30, 'marine_tank', 'Desbloquea: Predator Annihilator, Predator Destructor, Gladiator Valiant, Gladiator Lancer, Gladiator Reaper, Vindicator, Whirlwind, Repulsor, Repulsor Executioner.', false, 'active'),
    (public.seed_uuid('technology_node', 'marines-reliquias-cruzada'), 'marines-reliquias-cruzada', 'troops-space-marines-v1', 'Reliquias de Cruzada', 'Las arcas mas antiguas, gunships de supremacia aerea y superpesados del capitulo entran en guerra total. Desbloquea: Land Raider, Land Raider Crusader, Land Raider Redeemer, Stormraven Gunship, Stormhawk Interceptor, Stormtalon Gunship, Astraeus y Thunderhawk Gunship.', 'Arsenal de Cruzada', 5, 3, 2, 3, 30, 'marine_relic_armor', 'Desbloquea: Land Raider, Land Raider Crusader, Land Raider Redeemer, Stormraven Gunship, Stormhawk Interceptor, Stormtalon Gunship, Astraeus, Thunderhawk Gunship.', false, 'active')
  on conflict (slug) do update
  set tree_key = excluded.tree_key,
      name = excluded.name,
      description = excluded.description,
      branch = excluded.branch,
      tier = excluded.tier,
      position_x = excluded.position_x,
      position_y = excluded.position_y,
      cost_technology = excluded.cost_technology,
      research_time_seconds = excluded.research_time_seconds,
      icon_key = excluded.icon_key,
      effect_summary = excluded.effect_summary,
      is_starter = excluded.is_starter,
      implementation_status = excluded.implementation_status,
      updated_at = now();

  delete from public.technology_nodes
  where tree_key = 'troops-space-marines-v1'
    and slug not in (
      'marines-escuadras-batalla',
      'marines-oficiales-compania',
      'marines-veteranos-capitulo',
      'marines-gravis-fuego-pesado',
      'marines-primera-compania',
      'marines-patrullas-phobos',
      'marines-eliminacion-silenciosa',
      'marines-asalto-orbital',
      'marines-cazadores-motorizados',
      'marines-despliegue-mecanizado',
      'marines-bastiones-apoyo',
      'marines-alas-tormenta',
      'marines-sarcofagos-guerra',
      'marines-lanzas-blindadas',
      'marines-reliquias-cruzada'
    );

  delete from public.technology_prerequisites prerequisites
  using public.technology_nodes nodes
  where prerequisites.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-space-marines-v1';

  insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
  select tech.id, required.id, data.prerequisite_group
  from (
    values
      ('marines-escuadras-batalla', 'fundacion-planetaria', 1),
      ('marines-oficiales-compania', 'marines-escuadras-batalla', 1),
      ('marines-oficiales-compania', 'asamblea-planetaria', 2),
      ('marines-veteranos-capitulo', 'marines-oficiales-compania', 1),
      ('marines-gravis-fuego-pesado', 'marines-escuadras-batalla', 1),
      ('marines-gravis-fuego-pesado', 'maquinaria-belica', 2),
      ('marines-primera-compania', 'marines-veteranos-capitulo', 1),
      ('marines-primera-compania', 'marines-gravis-fuego-pesado', 2),
      ('marines-patrullas-phobos', 'marines-escuadras-batalla', 1),
      ('marines-eliminacion-silenciosa', 'marines-patrullas-phobos', 1),
      ('marines-asalto-orbital', 'marines-patrullas-phobos', 1),
      ('marines-asalto-orbital', 'marines-oficiales-compania', 2),
      ('marines-cazadores-motorizados', 'marines-asalto-orbital', 1),
      ('marines-cazadores-motorizados', 'maquinaria-belica', 2),
      ('marines-despliegue-mecanizado', 'marines-escuadras-batalla', 1),
      ('marines-despliegue-mecanizado', 'maquinaria-belica', 2),
      ('marines-bastiones-apoyo', 'marines-despliegue-mecanizado', 1),
      ('marines-alas-tormenta', 'marines-despliegue-mecanizado', 1),
      ('marines-sarcofagos-guerra', 'marines-bastiones-apoyo', 1),
      ('marines-sarcofagos-guerra', 'marines-oficiales-compania', 2),
      ('marines-lanzas-blindadas', 'marines-sarcofagos-guerra', 1),
      ('marines-lanzas-blindadas', 'marines-alas-tormenta', 2),
      ('marines-reliquias-cruzada', 'marines-lanzas-blindadas', 1),
      ('marines-reliquias-cruzada', 'marines-primera-compania', 2)
  ) as data(technology_slug, required_slug, prerequisite_group)
  join public.technology_nodes tech on tech.slug = data.technology_slug
  join public.technology_nodes required on required.slug = data.required_slug
  on conflict (technology_node_id, required_node_id) do update
  set prerequisite_group = excluded.prerequisite_group;

  delete from public.technology_effects effects
  using public.technology_nodes nodes
  where effects.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-space-marines-v1'
    and effects.effect_type = 'unlock_unit_template';

  insert into public.technology_effects (id, technology_node_id, effect_type, payload)
  select
    public.seed_uuid('technology_effect', data.technology_slug || '-units'),
    technology_nodes.id,
    'unlock_unit_template',
    jsonb_build_object('unit_template_slugs', data.unit_template_slugs)
  from (
    values
      ('marines-escuadras-batalla', array['unit-space-marines-assault-intercessor-squad','unit-space-marines-intercessor-squad','unit-space-marines-heavy-intercessor-squad','unit-space-marines-tactical-squad']::text[]),
      ('marines-oficiales-compania', array['unit-space-marines-captain','unit-space-marines-lieutenant','unit-space-marines-ancient','unit-space-marines-apothecary','unit-space-marines-chaplain','unit-space-marines-librarian','unit-space-marines-librarius-adept-crucible']::text[]),
      ('marines-veteranos-capitulo', array['unit-space-marines-bladeguard-veteran-squad','unit-space-marines-sternguard-veteran-squad','unit-space-marines-company-heroes','unit-space-marines-bladeguard-ancient','unit-space-marines-champion-of-the-chapter-crucible','unit-space-marines-judiciar']::text[]),
      ('marines-gravis-fuego-pesado', array['unit-space-marines-aggressor-squad','unit-space-marines-eradicator-squad','unit-space-marines-infernus-squad','unit-space-marines-hellblaster-squad','unit-space-marines-devastator-squad','unit-space-marines-desolation-squad','unit-space-marines-apothecary-biologis','unit-space-marines-captain-in-gravis-armour']::text[]),
      ('marines-primera-compania', array['unit-space-marines-terminator-squad','unit-space-marines-terminator-assault-squad','unit-space-marines-ancient-in-terminator-armor','unit-space-marines-chaplain-in-terminator-armour','unit-space-marines-librarian-in-terminator-armour','unit-space-marines-captain-in-terminator-armour','unit-space-marines-centurion-assault-squad','unit-space-marines-centurion-devastator-squad']::text[]),
      ('marines-patrullas-phobos', array['unit-space-marines-scout-squad','unit-space-marines-incursor-squad','unit-space-marines-infiltrator-squad','unit-space-marines-captain-in-phobos-armour','unit-space-marines-lieutenant-in-phobos-armour','unit-space-marines-librarian-in-phobos-armour']::text[]),
      ('marines-eliminacion-silenciosa', array['unit-space-marines-reiver-squad','unit-space-marines-eliminator-squad','unit-space-marines-lieutenant-in-reiver-armour','unit-space-marines-lieutenant-with-combi-weapon']::text[]),
      ('marines-asalto-orbital', array['unit-space-marines-assault-intercessors-with-jump-packs','unit-space-marines-vanguard-veteran-squad-with-jump-packs','unit-space-marines-inceptor-squad','unit-space-marines-suppressor-squad','unit-space-marines-captain-with-jump-pack','unit-space-marines-chaplain-with-jump-pack']::text[]),
      ('marines-cazadores-motorizados', array['unit-space-marines-outrider-squad','unit-space-marines-invader-atv','unit-space-marines-chaplain-on-bike']::text[]),
      ('marines-despliegue-mecanizado', array['unit-space-marines-drop-pod','unit-space-marines-rhino','unit-space-marines-impulsor','unit-space-marines-razorback']::text[]),
      ('marines-bastiones-apoyo', array['unit-space-marines-firestrike-servo-turrets','unit-space-marines-hammerfall-bunker','unit-space-marines-invictor-tactical-warsuit','unit-space-marines-techmarine']::text[]),
      ('marines-alas-tormenta', array['unit-space-marines-storm-speeder-hailstrike','unit-space-marines-storm-speeder-hammerstrike','unit-space-marines-storm-speeder-thunderstrike']::text[]),
      ('marines-sarcofagos-guerra', array['unit-space-marines-dreadnought','unit-space-marines-ballistus-dreadnought','unit-space-marines-brutalis-dreadnought','unit-space-marines-redemptor-dreadnought','unit-space-marines-venerable-battle-brother-crucible']::text[]),
      ('marines-lanzas-blindadas', array['unit-space-marines-predator-annihilator','unit-space-marines-predator-destructor','unit-space-marines-gladiator-valiant','unit-space-marines-gladiator-lancer','unit-space-marines-gladiator-reaper','unit-space-marines-vindicator','unit-space-marines-whirlwind','unit-space-marines-repulsor','unit-space-marines-repulsor-executioner']::text[]),
      ('marines-reliquias-cruzada', array['unit-space-marines-land-raider','unit-space-marines-land-raider-crusader','unit-space-marines-land-raider-redeemer','unit-space-marines-stormraven-gunship','unit-space-marines-stormhawk-interceptor','unit-space-marines-stormtalon-gunship','unit-space-marines-astraeus','unit-space-marines-thunderhawk-gunship']::text[])
  ) as data(technology_slug, unit_template_slugs)
  join public.technology_nodes on technology_nodes.slug = data.technology_slug
  on conflict (id) do update
  set technology_node_id = excluded.technology_node_id,
      effect_type = excluded.effect_type,
      payload = excluded.payload;

  select id into v_space_faction_id
  from public.factions
  where slug = 'space-marines';

  if v_space_faction_id is not null then
    update public.unit_templates
    set is_available = false,
        required_technology_node_id = null
    where faction_id = v_space_faction_id;

    update public.unit_templates templates
    set is_available = true,
        required_technology_node_id = technology_nodes.id
    from (
      values
        ('unit-space-marines-assault-intercessor-squad', 'marines-escuadras-batalla'),
        ('unit-space-marines-intercessor-squad', 'marines-escuadras-batalla'),
        ('unit-space-marines-heavy-intercessor-squad', 'marines-escuadras-batalla'),
        ('unit-space-marines-tactical-squad', 'marines-escuadras-batalla'),
        ('unit-space-marines-captain', 'marines-oficiales-compania'),
        ('unit-space-marines-lieutenant', 'marines-oficiales-compania'),
        ('unit-space-marines-ancient', 'marines-oficiales-compania'),
        ('unit-space-marines-apothecary', 'marines-oficiales-compania'),
        ('unit-space-marines-chaplain', 'marines-oficiales-compania'),
        ('unit-space-marines-librarian', 'marines-oficiales-compania'),
        ('unit-space-marines-librarius-adept-crucible', 'marines-oficiales-compania'),
        ('unit-space-marines-bladeguard-veteran-squad', 'marines-veteranos-capitulo'),
        ('unit-space-marines-sternguard-veteran-squad', 'marines-veteranos-capitulo'),
        ('unit-space-marines-company-heroes', 'marines-veteranos-capitulo'),
        ('unit-space-marines-bladeguard-ancient', 'marines-veteranos-capitulo'),
        ('unit-space-marines-champion-of-the-chapter-crucible', 'marines-veteranos-capitulo'),
        ('unit-space-marines-judiciar', 'marines-veteranos-capitulo'),
        ('unit-space-marines-aggressor-squad', 'marines-gravis-fuego-pesado'),
        ('unit-space-marines-eradicator-squad', 'marines-gravis-fuego-pesado'),
        ('unit-space-marines-infernus-squad', 'marines-gravis-fuego-pesado'),
        ('unit-space-marines-hellblaster-squad', 'marines-gravis-fuego-pesado'),
        ('unit-space-marines-devastator-squad', 'marines-gravis-fuego-pesado'),
        ('unit-space-marines-desolation-squad', 'marines-gravis-fuego-pesado'),
        ('unit-space-marines-apothecary-biologis', 'marines-gravis-fuego-pesado'),
        ('unit-space-marines-captain-in-gravis-armour', 'marines-gravis-fuego-pesado'),
        ('unit-space-marines-terminator-squad', 'marines-primera-compania'),
        ('unit-space-marines-terminator-assault-squad', 'marines-primera-compania'),
        ('unit-space-marines-ancient-in-terminator-armor', 'marines-primera-compania'),
        ('unit-space-marines-chaplain-in-terminator-armour', 'marines-primera-compania'),
        ('unit-space-marines-librarian-in-terminator-armour', 'marines-primera-compania'),
        ('unit-space-marines-captain-in-terminator-armour', 'marines-primera-compania'),
        ('unit-space-marines-centurion-assault-squad', 'marines-primera-compania'),
        ('unit-space-marines-centurion-devastator-squad', 'marines-primera-compania'),
        ('unit-space-marines-scout-squad', 'marines-patrullas-phobos'),
        ('unit-space-marines-incursor-squad', 'marines-patrullas-phobos'),
        ('unit-space-marines-infiltrator-squad', 'marines-patrullas-phobos'),
        ('unit-space-marines-captain-in-phobos-armour', 'marines-patrullas-phobos'),
        ('unit-space-marines-lieutenant-in-phobos-armour', 'marines-patrullas-phobos'),
        ('unit-space-marines-librarian-in-phobos-armour', 'marines-patrullas-phobos'),
        ('unit-space-marines-reiver-squad', 'marines-eliminacion-silenciosa'),
        ('unit-space-marines-eliminator-squad', 'marines-eliminacion-silenciosa'),
        ('unit-space-marines-lieutenant-in-reiver-armour', 'marines-eliminacion-silenciosa'),
        ('unit-space-marines-lieutenant-with-combi-weapon', 'marines-eliminacion-silenciosa'),
        ('unit-space-marines-assault-intercessors-with-jump-packs', 'marines-asalto-orbital'),
        ('unit-space-marines-vanguard-veteran-squad-with-jump-packs', 'marines-asalto-orbital'),
        ('unit-space-marines-inceptor-squad', 'marines-asalto-orbital'),
        ('unit-space-marines-suppressor-squad', 'marines-asalto-orbital'),
        ('unit-space-marines-captain-with-jump-pack', 'marines-asalto-orbital'),
        ('unit-space-marines-chaplain-with-jump-pack', 'marines-asalto-orbital'),
        ('unit-space-marines-outrider-squad', 'marines-cazadores-motorizados'),
        ('unit-space-marines-invader-atv', 'marines-cazadores-motorizados'),
        ('unit-space-marines-chaplain-on-bike', 'marines-cazadores-motorizados'),
        ('unit-space-marines-drop-pod', 'marines-despliegue-mecanizado'),
        ('unit-space-marines-rhino', 'marines-despliegue-mecanizado'),
        ('unit-space-marines-impulsor', 'marines-despliegue-mecanizado'),
        ('unit-space-marines-razorback', 'marines-despliegue-mecanizado'),
        ('unit-space-marines-firestrike-servo-turrets', 'marines-bastiones-apoyo'),
        ('unit-space-marines-hammerfall-bunker', 'marines-bastiones-apoyo'),
        ('unit-space-marines-invictor-tactical-warsuit', 'marines-bastiones-apoyo'),
        ('unit-space-marines-techmarine', 'marines-bastiones-apoyo'),
        ('unit-space-marines-storm-speeder-hailstrike', 'marines-alas-tormenta'),
        ('unit-space-marines-storm-speeder-hammerstrike', 'marines-alas-tormenta'),
        ('unit-space-marines-storm-speeder-thunderstrike', 'marines-alas-tormenta'),
        ('unit-space-marines-dreadnought', 'marines-sarcofagos-guerra'),
        ('unit-space-marines-ballistus-dreadnought', 'marines-sarcofagos-guerra'),
        ('unit-space-marines-brutalis-dreadnought', 'marines-sarcofagos-guerra'),
        ('unit-space-marines-redemptor-dreadnought', 'marines-sarcofagos-guerra'),
        ('unit-space-marines-venerable-battle-brother-crucible', 'marines-sarcofagos-guerra'),
        ('unit-space-marines-predator-annihilator', 'marines-lanzas-blindadas'),
        ('unit-space-marines-predator-destructor', 'marines-lanzas-blindadas'),
        ('unit-space-marines-gladiator-valiant', 'marines-lanzas-blindadas'),
        ('unit-space-marines-gladiator-lancer', 'marines-lanzas-blindadas'),
        ('unit-space-marines-gladiator-reaper', 'marines-lanzas-blindadas'),
        ('unit-space-marines-vindicator', 'marines-lanzas-blindadas'),
        ('unit-space-marines-whirlwind', 'marines-lanzas-blindadas'),
        ('unit-space-marines-repulsor', 'marines-lanzas-blindadas'),
        ('unit-space-marines-repulsor-executioner', 'marines-lanzas-blindadas'),
        ('unit-space-marines-land-raider', 'marines-reliquias-cruzada'),
        ('unit-space-marines-land-raider-crusader', 'marines-reliquias-cruzada'),
        ('unit-space-marines-land-raider-redeemer', 'marines-reliquias-cruzada'),
        ('unit-space-marines-stormraven-gunship', 'marines-reliquias-cruzada'),
        ('unit-space-marines-stormhawk-interceptor', 'marines-reliquias-cruzada'),
        ('unit-space-marines-stormtalon-gunship', 'marines-reliquias-cruzada'),
        ('unit-space-marines-astraeus', 'marines-reliquias-cruzada'),
        ('unit-space-marines-thunderhawk-gunship', 'marines-reliquias-cruzada')
    ) as assignments(unit_slug, technology_slug)
    join public.technology_nodes on technology_nodes.slug = assignments.technology_slug
    where templates.slug = assignments.unit_slug
      and templates.faction_id = v_space_faction_id;

    perform public.refresh_available_technologies(v_space_faction_id);
  end if;
end;
$$;

revoke execute on function public.seed_space_marines_troop_technology_tree() from public;
revoke execute on function public.seed_space_marines_troop_technology_tree() from anon;
revoke execute on function public.seed_space_marines_troop_technology_tree() from authenticated;

select public.seed_space_marines_troop_technology_tree();
