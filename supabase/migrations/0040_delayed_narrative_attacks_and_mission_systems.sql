alter table public.systems
  add column if not exists is_temporary_mission boolean not null default false,
  add column if not exists mission_threat_faction_id uuid references public.factions(id) on delete set null,
  add column if not exists mission_enemy_units_visible boolean not null default false,
  add column if not exists mission_enemy_units jsonb not null default '[]'::jsonb,
  add column if not exists mission_expires_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'systems_mission_enemy_units_array_check'
      and conrelid = 'public.systems'::regclass
  ) then
    alter table public.systems
      add constraint systems_mission_enemy_units_array_check
      check (jsonb_typeof(mission_enemy_units) = 'array');
  end if;
end;
$$;

create table if not exists public.narrative_attacks (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  narrative_faction_id uuid not null references public.factions(id) on delete cascade,
  description text not null,
  arrival_at timestamptz not null,
  status text not null default 'incoming' check (status in ('incoming', 'arrived', 'cancelled')),
  conflict_id uuid references public.conflicts(id) on delete set null,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists narrative_attacks_system_status_idx
on public.narrative_attacks (system_id, status);

create index if not exists narrative_attacks_arrival_idx
on public.narrative_attacks (status, arrival_at);

alter table public.narrative_attacks enable row level security;

drop policy if exists narrative_attacks_select_public on public.narrative_attacks;
create policy narrative_attacks_select_public
on public.narrative_attacks
for select
to anon, authenticated
using (true);

drop policy if exists narrative_attacks_admin_all on public.narrative_attacks;
create policy narrative_attacks_admin_all
on public.narrative_attacks
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.get_visible_systems()
returns table (
  id uuid,
  slug text,
  name text,
  x numeric,
  y numeric,
  size numeric,
  star_class text,
  type text,
  status text,
  controller_faction_id uuid,
  blocked_until timestamptz,
  public_description text,
  secret_admin_notes text,
  mission_id uuid,
  is_capital boolean,
  created_at timestamptz,
  updated_at timestamptz,
  system_kind text,
  is_conquerable boolean,
  allows_shared_occupation boolean,
  building_slots integer,
  is_temporary_mission boolean,
  mission_threat_faction_id uuid,
  mission_enemy_units_visible boolean,
  mission_enemy_units jsonb,
  mission_expires_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    systems.id,
    systems.slug,
    systems.name,
    systems.x,
    systems.y,
    systems.size,
    systems.star_class,
    systems.type,
    systems.status,
    systems.controller_faction_id,
    systems.blocked_until,
    systems.public_description,
    case when public.is_admin() then systems.secret_admin_notes else null::text end as secret_admin_notes,
    systems.mission_id,
    systems.is_capital,
    systems.created_at,
    systems.updated_at,
    systems.system_kind,
    systems.is_conquerable,
    systems.allows_shared_occupation,
    systems.building_slots,
    systems.is_temporary_mission,
    systems.mission_threat_faction_id,
    systems.mission_enemy_units_visible,
    case
      when public.is_admin() or systems.mission_enemy_units_visible
      then systems.mission_enemy_units
      else '[]'::jsonb
    end as mission_enemy_units,
    systems.mission_expires_at
  from public.systems
  order by systems.name;
$$;

create or replace function public.admin_create_narrative_attack(
  target_system_id uuid,
  narrative_faction_id uuid,
  attack_description text,
  arrival_at timestamptz
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
  v_attack_id uuid := gen_random_uuid();
  v_description text := trim(coalesce(attack_description, ''));
  v_arrival_at timestamptz := coalesce(admin_create_narrative_attack.arrival_at, now() + interval '1 day');
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede crear incursiones narrativas';
  end if;

  if length(v_description) < 8 then
    raise exception 'La descripcion del ataque debe tener al menos 8 caracteres';
  end if;

  if v_arrival_at <= now() then
    raise exception 'La llegada del ataque debe estar en el futuro';
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

  if coalesce(v_system.is_temporary_mission, false) then
    raise exception 'Las incursiones narrativas se lanzan contra sistemas normales, no misiones temporales';
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

  if exists (
    select 1
    from public.narrative_attacks
    where narrative_attacks.system_id = v_system.id
      and narrative_attacks.status = 'incoming'
  ) then
    raise exception 'Este sistema ya tiene una amenaza narrativa entrante';
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

  insert into public.narrative_attacks (
    id,
    system_id,
    narrative_faction_id,
    description,
    arrival_at,
    status,
    created_by_user_id
  )
  values (
    v_attack_id,
    v_system.id,
    v_faction.id,
    v_description,
    v_arrival_at,
    'incoming',
    v_user_id
  );

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_narrative_attack_scheduled',
    jsonb_build_object(
      'narrative_attack_id', v_attack_id,
      'system_id', v_system.id,
      'narrative_faction_id', v_faction.id,
      'arrival_at', v_arrival_at,
      'description', v_description
    )
  );

  return v_attack_id;
end;
$$;

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
begin
  return public.admin_create_narrative_attack(
    target_system_id,
    narrative_faction_id,
    attack_description,
    now() + interval '1 day'
  );
end;
$$;

create or replace function public.resolve_narrative_attacks()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attack public.narrative_attacks%rowtype;
  v_system public.systems%rowtype;
  v_blocked_until timestamptz;
  v_conflict_id uuid;
  v_conflict_slug text;
  v_resolved integer := 0;
begin
  for v_attack in
    select *
    from public.narrative_attacks
    where status = 'incoming'
      and arrival_at <= now()
    order by arrival_at, created_at
    for update skip locked
  loop
    select *
    into v_system
    from public.systems
    where id = v_attack.system_id
    for update;

    if not found then
      update public.narrative_attacks
      set status = 'cancelled', updated_at = now()
      where id = v_attack.id;
      continue;
    end if;

    if v_system.status = 'war'
      or (v_system.blocked_until is not null and v_system.blocked_until > now())
      or exists (
        select 1
        from public.conflicts
        where conflicts.system_id = v_system.id
          and conflicts.status = 'pending'
      ) then
      update public.narrative_attacks
      set status = 'cancelled', updated_at = now()
      where id = v_attack.id;

      insert into public.campaign_logs (action_type, payload)
      values (
        'narrative_attack_cancelled',
        jsonb_build_object(
          'narrative_attack_id', v_attack.id,
          'system_id', v_system.id,
          'reason', 'system_unavailable_on_arrival'
        )
      );
      continue;
    end if;

    select now() + make_interval(mins => conflict_block_duration_minutes)
    into v_blocked_until
    from public.campaign_settings
    where id = 'default';

    v_blocked_until := coalesce(v_blocked_until, now() + interval '14 days');
    v_conflict_id := gen_random_uuid();
    v_conflict_slug :=
      'narrative-' ||
      v_attack.id::text ||
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
      v_attack.narrative_faction_id,
      v_system.controller_faction_id,
      'pending',
      v_blocked_until,
      v_attack.description
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

    update public.narrative_attacks
    set
      status = 'arrived',
      conflict_id = v_conflict_id,
      updated_at = now()
    where id = v_attack.id;

    insert into public.campaign_logs (action_type, payload)
    values (
      'narrative_attack_arrived',
      jsonb_build_object(
        'narrative_attack_id', v_attack.id,
        'conflict_id', v_conflict_id,
        'system_id', v_system.id,
        'narrative_faction_id', v_attack.narrative_faction_id,
        'defender_faction_id', v_system.controller_faction_id,
        'blocked_until', v_blocked_until
      )
    );

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

create or replace function public.admin_create_narrative_mission(
  anchor_system_id uuid,
  narrative_faction_id uuid,
  mission_name text,
  mission_description text,
  enemy_units_visible boolean default false,
  enemy_units jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_anchor public.systems%rowtype;
  v_faction public.factions%rowtype;
  v_system_id uuid := gen_random_uuid();
  v_mission_id uuid := gen_random_uuid();
  v_name text := trim(coalesce(mission_name, ''));
  v_description text := trim(coalesce(mission_description, ''));
  v_enemy_units jsonb := coalesce(enemy_units, '[]'::jsonb);
  v_index integer;
  v_angle double precision;
  v_distance double precision;
  v_x numeric;
  v_y numeric;
  v_base_slug text;
  v_system_slug text;
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede crear misiones narrativas';
  end if;

  if length(v_name) < 3 then
    raise exception 'El nombre de la mision debe tener al menos 3 caracteres';
  end if;

  if length(v_description) < 8 then
    raise exception 'La descripcion narrativa debe tener al menos 8 caracteres';
  end if;

  if jsonb_typeof(v_enemy_units) <> 'array' then
    raise exception 'La lista de tropas enemigas debe ser un array JSON';
  end if;

  select *
  into v_anchor
  from public.systems
  where id = anchor_system_id
  for update;

  if not found then
    raise exception 'Sistema de anclaje invalido';
  end if;

  if coalesce(v_anchor.system_kind, 'standard') = 'gaseous'
    or coalesce(v_anchor.is_temporary_mission, false) then
    raise exception 'La mision debe conectarse a un sistema normal';
  end if;

  select *
  into v_faction
  from public.factions
  where id = narrative_faction_id
    and is_narrative = true;

  if not found then
    raise exception 'La faccion seleccionada no es una amenaza narrativa valida';
  end if;

  select count(*)
  into v_index
  from public.systems
  where is_temporary_mission;

  v_angle := 0.7 + (v_index % 12) * 0.52;
  v_distance := 120 + (v_index % 3) * 32;
  v_x := round((v_anchor.x::double precision + cos(v_angle) * v_distance)::numeric, 2);
  v_y := round((v_anchor.y::double precision + sin(v_angle) * v_distance)::numeric, 2);
  v_base_slug := trim(both '-' from regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
  v_system_slug := 'mission-' || coalesce(nullif(v_base_slug, ''), 'objetivo') || '-' || substr(v_system_id::text, 1, 8);

  insert into public.systems (
    id,
    slug,
    name,
    x,
    y,
    size,
    star_class,
    type,
    status,
    controller_faction_id,
    public_description,
    is_capital,
    building_slots,
    system_kind,
    is_conquerable,
    allows_shared_occupation,
    is_temporary_mission,
    mission_threat_faction_id,
    mission_enemy_units_visible,
    mission_enemy_units
  )
  values (
    v_system_id,
    v_system_slug,
    v_name,
    v_x,
    v_y,
    1.05,
    case when v_faction.slug = 'tiranidos' then 'violet' else 'green' end,
    'Mision narrativa temporal',
    'controlled',
    v_faction.id,
    v_description,
    false,
    0,
    'standard',
    true,
    false,
    true,
    v_faction.id,
    coalesce(enemy_units_visible, false),
    v_enemy_units
  );

  insert into public.system_edges (
    slug,
    from_system_id,
    to_system_id,
    uridium_cost,
    is_blocked
  )
  values (
    'mission-route-' || substr(v_system_id::text, 1, 8),
    v_anchor.id,
    v_system_id,
    1,
    false
  );

  insert into public.system_production (system_id)
  values (v_system_id)
  on conflict (system_id) do nothing;

  insert into public.missions (
    id,
    system_id,
    title,
    narrative_description,
    recommended_points,
    objectives,
    special_rules,
    victory_conditions,
    admin_notes
  )
  values (
    v_mission_id,
    v_system_id,
    v_name,
    v_description,
    'Evento narrativo',
    'Atacar el sistema temporal y resolver la batalla fisica con el administrador.',
    'La amenaza narrativa esta controlada por el administrador.',
    'El administrador aplica el resultado narrativo tras el reporte.',
    jsonb_build_object(
      'anchor_system_id', v_anchor.id,
      'narrative_faction_id', v_faction.id,
      'enemy_units_visible', coalesce(enemy_units_visible, false)
    )::text
  );

  update public.systems
  set mission_id = v_mission_id
  where id = v_system_id;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_narrative_mission_created',
    jsonb_build_object(
      'system_id', v_system_id,
      'mission_id', v_mission_id,
      'anchor_system_id', v_anchor.id,
      'narrative_faction_id', v_faction.id,
      'enemy_units_visible', coalesce(enemy_units_visible, false),
      'enemy_units', v_enemy_units
    )
  );

  return v_system_id;
end;
$$;

revoke execute on function public.get_visible_systems() from public;
revoke execute on function public.admin_create_narrative_attack(uuid, uuid, text, timestamptz) from public;
revoke execute on function public.admin_create_narrative_attack(uuid, uuid, text) from public;
revoke execute on function public.resolve_narrative_attacks() from public;
revoke execute on function public.admin_create_narrative_mission(uuid, uuid, text, text, boolean, jsonb) from public;

grant execute on function public.get_visible_systems() to anon, authenticated;
grant execute on function public.admin_create_narrative_attack(uuid, uuid, text, timestamptz) to authenticated;
grant execute on function public.admin_create_narrative_attack(uuid, uuid, text) to authenticated;
grant execute on function public.resolve_narrative_attacks() to authenticated;
grant execute on function public.admin_create_narrative_mission(uuid, uuid, text, text, boolean, jsonb) to authenticated;
