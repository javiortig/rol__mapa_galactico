-- Launch the real campaign state: campaign timers, clean board, final resources
-- and all starting units placed in each faction capital.

alter table public.campaign_settings
  alter column timing_mode set default 'campaign';

create or replace function public.apply_campaign_timing_mode(target_mode text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mode text := lower(trim(coalesce(target_mode, '')));
  v_resource_hours integer;
  v_movement_edge_seconds integer;
  v_attack_seconds integer;
  v_conflict_block_minutes integer;
begin
  if v_mode not in ('test', 'campaign') then
    raise exception 'Modo de tiempos no valido: %', target_mode;
  end if;

  if v_mode = 'test' then
    v_resource_hours := 1;
    v_movement_edge_seconds := 3;
    v_attack_seconds := 300;
    v_conflict_block_minutes := 60;

    update public.technology_nodes
    set research_time_seconds = 3,
        updated_at = now()
    where research_time_seconds <> 3;

    update public.unit_templates
    set recruitment_time_seconds = 3
    where recruitment_time_seconds <> 3;

    update public.building_templates
    set construction_time_seconds = 3,
        updated_at = now()
    where construction_time_seconds <> 3;
  else
    v_resource_hours := 24;
    v_movement_edge_seconds := 259200;
    v_attack_seconds := 604800;
    v_conflict_block_minutes := 20160;

    update public.technology_nodes
    set research_time_seconds = case
      when tree_key = 'common-v1' and branch = 'Progreso' and cost_technology <= 0 then 1800
      when tree_key = 'common-v1' and branch = 'Progreso' and cost_technology = 1 then 7200
      when tree_key = 'common-v1' and branch = 'Progreso' and cost_technology = 2 then 21600
      else greatest(86400, greatest(cost_technology, 1) * 86400)
    end,
        updated_at = now()
    where research_time_seconds is distinct from case
      when tree_key = 'common-v1' and branch = 'Progreso' and cost_technology <= 0 then 1800
      when tree_key = 'common-v1' and branch = 'Progreso' and cost_technology = 1 then 7200
      when tree_key = 'common-v1' and branch = 'Progreso' and cost_technology = 2 then 21600
      else greatest(86400, greatest(cost_technology, 1) * 86400)
    end;

    update public.unit_templates
    set recruitment_time_seconds = case
      when points <= 90 then 86400
      when points <= 180 then 172800
      when points <= 300 then 259200
      else 345600
    end
    where recruitment_time_seconds is distinct from case
      when points <= 90 then 86400
      when points <= 180 then 172800
      when points <= 300 then 259200
      else 345600
    end;

    update public.building_templates
    set construction_time_seconds = case
      when industrial_material_cost <= 20 then 86400
      when industrial_material_cost <= 34 then 172800
      else 259200
    end,
        updated_at = now()
    where construction_time_seconds is distinct from case
      when industrial_material_cost <= 20 then 86400
      when industrial_material_cost <= 34 then 172800
      else 259200
    end;
  end if;

  update public.campaign_settings
  set
    timing_mode = v_mode,
    timing_mode_updated_at = now(),
    resource_tick_interval_hours = v_resource_hours,
    movement_edge_duration_seconds = v_movement_edge_seconds,
    attack_duration_seconds = v_attack_seconds,
    conflict_block_duration_minutes = v_conflict_block_minutes,
    next_resource_tick_at = now() + make_interval(hours => v_resource_hours),
    updated_at = now()
  where id = 'default';

  update public.movement_orders
  set
    duration_seconds = case
      when movement_type = 'attack' then v_attack_seconds
      else v_movement_edge_seconds * greatest(coalesce(segment_count, cardinality(path_system_ids) - 1, 1), 1)
    end,
    arrival_at = case
      when status <> 'moving' then arrival_at
      when v_mode = 'test' then least(
        coalesce(arrival_at, now() + make_interval(secs =>
          case
            when movement_type = 'attack' then v_attack_seconds
            else v_movement_edge_seconds * greatest(coalesce(segment_count, cardinality(path_system_ids) - 1, 1), 1)
          end
        )),
        now() + make_interval(secs =>
          case
            when movement_type = 'attack' then v_attack_seconds
            else v_movement_edge_seconds * greatest(coalesce(segment_count, cardinality(path_system_ids) - 1, 1), 1)
          end
        )
      )
      else coalesce(started_at, now()) + make_interval(secs =>
        case
          when movement_type = 'attack' then v_attack_seconds
          else v_movement_edge_seconds * greatest(coalesce(segment_count, cardinality(path_system_ids) - 1, 1), 1)
        end
      )
    end,
    updated_at = now()
  where status in ('moving', 'pending_approval');

  update public.battle_operations
  set attack_arrival_at = movement_orders.arrival_at,
      updated_at = now()
  from public.movement_orders
  where battle_operations.attack_movement_order_id = movement_orders.id
    and battle_operations.status = 'moving'
    and movement_orders.status = 'moving'
    and battle_operations.attack_arrival_at is distinct from movement_orders.arrival_at;

  update public.recruitment_queue
  set
    finishes_at = case
      when v_mode = 'test' then least(finishes_at, now() + interval '3 seconds')
      else coalesce(recruitment_queue.started_at, now())
        + make_interval(secs => unit_templates.recruitment_time_seconds * greatest(recruitment_queue.quantity, 1))
    end,
    updated_at = now()
  from public.unit_templates
  where recruitment_queue.unit_template_id = unit_templates.id
    and recruitment_queue.status = 'queued';

  update public.unit_recovery_queue
  set
    finishes_at = case
      when v_mode = 'test' then least(unit_recovery_queue.finishes_at, now() + interval '3 seconds')
      else coalesce(unit_recovery_queue.started_at, now())
        + make_interval(secs => greatest(3, ceil(unit_templates.recruitment_time_seconds::numeric / 2)::integer))
    end,
    updated_at = now()
  from public.campaign_units
  join public.unit_templates on unit_templates.id = campaign_units.unit_template_id
  where unit_recovery_queue.campaign_unit_id = campaign_units.id
    and unit_recovery_queue.status = 'queued';

  update public.system_buildings
  set
    finishes_at = case
      when v_mode = 'test' then least(system_buildings.finishes_at, now() + interval '3 seconds')
      else coalesce(system_buildings.started_at, now()) + make_interval(secs => building_templates.construction_time_seconds)
    end,
    updated_at = now()
  from public.building_templates
  where system_buildings.building_template_id = building_templates.id
    and system_buildings.status = 'constructing'
    and system_buildings.finishes_at is not null;

  update public.faction_technologies
  set
    finishes_at = case
      when v_mode = 'test' then least(faction_technologies.finishes_at, now() + interval '3 seconds')
      else coalesce(faction_technologies.started_at, now()) + make_interval(secs => technology_nodes.research_time_seconds)
    end,
    updated_at = now()
  from public.technology_nodes
  where faction_technologies.technology_node_id = technology_nodes.id
    and faction_technologies.status = 'researching'
    and faction_technologies.finishes_at is not null;

  insert into public.campaign_logs (action_type, payload)
  values (
    'campaign_timing_mode_applied',
    jsonb_build_object(
      'timing_mode', v_mode,
      'resource_tick_interval_hours', v_resource_hours,
      'movement_edge_duration_seconds', v_movement_edge_seconds,
      'attack_duration_seconds', v_attack_seconds,
      'conflict_block_duration_minutes', v_conflict_block_minutes
    )
  );

  return v_mode;
end;
$$;

create or replace function public.admin_set_campaign_timing_mode(target_mode text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mode text := lower(trim(coalesce(target_mode, '')));
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Solo admin puede cambiar el modo de tiempos';
  end if;

  if v_mode <> 'campaign' then
    raise exception 'La campana real esta activa; solo se puede aplicar el perfil campaign';
  end if;

  v_mode := public.apply_campaign_timing_mode('campaign');

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    auth.uid(),
    'admin_campaign_timing_mode_updated',
    jsonb_build_object('timing_mode', v_mode)
  );

  return v_mode;
end;
$$;

revoke execute on function public.apply_campaign_timing_mode(text) from public;
revoke execute on function public.apply_campaign_timing_mode(text) from anon;
revoke execute on function public.apply_campaign_timing_mode(text) from authenticated;

revoke execute on function public.admin_set_campaign_timing_mode(text) from public;
revoke execute on function public.admin_set_campaign_timing_mode(text) from anon;
grant execute on function public.admin_set_campaign_timing_mode(text) to authenticated;

delete from public.battle_reports;
delete from public.narrative_attacks;
delete from public.missions;
delete from public.battle_unit_commitments;
delete from public.battle_operation_members;
delete from public.battle_operations;
delete from public.movement_passage_requests;
delete from public.movement_order_units;
delete from public.movement_orders;
delete from public.trade_offers;
delete from public.unit_recovery_queue;
delete from public.recruitment_queue;
delete from public.campaign_units;
delete from public.conflicts;
delete from public.system_buildings;

delete from public.systems
where coalesce(is_temporary_mission, false) = true;

update public.systems
set
  status = case when controller_faction_id is null then 'neutral' else 'controlled' end,
  blocked_until = null,
  updated_at = now()
where coalesce(is_temporary_mission, false) = false;

select public.refresh_system_production_from_buildings();

insert into public.faction_resources (
  faction_id,
  supply,
  minerals,
  ancestral_stone,
  honor,
  gold,
  industrial_material,
  uridium,
  technology
)
select
  factions.id,
  100,
  40,
  0,
  0,
  0,
  150,
  10,
  6
from public.factions
where factions.slug in (
  'legiones-daemonicas',
  'adeptus-custodes',
  'space-marines',
  'cultos-genestealer',
  'necrones'
)
on conflict (faction_id) do update
set
  supply = excluded.supply,
  minerals = excluded.minerals,
  ancestral_stone = excluded.ancestral_stone,
  honor = excluded.honor,
  gold = excluded.gold,
  industrial_material = excluded.industrial_material,
  uridium = excluded.uridium,
  technology = excluded.technology,
  updated_at = now();

delete from public.faction_technologies progress
using public.factions
where progress.faction_id = factions.id
  and factions.slug in (
    'legiones-daemonicas',
    'adeptus-custodes',
    'space-marines',
    'cultos-genestealer',
    'necrones'
  );

insert into public.faction_technologies (faction_id, technology_node_id, status, unlocked_at)
select factions.id, technology_nodes.id, 'unlocked', now()
from public.factions
cross join public.technology_nodes
where factions.slug in (
    'legiones-daemonicas',
    'adeptus-custodes',
    'space-marines',
    'cultos-genestealer',
    'necrones'
  )
  and technology_nodes.is_starter = true
  and coalesce(technology_nodes.implementation_status, 'active') = 'active'
on conflict (faction_id, technology_node_id) do update
set
  status = excluded.status,
  unlocked_at = excluded.unlocked_at,
  started_at = null,
  finishes_at = null,
  updated_at = now();

do $$
declare
  v_faction_id uuid;
begin
  for v_faction_id in
    select id
    from public.factions
    where slug in (
      'legiones-daemonicas',
      'adeptus-custodes',
      'space-marines',
      'cultos-genestealer',
      'necrones'
    )
  loop
    perform public.refresh_available_technologies(v_faction_id);
  end loop;
end;
$$;

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
    ('necron-plasmancer', 'necrones', 'unit-necrones-plasmancer', 'thokt-vault', 55, 1, 1, 0, 1),
    ('necron-immortals-damaged', 'necrones', 'unit-necrones-immortals', 'thokt-vault', 70, 4, 5, 0, 1),
    ('necron-warriors', 'necrones', 'unit-necrones-necron-warriors', 'thokt-vault', 90, 10, 10, 0, 1),
    ('necron-tomb-blades-damaged', 'necrones', 'unit-necrones-tomb-blades', 'thokt-vault', 75, 2, 3, 0, 1),
    ('daemon-flamers-damaged', 'legiones-daemonicas', 'unit-legiones-daemonicas-flamers', 'mordax', 65, 1, 3, 0, 1),
    ('daemon-burning-chariot', 'legiones-daemonicas', 'unit-legiones-daemonicas-burning-chariot', 'mordax', 115, 1, 1, 0, 1),
    ('daemon-pink-horrors-damaged', 'legiones-daemonicas', 'unit-legiones-daemonicas-pink-horrors', 'mordax', 140, 7, 10, 0, 1),
    ('cult-neophyte-hybrids-damaged', 'cultos-genestealer', 'unit-cultos-genestealer-neophyte-hybrids', 'blackglass', 65, 7, 10, 0, 1),
    ('cult-abominant', 'cultos-genestealer', 'unit-cultos-genestealer-abominant', 'blackglass', 85, 1, 1, 0, 1),
    ('cult-aberrants', 'cultos-genestealer', 'unit-cultos-genestealer-aberrants', 'blackglass', 135, 5, 5, 0, 1),
    ('sombra-intercessors-damaged', 'space-marines', 'unit-space-marines-intercessor-squad', 'sa-cea-gate', 80, 4, 5, 0, 1),
    ('sombra-intercessors-large-damaged', 'space-marines', 'unit-space-marines-intercessor-squad', 'sa-cea-gate', 150, 7, 10, 0, 1),
    ('sombra-lieutenant', 'space-marines', 'unit-space-marines-lieutenant', 'sa-cea-gate', 55, 1, 1, 0, 1),
    ('sombra-bladeguard-damaged', 'space-marines', 'unit-space-marines-bladeguard-veteran-squad', 'sa-cea-gate', 80, 1, 3, 0, 1),
    ('custodes-blade-champion', 'adeptus-custodes', 'unit-adeptus-custodes-blade-champion', 'kharon-prime', 120, 1, 1, 0, 1),
    ('custodes-guard-damaged', 'adeptus-custodes', 'unit-adeptus-custodes-custodian-guard', 'kharon-prime', 160, 3, 4, 0, 1),
    ('custodes-prosecutor-damaged', 'adeptus-custodes', 'unit-adeptus-custodes-prosecutors', 'kharon-prime', 40, 1, 4, 0, 1)
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

select public.apply_campaign_timing_mode('campaign');

insert into public.campaign_logs (action_type, payload)
values (
  'real_campaign_launch_state_applied',
  jsonb_build_object(
    'timing_mode', 'campaign',
    'attack_duration_seconds', 604800,
    'movement_edge_duration_seconds', 259200,
    'resource_tick_interval_hours', 24,
    'initial_units_count', 17,
    'starting_resources', jsonb_build_object(
      'supply', 100,
      'minerals', 40,
      'honor', 0,
      'gold', 0,
      'industrial_material', 150,
      'uridium', 10,
      'technology', 6
    )
  )
);
