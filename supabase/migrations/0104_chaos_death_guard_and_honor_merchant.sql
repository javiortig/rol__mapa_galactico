-- Merge the Death Guard roster into the existing Daemonic Legions faction.
-- The internal faction slug remains stable so live users, territory and progress survive.

update public.factions
set name = 'El Caos'
where slug = 'legiones-daemonicas';

update public.profiles
set display_name = 'Heraldo del Caos'
where id in (
  select player_factions.user_id
  from public.player_factions
  join public.factions on factions.id = player_factions.faction_id
  where factions.slug = 'legiones-daemonicas'
);

create table if not exists public.unit_template_technology_unlocks (
  unit_template_id uuid not null references public.unit_templates(id) on delete cascade,
  technology_node_id uuid not null references public.technology_nodes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (unit_template_id, technology_node_id)
);

create index if not exists unit_template_technology_unlocks_node_idx
on public.unit_template_technology_unlocks (technology_node_id, unit_template_id);

alter table public.unit_template_technology_unlocks enable row level security;

drop policy if exists unit_template_technology_unlocks_select_public
on public.unit_template_technology_unlocks;

create policy unit_template_technology_unlocks_select_public
on public.unit_template_technology_unlocks
for select
to anon, authenticated
using (true);

grant select on public.unit_template_technology_unlocks to anon, authenticated;
revoke insert, update, delete on public.unit_template_technology_unlocks from anon, authenticated;

-- Preserve the legacy single-node requirement as a relation before adding OR unlocks.
insert into public.unit_template_technology_unlocks (unit_template_id, technology_node_id)
select id, required_technology_node_id
from public.unit_templates
where required_technology_node_id is not null
on conflict do nothing;

