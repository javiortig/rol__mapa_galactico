create or replace function public.normalize_unit_keyword(keyword text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when lower(coalesce(keyword, '')) in ('vehiculo', 'vehicle', 'vehiculos', 'superpesado') then 'Vehiculo'
    when lower(coalesce(keyword, '')) in ('caracter', 'character', 'characters', 'personaje', 'personajes') then 'Caracter'
    when lower(coalesce(keyword, '')) in ('infanteria', 'infantry', 'elite', 'elites') then 'Infanteria'
    when lower(coalesce(keyword, '')) in ('bestia', 'beast', 'monstruo', 'monster', 'monsters') then 'Bestia'
    when lower(coalesce(keyword, '')) in ('montado', 'montada', 'montados', 'montadas', 'mounted') then 'Montado'
    when lower(coalesce(keyword, '')) like '%veh%' then 'Vehiculo'
    when lower(coalesce(keyword, '')) like '%character%' or lower(coalesce(keyword, '')) like '%person%' or lower(coalesce(keyword, '')) like '%caracter%' then 'Caracter'
    when lower(coalesce(keyword, '')) like '%monstru%' or lower(coalesce(keyword, '')) like '%beast%' then 'Bestia'
    when lower(coalesce(keyword, '')) like '%mount%' or lower(coalesce(keyword, '')) like '%montad%' then 'Montado'
    when lower(coalesce(keyword, '')) like '%infan%' or lower(coalesce(keyword, '')) like '%elite%' then 'Infanteria'
    else null
  end;
$$;

create or replace function public.unit_keywords_are_valid(keywords text[])
returns boolean
language sql
immutable
set search_path = public
as $$
  select coalesce(array_length(keywords, 1), 0) between 1 and 2
    and not exists (
      select 1
      from unnest(coalesce(keywords, array[]::text[])) as item(keyword)
      where item.keyword not in ('Vehiculo', 'Caracter', 'Infanteria', 'Bestia', 'Montado')
    )
    and (
      select count(*)
      from unnest(coalesce(keywords, array[]::text[])) as item(keyword)
    ) = (
      select count(distinct item.keyword)
      from unnest(coalesce(keywords, array[]::text[])) as item(keyword)
    );
$$;

create or replace function public.unit_keywords_from_category(category text, legacy_unit_type text default null)
returns text[]
language sql
immutable
set search_path = public
as $$
  select case
    when public.normalize_unit_keyword(legacy_unit_type) = 'Caracter'
      or public.normalize_unit_keyword(category) = 'Caracter'
      then array['Infanteria', 'Caracter']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Vehiculo'
      or public.normalize_unit_keyword(category) = 'Vehiculo'
      then array['Vehiculo']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Bestia'
      or public.normalize_unit_keyword(category) = 'Bestia'
      then array['Bestia']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Montado'
      or public.normalize_unit_keyword(category) = 'Montado'
      then array['Montado']::text[]
    else array['Infanteria']::text[]
  end;
$$;

create or replace function public.normalize_unit_keywords(
  raw_keywords text[],
  category text default null,
  legacy_unit_type text default null
)
returns text[]
language plpgsql
immutable
set search_path = public
as $$
declare
  v_result text[] := array[]::text[];
  v_raw text;
  v_keyword text;
begin
  foreach v_raw in array coalesce(raw_keywords, array[]::text[]) loop
    v_keyword := public.normalize_unit_keyword(v_raw);

    if v_keyword is not null and not v_keyword = any(v_result) then
      v_result := array_append(v_result, v_keyword);
    end if;

    if array_length(v_result, 1) >= 2 then
      exit;
    end if;
  end loop;

  if coalesce(array_length(v_result, 1), 0) = 0 then
    v_result := public.unit_keywords_from_category(category, legacy_unit_type);
  end if;

  if not public.unit_keywords_are_valid(v_result) then
    v_result := array['Infanteria']::text[];
  end if;

  return v_result;
end;
$$;

create or replace function public.legacy_unit_type_from_keywords(keywords text[])
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when 'Caracter' = any(coalesce(keywords, array[]::text[])) then 'character'
    when 'Vehiculo' = any(coalesce(keywords, array[]::text[])) then 'vehicle'
    when 'Bestia' = any(coalesce(keywords, array[]::text[])) then 'beast'
    when 'Montado' = any(coalesce(keywords, array[]::text[])) then 'mounted'
    else 'infantry'
  end;
$$;

alter table public.unit_templates
  add column if not exists unit_keywords text[] not null default array['Infanteria']::text[];

alter table public.campaign_units
  add column if not exists unit_keywords text[] not null default array['Infanteria']::text[];

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.unit_templates'::regclass
      and pg_get_constraintdef(oid) ilike '%unit_keywords%'
  loop
    execute format('alter table public.unit_templates drop constraint %I', v_constraint.conname);
  end loop;

  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.campaign_units'::regclass
      and pg_get_constraintdef(oid) ilike '%unit_keywords%'
  loop
    execute format('alter table public.campaign_units drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

alter table public.unit_templates
  add constraint unit_templates_unit_keywords_check
  check (public.unit_keywords_are_valid(unit_keywords));

alter table public.campaign_units
  add constraint campaign_units_unit_keywords_check
  check (public.unit_keywords_are_valid(unit_keywords));

update public.unit_templates
set
  unit_keywords = public.unit_keywords_from_category(category, unit_type),
  unit_type = public.legacy_unit_type_from_keywords(public.unit_keywords_from_category(category, unit_type));

update public.campaign_units units
set
  unit_keywords = coalesce(templates.unit_keywords, public.unit_keywords_from_category(units.category, units.unit_type)),
  unit_type = public.legacy_unit_type_from_keywords(coalesce(templates.unit_keywords, public.unit_keywords_from_category(units.category, units.unit_type)))
from public.unit_templates templates
where templates.id = units.unit_template_id;

update public.campaign_units
set
  unit_keywords = public.unit_keywords_from_category(category, unit_type),
  unit_type = public.legacy_unit_type_from_keywords(public.unit_keywords_from_category(category, unit_type))
where unit_template_id is null;

create or replace function public.sync_campaign_unit_type_and_rank()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_template_type text;
  v_template_keywords text[];
begin
  if new.unit_template_id is not null then
    select unit_templates.unit_type, unit_templates.unit_keywords
    into v_template_type, v_template_keywords
    from public.unit_templates
    where unit_templates.id = new.unit_template_id;
  end if;

  new.unit_keywords := public.normalize_unit_keywords(coalesce(new.unit_keywords, v_template_keywords), new.category, coalesce(v_template_type, new.unit_type));

  if v_template_keywords is not null and new.unit_keywords = array['Infanteria']::text[] and v_template_keywords <> array['Infanteria']::text[] then
    new.unit_keywords := v_template_keywords;
  end if;

  new.unit_type := public.legacy_unit_type_from_keywords(new.unit_keywords);

  if 'Caracter' = any(new.unit_keywords) then
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
before insert or update of unit_template_id, category, unit_type, unit_keywords, experience
on public.campaign_units
for each row
execute function public.sync_campaign_unit_type_and_rank();

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
    raise exception 'Caracter no encontrado';
  end if;

  if v_character.faction_id is distinct from v_relic.faction_id then
    raise exception 'La reliquia y el Caracter deben ser de la misma faccion';
  end if;

  if not ('Caracter' = any(coalesce(v_character.unit_keywords, array[]::text[]))) then
    raise exception 'Solo unidades con keyword Caracter pueden equipar reliquias';
  end if;

  if v_character.status <> 'ready' or v_character.quantity <= 0 then
    raise exception 'El Caracter debe estar listo y vivo';
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
    raise exception 'El Caracter debe estar en el sistema del Santuario';
  end if;

  v_slots := public.character_relic_slots(v_character.experience);
  if v_slots <= 0 then
    raise exception 'El Caracter necesita nivel 3 para equipar reliquias';
  end if;

  select count(*)
  into v_equipped_count
  from public.relics
  where equipped_unit_id = v_character.id;

  if v_equipped_count >= v_slots then
    raise exception 'El Caracter no tiene slots de reliquia libres';
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
    raise exception 'Caracter equipado no encontrado';
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
    raise exception 'El Caracter debe estar listo en el sistema del Santuario';
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

revoke execute on function public.normalize_unit_keyword(text) from public;
revoke execute on function public.unit_keywords_are_valid(text[]) from public;
revoke execute on function public.unit_keywords_from_category(text, text) from public;
revoke execute on function public.normalize_unit_keywords(text[], text, text) from public;
revoke execute on function public.legacy_unit_type_from_keywords(text[]) from public;

grant execute on function public.normalize_unit_keyword(text) to authenticated;
grant execute on function public.unit_keywords_are_valid(text[]) to authenticated;
grant execute on function public.unit_keywords_from_category(text, text) to authenticated;
grant execute on function public.normalize_unit_keywords(text[], text, text) to authenticated;
grant execute on function public.legacy_unit_type_from_keywords(text[]) to authenticated;
