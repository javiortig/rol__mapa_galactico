alter table public.technology_nodes
  add column if not exists implementation_status text not null default 'active';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.technology_nodes'::regclass
      and conname = 'technology_nodes_implementation_status_check'
  ) then
    alter table public.technology_nodes
      add constraint technology_nodes_implementation_status_check
        check (implementation_status in ('active', 'planned', 'deprecated'));
  end if;
end;
$$;

alter table public.technology_prerequisites
  add column if not exists prerequisite_group integer;

with ranked as (
  select
    technology_node_id,
    required_node_id,
    row_number() over (partition by technology_node_id order by created_at, required_node_id)::integer as group_number
  from public.technology_prerequisites
)
update public.technology_prerequisites prerequisites
set prerequisite_group = ranked.group_number
from ranked
where prerequisites.technology_node_id = ranked.technology_node_id
  and prerequisites.required_node_id = ranked.required_node_id
  and prerequisites.prerequisite_group is null;

alter table public.technology_prerequisites
  alter column prerequisite_group set default 1,
  alter column prerequisite_group set not null;

create index if not exists technology_prerequisites_group_idx
  on public.technology_prerequisites (technology_node_id, prerequisite_group);

create or replace function public.are_technology_prerequisites_met(
  target_faction_id uuid,
  target_technology_node_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from (
      select prerequisite_group
      from public.technology_prerequisites
      where technology_node_id = target_technology_node_id
      group by prerequisite_group
    ) groups
    where not exists (
      select 1
      from public.technology_prerequisites prerequisites
      join public.faction_technologies unlocked
        on unlocked.technology_node_id = prerequisites.required_node_id
       and unlocked.faction_id = target_faction_id
       and unlocked.status = 'unlocked'
      where prerequisites.technology_node_id = target_technology_node_id
        and prerequisites.prerequisite_group = groups.prerequisite_group
    )
  );
$$;

