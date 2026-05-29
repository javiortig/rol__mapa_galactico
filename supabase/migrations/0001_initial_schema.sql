create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null check (role in ('admin', 'player', 'spectator')),
  created_at timestamptz not null default now()
);

create table public.factions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  color text not null,
  emblem_url text,
  capital_system_id uuid,
  created_at timestamptz not null default now()
);

create table public.player_factions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  faction_id uuid not null references public.factions(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, faction_id)
);

create table public.systems (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  x numeric not null,
  y numeric not null,
  size numeric not null default 1,
  star_class text check (star_class in ('blue', 'white', 'yellow', 'orange', 'red', 'violet', 'green')),
  type text not null,
  status text not null check (status in ('neutral', 'controlled', 'war')),
  controller_faction_id uuid references public.factions(id),
  blocked_until timestamptz,
  public_description text not null default '',
  secret_admin_notes text,
  mission_id uuid,
  is_capital boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.factions
  add constraint factions_capital_system_id_fkey
  foreign key (capital_system_id) references public.systems(id);

create table public.system_edges (
  id uuid primary key default gen_random_uuid(),
  from_system_id uuid not null references public.systems(id) on delete cascade,
  to_system_id uuid not null references public.systems(id) on delete cascade,
  uridium_cost integer not null default 1 check (uridium_cost > 0),
  is_blocked boolean not null default false,
  created_at timestamptz not null default now(),
  check (from_system_id <> to_system_id)
);

create table public.faction_resources (
  faction_id uuid primary key references public.factions(id) on delete cascade,
  supply integer not null default 0,
  minerals integer not null default 0,
  ancestral_stone integer not null default 0,
  uridium integer not null default 0,
  technology integer not null default 0,
  updated_at timestamptz not null default now()
);

create table public.system_production (
  system_id uuid primary key references public.systems(id) on delete cascade,
  supply_per_tick integer not null default 0,
  minerals_per_tick integer not null default 0,
  ancestral_stone_per_tick integer not null default 0,
  uridium_per_tick integer not null default 0,
  technology_per_tick integer not null default 0
);

create table public.campaign_settings (
  id text primary key default 'default',
  resource_tick_interval_hours integer not null default 24 check (resource_tick_interval_hours > 0),
  last_resource_tick_at timestamptz,
  next_resource_tick_at timestamptz,
  updated_at timestamptz not null default now()
);

insert into public.campaign_settings (id, resource_tick_interval_hours, next_resource_tick_at)
values ('default', 24, now() + interval '24 hours')
on conflict (id) do nothing;

create table public.armies (
  id uuid primary key default gen_random_uuid(),
  faction_id uuid not null references public.factions(id) on delete cascade,
  name text not null,
  current_system_id uuid references public.systems(id),
  status text not null check (status in ('ready', 'moving', 'in_war')),
  points_total integer not null default 0,
  is_visible_publicly boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.army_units (
  id uuid primary key default gen_random_uuid(),
  army_id uuid not null references public.armies(id) on delete cascade,
  name text not null,
  points integer not null,
  quantity integer not null default 1,
  experience integer not null default 0,
  rank text,
  enhancement_text text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.unit_templates (
  id uuid primary key default gen_random_uuid(),
  faction_id uuid not null references public.factions(id) on delete cascade,
  name text not null,
  category text not null,
  points integer not null,
  supply_cost integer not null default 0,
  minerals_cost integer not null default 0,
  ancestral_stone_cost integer not null default 0,
  uridium_cost integer not null default 0,
  technology_cost integer not null default 0,
  recruitment_time_seconds integer not null,
  requirements jsonb,
  notes text,
  is_available boolean not null default true
);

create table public.recruitment_queue (
  id uuid primary key default gen_random_uuid(),
  faction_id uuid not null references public.factions(id) on delete cascade,
  unit_template_id uuid not null references public.unit_templates(id),
  quantity integer not null default 1,
  supply_cost integer not null default 0,
  minerals_cost integer not null default 0,
  ancestral_stone_cost integer not null default 0,
  uridium_cost integer not null default 0,
  technology_cost integer not null default 0,
  started_at timestamptz not null default now(),
  finishes_at timestamptz not null,
  status text not null check (status in ('queued', 'completed', 'cancelled')),
  created_at timestamptz not null default now()
);

create table public.movement_orders (
  id uuid primary key default gen_random_uuid(),
  army_id uuid not null references public.armies(id) on delete cascade,
  faction_id uuid not null references public.factions(id) on delete cascade,
  from_system_id uuid not null references public.systems(id),
  to_system_id uuid not null references public.systems(id),
  uridium_cost integer not null,
  started_at timestamptz not null default now(),
  arrival_at timestamptz not null,
  status text not null check (status in ('moving', 'arrived', 'cancelled')),
  created_at timestamptz not null default now()
);

create table public.conflicts (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  attacker_faction_id uuid not null references public.factions(id),
  defender_faction_id uuid references public.factions(id),
  status text not null check (status in ('pending', 'resolved', 'cancelled')),
  winner_faction_id uuid references public.factions(id),
  blocked_until timestamptz,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  notes text
);

create table public.battle_reports (
  id uuid primary key default gen_random_uuid(),
  conflict_id uuid not null references public.conflicts(id) on delete cascade,
  reporter_user_id uuid not null references public.profiles(id),
  reporter_faction_id uuid references public.factions(id),
  winner_faction_id uuid references public.factions(id),
  final_controller_faction_id uuid references public.factions(id),
  casualties jsonb,
  survivors jsonb,
  xp_awards jsonb,
  enhancements jsonb,
  post_battle_blocked_until timestamptz,
  narrative_notes text,
  status text not null check (status in ('submitted', 'auto_confirmed', 'admin_confirmed', 'disputed', 'rejected')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  title text not null,
  narrative_description text not null,
  recommended_points text,
  objectives text not null,
  special_rules text not null,
  victory_conditions text not null,
  rewards text,
  map_image_url text,
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.relics (
  id uuid primary key default gen_random_uuid(),
  faction_id uuid references public.factions(id),
  system_id uuid references public.systems(id),
  name text not null,
  description text not null,
  effect_text text,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.system_special_objects (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  name text not null,
  type text not null check (type in ('relic', 'technology', 'resource', 'anomaly')),
  public_description text not null,
  secret_description text,
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.campaign_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id),
  faction_id uuid references public.factions(id),
  action_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.factions enable row level security;
alter table public.player_factions enable row level security;
alter table public.systems enable row level security;
alter table public.system_edges enable row level security;
alter table public.faction_resources enable row level security;
alter table public.system_production enable row level security;
alter table public.campaign_settings enable row level security;
alter table public.armies enable row level security;
alter table public.army_units enable row level security;
alter table public.unit_templates enable row level security;
alter table public.recruitment_queue enable row level security;
alter table public.movement_orders enable row level security;
alter table public.conflicts enable row level security;
alter table public.battle_reports enable row level security;
alter table public.missions enable row level security;
alter table public.relics enable row level security;
alter table public.system_special_objects enable row level security;
alter table public.campaign_logs enable row level security;

create or replace function public.resolve_resource_ticks()
returns void
language plpgsql
security definer
as $$
begin
  raise notice 'resolve_resource_ticks contract placeholder';
end;
$$;

create or replace function public.resolve_movement_orders()
returns void
language plpgsql
security definer
as $$
begin
  raise notice 'resolve_movement_orders contract placeholder';
end;
$$;

create or replace function public.resolve_recruitment_queue()
returns void
language plpgsql
security definer
as $$
begin
  raise notice 'resolve_recruitment_queue contract placeholder';
end;
$$;

create or replace function public.recruit_unit(unit_template_id uuid, quantity integer)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_template public.unit_templates%rowtype;
  v_resources public.faction_resources%rowtype;
  v_is_admin boolean := false;
  v_queue_id uuid;
  v_quantity integer := quantity;
  v_supply_cost integer;
  v_minerals_cost integer;
  v_ancestral_stone_cost integer;
  v_uridium_cost integer;
  v_technology_cost integer;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if v_quantity is null or v_quantity < 1 then
    raise exception 'Cantidad inválida';
  end if;

  select coalesce(role = 'admin', false)
  into v_is_admin
  from public.profiles
  where id = v_user_id;

  select *
  into v_template
  from public.unit_templates
  where id = $1
    and is_available = true;

  if not found then
    raise exception 'Unidad no disponible';
  end if;

  if not v_is_admin and not exists (
    select 1
    from public.player_factions
    where user_id = v_user_id
      and faction_id = v_template.faction_id
  ) then
    raise exception 'No puedes reclutar unidades de esta facción';
  end if;

  v_supply_cost := v_template.supply_cost * v_quantity;
  v_minerals_cost := v_template.minerals_cost * v_quantity;
  v_ancestral_stone_cost := v_template.ancestral_stone_cost * v_quantity;
  v_uridium_cost := v_template.uridium_cost * v_quantity;
  v_technology_cost := v_template.technology_cost * v_quantity;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_template.faction_id
  for update;

  if not found then
    raise exception 'La facción no tiene recursos inicializados';
  end if;

  if v_resources.supply < v_supply_cost
    or v_resources.minerals < v_minerals_cost
    or v_resources.ancestral_stone < v_ancestral_stone_cost
    or v_resources.uridium < v_uridium_cost
    or v_resources.technology < v_technology_cost then
    raise exception 'Recursos insuficientes';
  end if;

  update public.faction_resources
  set
    supply = supply - v_supply_cost,
    minerals = minerals - v_minerals_cost,
    ancestral_stone = ancestral_stone - v_ancestral_stone_cost,
    uridium = uridium - v_uridium_cost,
    technology = technology - v_technology_cost,
    updated_at = now()
  where faction_id = v_template.faction_id;

  insert into public.recruitment_queue (
    faction_id,
    unit_template_id,
    quantity,
    supply_cost,
    minerals_cost,
    ancestral_stone_cost,
    uridium_cost,
    technology_cost,
    started_at,
    finishes_at,
    status
  )
  values (
    v_template.faction_id,
    v_template.id,
    v_quantity,
    v_supply_cost,
    v_minerals_cost,
    v_ancestral_stone_cost,
    v_uridium_cost,
    v_technology_cost,
    now(),
    now() + make_interval(secs => v_template.recruitment_time_seconds * v_quantity),
    'queued'
  )
  returning id into v_queue_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_template.faction_id,
    'recruitment_started',
    jsonb_build_object(
      'queue_id', v_queue_id,
      'unit_template_id', v_template.id,
      'unit_name', v_template.name,
      'quantity', v_quantity,
      'supply_cost', v_supply_cost,
      'minerals_cost', v_minerals_cost,
      'ancestral_stone_cost', v_ancestral_stone_cost,
      'uridium_cost', v_uridium_cost,
      'technology_cost', v_technology_cost
    )
  );

  return v_queue_id;
end;
$$;

create or replace function public.submit_battle_report(conflict_id uuid, report_payload jsonb)
returns uuid
language plpgsql
security definer
as $$
begin
  raise notice 'submit_battle_report contract placeholder for %', conflict_id;
  return null;
end;
$$;
