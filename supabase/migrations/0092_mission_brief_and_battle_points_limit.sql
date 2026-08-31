alter table public.campaign_settings
  add column if not exists battle_points_limit integer not null default 500
    check (battle_points_limit > 0);

update public.campaign_settings
set battle_points_limit = 500,
    updated_at = now()
where id = 'default'
  and battle_points_limit is distinct from 500;

create or replace function public.battle_points_limit()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    coalesce((select campaign_settings.battle_points_limit from public.campaign_settings where id = 'default'), 500),
    1
  )::integer;
$$;

create or replace function public.faction_is_narrative(target_faction_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select factions.is_narrative from public.factions where factions.id = target_faction_id), false);
$$;

create or replace function public.is_tabletop_points_limited_battle(
  attacker_faction_id uuid,
  defender_faction_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select attacker_faction_id is not null
    and defender_faction_id is not null
    and not public.faction_is_narrative(attacker_faction_id)
    and not public.faction_is_narrative(defender_faction_id);
$$;

create or replace function public.selected_units_roster_points(target_unit_ids uuid[])
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(public.unit_roster_points(units.points, units.quantity)), 0)::integer
  from public.campaign_units as units
  where units.id = any(coalesce(target_unit_ids, '{}'::uuid[]))
    and units.quantity > 0
    and units.status <> 'destroyed';
$$;