with desired_nodes(slug, description, effect_summary, research_time_seconds) as (
  values
    ('daemonicas-chispas-inmaterium',
      'Los primeros coros del Caos avanzan entre magia viva y guerreros marcados por la plaga. Desbloquea: Blue Horrors, Pink Horrors y Plague Marines.',
      'Desbloquea: Blue Horrors, Pink Horrors, Plague Marines.', 172800),
    ('daemonicas-carros-fuego-mutante',
      'Bestias aullantes y engendros mutados cruzan la batalla como meteoros de hambre y hechicería. Desbloquea: Screamers y Chaos Spawn.',
      'Desbloquea: Screamers, Chaos Spawn.', 172800),
    ('daemonicas-llamas-imposibles',
      'Una llama con nombre propio cruza el velo mientras una marea de muertos resistentes ocupa las ruinas. Desbloquea: Exalted Flamer y Poxwalkers.',
      'Desbloquea: Exalted Flamer, Poxwalkers.', 172800),
    ('daemonicas-mareas-rosadas',
      'Las llamas del cambio persiguen objetivos con voluntad propia mientras la guardia corrupta cierra la brecha. Desbloquea: Flamers y Blightlord Terminators.',
      'Desbloquea: Flamers, Blightlord Terminators.', 172800),
    ('daemonicas-carros-ardientes',
      'Plataformas de fuego cambiante y drones corruptos cabalgan sobre la tormenta para abrir brechas. Desbloquea: Burning Chariot y Foetid Bloat-drone.',
      'Desbloquea: Burning Chariot, Foetid Bloat-drone.', 172800),
    ('daemonicas-forja-almas-tzeentch',
      'La disformidad encadena máquinas infernales y llama al Primarca de la Plaga al frente. Desbloquea: Tzeentch Soul Grinder y Mortarion.',
      'Desbloquea: Tzeentch Soul Grinder, Mortarion.', 259200),
    ('daemonicas-piras-cambio',
      'Los horrores reciben maestros de hechicería y heraldos de la entropía capaces de convertir caos bruto en plan. Desbloquea: Changecaster y Noxious Blightbringer.',
      'Desbloquea: Changecaster, Noxious Blightbringer.', 86400),
    ('daemonicas-voces-velo',
      'Los heraldos sin nombre y los hechiceros de la plaga traducen augurios imposibles en órdenes. Desbloquea: Daemonic Herald [Crucible] y Malignant Plaguecaster.',
      'Desbloquea: Daemonic Herald [Crucible], Malignant Plaguecaster.', 86400),
    ('daemonicas-discos-sortilegio',
      'Augures montados, señores de disco y alquimistas de la plaga tuercen el destino del frente. Desbloquea: Fluxmaster, Fateskimmer y Biologus Putrifier.',
      'Desbloquea: Fluxmaster, Fateskimmer, Biologus Putrifier.', 172800),
    ('daemonicas-escribas-destino',
      'Los nombres verdaderos y las rutas de invasión quedan inscritos junto a planos de máquinas corruptas. Desbloquea: The Blue Scribes, Myphitic Blight-hauler y Chaos Predator Annihilator.',
      'Desbloquea: The Blue Scribes, Myphitic Blight-hauler, Chaos Predator Annihilator.', 172800),
    ('daemonicas-mascaras-engano',
      'La corte aprende a ganar guerras con apariciones, aurigas y campeones acorazados por la podredumbre. Desbloquea: The Changeling, Daemonic Charioteer [Crucible] y Lord of Contagion.',
      'Desbloquea: The Changeling, Daemonic Charioteer [Crucible], Lord of Contagion.', 259200),
    ('daemonicas-senor-cambio',
      'Un Gran Demonio de Tzeentch atraviesa el velo junto a ingenios de plaga de avance inexorable. Desbloquea: Lord of Change, Myphitic Blight-hauler y Foetid Bloat-drone with Heavy Blight Launcher.',
      'Desbloquea: Lord of Change, Myphitic Blight-hauler, Foetid Bloat-drone with Heavy Blight Launcher.', 172800),
    ('daemonicas-kairos-teje-destinos',
      'La campaña queda atrapada entre futuros contradictorios mientras la artillería de plaga avanza. Desbloquea: Kairos Fateweaver y Plagueburst Crawler.',
      'Desbloquea: Kairos Fateweaver, Plagueburst Crawler.', 172800),
    ('daemonicas-primer-principe',
      'Las sendas rivales de la disformidad se inclinan ante una sombra y sus máquinas profanadas. Desbloquea: Be''lakor y Defiler.',
      'Desbloquea: Be''lakor, Defiler.', 172800),
    ('daemonicas-ascension-demonica',
      'La carne mortal deja de importar cuando la voluntad de la disformidad moldea príncipes capaces de mandar legiones. Desbloquea: Daemon Prince of Chaos y Daemon Prince of Chaos with wings.',
      'Desbloquea: Daemon Prince of Chaos, Daemon Prince of Chaos with wings.', 172800)
)
update public.technology_nodes as nodes
set description = desired_nodes.description,
    effect_summary = desired_nodes.effect_summary,
    research_time_seconds = desired_nodes.research_time_seconds,
    updated_at = now()
from desired_nodes
where nodes.slug = desired_nodes.slug
  and nodes.tree_key = 'troops-legiones-daemonicas-v1';

