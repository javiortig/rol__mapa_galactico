create or replace function public.system_has_unresolved_battle_block(target_system_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.systems
    where systems.id = $1
      and systems.status = 'war'
  )
  or exists (
    select 1
    from public.conflicts
    where conflicts.system_id = $1
      and conflicts.status = 'pending'
  )
  or exists (
    select 1
    from public.narrative_attacks
    where narrative_attacks.system_id = $1
      and narrative_attacks.status = 'incoming'
  )
  or exists (
    select 1
    from public.movement_orders
    where movement_orders.to_system_id = $1
      and movement_orders.movement_type = 'attack'
      and movement_orders.status in ('pending_approval', 'moving')
  )
  or exists (
    select 1
    from public.battle_operations
    where battle_operations.target_system_id = $1
      and battle_operations.status in ('assembling', 'moving', 'in_battle')
  );
$$;

create or replace function public.can_faction_depart_from_system(
  target_system_id uuid,
  target_faction_id uuid,
  allow_foreign_presence boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.systems
    where systems.id = $1
      and systems.status <> 'war'
      and coalesce(systems.is_temporary_mission, false) = false
      and not exists (
        select 1
        from public.conflicts
        where conflicts.system_id = systems.id
          and conflicts.status = 'pending'
      )
      and (
        (
          systems.status = 'controlled'
          and systems.controller_faction_id = $2
        )
        or coalesce(systems.system_kind, 'standard') = 'gaseous'
        or coalesce(systems.allows_shared_occupation, false)
        or not coalesce(systems.is_conquerable, true)
        or $3
      )
  );
$$;

create or replace function public.can_select_campaign_unit_for_operation(target_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.battle_unit_commitments
    join public.battle_operations
      on battle_operations.id = battle_unit_commitments.operation_id
    join public.battle_operation_members
      on battle_operation_members.operation_id = battle_unit_commitments.operation_id
    where battle_unit_commitments.unit_id = target_unit_id
      and battle_operations.status in ('assembling', 'moving', 'in_battle')
      and battle_unit_commitments.status not in ('returned', 'destroyed', 'cancelled')
      and battle_operation_members.invitation_status = 'accepted'
      and public.is_faction_member(battle_operation_members.faction_id)
  );
$$;

drop policy if exists campaign_units_select_visible_member_or_admin on public.campaign_units;
create policy campaign_units_select_visible_member_or_admin
on public.campaign_units
for select
to authenticated
using (
  public.is_admin()
  or is_visible_publicly
  or public.is_faction_member(faction_id)
  or public.user_has_presence_in_system(current_system_id)
  or public.user_controls_system(current_system_id)
  or public.can_select_campaign_unit_for_operation(id)
  or public.can_select_campaign_unit_for_passage_request(id)
);

create or replace function public.find_nearest_allied_safe_system(
  target_faction_id uuid,
  origin_system_id uuid
)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  with recursive graph(system_id, depth, path) as (
    select
      case
        when system_edges.from_system_id = origin_system_id then system_edges.to_system_id
        else system_edges.from_system_id
      end as system_id,
      1 as depth,
      array[
        origin_system_id,
        case
          when system_edges.from_system_id = origin_system_id then system_edges.to_system_id
          else system_edges.from_system_id
        end
      ] as path
    from public.system_edges
    where not system_edges.is_blocked
      and (system_edges.from_system_id = origin_system_id or system_edges.to_system_id = origin_system_id)

    union all

    select
      case
        when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
        else system_edges.from_system_id
      end as system_id,
      graph.depth + 1,
      graph.path ||
        case
          when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
          else system_edges.from_system_id
        end
    from graph
    join public.system_edges
      on not system_edges.is_blocked
      and (system_edges.from_system_id = graph.system_id or system_edges.to_system_id = graph.system_id)
    where graph.depth < 30
      and not (
        case
          when system_edges.from_system_id = graph.system_id then system_edges.to_system_id
          else system_edges.from_system_id
        end = any(graph.path)
      )
  )
  select systems.id
  from graph
  join public.systems on systems.id = graph.system_id
  where systems.controller_faction_id = target_faction_id
    and systems.status = 'controlled'
    and not public.system_has_unresolved_battle_block(systems.id)
  order by graph.depth, systems.name
  limit 1;
