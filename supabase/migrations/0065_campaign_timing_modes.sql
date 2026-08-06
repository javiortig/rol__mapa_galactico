alter table public.campaign_settings
  add column if not exists timing_mode text not null default 'test',
  add column if not exists timing_mode_updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'campaign_settings_timing_mode_check'
      and conrelid = 'public.campaign_settings'::regclass
  ) then
    alter table public.campaign_settings
      add constraint campaign_settings_timing_mode_check
      check (timing_mode in ('test', 'campaign'));
  end if;
end;
$$;

comment on column public.campaign_settings.timing_mode is
  'Perfil de tiempos de la campana: test usa duraciones cortas; campaign usa duraciones reales.';

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
    v_attack_seconds := 518400;
    v_conflict_block_minutes := 20160;

    update public.technology_nodes
    set research_time_seconds = greatest(86400, greatest(cost_technology, 1) * 86400),
        updated_at = now()
    where research_time_seconds is distinct from greatest(86400, greatest(cost_technology, 1) * 86400);

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
  v_mode text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Solo admin puede cambiar el modo de tiempos';
  end if;

  v_mode := public.apply_campaign_timing_mode(target_mode);

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    auth.uid(),
    'admin_campaign_timing_mode_updated',
    jsonb_build_object('timing_mode', v_mode)
  );

  return v_mode;
end;
$$;

create or replace function public.apply_test_timers_three_seconds()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.apply_campaign_timing_mode('test');
end;
$$;

revoke execute on function public.apply_campaign_timing_mode(text) from public;
revoke execute on function public.apply_campaign_timing_mode(text) from anon;
revoke execute on function public.apply_campaign_timing_mode(text) from authenticated;

revoke execute on function public.admin_set_campaign_timing_mode(text) from public;
revoke execute on function public.admin_set_campaign_timing_mode(text) from anon;
grant execute on function public.admin_set_campaign_timing_mode(text) to authenticated;

revoke execute on function public.apply_test_timers_three_seconds() from public;
revoke execute on function public.apply_test_timers_three_seconds() from anon;
revoke execute on function public.apply_test_timers_three_seconds() from authenticated;

select public.apply_campaign_timing_mode('test');
