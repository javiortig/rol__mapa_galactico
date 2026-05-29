drop function if exists public.resolve_resource_ticks();
drop function if exists public.resolve_movement_orders();
drop function if exists public.resolve_recruitment_queue();

create or replace function public.resolve_resource_ticks()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.campaign_settings%rowtype;
  v_tick_at timestamptz;
  v_last_applied_at timestamptz;
  v_applied integer := 0;
begin
  select *
  into v_settings
  from public.campaign_settings
  where id = 'default'
  for update;

  if not found then
    insert into public.campaign_settings (id, resource_tick_interval_hours, next_resource_tick_at)
    values ('default', 24, now() + interval '24 hours')
    returning * into v_settings;
  end if;

  v_tick_at := coalesce(v_settings.next_resource_tick_at, now() + make_interval(hours => v_settings.resource_tick_interval_hours));

  while v_tick_at <= now() loop
    insert into public.faction_resources (
      faction_id,
      supply,
      minerals,
      ancestral_stone,
      uridium,
      technology,
      updated_at
    )
    select
      systems.controller_faction_id,
      coalesce(sum(system_production.supply_per_tick), 0)::integer,
      coalesce(sum(system_production.minerals_per_tick), 0)::integer,
      coalesce(sum(system_production.ancestral_stone_per_tick), 0)::integer,
      coalesce(sum(system_production.uridium_per_tick), 0)::integer,
      coalesce(sum(system_production.technology_per_tick), 0)::integer,
      now()
    from public.systems
    join public.system_production on system_production.system_id = systems.id
    where systems.status = 'controlled'
      and systems.controller_faction_id is not null
    group by systems.controller_faction_id
    on conflict (faction_id) do update
    set
      supply = public.faction_resources.supply + excluded.supply,
      minerals = public.faction_resources.minerals + excluded.minerals,
      ancestral_stone = public.faction_resources.ancestral_stone + excluded.ancestral_stone,
      uridium = public.faction_resources.uridium + excluded.uridium,
      technology = public.faction_resources.technology + excluded.technology,
      updated_at = now();

    insert into public.campaign_logs (action_type, payload)
    values (
      'resource_tick_applied',
      jsonb_build_object('tick_at', v_tick_at)
    );

    v_last_applied_at := v_tick_at;
    v_tick_at := v_tick_at + make_interval(hours => v_settings.resource_tick_interval_hours);
    v_applied := v_applied + 1;
  end loop;

  if v_applied > 0 then
    update public.campaign_settings
    set
      last_resource_tick_at = v_last_applied_at,
      next_resource_tick_at = v_tick_at,
      updated_at = now()
    where id = 'default';
  end if;

  return v_applied;
end;
$$;

create or replace function public.resolve_recruitment_queue()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_army_id uuid;
  v_reserve_slug text;
  v_completed integer := 0;
begin
  for v_item in
    select
      recruitment_queue.*,
      unit_templates.name as unit_name,
      unit_templates.points,
      factions.slug as faction_slug,
      factions.capital_system_id
    from public.recruitment_queue
    join public.unit_templates on unit_templates.id = recruitment_queue.unit_template_id
    join public.factions on factions.id = recruitment_queue.faction_id
    where recruitment_queue.status = 'queued'
      and recruitment_queue.finishes_at <= now()
    order by recruitment_queue.finishes_at
    for update of recruitment_queue
  loop
    v_reserve_slug := 'reserve-' || coalesce(v_item.faction_slug, v_item.faction_id::text);

    insert into public.armies (
      slug,
      faction_id,
      name,
      current_system_id,
      status,
      points_total,
      is_visible_publicly
    )
    values (
      v_reserve_slug,
      v_item.faction_id,
      'Reserva de Capital',
      v_item.capital_system_id,
      'ready',
      0,
      false
    )
    on conflict (slug) do update
    set
      current_system_id = excluded.current_system_id,
      status = 'ready',
      updated_at = now()
    returning id into v_army_id;

    insert into public.army_units (
      army_id,
      name,
      points,
      quantity,
      experience
    )
    values (
      v_army_id,
      v_item.unit_name,
      v_item.points,
      v_item.quantity,
      0
    );

    update public.armies
    set
      points_total = points_total + (v_item.points * v_item.quantity),
      updated_at = now()
    where id = v_army_id;

    update public.recruitment_queue
    set status = 'completed'
    where id = v_item.id;

    insert into public.campaign_logs (faction_id, action_type, payload)
    values (
      v_item.faction_id,
      'recruitment_completed',
      jsonb_build_object(
        'queue_id', v_item.id,
        'army_id', v_army_id,
        'unit_template_id', v_item.unit_template_id,
        'unit_name', v_item.unit_name,
        'quantity', v_item.quantity
      )
    );

    v_completed := v_completed + 1;
  end loop;

  return v_completed;