insert into public.technology_nodes (
  id,
  slug,
  tree_key,
  name,
  description,
  branch,
  tier,
  position_x,
  position_y,
  cost_technology,
  research_time_seconds,
  icon_key,
  effect_summary,
  is_starter,
  implementation_status
)
values
  (public.seed_uuid('technology_node', 'fundacion-planetaria'), 'fundacion-planetaria', 'common-v1', 'Fundacion Planetaria', 'Protocolos basicos para levantar la primera infraestructura estable de una campana.', 'Progreso', 0, 46, 48, 0, 30, 'foundation', 'Permite construir Barracones de Infanteria y Granjas Biologicas.', true, 'active'),
  (public.seed_uuid('technology_node', 'maquinaria-belica'), 'maquinaria-belica', 'common-v1', 'Maquinaria Belica', 'Talleres, elevadores y servosistemas para fabricar y mantener vehiculos.', 'Progreso', 1, 36, 34, 1, 30, 'war_machine', 'Permite construir Talleres de Guerra.', false, 'active'),
  (public.seed_uuid('technology_node', 'criadero-guerra'), 'criadero-guerra', 'common-v1', 'Criadero de Guerra', 'Jaulas, ritos de control y habitats adaptados para criaturas de guerra.', 'Progreso', 1, 54, 34, 1, 30, 'beast', 'Permite construir Nidos de Bestias.', false, 'active'),
  (public.seed_uuid('technology_node', 'asamblea-planetaria'), 'asamblea-planetaria', 'common-v1', 'Asamblea Planetaria', 'Estructura de mando local capaz de sostener oficiales, personajes y estados mayores.', 'Progreso', 2, 45, 22, 2, 30, 'command', 'Permite construir Cuarteles de Mando.', false, 'active'),
  (public.seed_uuid('technology_node', 'procesado-metalurgico'), 'procesado-metalurgico', 'common-v1', 'Procesado Metalurgico', 'Cadenas industriales para convertir mineral bruto en materiales de construccion.', 'Progreso', 1, 63, 50, 0, 30, 'factory', 'Permite construir Plantas de Fundicion.', false, 'active'),
  (public.seed_uuid('technology_node', 'cristalizacion-combustible-cuantico'), 'cristalizacion-combustible-cuantico', 'common-v1', 'Cristalizacion de Combustible Cuantico', 'Tecnicas de estabilizacion para refinar Iridium util en rutas de salto.', 'Progreso', 2, 73, 39, 0, 30, 'uridium', 'Permite construir Refinerias de Iridium.', false, 'active'),
  (public.seed_uuid('technology_node', 'extraccion-subterranea'), 'extraccion-subterranea', 'common-v1', 'Extraccion Subterranea', 'Sondeos profundos y maquinaria pesada para explotar vetas minerales.', 'Progreso', 2, 73, 55, 1, 30, 'mine', 'Permite construir Complejos Mineros.', false, 'active'),
  (public.seed_uuid('technology_node', 'monumentos-gloria'), 'monumentos-gloria', 'common-v1', 'Monumentos a la Gloria', 'Arquitectura ceremonial para convertir victorias y lealtad en Honor.', 'Progreso', 2, 73, 71, 1, 30, 'honor', 'Permite construir Monumentos.', false, 'active'),
  (public.seed_uuid('technology_node', 'fiebre-oro'), 'fiebre-oro', 'common-v1', 'La Fiebre del Oro', 'Prospeccion avanzada para localizar y explotar yacimientos preciosos.', 'Progreso', 3, 86, 55, 1, 30, 'gold', 'Permite construir Minas de Oro.', false, 'active'),
  (public.seed_uuid('technology_node', 'pactos-mercantiles'), 'pactos-mercantiles', 'common-v1', 'Pactos Mercantiles', 'Acuerdos y garantias para atraer camaras de comercio al frente.', 'Progreso', 4, 91, 40, 1, 30, 'commerce', 'Permite construir Camaras de Comercio.', false, 'active'),
  (public.seed_uuid('technology_node', 'contactos-economicos'), 'contactos-economicos', 'common-v1', 'Contactos Economicos', 'Red de intermediarios y agentes comerciales con acceso al mercader.', 'Progreso', 5, 96, 30, 1, 30, 'merchant', 'Permite comerciar con el Mercader.', false, 'active'),
  (public.seed_uuid('technology_node', 'tratos-preferentes'), 'tratos-preferentes', 'common-v1', 'Tratos Preferentes', 'Credenciales, favores y rutas protegidas que reducen las tasas del mercader.', 'Progreso', 6, 96, 18, 2, 30, 'trade_discount', 'Mejora precios del Mercader: compra a 1.5x y venta a 0.75x del valor.', false, 'active'),
  (public.seed_uuid('technology_node', 'mercado-galactico'), 'mercado-galactico', 'common-v1', 'Mercado Galactico', 'Acceso a tablones de oferta y rutas de intercambio entre jugadores.', 'Progreso', 5, 96, 52, 1, 30, 'market', 'Permite usar el Comercio Estelar.', false, 'active'),
  (public.seed_uuid('technology_node', 'aranceles-privilegiados'), 'aranceles-privilegiados', 'common-v1', 'Aranceles Privilegiados', 'Tratados fiscales que reducen la comision del comercio estelar.', 'Progreso', 6, 96, 64, 2, 30, 'tariff', 'Reduce tu comision de Comercio Estelar al 10%, minimo 1 oro.', false, 'active'),

  (public.seed_uuid('technology_node', 'oficina-inteligencia'), 'oficina-inteligencia', 'common-v1', 'Oficina de Inteligencia', 'Primer nucleo burocratico para futuras operaciones de espionaje.', 'Inteligencia', 1, 18, 58, 0, 30, 'intelligence', 'Proximamente: desbloqueara Nexos de Inteligencia.', false, 'planned'),
  (public.seed_uuid('technology_node', 'celulas-informacion'), 'celulas-informacion', 'common-v1', 'Celulas de Informacion', 'Redes discretas de observadores, informadores y escuchas.', 'Inteligencia', 2, 14, 70, 2, 30, 'cells', 'Proximamente: produccion de espionaje y Antenas de Reconocimiento.', false, 'planned'),
  (public.seed_uuid('technology_node', 'doctrina-clandestina'), 'doctrina-clandestina', 'common-v1', 'Doctrina Clandestina', 'Protocolos de infiltracion sostenida para operaciones encubiertas.', 'Inteligencia', 3, 8, 82, 1, 30, 'cloak', 'Proximamente: mejora de produccion de espionaje.', false, 'planned'),
  (public.seed_uuid('technology_node', 'doble-agente'), 'doble-agente', 'common-v1', 'Doble Agente', 'Contramedidas para detectar redes enemigas y operaciones infiltradas.', 'Inteligencia', 3, 18, 86, 1, 30, 'agent', 'Proximamente: probabilidad de detectar espionaje enemigo.', false, 'planned'),
  (public.seed_uuid('technology_node', 'tecnologia-sar'), 'tecnologia-sar', 'common-v1', 'Tecnologia SAR', 'Lectura de largo alcance para reconocimiento y triangulacion avanzada.', 'Inteligencia', 3, 28, 82, 1, 30, 'radar', 'Proximamente: duplicara alcance de Antenas de Reconocimiento.', false, 'planned')
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

update public.technology_nodes
set
  research_time_seconds = 30,
  implementation_status = case
    when slug in (
      'doctrina-campana',
      'estado-mayor-cruzada',
      'honores-batalla',
      'talleres-campana',
      'dominio-bestial',
      'arsenal-pesado',
      'nodo-logistico',
      'manufactorum-local',
      'red-suministro',
      'puerto-uridium',
      'auspex-reliquias',
      'nucleos-datos',
      'cifra-negra'
    ) then 'deprecated'
    else implementation_status
  end,
  updated_at = now()
where tree_key = 'common-v1';

update public.technology_nodes
set
  branch = 'Mando militar',
  position_x = case slug
    when 'entrenamiento-linea' then 22
    when 'logistica-frente' then 10
    when 'cadenas-mando' then 25
    else position_x
  end,
  position_y = case slug
    when 'entrenamiento-linea' then 32
    when 'logistica-frente' then 22
    when 'cadenas-mando' then 18
    else position_y
  end,
  effect_summary = case slug
    when 'entrenamiento-linea' then 'Unidades basicas desbloqueadas.'
    when 'logistica-frente' then '-10% Suministro al reclutar Infanteria.'
    when 'cadenas-mando' then '-10% tiempo al reclutar Infanteria.'
    else effect_summary
  end,
  implementation_status = 'active',
  research_time_seconds = 30,
  updated_at = now()
where slug in ('entrenamiento-linea', 'logistica-frente', 'cadenas-mando');

