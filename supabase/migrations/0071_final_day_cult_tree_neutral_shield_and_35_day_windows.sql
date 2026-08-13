create or replace function public.attack_operation_window_days()
returns integer
language sql
immutable
as $$
  select 35;
$$;

create or replace function public.apply_neutral_conquest_shield()
returns trigger
language plpgsql
as $$
begin
  if old.status = 'neutral'
    and new.status = 'controlled'
    and old.controller_faction_id is null
    and new.controller_faction_id is not null
    and new.blocked_until is null
    and coalesce(new.is_capital, false) = false
    and coalesce(new.is_temporary_mission, false) = false then
    new.blocked_until := now() + interval '14 days';
  end if;

  return new;
end;
$$;

drop trigger if exists systems_neutral_conquest_shield_trigger on public.systems;
create trigger systems_neutral_conquest_shield_trigger
before update on public.systems
for each row
execute function public.apply_neutral_conquest_shield();

update public.faction_resources
set technology = 8,
    updated_at = now()
from public.factions
where faction_resources.faction_id = factions.id
  and factions.slug in (
    'legiones-daemonicas',
    'adeptus-custodes',
    'space-marines',
    'cultos-genestealer',
    'necrones'
  );

update public.technology_nodes
set branch = 'Cámara Anathema',
    updated_at = now()
where tree_key = 'troops-adeptus-custodes-v1'
  and branch = 'Camara Anathema';

insert into public.unit_templates (
  id, slug, faction_id, name, category, unit_type, unit_keywords, points, default_quantity, wounds_per_model,
  supply_cost, minerals_cost, ancestral_stone_cost, honor_cost, gold_cost, industrial_material_cost,
  uridium_cost, technology_cost, recruitment_time_seconds, recruitment_building_type, notes, is_available,
  required_technology_node_id, source_section, source_faction_name, is_allied_unit
)
select
  public.seed_uuid('unit_template', data.slug),
  data.slug,
  factions.id,
  data.name,
  'Aliada',
  data.unit_type,
  data.unit_keywords,
  data.points,
  data.default_quantity,
  data.wounds_per_model,
  data.supply_cost,
  data.minerals_cost,
  0,
  data.honor_cost,
  data.gold_cost,
  0,
  0,
  0,
  3,
  data.recruitment_building_type,
  'Unidad aliada Final Day importada desde data/11th-final-day-tyranids.json.',
  false,
  null::uuid,
  'FINAL DAY TYRANIDS',
  'Xenos - Tyranids',
  true
