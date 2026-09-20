begin;

lock table
  public.campaign_units,
  public.faction_technologies,
  public.system_buildings,
  public.movement_orders,
  public.movement_order_units,
  public.conflicts,
  public.recruitment_queue,
  public.unit_recovery_queue,
  public.faction_resources,
  public.systems,
  public.system_edges,
  public.system_resource_capabilities,
  public.system_production
in share row exclusive mode;

do $$
begin
  if exists (
    select 1
    from public.movement_orders
    where status in ('pending_approval', 'moving')
  ) then
    raise exception 'No se puede ampliar el mapa mientras haya movimientos activos';
  end if;
end;
$$;

create temporary table protected_campaign_state (
  table_name text primary key,
  content_hash text not null
) on commit drop;

insert into protected_campaign_state (table_name, content_hash)
values
  ('campaign_units', (
    select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
    from public.campaign_units rows
  )),
  ('faction_technologies', (
    select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
    from public.faction_technologies rows
  )),
  ('system_buildings', (
    select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
    from public.system_buildings rows
  )),
  ('movement_orders', (
    select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
    from public.movement_orders rows
  )),
  ('movement_order_units', (
    select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
    from public.movement_order_units rows
  )),
  ('conflicts', (
    select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
    from public.conflicts rows
  )),
  ('recruitment_queue', (
    select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
    from public.recruitment_queue rows
  )),
  ('unit_recovery_queue', (
    select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
    from public.unit_recovery_queue rows
  ));

create temporary table faction_resources_before on commit drop as
select *
from public.faction_resources;

create temporary table existing_systems_before on commit drop as
select
  id,
  slug,
  to_jsonb(systems) - 'x' - 'y' as non_visual_state
from public.systems systems;

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
  allows_shared_occupation
)
values
  (
    public.seed_uuid('system', 'umbral-ceniza'),
    'umbral-ceniza',
    'Umbral de Ceniza',
    275, 147, 0.88, 'orange', 'Sistema fronterizo', 'neutral', null, null,
    'Una estrella exhausta envuelta en velos de ceniza y fragmentos de antiguas fortalezas orbitales.',
    false, 3, 'standard', true, false
  ),
  (
    public.seed_uuid('system', 'vigilia-noctis'),
    'vigilia-noctis',
    'Vigilia Noctis',
    735, 68, 0.92, 'blue', 'Sistema fronterizo', 'neutral', null, null,
    'Un corredor oscuro vigilado por lunas sin atmósfera y balizas imperiales apagadas.',
    false, 3, 'standard', true, false
  ),
  (
    public.seed_uuid('system', 'pozo-khepra'),
    'pozo-khepra',
    'Pozo Khepra',
    784, 447, 0.84, 'yellow', 'Sistema fronterizo', 'neutral', null, null,
    'Pozos mineros abandonados horadan sus mundos interiores, unidos por túneles de origen incierto.',
    false, 3, 'standard', true, false
  ),
  (
    public.seed_uuid('system', 'cenotafio-ankh'),
    'cenotafio-ankh',
    'Cenotafio Ankh',
    615, 860, 0.90, 'green', 'Sistema fronterizo', 'neutral', null, null,
    'Un sol verdoso ilumina complejos funerarios que preceden a todos los registros del sector.',
    false, 3, 'standard', true, false
  ),
  (
    public.seed_uuid('system', 'baluarte-sol'),
    'baluarte-sol',
    'Baluarte Sol',
    287, 807, 0.90, 'white', 'Sistema fronterizo', 'neutral', null, null,
    'Restos de una ciudadela solar orbitan una estrella blanca de luz severa y constante.',
    false, 3, 'standard', true, false
  ),
  (
    public.seed_uuid('system', 'corona-voss'),
    'corona-voss',
    'Corona Voss',
    452, 406, 0.82, 'white', 'Sistema del corredor central', 'neutral', null, null,
    'Mundos rocosos forman una corona irregular alrededor de una estrella cubierta de cicatrices magnéticas.',
    false, 4, 'standard', true, false
  ),
  (
    public.seed_uuid('system', 'nadir-kappa'),
    'nadir-kappa',
    'Nadir Kappa',
    504, 594, 0.86, 'red', 'Encrucijada central', 'neutral', null, null,
    'Una encrucijada de rutas antiguas marcada por pecios, puestos de escucha y señales contradictorias.',
    false, 4, 'standard', true, false
  ),
  (
    public.seed_uuid('system', 'cicatriz-helion'),
    'cicatriz-helion',
    'Cicatriz Helion',
    378, 687, 0.80, 'violet', 'Sistema del corredor central', 'neutral', null, null,
    'Descargas violetas recorren una cadena de planetas quebrados por una catástrofe olvidada.',
    false, 4, 'standard', true, false
  ),
  (
    public.seed_uuid('system', 'nebulosa-caronte'),
    'nebulosa-caronte',
    'Nebulosa Caronte',
    298, 542, 1.06, 'violet', 'Anomalía gaseosa central', 'neutral', null, null,
    'Un océano de gases ionizados donde los auspex dibujan rutas que cambian con cada tormenta.',
    false, 0, 'gaseous', false, true
  )
