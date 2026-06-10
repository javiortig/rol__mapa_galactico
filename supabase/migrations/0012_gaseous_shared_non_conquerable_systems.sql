alter table public.systems
  add column if not exists system_kind text not null default 'standard',
  add column if not exists is_conquerable boolean not null default true,
  add column if not exists allows_shared_occupation boolean not null default false;

update public.systems
set
  system_kind = coalesce(system_kind, 'standard'),
  is_conquerable = coalesce(is_conquerable, true),
  allows_shared_occupation = coalesce(allows_shared_occupation, false);

update public.systems
set
  system_kind = 'gaseous',
  is_conquerable = false,
  allows_shared_occupation = true,
  status = 'neutral',
  controller_faction_id = null,
  blocked_until = null,
  updated_at = now()
where slug in ('nexus-aster', 'ashen-road');

update public.systems
set
  status = 'neutral',
  controller_faction_id = null,
  blocked_until = null,
  updated_at = now()
where not is_conquerable
  and (status <> 'neutral' or controller_faction_id is not null or blocked_until is not null);

update public.conflicts
set
  status = 'cancelled',
  resolved_at = coalesce(resolved_at, now()),
  blocked_until = null,
  notes = concat_ws(' | ', nullif(notes, ''), 'Cancelado: sistema no conquistable/compartido')
where status = 'pending'
  and system_id in (
    select id
    from public.systems
    where not is_conquerable or allows_shared_occupation
  );

update public.campaign_units
set
  status = 'ready',
  updated_at = now()
where status = 'in_war'
  and current_system_id in (
    select id
    from public.systems
    where not is_conquerable or allows_shared_occupation
  );

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.systems'::regclass
      and conname = 'systems_system_kind_allowed_check'
  ) then
    alter table public.systems
      add constraint systems_system_kind_allowed_check
      check (system_kind in ('standard', 'gaseous'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.systems'::regclass
      and conname = 'systems_gaseous_requires_shared_non_conquerable_check'
  ) then
    alter table public.systems
      add constraint systems_gaseous_requires_shared_non_conquerable_check
      check (system_kind <> 'gaseous' or (allows_shared_occupation and not is_conquerable));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.systems'::regclass
      and conname = 'systems_non_conquerable_must_stay_neutral_check'
  ) then
    alter table public.systems
      add constraint systems_non_conquerable_must_stay_neutral_check
      check (
        is_conquerable
        or (
          status = 'neutral'
          and controller_faction_id is null
          and blocked_until is null
        )
      );
  end if;
end $$;

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

    if coalesce(v_system.allows_shared_occupation, false) or not coalesce(v_system.is_conquerable, true) then
      update public.systems
      set
        status = 'neutral',
        controller_faction_id = null,
        blocked_until = null,
        updated_at = now()
      where id = v_order.to_system_id;

      update public.campaign_units
      set
        current_system_id = v_order.to_system_id,
        status = 'ready',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );

      update public.campaign_units
      set
        status = 'ready',
        updated_at = now()
      where current_system_id = v_order.to_system_id
        and status = 'in_war';

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'movement_completed_shared',
        jsonb_build_object('movement_order_id', v_order.id, 'system_id', v_order.to_system_id)
      );
    elsif v_system.status = 'war' then
      update public.campaign_units
      set
        current_system_id = v_order.to_system_id,
        status = 'in_war',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'movement_arrived_locked',
        jsonb_build_object('movement_order_id', v_order.id, 'system_id', v_order.to_system_id)
      );
    elsif v_system.controller_faction_id is null
      or v_system.controller_faction_id is distinct from v_order.faction_id then
      select now() + make_interval(mins => conflict_block_duration_minutes)
      into v_blocked_until
      from public.campaign_settings
      where id = 'default';

      v_blocked_until := coalesce(v_blocked_until, now() + interval '30 minutes');

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

      update public.campaign_units
      set
        current_system_id = v_order.to_system_id,
        status = 'in_war',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );

      update public.campaign_units
      set
        status = 'in_war',
        updated_at = now()
      where current_system_id = v_order.to_system_id
        and status = 'ready'
        and quantity > 0
        and v_system.controller_faction_id is not null
        and faction_id = v_system.controller_faction_id;

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
      update public.campaign_units
      set
        current_system_id = v_order.to_system_id,
        status = 'ready',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      );

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
  v_target_system public.systems%rowtype;
  v_effective_final_controller_faction_id uuid;
  v_effective_post_battle_blocked_until timestamptz;
  v_unit public.campaign_units%rowtype;
  v_survivors integer;
  v_wounds integer;
  v_retreat_system_id uuid;
begin
  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id
  for update;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  select *
  into v_target_system
  from public.systems
  where id = v_conflict.system_id
  for update;

  if not found then
    raise exception 'Sistema del conflicto no encontrado';
  end if;

  v_effective_final_controller_faction_id := apply_battle_outcome.final_controller_faction_id;
  v_effective_post_battle_blocked_until := apply_battle_outcome.post_battle_blocked_until;

  if not coalesce(v_target_system.is_conquerable, true) or coalesce(v_target_system.allows_shared_occupation, false) then
    v_effective_final_controller_faction_id := null;
    v_effective_post_battle_blocked_until := null;
  end if;

  perform public.validate_battle_survivors_and_wounds(target_conflict_id, survivors, wounds_remaining);

  update public.conflicts
  set
    status = 'resolved',
    winner_faction_id = apply_battle_outcome.winner_faction_id,
    blocked_until = v_effective_post_battle_blocked_until,
    resolved_at = now(),
    notes = coalesce(apply_battle_outcome.narrative_notes, notes)
  where id = target_conflict_id;

  update public.systems
  set
    status = case when v_effective_final_controller_faction_id is null then 'neutral' else 'controlled' end,
    controller_faction_id = v_effective_final_controller_faction_id,
    blocked_until = v_effective_post_battle_blocked_until,
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

    if v_survivors = 0 then
      update public.campaign_units
      set
        quantity = 0,
        wounds_taken = 0,
        status = 'destroyed',
        destroyed_at = now(),
        updated_at = now()
      where id = v_unit.id;
    elsif v_effective_final_controller_faction_id is null
      or v_unit.faction_id is not distinct from v_effective_final_controller_faction_id then
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
      else
        update public.campaign_units
        set
          quantity = v_survivors,
          wounds_taken = v_wounds,
          current_system_id = v_retreat_system_id,
          status = 'ready',
          updated_at = now()
        where id = v_unit.id;
      end if;
    end if;
  end loop;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    apply_battle_outcome.actor_user_id,
    apply_battle_outcome.actor_faction_id,
    'battle_outcome_applied',
    jsonb_build_object(
      'conflict_id', target_conflict_id,
      'winner_faction_id', apply_battle_outcome.winner_faction_id,
      'final_controller_faction_id', v_effective_final_controller_faction_id,
      'survivors', survivors,
      'wounds_remaining', wounds_remaining
    )
  );
end;
$$;
