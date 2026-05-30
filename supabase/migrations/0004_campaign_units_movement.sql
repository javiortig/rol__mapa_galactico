alter table public.campaign_settings
  add column if not exists movement_edge_duration_seconds integer not null default 120 check (movement_edge_duration_seconds > 0),
  add column if not exists conflict_block_duration_minutes integer not null default 30 check (conflict_block_duration_minutes > 0);

drop table if exists public.army_units cascade;
drop table if exists public.armies cascade;

create table if not exists public.campaign_units (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  faction_id uuid not null references public.factions(id) on delete cascade,
  unit_template_id uuid references public.unit_templates(id),
  name text not null,
  category text not null,
  points integer not null default 0,
  quantity integer not null default 1 check (quantity > 0),
  experience integer not null default 0,
  rank text,
  enhancement_text text,
  notes text,
  current_system_id uuid references public.systems(id),
  status text not null check (status in ('ready', 'moving', 'in_war')),
  is_visible_publicly boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.movement_orders
  drop constraint if exists movement_orders_army_id_fkey,
  drop column if exists army_id,
  add column if not exists path_system_ids uuid[] not null default '{}',
  add column if not exists segment_count integer not null default 1 check (segment_count > 0),
  add column if not exists duration_seconds integer not null default 120 check (duration_seconds > 0);

create table if not exists public.movement_order_units (
  movement_order_id uuid not null references public.movement_orders(id) on delete cascade,
  unit_id uuid not null references public.campaign_units(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (movement_order_id, unit_id)
);

create index if not exists campaign_units_faction_status_idx on public.campaign_units (faction_id, status);
create index if not exists campaign_units_system_status_idx on public.campaign_units (current_system_id, status);
create index if not exists movement_order_units_unit_id_idx on public.movement_order_units (unit_id);

alter table public.campaign_units enable row level security;
alter table public.movement_order_units enable row level security;

drop policy if exists campaign_units_select_visible_member_or_admin on public.campaign_units;
create policy campaign_units_select_visible_member_or_admin
on public.campaign_units
for select
to authenticated
using (public.is_admin() or is_visible_publicly or public.is_faction_member(faction_id));

drop policy if exists campaign_units_admin_all on public.campaign_units;
create policy campaign_units_admin_all
on public.campaign_units
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists movement_order_units_select_member_or_admin on public.movement_order_units;
create policy movement_order_units_select_member_or_admin
on public.movement_order_units
for select
to authenticated
using (
  exists (
    select 1
    from public.movement_orders
    where movement_orders.id = movement_order_units.movement_order_id
      and (public.is_admin() or public.is_faction_member(movement_orders.faction_id))
  )
);

drop policy if exists movement_order_units_admin_all on public.movement_order_units;
create policy movement_order_units_admin_all
on public.movement_order_units
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop function if exists public.create_movement_order(uuid[], uuid[]);

create or replace function public.resolve_recruitment_queue()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_unit_id uuid;
  v_completed integer := 0;
begin
  for v_item in
    select
      recruitment_queue.*,
      unit_templates.name as unit_name,
      unit_templates.category,
      unit_templates.points,
      factions.capital_system_id
    from public.recruitment_queue
    join public.unit_templates on unit_templates.id = recruitment_queue.unit_template_id
    join public.factions on factions.id = recruitment_queue.faction_id
    where recruitment_queue.status = 'queued'
      and recruitment_queue.finishes_at <= now()
    order by recruitment_queue.finishes_at
    for update of recruitment_queue
  loop
    insert into public.campaign_units (
      slug,
      faction_id,
      unit_template_id,
      name,
      category,
      points,
      quantity,
      experience,
      current_system_id,
      status,
      is_visible_publicly
    )
    values (
      'recruited-' || v_item.id::text,
      v_item.faction_id,
      v_item.unit_template_id,
      v_item.unit_name,
      v_item.category,
      v_item.points,
      v_item.quantity,
      0,
      v_item.capital_system_id,
      'ready',
      false
    )
    returning id into v_unit_id;

    update public.recruitment_queue
    set status = 'completed'
    where id = v_item.id;

    insert into public.campaign_logs (faction_id, action_type, payload)
    values (
      v_item.faction_id,
      'recruitment_completed',
      jsonb_build_object(
        'queue_id', v_item.id,
        'unit_id', v_unit_id,
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

create or replace function public.create_movement_order(unit_ids uuid[], path_system_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_faction_id uuid;
  v_origin_system_id uuid;
  v_destination_system_id uuid;
  v_unit_count integer;
  v_path_length integer;
  v_index integer;
  v_from uuid;
  v_to uuid;
  v_edge public.system_edges%rowtype;
  v_system public.systems%rowtype;
  v_total_cost integer := 0;
  v_resources public.faction_resources%rowtype;
  v_duration_seconds integer;
  v_order_id uuid;
  v_distinct_unit_ids uuid[];
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if unit_ids is null or cardinality(unit_ids) = 0 then
    raise exception 'Selecciona al menos una unidad';
  end if;

  if path_system_ids is null or cardinality(path_system_ids) < 2 then
    raise exception 'La ruta debe tener origen y destino';
  end if;

  select array_agg(unit_id)
  into v_distinct_unit_ids
  from (
    select distinct unnest(unit_ids) as unit_id
  ) distinct_units;

  if cardinality(v_distinct_unit_ids) <> cardinality(unit_ids) then
    raise exception 'La seleccion contiene unidades duplicadas';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  perform 1
  from public.campaign_units
  where id = any(v_distinct_unit_ids)
  for update;

  select count(*)::integer
  into v_unit_count
  from public.campaign_units
  where id = any(v_distinct_unit_ids)
    and status = 'ready';

  if v_unit_count <> cardinality(v_distinct_unit_ids) then
    raise exception 'Todas las unidades deben existir y estar listas';
  end if;

  select faction_id, current_system_id
  into v_faction_id, v_origin_system_id
  from public.campaign_units
  where id = any(v_distinct_unit_ids)
  limit 1;

  if (select count(distinct faction_id) from public.campaign_units where id = any(v_distinct_unit_ids)) <> 1 then
    raise exception 'Todas las unidades deben pertenecer a la misma faccion';
  end if;

  if (select count(distinct current_system_id) from public.campaign_units where id = any(v_distinct_unit_ids)) <> 1 then
    raise exception 'Todas las unidades deben estar en el mismo sistema';
  end if;

  if not v_is_admin and not exists (
    select 1
    from public.player_factions
    where user_id = v_user_id
      and faction_id = v_faction_id
  ) then
    raise exception 'No puedes mover unidades de esta faccion';
  end if;

  if path_system_ids[1] is distinct from v_origin_system_id then
    raise exception 'La ruta debe empezar en el sistema de origen de las unidades';
  end if;

  v_path_length := cardinality(path_system_ids);
  v_destination_system_id := path_system_ids[v_path_length];

  for v_index in 1..v_path_length loop
    select *
    into v_system
    from public.systems
    where id = path_system_ids[v_index];

    if not found then
      raise exception 'La ruta contiene un sistema inexistente';
    end if;

    if v_index > 1 and (v_system.status = 'war' or v_system.blocked_until is not null and v_system.blocked_until > now()) then
      raise exception 'La ruta contiene un sistema bloqueado o en guerra';
    end if;
  end loop;

  for v_index in 1..(v_path_length - 1) loop
    v_from := path_system_ids[v_index];
    v_to := path_system_ids[v_index + 1];

    select *
    into v_edge
    from public.system_edges
    where not is_blocked
      and (
        (from_system_id = v_from and to_system_id = v_to)
        or (from_system_id = v_to and to_system_id = v_from)
      )
    limit 1;

    if not found then
      raise exception 'La ruta contiene un tramo no valido';
    end if;

    v_total_cost := v_total_cost + v_edge.uridium_cost;
  end loop;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found or v_resources.uridium < v_total_cost then
    raise exception 'Uridium insuficiente';
  end if;

  select movement_edge_duration_seconds * (v_path_length - 1)
  into v_duration_seconds
  from public.campaign_settings
  where id = 'default';

  v_duration_seconds := coalesce(v_duration_seconds, 120 * (v_path_length - 1));

  update public.faction_resources
  set
    uridium = uridium - v_total_cost,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.movement_orders (
    faction_id,
    from_system_id,
    to_system_id,
    uridium_cost,
    started_at,
    arrival_at,
    status,
    path_system_ids,
    segment_count,
    duration_seconds
  )
  values (
    v_faction_id,
    v_origin_system_id,
    v_destination_system_id,
    v_total_cost,
    now(),
    now() + make_interval(secs => v_duration_seconds),
    'moving',
    path_system_ids,
    v_path_length - 1,
    v_duration_seconds
  )
  returning id into v_order_id;

  insert into public.movement_order_units (movement_order_id, unit_id)
  select v_order_id, unnest(v_distinct_unit_ids);

  update public.campaign_units
  set
    status = 'moving',
    updated_at = now()
  where id = any(v_distinct_unit_ids);

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'movement_started',
    jsonb_build_object(
      'movement_order_id', v_order_id,
      'unit_ids', to_jsonb(v_distinct_unit_ids),
      'path_system_ids', to_jsonb(path_system_ids),
      'uridium_cost', v_total_cost,
      'duration_seconds', v_duration_seconds
    )
  );

  return v_order_id;
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

      update public.campaign_units
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

  update public.campaign_units
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

grant execute on function public.create_movement_order(uuid[], uuid[]) to authenticated;
