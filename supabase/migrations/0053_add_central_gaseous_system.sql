create or replace function public.seed_uuid(prefix text, slug text)
returns uuid
language plpgsql
immutable
as $$
declare
  hash text := md5(prefix || ':' || slug);
begin
  return (
    substr(hash, 1, 8) || '-' ||
    substr(hash, 9, 4) || '-' ||
    substr(hash, 13, 4) || '-' ||
    substr(hash, 17, 4) || '-' ||
    substr(hash, 21, 12)
  )::uuid;
end;
$$;

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
  allows_shared_occupation,
  is_temporary_mission,
  mission_threat_faction_id,
  mission_enemy_units_visible,
  mission_enemy_units,
  mission_expires_at,
  mission_expires_after_battle,
  temporary_mission_status,
  temporary_mission_closed_at
)
values (
  public.seed_uuid('system', 'maelstrom-gas'),
  'maelstrom-gas',
  'Maelstrom Gas',
  560,
  485,
  1.08,
  'violet',
  'Anomalia gaseosa central',
  'neutral',
  null,
  null,
  'Una nube de plasma y gases ionizados abre un paso peligroso entre los dos nodos centrales.',
  false,
  0,
  'gaseous',
  false,
  true,
  false,
  null,
  false,
  '[]'::jsonb,
  null,
  false,
  'active',
  null
)
on conflict (slug) do update
set
  name = excluded.name,
  x = excluded.x,
  y = excluded.y,
  size = excluded.size,
  star_class = excluded.star_class,
  type = excluded.type,
  status = 'neutral',
  controller_faction_id = null,
  blocked_until = null,
  public_description = excluded.public_description,
  is_capital = false,
  building_slots = 0,
  system_kind = 'gaseous',
  is_conquerable = false,
  allows_shared_occupation = true,
  is_temporary_mission = false,
  mission_threat_faction_id = null,
  mission_enemy_units_visible = false,
  mission_enemy_units = '[]'::jsonb,
  mission_expires_at = null,
  mission_expires_after_battle = false,
  temporary_mission_status = 'active',
  temporary_mission_closed_at = null,
  updated_at = now();

delete from public.system_buildings
where system_id = public.seed_uuid('system', 'maelstrom-gas');

delete from public.system_resource_capabilities
where system_id = public.seed_uuid('system', 'maelstrom-gas');

delete from public.system_production
where system_id = public.seed_uuid('system', 'maelstrom-gas');

insert into public.system_edges (id, slug, from_system_id, to_system_id, uridium_cost, is_blocked)
values
  (public.seed_uuid('edge', 'route-27'), 'route-27', public.seed_uuid('system', 'nexus-aster'), public.seed_uuid('system', 'maelstrom-gas'), 1, false),
  (public.seed_uuid('edge', 'route-28'), 'route-28', public.seed_uuid('system', 'goregate'), public.seed_uuid('system', 'maelstrom-gas'), 1, false)
on conflict (slug) do update
set
  from_system_id = excluded.from_system_id,
  to_system_id = excluded.to_system_id,
  uridium_cost = excluded.uridium_cost,
  is_blocked = excluded.is_blocked;

insert into public.system_special_objects (id, system_id, name, type, public_description, is_public)
values (
  public.seed_uuid('system_special_object', 'obj-maelstrom-gas'),
  public.seed_uuid('system', 'maelstrom-gas'),
  'Marea ionizada',
  'anomaly',
  'Tormentas de plasma velan el centro del mapa y distorsionan todos los augurios cercanos.',
  true
)
on conflict (id) do update
set
  system_id = excluded.system_id,
  name = excluded.name,
  type = excluded.type,
  public_description = excluded.public_description,
  is_public = excluded.is_public;

select public.rebuild_system_resource_capabilities();
select public.refresh_system_production_from_buildings();

insert into public.campaign_logs (faction_id, action_type, payload)
values (
  null,
  'central_gaseous_system_added',
  jsonb_build_object(
    'system', 'maelstrom-gas',
    'connected_to', jsonb_build_array('nexus-aster', 'goregate'),
    'applied_at', now()
  )
);