end;
$$;

create or replace function public.resolve_movement_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_system public.systems%rowtype;
  v_conflict_id uuid;
  v_blocked_until timestamptz;
  v_resolved integer := 0;
begin
  for v_order in
    select *
    from public.movement_orders
    where status = 'moving'
      and arrival_at <= now()
    order by arrival_at
    for update
  loop
    select *
    into v_system
    from public.systems
    where id = v_order.to_system_id
    for update;

    update public.movement_orders
    set status = 'arrived'
    where id = v_order.id;

    if v_system.status = 'war' then
      update public.armies
      set
        current_system_id = v_order.to_system_id,
        status = 'in_war',
        updated_at = now()
      where id = v_order.army_id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'movement_arrived_locked',
        jsonb_build_object('movement_order_id', v_order.id, 'system_id', v_order.to_system_id)
      );
    elsif v_system.controller_faction_id is null
      or v_system.controller_faction_id is distinct from v_order.faction_id then
      v_blocked_until := now() + interval '7 days';

      insert into public.conflicts (
        slug,
        system_id,
        attacker_faction_id,
        defender_faction_id,
        status,
        blocked_until,
        notes
      )
      values (
        'conflict-' || v_order.id::text,
        v_order.to_system_id,
        v_order.faction_id,
        v_system.controller_faction_id,
        'pending',
        v_blocked_until,
        'Conflicto generado por llegada de movimiento.'
      )
      returning id into v_conflict_id;

      update public.systems
      set
        status = 'war',
        blocked_until = v_blocked_until,
        updated_at = now()
      where id = v_order.to_system_id;

      update public.armies
      set
        current_system_id = v_order.to_system_id,
        status = 'in_war',
        updated_at = now()
      where id = v_order.army_id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values
        (
          v_order.faction_id,
          'conflict_created',
          jsonb_build_object(
            'conflict_id', v_conflict_id,
            'movement_order_id', v_order.id,
            'system_id', v_order.to_system_id,
            'blocked_until', v_blocked_until
          )
        ),
        (
          v_order.faction_id,
          'system_locked',
          jsonb_build_object('system_id', v_order.to_system_id, 'blocked_until', v_blocked_until)
        );
    else
      update public.armies
      set
        current_system_id = v_order.to_system_id,
        status = 'ready',
        updated_at = now()
      where id = v_order.army_id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'movement_completed',
        jsonb_build_object('movement_order_id', v_order.id, 'system_id', v_order.to_system_id)
      );
    end if;

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

