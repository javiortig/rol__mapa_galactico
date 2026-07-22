create or replace function public.seed_necron_troop_technology_tree()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_necron_faction_id uuid;
begin
  insert into public.technology_nodes (
    id, slug, tree_key, name, description, branch, tier, position_x, position_y,
    cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
  )
  values
    (public.seed_uuid('technology_node', 'necrones-protocolos-reanimacion'), 'necrones-protocolos-reanimacion', 'troops-necrones-v1', 'Protocolos de Reanimacion', 'Las cohortes basicas despiertan en masa y sostienen la primera linea de conquista. Desbloquea: Immortals y Necron Warriors.', 'Falange Dinastica', 1, 1, 2, 1, 30, 'necron_phalanx', 'Desbloquea: Immortals, Necron Warriors.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-camaras-acecho'), 'necrones-camaras-acecho', 'troops-necrones-v1', 'Camaras de Acecho', 'Las criptas laterales despiertan cazadores, guardianes de camara y horrores de emboscada. Desbloquea: Cryptothralls, Deathmarks y Flayed Ones.', 'Falange Dinastica', 2, 1, 1, 1, 30, 'necron_ambush', 'Desbloquea: Cryptothralls, Deathmarks, Flayed Ones.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-guardia-triarca'), 'necrones-guardia-triarca', 'troops-necrones-v1', 'Guardia del Triarca', 'Las castas juramentadas recuperan su funcion como escoltas y ejecutores de la voluntad triarcal. Desbloquea: Lychguard y Triarch Praetorians.', 'Falange Dinastica', 2, 1, 3, 2, 30, 'necron_guard', 'Desbloquea: Lychguard, Triarch Praetorians.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-cultos-destructores'), 'necrones-cultos-destructores', 'troops-necrones-v1', 'Cultos Destructores', 'Las subrutinas de aniquilacion liberan cazadores montados, asesinos hiperfase y plataformas de exterminio. Desbloquea: Lokhust Destroyers, Lokhust Heavy Destroyers, Ophydian Destroyers, Skorpekh Destroyers y Tomb Blades.', 'Falange Dinastica', 3, 1, 1, 2, 30, 'necron_destroyer', 'Desbloquea: Lokhust Destroyers, Lokhust Heavy Destroyers, Ophydian Destroyers, Skorpekh Destroyers, Tomb Blades.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-nobleza-dinastica'), 'necrones-nobleza-dinastica', 'troops-necrones-v1', 'Mandos de la Linea', 'Los primeros nobles recuperan autoridad sobre cohortes, guardianes y objetivos de conquista. Desbloquea: Royal Warden, Overlord y Overlord with Translocation Shroud.', 'Falange Dinastica', 3, 1, 3, 3, 30, 'necron_nobility', 'Desbloquea: Royal Warden, Overlord, Overlord with Translocation Shroud.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-nobles-exterminio'), 'necrones-nobles-exterminio', 'troops-necrones-v1', 'Nobles de Exterminio', 'Los senores ligados a cultos destructores y plataformas de mando toman el control del contraataque. Desbloquea: Skorpekh Lord, Lokhust Lord, Catacomb Command Barge y Triarchal Overseer [Crucible].', 'Falange Dinastica', 4, 1, 2, 3, 30, 'necron_lord', 'Desbloquea: Skorpekh Lord, Lokhust Lord, Catacomb Command Barge, Triarchal Overseer [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-concilio-cryptek'), 'necrones-concilio-cryptek', 'troops-necrones-v1', 'Concilio Cryptek', 'Los tecnosabios de la tumba reactivan chronometria, geomancia, tecnologia viva y energia plasmica. Desbloquea: Plasmancer, Psychomancer, Chronomancer, Geomancer y Technomancer.', 'Corte Criptecnica', 1, 2, 2, 1, 30, 'necron_cryptek', 'Desbloquea: Plasmancer, Psychomancer, Chronomancer, Geomancer, Technomancer.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-oraculos-eternidad'), 'necrones-oraculos-eternidad', 'troops-necrones-v1', 'Oraculos de Eternidad', 'Profetas, coleccionistas imposibles y pistoleros dimensionales alteran el destino de la cruzada. Desbloquea: Trazyn the Infinite, Orikan the Diviner y Hexmark Destroyer.', 'Corte Criptecnica', 2, 2, 1, 1, 30, 'necron_oracle', 'Desbloquea: Trazyn the Infinite, Orikan the Diviner, Hexmark Destroyer.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-senores-tormenta'), 'necrones-senores-tormenta', 'troops-necrones-v1', 'Dinastas Legendarios', 'La corte despierta a sus figuras mas temidas y a protocolos [Crucible] de mando superior. Desbloquea: Imotekh the Stormlord, Illuminor Szeras, Nekrosor Ammentar, Dynastic Conqueror [Crucible] y Hyperscientist [Crucible].', 'Corte Criptecnica', 2, 2, 3, 2, 30, 'necron_lord', 'Desbloquea: Imotekh the Stormlord, Illuminor Szeras, Nekrosor Ammentar, Dynastic Conqueror [Crucible], Hyperscientist [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-dioses-fragmentados'), 'necrones-dioses-fragmentados', 'troops-necrones-v1', 'Dioses Fragmentados', 'La dinastia rompe sellos imposibles y despliega entidades de final de campana. Desbloquea: C''tan Shard of the Deceiver, Transcendent C''tan, C''tan Shard of the Void Dragon, C''tan Shard of the Nightbringer y The Silent King.', 'Corte Criptecnica', 3, 2, 2, 3, 30, 'necron_ctan', 'Desbloquea: C''tan Shard of the Deceiver, Transcendent C''tan, C''tan Shard of the Void Dragon, C''tan Shard of the Nightbringer, The Silent King.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-enjambres-canoptek'), 'necrones-enjambres-canoptek', 'troops-necrones-v1', 'Enjambres Canoptek', 'La maquinaria de mantenimiento despierta en masas menores para limpiar, devorar y cartografiar mundos tumba. Desbloquea: Canoptek Scarab Swarms, Canoptek Tomb Crawlers y Canoptek Macrocytes.', 'Constructos Eternos', 1, 3, 1, 1, 30, 'necron_canoptek', 'Desbloquea: Canoptek Scarab Swarms, Canoptek Tomb Crawlers, Canoptek Macrocytes.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-matrices-reparacion'), 'necrones-matrices-reparacion', 'troops-necrones-v1', 'Matrices de Reparacion', 'Constructos canoptek avanzados mantienen la ofensiva, reparan necrodermis y cazan intrusos. Desbloquea: Canoptek Reanimator, Canoptek Spyders, Canoptek Wraiths y Canoptek Doomstalker.', 'Constructos Eternos', 2, 3, 1, 1, 30, 'necron_repair', 'Desbloquea: Canoptek Reanimator, Canoptek Spyders, Canoptek Wraiths, Canoptek Doomstalker.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-arcas-tumba'), 'necrones-arcas-tumba', 'troops-necrones-v1', 'Arcas de la Tumba', 'Las criptas activan transportes, plataformas de supresion y nodos de dominio territorial. Desbloquea: Ghost Ark, Annihilation Barge, Triarch Stalker y Convergence of Dominion.', 'Constructos Eternos', 1, 3, 3, 2, 30, 'necron_ark', 'Desbloquea: Ghost Ark, Annihilation Barge, Triarch Stalker, Convergence of Dominion.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-guadanas-noche'), 'necrones-guadanas-noche', 'troops-necrones-v1', 'Guadanas de la Noche', 'Aeronaves y arcas de exterminio abren corredores de terror sobre el frente central. Desbloquea: Night Scythe, Doom Scythe, Doomsday Ark y Obelisk.', 'Constructos Eternos', 2, 3, 3, 2, 30, 'necron_air', 'Desbloquea: Night Scythe, Doom Scythe, Doomsday Ark, Obelisk.', false, 'active'),
    (public.seed_uuid('technology_node', 'necrones-megaestructuras-vivientes'), 'necrones-megaestructuras-vivientes', 'troops-necrones-v1', 'Megaestructuras Vivientes', 'La necrodermis titanica vuelve a caminar mediante portales, bovedas y constructos pesados de final de campana. Desbloquea: Monolith, Tesseract Vault y Seraptek Heavy Construct.', 'Constructos Eternos', 3, 3, 2, 3, 30, 'necron_monolith', 'Desbloquea: Monolith, Tesseract Vault, Seraptek Heavy Construct.', false, 'active')
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
  where tree_key = 'troops-necrones-v1'
    and slug not in (
      'necrones-protocolos-reanimacion',
      'necrones-camaras-acecho',
      'necrones-guardia-triarca',
      'necrones-cultos-destructores',
      'necrones-nobleza-dinastica',
      'necrones-nobles-exterminio',
      'necrones-concilio-cryptek',
      'necrones-oraculos-eternidad',
      'necrones-senores-tormenta',
      'necrones-dioses-fragmentados',
      'necrones-enjambres-canoptek',
      'necrones-matrices-reparacion',
      'necrones-arcas-tumba',
      'necrones-guadanas-noche',
      'necrones-megaestructuras-vivientes'
    );

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
      ('necrones-guardia-triarca', 'necrones-protocolos-reanimacion', 1),
      ('necrones-cultos-destructores', 'necrones-camaras-acecho', 1),
      ('necrones-cultos-destructores', 'maquinaria-belica', 2),
      ('necrones-nobleza-dinastica', 'necrones-guardia-triarca', 1),
      ('necrones-nobleza-dinastica', 'asamblea-planetaria', 2),
      ('necrones-nobles-exterminio', 'necrones-cultos-destructores', 1),
      ('necrones-nobles-exterminio', 'necrones-nobleza-dinastica', 2),
      ('necrones-concilio-cryptek', 'asamblea-planetaria', 1),
      ('necrones-oraculos-eternidad', 'necrones-concilio-cryptek', 1),
      ('necrones-senores-tormenta', 'necrones-concilio-cryptek', 1),
      ('necrones-senores-tormenta', 'necrones-nobleza-dinastica', 2),
      ('necrones-dioses-fragmentados', 'necrones-oraculos-eternidad', 1),
      ('necrones-dioses-fragmentados', 'necrones-senores-tormenta', 2),
      ('necrones-dioses-fragmentados', 'necrones-nobles-exterminio', 3),
      ('necrones-enjambres-canoptek', 'criadero-guerra', 1),
      ('necrones-enjambres-canoptek', 'maquinaria-belica', 2),
      ('necrones-matrices-reparacion', 'necrones-enjambres-canoptek', 1),
      ('necrones-arcas-tumba', 'maquinaria-belica', 1),
      ('necrones-arcas-tumba', 'necrones-protocolos-reanimacion', 2),
      ('necrones-guadanas-noche', 'necrones-arcas-tumba', 1),
      ('necrones-megaestructuras-vivientes', 'necrones-matrices-reparacion', 1),
      ('necrones-megaestructuras-vivientes', 'necrones-guadanas-noche', 2)
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
      ('necrones-nobleza-dinastica', array['unit-necrones-royal-warden','unit-necrones-overlord','unit-necrones-overlord-with-translocation-shroud']::text[]),
      ('necrones-nobles-exterminio', array['unit-necrones-skorpekh-lord','unit-necrones-lokhust-lord','unit-necrones-catacomb-command-barge','unit-necrones-triarchal-overseer-crucible']::text[]),
      ('necrones-concilio-cryptek', array['unit-necrones-plasmancer','unit-necrones-psychomancer','unit-necrones-chronomancer','unit-necrones-geomancer','unit-necrones-technomancer']::text[]),
      ('necrones-oraculos-eternidad', array['unit-necrones-trazyn-the-infinite','unit-necrones-orikan-the-diviner','unit-necrones-hexmark-destroyer']::text[]),
      ('necrones-senores-tormenta', array['unit-necrones-imotekh-the-stormlord','unit-necrones-illuminor-szeras','unit-necrones-nekrosor-ammentar','unit-necrones-dynastic-conqueror-crucible','unit-necrones-hyperscientist-crucible']::text[]),
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

  select id into v_necron_faction_id
  from public.factions
  where slug = 'necrones';

  if v_necron_faction_id is not null then
    update public.unit_templates
    set is_available = false,
        required_technology_node_id = null
    where faction_id = v_necron_faction_id;

    update public.unit_templates templates
    set is_available = true,
        required_technology_node_id = technology_nodes.id
    from (
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
        ('unit-necrones-lokhust-lord', 'necrones-nobles-exterminio'),
        ('unit-necrones-catacomb-command-barge', 'necrones-nobles-exterminio'),
        ('unit-necrones-triarchal-overseer-crucible', 'necrones-nobles-exterminio'),
        ('unit-necrones-plasmancer', 'necrones-concilio-cryptek'),
        ('unit-necrones-psychomancer', 'necrones-concilio-cryptek'),
        ('unit-necrones-chronomancer', 'necrones-concilio-cryptek'),
        ('unit-necrones-geomancer', 'necrones-concilio-cryptek'),
        ('unit-necrones-technomancer', 'necrones-concilio-cryptek'),
        ('unit-necrones-trazyn-the-infinite', 'necrones-oraculos-eternidad'),
        ('unit-necrones-orikan-the-diviner', 'necrones-oraculos-eternidad'),
        ('unit-necrones-hexmark-destroyer', 'necrones-oraculos-eternidad'),
        ('unit-necrones-imotekh-the-stormlord', 'necrones-senores-tormenta'),
        ('unit-necrones-illuminor-szeras', 'necrones-senores-tormenta'),
        ('unit-necrones-nekrosor-ammentar', 'necrones-senores-tormenta'),
        ('unit-necrones-dynastic-conqueror-crucible', 'necrones-senores-tormenta'),
        ('unit-necrones-hyperscientist-crucible', 'necrones-senores-tormenta'),
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
    ) as assignments(unit_slug, technology_slug)
    join public.technology_nodes on technology_nodes.slug = assignments.technology_slug
    where templates.slug = assignments.unit_slug
      and templates.faction_id = v_necron_faction_id;

    perform public.refresh_available_technologies(v_necron_faction_id);
  end if;
end;
$$;

revoke execute on function public.seed_necron_troop_technology_tree() from public;
revoke execute on function public.seed_necron_troop_technology_tree() from anon;
revoke execute on function public.seed_necron_troop_technology_tree() from authenticated;

select public.seed_necron_troop_technology_tree();