with desired_units(
  slug, name, category, unit_type, unit_keywords, points, default_quantity,
  wounds_per_model, supply_cost, minerals_cost, honor_cost, gold_cost,
  recruitment_time_seconds, recruitment_building_type, technology_slug
) as (
  values
    ('unit-legiones-daemonicas-plague-marines', 'Plague Marines', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 90, 5, 2, 90, 0, 0, 0, 86400, 'barracon-infanteria', 'daemonicas-chispas-inmaterium'),
    ('unit-legiones-daemonicas-chaos-spawn', 'Chaos Spawn', 'Otras hojas de datos', 'beast', array['Bestia']::text[], 80, 2, 4, 64, 8, 0, 0, 86400, 'nido-bestias', 'daemonicas-carros-fuego-mutante'),
    ('unit-legiones-daemonicas-poxwalkers', 'Poxwalkers', 'Linea de batalla', 'infantry', array['Infanteria']::text[], 65, 10, 1, 65, 0, 0, 0, 86400, 'barracon-infanteria', 'daemonicas-llamas-imposibles'),
    ('unit-legiones-daemonicas-blightlord-terminators', 'Blightlord Terminators', 'Otras hojas de datos', 'infantry', array['Infanteria']::text[], 115, 3, 3, 74, 8, 0, 5, 172800, 'barracon-infanteria', 'daemonicas-mareas-rosadas'),
    ('unit-legiones-daemonicas-foetid-bloat-drone', 'Foetid Bloat-drone', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 100, 1, 10, 0, 50, 0, 0, 172800, 'taller-guerra', 'daemonicas-carros-ardientes'),
    ('unit-legiones-daemonicas-mortarion', 'Mortarion', 'Personaje', 'character', array['Monstruo','Caracter']::text[], 375, 1, 16, 64, 18, 37, 18, 345600, 'cuartel-mando', 'daemonicas-forja-almas-tzeentch'),
    ('unit-legiones-daemonicas-myphitic-blight-hauler', 'Myphitic Blight-hauler', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 95, 1, 10, 0, 48, 0, 0, 172800, 'taller-guerra', 'daemonicas-senor-cambio'),
    ('unit-legiones-daemonicas-foetid-bloat-drone-heavy-blight-launcher', 'Foetid Bloat-drone with Heavy Blight Launcher', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 125, 1, 10, 0, 63, 0, 0, 172800, 'taller-guerra', 'daemonicas-senor-cambio'),
    ('unit-legiones-daemonicas-plagueburst-crawler', 'Plagueburst Crawler', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 170, 1, 12, 0, 65, 0, 8, 172800, 'taller-guerra', 'daemonicas-kairos-teje-destinos'),
    ('unit-legiones-daemonicas-defiler', 'Defiler', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 300, 1, 14, 0, 150, 0, 0, 259200, 'taller-guerra', 'daemonicas-primer-principe'),
    ('unit-legiones-daemonicas-noxious-blightbringer', 'Noxious Blightbringer', 'Personaje', 'character', array['Infanteria','Caracter']::text[], 50, 1, 4, 19, 3, 5, 0, 86400, 'cuartel-mando', 'daemonicas-piras-cambio'),
    ('unit-legiones-daemonicas-malignant-plaguecaster', 'Malignant Plaguecaster', 'Personaje', 'character', array['Infanteria','Caracter']::text[], 60, 1, 4, 22, 4, 6, 0, 86400, 'cuartel-mando', 'daemonicas-voces-velo'),
    ('unit-legiones-daemonicas-biologus-putrifier', 'Biologus Putrifier', 'Personaje', 'character', array['Infanteria','Caracter']::text[], 60, 1, 4, 22, 4, 6, 0, 86400, 'cuartel-mando', 'daemonicas-discos-sortilegio'),
    ('unit-legiones-daemonicas-chaos-predator-annihilator', 'Chaos Predator Annihilator', 'Otras hojas de datos', 'vehicle', array['Vehiculo']::text[], 135, 1, 11, 0, 68, 0, 0, 172800, 'taller-guerra', 'daemonicas-escribas-destino'),
    ('unit-legiones-daemonicas-lord-of-contagion', 'Lord of Contagion', 'Personaje', 'character', array['Infanteria','Caracter']::text[], 120, 1, 6, 18, 6, 12, 6, 172800, 'cuartel-mando', 'daemonicas-mascaras-engano')
)
insert into public.unit_templates (
  id, slug, faction_id, name, category, unit_type, unit_keywords, points,
  default_quantity, wounds_per_model, supply_cost, minerals_cost,
  ancestral_stone_cost, honor_cost, gold_cost, industrial_material_cost,
  uridium_cost, technology_cost, recruitment_time_seconds,
  recruitment_building_type, notes, is_available,
  required_technology_node_id, source_section, source_faction_name,
  is_allied_unit
)
select
  public.seed_uuid('unit_template', desired_units.slug),
  desired_units.slug,
  factions.id,
  desired_units.name,
  desired_units.category,
  desired_units.unit_type,
  desired_units.unit_keywords,
  desired_units.points,
  desired_units.default_quantity,
  desired_units.wounds_per_model,
  desired_units.supply_cost,
  desired_units.minerals_cost,
  0,
  desired_units.honor_cost,
  desired_units.gold_cost,
  0,
  0,
  0,
  desired_units.recruitment_time_seconds,
  desired_units.recruitment_building_type,
  'Unidad de Death Guard integrada en El Caos.',
  true,
  technology_nodes.id,
  'Death Guard',
  'Chaos - Death Guard',
  false