update public.technology_nodes
set
  branch = 'Infanteria y elite',
  position_x = case slug
    when 'veteranos-guerra' then 30
    when 'especializacion-elite' then 18
    else position_x
  end,
  position_y = case slug
    when 'veteranos-guerra' then 42
    when 'especializacion-elite' then 48
    else position_y
  end,
  implementation_status = 'active',
  research_time_seconds = 30,
  updated_at = now()
where slug in ('veteranos-guerra', 'especializacion-elite');

update public.technology_nodes
set
  branch = 'Blindados y maquinas',
  position_x = case slug
    when 'motores-guerra' then 42
    when 'blindaje-reforzado' then 55
    else position_x
  end,
  position_y = case slug
    when 'motores-guerra' then 15
    when 'blindaje-reforzado' then 16
    else position_y
  end,
  implementation_status = 'active',
  research_time_seconds = 30,
  updated_at = now()
where slug in ('motores-guerra', 'blindaje-reforzado');

update public.technology_nodes
set
  branch = 'Arqueotecnologia',
  position_x = 36,
  position_y = 62,
  implementation_status = 'active',
  research_time_seconds = 30,
  updated_at = now()
where slug = 'matrices-eficiencia';

delete from public.technology_prerequisites
where technology_node_id in (
  select id
  from public.technology_nodes
  where tree_key = 'common-v1'
);

insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
select tech.id, req.id, data.prerequisite_group
from (
  values
    ('maquinaria-belica', 'fundacion-planetaria', 1),
    ('criadero-guerra', 'fundacion-planetaria', 1),
    ('asamblea-planetaria', 'maquinaria-belica', 1),
    ('asamblea-planetaria', 'criadero-guerra', 1),
    ('procesado-metalurgico', 'fundacion-planetaria', 1),
    ('cristalizacion-combustible-cuantico', 'procesado-metalurgico', 1),
    ('extraccion-subterranea', 'procesado-metalurgico', 1),
    ('monumentos-gloria', 'procesado-metalurgico', 1),
    ('fiebre-oro', 'cristalizacion-combustible-cuantico', 1),
    ('fiebre-oro', 'extraccion-subterranea', 2),
    ('fiebre-oro', 'monumentos-gloria', 3),
    ('pactos-mercantiles', 'fiebre-oro', 1),
    ('contactos-economicos', 'pactos-mercantiles', 1),
    ('tratos-preferentes', 'contactos-economicos', 1),
    ('mercado-galactico', 'pactos-mercantiles', 1),
    ('aranceles-privilegiados', 'mercado-galactico', 1),
    ('celulas-informacion', 'oficina-inteligencia', 1),
    ('doctrina-clandestina', 'celulas-informacion', 1),
    ('doble-agente', 'celulas-informacion', 1),
    ('tecnologia-sar', 'celulas-informacion', 1),
    ('logistica-frente', 'entrenamiento-linea', 1),
    ('cadenas-mando', 'entrenamiento-linea', 1),
    ('veteranos-guerra', 'entrenamiento-linea', 1),
    ('especializacion-elite', 'veteranos-guerra', 1),
    ('motores-guerra', 'maquinaria-belica', 1),
    ('blindaje-reforzado', 'motores-guerra', 1),
    ('matrices-eficiencia', 'procesado-metalurgico', 1)
) as data(technology_slug, required_slug, prerequisite_group)
join public.technology_nodes tech on tech.slug = data.technology_slug
join public.technology_nodes req on req.slug = data.required_slug
on conflict (technology_node_id, required_node_id) do update
set prerequisite_group = excluded.prerequisite_group;

delete from public.technology_effects
where technology_node_id in (
  select id
  from public.technology_nodes
  where tree_key = 'common-v1'
)
and effect_type in (
  'unlock_building_template',
  'unlock_building',
  'unlock_merchant_trade',
  'merchant_rate_modifier',
  'unlock_stellar_trade',
  'stellar_trade_fee_discount'
);

insert into public.technology_effects (id, technology_node_id, effect_type, payload)
select public.seed_uuid('technology_effect', data.effect_slug), nodes.id, data.effect_type, data.payload::jsonb
from (
  values
    ('fundacion-planetaria-buildings', 'fundacion-planetaria', 'unlock_building_template', '{"building_template_slugs":["barracon-infanteria","granja-biologica"]}'),
    ('maquinaria-belica-building', 'maquinaria-belica', 'unlock_building_template', '{"building_template_slugs":["taller-guerra"]}'),
    ('criadero-guerra-building', 'criadero-guerra', 'unlock_building_template', '{"building_template_slugs":["nido-bestias"]}'),
    ('asamblea-planetaria-building', 'asamblea-planetaria', 'unlock_building_template', '{"building_template_slugs":["cuartel-mando"]}'),
    ('procesado-metalurgico-building', 'procesado-metalurgico', 'unlock_building_template', '{"building_template_slugs":["planta-fundicion"]}'),
    ('cristalizacion-building', 'cristalizacion-combustible-cuantico', 'unlock_building_template', '{"building_template_slugs":["refineria-iridium"]}'),
    ('extraccion-building', 'extraccion-subterranea', 'unlock_building_template', '{"building_template_slugs":["complejo-minero"]}'),
    ('monumentos-building', 'monumentos-gloria', 'unlock_building_template', '{"building_template_slugs":["monumento"]}'),
    ('fiebre-oro-building', 'fiebre-oro', 'unlock_building_template', '{"building_template_slugs":["mina-oro"]}'),
    ('pactos-building', 'pactos-mercantiles', 'unlock_building_template', '{"building_template_slugs":["camara-comercio"]}'),
    ('contactos-merchant', 'contactos-economicos', 'unlock_merchant_trade', '{}'),
    ('tratos-merchant-rates', 'tratos-preferentes', 'merchant_rate_modifier', '{"buy_multiplier":1.5,"sell_multiplier":0.75}'),
    ('mercado-stellar', 'mercado-galactico', 'unlock_stellar_trade', '{}'),
    ('aranceles-fee', 'aranceles-privilegiados', 'stellar_trade_fee_discount', '{"percent":10,"minimum_gold":1}')
) as data(effect_slug, technology_slug, effect_type, payload)
join public.technology_nodes nodes on nodes.slug = data.technology_slug
on conflict (id) do update
set technology_node_id = excluded.technology_node_id, effect_type = excluded.effect_type, payload = excluded.payload;

