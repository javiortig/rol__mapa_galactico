-- Existing campaign systems and conflicts keep their effective 500-point rule.
alter table public.systems
  add column battle_points_limit integer not null default 500
  check (battle_points_limit between 1 and 5000);

alter table public.narrative_attacks
  add column battle_points_limit integer not null default 500
  check (battle_points_limit between 1 and 5000);

alter table public.conflicts
  add column battle_points_limit integer not null default 500
  check (battle_points_limit between 1 and 5000);

create or replace function public.set_conflict_battle_points_limit()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  select coalesce(
    (
      select attack.battle_points_limit
      from public.narrative_attacks as attack
      where attack.system_id = new.system_id
        and attack.narrative_faction_id = new.attacker_faction_id
        and attack.status = 'incoming'
      order by attack.created_at desc
      limit 1
    ),
    (select systems.battle_points_limit from public.systems where id = new.system_id),
    500
  ) into new.battle_points_limit;

  return new;
end;
$$;

create trigger conflicts_set_battle_points_limit
before insert on public.conflicts
for each row
execute function public.set_conflict_battle_points_limit();

create or replace function public.validate_system_battle_side_points(
  target_system_id uuid,
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
  v_limit integer;
begin
  select systems.battle_points_limit into v_limit
  from public.systems
  where systems.id = target_system_id;

  if v_limit is null then
    raise exception 'Sistema objetivo no encontrado';
  end if;

  if coalesce(side_points, 0) > v_limit then
    raise exception 'El % supera el limite de % puntos (% pts)',
      coalesce(side_label, 'bando'), v_limit, side_points;
  end if;
end;
$$;

-- Keep the existing attack and coalition workflows; replace only their
-- roster validation with the target system's limit, including PvE targets.
do $$
declare
  v_item record;
  v_definition text;
  v_anchor text := 'perform public.validate_tabletop_battle_side_points(';
begin
  for v_item in
    select * from (values
      ('public.create_attack_order(jsonb,uuid,uuid)', 'v_target.id'),
      ('public.create_coalition_attack_draft(jsonb,uuid,uuid,uuid[])', 'v_target.id'),
      ('public.join_battle_operation(uuid,jsonb,uuid[])', 'v_operation.target_system_id'),
      ('public.launch_coalition_attack(uuid)', 'v_operation.target_system_id')
    ) as items(signature, system_expression)
  loop
    select pg_get_functiondef(to_regprocedure(v_item.signature)) into v_definition;

    if v_definition is null
      or (length(v_definition) - length(replace(v_definition, v_anchor, ''))) / length(v_anchor) <> 1 then
      raise exception 'No se encontro una unica validacion de puntos en %', v_item.signature;
    end if;

    execute replace(
      v_definition,
      v_anchor,
      'perform public.validate_system_battle_side_points(' || v_item.system_expression || ','
    );
  end loop;
end $$;

create or replace function public.admin_set_system_battle_points_limit(
  target_system_id uuid,
  points_limit integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Solo admin puede cambiar el limite de batalla';
  end if;

  if points_limit is null or points_limit not between 1 and 5000 then
    raise exception 'El limite debe estar entre 1 y 5000 puntos';
  end if;

  update public.systems
  set battle_points_limit = points_limit, updated_at = now()
  where id = target_system_id;

  if not found then
    raise exception 'Sistema no encontrado';
  end if;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (auth.uid(), 'system_battle_points_limit_set',
    jsonb_build_object('system_id', target_system_id, 'battle_points_limit', points_limit));
end;
$$;

create or replace function public.admin_create_narrative_attack(
  target_system_id uuid,
  narrative_faction_id uuid,
  attack_description text,
  arrival_at timestamptz,
  points_limit integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attack_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Solo admin puede crear incursiones narrativas';
  end if;

  if points_limit is null or points_limit not between 1 and 5000 then
    raise exception 'El limite debe estar entre 1 y 5000 puntos';
  end if;

  v_attack_id := public.admin_create_narrative_attack(
    target_system_id, narrative_faction_id, attack_description, arrival_at
  );

  update public.narrative_attacks
  set battle_points_limit = points_limit, updated_at = now()
  where id = v_attack_id;

  return v_attack_id;
end;
$$;

create or replace function public.admin_create_narrative_mission(
  anchor_system_id uuid,
  narrative_faction_id uuid,
  mission_name text,
  mission_description text,
  enemy_units_visible boolean,
  enemy_units jsonb,
  duration_days integer,
  expires_after_battle boolean,
  points_limit integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_system_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Solo admin puede crear misiones narrativas';
  end if;

  if points_limit is null or points_limit not between 1 and 5000 then
    raise exception 'El limite debe estar entre 1 y 5000 puntos';
  end if;

  v_system_id := public.admin_create_narrative_mission(
    anchor_system_id, narrative_faction_id, mission_name, mission_description,
    enemy_units_visible, enemy_units, duration_days, expires_after_battle
  );

  update public.systems
  set battle_points_limit = points_limit, updated_at = now()
  where id = v_system_id;

  update public.missions
  set recommended_points = points_limit::text || ' pts por bando'
  where system_id = v_system_id;

  return v_system_id;
end;
$$;

revoke execute on function public.set_conflict_battle_points_limit() from public;
revoke execute on function public.validate_system_battle_side_points(uuid,uuid,uuid,integer,text) from public;
revoke execute on function public.admin_set_system_battle_points_limit(uuid,integer) from public;
revoke execute on function public.admin_create_narrative_attack(uuid,uuid,text,timestamptz,integer) from public;
revoke execute on function public.admin_create_narrative_mission(uuid,uuid,text,text,boolean,jsonb,integer,boolean,integer) from public;

grant execute on function public.admin_set_system_battle_points_limit(uuid,integer) to authenticated;
grant execute on function public.admin_create_narrative_attack(uuid,uuid,text,timestamptz,integer) to authenticated;
grant execute on function public.admin_create_narrative_mission(uuid,uuid,text,text,boolean,jsonb,integer,boolean,integer) to authenticated;