from desired_units
join public.factions on factions.slug = 'legiones-daemonicas'
join public.technology_nodes on technology_nodes.slug = desired_units.technology_slug
on conflict (slug) do update
set faction_id = excluded.faction_id,
    name = excluded.name,
    category = excluded.category,
    unit_type = excluded.unit_type,
    unit_keywords = excluded.unit_keywords,
    points = excluded.points,
    default_quantity = excluded.default_quantity,
    wounds_per_model = excluded.wounds_per_model,
    supply_cost = excluded.supply_cost,
    minerals_cost = excluded.minerals_cost,
    ancestral_stone_cost = 0,
    honor_cost = excluded.honor_cost,
    gold_cost = excluded.gold_cost,
    industrial_material_cost = 0,
    uridium_cost = 0,
    technology_cost = 0,
    recruitment_time_seconds = excluded.recruitment_time_seconds,
    recruitment_building_type = excluded.recruitment_building_type,
    notes = excluded.notes,
    is_available = true,
    required_technology_node_id = excluded.required_technology_node_id,
    source_section = excluded.source_section,
    source_faction_name = excluded.source_faction_name,
    is_allied_unit = false;

with desired_unlocks(template_slug, technology_slug) as (
  values
    ('unit-legiones-daemonicas-plague-marines', 'daemonicas-chispas-inmaterium'),
    ('unit-legiones-daemonicas-chaos-spawn', 'daemonicas-carros-fuego-mutante'),
    ('unit-legiones-daemonicas-poxwalkers', 'daemonicas-llamas-imposibles'),
    ('unit-legiones-daemonicas-blightlord-terminators', 'daemonicas-mareas-rosadas'),
    ('unit-legiones-daemonicas-foetid-bloat-drone', 'daemonicas-carros-ardientes'),
    ('unit-legiones-daemonicas-mortarion', 'daemonicas-forja-almas-tzeentch'),
    ('unit-legiones-daemonicas-myphitic-blight-hauler', 'daemonicas-senor-cambio'),
    ('unit-legiones-daemonicas-myphitic-blight-hauler', 'daemonicas-escribas-destino'),
    ('unit-legiones-daemonicas-foetid-bloat-drone-heavy-blight-launcher', 'daemonicas-senor-cambio'),
    ('unit-legiones-daemonicas-plagueburst-crawler', 'daemonicas-kairos-teje-destinos'),
    ('unit-legiones-daemonicas-defiler', 'daemonicas-primer-principe'),
    ('unit-legiones-daemonicas-noxious-blightbringer', 'daemonicas-piras-cambio'),
    ('unit-legiones-daemonicas-malignant-plaguecaster', 'daemonicas-voces-velo'),
    ('unit-legiones-daemonicas-biologus-putrifier', 'daemonicas-discos-sortilegio'),
    ('unit-legiones-daemonicas-chaos-predator-annihilator', 'daemonicas-escribas-destino'),
    ('unit-legiones-daemonicas-lord-of-contagion', 'daemonicas-mascaras-engano')
)
insert into public.unit_template_technology_unlocks (unit_template_id, technology_node_id)
select unit_templates.id, technology_nodes.id
from desired_unlocks
join public.unit_templates on unit_templates.slug = desired_unlocks.template_slug
join public.technology_nodes on technology_nodes.slug = desired_unlocks.technology_slug
on conflict do nothing;