create or replace function public.validate_tabletop_battle_side_points(
  attacker_faction_id uuid,
  defender_faction_id uuid,
  side_points integer,
  side_label text default 'bando'
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit integer := public.battle_points_limit();
begin
  if public.is_tabletop_points_limited_battle(attacker_faction_id, defender_faction_id)
    and coalesce(side_points, 0) > v_limit then
    raise exception 'El % supera el limite de % puntos (% pts)', coalesce(side_label, 'bando'), v_limit, coalesce(side_points, 0);
  end if;
end;
$$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.create_attack_order(jsonb, uuid, uuid)'::regprocedure)
  into v_definition;

  if position('public.validate_tabletop_battle_side_points(' in v_definition) = 0 then
    v_patched := replace(
      v_definition,
      '  perform public.validate_attack_limits(v_faction_id, v_target.controller_faction_id);

  select attack_duration_seconds',
      '  perform public.validate_attack_limits(v_faction_id, v_target.controller_faction_id);

  perform public.validate_tabletop_battle_side_points(
    v_faction_id,
    v_target.controller_faction_id,
    public.selected_units_roster_points(v_selected_unit_ids),
    ''bando atacante''
  );

  select attack_duration_seconds'
    );

    if v_patched = v_definition then
      raise exception 'No se pudo parchear create_attack_order con limite de puntos';
    end if;

    execute v_patched;
  end if;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.create_coalition_attack_draft(jsonb, uuid, uuid, uuid[])'::regprocedure)
  into v_definition;

  if position('public.validate_tabletop_battle_side_points(' in v_definition) = 0 then
    v_patched := replace(
      v_definition,
      '  insert into public.battle_operations (',
      '  perform public.validate_tabletop_battle_side_points(
    v_faction_id,
    v_target.controller_faction_id,
    public.selected_units_roster_points(v_selected_unit_ids),
    ''bando atacante''
  );

  insert into public.battle_operations ('
    );

    if v_patched = v_definition then
      raise exception 'No se pudo parchear create_coalition_attack_draft con limite de puntos';
    end if;

    execute v_patched;
  end if;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.join_battle_operation(uuid, jsonb, uuid[])'::regprocedure)
  into v_definition;

  if position('public.validate_tabletop_battle_side_points(' in v_definition) = 0 then
    v_patched := replace(
      v_definition,
      '  v_total_cost := v_route_cost * cardinality(v_selected_unit_ids);

  select movement_edge_duration_seconds',
      '  v_total_cost := v_route_cost * cardinality(v_selected_unit_ids);

  perform public.validate_tabletop_battle_side_points(
    v_operation.leader_faction_id,
    v_operation.defender_faction_id,
    coalesce((
      select sum(points_at_commitment)
      from public.battle_unit_commitments
      where battle_unit_commitments.operation_id = v_operation.id
        and side = v_member.side
        and status not in (''returned'', ''destroyed'', ''cancelled'')
    ), 0)::integer + public.selected_units_roster_points(v_selected_unit_ids),
    case when v_member.side = ''attacker'' then ''bando atacante'' else ''bando defensor'' end
  );

  select movement_edge_duration_seconds'
    );

    if v_patched = v_definition then
      raise exception 'No se pudo parchear join_battle_operation con limite de puntos';
    end if;

    execute v_patched;
  end if;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.launch_coalition_attack(uuid)'::regprocedure)
  into v_definition;

  if position('public.validate_tabletop_battle_side_points(' in v_definition) = 0 then
    v_patched := replace(
      v_definition,
      '  perform public.validate_attack_limits(v_operation.leader_faction_id, v_operation.defender_faction_id);

  select attack_duration_seconds',
      '  perform public.validate_attack_limits(v_operation.leader_faction_id, v_operation.defender_faction_id);

  perform public.validate_tabletop_battle_side_points(
    v_operation.leader_faction_id,
    v_operation.defender_faction_id,
    coalesce((
      select sum(points_at_commitment)
      from public.battle_unit_commitments
      where battle_unit_commitments.operation_id = v_operation.id
        and side = ''attacker''
        and status not in (''returned'', ''destroyed'', ''cancelled'')
    ), 0)::integer,
    ''bando atacante''
  );

  select attack_duration_seconds'
    );

    if v_patched = v_definition then
      raise exception 'No se pudo parchear launch_coalition_attack con limite de puntos';
    end if;

    execute v_patched;
  end if;
end $$;

create or replace function public.normalize_conquered_narrative_world()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_narrative boolean := false;
  v_new_narrative boolean := false;
begin
  if tg_op = 'UPDATE'
    and coalesce(old.is_temporary_mission, false) = false
    and new.status = 'controlled'
    and new.controller_faction_id is not null
    and new.controller_faction_id is distinct from old.controller_faction_id then
    select coalesce(factions.is_narrative, false)
    into v_old_narrative
    from public.factions
    where factions.id = old.controller_faction_id;

    select coalesce(factions.is_narrative, false)
    into v_new_narrative
    from public.factions
    where factions.id = new.controller_faction_id;

    if v_old_narrative and not v_new_narrative then
      new.mission_id := null;
      new.mission_threat_faction_id := null;
      new.mission_enemy_units_visible := false;
      new.mission_enemy_units := '[]'::jsonb;
      new.mission_expires_at := null;
      new.mission_expires_after_battle := false;
      new.temporary_mission_status := 'active';
      new.temporary_mission_closed_at := null;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists normalize_conquered_narrative_world_trigger on public.systems;
create trigger normalize_conquered_narrative_world_trigger
before update of status, controller_faction_id on public.systems
for each row
execute function public.normalize_conquered_narrative_world();

revoke execute on function public.battle_points_limit() from public;
revoke execute on function public.faction_is_narrative(uuid) from public;
revoke execute on function public.is_tabletop_points_limited_battle(uuid, uuid) from public;
revoke execute on function public.selected_units_roster_points(uuid[]) from public;
revoke execute on function public.validate_tabletop_battle_side_points(uuid, uuid, integer, text) from public;
revoke execute on function public.create_attack_order(jsonb, uuid, uuid) from public;
revoke execute on function public.create_coalition_attack_draft(jsonb, uuid, uuid, uuid[]) from public;
revoke execute on function public.join_battle_operation(uuid, jsonb, uuid[]) from public;
revoke execute on function public.launch_coalition_attack(uuid) from public;

grant execute on function public.create_attack_order(jsonb, uuid, uuid) to authenticated;
grant execute on function public.create_coalition_attack_draft(jsonb, uuid, uuid, uuid[]) to authenticated;
grant execute on function public.join_battle_operation(uuid, jsonb, uuid[]) to authenticated;
grant execute on function public.launch_coalition_attack(uuid) to authenticated;

insert into public.campaign_logs (action_type, payload)
values (
  'battle_points_limit_enabled',
  jsonb_build_object(
    'battle_points_limit', 500,
    'rule', 'Las batallas entre facciones jugadoras usan un maximo de 500 puntos por bando.'
  )
);