on conflict (slug) do nothing;

create temporary table expanded_map_positions (
  slug text primary key,
  x numeric not null,
  y numeric not null
) on commit drop;

insert into expanded_map_positions (slug, x, y)
values
  ('mordax', 102, 157),
  ('drusus', 167, 362),
  ('umbral-ceniza', 275, 147),
  ('goregate', 478, 224),
  ('vigilia-noctis', 735, 68),
  ('sa-cea-gate', 853, 137),
  ('lyra-terminus', 929, 329),
  ('maelstrom-gas', 642, 379),
  ('pozo-khepra', 784, 447),
  ('blackglass', 900, 552),
  ('red-sabbath', 800, 623),
  ('voidmist-basin', 679, 635),
  ('novem', 756, 737),
  ('thokt-vault', 918, 895),
  ('cenotafio-ankh', 615, 860),
  ('nexus-aster', 494, 871),
  ('baluarte-sol', 287, 807),
  ('kharon-prime', 68, 885),
  ('helios-drift', 78, 727),
  ('nebulosa-caronte', 298, 542),
  ('cicatriz-helion', 378, 687),
  ('nadir-kappa', 504, 594),
  ('corona-voss', 452, 406);

update public.systems systems
set
  x = positions.x,
  y = positions.y,
  updated_at = systems.updated_at
from expanded_map_positions positions
where systems.slug = positions.slug;

insert into public.system_production (system_id)
select systems.id
from public.systems systems
where systems.slug in (
  'umbral-ceniza',
  'vigilia-noctis',
  'pozo-khepra',
  'cenotafio-ankh',
  'baluarte-sol',
  'corona-voss',
  'nadir-kappa',
  'cicatriz-helion',
  'nebulosa-caronte'
)
on conflict (system_id) do nothing;

create temporary table desired_expanded_edges (
  from_slug text not null,
  to_slug text not null,
  primary key (from_slug, to_slug),
  check (from_slug < to_slug)
) on commit drop;

insert into desired_expanded_edges (from_slug, to_slug)
values
  ('drusus', 'mordax'),
  ('mordax', 'umbral-ceniza'),
  ('goregate', 'umbral-ceniza'),
  ('drusus', 'nebulosa-caronte'),
  ('lyra-terminus', 'sa-cea-gate'),
  ('sa-cea-gate', 'vigilia-noctis'),
  ('goregate', 'vigilia-noctis'),
  ('lyra-terminus', 'maelstrom-gas'),
  ('goregate', 'maelstrom-gas'),
  ('maelstrom-gas', 'pozo-khepra'),
  ('blackglass', 'pozo-khepra'),
  ('blackglass', 'red-sabbath'),
  ('red-sabbath', 'voidmist-basin'),
  ('novem', 'voidmist-basin'),
  ('novem', 'thokt-vault'),
  ('cenotafio-ankh', 'thokt-vault'),
  ('cenotafio-ankh', 'nexus-aster'),
  ('nexus-aster', 'voidmist-basin'),
  ('helios-drift', 'nebulosa-caronte'),
  ('helios-drift', 'kharon-prime'),
  ('baluarte-sol', 'kharon-prime'),
  ('baluarte-sol', 'nexus-aster'),
  ('corona-voss', 'nebulosa-caronte'),
  ('corona-voss', 'maelstrom-gas'),
  ('nadir-kappa', 'nebulosa-caronte'),
  ('maelstrom-gas', 'nadir-kappa'),
  ('nadir-kappa', 'voidmist-basin'),
  ('cicatriz-helion', 'nebulosa-caronte'),
  ('cicatriz-helion', 'voidmist-basin');