from (
  values
    ('unit-cultos-genestealer-winged-hive-tyrant', 'Winged Hive Tyrant', 'character', array['Bestia','Caracter']::text[], 185, 1, 8, 54, 13, 16, 5, 'cuartel-mando'),
    ('unit-cultos-genestealer-winged-tyranid-prime', 'Winged Tyranid Prime', 'character', array['Infanteria','Caracter']::text[], 65, 1, 5, 27, 4, 5, 1, 'cuartel-mando'),
    ('unit-cultos-genestealer-deathleaper', 'Deathleaper', 'character', array['Infanteria','Caracter']::text[], 80, 1, 5, 23, 6, 7, 2, 'cuartel-mando'),
    ('unit-cultos-genestealer-gargoyles', 'Gargoyles', 'infantry', array['Infanteria']::text[], 80, 10, 1, 50, 10, 0, 2, 'barracon-infanteria'),
    ('unit-cultos-genestealer-hyperadapted-raveners', 'Hyperadapted Raveners', 'character', array['Infanteria','Caracter']::text[], 165, 5, 5, 51, 12, 14, 4, 'cuartel-mando'),
    ('unit-cultos-genestealer-lictor', 'Lictor', 'infantry', array['Infanteria']::text[], 60, 1, 1, 41, 7, 0, 1, 'barracon-infanteria'),
    ('unit-cultos-genestealer-mawloc', 'Mawloc', 'beast', array['Bestia']::text[], 135, 1, 3, 58, 6, 9, 4, 'nido-bestias'),
    ('unit-cultos-genestealer-neurolictor', 'Neurolictor', 'infantry', array['Infanteria']::text[], 80, 1, 1, 50, 10, 0, 2, 'barracon-infanteria'),
    ('unit-cultos-genestealer-parasite-of-mortrex', 'Parasite of Mortrex', 'character', array['Infanteria','Caracter']::text[], 70, 1, 5, 20, 5, 6, 2, 'cuartel-mando'),
    ('unit-cultos-genestealer-raveners', 'Raveners', 'infantry', array['Infanteria']::text[], 125, 5, 1, 75, 15, 1, 3, 'barracon-infanteria'),
    ('unit-cultos-genestealer-trygon', 'Trygon', 'beast', array['Bestia']::text[], 140, 1, 3, 61, 7, 9, 4, 'nido-bestias'),
    ('unit-cultos-genestealer-tyrannocyte', 'Tyrannocyte', 'beast', array['Bestia']::text[], 80, 1, 3, 37, 4, 5, 2, 'nido-bestias'),
    ('unit-cultos-genestealer-von-ryans-leapers', 'Von Ryan''s Leapers', 'infantry', array['Infanteria']::text[], 55, 3, 1, 38, 6, 0, 1, 'barracon-infanteria'),
    ('unit-cultos-genestealer-the-red-terror', 'The Red Terror', 'character', array['Bestia','Caracter']::text[], 130, 1, 8, 42, 9, 11, 3, 'cuartel-mando')
) as data(slug, name, unit_type, unit_keywords, points, default_quantity, wounds_per_model, supply_cost, minerals_cost, honor_cost, gold_cost, recruitment_building_type)
join public.factions on factions.slug = 'cultos-genestealer'
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
    ancestral_stone_cost = excluded.ancestral_stone_cost,
    honor_cost = excluded.honor_cost,
    gold_cost = excluded.gold_cost,
    industrial_material_cost = excluded.industrial_material_cost,
    uridium_cost = excluded.uridium_cost,
    technology_cost = excluded.technology_cost,
    recruitment_time_seconds = excluded.recruitment_time_seconds,
    recruitment_building_type = excluded.recruitment_building_type,
    notes = excluded.notes,
    is_available = excluded.is_available,
    required_technology_node_id = excluded.required_technology_node_id,
    source_section = excluded.source_section,
    source_faction_name = excluded.source_faction_name,
    is_allied_unit = excluded.is_allied_unit;

