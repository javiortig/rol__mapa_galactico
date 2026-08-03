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
    and (systems.blocked_until is null or systems.blocked_until <= now())
    and not exists (
      select 1
      from public.conflicts
      where conflicts.system_id = systems.id
        and conflicts.status = 'pending'
    )
    and not exists (
      select 1
      from public.narrative_attacks
      where narrative_attacks.system_id = systems.id
        and narrative_attacks.status = 'incoming'
    )
    and not exists (
      select 1
      from public.movement_orders
      where movement_orders.to_system_id = systems.id
        and movement_orders.movement_type = 'attack'
        and movement_orders.status in ('pending_approval', 'moving', 'in_battle')
    )
    and not exists (
      select 1
      from public.battle_operations
      where battle_operations.target_system_id = systems.id
        and battle_operations.status in ('assembling', 'moving', 'in_battle')
    )
  order by graph.depth, systems.name
  limit 1;
$$;

create or replace function public.find_retreat_system(target_faction_id uuid, origin_system_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select public.find_nearest_allied_safe_system(target_faction_id, origin_system_id);
$$;

create or replace function public.apply_battle_outcome(
  target_conflict_id uuid,
  winner_faction_id uuid,
  final_controller_faction_id uuid,
  post_battle_blocked_until timestamptz,
  survivors jsonb,
  wounds_remaining jsonb,
  actor_user_id uuid,
  actor_faction_id uuid,
  narrative_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conflict public.conflicts%rowtype;
  v_unit public.campaign_units%rowtype;
  v_commitment public.battle_unit_commitments%rowtype;
  v_survivors integer;
  v_wounds integer;
  v_retreat_system_id uuid;
  v_supporter_side_lost boolean;
begin
  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id
  for update;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  perform public.validate_battle_survivors_and_wounds(target_conflict_id, survivors, wounds_remaining);

  update public.conflicts
  set
    status = 'resolved',
    winner_faction_id = apply_battle_outcome.winner_faction_id,
    blocked_until = apply_battle_outcome.post_battle_blocked_until,
    resolved_at = now(),
    notes = coalesce(apply_battle_outcome.narrative_notes, notes)
  where id = target_conflict_id;

  update public.systems
  set
    status = case when apply_battle_outcome.final_controller_faction_id is null then 'neutral' else 'controlled' end,
    controller_faction_id = apply_battle_outcome.final_controller_faction_id,
    blocked_until = apply_battle_outcome.post_battle_blocked_until,
    updated_at = now()
  where id = v_conflict.system_id;

  for v_unit in
    select *
    from public.campaign_units
    where current_system_id = v_conflict.system_id
      and status = 'in_war'
    order by created_at, id
    for update
  loop
    v_survivors := (survivors->>v_unit.id::text)::integer;
    v_wounds := (wounds_remaining->>v_unit.id::text)::integer;

    select *
    into v_commitment
    from public.battle_unit_commitments
    where operation_id = v_conflict.battle_operation_id
      and unit_id = v_unit.id;

    v_supporter_side_lost :=
      v_commitment.id is not null
      and v_commitment.role = 'supporter'
      and apply_battle_outcome.winner_faction_id is not null
      and (
        (v_commitment.side = 'attacker' and v_conflict.attacker_faction_id is distinct from apply_battle_outcome.winner_faction_id)
        or
        (v_commitment.side = 'defender' and v_conflict.defender_faction_id is distinct from apply_battle_outcome.winner_faction_id)
      );

    if v_survivors = 0 then
      update public.campaign_units
      set
        quantity = 0,
        wounds_taken = 0,
        status = 'destroyed',
        destroyed_at = now(),
        updated_at = now()
      where id = v_unit.id;

      if v_commitment.id is not null then
        update public.battle_unit_commitments
        set status = 'destroyed', updated_at = now()
        where id = v_commitment.id;
      end if;
    elsif v_commitment.id is not null and v_commitment.role = 'supporter' and not v_supporter_side_lost then
      update public.campaign_units
      set
        quantity = v_survivors,
        wounds_taken = v_wounds,
        status = 'moving',
        updated_at = now()
      where id = v_unit.id;

      perform public.queue_battle_support_return(v_commitment.id);
    elsif apply_battle_outcome.final_controller_faction_id is null
      or v_unit.faction_id is not distinct from apply_battle_outcome.final_controller_faction_id then
      update public.campaign_units
      set
        quantity = v_survivors,
        wounds_taken = v_wounds,
        status = 'ready',
        updated_at = now()
      where id = v_unit.id;
    else
      v_retreat_system_id := public.find_retreat_system(v_unit.faction_id, v_conflict.system_id);

      if v_retreat_system_id is null then
        update public.campaign_units
        set
          quantity = v_survivors,
          wounds_taken = v_wounds,
          status = 'retreat_pending',
          updated_at = now()
        where id = v_unit.id;

        if v_commitment.id is not null then
          update public.battle_unit_commitments
          set status = 'return_pending', updated_at = now()
          where id = v_commitment.id;
        end if;
      else
        update public.campaign_units
        set
          quantity = v_survivors,
          wounds_taken = v_wounds,
          current_system_id = v_retreat_system_id,
          status = 'ready',
          updated_at = now()
        where id = v_unit.id;

        if v_commitment.id is not null then
          update public.battle_unit_commitments
          set status = 'returned', updated_at = now()
          where id = v_commitment.id;
        end if;
      end if;
    end if;
  end loop;

  if v_conflict.battle_operation_id is not null then
    update public.battle_operations
    set status = 'resolved', resolved_at = now(), updated_at = now()
    where id = v_conflict.battle_operation_id;
  end if;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    apply_battle_outcome.actor_user_id,
    apply_battle_outcome.actor_faction_id,
    'battle_outcome_applied',
    jsonb_build_object(
      'conflict_id', target_conflict_id,
      'operation_id', v_conflict.battle_operation_id,
      'winner_faction_id', apply_battle_outcome.winner_faction_id,
      'final_controller_faction_id', apply_battle_outcome.final_controller_faction_id,
      'survivors', survivors,
      'wounds_remaining', wounds_remaining
    )
  );
end;
$$;

create or replace function public.validate_battle_report(target_conflict_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.conflicts%rowtype;
  v_report public.battle_reports%rowtype;
  v_reporter_faction_id uuid;
  v_validations jsonb;
  v_required_faction_id uuid;
  v_all_validated boolean := true;
  v_is_conquerable_system boolean := true;
  v_winner_faction_id uuid;
  v_final_controller_faction_id uuid;
  v_post_battle_blocked_until timestamptz;
  v_survivors jsonb;
  v_wounds_remaining jsonb;
  v_casualties jsonb;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Conflicto pendiente no encontrado';
  end if;

  select player_factions.faction_id
  into v_reporter_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
    and exists (
      select 1
      from public.get_battle_report_required_faction_ids(v_conflict.id) required_factions
      where required_factions.faction_id = player_factions.faction_id
    )
  order by player_factions.created_at
  limit 1;

  if v_reporter_faction_id is null then
    raise exception 'Solo participantes pueden validar esta batalla';
  end if;

  select coalesce(systems.is_conquerable, true)
  into v_is_conquerable_system
  from public.systems
  where systems.id = v_conflict.system_id;

  select *
  into v_report
  from public.battle_reports
  where battle_reports.conflict_id = v_conflict.id
    and battle_reports.status in ('draft', 'awaiting_validation', 'players_confirmed')
  order by battle_reports.updated_at desc, battle_reports.created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'No hay informe compartido para validar';
  end if;

  v_survivors := coalesce(v_report.survivors, '{}'::jsonb);
  v_wounds_remaining := coalesce(v_report.wounds_remaining, '{}'::jsonb);
  v_casualties := public.validate_battle_survivors_and_wounds(
    v_conflict.id,
    v_survivors,
    v_wounds_remaining
  );

  v_validations := coalesce(v_report.participant_validations, '{}'::jsonb)
    || jsonb_build_object(
      v_reporter_faction_id::text,
      jsonb_build_object(
        'faction_id', v_reporter_faction_id,
        'user_id', v_user_id,
        'revision', v_report.revision,
        'confirmed_at', now()
      )
    );

  for v_required_faction_id in
    select required_factions.faction_id
    from public.get_battle_report_required_faction_ids(v_conflict.id) required_factions
  loop
    if not (v_validations ? v_required_faction_id::text)
      or coalesce((v_validations->v_required_faction_id::text->>'revision')::integer, 0) <> v_report.revision then
      v_all_validated := false;
    end if;
  end loop;

  if not v_all_validated then
    update public.battle_reports
    set
      participant_validations = v_validations,
      status = 'awaiting_validation',
      resolved_at = null,
      updated_at = now()
    where id = v_report.id;

    insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
    values (
      v_user_id,
      v_reporter_faction_id,
      'battle_report_validated',
      jsonb_build_object(
        'report_id', v_report.id,
        'conflict_id', v_conflict.id,
        'revision', v_report.revision
      )
    );

    return v_report.id;
  end if;

  v_winner_faction_id := v_report.winner_faction_id;
  v_final_controller_faction_id := case
    when v_is_conquerable_system then coalesce(v_report.final_controller_faction_id, v_winner_faction_id)
    else null
  end;
  v_post_battle_blocked_until := coalesce(v_report.post_battle_blocked_until, now() + interval '14 days');

  perform public.apply_battle_outcome(
    target_conflict_id,
    v_winner_faction_id,
    v_final_controller_faction_id,
    v_post_battle_blocked_until,
    v_survivors,
    v_wounds_remaining,
    v_user_id,
    v_reporter_faction_id,
    v_report.narrative_notes
  );

  update public.battle_reports
  set
    participant_validations = v_validations,
    winner_faction_id = v_winner_faction_id,
    final_controller_faction_id = v_final_controller_faction_id,
    casualties = v_casualties,
    survivors = v_survivors,
    wounds_remaining = v_wounds_remaining,
    post_battle_blocked_until = v_post_battle_blocked_until,
    status = 'auto_confirmed',
    resolved_at = now(),
    updated_at = now()
  where id = v_report.id;

  update public.battle_reports
  set
    status = 'rejected',
    updated_at = now()
  where conflict_id = target_conflict_id
    and id <> v_report.id
    and status in ('draft', 'awaiting_validation', 'players_confirmed', 'submitted', 'disputed');

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_reporter_faction_id,
    'battle_report_auto_confirmed',
    jsonb_build_object(
      'report_id', v_report.id,
      'conflict_id', v_conflict.id,
      'revision', v_report.revision
    )
  );

  return v_report.id;
end;
$$;

revoke execute on function public.find_nearest_allied_safe_system(uuid, uuid) from public;
revoke execute on function public.find_retreat_system(uuid, uuid) from public;
revoke execute on function public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text) from public;
revoke execute on function public.validate_battle_report(uuid) from public;

grant execute on function public.validate_battle_report(uuid) to authenticated;