delete from public.system_edges edges
using public.systems origins, public.systems targets
where origins.id = edges.from_system_id
  and targets.id = edges.to_system_id
  and not exists (
    select 1
    from desired_expanded_edges desired
    where desired.from_slug = least(origins.slug, targets.slug)
      and desired.to_slug = greatest(origins.slug, targets.slug)
  );

insert into public.system_edges (
  id,
  slug,
  from_system_id,
  to_system_id,
  uridium_cost,
  is_blocked
)
select
  public.seed_uuid('expanded_map_edge', desired.from_slug || ':' || desired.to_slug),
  'route-' || desired.from_slug || '-' || desired.to_slug,
  origins.id,
  targets.id,
  1,
  false
from desired_expanded_edges desired
join public.systems origins on origins.slug = desired.from_slug
join public.systems targets on targets.slug = desired.to_slug
where not exists (
  select 1
  from public.system_edges edges
  where least(edges.from_system_id, edges.to_system_id) = least(origins.id, targets.id)
    and greatest(edges.from_system_id, edges.to_system_id) = greatest(origins.id, targets.id)
);

update public.system_edges edges
set
  uridium_cost = 1,
  is_blocked = false
from public.systems origins, public.systems targets, desired_expanded_edges desired
where origins.id = edges.from_system_id
  and targets.id = edges.to_system_id
  and desired.from_slug = least(origins.slug, targets.slug)
  and desired.to_slug = greatest(origins.slug, targets.slug);