$$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.create_movement_order(jsonb, uuid[])'::regprocedure)
  into v_definition;

  v_patched := regexp_replace(
    v_definition,
    '\s*if v_index = v_path_length\s+and \(v_system.status = ''war'' or v_system.blocked_until is not null and v_system.blocked_until > now\(\)\) then\s+raise exception ''El destino esta bloqueado o en guerra'';\s+end if;',
    '    if v_index = v_path_length
      and (
        v_system.status = ''war''
        or exists (
          select 1
          from public.conflicts
          where conflicts.system_id = v_system.id
            and conflicts.status = ''pending''
        )
        or (
          v_system.blocked_until is not null
          and v_system.blocked_until > now()
          and v_system.controller_faction_id is distinct from v_faction_id
        )
      ) then
      raise exception ''El destino esta bloqueado o en guerra'';
    end if;',
    'm'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo parchear create_movement_order';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.start_building_construction(uuid, uuid)'::regprocedure)
  into v_definition;

  v_patched := regexp_replace(
    v_definition,
    '\s*if v_system.blocked_until is not null and v_system.blocked_until > now\(\) then\s+raise exception ''El sistema esta bloqueado'';\s+end if;',
    '  if public.system_has_unresolved_battle_block(v_system.id) then
    raise exception ''El sistema esta bloqueado'';
  end if;',
    'm'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo parchear start_building_construction';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb)'::regprocedure)
  into v_definition;

  v_patched := regexp_replace(
    v_definition,
    '\s*if v_building.blocked_until is not null and v_building.blocked_until > now\(\) then\s+raise exception ''El sistema esta bloqueado'';\s+end if;',
    '  if public.system_has_unresolved_battle_block(v_building.system_id) then
    raise exception ''El sistema esta bloqueado'';
  end if;',
    'm'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo parchear recruit_unit_variant_at_building';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.resupply_unit_at_building(uuid, uuid)'::regprocedure)
  into v_definition;

  v_patched := regexp_replace(
    v_definition,
    '\s*if v_building.blocked_until is not null and v_building.blocked_until > now\(\) then\s+raise exception ''El sistema esta bloqueado'';\s+end if;',
    '  if public.system_has_unresolved_battle_block(v_building.system_id) then
    raise exception ''El sistema esta bloqueado'';
  end if;',
    'm'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo parchear resupply_unit_at_building';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.destroy_system_building(uuid)'::regprocedure)
  into v_definition;

  v_patched := regexp_replace(
    v_definition,
    '\s*if v_system.blocked_until is not null and v_system.blocked_until > now\(\) then\s+raise exception ''No puedes destruir edificios en un sistema bloqueado'';\s+end if;',
    '    if public.system_has_unresolved_battle_block(v_system.id) then
      raise exception ''No puedes destruir edificios en un sistema bloqueado'';
    end if;',
    'm'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo parchear destroy_system_building';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text)'::regprocedure)
  into v_definition;

  v_patched := replace(
    v_definition,
    '  if v_conflict.battle_operation_id is not null then
    update public.battle_operations',
    '  if apply_battle_outcome.final_controller_faction_id is not null then
    for v_unit in
      select *
      from public.campaign_units
      where current_system_id = v_conflict.system_id
        and faction_id is distinct from apply_battle_outcome.final_controller_faction_id
        and status = ''ready''
        and quantity > 0
      order by created_at, id
      for update
    loop
      v_retreat_system_id := public.find_retreat_system(v_unit.faction_id, v_conflict.system_id);

      if v_retreat_system_id is null then
        update public.campaign_units
        set
          status = ''retreat_pending'',
          updated_at = now()
        where id = v_unit.id;
      else
        update public.campaign_units
        set
          current_system_id = v_retreat_system_id,
          status = ''ready'',
          updated_at = now()
        where id = v_unit.id;
      end if;
    end loop;
  end if;

  if v_conflict.battle_operation_id is not null then
    update public.battle_operations'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo parchear apply_battle_outcome';
  end if;

  execute v_patched;
end $$;

revoke execute on function public.system_has_unresolved_battle_block(uuid) from public;
revoke execute on function public.can_faction_depart_from_system(uuid, uuid, boolean) from public;
revoke execute on function public.can_select_campaign_unit_for_operation(uuid) from public;
revoke execute on function public.find_nearest_allied_safe_system(uuid, uuid) from public;
revoke execute on function public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text) from public;

grant execute on function public.system_has_unresolved_battle_block(uuid) to authenticated;
grant execute on function public.can_faction_depart_from_system(uuid, uuid, boolean) to authenticated;
grant execute on function public.can_select_campaign_unit_for_operation(uuid) to authenticated;
