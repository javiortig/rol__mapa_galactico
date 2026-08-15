create or replace function public.admin_confirm_battle_report(
  target_conflict_id uuid,
  report_payload jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.conflicts%rowtype;
  v_report public.battle_reports%rowtype;
  v_payload jsonb := coalesce(report_payload, '{}'::jsonb);
  v_has_payload boolean := report_payload is not null and report_payload <> '{}'::jsonb;
  v_is_conquerable_system boolean := true;
  v_winner_faction_id uuid;
  v_final_controller_faction_id uuid;
  v_post_battle_blocked_until timestamptz;
  v_survivors jsonb;
  v_wounds_remaining jsonb;
  v_battle_mode text;
  v_narrative_notes text;
  v_casualties jsonb;
  v_report_id uuid;
  v_revision integer := 1;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede confirmar batallas';
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

  select coalesce(systems.is_conquerable, true)
  into v_is_conquerable_system
  from public.systems
  where systems.id = v_conflict.system_id;

  select *
  into v_report
  from public.battle_reports
  where conflict_id = target_conflict_id
    and status <> 'rejected'
  order by updated_at desc, created_at desc
  limit 1
  for update;

  if not found and not v_has_payload then
    raise exception 'No hay datos de resolucion para aplicar';
  end if;

  v_battle_mode := case
    when v_payload ? 'battle_mode' then coalesce(nullif(v_payload->>'battle_mode', ''), 'tabletop')
    when v_report.id is not null then v_report.battle_mode
    else 'tabletop'
  end;

  if v_battle_mode not in ('tabletop', 'autoresolve') then
    raise exception 'Modo de batalla no valido';
  end if;

  v_winner_faction_id := case
    when v_payload ? 'winner_faction_id' then nullif(v_payload->>'winner_faction_id', '')::uuid
    else v_report.winner_faction_id
  end;

  if v_winner_faction_id is not null
    and v_winner_faction_id not in (v_conflict.attacker_faction_id, v_conflict.defender_faction_id) then
    raise exception 'La faccion ganadora debe participar en el conflicto';
  end if;

  v_final_controller_faction_id := case
    when not v_is_conquerable_system then null
    when v_payload ? 'final_controller_faction_id' then nullif(v_payload->>'final_controller_faction_id', '')::uuid
    when v_report.id is not null then coalesce(v_report.final_controller_faction_id, v_winner_faction_id)
    else v_winner_faction_id
  end;

  v_post_battle_blocked_until := case
    when v_payload ? 'post_battle_blocked_until' then nullif(v_payload->>'post_battle_blocked_until', '')::timestamptz
    when v_report.id is not null then coalesce(v_report.post_battle_blocked_until, now() + interval '8 days')
    else now() + interval '8 days'
  end;

  v_survivors := case
    when v_payload ? 'survivors' then coalesce(v_payload->'survivors', '{}'::jsonb)
    when v_report.id is not null then coalesce(v_report.survivors, '{}'::jsonb)
    else '{}'::jsonb
  end;

  v_wounds_remaining := case
    when v_payload ? 'wounds_remaining' then coalesce(v_payload->'wounds_remaining', '{}'::jsonb)
    when v_report.id is not null then coalesce(v_report.wounds_remaining, '{}'::jsonb)
    else '{}'::jsonb
  end;

  v_narrative_notes := case
    when v_payload ? 'narrative_notes' then v_payload->>'narrative_notes'
    else v_report.narrative_notes
  end;

  v_casualties := public.validate_battle_survivors_and_wounds(
    target_conflict_id,
    v_survivors,
    v_wounds_remaining
  );

  perform public.apply_battle_outcome(
    target_conflict_id,
    v_winner_faction_id,
    v_final_controller_faction_id,
    v_post_battle_blocked_until,
    v_survivors,
    v_wounds_remaining,
    v_user_id,
    v_final_controller_faction_id,
    v_narrative_notes
  );

  if v_report.id is not null then
    v_report_id := v_report.id;
    v_revision := coalesce(v_report.revision, 1);

    update public.battle_reports
    set
      reporter_user_id = v_user_id,
      reporter_faction_id = null,
      winner_faction_id = v_winner_faction_id,
      final_controller_faction_id = v_final_controller_faction_id,
      casualties = v_casualties,
      survivors = v_survivors,
      wounds_remaining = v_wounds_remaining,
      xp_awards = coalesce(xp_awards, '{}'::jsonb),
      enhancements = coalesce(enhancements, '{}'::jsonb),
      post_battle_blocked_until = v_post_battle_blocked_until,
      narrative_notes = v_narrative_notes,
      battle_mode = v_battle_mode,
      status = 'admin_confirmed',
      resolved_at = now(),
      updated_at = now()
    where id = v_report_id;
  else
    insert into public.battle_reports (
      conflict_id,
      reporter_user_id,
      reporter_faction_id,
      winner_faction_id,
      final_controller_faction_id,
      casualties,
      survivors,
      wounds_remaining,
      xp_awards,
      enhancements,
      post_battle_blocked_until,
      narrative_notes,
      battle_mode,
      revision,
      participant_validations,
      status,
      resolved_at,
      updated_at
    )
    values (
      v_conflict.id,
      v_user_id,
      null,
      v_winner_faction_id,
      v_final_controller_faction_id,
      v_casualties,
      v_survivors,
      v_wounds_remaining,
      '{}'::jsonb,
      '{}'::jsonb,
      v_post_battle_blocked_until,
      v_narrative_notes,
      v_battle_mode,
      1,
      '{}'::jsonb,
      'admin_confirmed',
      now(),
      now()
    )
    returning id into v_report_id;
  end if;

  update public.battle_reports
  set
    status = 'rejected',
    updated_at = now()
  where conflict_id = target_conflict_id
    and id <> v_report_id
    and status in ('draft', 'awaiting_validation', 'players_confirmed', 'submitted', 'disputed');

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'battle_report_admin_confirmed',
    jsonb_build_object(
      'report_id', v_report_id,
      'conflict_id', target_conflict_id,
      'revision', v_revision,
      'direct_resolution', true
    )
  );
end;
$$;

revoke execute on function public.admin_confirm_battle_report(uuid, jsonb) from public;
grant execute on function public.admin_confirm_battle_report(uuid, jsonb) to authenticated;