do $$
declare
  v_senado_id uuid;
  v_monumento_id uuid;
begin
  select id into v_senado_id from public.building_templates where slug = 'senado';
  select id into v_monumento_id from public.building_templates where slug = 'monumento';

  if v_senado_id is not null and v_monumento_id is null then
    update public.building_templates
    set slug = 'monumento'
    where id = v_senado_id;
  elsif v_senado_id is not null and v_monumento_id is not null and v_senado_id <> v_monumento_id then
    delete from public.system_buildings old_building
    using public.system_buildings kept_building
    where old_building.building_template_id = v_senado_id
      and kept_building.system_id = old_building.system_id
      and kept_building.building_template_id = v_monumento_id;

    update public.system_buildings
    set building_template_id = v_monumento_id
    where building_template_id = v_senado_id;

    delete from public.building_templates
    where id = v_senado_id;
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
values
  (coalesce((select id from public.building_templates where slug = 'barracon-infanteria'), public.seed_uuid('building_template', 'barracon-infanteria')), 'barracon-infanteria', 'Barracon de Infanteria', 'Centro de instruccion para tropas de linea y cuadros veteranos.', 'Reclutamiento', 'recruitment', 12, 8, 0, 0, 4, 0, 0, 240, null, 0, array['Infanteria','Infantería','Elite','Élite']::text[], public.seed_uuid('technology_node', 'fundacion-planetaria'), 'infantry_barracks', true),
  (coalesce((select id from public.building_templates where slug = 'cuartel-mando'), public.seed_uuid('building_template', 'cuartel-mando')), 'cuartel-mando', 'Cuartel de Mando', 'Instalacion de oficiales, heroes y personajes de mando.', 'Reclutamiento', 'recruitment', 10, 10, 1, 0, 6, 0, 0, 300, null, 0, array['Personaje','Character','Characters']::text[], public.seed_uuid('technology_node', 'asamblea-planetaria'), 'command_quarters', true),
  (coalesce((select id from public.building_templates where slug = 'taller-guerra'), public.seed_uuid('building_template', 'taller-guerra')), 'taller-guerra', 'Taller de Guerra', 'Bahias de reparacion y ensamblaje de vehiculos.', 'Reclutamiento', 'recruitment', 6, 16, 0, 0, 8, 0, 0, 300, null, 0, array['Vehiculo','Vehículo']::text[], public.seed_uuid('technology_node', 'maquinaria-belica'), 'war_workshop', true),
  (coalesce((select id from public.building_templates where slug = 'nido-bestias'), public.seed_uuid('building_template', 'nido-bestias')), 'nido-bestias', 'Nido de Bestias', 'Jaulas y rituales de control para monstruos de guerra.', 'Reclutamiento', 'recruitment', 14, 8, 1, 0, 6, 0, 0, 300, null, 0, array['Monstruo','Monster','Monsters']::text[], public.seed_uuid('technology_node', 'criadero-guerra'), 'beast_lair', true),
  (coalesce((select id from public.building_templates where slug = 'camara-comercio'), public.seed_uuid('building_template', 'camara-comercio')), 'camara-comercio', 'Camara de Comercio', 'Mercado orbital y punto de contacto con rutas mercantes.', 'Comercio', 'commerce', 8, 8, 0, 1, 4, 0, 0, 240, null, 0, array[]::text[], public.seed_uuid('technology_node', 'pactos-mercantiles'), 'commerce', true),
  (coalesce((select id from public.building_templates where slug = 'nexo-inteligencia'), public.seed_uuid('building_template', 'nexo-inteligencia')), 'nexo-inteligencia', 'Nexo de Inteligencia', 'Centro de analisis para operaciones de espionaje futuras.', 'Inteligencia', 'intelligence', 6, 12, 1, 0, 6, 0, 0, 300, null, 0, array[]::text[], public.seed_uuid('technology_node', 'oficina-inteligencia'), 'intelligence', true),
  (coalesce((select id from public.building_templates where slug = 'antenas-reconocimiento'), public.seed_uuid('building_template', 'antenas-reconocimiento')), 'antenas-reconocimiento', 'Antenas de Reconocimiento', 'Matrices de escucha y auspex de largo alcance.', 'Inteligencia', 'intelligence', 4, 8, 0, 0, 5, 2, 0, 240, null, 0, array[]::text[], public.seed_uuid('technology_node', 'celulas-informacion'), 'recon', true),
  (coalesce((select id from public.building_templates where slug = 'granja-biologica'), public.seed_uuid('building_template', 'granja-biologica')), 'granja-biologica', 'Granja Biologica', 'Complejos de biomasa y cultivos adaptados al frente.', 'Produccion', 'production', 4, 4, 0, 0, 3, 0, 0, 180, 'supply', 10, array[]::text[], public.seed_uuid('technology_node', 'fundacion-planetaria'), 'biofarm', true),
  (coalesce((select id from public.building_templates where slug = 'complejo-minero'), public.seed_uuid('building_template', 'complejo-minero')), 'complejo-minero', 'Complejo Minero', 'Pozos, excavadoras y refinerias de mineral bruto.', 'Produccion', 'production', 4, 6, 0, 0, 4, 0, 0, 180, 'minerals', 6, array[]::text[], public.seed_uuid('technology_node', 'extraccion-subterranea'), 'mine', true),
  (coalesce((select id from public.building_templates where slug = 'refineria-iridium'), public.seed_uuid('building_template', 'refineria-iridium')), 'refineria-iridium', 'Refineria de Iridium', 'Planta especializada para estabilizar cristales de salto.', 'Produccion', 'production', 4, 8, 0, 0, 5, 0, 0, 240, 'uridium', 4, array[]::text[], public.seed_uuid('technology_node', 'cristalizacion-combustible-cuantico'), 'iridium_refinery', true),
  (coalesce((select id from public.building_templates where slug = 'mina-oro'), public.seed_uuid('building_template', 'mina-oro')), 'mina-oro', 'Mina de Oro', 'Extraccion de metales preciosos para rutas comerciales.', 'Produccion', 'production', 4, 8, 0, 0, 5, 0, 0, 240, 'gold', 3, array[]::text[], public.seed_uuid('technology_node', 'fiebre-oro'), 'gold_mine', true),
  (coalesce((select id from public.building_templates where slug = 'planta-fundicion'), public.seed_uuid('building_template', 'planta-fundicion')), 'planta-fundicion', 'Planta de Fundicion', 'Produce Material Industrial para nuevas construcciones.', 'Produccion', 'production', 4, 10, 0, 0, 3, 0, 0, 240, 'industrial_material', 5, array[]::text[], public.seed_uuid('technology_node', 'procesado-metalurgico'), 'foundry', true),
  (coalesce((select id from public.building_templates where slug = 'monumento'), public.seed_uuid('building_template', 'monumento')), 'monumento', 'Monumento', 'Estructura ceremonial que transforma gloria local en Honor.', 'Produccion', 'production', 8, 8, 0, 1, 5, 0, 0, 300, 'honor', 2, array[]::text[], public.seed_uuid('technology_node', 'monumentos-gloria'), 'monument', true)
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
  produced_resource_key = excluded.produced_resource_key,
  produced_amount = excluded.produced_amount,
  allowed_unit_categories = excluded.allowed_unit_categories,
  required_technology_node_id = excluded.required_technology_node_id,
  icon_key = excluded.icon_key,
  is_available = excluded.is_available,
  updated_at = now();