-- Keep the tree's descriptive unlock effects synchronized with recruitment rules.
with desired_effects(technology_slug, unit_template_slugs) as (
  values
    ('daemonicas-chispas-inmaterium', array['unit-legiones-daemonicas-blue-horrors','unit-legiones-daemonicas-pink-horrors','unit-legiones-daemonicas-plague-marines']::text[]),
    ('daemonicas-carros-fuego-mutante', array['unit-legiones-daemonicas-screamers','unit-legiones-daemonicas-chaos-spawn']::text[]),
    ('daemonicas-llamas-imposibles', array['unit-legiones-daemonicas-exalted-flamer','unit-legiones-daemonicas-poxwalkers']::text[]),
    ('daemonicas-mareas-rosadas', array['unit-legiones-daemonicas-flamers','unit-legiones-daemonicas-blightlord-terminators']::text[]),
    ('daemonicas-carros-ardientes', array['unit-legiones-daemonicas-burning-chariot','unit-legiones-daemonicas-foetid-bloat-drone']::text[]),
    ('daemonicas-forja-almas-tzeentch', array['unit-legiones-daemonicas-tzeentch-soul-grinder','unit-legiones-daemonicas-mortarion']::text[]),
    ('daemonicas-piras-cambio', array['unit-legiones-daemonicas-changecaster','unit-legiones-daemonicas-noxious-blightbringer']::text[]),
    ('daemonicas-voces-velo', array['unit-legiones-daemonicas-daemonic-herald-crucible','unit-legiones-daemonicas-malignant-plaguecaster']::text[]),
    ('daemonicas-discos-sortilegio', array['unit-legiones-daemonicas-fluxmaster','unit-legiones-daemonicas-fateskimmer','unit-legiones-daemonicas-biologus-putrifier']::text[]),
    ('daemonicas-escribas-destino', array['unit-legiones-daemonicas-the-blue-scribes','unit-legiones-daemonicas-myphitic-blight-hauler','unit-legiones-daemonicas-chaos-predator-annihilator']::text[]),
    ('daemonicas-mascaras-engano', array['unit-legiones-daemonicas-the-changeling','unit-legiones-daemonicas-daemonic-charioteer-crucible','unit-legiones-daemonicas-lord-of-contagion']::text[]),
    ('daemonicas-ascension-demonica', array['unit-legiones-daemonicas-daemon-prince-of-chaos','unit-legiones-daemonicas-daemon-prince-of-chaos-with-wings']::text[]),
    ('daemonicas-senor-cambio', array['unit-legiones-daemonicas-lord-of-change','unit-legiones-daemonicas-myphitic-blight-hauler','unit-legiones-daemonicas-foetid-bloat-drone-heavy-blight-launcher']::text[]),
    ('daemonicas-kairos-teje-destinos', array['unit-legiones-daemonicas-kairos-fateweaver','unit-legiones-daemonicas-plagueburst-crawler']::text[]),
    ('daemonicas-primer-principe', array['unit-legiones-daemonicas-belakor','unit-legiones-daemonicas-defiler']::text[])
)
insert into public.technology_effects (id, technology_node_id, effect_type, payload)
select
  public.seed_uuid('technology_effect', desired_effects.technology_slug || '-units'),
  technology_nodes.id,
  'unlock_unit_template',
  jsonb_build_object('unit_template_slugs', desired_effects.unit_template_slugs)
from desired_effects
join public.technology_nodes on technology_nodes.slug = desired_effects.technology_slug
on conflict (id) do update
set technology_node_id = excluded.technology_node_id,
    effect_type = excluded.effect_type,
    payload = excluded.payload;

insert into public.unit_template_model_options (
  id, unit_template_id, slug, label, models, min_models, max_models, points,
  copy_from, copy_to, source, points_change_direction, points_change_amount
)
select
  public.seed_uuid('unit_template_model_option', data.template_slug || ':' || data.slug),
  unit_templates.id,
  data.slug,
  data.label,
  data.models,
  data.min_models,
  data.max_models,
  data.points,
  data.copy_from,
  data.copy_to,
  'mfm',
  null,
  null