insert into public.unit_template_model_options (
  id, unit_template_id, slug, label, models, min_models, max_models, points, copy_from, copy_to, source,
  points_change_direction, points_change_amount
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
  null::text,
  null::integer
from (
  values
    ('unit-cultos-genestealer-winged-hive-tyrant', 'models-1-1-copy-1-plus', '1 model', 1, 1, 1, 185, 1, null::integer),
    ('unit-cultos-genestealer-winged-tyranid-prime', 'models-1-1-copy-1-plus', '1 model', 1, 1, 1, 65, 1, null::integer),
    ('unit-cultos-genestealer-deathleaper', 'models-1-1-copy-1-plus', '1 model', 1, 1, 1, 80, 1, null::integer),
    ('unit-cultos-genestealer-gargoyles', 'models-10-10-copy-1-plus', '10 models', 10, 10, 10, 80, 1, null::integer),
    ('unit-cultos-genestealer-gargoyles', 'models-20-20-copy-1-plus', '20 models', 20, 20, 20, 155, 1, null::integer),
    ('unit-cultos-genestealer-hyperadapted-raveners', 'models-5-5-copy-1-2', '5 models', 5, 5, 5, 165, 1, 2),
    ('unit-cultos-genestealer-hyperadapted-raveners', 'models-5-5-copy-3-plus', '5 models', 5, 5, 5, 175, 3, null::integer),
    ('unit-cultos-genestealer-lictor', 'models-1-1-copy-1-plus', '1 model', 1, 1, 1, 60, 1, null::integer),
    ('unit-cultos-genestealer-mawloc', 'models-1-1-copy-1-plus', '1 model', 1, 1, 1, 135, 1, null::integer),
    ('unit-cultos-genestealer-neurolictor', 'models-1-1-copy-1-2', '1 model', 1, 1, 1, 80, 1, 2),
    ('unit-cultos-genestealer-neurolictor', 'models-1-1-copy-3-plus', '1 model', 1, 1, 1, 90, 3, null::integer),
    ('unit-cultos-genestealer-parasite-of-mortrex', 'models-1-1-copy-1-plus', '1 model', 1, 1, 1, 70, 1, null::integer),
    ('unit-cultos-genestealer-raveners', 'models-5-5-copy-1-2', '5 models', 5, 5, 5, 125, 1, 2),
    ('unit-cultos-genestealer-raveners', 'models-5-5-copy-3-plus', '5 models', 5, 5, 5, 135, 3, null::integer),
    ('unit-cultos-genestealer-trygon', 'models-1-1-copy-1-plus', '1 model', 1, 1, 1, 140, 1, null::integer),
    ('unit-cultos-genestealer-tyrannocyte', 'models-1-1-copy-1-3', '1 model', 1, 1, 1, 80, 1, 3),
    ('unit-cultos-genestealer-tyrannocyte', 'models-1-1-copy-4-plus', '1 model', 1, 1, 1, 90, 4, null::integer),
    ('unit-cultos-genestealer-von-ryans-leapers', 'models-3-3-copy-1-plus', '3 models', 3, 3, 3, 55, 1, null::integer),
    ('unit-cultos-genestealer-von-ryans-leapers', 'models-6-6-copy-1-plus', '6 models', 6, 6, 6, 105, 1, null::integer),
    ('unit-cultos-genestealer-the-red-terror', 'models-1-1-copy-1-plus', '1 model', 1, 1, 1, 130, 1, null::integer)
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

create or replace function public.seed_genestealer_cult_troop_technology_tree()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cult_faction_id uuid;
begin
  insert into public.technology_nodes (
    id, slug, tree_key, name, description, branch, tier, position_x, position_y,
    cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
  )
  select
    public.seed_uuid('technology_node', data.slug),
    data.slug,
    data.tree_key,
    data.name,
    data.description,
    data.branch,
    data.tier,
    data.position_x,
    data.position_y,
    data.cost_technology,
    data.research_time_seconds,
    data.icon_key,
    data.effect_summary,
    false,
    'active'
  from (
    values
      ('culto-celulas-mineras', 'Celulas Mineras', 'Las primeras celulas obreras toman armas ocultas y convierten manufactorums en cuarteles secretos. Desbloquea: Neophyte Hybrids.', 'troops-cultos-genestealer-v1', 'Red de Insurreccion', 1, 1, 2, 1, 30, 'cult_cell', 'Desbloquea: Neophyte Hybrids.'),
      ('culto-iconos-alzamiento', 'Iconos del Alzamiento', 'Los acolitos salen de los santuarios industriales con iconos y armas rituales para dirigir masas insurgentes. Desbloquea: Acolyte Hybrids with Autopistols y Acolyte Iconward.', 'troops-cultos-genestealer-v1', 'Red de Insurreccion', 2, 1, 1, 2, 30, 'cult_icon', 'Desbloquea: Acolyte Hybrids with Autopistols, Acolyte Iconward.'),
      ('culto-purga-prometio', 'Purga de Prometio', 'Las cuadrillas de tunel aprenden a limpiar bunkeres y corredores con fuego industrial. Desbloquea: Acolyte Hybrids with Hand Flamers.', 'troops-cultos-genestealer-v1', 'Red de Insurreccion', 2, 1, 3, 2, 30, 'cult_flame', 'Desbloquea: Acolyte Hybrids with Hand Flamers.'),
      ('culto-convoy-subterraneo', 'Convoy Subterraneo', 'Rutas mineras, talleres ocultos y conductores juramentados convierten vehiculos civiles en columnas de guerra. Desbloquea: Goliath Truck y Achilles Ridgerunners.', 'troops-cultos-genestealer-v1', 'Red de Insurreccion', 3, 1, 1, 2, 30, 'cult_convoy', 'Desbloquea: Goliath Truck, Achilles Ridgerunners.'),
      ('culto-muelas-industriales', 'Muelas Industriales', 'Las maquinas de extraccion pesada se blindan, se arman y se lanzan contra fortalezas de superficie. Desbloquea: Goliath Rockgrinder.', 'troops-cultos-genestealer-v1', 'Red de Insurreccion', 4, 1, 1, 3, 30, 'cult_rockgrinder', 'Desbloquea: Goliath Rockgrinder.'),
      ('culto-vox-cuarta-generacion', 'Vox de Cuarta Generacion', 'Predicadores, psiquicos y transmisores clandestinos convierten rumores de colmena en mandato sagrado. Desbloquea: Clamavus y Magus.', 'troops-cultos-genestealer-v1', 'Sombras del Culto', 1, 2, 2, 1, 30, 'cult_vox', 'Desbloquea: Clamavus, Magus.'),
      ('culto-cuchillos-bajo-ciudad', 'Cuchillos Bajo la Ciudad', 'Custodios personales y asesinos de culto eliminan objetivos clave antes de que la revuelta sea visible. Desbloquea: Locus y Sanctus.', 'troops-cultos-genestealer-v1', 'Sombras del Culto', 2, 2, 1, 2, 30, 'cult_blade', 'Desbloquea: Locus, Sanctus.'),
      ('culto-mito-pistolero', 'Mito Pistolero', 'Heroes callejeros y especialistas en demoliciones vuelven cada callejon una trampa propagandistica. Desbloquea: Kelermorph y Reductus Saboteur.', 'troops-cultos-genestealer-v1', 'Sombras del Culto', 2, 2, 3, 2, 30, 'cult_guns', 'Desbloquea: Kelermorph, Reductus Saboteur.'),
      ('culto-guerrilla-crucible', 'Guerrilla Crucible', 'Escuadras de reconocimiento, motos de tunel y celulas [Crucible] golpean flancos y rutas de retirada. Desbloquea: Atalan Jackals, Jackal Alphus y Cult Guerrilla [Crucible].', 'troops-cultos-genestealer-v1', 'Sombras del Culto', 3, 2, 2, 2, 30, 'cult_guerrilla', 'Desbloquea: Atalan Jackals, Jackal Alphus, Cult Guerrilla [Crucible].'),
      ('culto-profetas-dia-ascension', 'Profetas del Dia de la Ascension', 'Voces bendecidas, coordinadores y mentes sinapticas anuncian el momento exacto en que la ciudad debe caer. Desbloquea: Primus, Nexos, Benefictus, Voice of the Patriarch [Crucible] y Cult Insurrectionist [Crucible].', 'troops-cultos-genestealer-v1', 'Sombras del Culto', 4, 2, 2, 2, 30, 'cult_prophet', 'Desbloquea: Primus, Nexos, Benefictus, Voice of the Patriarch [Crucible], Cult Insurrectionist [Crucible].'),
      ('culto-savia-mutagena', 'Savia Mutagena', 'Cirujanos de culto y mutantes de primera linea aceleran la transformacion de la progenie hibrida. Desbloquea: Biophagus y Hybrid Metamorphs.', 'troops-cultos-genestealer-v1', 'Ascension del Patriarca', 1, 3, 1, 2, 30, 'cult_mutation', 'Desbloquea: Biophagus, Hybrid Metamorphs.'),
      ('culto-pureza-genetica', 'Pureza Genetica', 'Los descendientes mas puros del beso genestealer salen de madrigueras selladas para romper lineas enemigas. Desbloquea: Purestrain Genestealers.', 'troops-cultos-genestealer-v1', 'Ascension del Patriarca', 2, 3, 1, 2, 30, 'cult_genestealer', 'Desbloquea: Purestrain Genestealers.'),
      ('culto-musculo-aberrante', 'Musculo Aberrante', 'La fuerza mutante del culto se convierte en ariete vivo protegido por amos deformes. Desbloquea: Aberrants y Abominant.', 'troops-cultos-genestealer-v1', 'Ascension del Patriarca', 2, 3, 3, 2, 30, 'cult_aberrant', 'Desbloquea: Aberrants, Abominant.'),
      ('culto-trono-patriarca', 'Trono del Patriarca', 'La progenie y los aberrantes reconocen una unica voluntad sinaptica al final del alzamiento. Desbloquea: Patriarch.', 'troops-cultos-genestealer-v1', 'Ascension del Patriarca', 3, 3, 2, 2, 30, 'cult_patriarch', 'Desbloquea: Patriarch.'),
      ('culto-dia-final', 'El Dia Final', 'La senal del Patriarca abre paso a organismos de vanguardia tiranidos. Desbloquea: Winged Hive Tyrant, Winged Tyranid Prime, Deathleaper, Gargoyles, Hyperadapted Raveners, Lictor, Mawloc, Neurolictor, Parasite of Mortrex, Raveners, Trygon, Tyrannocyte, Von Ryan''s Leapers y The Red Terror.', 'troops-cultos-genestealer-v1', 'Ascension del Patriarca', 5, 3, 2, 3, 30, 'cult_final_day', 'Desbloquea: Winged Hive Tyrant, Winged Tyranid Prime, Deathleaper, Gargoyles, Hyperadapted Raveners, Lictor, Mawloc, Neurolictor, Parasite of Mortrex, Raveners, Trygon, Tyrannocyte, Von Ryan''s Leapers y The Red Terror.')
  ) as data(slug, name, description, tree_key, branch, tier, position_x, position_y, cost_technology, research_time_seconds, icon_key, effect_summary)
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
  where tree_key = 'troops-cultos-genestealer-v1'
    and slug not in (
      'culto-celulas-mineras',
      'culto-iconos-alzamiento',
      'culto-purga-prometio',
      'culto-convoy-subterraneo',
      'culto-muelas-industriales',
      'culto-vox-cuarta-generacion',
      'culto-cuchillos-bajo-ciudad',
      'culto-mito-pistolero',
      'culto-guerrilla-crucible',
      'culto-profetas-dia-ascension',
      'culto-savia-mutagena',
      'culto-pureza-genetica',
      'culto-musculo-aberrante',
      'culto-trono-patriarca',
      'culto-dia-final'
    );

  delete from public.technology_prerequisites prerequisites
  using public.technology_nodes nodes
  where prerequisites.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-cultos-genestealer-v1';

  insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
  select tech.id, required.id, data.prerequisite_group
  from (
    values
      ('culto-celulas-mineras', 'fundacion-planetaria', 1),
      ('culto-iconos-alzamiento', 'culto-celulas-mineras', 1),
      ('culto-purga-prometio', 'culto-celulas-mineras', 1),
      ('culto-convoy-subterraneo', 'culto-iconos-alzamiento', 1),
      ('culto-convoy-subterraneo', 'maquinaria-belica', 2),
      ('culto-muelas-industriales', 'culto-convoy-subterraneo', 1),
      ('culto-vox-cuarta-generacion', 'asamblea-planetaria', 1),
      ('culto-cuchillos-bajo-ciudad', 'culto-vox-cuarta-generacion', 1),
      ('culto-mito-pistolero', 'culto-vox-cuarta-generacion', 1),
      ('culto-guerrilla-crucible', 'culto-mito-pistolero', 1),
      ('culto-guerrilla-crucible', 'culto-convoy-subterraneo', 2),
      ('culto-profetas-dia-ascension', 'culto-guerrilla-crucible', 1),
      ('culto-profetas-dia-ascension', 'culto-cuchillos-bajo-ciudad', 2),
      ('culto-savia-mutagena', 'criadero-guerra', 1),
      ('culto-pureza-genetica', 'culto-savia-mutagena', 1),
      ('culto-musculo-aberrante', 'culto-savia-mutagena', 1),
      ('culto-musculo-aberrante', 'culto-iconos-alzamiento', 2),
      ('culto-trono-patriarca', 'culto-pureza-genetica', 1),
      ('culto-trono-patriarca', 'culto-musculo-aberrante', 2),
      ('culto-dia-final', 'culto-trono-patriarca', 1),
      ('culto-dia-final', 'culto-profetas-dia-ascension', 2)
  ) as data(technology_slug, required_slug, prerequisite_group)
  join public.technology_nodes tech on tech.slug = data.technology_slug
  join public.technology_nodes required on required.slug = data.required_slug
  on conflict (technology_node_id, required_node_id) do update
  set prerequisite_group = excluded.prerequisite_group;

  delete from public.technology_effects effects
  using public.technology_nodes nodes
  where effects.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-cultos-genestealer-v1'
    and effects.effect_type = 'unlock_unit_template';

  insert into public.technology_effects (id, technology_node_id, effect_type, payload)
  select
    public.seed_uuid('technology_effect', data.technology_slug || '-units'),
    technology_nodes.id,
    'unlock_unit_template',
    jsonb_build_object('unit_template_slugs', data.unit_template_slugs)
  from (
    values
      ('culto-celulas-mineras', array['unit-cultos-genestealer-neophyte-hybrids']::text[]),
      ('culto-iconos-alzamiento', array['unit-cultos-genestealer-acolyte-hybrids-with-autopistols','unit-cultos-genestealer-acolyte-iconward']::text[]),
      ('culto-purga-prometio', array['unit-cultos-genestealer-acolyte-hybrids-with-hand-flamers']::text[]),
      ('culto-convoy-subterraneo', array['unit-cultos-genestealer-goliath-truck','unit-cultos-genestealer-achilles-ridgerunners']::text[]),
      ('culto-muelas-industriales', array['unit-cultos-genestealer-goliath-rockgrinder']::text[]),
      ('culto-vox-cuarta-generacion', array['unit-cultos-genestealer-clamavus','unit-cultos-genestealer-magus']::text[]),
      ('culto-cuchillos-bajo-ciudad', array['unit-cultos-genestealer-locus','unit-cultos-genestealer-sanctus']::text[]),
      ('culto-mito-pistolero', array['unit-cultos-genestealer-kelermorph','unit-cultos-genestealer-reductus-saboteur']::text[]),
      ('culto-guerrilla-crucible', array['unit-cultos-genestealer-atalan-jackals','unit-cultos-genestealer-jackal-alphus','unit-cultos-genestealer-cult-guerrilla-crucible']::text[]),
      ('culto-profetas-dia-ascension', array['unit-cultos-genestealer-primus','unit-cultos-genestealer-nexos','unit-cultos-genestealer-benefictus','unit-cultos-genestealer-voice-of-the-patriarch-crucible','unit-cultos-genestealer-cult-insurrectionist-crucible']::text[]),
      ('culto-savia-mutagena', array['unit-cultos-genestealer-biophagus','unit-cultos-genestealer-hybrid-metamorphs']::text[]),
      ('culto-pureza-genetica', array['unit-cultos-genestealer-purestrain-genestealers']::text[]),
      ('culto-musculo-aberrante', array['unit-cultos-genestealer-aberrants','unit-cultos-genestealer-abominant']::text[]),
      ('culto-trono-patriarca', array['unit-cultos-genestealer-patriarch']::text[]),
      ('culto-dia-final', array['unit-cultos-genestealer-winged-hive-tyrant','unit-cultos-genestealer-winged-tyranid-prime','unit-cultos-genestealer-deathleaper','unit-cultos-genestealer-gargoyles','unit-cultos-genestealer-hyperadapted-raveners','unit-cultos-genestealer-lictor','unit-cultos-genestealer-mawloc','unit-cultos-genestealer-neurolictor','unit-cultos-genestealer-parasite-of-mortrex','unit-cultos-genestealer-raveners','unit-cultos-genestealer-trygon','unit-cultos-genestealer-tyrannocyte','unit-cultos-genestealer-von-ryans-leapers','unit-cultos-genestealer-the-red-terror']::text[])
  ) as data(technology_slug, unit_template_slugs)
  join public.technology_nodes on technology_nodes.slug = data.technology_slug
  on conflict (id) do update
  set technology_node_id = excluded.technology_node_id,
      effect_type = excluded.effect_type,
      payload = excluded.payload;

  select id into v_cult_faction_id
  from public.factions
  where slug = 'cultos-genestealer';

  if v_cult_faction_id is not null then
    update public.unit_templates
    set is_available = false,
        required_technology_node_id = null
    where faction_id = v_cult_faction_id;

    update public.unit_templates templates
    set is_available = true,
        required_technology_node_id = technology_nodes.id
    from (
      values
        ('culto-celulas-mineras', array['unit-cultos-genestealer-neophyte-hybrids']::text[]),
        ('culto-iconos-alzamiento', array['unit-cultos-genestealer-acolyte-hybrids-with-autopistols','unit-cultos-genestealer-acolyte-iconward']::text[]),
        ('culto-purga-prometio', array['unit-cultos-genestealer-acolyte-hybrids-with-hand-flamers']::text[]),
        ('culto-convoy-subterraneo', array['unit-cultos-genestealer-goliath-truck','unit-cultos-genestealer-achilles-ridgerunners']::text[]),
        ('culto-muelas-industriales', array['unit-cultos-genestealer-goliath-rockgrinder']::text[]),
        ('culto-vox-cuarta-generacion', array['unit-cultos-genestealer-clamavus','unit-cultos-genestealer-magus']::text[]),
        ('culto-cuchillos-bajo-ciudad', array['unit-cultos-genestealer-locus','unit-cultos-genestealer-sanctus']::text[]),
        ('culto-mito-pistolero', array['unit-cultos-genestealer-kelermorph','unit-cultos-genestealer-reductus-saboteur']::text[]),
        ('culto-guerrilla-crucible', array['unit-cultos-genestealer-atalan-jackals','unit-cultos-genestealer-jackal-alphus','unit-cultos-genestealer-cult-guerrilla-crucible']::text[]),
        ('culto-profetas-dia-ascension', array['unit-cultos-genestealer-primus','unit-cultos-genestealer-nexos','unit-cultos-genestealer-benefictus','unit-cultos-genestealer-voice-of-the-patriarch-crucible','unit-cultos-genestealer-cult-insurrectionist-crucible']::text[]),
        ('culto-savia-mutagena', array['unit-cultos-genestealer-biophagus','unit-cultos-genestealer-hybrid-metamorphs']::text[]),
        ('culto-pureza-genetica', array['unit-cultos-genestealer-purestrain-genestealers']::text[]),
        ('culto-musculo-aberrante', array['unit-cultos-genestealer-aberrants','unit-cultos-genestealer-abominant']::text[]),
        ('culto-trono-patriarca', array['unit-cultos-genestealer-patriarch']::text[]),
        ('culto-dia-final', array['unit-cultos-genestealer-winged-hive-tyrant','unit-cultos-genestealer-winged-tyranid-prime','unit-cultos-genestealer-deathleaper','unit-cultos-genestealer-gargoyles','unit-cultos-genestealer-hyperadapted-raveners','unit-cultos-genestealer-lictor','unit-cultos-genestealer-mawloc','unit-cultos-genestealer-neurolictor','unit-cultos-genestealer-parasite-of-mortrex','unit-cultos-genestealer-raveners','unit-cultos-genestealer-trygon','unit-cultos-genestealer-tyrannocyte','unit-cultos-genestealer-von-ryans-leapers','unit-cultos-genestealer-the-red-terror']::text[])
    ) as groups(technology_slug, unit_template_slugs)
    cross join lateral unnest(groups.unit_template_slugs) as assignments(unit_slug)
    join public.technology_nodes on technology_nodes.slug = groups.technology_slug
    where templates.slug = assignments.unit_slug
      and templates.faction_id = v_cult_faction_id;

    perform public.refresh_available_technologies(v_cult_faction_id);
  end if;
end;
$$;

revoke execute on function public.seed_genestealer_cult_troop_technology_tree() from public;
revoke execute on function public.seed_genestealer_cult_troop_technology_tree() from anon;
revoke execute on function public.seed_genestealer_cult_troop_technology_tree() from authenticated;

select public.seed_genestealer_cult_troop_technology_tree();
