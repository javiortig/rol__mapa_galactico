create or replace function public.normalize_unit_keyword(keyword text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when lower(coalesce(keyword, '')) in ('vehiculo', 'vehicle', 'vehiculos', 'superpesado') then 'Vehiculo'
    when lower(coalesce(keyword, '')) in ('aeronave', 'aeronaves', 'aircraft', 'flyer', 'flyers') then 'Aeronave'
    when lower(coalesce(keyword, '')) in ('fortificacion', 'fortificaciones', 'fortification', 'fortifications') then 'Fortificacion'
    when lower(coalesce(keyword, '')) in ('caracter', 'character', 'characters', 'personaje', 'personajes') then 'Caracter'
    when lower(coalesce(keyword, '')) in ('infanteria', 'infantry', 'elite', 'elites') then 'Infanteria'
    when lower(coalesce(keyword, '')) in ('bestia', 'beast', 'monstruo', 'monster', 'monsters', 'swarm') then 'Bestia'
    when lower(coalesce(keyword, '')) in ('montado', 'montada', 'montados', 'montadas', 'mounted') then 'Montado'
    when lower(coalesce(keyword, '')) like '%fortif%' then 'Fortificacion'
    when lower(coalesce(keyword, '')) like '%aircraft%' or lower(coalesce(keyword, '')) like '%aeronav%' then 'Aeronave'
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
      where item.keyword not in ('Vehiculo', 'Caracter', 'Infanteria', 'Bestia', 'Montado', 'Aeronave', 'Fortificacion')
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
    when public.normalize_unit_keyword(legacy_unit_type) = 'Fortificacion'
      or public.normalize_unit_keyword(category) = 'Fortificacion'
      then array['Fortificacion']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Aeronave'
      or public.normalize_unit_keyword(category) = 'Aeronave'
      then array['Vehiculo', 'Aeronave']::text[]
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

create or replace function public.legacy_unit_type_from_keywords(keywords text[])
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when 'Caracter' = any(coalesce(keywords, array[]::text[])) then 'character'
    when 'Vehiculo' = any(coalesce(keywords, array[]::text[]))
      or 'Aeronave' = any(coalesce(keywords, array[]::text[]))
      or 'Fortificacion' = any(coalesce(keywords, array[]::text[])) then 'vehicle'
    when 'Bestia' = any(coalesce(keywords, array[]::text[])) then 'beast'
    when 'Montado' = any(coalesce(keywords, array[]::text[])) then 'mounted'
    else 'infantry'
  end;
$$;