create or replace function public.recruit_unit(unit_template_id uuid, quantity integer)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_template public.unit_templates%rowtype;
  v_resources public.faction_resources%rowtype;
  v_is_admin boolean := false;
  v_queue_id uuid;
  v_quantity integer := quantity;
  v_supply_cost integer;
  v_minerals_cost integer;
  v_ancestral_stone_cost integer;
  v_uridium_cost integer;
  v_technology_cost integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if v_quantity is null or v_quantity < 1 then
    raise exception 'Cantidad invalida';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_template
  from public.unit_templates
  where id = $1
    and is_available = true;

  if not found then
    raise exception 'Unidad no disponible';
  end if;

  if not v_is_admin and not exists (
    select 1
    from public.player_factions
    where user_id = v_user_id
      and faction_id = v_template.faction_id
  ) then
    raise exception 'No puedes reclutar unidades de esta faccion';
  end if;

  v_supply_cost := v_template.supply_cost * v_quantity;
  v_minerals_cost := v_template.minerals_cost * v_quantity;
  v_ancestral_stone_cost := v_template.ancestral_stone_cost * v_quantity;
  v_uridium_cost := v_template.uridium_cost * v_quantity;
  v_technology_cost := v_template.technology_cost * v_quantity;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_template.faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
  end if;

  if v_resources.supply < v_supply_cost
    or v_resources.minerals < v_minerals_cost
    or v_resources.ancestral_stone < v_ancestral_stone_cost
    or v_resources.uridium < v_uridium_cost
    or v_resources.technology < v_technology_cost then
    raise exception 'Recursos insuficientes';
  end if;

  update public.faction_resources
  set
    supply = supply - v_supply_cost,
    minerals = minerals - v_minerals_cost,
    ancestral_stone = ancestral_stone - v_ancestral_stone_cost,
    uridium = uridium - v_uridium_cost,
    technology = technology - v_technology_cost,
    updated_at = now()
  where faction_id = v_template.faction_id;

  insert into public.recruitment_queue (
    faction_id,
    unit_template_id,
    quantity,
    supply_cost,
    minerals_cost,
    ancestral_stone_cost,
    uridium_cost,
    technology_cost,
    started_at,
    finishes_at,
    status
  )
  values (
    v_template.faction_id,
    v_template.id,
    v_quantity,
    v_supply_cost,
    v_minerals_cost,
    v_ancestral_stone_cost,
    v_uridium_cost,
    v_technology_cost,
    now(),
    now() + make_interval(secs => v_template.recruitment_time_seconds * v_quantity),
    'queued'
  )
  returning id into v_queue_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_template.faction_id,
    'recruitment_started',
    jsonb_build_object(
      'queue_id', v_queue_id,
      'unit_template_id', v_template.id,
      'unit_name', v_template.name,
      'quantity', v_quantity,
      'supply_cost', v_supply_cost,
      'minerals_cost', v_minerals_cost,
      'ancestral_stone_cost', v_ancestral_stone_cost,
      'uridium_cost', v_uridium_cost,
      'technology_cost', v_technology_cost
    )
  );

  return v_queue_id;
end;
$$;

create or replace function public.submit_battle_report(conflict_id uuid, report_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.conflicts%rowtype;
  v_reporter_faction_id uuid;
  v_is_admin boolean := false;
  v_report_id uuid;
  v_other public.battle_reports%rowtype;
  v_winner_faction_id uuid;
  v_final_controller_faction_id uuid;
  v_post_battle_blocked_until timestamptz;
  v_casualties jsonb;
  v_survivors jsonb;
  v_xp_awards jsonb;
  v_enhancements jsonb;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_conflict
  from public.conflicts
  where id = $1
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Conflicto pendiente no encontrado';
  end if;

  select player_factions.faction_id
  into v_reporter_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
    and player_factions.faction_id in (v_conflict.attacker_faction_id, v_conflict.defender_faction_id)
  order by player_factions.created_at
  limit 1;

  if not v_is_admin and v_reporter_faction_id is null then
    raise exception 'Solo participantes o admin pueden reportar esta batalla';
  end if;

  v_winner_faction_id := nullif(report_payload->>'winner_faction_id', '')::uuid;
  v_final_controller_faction_id := nullif(report_payload->>'final_controller_faction_id', '')::uuid;
  v_post_battle_blocked_until := nullif(report_payload->>'post_battle_blocked_until', '')::timestamptz;
  v_casualties := coalesce(report_payload->'casualties', '{}'::jsonb);
  v_survivors := coalesce(report_payload->'survivors', '{}'::jsonb);
  v_xp_awards := coalesce(report_payload->'xp_awards', '{}'::jsonb);
  v_enhancements := coalesce(report_payload->'enhancements', '{}'::jsonb);

  insert into public.battle_reports (
    conflict_id,
    reporter_user_id,
    reporter_faction_id,
    winner_faction_id,
    final_controller_faction_id,
    casualties,
    survivors,
    xp_awards,
    enhancements,
    post_battle_blocked_until,
    narrative_notes,
    status
  )
  values (
    v_conflict.id,
    v_user_id,
    v_reporter_faction_id,
    v_winner_faction_id,
    v_final_controller_faction_id,
    v_casualties,
    v_survivors,
    v_xp_awards,
    v_enhancements,
    v_post_battle_blocked_until,
    report_payload->>'narrative_notes',
    'submitted'
  )
  returning id into v_report_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_reporter_faction_id,
    'battle_report_submitted',
    jsonb_build_object('report_id', v_report_id, 'conflict_id', v_conflict.id)
  );

  select *
  into v_other
  from public.battle_reports
  where battle_reports.conflict_id = v_conflict.id
    and battle_reports.id <> v_report_id
    and battle_reports.status = 'submitted'
    and (
      v_reporter_faction_id is null
      or battle_reports.reporter_faction_id is distinct from v_reporter_faction_id
    )
  order by battle_reports.created_at
  limit 1;

  if found then
    if v_other.winner_faction_id is not distinct from v_winner_faction_id
      and v_other.final_controller_faction_id is not distinct from v_final_controller_faction_id
      and coalesce(v_other.casualties, '{}'::jsonb) = v_casualties
      and coalesce(v_other.survivors, '{}'::jsonb) = v_survivors
      and coalesce(v_other.xp_awards, '{}'::jsonb) = v_xp_awards
      and coalesce(v_other.enhancements, '{}'::jsonb) = v_enhancements then
      update public.battle_reports
      set
        status = 'auto_confirmed',
        resolved_at = now()
      where id in (v_report_id, v_other.id);

      update public.conflicts
      set
        status = 'resolved',
        winner_faction_id = v_winner_faction_id,
        blocked_until = v_post_battle_blocked_until,
        resolved_at = now()
      where id = v_conflict.id;

      update public.systems
      set
        status = case when v_final_controller_faction_id is null then 'neutral' else 'controlled' end,
        controller_faction_id = v_final_controller_faction_id,
        blocked_until = v_post_battle_blocked_until,
        updated_at = now()
      where id = v_conflict.system_id;

      update public.armies
      set
        status = 'ready',
        updated_at = now()
      where current_system_id = v_conflict.system_id
        and status = 'in_war';

      insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
      values (
        v_user_id,
        v_reporter_faction_id,
        'battle_report_auto_confirmed',
        jsonb_build_object('conflict_id', v_conflict.id, 'report_ids', jsonb_build_array(v_report_id, v_other.id))
      );
    else
      update public.battle_reports
      set status = 'disputed'
      where id in (v_report_id, v_other.id);

      insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
      values (
        v_user_id,
        v_reporter_faction_id,
        'battle_report_disputed',
        jsonb_build_object('conflict_id', v_conflict.id, 'report_ids', jsonb_build_array(v_report_id, v_other.id))
      );
    end if;
  end if;

  return v_report_id;
