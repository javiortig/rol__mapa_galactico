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
values (
  public.seed_uuid('technology_node', 'custodia-reliquias'),
  'custodia-reliquias',
  'common-v1',
  'Custodia de Reliquias',
  'Protocolos de sellado, inventario y escolta para custodiar artefactos sagrados de campana.',
  'Progreso',
  3,
  86,
  72,
  1,
  case
    when (select timing_mode from public.campaign_settings where id = 'default') = 'test' then 3
    else 7200
  end,
  'relic_sanctuary',
  'Desbloquea Santuario de Reliquias.',
  false,
  'active'
)
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
  description = 'Arquitectura ceremonial para convertir victorias y lealtad en Honor.',
  effect_summary = 'Desbloquea Monumento.',
  updated_at = now()
where slug = 'monumentos-gloria'
  and tree_key = 'common-v1';

insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
select
  technology.id,
  required.id,
  1
from public.technology_nodes technology
join public.technology_nodes required
  on required.slug = 'monumentos-gloria'
where technology.slug = 'custodia-reliquias'
on conflict (technology_node_id, required_node_id) do update
set prerequisite_group = excluded.prerequisite_group;

delete from public.technology_effects effects
using public.technology_nodes nodes
where effects.technology_node_id = nodes.id
  and nodes.slug = 'monumentos-gloria'
  and effects.effect_type = 'unlock_building_template'
  and effects.payload -> 'building_template_slugs' ? 'santuario-reliquias';

insert into public.technology_effects (id, technology_node_id, effect_type, payload)
select
  public.seed_uuid('technology_effect', 'custodia-relic-sanctuary'),
  nodes.id,
  'unlock_building_template',
  '{"building_template_slugs":["santuario-reliquias"]}'::jsonb
from public.technology_nodes nodes
where nodes.slug = 'custodia-reliquias'
on conflict (id) do update
set
  technology_node_id = excluded.technology_node_id,
  effect_type = excluded.effect_type,
  payload = excluded.payload;

update public.building_templates
set
  required_technology_node_id = (select id from public.technology_nodes where slug = 'custodia-reliquias'),
  updated_at = now()
where slug = 'santuario-reliquias';

insert into public.campaign_logs (action_type, payload)
values (
  'relic_sanctuary_unlock_moved',
  jsonb_build_object(
    'from_technology_slug', 'monumentos-gloria',
    'to_technology_slug', 'custodia-reliquias',
    'building_template_slug', 'santuario-reliquias'
  )
);
