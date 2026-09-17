update public.technology_nodes
set cost_technology = 0
where tree_key = 'common-v1'
  and slug in ('contactos-economicos', 'mercado-galactico');

insert into public.campaign_logs (action_type, payload)
values (
  'economic_technology_costs_updated',
  jsonb_build_object(
    'technology_slugs', jsonb_build_array('contactos-economicos', 'mercado-galactico'),
    'cost_technology', 0
  )
);
