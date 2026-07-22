create temp table temp_necron_troop_technology_nodes (
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
) on commit drop;

insert into temp_necron_troop_technology_nodes (
  slug, name, description, branch, tier, position_x, position_y, cost_technology, research_time_seconds,
  icon_key, effect_summary, prerequisite_slugs, unit_template_slugs
)
values
  (
    'necrones-protocolos-reanimacion',
    'Protocolos de Reanimacion',
    'Las cohortes basicas despiertan en masa y sostienen la primera linea de conquista.',
    'Falange Dinastica',
    1, 1, 1, 1, 30, 'necron_phalanx',
    'Desbloquea Warriors e Immortals.',
    array['fundacion-planetaria'],
    array['unit-necrones-immortals','unit-necrones-necron-warriors']
  ),
  (
    'necrones-camaras-acecho',
    'Camaras de Acecho',
    'Asesinos, custodios cripticos y horrores desollados preparan emboscadas desde tumbas ocultas.',
    'Falange Dinastica',
    2, 1, 2, 1, 30, 'necron_ambush',
    'Desbloquea Cryptothralls, Deathmarks y Flayed Ones.',
    array['necrones-protocolos-reanimacion'],
    array['unit-necrones-cryptothralls','unit-necrones-deathmarks','unit-necrones-flayed-ones']
  ),
  (
    'necrones-guardia-triarca',
    'Guardia del Triarca',
    'Las castas juramentadas recuperan su funcion: custodiar nobles y ejecutar la voluntad del Triarca.',
    'Falange Dinastica',
    3, 1, 3, 2, 30, 'necron_guard',
    'Desbloquea Lychguard y Triarch Praetorians.',
    array['necrones-camaras-acecho'],
    array['unit-necrones-lychguard','unit-necrones-triarch-praetorians']
  ),
  (
    'necrones-cultos-destructores',
    'Cultos Destructores',
    'La obsesion por la aniquilacion toma forma en cazadores, filos hiperfase y plataformas antigraviticas.',
    'Falange Dinastica',
    4, 1, 4, 2, 30, 'necron_destroyer',
    'Desbloquea Destroyers y Tomb Blades.',
    array['necrones-guardia-triarca'],
    array['unit-necrones-lokhust-destroyers','unit-necrones-lokhust-heavy-destroyers','unit-necrones-ophydian-destroyers','unit-necrones-skorpekh-destroyers','unit-necrones-tomb-blades']
  ),
  (
    'necrones-nobleza-dinastica',
    'Nobleza Dinastica',
    'Los mandos de batalla imponen jerarquia sobre cohortes, guardias y asesinos de la dinastia.',
    'Falange Dinastica',
    5, 1, 5, 3, 30, 'necron_nobility',
    'Desbloquea mandos comunes de la dinastia.',
    array['necrones-cultos-destructores'],
    array['unit-necrones-royal-warden','unit-necrones-overlord','unit-necrones-overlord-with-translocation-shroud','unit-necrones-skorpekh-lord']
  ),
  (
    'necrones-concilio-cryptek',
    'Concilio Cryptek',
    'Los tecnosabios de la tumba reactivan chronometria, geomancia, tecnologia viva y energia plasmica.',
    'Corte Criptecnica',
    1, 2, 1, 1, 30, 'necron_cryptek',
    'Desbloquea Crypteks basicos.',
    array['asamblea-planetaria'],
    array['unit-necrones-plasmancer','unit-necrones-psychomancer','unit-necrones-chronomancer','unit-necrones-geomancer','unit-necrones-technomancer']
  ),
  (
    'necrones-oraculos-eternidad',
    'Oraculos de Eternidad',
    'Profetas, senescales y asesinos independientes manipulan el destino de la cruzada.',
    'Corte Criptecnica',
    2, 2, 2, 1, 30, 'necron_oracle',
    'Desbloquea personajes de apoyo y cazadores singulares.',
    array['necrones-concilio-cryptek'],
    array['unit-necrones-trazyn-the-infinite','unit-necrones-orikan-the-diviner','unit-necrones-hexmark-destroyer','unit-necrones-lokhust-lord']
  ),
  (
    'necrones-senores-tormenta',
    'Senores de la Tormenta',
    'La corte despierta a sus figuras de autoridad mas temidas para reclamar mundos perdidos.',
    'Corte Criptecnica',
    3, 2, 3, 2, 30, 'necron_lord',
    'Desbloquea heroes dinasticos mayores.',
    array['necrones-oraculos-eternidad'],
    array['unit-necrones-imotekh-the-stormlord','unit-necrones-illuminor-szeras','unit-necrones-nekrosor-ammentar']
  ),
  (
    'necrones-protocolos-crucible',
    'Protocolos Crucible',
    'Protocolos experimentales permiten desplegar activos [Crucible] y mandos de plataforma.',
    'Corte Criptecnica',
    4, 2, 4, 2, 30, 'necron_crucible',
    'Desbloquea mandos Crucible y Catacomb Command Barge.',
    array['necrones-senores-tormenta'],
    array['unit-necrones-dynastic-conqueror-crucible','unit-necrones-hyperscientist-crucible','unit-necrones-triarchal-overseer-crucible','unit-necrones-catacomb-command-barge']
  ),
  (
    'necrones-dioses-fragmentados',
    'Dioses Fragmentados',
    'La dinastia rompe sellos imposibles y conduce fragmentos C''tan y al Rey Silente al tablero.',
    'Corte Criptecnica',
    5, 2, 5, 3, 30, 'necron_ctan',
    'Desbloquea C''tan y The Silent King.',
    array['necrones-protocolos-crucible'],
    array['unit-necrones-ctan-shard-of-the-deceiver','unit-necrones-transcendent-ctan','unit-necrones-ctan-shard-of-the-void-dragon','unit-necrones-ctan-shard-of-the-nightbringer','unit-necrones-the-silent-king']
  ),
  (
    'necrones-enjambres-canoptek',
    'Enjambres Canoptek',
    'La maquinaria de mantenimiento despierta en masas menores para limpiar, devorar y cartografiar mundos tumba.',
    'Constructos Eternos',
    1, 3, 1, 1, 30, 'necron_canoptek',
    'Desbloquea enjambres y constructos menores.',
    array['criadero-guerra','maquinaria-belica'],
    array['unit-necrones-canoptek-scarab-swarms','unit-necrones-canoptek-tomb-crawlers','unit-necrones-canoptek-macrocytes']
  ),
  (
    'necrones-matrices-reparacion',
    'Matrices de Reparacion',
    'Constructos canoptek avanzados mantienen la ofensiva, reparan necrodermis y cazan intrusos.',
    'Constructos Eternos',
    2, 3, 2, 1, 30, 'necron_repair',
    'Desbloquea Reanimator, Spyders, Wraiths y Doomstalker.',
    array['necrones-enjambres-canoptek'],
    array['unit-necrones-canoptek-reanimator','unit-necrones-canoptek-spyders','unit-necrones-canoptek-wraiths','unit-necrones-canoptek-doomstalker']
  ),
  (
    'necrones-arcas-tumba',
    'Arcas de la Tumba',
    'Transportes, plataformas de supresion y fortificaciones moviles conectan las criptas reactivadas.',
    'Constructos Eternos',
    3, 3, 3, 2, 30, 'necron_ark',
    'Desbloquea arcas y plataformas de apoyo.',
    array['necrones-matrices-reparacion'],
    array['unit-necrones-ghost-ark','unit-necrones-annihilation-barge','unit-necrones-triarch-stalker','unit-necrones-convergence-of-dominion']
  ),
  (
    'necrones-guadanas-noche',
    'Guadanas de la Noche',
    'Aeronaves y arcas de exterminio abren corredores de terror sobre el frente central.',
    'Constructos Eternos',
    4, 3, 4, 2, 30, 'necron_air',
    'Desbloquea Night Scythe, Doom Scythe, Doomsday Ark y Obelisk.',
    array['necrones-arcas-tumba'],
    array['unit-necrones-night-scythe','unit-necrones-doom-scythe','unit-necrones-doomsday-ark','unit-necrones-obelisk']
  ),
  (
    'necrones-megaestructuras-vivientes',
    'Megaestructuras Vivientes',
    'La necrodermis titanica vuelve a caminar: portales, bovedas y constructos pesados de final de campana.',
    'Constructos Eternos',
    5, 3, 5, 3, 30, 'necron_monolith',
    'Desbloquea Monolith, Tesseract Vault y Seraptek Heavy Construct.',
    array['necrones-guadanas-noche'],
    array['unit-necrones-monolith','unit-necrones-tesseract-vault','unit-necrones-seraptek-heavy-construct']
  );

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
from temp_necron_troop_technology_nodes nodes
on conflict (slug) do update
set
  tree_key = excluded.tree_key,
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
select
  tech.id,
  required.id,
  prerequisite.ordinality::integer
from temp_necron_troop_technology_nodes nodes
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
from temp_necron_troop_technology_nodes nodes
join public.technology_nodes on technology_nodes.slug = nodes.slug
on conflict (id) do update
set
  technology_node_id = excluded.technology_node_id,
  effect_type = excluded.effect_type,
  payload = excluded.payload;

update public.unit_templates templates
set
  is_available = true,
  required_technology_node_id = technology_nodes.id
from temp_necron_troop_technology_nodes nodes
cross join lateral unnest(nodes.unit_template_slugs) as unit_slug
join public.technology_nodes on technology_nodes.slug = nodes.slug
where templates.slug = unit_slug
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