end;
$$;

create or replace function public.admin_resolve_battle(
  target_conflict_id uuid,
  winner_faction_id uuid,
  final_controller_faction_id uuid,
  post_battle_blocked_until timestamptz default null,
  narrative_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.conflicts%rowtype;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede resolver batallas manualmente';
  end if;

  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id
  for update;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  update public.conflicts
  set
    status = 'resolved',
    winner_faction_id = admin_resolve_battle.winner_faction_id,
    blocked_until = admin_resolve_battle.post_battle_blocked_until,
    resolved_at = now(),
    notes = coalesce(admin_resolve_battle.narrative_notes, notes)
  where id = target_conflict_id;

  update public.systems
  set
    status = case when admin_resolve_battle.final_controller_faction_id is null then 'neutral' else 'controlled' end,
    controller_faction_id = admin_resolve_battle.final_controller_faction_id,
    blocked_until = admin_resolve_battle.post_battle_blocked_until,
    updated_at = now()
  where id = v_conflict.system_id;

  update public.armies
  set
    status = 'ready',
    updated_at = now()
  where current_system_id = v_conflict.system_id
    and status = 'in_war';

  insert into public.battle_reports (
    conflict_id,
    reporter_user_id,
    winner_faction_id,
    final_controller_faction_id,
    post_battle_blocked_until,
    narrative_notes,
    status,
    resolved_at
  )
  values (
    target_conflict_id,
    v_user_id,
    admin_resolve_battle.winner_faction_id,
    admin_resolve_battle.final_controller_faction_id,
    admin_resolve_battle.post_battle_blocked_until,
    admin_resolve_battle.narrative_notes,
    'admin_confirmed',
    now()
  );

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    admin_resolve_battle.final_controller_faction_id,
    'battle_report_admin_resolved',
    jsonb_build_object(
      'conflict_id', target_conflict_id,
      'winner_faction_id', admin_resolve_battle.winner_faction_id,
      'final_controller_faction_id', admin_resolve_battle.final_controller_faction_id
    )
  );
end;
$$;

grant execute on function public.resolve_resource_ticks() to authenticated;
grant execute on function public.resolve_movement_orders() to authenticated;
grant execute on function public.resolve_recruitment_queue() to authenticated;
grant execute on function public.recruit_unit(uuid, integer) to authenticated;
grant execute on function public.submit_battle_report(uuid, jsonb) to authenticated;
grant execute on function public.admin_resolve_battle(uuid, uuid, uuid, timestamptz, text) to authenticated;
