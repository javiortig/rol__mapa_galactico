create or replace function public.map_unit_category_to_type(category text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when lower(coalesce(category, '')) in ('beast', 'monstruo', 'monster', 'monsters') then 'beast'
    when lower(coalesce(category, '')) in ('vehicle', 'vehiculo', 'vehiculos', 'superpesado') then 'vehicle'
    when lower(coalesce(category, '')) in ('character', 'characters', 'personaje', 'personajes') then 'character'
    when lower(coalesce(category, '')) in ('mounted', 'montada', 'montado', 'montados', 'montadas') then 'mounted'
    when lower(coalesce(category, '')) like '%veh%' then 'vehicle'
    when lower(coalesce(category, '')) like '%person%' or lower(coalesce(category, '')) like '%character%' then 'character'
    when lower(coalesce(category, '')) like '%monstru%' or lower(coalesce(category, '')) like '%beast%' then 'beast'
    when lower(coalesce(category, '')) like '%mount%' or lower(coalesce(category, '')) like '%montad%' then 'mounted'
    else 'infantry'
  end;
$$;

create or replace function public.character_rank_for_level(character_level integer)
returns text
language sql
immutable
set search_path = public
as $$
  select case least(greatest(coalesce(character_level, 1), 1), 10)
    when 1 then 'Oficial'
    when 2 then 'Oficial Veterano'
    when 3 then 'Campeon'
    when 4 then 'Capitan'
    when 5 then 'Comandante'
    when 6 then 'Senor de Guerra'
    when 7 then 'Alto Senor'
    when 8 then 'Heroe de Cruzada'
    when 9 then 'Leyenda de Guerra'
    else 'Leyenda del Sector'
  end;
$$;

create or replace function public.character_relic_slots(character_level integer)
returns integer
language sql
immutable
set search_path = public
as $$
  select case
    when least(greatest(coalesce(character_level, 1), 1), 10) >= 6 then 2
    when least(greatest(coalesce(character_level, 1), 1), 10) >= 3 then 1
    else 0
  end;
$$;

alter table public.unit_templates
  add column if not exists unit_type text not null default 'infantry';

alter table public.campaign_units
  add column if not exists unit_type text not null default 'infantry';

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.unit_templates'::regclass
      and pg_get_constraintdef(oid) ilike '%unit_type%'
  loop
    execute format('alter table public.unit_templates drop constraint %I', v_constraint.conname);
  end loop;

  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.campaign_units'::regclass
      and pg_get_constraintdef(oid) ilike '%unit_type%'
  loop
    execute format('alter table public.campaign_units drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

alter table public.unit_templates
  add constraint unit_templates_unit_type_check
  check (unit_type in ('beast', 'vehicle', 'character', 'infantry', 'mounted'));

alter table public.campaign_units
  add constraint campaign_units_unit_type_check
  check (unit_type in ('beast', 'vehicle', 'character', 'infantry', 'mounted'));

update public.unit_templates
set unit_type = public.map_unit_category_to_type(category);

update public.campaign_units units
set unit_type = coalesce(templates.unit_type, public.map_unit_category_to_type(units.category), 'infantry')
from public.unit_templates templates
where templates.id = units.unit_template_id;

update public.campaign_units
set unit_type = public.map_unit_category_to_type(category)
where unit_template_id is null;

create or replace function public.sync_campaign_unit_type_and_rank()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_template_type text;
begin
  if new.unit_template_id is not null then
    select unit_templates.unit_type
    into v_template_type
    from public.unit_templates
    where unit_templates.id = new.unit_template_id;
  end if;

  new.unit_type := coalesce(v_template_type, public.map_unit_category_to_type(new.category), new.unit_type, 'infantry');

  if new.unit_type = 'character' then
    new.experience := least(greatest(coalesce(new.experience, 1), 1), 10);
    new.rank := public.character_rank_for_level(new.experience);
  elsif new.experience is null then
    new.experience := 0;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_campaign_unit_type_and_rank_trigger on public.campaign_units;
create trigger sync_campaign_unit_type_and_rank_trigger
before insert or update of unit_template_id, category, unit_type, experience
on public.campaign_units
for each row
execute function public.sync_campaign_unit_type_and_rank();

update public.campaign_units
set experience = case when unit_type = 'character' then least(greatest(coalesce(experience, 1), 1), 10) else coalesce(experience, 0) end;

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.building_templates'::regclass
      and pg_get_constraintdef(oid) ilike '%building_kind%'
  loop
    execute format('alter table public.building_templates drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

alter table public.building_templates
  add constraint building_templates_kind_check
  check (building_kind in ('recruitment', 'commerce', 'intelligence', 'production', 'relic'));

alter table public.relics
  add column if not exists slug text,
  add column if not exists icon_key text,
  add column if not exists rarity text not null default 'common',
  add column if not exists equipped_unit_id uuid references public.campaign_units(id) on delete set null,
  add column if not exists equipped_at timestamptz;

drop index if exists public.relics_slug_key;
create unique index if not exists relics_slug_key on public.relics (slug);
create index if not exists relics_faction_system_idx on public.relics (faction_id, system_id);
create index if not exists relics_equipped_unit_idx on public.relics (equipped_unit_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.relics'::regclass
      and conname = 'relics_rarity_check'
  ) then
    alter table public.relics
      add constraint relics_rarity_check
      check (rarity in ('common', 'rare', 'epic', 'legendary'));
  end if;
end;
$$;

insert into public.building_templates (
  id,
  slug,
  name,
  description,
  category,
  building_kind,
  supply_cost,
  minerals_cost,
  honor_cost,
  gold_cost,
  industrial_material_cost,
  uridium_cost,
  technology_cost,
  construction_time_seconds,
  produced_resource_key,
  produced_amount,
  allowed_unit_categories,
  required_technology_node_id,
  icon_key,
  is_available
)
values (
  coalesce((select id from public.building_templates where slug = 'santuario-reliquias'), gen_random_uuid()),
  'santuario-reliquias',
  'Santuario de Reliquias',
  'Camara sellada donde se custodian reliquias narrativas y se equipan a Caracteres veteranos.',
  'Reliquias',
  'relic',
  8,
  8,
  2,
  1,
  5,
  0,
  0,
  30,
  null,
  0,
  array[]::text[],
  (select id from public.technology_nodes where slug = 'monumentos-gloria'),
  'relic_sanctuary',
  true
)
on conflict (slug) do update
set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  building_kind = excluded.building_kind,
  supply_cost = excluded.supply_cost,
  minerals_cost = excluded.minerals_cost,
  honor_cost = excluded.honor_cost,
  gold_cost = excluded.gold_cost,
  industrial_material_cost = excluded.industrial_material_cost,
  uridium_cost = excluded.uridium_cost,
  technology_cost = excluded.technology_cost,
  construction_time_seconds = excluded.construction_time_seconds,
  required_technology_node_id = excluded.required_technology_node_id,
  icon_key = excluded.icon_key,
  is_available = excluded.is_available,
  updated_at = now();

insert into public.technology_effects (id, technology_node_id, effect_type, payload)
select
  coalesce((select id from public.technology_effects where id = md5('technology_effect:monumentos-relic-sanctuary')::uuid), md5('technology_effect:monumentos-relic-sanctuary')::uuid),
  technology_nodes.id,
  'unlock_building_template',
  '{"building_template_slugs":["santuario-reliquias"]}'::jsonb
from public.technology_nodes
where technology_nodes.slug = 'monumentos-gloria'
on conflict (id) do update
set technology_node_id = excluded.technology_node_id, effect_type = excluded.effect_type, payload = excluded.payload;

insert into public.system_buildings (id, system_id, building_template_id, status, started_at, finishes_at, constructed_at)
select
  gen_random_uuid(),
  systems.id,
  building_templates.id,
  'active',
  now() - interval '30 seconds',
  now() - interval '1 second',
  now() - interval '1 second'
from public.systems
join public.building_templates on building_templates.slug = 'santuario-reliquias'
where systems.is_capital = true
on conflict (system_id, building_template_id) do update
set status = excluded.status, started_at = excluded.started_at, finishes_at = excluded.finishes_at, constructed_at = excluded.constructed_at, updated_at = now();

insert into public.unit_templates (
  id,
  slug,
  faction_id,
  name,
  category,
  unit_type,
  points,
  default_quantity,
  wounds_per_model,
  supply_cost,
  minerals_cost,
  honor_cost,
  ancestral_stone_cost,
  gold_cost,
  industrial_material_cost,
  uridium_cost,
  technology_cost,
  recruitment_time_seconds,
  recruitment_building_type,
  notes,
  is_available,
  required_technology_node_id
)
select
  coalesce((select id from public.unit_templates existing where existing.slug = data.slug), gen_random_uuid()),
  data.slug,
  factions.id,
  data.name,
  'Personaje',
  'character',
  data.points,
  1,
  data.wounds_per_model,
  data.supply_cost,
  data.minerals_cost,
  data.honor_cost,
  data.honor_cost,
  data.gold_cost,
  data.industrial_material_cost,
  0,
  0,
  30,
  'cuartel-mando',
  data.notes,
  true,
  (select id from public.technology_nodes where slug = 'asamblea-planetaria')
from (
  values
    ('unit-orcos-warboss', 'orcos', 'Warboss', 110, 6, 8, 5, 2, 1, 2, 'Jefe de guerra preparado para portar trofeos sagrados.'),
    ('unit-necrones-overlord', 'necrones', 'Overlord', 100, 5, 6, 6, 2, 1, 2, 'Noble inmortal con protocolos de mando dinastico.'),
    ('unit-guardia-castellan', 'guardia-imperial', 'Cadian Castellan', 70, 4, 8, 4, 1, 1, 1, 'Oficial veterano de campana y enlace de mando.'),
    ('unit-culto-primus', 'culto-genestelar', 'Primus', 80, 4, 7, 4, 2, 1, 1, 'Lider de celula capaz de guiar la insurreccion.'),
    ('unit-sombra-captain', 'sombra-emperador', 'Captain', 95, 6, 6, 6, 3, 1, 2, 'Capitan de la Sombra del Emperador.'),
    ('unit-muerte-lord-contagion', 'guardia-muerte', 'Lord of Contagion', 100, 6, 7, 6, 3, 1, 2, 'Campeon corrupto de resistencia sobrenatural.')
) as data(slug, faction_slug, name, points, wounds_per_model, supply_cost, minerals_cost, honor_cost, gold_cost, industrial_material_cost, notes)
join public.factions on factions.slug = data.faction_slug
on conflict (slug) do update
set
  faction_id = excluded.faction_id,
  name = excluded.name,
  category = excluded.category,
  unit_type = excluded.unit_type,
  points = excluded.points,
  default_quantity = excluded.default_quantity,
  wounds_per_model = excluded.wounds_per_model,
  supply_cost = excluded.supply_cost,
  minerals_cost = excluded.minerals_cost,
  honor_cost = excluded.honor_cost,
  ancestral_stone_cost = excluded.ancestral_stone_cost,
  gold_cost = excluded.gold_cost,
  industrial_material_cost = excluded.industrial_material_cost,
  uridium_cost = excluded.uridium_cost,
  technology_cost = excluded.technology_cost,
  recruitment_time_seconds = excluded.recruitment_time_seconds,
  recruitment_building_type = excluded.recruitment_building_type,
  notes = excluded.notes,
  is_available = excluded.is_available,
  required_technology_node_id = excluded.required_technology_node_id;

insert into public.campaign_units (
  id,
  slug,
  faction_id,
  unit_template_id,
  name,
  category,
  unit_type,
  points,
  quantity,
  starting_quantity,
  wounds_taken,
  experience,
  rank,
  current_system_id,
  status,
  is_visible_publicly
)
select
  coalesce((select id from public.campaign_units existing where existing.slug = data.slug), gen_random_uuid()),
  data.slug,
  factions.id,
  unit_templates.id,
  data.name,
  'Personaje',
  'character',
  unit_templates.points,
  1,
  1,
  0,
  data.level,
  public.character_rank_for_level(data.level),
  factions.capital_system_id,
  'ready',
  false
from (
  values
    ('character-orcos-warboss', 'orcos', 'Warboss Gorbad Krumpa', 'unit-orcos-warboss', 3),
    ('character-necrones-overlord', 'necrones', 'Overlord Sekh-Nemesor', 'unit-necrones-overlord', 3),
    ('character-guardia-castellan', 'guardia-imperial', 'Castellan Mira Holt', 'unit-guardia-castellan', 3),
    ('character-culto-primus', 'culto-genestelar', 'Primus Korda Vhal', 'unit-culto-primus', 3),
    ('character-sombra-captain', 'sombra-emperador', 'Captain Aster Valen', 'unit-sombra-captain', 3),
    ('character-muerte-lord-contagion', 'guardia-muerte', 'Lord Morbus Vane', 'unit-muerte-lord-contagion', 3)
) as data(slug, faction_slug, name, template_slug, level)
join public.factions on factions.slug = data.faction_slug
join public.unit_templates on unit_templates.slug = data.template_slug
where factions.capital_system_id is not null
on conflict (slug) do update
set
  faction_id = excluded.faction_id,
  unit_template_id = excluded.unit_template_id,
  name = excluded.name,
  category = excluded.category,
  unit_type = excluded.unit_type,
  points = excluded.points,
  quantity = excluded.quantity,
  starting_quantity = excluded.starting_quantity,
  wounds_taken = excluded.wounds_taken,
  experience = excluded.experience,
  rank = excluded.rank,
  current_system_id = excluded.current_system_id,
  status = excluded.status,
  is_visible_publicly = excluded.is_visible_publicly,
  updated_at = now();

insert into public.relics (
  id,
  slug,
  faction_id,
  system_id,
  name,
  description,
  effect_text,
  icon_key,
  rarity,
  is_public
)
select
  coalesce((select id from public.relics existing where existing.slug = data.slug), gen_random_uuid()),
  data.slug,
  factions.id,
  factions.capital_system_id,
  data.name,
  data.description,
  data.effect_text,
  data.icon_key,
  data.rarity,
  false
from (
  values
    ('relic-orcos-krozius-chatarra', 'orcos', 'Krozius de Chatarra Sagrada', 'Un trofeo brutal cubierto de sellos arrancados a enemigos imperiales.', 'Reliquia narrativa: simboliza autoridad brutal y victorias de abordaje.', 'hammer', 'rare'),
    ('relic-orcos-diente-gorko', 'orcos', 'Diente de Gorko', 'Colmillo enorme engarzado en hierro candente.', 'Reliquia narrativa: inspira cargas temerarias y duelos de jefes.', 'tooth', 'common'),
    ('relic-necrones-orbe-hekatep', 'necrones', 'Orbe de Hekatep', 'Esfera de mando que pulsa con codigo dinastico verde.', 'Reliquia narrativa: ancla protocolos de reanimacion y autoridad de tumba.', 'orb', 'rare'),
    ('relic-necrones-cetro-fase', 'necrones', 'Cetro de Fase', 'Baston de nobleza con filo que vibra entre realidades.', 'Reliquia narrativa: marca derecho de conquista sobre mundos dormidos.', 'scepter', 'common'),
    ('relic-guardia-estandarte-kasr', 'guardia-imperial', 'Estandarte de Kasr Vhal', 'Bandera de guerra recuperada de una fortaleza perdida.', 'Reliquia narrativa: concede legitimidad y valor a una linea imperial.', 'banner', 'rare'),
    ('relic-guardia-aquila-rota', 'guardia-imperial', 'Aquila Rota', 'Fragmento dorado de un santuario bombardeado.', 'Reliquia narrativa: juramento de resistencia bajo fuego imposible.', 'aquila', 'common'),
    ('relic-culto-garra-patriarca', 'culto-genestelar', 'Garra del Patriarca', 'Taliman oseo oculto en un relicario de manufactorum.', 'Reliquia narrativa: refuerza la fe de celulas insurgentes.', 'claw', 'rare'),
    ('relic-culto-mascara-vidrio', 'culto-genestelar', 'Mascara de Vidrio Negro', 'Mascara ritual usada por predicadores de la cuarta generacion.', 'Reliquia narrativa: simboliza infiltracion y control de masas.', 'mask', 'common'),
    ('relic-sombra-crux-eclipsada', 'sombra-emperador', 'Crux Eclipsada', 'Insignia de honor ennegrecida por la luz de un sol muerto.', 'Reliquia narrativa: recuerda juramentos de purga y defensa del sector.', 'crux', 'rare'),
    ('relic-sombra-fragmento-narthex', 'sombra-emperador', 'Fragmento del Narthex', 'Pieza de un altar sellado antes de la guerra actual.', 'Reliquia narrativa: legitima campanas de recuperacion sagrada.', 'reliquary', 'common'),
    ('relic-muerte-campana-putrida', 'guardia-muerte', 'Campana Putrida', 'Campana menor cubierta de oxido y letanias enfermas.', 'Reliquia narrativa: anuncia avances inevitables de la plaga.', 'bell', 'rare'),
    ('relic-muerte-incensario-morbus', 'guardia-muerte', 'Incensario de Morbus', 'Artefacto que exhala niebla toxica en susurros.', 'Reliquia narrativa: acompana procesiones de corrupcion y asedio.', 'censer', 'common')
) as data(slug, faction_slug, name, description, effect_text, icon_key, rarity)
join public.factions on factions.slug = data.faction_slug
where factions.capital_system_id is not null
on conflict (slug) do update
set
  faction_id = excluded.faction_id,
  system_id = coalesce(public.relics.system_id, excluded.system_id),
  name = excluded.name,
  description = excluded.description,
  effect_text = excluded.effect_text,
  icon_key = excluded.icon_key,
  rarity = excluded.rarity,
  is_public = excluded.is_public;

create or replace function public.equip_relic_to_character(
  relic_id uuid,
  character_unit_id uuid,
  system_building_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_relic public.relics%rowtype;
  v_character public.campaign_units%rowtype;
  v_building public.system_buildings%rowtype;
  v_system public.systems%rowtype;
  v_template public.building_templates%rowtype;
  v_slots integer;
  v_equipped_count integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  v_is_admin := public.is_admin();

  select * into v_relic from public.relics where id = relic_id for update;
  if not found then
    raise exception 'Reliquia no encontrada';
  end if;

  if v_relic.faction_id is null then
    raise exception 'Reliquia sin faccion asignada';
  end if;

  if not v_is_admin and not public.is_faction_member(v_relic.faction_id) then
    raise exception 'No puedes usar reliquias de otra faccion';
  end if;

  if v_relic.equipped_unit_id is not null then
    raise exception 'La reliquia ya esta equipada';
  end if;

  select * into v_character from public.campaign_units where id = character_unit_id for update;
  if not found then
    raise exception 'Character no encontrado';
  end if;

  if v_character.faction_id is distinct from v_relic.faction_id then
    raise exception 'La reliquia y el character deben ser de la misma faccion';
  end if;

  if v_character.unit_type <> 'character' then
    raise exception 'Solo los characters pueden equipar reliquias';
  end if;

  if v_character.status <> 'ready' or v_character.quantity <= 0 then
    raise exception 'El character debe estar listo y vivo';
  end if;

  select * into v_building from public.system_buildings where id = system_building_id for update;
  if not found then
    raise exception 'Santuario no encontrado';
  end if;

  select * into v_template from public.building_templates where id = v_building.building_template_id;
  if not found or v_template.slug <> 'santuario-reliquias' or v_template.building_kind <> 'relic' then
    raise exception 'El edificio no es un Santuario de Reliquias';
  end if;

  if v_building.status <> 'active' then
    raise exception 'El Santuario no esta activo';
  end if;

  select * into v_system from public.systems where id = v_building.system_id;
  if not found then
    raise exception 'Sistema invalido';
  end if;

  if not v_is_admin and v_system.controller_faction_id is distinct from v_relic.faction_id then
    raise exception 'El Santuario debe estar en un sistema controlado por tu faccion';
  end if;

  if v_relic.system_id is distinct from v_building.system_id then
    raise exception 'La reliquia debe estar almacenada en este Santuario';
  end if;

  if v_character.current_system_id is distinct from v_building.system_id then
    raise exception 'El character debe estar en el sistema del Santuario';
  end if;

  v_slots := public.character_relic_slots(v_character.experience);
  if v_slots <= 0 then
    raise exception 'El character necesita nivel 3 para equipar reliquias';
  end if;

  select count(*)
  into v_equipped_count
  from public.relics
  where equipped_unit_id = v_character.id;

  if v_equipped_count >= v_slots then
    raise exception 'El character no tiene slots de reliquia libres';
  end if;

  update public.relics
  set
    system_id = null,
    equipped_unit_id = v_character.id,
    equipped_at = now()
  where id = v_relic.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_relic.faction_id,
    'relic_equipped',
    jsonb_build_object('relic_id', v_relic.id, 'character_unit_id', v_character.id, 'system_building_id', v_building.id)
  );

  return v_relic.id;
end;
$$;

create or replace function public.unequip_relic_from_character(
  relic_id uuid,
  system_building_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_relic public.relics%rowtype;
  v_character public.campaign_units%rowtype;
  v_building public.system_buildings%rowtype;
  v_system public.systems%rowtype;
  v_template public.building_templates%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  v_is_admin := public.is_admin();

  select * into v_relic from public.relics where id = relic_id for update;
  if not found then
    raise exception 'Reliquia no encontrada';
  end if;

  if v_relic.equipped_unit_id is null then
    raise exception 'La reliquia no esta equipada';
  end if;

  if v_relic.faction_id is null then
    raise exception 'Reliquia sin faccion asignada';
  end if;

  if not v_is_admin and not public.is_faction_member(v_relic.faction_id) then
    raise exception 'No puedes usar reliquias de otra faccion';
  end if;

  select * into v_character from public.campaign_units where id = v_relic.equipped_unit_id for update;
  if not found then
    raise exception 'Character equipado no encontrado';
  end if;

  select * into v_building from public.system_buildings where id = system_building_id for update;
  if not found then
    raise exception 'Santuario no encontrado';
  end if;

  select * into v_template from public.building_templates where id = v_building.building_template_id;
  if not found or v_template.slug <> 'santuario-reliquias' or v_template.building_kind <> 'relic' then
    raise exception 'El edificio no es un Santuario de Reliquias';
  end if;

  if v_building.status <> 'active' then
    raise exception 'El Santuario no esta activo';
  end if;

  select * into v_system from public.systems where id = v_building.system_id;
  if not found then
    raise exception 'Sistema invalido';
  end if;

  if not v_is_admin and v_system.controller_faction_id is distinct from v_relic.faction_id then
    raise exception 'El Santuario debe estar en un sistema controlado por tu faccion';
  end if;

  if v_character.current_system_id is distinct from v_building.system_id or v_character.status <> 'ready' then
    raise exception 'El character debe estar listo en el sistema del Santuario';
  end if;

  update public.relics
  set
    system_id = v_building.system_id,
    equipped_unit_id = null,
    equipped_at = null
  where id = v_relic.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_relic.faction_id,
    'relic_unequipped',
    jsonb_build_object('relic_id', v_relic.id, 'character_unit_id', v_character.id, 'system_building_id', v_building.id)
  );

  return v_relic.id;
end;
$$;

revoke execute on function public.map_unit_category_to_type(text) from public;
revoke execute on function public.character_rank_for_level(integer) from public;
revoke execute on function public.character_relic_slots(integer) from public;
revoke execute on function public.equip_relic_to_character(uuid, uuid, uuid) from public;
revoke execute on function public.unequip_relic_from_character(uuid, uuid) from public;

grant execute on function public.map_unit_category_to_type(text) to authenticated;
grant execute on function public.character_rank_for_level(integer) to authenticated;
grant execute on function public.character_relic_slots(integer) to authenticated;
grant execute on function public.equip_relic_to_character(uuid, uuid, uuid) to authenticated;
grant execute on function public.unequip_relic_from_character(uuid, uuid) to authenticated;
