alter table public.unit_templates
  add column if not exists required_technology_node_id uuid;

create table if not exists public.technology_nodes (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  tree_key text not null default 'common-v1',
  name text not null,
  description text not null,
  branch text not null,
  tier integer not null default 1 check (tier >= 0),
  position_x numeric not null,
  position_y numeric not null,
  cost_technology integer not null default 0 check (cost_technology >= 0),
  research_time_seconds integer not null default 120 check (research_time_seconds >= 0),
  icon_key text,
  effect_summary text,
  is_starter boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.unit_templates
  drop constraint if exists unit_templates_required_technology_node_id_fkey,
  add constraint unit_templates_required_technology_node_id_fkey
    foreign key (required_technology_node_id) references public.technology_nodes(id) on delete set null;

create table if not exists public.technology_prerequisites (
  technology_node_id uuid not null references public.technology_nodes(id) on delete cascade,
  required_node_id uuid not null references public.technology_nodes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (technology_node_id, required_node_id),
  check (technology_node_id <> required_node_id)
);

create table if not exists public.faction_technologies (
  faction_id uuid not null references public.factions(id) on delete cascade,
  technology_node_id uuid not null references public.technology_nodes(id) on delete cascade,
  status text not null check (status in ('available', 'researching', 'unlocked')),
  started_at timestamptz,
  finishes_at timestamptz,
  unlocked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (faction_id, technology_node_id)
);

create table if not exists public.technology_effects (
  id uuid primary key default gen_random_uuid(),
  technology_node_id uuid not null references public.technology_nodes(id) on delete cascade,
  effect_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.building_templates (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null,
  category text not null,
  required_technology_node_id uuid references public.technology_nodes(id) on delete set null,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists faction_technologies_status_idx on public.faction_technologies (faction_id, status);
create index if not exists technology_effects_node_idx on public.technology_effects (technology_node_id, effect_type);
create index if not exists unit_templates_required_technology_idx on public.unit_templates (required_technology_node_id);

alter table public.technology_nodes enable row level security;
alter table public.technology_prerequisites enable row level security;
alter table public.faction_technologies enable row level security;
alter table public.technology_effects enable row level security;
alter table public.building_templates enable row level security;

drop policy if exists technology_nodes_select_public on public.technology_nodes;
create policy technology_nodes_select_public
on public.technology_nodes
for select
to anon, authenticated
using (true);

drop policy if exists technology_nodes_admin_all on public.technology_nodes;
create policy technology_nodes_admin_all
on public.technology_nodes
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists technology_prerequisites_select_public on public.technology_prerequisites;
create policy technology_prerequisites_select_public
on public.technology_prerequisites
for select
to anon, authenticated
using (true);

drop policy if exists technology_prerequisites_admin_all on public.technology_prerequisites;
create policy technology_prerequisites_admin_all
on public.technology_prerequisites
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists technology_effects_select_public on public.technology_effects;
create policy technology_effects_select_public
on public.technology_effects
for select
to anon, authenticated
using (true);

drop policy if exists technology_effects_admin_all on public.technology_effects;
create policy technology_effects_admin_all
on public.technology_effects
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists building_templates_select_public on public.building_templates;
create policy building_templates_select_public
on public.building_templates
for select
to anon, authenticated
using (true);

drop policy if exists building_templates_admin_all on public.building_templates;
create policy building_templates_admin_all
on public.building_templates
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists faction_technologies_select_member_or_admin on public.faction_technologies;
create policy faction_technologies_select_member_or_admin
on public.faction_technologies
for select
to authenticated
using (public.is_admin() or public.is_faction_member(faction_id));

drop policy if exists faction_technologies_admin_all on public.faction_technologies;
create policy faction_technologies_admin_all
on public.faction_technologies
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.refresh_available_technologies(target_faction_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer := 0;
begin
  insert into public.faction_technologies (
    faction_id,
    technology_node_id,
    status
  )
  select
    target_faction_id,
    technology_nodes.id,
    'available'
  from public.technology_nodes
  where not technology_nodes.is_starter
    and not exists (
      select 1
      from public.faction_technologies existing
      where existing.faction_id = target_faction_id
        and existing.technology_node_id = technology_nodes.id
    )
    and not exists (
      select 1
      from public.technology_prerequisites prerequisites
      where prerequisites.technology_node_id = technology_nodes.id
        and not exists (
          select 1
          from public.faction_technologies unlocked
          where unlocked.faction_id = target_faction_id
            and unlocked.technology_node_id = prerequisites.required_node_id
            and unlocked.status = 'unlocked'
        )
    );

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

create or replace function public.resolve_technology_research()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_research record;
  v_resolved integer := 0;
begin
  for v_research in
    select *
    from public.faction_technologies
    where status = 'researching'
      and finishes_at <= now()
    order by finishes_at
    for update
  loop
    update public.faction_technologies
    set
      status = 'unlocked',
      unlocked_at = now(),
      updated_at = now()
    where faction_id = v_research.faction_id
      and technology_node_id = v_research.technology_node_id;

    perform public.refresh_available_technologies(v_research.faction_id);

    insert into public.campaign_logs (faction_id, action_type, payload)
    values (
      v_research.faction_id,
      'technology_research_completed',
      jsonb_build_object('technology_node_id', v_research.technology_node_id)
    );

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

create or replace function public.start_technology_research(technology_node_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_faction_id uuid;
  v_node public.technology_nodes%rowtype;
  v_resources public.faction_resources%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  perform public.resolve_technology_research();

  select player_factions.faction_id
  into v_faction_id
  from public.player_factions
  where player_factions.user_id = v_user_id
  order by player_factions.created_at
  limit 1;

  if v_faction_id is null then
    raise exception 'El usuario no tiene faccion activa';
  end if;

  select *
  into v_node
  from public.technology_nodes
  where id = start_technology_research.technology_node_id;

  if not found then
    raise exception 'Tecnologia no encontrada';
  end if;

  if exists (
    select 1
    from public.faction_technologies progress
    where progress.faction_id = v_faction_id
      and progress.status = 'researching'
  ) then
    raise exception 'Ya hay una investigacion activa';
  end if;

  if exists (
    select 1
    from public.faction_technologies progress
    where progress.faction_id = v_faction_id
      and progress.technology_node_id = v_node.id
      and progress.status in ('researching', 'unlocked')
  ) then
    raise exception 'Esta tecnologia ya esta en progreso o desbloqueada';
  end if;

  if exists (
    select 1
    from public.technology_prerequisites prerequisites
    where prerequisites.technology_node_id = v_node.id
      and not exists (
        select 1
        from public.faction_technologies unlocked
        where unlocked.faction_id = v_faction_id
          and unlocked.technology_node_id = prerequisites.required_node_id
          and unlocked.status = 'unlocked'
      )
  ) then
    raise exception 'Faltan tecnologias requeridas';
  end if;

  if v_node.is_starter then
    raise exception 'La tecnologia inicial ya esta desbloqueada';
  end if;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_faction_id
  for update;

  if not found or v_resources.technology < v_node.cost_technology then
    raise exception 'Componentes tecnologicos insuficientes';
  end if;

  update public.faction_resources
  set
    technology = technology - v_node.cost_technology,
    updated_at = now()
  where faction_id = v_faction_id;

  insert into public.faction_technologies (
    faction_id,
    technology_node_id,
    status,
    started_at,
    finishes_at
  )
  values (
    v_faction_id,
    v_node.id,
    'researching',
    now(),
    now() + make_interval(secs => v_node.research_time_seconds)
  )
  on conflict on constraint faction_technologies_pkey do update
  set
    status = 'researching',
    started_at = excluded.started_at,
    finishes_at = excluded.finishes_at,
    updated_at = now();

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (
    v_user_id,
    v_faction_id,
    'technology_research_started',
    jsonb_build_object(
      'technology_node_id', v_node.id,
      'technology_name', v_node.name,
      'cost_technology', v_node.cost_technology,
      'finishes_at', now() + make_interval(secs => v_node.research_time_seconds)
    )
  );

  return v_node.id;
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
  v_recruitment_seconds integer;
  v_effect record;
  v_percent integer;
  v_category text;
  v_resource text;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  perform public.resolve_technology_research();

  if v_quantity is null or v_quantity < 1 then
    raise exception 'Cantidad invalida';
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
    raise exception 'No puedes reclutar unidades de esta faccion';
  end if;

  if v_template.required_technology_node_id is not null
    and not exists (
      select 1
      from public.faction_technologies
      where faction_id = v_template.faction_id
        and technology_node_id = v_template.required_technology_node_id
        and status = 'unlocked'
    ) then
    raise exception 'Esta unidad requiere tecnologia desbloqueada';
  end if;

  v_supply_cost := v_template.supply_cost * v_quantity;
  v_minerals_cost := v_template.minerals_cost * v_quantity;
  v_ancestral_stone_cost := v_template.ancestral_stone_cost * v_quantity;
  v_uridium_cost := v_template.uridium_cost * v_quantity;
  v_technology_cost := v_template.technology_cost * v_quantity;
  v_recruitment_seconds := v_template.recruitment_time_seconds * v_quantity;

  for v_effect in
    select technology_effects.*
    from public.technology_effects
    join public.faction_technologies
      on faction_technologies.technology_node_id = technology_effects.technology_node_id
    where faction_technologies.faction_id = v_template.faction_id
      and faction_technologies.status = 'unlocked'
      and technology_effects.effect_type in ('recruitment_cost_discount', 'recruitment_time_discount')
    order by technology_effects.created_at, technology_effects.id
  loop
    v_percent := greatest(0, least(90, coalesce((v_effect.payload->>'percent')::integer, 0)));
    v_category := coalesce(v_effect.payload->>'category', 'all');
    v_resource := coalesce(v_effect.payload->>'resource', 'all');

    if v_percent <= 0 or (v_category <> 'all' and v_category <> v_template.category) then
      continue;
    end if;

    if v_effect.effect_type = 'recruitment_time_discount' then
      v_recruitment_seconds := greatest(v_quantity, ceil((v_recruitment_seconds::numeric * (100 - v_percent)) / 100)::integer);
    elsif v_effect.effect_type = 'recruitment_cost_discount' then
      if v_resource in ('all', 'supply') and v_supply_cost > 0 then
        v_supply_cost := greatest(1, floor((v_supply_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'minerals') and v_minerals_cost > 0 then
        v_minerals_cost := greatest(1, floor((v_minerals_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'ancestralStone') and v_ancestral_stone_cost > 0 then
        v_ancestral_stone_cost := greatest(1, floor((v_ancestral_stone_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'uridium') and v_uridium_cost > 0 then
        v_uridium_cost := greatest(1, floor((v_uridium_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
      if v_resource in ('all', 'technology') and v_technology_cost > 0 then
        v_technology_cost := greatest(1, floor((v_technology_cost::numeric * (100 - v_percent)) / 100)::integer);
      end if;
    end if;
  end loop;

  select *
  into v_resources
  from public.faction_resources
  where faction_id = v_template.faction_id
  for update;

  if not found then
    raise exception 'La faccion no tiene recursos inicializados';
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
    now() + make_interval(secs => v_recruitment_seconds),
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
      'technology_cost', v_technology_cost,
      'duration_seconds', v_recruitment_seconds
    )
  );

  return v_queue_id;
end;
$$;

revoke execute on function public.refresh_available_technologies(uuid) from public;
revoke execute on function public.resolve_technology_research() from public;
revoke execute on function public.start_technology_research(uuid) from public;
grant execute on function public.resolve_technology_research() to authenticated;
grant execute on function public.start_technology_research(uuid) to authenticated;