create or replace function public.base_system_capacity(
  system_slug text,
  system_kind text,
  is_capital boolean,
  resource_key text
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_slug text := coalesce(system_slug, '');
begin
  if coalesce(system_kind, 'standard') = 'gaseous' then
    return 0;
  end if;

  return case v_slug
    when 'mordax' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'drusus' then case resource_key when 'minerals' then 4 when 'uridium' then 0.6 else 0 end
    when 'sa-cea-gate' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'lyra-terminus' then case resource_key when 'minerals' then 4 when 'uridium' then 0.6 else 0 end
    when 'thokt-vault' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'novem' then case resource_key when 'minerals' then 4 when 'uridium' then 0.6 else 0 end
    when 'kharon-prime' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'helios-drift' then case resource_key when 'minerals' then 4 when 'uridium' then 0.6 else 0 end
    when 'blackglass' then case resource_key when 'supply' then 11 when 'honor' then 0.5 when 'industrial_material' then 5 else 0 end
    when 'red-sabbath' then case resource_key when 'minerals' then 4 when 'uridium' then 0.6 else 0 end
    when 'nexus-aster' then case resource_key when 'supply' then 10 when 'minerals' then 3 when 'industrial_material' then 5 when 'uridium' then 0.6 else 0 end
    when 'goregate' then case resource_key when 'supply' then 5 when 'minerals' then 5 when 'industrial_material' then 6 when 'uridium' then 0.6 else 0 end
    when 'cenotafio-ankh' then case resource_key when 'supply' then 4 when 'minerals' then 3 else 0 end
    when 'umbral-ceniza' then case resource_key when 'supply' then 6 when 'minerals' then 2 else 0 end
    when 'baluarte-sol' then case resource_key when 'supply' then 6 when 'minerals' then 2 else 0 end
    when 'pozo-khepra' then case resource_key when 'supply' then 8 when 'minerals' then 1 else 0 end
    when 'vigilia-noctis' then case resource_key when 'supply' then 8 when 'minerals' then 1 else 0 end
    when 'corona-voss' then case resource_key when 'supply' then 7 when 'minerals' then 2 when 'honor' then 1 when 'gold' then 1 when 'industrial_material' then 5 when 'uridium' then 0.5 else 0 end
    when 'cicatriz-helion' then case resource_key when 'supply' then 6 when 'minerals' then 5 when 'gold' then 1 when 'industrial_material' then 5 when 'uridium' then 0.5 else 0 end
    when 'nadir-kappa' then case resource_key when 'supply' then 12 when 'minerals' then 4 when 'gold' then 1 when 'industrial_material' then 4 when 'uridium' then 0.5 else 0 end
    else 0
  end;
end;
$$;

select public.rebuild_system_resource_capabilities();
select public.refresh_system_production_from_buildings();

update public.faction_resources resources
set
  technology = resources.technology + 1,
  updated_at = now()
from public.factions factions
where factions.id = resources.faction_id
  and factions.slug in (
    'legiones-daemonicas',
    'cultos-genestealer',
    'space-marines',
    'adeptus-custodes',
    'necrones'
  );

do $$
declare
  v_reachable integer;
begin
  if (select count(*) from public.systems) <> 23 then
    raise exception 'El mapa ampliado debe tener 23 sistemas';
  end if;

  if (select count(*) from public.system_edges) <> 29 then
    raise exception 'El mapa ampliado debe tener 29 rutas';
  end if;

  if (select count(*) from public.systems where system_kind = 'gaseous') <> 3 then
    raise exception 'El mapa ampliado debe tener 3 sistemas gaseosos';
  end if;

  if exists (
    select 1
    from public.system_edges edges
    join public.systems origins on origins.id = edges.from_system_id
    join public.systems targets on targets.id = edges.to_system_id
    group by least(origins.slug, targets.slug), greatest(origins.slug, targets.slug)
    having count(*) > 1
  ) then
    raise exception 'El mapa ampliado contiene rutas duplicadas';
  end if;

  with recursive reachable(id) as (
    select id
    from public.systems
    where slug = 'mordax'

    union

    select case
      when edges.from_system_id = reachable.id then edges.to_system_id
      else edges.from_system_id
    end
    from reachable
    join public.system_edges edges
      on edges.from_system_id = reachable.id
      or edges.to_system_id = reachable.id
  )
  select count(*) into v_reachable
  from reachable;

  if v_reachable <> 23 then
    raise exception 'El mapa ampliado no está completamente conectado: %/23', v_reachable;
  end if;

  if exists (
    select 1
    from existing_systems_before snapshot
    join public.systems systems on systems.id = snapshot.id
    where (to_jsonb(systems) - 'x' - 'y') is distinct from snapshot.non_visual_state
  ) then
    raise exception 'La ampliación modificó el estado no visual de un sistema existente';
  end if;

  if exists (
    with current_state(table_name, content_hash) as (
      values
        ('campaign_units', (
          select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
          from public.campaign_units rows
        )),
        ('faction_technologies', (
          select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
          from public.faction_technologies rows
        )),
        ('system_buildings', (
          select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
          from public.system_buildings rows
        )),
        ('movement_orders', (
          select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
          from public.movement_orders rows
        )),
        ('movement_order_units', (
          select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
          from public.movement_order_units rows
        )),
        ('conflicts', (
          select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
          from public.conflicts rows
        )),
        ('recruitment_queue', (
          select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
          from public.recruitment_queue rows
        )),
        ('unit_recovery_queue', (
          select md5(coalesce(string_agg(to_jsonb(rows)::text, E'\n' order by to_jsonb(rows)::text), ''))
          from public.unit_recovery_queue rows
        ))
    )
    select 1
    from current_state current_rows
    join protected_campaign_state protected_rows using (table_name)
    where current_rows.content_hash is distinct from protected_rows.content_hash
  ) then
    raise exception 'La ampliación modificó estado protegido de la campaña';
  end if;

  if exists (
    select 1
    from faction_resources_before previous
    join public.faction_resources current_rows using (faction_id)
    join public.factions factions on factions.id = current_rows.faction_id
    where (
      factions.slug in (
        'legiones-daemonicas',
        'cultos-genestealer',
        'space-marines',
        'adeptus-custodes',
        'necrones'
      )
      and (
        current_rows.technology <> previous.technology + 1
        or (to_jsonb(current_rows) - 'technology' - 'updated_at')
          is distinct from (to_jsonb(previous) - 'technology' - 'updated_at')
      )
    ) or (
      factions.slug not in (
        'legiones-daemonicas',
        'cultos-genestealer',
        'space-marines',
        'adeptus-custodes',
        'necrones'
      )
      and to_jsonb(current_rows) is distinct from to_jsonb(previous)
    )
  ) then
    raise exception 'El incremento tecnológico modificó otros recursos';
  end if;
end;
$$;

commit;