from (
  values
    ('unit-legiones-daemonicas-plague-marines', 'models-5-5-copy-1-plus', '5 miniaturas', 5, 5, 5, 90, 1, null::integer),
    ('unit-legiones-daemonicas-plague-marines', 'models-7-7-copy-1-plus', '7 miniaturas', 7, 7, 7, 125, 1, null::integer),
    ('unit-legiones-daemonicas-plague-marines', 'models-10-10-copy-1-plus', '10 miniaturas', 10, 10, 10, 180, 1, null::integer),
    ('unit-legiones-daemonicas-chaos-spawn', 'models-2-2-copy-1-plus', '2 miniaturas', 2, 2, 2, 80, 1, null::integer),
    ('unit-legiones-daemonicas-poxwalkers', 'models-10-10-copy-1-plus', '10 miniaturas', 10, 10, 10, 65, 1, null::integer),
    ('unit-legiones-daemonicas-poxwalkers', 'models-20-20-copy-1-plus', '20 miniaturas', 20, 20, 20, 130, 1, null::integer),
    ('unit-legiones-daemonicas-blightlord-terminators', 'models-3-3-copy-1-plus', '3 miniaturas', 3, 3, 3, 115, 1, null::integer),
    ('unit-legiones-daemonicas-blightlord-terminators', 'models-5-5-copy-1-plus', '5 miniaturas', 5, 5, 5, 180, 1, null::integer),
    ('unit-legiones-daemonicas-blightlord-terminators', 'models-10-10-copy-1-plus', '10 miniaturas', 10, 10, 10, 360, 1, null::integer),
    ('unit-legiones-daemonicas-foetid-bloat-drone', 'models-1-1-copy-1-2', '1 miniatura', 1, 1, 1, 100, 1, 2),
    ('unit-legiones-daemonicas-foetid-bloat-drone', 'models-1-1-copy-3-plus', '1 miniatura', 1, 1, 1, 110, 3, null::integer),
    ('unit-legiones-daemonicas-mortarion', 'models-1-1-copy-1-plus', '1 miniatura', 1, 1, 1, 375, 1, null::integer),
    ('unit-legiones-daemonicas-myphitic-blight-hauler', 'models-1-1-copy-1-plus', '1 miniatura', 1, 1, 1, 95, 1, null::integer),
    ('unit-legiones-daemonicas-myphitic-blight-hauler', 'models-2-2-copy-1-plus', '2 miniaturas', 2, 2, 2, 190, 1, null::integer),
    ('unit-legiones-daemonicas-foetid-bloat-drone-heavy-blight-launcher', 'models-1-1-copy-1-2', '1 miniatura', 1, 1, 1, 125, 1, 2),
    ('unit-legiones-daemonicas-foetid-bloat-drone-heavy-blight-launcher', 'models-1-1-copy-3-plus', '1 miniatura', 1, 1, 1, 135, 3, null::integer),
    ('unit-legiones-daemonicas-plagueburst-crawler', 'models-1-1-copy-1-1', '1 miniatura', 1, 1, 1, 170, 1, 1),
    ('unit-legiones-daemonicas-plagueburst-crawler', 'models-1-1-copy-2-plus', '1 miniatura', 1, 1, 1, 200, 2, null::integer),
    ('unit-legiones-daemonicas-defiler', 'models-1-1-copy-1-1', '1 miniatura', 1, 1, 1, 300, 1, 1),
    ('unit-legiones-daemonicas-defiler', 'models-1-1-copy-2-plus', '1 miniatura', 1, 1, 1, 350, 2, null::integer),
    ('unit-legiones-daemonicas-noxious-blightbringer', 'models-1-1-copy-1-plus', '1 miniatura', 1, 1, 1, 50, 1, null::integer),
    ('unit-legiones-daemonicas-malignant-plaguecaster', 'models-1-1-copy-1-plus', '1 miniatura', 1, 1, 1, 60, 1, null::integer),
    ('unit-legiones-daemonicas-biologus-putrifier', 'models-1-1-copy-1-plus', '1 miniatura', 1, 1, 1, 60, 1, null::integer),
    ('unit-legiones-daemonicas-chaos-predator-annihilator', 'models-1-1-copy-1-2', '1 miniatura', 1, 1, 1, 135, 1, 2),
    ('unit-legiones-daemonicas-lord-of-contagion', 'models-1-1-copy-1-plus', '1 miniatura', 1, 1, 1, 120, 1, null::integer)
) as data(template_slug, slug, label, models, min_models, max_models, points, copy_from, copy_to)
join public.unit_templates on unit_templates.slug = data.template_slug
on conflict (unit_template_id, slug) do update
set label = excluded.label,
    models = excluded.models,
    min_models = excluded.min_models,
    max_models = excluded.max_models,
    points = excluded.points,
    copy_from = excluded.copy_from,
    copy_to = excluded.copy_to,
    source = excluded.source,
    updated_at = now();

