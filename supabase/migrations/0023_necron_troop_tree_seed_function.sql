create or replace function public.seed_necron_troop_technology_tree()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.technology_nodes (
    id, slug, tree_key, name, description, branch, tier, position_x, position_y,
    cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
  )
  values
    (public.seed_uuid('technology_node', 'necrones-protocolos-reanimacion'), 'necrones-protocolos-reanimacion', 'troops-necrones-v1', 'Protocolos de Reanimacion', 'Las cohortes basicas despiertan en masa y sostienen la primera linea de conquista.', 'Falange Dinastica', 1, 1, 1, 1, 30, 'necron_phalanx', 'Desbloquea Warriors e Immortals.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-camaras-acecho'), 'necrones-camaras-acecho', 'troops-necrones-v1', 'Camaras de Acecho', 'Asesinos, custodios cripticos y horrores desollados preparan emboscadas desde tumbas ocultas.', 'Falange Dinastica', 2, 1, 2, 1, 30, 'necron_ambush', 'Desbloquea Cryptothralls, Deathmarks y Flayed Ones.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-guardia-triarca'), 'necrones-guardia-triarca', 'troops-necrones-v1', 'Guardia del Triarca', 'Las castas juramentadas recuperan su funcion: custodiar nobles y ejecutar la voluntad del Triarca.', 'Falange Dinastica', 3, 1, 3, 2, 30, 'necron_guard', 'Desbloquea Lychguard y Triarch Praetorians.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-cultos-destructores'), 'necrones-cultos-destructores', 'troops-necrones-v1', 'Cultos Destructores', 'La obsesion por la aniquilacion toma forma en cazadores, filos hiperfase y plataformas antigraviticas.', 'Falange Dinastica', 4, 1, 4, 2, 30, 'necron_destroyer', 'Desbloquea Destroyers y Tomb Blades.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-nobleza-dinastica'), 'necrones-nobleza-dinastica', 'troops-necrones-v1', 'Nobleza Dinastica', 'Los mandos de batalla imponen jerarquia sobre cohortes, guardias y asesinos de la dinastia.', 'Falange Dinastica', 5, 1, 5, 3, 30, 'necron_nobility', 'Desbloquea mandos comunes de la dinastia.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-concilio-cryptek'), 'necrones-concilio-cryptek', 'troops-necrones-v1', 'Concilio Cryptek', 'Los tecnosabios de la tumba reactivan chronometria, geomancia, tecnologia viva y energia plasmica.', 'Corte Criptecnica', 1, 2, 1, 1, 30, 'necron_cryptek', 'Desbloquea Crypteks basicos.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-oraculos-eternidad'), 'necrones-oraculos-eternidad', 'troops-necrones-v1', 'Oraculos de Eternidad', 'Profetas, senescales y asesinos independientes manipulan el destino de la cruzada.', 'Corte Criptecnica', 2, 2, 2, 1, 30, 'necron_oracle', 'Desbloquea personajes de apoyo y cazadores singulares.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-senores-tormenta'), 'necrones-senores-tormenta', 'troops-necrones-v1', 'Senores de la Tormenta', 'La corte despierta a sus figuras de autoridad mas temidas para reclamar mundos perdidos.', 'Corte Criptecnica', 3, 2, 3, 2, 30, 'necron_lord', 'Desbloquea heroes dinasticos mayores.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-protocolos-crucible'), 'necrones-protocolos-crucible', 'troops-necrones-v1', 'Protocolos Crucible', 'Protocolos experimentales permiten desplegar activos [Crucible] y mandos de plataforma.', 'Corte Criptecnica', 4, 2, 4, 2, 30, 'necron_crucible', 'Desbloquea mandos Crucible y Catacomb Command Barge.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-dioses-fragmentados'), 'necrones-dioses-fragmentados', 'troops-necrones-v1', 'Dioses Fragmentados', 'La dinastia rompe sellos imposibles y conduce fragmentos C''tan y al Rey Silente al tablero.', 'Corte Criptecnica', 5, 2, 5, 3, 30, 'necron_ctan', 'Desbloquea C''tan y The Silent King.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-enjambres-canoptek'), 'necrones-enjambres-canoptek', 'troops-necrones-v1', 'Enjambres Canoptek', 'La maquinaria de mantenimiento despierta en masas menores para limpiar, devorar y cartografiar mundos tumba.', 'Constructos Eternos', 1, 3, 1, 1, 30, 'necron_canoptek', 'Desbloquea enjambres y constructos menores.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-matrices-reparacion'), 'necrones-matrices-reparacion', 'troops-necrones-v1', 'Matrices de Reparacion', 'Constructos canoptek avanzados mantienen la ofensiva, reparan necrodermis y cazan intrusos.', 'Constructos Eternos', 2, 3, 2, 1, 30, 'necron_repair', 'Desbloquea Reanimator, Spyders, Wraiths y Doomstalker.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-arcas-tumba'), 'necrones-arcas-tumba', 'troops-necrones-v1', 'Arcas de la Tumba', 'Transportes, plataformas de supresion y fortificaciones moviles conectan las criptas reactivadas.', 'Constructos Eternos', 3, 3, 3, 2, 30, 'necron_ark', 'Desbloquea arcas y plataformas de apoyo.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-guadanas-noche'), 'necrones-guadanas-noche', 'troops-necrones-v1', 'Guadanas de la Noche', 'Aeronaves y arcas de exterminio abren corredores de terror sobre el frente central.', 'Constructos Eternos', 4, 3, 4, 2, 30, 'necron_air', 'Desbloquea Night Scythe, Doom Scythe, Doomsday Ark y Obelisk.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-megaestructuras-vivientes'), 'necrones-megaestructuras-vivientes', 'troops-necrones-v1', 'Megaestructuras Vivientes', 'La necrodermis titanica vuelve a caminar: portales, bovedas y constructos pesados de final de campana.', 'Constructos Eternos', 5, 3, 5, 3, 30, 'necron_monolith', 'Desbloquea Monolith, Tesseract Vault y Seraptek Heavy Construct.', false, 'active')
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

  delete from public.technology_prerequisites prerequisites
  using public.technology_nodes nodes
  where prerequisites.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-necrones-v1';

  insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
  select tech.id, required.id, data.prerequisite_group
  from (
    values
      ('necrones-protocolos-reanimacion', 'fundacion-planetaria', 1),
      ('necrones-camaras-acecho', 'necrones-protocolos-reanimacion', 1),
      ('necrones-guardia-triarca', 'necrones-camaras-acecho', 1),
      ('necrones-cultos-destructores', 'necrones-guardia-triarca', 1),
      ('necrones-nobleza-dinastica', 'necrones-cultos-destructores', 1),
      ('necrones-concilio-cryptek', 'asamblea-planetaria', 1),
      ('necrones-oraculos-eternidad', 'necrones-concilio-cryptek', 1),
      ('necrones-senores-tormenta', 'necrones-oraculos-eternidad', 1),
      ('necrones-protocolos-crucible', 'necrones-senores-tormenta', 1),
      ('necrones-dioses-fragmentados', 'necrones-protocolos-crucible', 1),
      ('necrones-enjambres-canoptek', 'criadero-guerra', 1),
      ('necrones-enjambres-canoptek', 'maquinaria-belica', 2),
      ('necrones-matrices-reparacion', 'necrones-enjambres-canoptek', 1),
      ('necrones-arcas-tumba', 'necrones-matrices-reparacion', 1),
      ('necrones-guadanas-noche', 'necrones-arcas-tumba', 1),
      ('necrones-megaestructuras-vivientes', 'necrones-guadanas-noche', 1)
  ) as data(technology_slug, required_slug, prerequisite_group)
  join public.technology_nodes tech on tech.slug = data.technology_slug
  join public.technology_nodes required on required.slug = data.required_slug
  on conflict (technology_node_id, required_node_id) do update
  set prerequisite_group = excluded.prerequisite_group;

  delete from public.technology_effects effects
  using public.technology_nodes nodes
  where effects.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-necrones-v1'
    and effects.effect_type = 'unlock_unit_template';

  insert into public.technology_effects (id, technology_node_id, effect_type, payload)
  select
    public.seed_uuid('technology_effect', data.technology_slug || '-units'),
    technology_nodes.id,
    'unlock_unit_template',
    jsonb_build_object('unit_template_slugs', data.unit_template_slugs)
  from (
    values
      ('necrones-protocolos-reanimacion', array['unit-necrones-immortals','unit-necrones-necron-warriors']::text[]),
      ('necrones-camaras-acecho', array['unit-necrones-cryptothralls','unit-necrones-deathmarks','unit-necrones-flayed-ones']::text[]),
      ('necrones-guardia-triarca', array['unit-necrones-lychguard','unit-necrones-triarch-praetorians']::text[]),
      ('necrones-cultos-destructores', array['unit-necrones-lokhust-destroyers','unit-necrones-lokhust-heavy-destroyers','unit-necrones-ophydian-destroyers','unit-necrones-skorpekh-destroyers','unit-necrones-tomb-blades']::text[]),
      ('necrones-nobleza-dinastica', array['unit-necrones-royal-warden','unit-necrones-overlord','unit-necrones-overlord-with-translocation-shroud','unit-necrones-skorpekh-lord']::text[]),
      ('necrones-concilio-cryptek', array['unit-necrones-plasmancer','unit-necrones-psychomancer','unit-necrones-chronomancer','unit-necrones-geomancer','unit-necrones-technomancer']::text[]),
      ('necrones-oraculos-eternidad', array['unit-necrones-trazyn-the-infinite','unit-necrones-orikan-the-diviner','unit-necrones-hexmark-destroyer','unit-necrones-lokhust-lord']::text[]),
      ('necrones-senores-tormenta', array['unit-necrones-imotekh-the-stormlord','unit-necrones-illuminor-szeras','unit-necrones-nekrosor-ammentar']::text[]),
      ('necrones-protocolos-crucible', array['unit-necrones-dynastic-conqueror-crucible','unit-necrones-hyperscientist-crucible','unit-necrones-triarchal-overseer-crucible','unit-necrones-catacomb-command-barge']::text[]),
      ('necrones-dioses-fragmentados', array['unit-necrones-ctan-shard-of-the-deceiver','unit-necrones-transcendent-ctan','unit-necrones-ctan-shard-of-the-void-dragon','unit-necrones-ctan-shard-of-the-nightbringer','unit-necrones-the-silent-king']::text[]),
      ('necrones-enjambres-canoptek', array['unit-necrones-canoptek-scarab-swarms','unit-necrones-canoptek-tomb-crawlers','unit-necrones-canoptek-macrocytes']::text[]),
      ('necrones-matrices-reparacion', array['unit-necrones-canoptek-reanimator','unit-necrones-canoptek-spyders','unit-necrones-canoptek-wraiths','unit-necrones-canoptek-doomstalker']::text[]),
      ('necrones-arcas-tumba', array['unit-necrones-ghost-ark','unit-necrones-annihilation-barge','unit-necrones-triarch-stalker','unit-necrones-convergence-of-dominion']::text[]),
      ('necrones-guadanas-noche', array['unit-necrones-night-scythe','unit-necrones-doom-scythe','unit-necrones-doomsday-ark','unit-necrones-obelisk']::text[]),
      ('necrones-megaestructuras-vivientes', array['unit-necrones-monolith','unit-necrones-tesseract-vault','unit-necrones-seraptek-heavy-construct']::text[])
  ) as data(technology_slug, unit_template_slugs)
  join public.technology_nodes on technology_nodes.slug = data.technology_slug
  on conflict (id) do update
  set technology_node_id = excluded.technology_node_id,
      effect_type = excluded.effect_type,
      payload = excluded.payload;
end;
$$;

revoke execute on function public.seed_necron_troop_technology_tree() from public;
revoke execute on function public.seed_necron_troop_technology_tree() from anon;
revoke execute on function public.seed_necron_troop_technology_tree() from authenticated;
