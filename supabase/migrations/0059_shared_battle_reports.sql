alter table public.battle_reports
  add column if not exists battle_mode text not null default 'tabletop',
  add column if not exists revision integer not null default 1,
  add column if not exists participant_validations jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.battle_reports'::regclass
      and contype = 'c'
      and (
        pg_get_constraintdef(oid) ilike '%status%'
        or pg_get_constraintdef(oid) ilike '%battle_mode%'
        or pg_get_constraintdef(oid) ilike '%revision%'
      )
  loop
    execute format('alter table public.battle_reports drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

alter table public.battle_reports
  add constraint battle_reports_status_check
    check (status in (
      'draft',
      'awaiting_validation',
      'players_confirmed',
      'submitted',
      'auto_confirmed',
      'admin_confirmed',
      'disputed',
      'rejected'
    )),
  add constraint battle_reports_battle_mode_check
    check (battle_mode in ('tabletop', 'autoresolve')),
  add constraint battle_reports_revision_check
    check (revision > 0);

create index if not exists battle_reports_conflict_updated_idx
on public.battle_reports (conflict_id, updated_at desc);

create or replace function public.get_battle_report_required_faction_ids(target_conflict_id uuid)
returns table (faction_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select distinct participant_id as faction_id
  from (
    select conflicts.attacker_faction_id as participant_id
    from public.conflicts
    where conflicts.id = target_conflict_id

    union all

    select conflicts.defender_faction_id as participant_id
    from public.conflicts
    where conflicts.id = target_conflict_id

    union all

    select campaign_units.faction_id as participant_id
    from public.conflicts
    join public.campaign_units
      on campaign_units.current_system_id = conflicts.system_id
      and campaign_units.status = 'in_war'
      and campaign_units.quantity > 0
    where conflicts.id = target_conflict_id

    union all

    select battle_unit_commitments.faction_id as participant_id
    from public.conflicts
    join public.battle_unit_commitments
      on battle_unit_commitments.operation_id = conflicts.battle_operation_id
      and battle_unit_commitments.status not in ('returned', 'destroyed', 'cancelled')
    where conflicts.id = target_conflict_id
  ) participants
  where participant_id is not null;
$$;

drop policy if exists battle_reports_select_owner_participant_or_admin on public.battle_reports;
create policy battle_reports_select_owner_participant_or_admin
on public.battle_reports
for select
to authenticated
using (
  public.is_admin()
  or reporter_user_id = auth.uid()
  or exists (
    select 1
    from public.player_factions
    where player_factions.user_id = auth.uid()
      and exists (
        select 1
        from public.get_battle_report_required_faction_ids(battle_reports.conflict_id) required_factions
        where required_factions.faction_id = player_factions.faction_id
      )
  )
);

create or replace function public.submit_battle_report(conflict_id uuid, report_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.conflicts%rowtype;
  v_existing public.battle_reports%rowtype;
  v_reporter_faction_id uuid;
  v_is_admin boolean := false;
  v_is_conquerable_system boolean := true;
  v_report_id uuid;
  v_winner_faction_id uuid;
  v_final_controller_faction_id uuid;
  v_post_battle_blocked_until timestamptz;
  v_casualties jsonb;
  v_survivors jsonb;
  v_wounds_remaining jsonb;
  v_battle_mode text;
  v_revision integer;
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

  select coalesce(systems.is_conquerable, true)
  into v_is_conquerable_system
  from public.systems
  where systems.id = v_conflict.system_id;

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

  if not v_is_admin and v_reporter_faction_id is null then
    raise exception 'Solo participantes o admin pueden editar esta batalla';
  end if;

  v_battle_mode := coalesce(nullif(report_payload->>'battle_mode', ''), 'tabletop');

  if v_battle_mode not in ('tabletop', 'autoresolve') then
    raise exception 'Modo de batalla no valido';
  end if;

  v_winner_faction_id := nullif(report_payload->>'winner_faction_id', '')::uuid;
  v_survivors := coalesce(report_payload->'survivors', '{}'::jsonb);
  v_wounds_remaining := coalesce(report_payload->'wounds_remaining', '{}'::jsonb);

  if v_winner_faction_id is not null
    and v_winner_faction_id not in (v_conflict.attacker_faction_id, v_conflict.defender_faction_id) then
    raise exception 'La faccion ganadora debe participar en el conflicto';
  end if;

  v_final_controller_faction_id := case
    when v_is_conquerable_system then v_winner_faction_id
    else null
  end;
  v_post_battle_blocked_until := now() + interval '7 days';

  v_casualties := public.validate_battle_survivors_and_wounds(
    v_conflict.id,
    v_survivors,
    v_wounds_remaining
  );

  select *
  into v_existing
  from public.battle_reports
  where battle_reports.conflict_id = v_conflict.id
    and battle_reports.status in (
      'draft',
      'awaiting_validation',
      'players_confirmed',
      'submitted',
      'auto_confirmed',
      'disputed'
    )
  order by battle_reports.updated_at desc, battle_reports.created_at desc
  limit 1
  for update;

  if found then
    v_revision := coalesce(v_existing.revision, 1) + 1;

    update public.battle_reports
    set
      reporter_user_id = v_user_id,
      reporter_faction_id = v_reporter_faction_id,
      winner_faction_id = v_winner_faction_id,
      final_controller_faction_id = v_final_controller_faction_id,
      casualties = v_casualties,
      survivors = v_survivors,
      wounds_remaining = v_wounds_remaining,
      xp_awards = '{}'::jsonb,
      enhancements = '{}'::jsonb,
      post_battle_blocked_until = v_post_battle_blocked_until,
      narrative_notes = report_payload->>'narrative_notes',
      battle_mode = v_battle_mode,
      revision = v_revision,
      participant_validations = '{}'::jsonb,
      status = 'awaiting_validation',
      resolved_at = null,
      updated_at = now()
    where id = v_existing.id
    returning id into v_report_id;
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
      updated_at
    )
    values (
      v_conflict.id,
      v_user_id,
      v_reporter_faction_id,
      v_winner_faction_id,
      v_final_controller_faction_id,
      v_casualties,
      v_survivors,
      v_wounds_remaining,
      '{}'::jsonb,
      '{}'::jsonb,
      v_post_battle_blocked_until,
      report_payload->>'narrative_notes',
      v_battle_mode,
      1,
      '{}'::jsonb,
      'awaiting_validation',
      now()
    )
    returning id into v_report_id;
  end if;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_reporter_faction_id,
    'battle_report_shared_saved',
    jsonb_build_object(
      'report_id', v_report_id,
      'conflict_id', v_conflict.id,
      'battle_mode', v_battle_mode
    )
  );

  return v_report_id;
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

  perform public.validate_battle_survivors_and_wounds(
    v_conflict.id,
    coalesce(v_report.survivors, '{}'::jsonb),
    coalesce(v_report.wounds_remaining, '{}'::jsonb)
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

  update public.battle_reports
  set
    participant_validations = v_validations,
    status = case when v_all_validated then 'players_confirmed' else 'awaiting_validation' end,
    resolved_at = case when v_all_validated then now() else null end,
    updated_at = now()
  where id = v_report.id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_reporter_faction_id,
    case when v_all_validated then 'battle_report_players_confirmed' else 'battle_report_validated' end,
    jsonb_build_object(
      'report_id', v_report.id,
      'conflict_id', v_conflict.id,
      'revision', v_report.revision
    )
  );

  return v_report.id;
end;
$$;

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
  v_is_conquerable_system boolean := true;
  v_winner_faction_id uuid;
  v_final_controller_faction_id uuid;
  v_post_battle_blocked_until timestamptz;
  v_survivors jsonb;
  v_wounds_remaining jsonb;
  v_battle_mode text;
  v_narrative_notes text;
  v_casualties jsonb;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede confirmar batallas';
  end if;

  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id;

  if not found then
    raise exception 'Conflicto no encontrado';
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

  if not found then
    raise exception 'No hay informe de batalla para confirmar';
  end if;

  if v_report.status <> 'players_confirmed' then
    raise exception 'Todos los participantes deben validar el informe antes de la confirmacion admin';
  end if;

  v_battle_mode := case
    when v_payload ? 'battle_mode' then coalesce(nullif(v_payload->>'battle_mode', ''), 'tabletop')
    else v_report.battle_mode
  end;

  if v_battle_mode not in ('tabletop', 'autoresolve') then
    raise exception 'Modo de batalla no valido';
  end if;

  v_winner_faction_id := case
    when v_payload ? 'winner_faction_id' then nullif(v_payload->>'winner_faction_id', '')::uuid
    else v_report.winner_faction_id
  end;
  v_final_controller_faction_id := case
    when v_payload ? 'final_controller_faction_id' then nullif(v_payload->>'final_controller_faction_id', '')::uuid
    when v_is_conquerable_system then coalesce(v_report.final_controller_faction_id, v_winner_faction_id)
    else null
  end;
  v_post_battle_blocked_until := case
    when v_payload ? 'post_battle_blocked_until' then nullif(v_payload->>'post_battle_blocked_until', '')::timestamptz
    else coalesce(v_report.post_battle_blocked_until, now() + interval '7 days')
  end;
  v_survivors := case
    when v_payload ? 'survivors' then coalesce(v_payload->'survivors', '{}'::jsonb)
    else coalesce(v_report.survivors, '{}'::jsonb)
  end;
  v_wounds_remaining := case
    when v_payload ? 'wounds_remaining' then coalesce(v_payload->'wounds_remaining', '{}'::jsonb)
    else coalesce(v_report.wounds_remaining, '{}'::jsonb)
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

  update public.battle_reports
  set
    winner_faction_id = v_winner_faction_id,
    final_controller_faction_id = v_final_controller_faction_id,
    casualties = v_casualties,
    survivors = v_survivors,
    wounds_remaining = v_wounds_remaining,
    post_battle_blocked_until = v_post_battle_blocked_until,
    narrative_notes = v_narrative_notes,
    battle_mode = v_battle_mode,
    status = 'admin_confirmed',
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

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'battle_report_admin_confirmed',
    jsonb_build_object(
      'report_id', v_report.id,
      'conflict_id', target_conflict_id,
      'revision', v_report.revision
    )
  );
end;
$$;

revoke execute on function public.validate_battle_report(uuid) from public;
revoke execute on function public.admin_confirm_battle_report(uuid, jsonb) from public;
revoke execute on function public.get_battle_report_required_faction_ids(uuid) from public;

grant execute on function public.submit_battle_report(uuid, jsonb) to authenticated;
grant execute on function public.validate_battle_report(uuid) to authenticated;
grant execute on function public.admin_confirm_battle_report(uuid, jsonb) to authenticated;
grant execute on function public.get_battle_report_required_faction_ids(uuid) to authenticated;