update public.system_buildings
set building_template_id = (select id from public.building_templates where slug = 'monumento')
where building_template_id in (select id from public.building_templates where slug = 'senado')
  and exists (select 1 from public.building_templates where slug = 'monumento');

delete from public.building_templates
where slug in ('senado', 'nodo-logistico', 'bastion-mando', 'manufactorum-local');

delete from public.faction_technologies progress
using public.technology_nodes nodes
where progress.technology_node_id = nodes.id
  and nodes.tree_key = 'common-v1'
  and (progress.status = 'available' or nodes.implementation_status in ('deprecated', 'planned'));

insert into public.faction_technologies (faction_id, technology_node_id, status, unlocked_at)
select factions.id, nodes.id, 'unlocked', now()
from public.factions
cross join public.technology_nodes nodes
where nodes.slug in ('fundacion-planetaria', 'entrenamiento-linea')
on conflict (faction_id, technology_node_id) do update
set status = excluded.status, unlocked_at = excluded.unlocked_at, started_at = null, finishes_at = null, updated_at = now();

create or replace function public.refresh_available_technologies(target_faction_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer := 0;
begin
  insert into public.faction_technologies (
    faction_id,
    technology_node_id,
    status
  )
  select
    target_faction_id,
    technology_nodes.id,
    'available'
  from public.technology_nodes
  where not technology_nodes.is_starter
    and technology_nodes.implementation_status = 'active'
    and not exists (
      select 1
      from public.faction_technologies existing
      where existing.faction_id = target_faction_id
        and existing.technology_node_id = technology_nodes.id
    )
    and public.are_technology_prerequisites_met(target_faction_id, technology_nodes.id);

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

create or replace function public.start_technology_research(technology_node_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_node public.technology_nodes%rowtype;
  v_resources public.faction_resources%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  perform public.resolve_technology_research();

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  select *
  into v_node
  from public.technology_nodes
  where id = start_technology_research.technology_node_id;

  if not found then
    raise exception 'Tecnologia no encontrada';
  end if;

  if v_node.implementation_status = 'planned' then
    raise exception 'Esta rama esta bloqueada hasta implementar espionaje';
  end if;

  if v_node.implementation_status <> 'active' then
    raise exception 'Esta tecnologia no esta disponible';
  end if;

  if exists (
    select 1
    from public.faction_technologies progress
    where progress.faction_id = v_faction_id
      and progress.status = 'researching'
  ) then
    raise exception 'Ya hay una investigacion activa';
  end if;

  if exists (
    select 1
    from public.faction_technologies progress
    where progress.faction_id = v_faction_id
      and progress.technology_node_id = v_node.id
      and progress.status in ('researching', 'unlocked')
  ) then
    raise exception 'Esta tecnologia ya esta en progreso o desbloqueada';
  end if;

  if v_node.is_starter then
    raise exception 'La tecnologia inicial ya esta desbloqueada';
  end if;

  if not public.are_technology_prerequisites_met(v_faction_id, v_node.id) then
    raise exception 'Faltan tecnologias requeridas';
  end if;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found or v_resources.technology < v_node.cost_technology then
    raise exception 'Componentes tecnologicos insuficientes';
  end if;

  update public.faction_resources
  set
    technology = technology - v_node.cost_technology,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.faction_technologies (
    faction_id,
    technology_node_id,
    status,
    started_at,
    finishes_at
  )
  values (
    v_faction_id,
    v_node.id,
    'researching',
    now(),
    now() + make_interval(secs => v_node.research_time_seconds)
  )
  on conflict on constraint faction_technologies_pkey do update
  set
    status = 'researching',
    started_at = excluded.started_at,
    finishes_at = excluded.finishes_at,
    updated_at = now();

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'technology_research_started',
    jsonb_build_object(
      'technology_node_id', v_node.id,
      'technology_name', v_node.name,
      'cost_technology', v_node.cost_technology,
      'finishes_at', now() + make_interval(secs => v_node.research_time_seconds)
    )
  );

  return v_node.id;
end;
$$;

do $$
declare
  v_faction_id uuid;
begin
  for v_faction_id in select id from public.factions loop
    perform public.refresh_available_technologies(v_faction_id);
  end loop;
end;
$$;

create or replace function public.has_active_commerce_building(target_faction_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.systems
    join public.system_buildings on system_buildings.system_id = systems.id
    join public.building_templates on building_templates.id = system_buildings.building_template_id
    where systems.controller_faction_id = target_faction_id
      and systems.status = 'controlled'
      and system_buildings.status = 'active'
      and building_templates.slug = 'camara-comercio'
  );
$$;

create or replace function public.has_unlocked_technology_effect(target_faction_id uuid, target_effect_type text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.technology_effects effects
    join public.faction_technologies progress
      on progress.technology_node_id = effects.technology_node_id
     and progress.faction_id = target_faction_id
     and progress.status = 'unlocked'
    where effects.effect_type = target_effect_type
  );
$$;

create or replace function public.get_merchant_buy_multiplier(target_faction_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    min(nullif((effects.payload->>'buy_multiplier')::numeric, 0)),
    2
  )
  from public.technology_effects effects
  join public.faction_technologies progress
    on progress.technology_node_id = effects.technology_node_id
   and progress.faction_id = target_faction_id
   and progress.status = 'unlocked'
  where effects.effect_type = 'merchant_rate_modifier';
$$;

create or replace function public.get_merchant_sell_multiplier(target_faction_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    max(nullif((effects.payload->>'sell_multiplier')::numeric, 0)),
    0.5
  )
  from public.technology_effects effects
  join public.faction_technologies progress
    on progress.technology_node_id = effects.technology_node_id
   and progress.faction_id = target_faction_id
   and progress.status = 'unlocked'
  where effects.effect_type = 'merchant_rate_modifier';
$$;

create or replace function public.get_stellar_trade_fee_percent(target_faction_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    min(nullif((effects.payload->>'percent')::numeric, 0)),
    30
  )
  from public.technology_effects effects
  join public.faction_technologies progress
    on progress.technology_node_id = effects.technology_node_id
   and progress.faction_id = target_faction_id
   and progress.status = 'unlocked'
  where effects.effect_type = 'stellar_trade_fee_discount';
$$;

create or replace function public.get_stellar_trade_fee_gold(target_faction_id uuid, gold_amount integer)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case
    when gold_amount is null or gold_amount <= 0 then 0
    else greatest(1, ceil((gold_amount::numeric * public.get_stellar_trade_fee_percent(target_faction_id)) / 100)::integer)
  end;
$$;

create or replace function public.merchant_trade(resource_key text, direction text, trade_quantity integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_resource_key text := public.normalize_trade_resource_key(resource_key);
  v_points integer;
  v_resources public.faction_resources%rowtype;
  v_gold_delta integer := 0;
  v_resource_delta integer := 0;
  v_price_gold integer;
  v_payout_gold integer;
  v_current_resource integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if v_resource_key is null then
    raise exception 'Recurso no comerciable';
  end if;

  if direction not in ('buy', 'sell') then
    raise exception 'Direccion de comercio invalida';
  end if;

  if trade_quantity is null or trade_quantity < 1 then
    raise exception 'Cantidad invalida';
  end if;

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  if not public.has_active_commerce_building(v_faction_id) then
    raise exception 'Necesitas una Camara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_faction_id, 'unlock_merchant_trade') then
    raise exception 'Necesitas investigar Contactos Economicos para comerciar con el Mercader';
  end if;

  v_points := public.trade_resource_points(v_resource_key);
  v_price_gold := ceil((v_points::numeric * trade_quantity * public.get_merchant_buy_multiplier(v_faction_id)) / 5)::integer;
  v_payout_gold := ceil((v_points::numeric * trade_quantity * public.get_merchant_sell_multiplier(v_faction_id)) / 5)::integer;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
  end if;

  v_current_resource := case v_resource_key
    when 'supply' then v_resources.supply
    when 'minerals' then v_resources.minerals
    when 'industrial_material' then v_resources.industrial_material
    when 'uridium' then v_resources.uridium
    else 0
  end;

  if direction = 'buy' then
    if v_resources.gold < v_price_gold then
      raise exception 'Oro insuficiente';
    end if;

    v_gold_delta := -v_price_gold;
    v_resource_delta := trade_quantity;
  else
    if v_current_resource < trade_quantity then
      raise exception 'Recurso insuficiente';
    end if;

    v_gold_delta := v_payout_gold;
    v_resource_delta := -trade_quantity;
  end if;

  update public.faction_resources
  set
    supply = supply + case when v_resource_key = 'supply' then v_resource_delta else 0 end,
    minerals = minerals + case when v_resource_key = 'minerals' then v_resource_delta else 0 end,
    industrial_material = industrial_material + case when v_resource_key = 'industrial_material' then v_resource_delta else 0 end,
    uridium = uridium + case when v_resource_key = 'uridium' then v_resource_delta else 0 end,
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

create or replace function public.create_trade_offer(
  offer_type text,
  resource_key text,
  resource_amount integer,
  gold_amount integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_resource_key text := public.normalize_trade_resource_key(resource_key);
  v_resources public.faction_resources%rowtype;
  v_fee_gold integer;
  v_current_resource integer;
  v_offer_id uuid;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if offer_type not in ('buy', 'sell') then
    raise exception 'Tipo de oferta invalido';
  end if;

  if v_resource_key is null then
    raise exception 'Recurso no comerciable';
  end if;

  if resource_amount is null or resource_amount < 1 or gold_amount is null or gold_amount < 1 then
    raise exception 'Oferta invalida';
  end if;

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  if not public.has_active_commerce_building(v_faction_id) then
    raise exception 'Necesitas una Camara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_faction_id, 'unlock_stellar_trade') then
    raise exception 'Necesitas investigar Mercado Galactico para publicar ofertas';
  end if;

  v_fee_gold := public.get_stellar_trade_fee_gold(v_faction_id, gold_amount);

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
  end if;

  v_current_resource := case v_resource_key
    when 'supply' then v_resources.supply
    when 'minerals' then v_resources.minerals
    when 'industrial_material' then v_resources.industrial_material
    when 'uridium' then v_resources.uridium
    else 0
  end;

  if offer_type = 'buy' then
    if v_resources.gold < gold_amount + v_fee_gold then
      raise exception 'Oro insuficiente para publicar esta compra';
    end if;

    update public.faction_resources
    set gold = gold - (gold_amount + v_fee_gold), updated_at = now()
    where faction_id = v_faction_id;
  else
    if v_current_resource < resource_amount or v_resources.gold < v_fee_gold then
      raise exception 'Recursos insuficientes para publicar esta venta';
    end if;

    update public.faction_resources
    set
      supply = supply - case when v_resource_key = 'supply' then resource_amount else 0 end,
      minerals = minerals - case when v_resource_key = 'minerals' then resource_amount else 0 end,
      industrial_material = industrial_material - case when v_resource_key = 'industrial_material' then resource_amount else 0 end,
      uridium = uridium - case when v_resource_key = 'uridium' then resource_amount else 0 end,
      gold = gold - v_fee_gold,
      updated_at = now()
    where faction_id = v_faction_id;
  end if;

  insert into public.trade_offers (
    creator_faction_id,
    offer_type,
    resource_key,
    resource_amount,
    gold_amount,
    fee_gold,
    status,
    is_reserved
  )
  values (
    v_faction_id,
    offer_type,
    v_resource_key,
    resource_amount,
    gold_amount,
    v_fee_gold,
    'open',
    true
  )
  returning id into v_offer_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'trade_offer_created',
    jsonb_build_object(
      'trade_offer_id', v_offer_id,
      'offer_type', offer_type,
      'resource_key', v_resource_key,
      'resource_amount', resource_amount,
      'gold_amount', gold_amount,
      'fee_gold', v_fee_gold,
      'reserved', true
    )
  );

  return v_offer_id;
end;
$$;

create or replace function public.accept_trade_offer(offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_acceptor_faction_id uuid;
  v_offer public.trade_offers%rowtype;
  v_resource_key text;
  v_acceptor_resources public.faction_resources%rowtype;
  v_acceptor_current_resource integer;
  v_acceptor_fee_gold integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select player_factions.faction_id
  into v_acceptor_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_acceptor_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  if not public.has_active_commerce_building(v_acceptor_faction_id) then
    raise exception 'Necesitas una Camara de Comercio activa';
  end if;

  if not public.has_unlocked_technology_effect(v_acceptor_faction_id, 'unlock_stellar_trade') then
    raise exception 'Necesitas investigar Mercado Galactico para aceptar ofertas';
  end if;

  select *
  into v_offer
  from public.trade_offers
  where id = accept_trade_offer.offer_id
    and status = 'open'
  for update;

  if not found then
    raise exception 'Oferta no disponible';
  end if;

  v_resource_key := public.normalize_trade_resource_key(v_offer.resource_key);

  if v_resource_key is null then
    raise exception 'Oferta con recurso no comerciable';
  end if;

  if not v_offer.is_reserved then
    raise exception 'Oferta antigua sin reserva; debe cancelarse y crearse de nuevo';
  end if;

  if v_offer.creator_faction_id = v_acceptor_faction_id then
    raise exception 'No puedes aceptar tu propia oferta';
  end if;

  v_acceptor_fee_gold := public.get_stellar_trade_fee_gold(v_acceptor_faction_id, v_offer.gold_amount);

  select *
  into v_acceptor_resources
  from public.faction_resources
  where faction_id = v_acceptor_faction_id
  for update;

  if not found then
    raise exception 'Faltan recursos inicializados';
  end if;

  v_acceptor_current_resource := case v_resource_key
    when 'supply' then v_acceptor_resources.supply
    when 'minerals' then v_acceptor_resources.minerals
    when 'industrial_material' then v_acceptor_resources.industrial_material
    when 'uridium' then v_acceptor_resources.uridium
    else 0
  end;

  if v_offer.offer_type = 'buy' then
    if v_acceptor_current_resource < v_offer.resource_amount or v_acceptor_resources.gold < v_acceptor_fee_gold then
      raise exception 'No tienes recursos u oro suficiente para aceptar esta venta';
    end if;

    update public.faction_resources
    set
      supply = supply + case when v_resource_key = 'supply' then v_offer.resource_amount else 0 end,
      minerals = minerals + case when v_resource_key = 'minerals' then v_offer.resource_amount else 0 end,
      industrial_material = industrial_material + case when v_resource_key = 'industrial_material' then v_offer.resource_amount else 0 end,
      uridium = uridium + case when v_resource_key = 'uridium' then v_offer.resource_amount else 0 end,
      updated_at = now()
    where faction_id = v_offer.creator_faction_id;

    update public.faction_resources
    set
      supply = supply - case when v_resource_key = 'supply' then v_offer.resource_amount else 0 end,
      minerals = minerals - case when v_resource_key = 'minerals' then v_offer.resource_amount else 0 end,
      industrial_material = industrial_material - case when v_resource_key = 'industrial_material' then v_offer.resource_amount else 0 end,
      uridium = uridium - case when v_resource_key = 'uridium' then v_offer.resource_amount else 0 end,
      gold = gold + v_offer.gold_amount - v_acceptor_fee_gold,
      updated_at = now()
    where faction_id = v_acceptor_faction_id;
  else
    if v_acceptor_resources.gold < v_offer.gold_amount + v_acceptor_fee_gold then
      raise exception 'Oro insuficiente para aceptar esta compra';
    end if;

    update public.faction_resources
    set
      gold = gold + v_offer.gold_amount,
      updated_at = now()
    where faction_id = v_offer.creator_faction_id;

    update public.faction_resources
    set
      supply = supply + case when v_resource_key = 'supply' then v_offer.resource_amount else 0 end,
      minerals = minerals + case when v_resource_key = 'minerals' then v_offer.resource_amount else 0 end,
      industrial_material = industrial_material + case when v_resource_key = 'industrial_material' then v_offer.resource_amount else 0 end,
      uridium = uridium + case when v_resource_key = 'uridium' then v_offer.resource_amount else 0 end,
      gold = gold - (v_offer.gold_amount + v_acceptor_fee_gold),
      updated_at = now()
    where faction_id = v_acceptor_faction_id;
  end if;

  update public.trade_offers
  set
    resource_key = v_resource_key,
    status = 'accepted',
    accepted_by_faction_id = v_acceptor_faction_id,
    accepted_at = now(),
    updated_at = now()
  where id = v_offer.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_acceptor_faction_id,
    'trade_offer_accepted',
    jsonb_build_object(
      'trade_offer_id', v_offer.id,
      'creator_faction_id', v_offer.creator_faction_id,
      'acceptor_faction_id', v_acceptor_faction_id,
      'offer_type', v_offer.offer_type,
      'resource_key', v_resource_key,
      'resource_amount', v_offer.resource_amount,
      'gold_amount', v_offer.gold_amount,
      'creator_fee_gold', v_offer.fee_gold,
      'acceptor_fee_gold', v_acceptor_fee_gold
    )
  );

  return v_offer.id;
end;
$$;

revoke execute on function public.are_technology_prerequisites_met(uuid, uuid) from public;
revoke execute on function public.has_active_commerce_building(uuid) from public;
revoke execute on function public.has_unlocked_technology_effect(uuid, text) from public;
revoke execute on function public.get_merchant_buy_multiplier(uuid) from public;
revoke execute on function public.get_merchant_sell_multiplier(uuid) from public;
revoke execute on function public.get_stellar_trade_fee_percent(uuid) from public;
revoke execute on function public.get_stellar_trade_fee_gold(uuid, integer) from public;
revoke execute on function public.refresh_available_technologies(uuid) from public;
revoke execute on function public.start_technology_research(uuid) from public;

grant execute on function public.start_technology_research(uuid) to authenticated;
grant execute on function public.merchant_trade(text, text, integer) to authenticated;
grant execute on function public.create_trade_offer(text, text, integer, integer) to authenticated;
grant execute on function public.accept_trade_offer(uuid) to authenticated;

select public.refresh_system_production_from_buildings();
