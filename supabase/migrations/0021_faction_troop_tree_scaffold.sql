create index if not exists technology_nodes_tree_key_idx
  on public.technology_nodes (tree_key);

create or replace function public.expected_troop_tree_key(target_faction_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select 'troops-' || factions.slug || '-v1'
  from public.factions
  where factions.id = target_faction_id;
$$;

create or replace function public.is_technology_tree_allowed_for_faction(
  target_faction_id uuid,
  target_tree_key text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_tree_key = 'common-v1'
    or target_tree_key = public.expected_troop_tree_key(target_faction_id);
$$;

update public.technology_nodes
set implementation_status = 'deprecated',
    updated_at = now()
where tree_key = 'common-v1'
  and slug in (
    'entrenamiento-linea',
    'logistica-frente',
    'cadenas-mando',
    'veteranos-guerra',
    'especializacion-elite',
    'motores-guerra',
    'blindaje-reforzado',
    'matrices-eficiencia'
  );

delete from public.technology_effects
where technology_node_id in (
  select id
  from public.technology_nodes
  where tree_key = 'common-v1'
    and slug in (
      'entrenamiento-linea',
      'logistica-frente',
      'cadenas-mando',
      'veteranos-guerra',
      'especializacion-elite',
      'motores-guerra',
      'blindaje-reforzado',
      'matrices-eficiencia'
    )
)
and effect_type in ('unlock_unit_template', 'recruitment_cost_discount', 'recruitment_time_discount');

delete from public.faction_technologies progress
using public.technology_nodes nodes
where progress.technology_node_id = nodes.id
  and nodes.tree_key = 'common-v1'
  and nodes.implementation_status = 'deprecated';

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
    and technology_nodes.implementation_status = 'active'
    and public.is_technology_tree_allowed_for_faction(target_faction_id, technology_nodes.tree_key)
    and not exists (
      select 1
      from public.faction_technologies existing
      where existing.faction_id = target_faction_id
        and existing.technology_node_id = technology_nodes.id
    )
    and public.are_technology_prerequisites_met(target_faction_id, technology_nodes.id);

  get diagnostics v_inserted = row_count;
  return v_inserted;
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

  if not public.is_technology_tree_allowed_for_faction(v_faction_id, v_node.tree_key) then
    raise exception 'Esta tecnologia pertenece a otra faccion';
  end if;

  if v_node.implementation_status = 'planned' then
    raise exception 'Esta rama esta bloqueada hasta implementar espionaje';
  end if;

  if v_node.implementation_status <> 'active' then
    raise exception 'Esta tecnologia no esta disponible';
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

  if v_node.is_starter then
    raise exception 'La tecnologia inicial ya esta desbloqueada';
  end if;

  if not public.are_technology_prerequisites_met(v_faction_id, v_node.id) then
    raise exception 'Faltan tecnologias requeridas';
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
      'technology_tree_key', v_node.tree_key,
      'cost_technology', v_node.cost_technology,
      'finishes_at', now() + make_interval(secs => v_node.research_time_seconds)
    )
  );

  return v_node.id;
end;
$$;

revoke execute on function public.expected_troop_tree_key(uuid) from public;
revoke execute on function public.is_technology_tree_allowed_for_faction(uuid, text) from public;
revoke execute on function public.refresh_available_technologies(uuid) from public;
revoke execute on function public.start_technology_research(uuid) from public;
grant execute on function public.expected_troop_tree_key(uuid) to authenticated;
grant execute on function public.is_technology_tree_allowed_for_faction(uuid, text) to authenticated;
grant execute on function public.refresh_available_technologies(uuid) to authenticated;
grant execute on function public.start_technology_research(uuid) to authenticated;

delete from public.faction_technologies progress
using public.technology_nodes nodes
where progress.technology_node_id = nodes.id
  and progress.status = 'available'
  and not public.is_technology_tree_allowed_for_faction(progress.faction_id, nodes.tree_key);
