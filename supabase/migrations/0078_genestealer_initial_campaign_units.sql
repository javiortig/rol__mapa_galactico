-- Add the final initial campaign units for Genestealer Cults.

insert into public.campaign_units (
  id, slug, faction_id, unit_template_id, name, category, unit_type, unit_keywords,
  points, quantity, starting_quantity, wounds_taken, experience, rank,
  current_system_id, status, is_visible_publicly
)
select
  public.seed_uuid('campaign_unit', data.slug),
  data.slug,
  factions.id,
  unit_templates.id,
  unit_templates.name,
  unit_templates.category,
  unit_templates.unit_type,
  unit_templates.unit_keywords,
  data.points,
  data.quantity,
  data.starting_quantity,
  data.wounds_taken,
  data.experience,
  case
    when unit_templates.unit_keywords @> array['Caracter']::text[] then public.character_rank_for_level(data.experience)
    else null
  end,
  systems.id,
  'ready',
  false
from (
  values
    ('cult-neophyte-hybrids-damaged', 'cultos-genestealer', 'unit-cultos-genestealer-neophyte-hybrids', 'blackglass', 65, 7, 10, 0, 1),
    ('cult-abominant', 'cultos-genestealer', 'unit-cultos-genestealer-abominant', 'blackglass', 85, 1, 1, 0, 1),
    ('cult-aberrants', 'cultos-genestealer', 'unit-cultos-genestealer-aberrants', 'blackglass', 135, 5, 5, 0, 1)
) as data(slug, faction_slug, template_slug, system_slug, points, quantity, starting_quantity, wounds_taken, experience)
join public.factions on factions.slug = data.faction_slug
join public.unit_templates on unit_templates.slug = data.template_slug
join public.systems on systems.slug = data.system_slug
on conflict (slug) do update
set
  faction_id = excluded.faction_id,
  unit_template_id = excluded.unit_template_id,
  name = excluded.name,
  category = excluded.category,
  unit_type = excluded.unit_type,
  unit_keywords = excluded.unit_keywords,
  points = excluded.points,
  quantity = excluded.quantity,
  starting_quantity = excluded.starting_quantity,
  wounds_taken = excluded.wounds_taken,
  experience = excluded.experience,
  rank = excluded.rank,
  current_system_id = excluded.current_system_id,
  status = excluded.status,
  is_visible_publicly = excluded.is_visible_publicly,
  destroyed_at = null,
  updated_at = now();

insert into public.campaign_logs (action_type, payload)
values (
  'genestealer_initial_units_applied',
  jsonb_build_object(
    'system_slug', 'blackglass',
    'units', jsonb_build_array(
      jsonb_build_object('slug', 'cult-neophyte-hybrids-damaged', 'quantity', 7, 'starting_quantity', 10),
      jsonb_build_object('slug', 'cult-abominant', 'quantity', 1, 'starting_quantity', 1),
      jsonb_build_object('slug', 'cult-aberrants', 'quantity', 5, 'starting_quantity', 5)
    )
  )
);
