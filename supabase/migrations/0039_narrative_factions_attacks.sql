alter table public.factions
  add column if not exists is_narrative boolean not null default false;

update public.factions
set is_narrative = false
where slug in (
  'legiones-daemonicas',
  'agentes-imperium',
  'cultos-genestealer',
  'aeldari',
  'space-marines',
  'adeptus-custodes',
  'necrones'
);

insert into public.factions (slug, name, color, capital_system_id, is_narrative)
values
  ('orcos', 'Orcos', '#84cc16', null, true),
  ('tiranidos', 'Tiranidos', '#a855f7', null, true)
on conflict (slug) do update
set
  name = excluded.name,
  color = excluded.color,
  capital_system_id = null,
  is_narrative = true;

create or replace function public.admin_create_narrative_attack(
  target_system_id uuid,
  narrative_faction_id uuid,
  attack_description text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_system public.systems%rowtype;
  v_faction public.factions%rowtype;
  v_blocked_until timestamptz;
  v_conflict_id uuid := gen_random_uuid();
  v_description text := trim(coalesce(attack_description, ''));
  v_conflict_slug text;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede crear incursiones narrativas';
  end if;

  if length(v_description) < 8 then
    raise exception 'La descripcion del ataque debe tener al menos 8 caracteres';
  end if;

  select *
  into v_system
  from public.systems
  where id = target_system_id
  for update;

  if not found then
    raise exception 'Sistema invalido';
  end if;

  if coalesce(v_system.system_kind, 'standard') = 'gaseous' then
    raise exception 'No se pueden lanzar incursiones narrativas contra sistemas gaseosos';
  end if;

  if v_system.status = 'war'
    or exists (
      select 1
      from public.conflicts
      where conflicts.system_id = v_system.id
        and conflicts.status = 'pending'
    ) then
    raise exception 'Este sistema ya tiene un conflicto pendiente';
  end if;

  if v_system.blocked_until is not null and v_system.blocked_until > now() then
    raise exception 'Este sistema esta bloqueado actualmente';
  end if;

  select *
  into v_faction
  from public.factions
  where id = narrative_faction_id
    and is_narrative = true;

  if not found then
    raise exception 'La faccion seleccionada no es una amenaza narrativa valida';
  end if;

  if v_system.controller_faction_id is not null and v_system.controller_faction_id = v_faction.id then
    raise exception 'La amenaza narrativa ya controla este sistema';
  end if;

  select now() + make_interval(mins => conflict_block_duration_minutes)
  into v_blocked_until
  from public.campaign_settings
  where id = 'default';

  v_blocked_until := coalesce(v_blocked_until, now() + interval '14 days');
  v_conflict_slug :=
    'narrative-' ||
    coalesce(v_faction.slug, v_faction.id::text) ||
    '-' ||
    coalesce(v_system.slug, v_system.id::text) ||
    '-' ||
    replace(replace(replace(clock_timestamp()::text, '-', ''), ':', ''), '.', '');

  insert into public.conflicts (
    id,
    slug,
    system_id,
    attacker_faction_id,
    defender_faction_id,
    status,
    blocked_until,
    notes
  )
  values (
    v_conflict_id,
    v_conflict_slug,
    v_system.id,
    v_faction.id,
    v_system.controller_faction_id,
    'pending',
    v_blocked_until,
    v_description
  );

  update public.systems
  set
    status = 'war',
    blocked_until = v_blocked_until,
    updated_at = now()
  where id = v_system.id;

  update public.campaign_units
  set
    status = 'in_war',
    updated_at = now()
  where current_system_id = v_system.id
    and status = 'ready'
    and quantity > 0;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_narrative_attack_created',
    jsonb_build_object(
      'conflict_id', v_conflict_id,
      'system_id', v_system.id,
      'narrative_faction_id', v_faction.id,
      'defender_faction_id', v_system.controller_faction_id,
      'blocked_until', v_blocked_until,
      'description', v_description
    )
  );

  return v_conflict_id;
end;
$$;

create or replace function public.admin_set_narrative_control(
  target_system_id uuid,
  narrative_faction_id uuid,
  control_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_system public.systems%rowtype;
  v_faction public.factions%rowtype;
  v_description text := nullif(trim(coalesce(control_description, '')), '');
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede entregar control narrativo';
  end if;

  select *
  into v_system
  from public.systems
  where id = target_system_id
  for update;

  if not found then
    raise exception 'Sistema invalido';
  end if;

  if coalesce(v_system.system_kind, 'standard') = 'gaseous' then
    raise exception 'Los sistemas gaseosos no pueden ser controlados';
  end if;

  if not coalesce(v_system.is_conquerable, true) then
    raise exception 'Este sistema no es conquistable';
  end if;

  select *
  into v_faction
  from public.factions
  where id = narrative_faction_id
    and is_narrative = true;

  if not found then
    raise exception 'La faccion seleccionada no es una amenaza narrativa valida';
  end if;

  update public.conflicts
  set
    status = 'cancelled',
    resolved_at = now(),
    notes = coalesce(v_description, notes)
  where system_id = v_system.id
    and status = 'pending';

  update public.systems
  set
    status = 'controlled',
    controller_faction_id = v_faction.id,
    blocked_until = null,
    updated_at = now()
  where id = v_system.id;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_narrative_control_set',
    jsonb_build_object(
      'system_id', v_system.id,
      'narrative_faction_id', v_faction.id,
      'description', v_description
    )
  );

  return v_system.id;
end;
$$;

revoke execute on function public.admin_create_narrative_attack(uuid, uuid, text) from public;
revoke execute on function public.admin_set_narrative_control(uuid, uuid, text) from public;

grant execute on function public.admin_create_narrative_attack(uuid, uuid, text) to authenticated;
grant execute on function public.admin_set_narrative_control(uuid, uuid, text) to authenticated;