insert into public.unit_template_wargear_options (
  id, unit_template_id, slug, name, points, pricing, source
)
select
  public.seed_uuid('unit_template_wargear_option', data.template_slug || ':' || data.slug),
  unit_templates.id,
  data.slug,
  data.name,
  15,
  'per_option',
  'mfm'
from (
  values
    ('unit-legiones-daemonicas-defiler', 'heavy-reaper-autocannon', 'Heavy Reaper Autocannon'),
    ('unit-legiones-daemonicas-defiler', 'hades-lascannon', 'Hades Lascannon')
) as data(template_slug, slug, name)
join public.unit_templates on unit_templates.slug = data.template_slug
on conflict (unit_template_id, slug) do update
set name = excluded.name,
    points = excluded.points,
    pricing = excluded.pricing,
    source = excluded.source,
    updated_at = now();

create or replace function public.is_unit_template_unlocked_for_faction(
  target_unit_template_id uuid,
  target_faction_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (
      select 1
      from public.unit_template_technology_unlocks
      where unit_template_id = target_unit_template_id
    ) then exists (
      select 1
      from public.unit_template_technology_unlocks as unlocks
      join public.faction_technologies as progress
        on progress.technology_node_id = unlocks.technology_node_id
       and progress.faction_id = target_faction_id
       and progress.status = 'unlocked'
      where unlocks.unit_template_id = target_unit_template_id
    )
    else coalesce((
      select templates.required_technology_node_id is null
        or exists (
          select 1
          from public.faction_technologies as progress
          where progress.faction_id = target_faction_id
            and progress.technology_node_id = templates.required_technology_node_id
            and progress.status = 'unlocked'
        )
      from public.unit_templates as templates
      where templates.id = target_unit_template_id
    ), false)
  end;
$$;

revoke execute on function public.is_unit_template_unlocked_for_faction(uuid, uuid) from public;
grant execute on function public.is_unit_template_unlocked_for_faction(uuid, uuid) to authenticated, service_role;

-- Patch the live recruitment function without replacing later fixes such as first-copy pricing.
do $$
declare
  v_definition text;
  v_patched text;
  v_old text := $old$if v_template.required_technology_node_id is not null
    and not exists (
      select 1
      from public.faction_technologies
      where faction_id = v_faction_id
        and technology_node_id = v_template.required_technology_node_id
        and status = 'unlocked'
    ) then
    raise exception 'Esta unidad requiere tecnologia desbloqueada';
  end if;$old$;
  v_new text := $new$if not public.is_unit_template_unlocked_for_faction(v_template.id, v_faction_id) then
    raise exception 'Esta unidad requiere tecnología desbloqueada';
  end if;$new$;
begin
  select pg_get_functiondef('public.recruit_unit_variant_at_building(uuid,uuid,integer,jsonb)'::regprocedure)
  into v_definition;

  v_patched := replace(v_definition, v_old, v_new);

  if v_patched = v_definition then
    raise exception 'No se pudo actualizar el desbloqueo tecnológico del reclutamiento';
  end if;

  execute v_patched;
end;
$$;

-- Honor is traded only with the Merchant. Player offers keep their existing four resources.
create or replace function public.merchant_trade(resource_key text, direction text, trade_quantity integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_resource_key text := case
    when lower(trim(coalesce(resource_key, ''))) in ('honor', 'honour') then 'honor'
    else public.normalize_trade_resource_key(resource_key)
  end;
  v_points integer;
  v_resources public.faction_resources%rowtype;
  v_gold_delta integer := 0;
  v_resource_delta integer := 0;
  v_price_gold integer;
  v_payout_gold integer;
  v_current_resource numeric := 0;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if v_resource_key not in ('supply', 'minerals', 'honor') then
    raise exception 'El Mercader solo comercia Suministro vital, Mineral y Honor';
  end if;

  if direction not in ('buy', 'sell') then
    raise exception 'Dirección de comercio inválida';
  end if;

  if trade_quantity is null or trade_quantity < 1 then
    raise exception 'Cantidad inválida';
  end if;

  select public.current_user_faction_id() into v_faction_id;

  if v_faction_id is null then
    raise exception 'El usuario no tiene facción activa';
  end if;

  if not public.has_active_commerce_building(v_faction_id) then
    raise exception 'Necesitas una Cámara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_faction_id, 'unlock_merchant_trade') then
    raise exception 'Necesitas investigar Contactos Económicos para comerciar con el Mercader';
  end if;

  v_points := case v_resource_key
    when 'supply' then 1
    when 'minerals' then 2
    when 'honor' then 5
  end;

  v_price_gold := ceil((v_points::numeric * trade_quantity * public.get_merchant_buy_multiplier(v_faction_id)) / 5)::integer;
  v_payout_gold := ceil((v_points::numeric * trade_quantity * public.get_merchant_sell_multiplier(v_faction_id)) / 5)::integer;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La facción no tiene recursos inicializados';
  end if;

  v_current_resource := case v_resource_key
    when 'supply' then v_resources.supply
    when 'minerals' then v_resources.minerals
    when 'honor' then v_resources.honor
    else 0
  end;

  if direction = 'buy' then
    if v_resources.gold < v_price_gold then
      raise exception 'Oro insuficiente';
    end if;

    if not public.can_receive_resource(v_faction_id, v_resource_key, trade_quantity) then
      raise exception 'Capacidad máxima de recurso alcanzada';
    end if;

    v_gold_delta := -v_price_gold;
    v_resource_delta := trade_quantity;
  else
    if v_current_resource < trade_quantity then
      raise exception 'Recurso insuficiente';
    end if;

    if not public.can_receive_resource(v_faction_id, 'gold', v_payout_gold) then
      raise exception 'Capacidad máxima de oro alcanzada';
    end if;

    v_gold_delta := v_payout_gold;
    v_resource_delta := -trade_quantity;
  end if;

  update public.faction_resources
  set
    supply = supply + case when v_resource_key = 'supply' then v_resource_delta else 0 end,
    minerals = minerals + case when v_resource_key = 'minerals' then v_resource_delta else 0 end,
    honor = honor + case when v_resource_key = 'honor' then v_resource_delta else 0 end,
    gold = gold + v_gold_delta,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'merchant_trade',
    jsonb_build_object(
      'resource_key', v_resource_key,
      'direction', direction,
      'quantity', trade_quantity,
      'gold_delta', v_gold_delta,
      'resource_delta', v_resource_delta
    )
  );

  return jsonb_build_object(
    'resource_key', v_resource_key,
    'direction', direction,
    'quantity', trade_quantity,
    'gold_delta', v_gold_delta,
    'resource_delta', v_resource_delta
  );
end;
$$;

revoke execute on function public.merchant_trade(text, text, integer) from public;
grant execute on function public.merchant_trade(text, text, integer) to authenticated, service_role;

insert into public.campaign_logs (action_type, payload)
values (
  'chaos_roster_expanded',
  jsonb_build_object(
    'faction_slug', 'legiones-daemonicas',
    'faction_name', 'El Caos',
    'death_guard_units_added', 15,
    'honor_enabled_for_merchant', true
  )
);
