-- Ordinary movement into a neutral system conquers it without granting a
-- protection shield. Battle outcomes keep applying their own shield directly.
drop trigger if exists systems_neutral_conquest_shield_trigger on public.systems;
drop function if exists public.apply_neutral_conquest_shield();

alter table public.movement_orders
  drop constraint if exists movement_orders_movement_purpose_check,
  add constraint movement_orders_movement_purpose_check
  check (
    movement_purpose in (
      'normal',
      'attack',
      'coalition_staging',
      'defense_support',
      'battle_return',
      'route_fallback'
    )
  );

-- Preserve the existing cancellation implementation for voluntary
-- cancellations, attacks, staging and defensive support.
alter function public.cancel_reserved_movement_order(uuid, text, integer)
  rename to cancel_reserved_movement_order_core_0107;

create or replace function public.cancel_reserved_movement_order(
  target_order_id uuid,
  reason text,
  refund_uridium integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_refund integer;
  v_path_length integer;
  v_last_passed_system_id uuid;
  v_return_order_id uuid;
  v_return_duration_seconds integer;
begin
  select *
  into v_order
  from public.movement_orders
  where id = target_order_id
  for update;

  if not found or v_order.status in ('cancelled', 'resolved', 'arrived') then
    return;
  end if;

  v_path_length := cardinality(v_order.path_system_ids);

  if v_order.status = 'moving'
    and v_order.movement_type = 'move'
    and v_order.movement_purpose = 'normal'
    and v_order.departure_at is not null
    and v_order.departure_at <= now()
    and v_order.arrival_at is not null
    and v_order.arrival_at <= now()
    and v_path_length >= 2
    and reason in (
      'El destino cambio a territorio bloqueado antes de la llegada',
      'El destino cambio a territorio aliado no autorizado antes de la llegada',
      'El destino cambio a territorio enemigo antes de la llegada',
      'La ruta quedo bloqueada antes de la llegada'
    ) then
    v_last_passed_system_id := v_order.path_system_ids[v_path_length - 1];

    if v_last_passed_system_id is not null
      and v_last_passed_system_id <> v_order.to_system_id
      and exists (
        select 1
        from public.systems
        where id = v_last_passed_system_id
      ) then
      v_refund := coalesce(refund_uridium, v_order.uridium_cost);

      select movement_edge_duration_seconds
      into v_return_duration_seconds
      from public.campaign_settings
      where id = 'default';

      v_return_duration_seconds := coalesce(v_return_duration_seconds, 259200);

      if v_refund > 0 then
        update public.faction_resources
        set
          uridium = uridium + v_refund,
          updated_at = now()
        where faction_id = v_order.faction_id;
      end if;

      update public.movement_passage_requests
      set
        status = case when status = 'pending' then 'rejected' else status end,
        response_reason = coalesce(response_reason, reason),
        responded_at = coalesce(responded_at, now())
      where movement_order_id = v_order.id;

      update public.movement_orders
      set
        status = 'cancelled',
        cancelled_at = now(),
        cancellation_reason = reason,
        resolved_at = now(),
        updated_at = now()
      where id = v_order.id;

      insert into public.movement_orders (
        faction_id,
        from_system_id,
        to_system_id,
        movement_type,
        movement_purpose,
        uridium_cost,
        started_at,
        departure_at,
        arrival_at,
        status,
        path_system_ids,
        segment_count,
        duration_seconds
      )
      values (
        v_order.faction_id,
        v_order.to_system_id,
        v_last_passed_system_id,
        'move',
        'route_fallback',
        0,
        now(),
        now(),
        now() + make_interval(secs => v_return_duration_seconds),
        'moving',
        array[v_order.to_system_id, v_last_passed_system_id],
        1,
        v_return_duration_seconds
      )
      returning id into v_return_order_id;

      insert into public.movement_order_units (
        movement_order_id,
        unit_id,
        quantity_at_departure
      )
      select
        v_return_order_id,
        unit_id,
        quantity_at_departure
      from public.movement_order_units
      where movement_order_id = v_order.id;

      update public.campaign_units
      set
        current_system_id = v_order.to_system_id,
        status = 'moving',
        updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      )
        and status = 'moving';

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (
        v_order.faction_id,
        'movement_route_fallback_started',
        jsonb_build_object(
          'cancelled_movement_order_id', v_order.id,
          'return_movement_order_id', v_return_order_id,
          'changed_destination_system_id', v_order.to_system_id,
          'last_passed_system_id', v_last_passed_system_id,
          'reason', reason,
          'refund_uridium', v_refund,
          'arrival_at', now() + make_interval(secs => v_return_duration_seconds)
        )
      );

      return;
    end if;
  end if;

  perform public.cancel_reserved_movement_order_core_0107(
    target_order_id,
    reason,
    refund_uridium
  );
end;
$$;

-- Route fallbacks deliberately settle at the last system already traversed.
-- They do not revalidate the changed destination because that could create a
-- cancellation loop or teleport the units elsewhere.
create or replace function public.resolve_route_fallback_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.movement_orders%rowtype;
  v_system public.systems%rowtype;
  v_resolved integer := 0;
begin
  for v_order in
    select *
    from public.movement_orders
    where status = 'moving'
      and movement_type = 'move'
      and movement_purpose = 'route_fallback'
      and arrival_at is not null
      and arrival_at <= now()
    order by arrival_at, created_at, id
    for update
  loop
    select *
    into v_system
    from public.systems
    where id = v_order.to_system_id
    for update;

    if not found then
      update public.campaign_units
      set status = 'retreat_pending', updated_at = now()
      where id in (
        select unit_id
        from public.movement_order_units
        where movement_order_id = v_order.id
      )
        and status = 'moving';

      update public.movement_orders
      set
        status = 'cancelled',
        cancelled_at = now(),
        cancellation_reason = 'El ultimo sistema atravesado ya no existe',
        resolved_at = now(),
        updated_at = now()
      where id = v_order.id;

      v_resolved := v_resolved + 1;
      continue;
    end if;

    if not coalesce(v_system.allows_shared_occupation, false)
      and coalesce(v_system.is_conquerable, true)
      and (v_system.status = 'neutral' or v_system.controller_faction_id is null) then
      update public.systems
      set
        status = 'controlled',
        controller_faction_id = v_order.faction_id,
        blocked_until = null,
        updated_at = now()
      where id = v_order.to_system_id;
    end if;

    update public.campaign_units
    set
      current_system_id = v_order.to_system_id,
      status = 'ready',
      updated_at = now()
    where id in (
      select unit_id
      from public.movement_order_units
      where movement_order_id = v_order.id
    )
      and status = 'moving';

    update public.movement_orders
    set status = 'arrived', resolved_at = now(), updated_at = now()
    where id = v_order.id;

    insert into public.campaign_logs (faction_id, action_type, payload)
    values (
      v_order.faction_id,
      'movement_route_fallback_arrived',
      jsonb_build_object(
        'movement_order_id', v_order.id,
        'system_id', v_order.to_system_id
      )
    );

    v_resolved := v_resolved + 1;
  end loop;

  return v_resolved;
end;
$$;

-- Run the dedicated fallback resolver before the existing, battle-aware
-- movement resolver. The existing function remains untouched internally.
alter function public.resolve_movement_orders()
  rename to resolve_movement_orders_core_0107;

create or replace function public.resolve_movement_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fallback_resolved integer;
  v_standard_resolved integer;
begin
  v_fallback_resolved := public.resolve_route_fallback_orders();
  v_standard_resolved := public.resolve_movement_orders_core_0107();

  return coalesce(v_fallback_resolved, 0) + coalesce(v_standard_resolved, 0);
end;
$$;

-- Apply the same segmented fog-of-war rule to the reverse edge.
do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.get_visible_movement_orders()'::regprocedure)
  into v_definition;

  v_patched := replace(
    v_definition,
    'movement_orders.movement_purpose = ''normal''',
    'movement_orders.movement_purpose in (''normal'', ''route_fallback'')'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo ampliar la visibilidad segmentada al repliegue de ruta';
  end if;

  execute v_patched;
end;
$$;

revoke all on function public.cancel_reserved_movement_order_core_0107(uuid, text, integer) from public, anon, authenticated;
revoke all on function public.cancel_reserved_movement_order(uuid, text, integer) from public, anon, authenticated;
revoke all on function public.resolve_route_fallback_orders() from public, anon, authenticated;
revoke all on function public.resolve_movement_orders_core_0107() from public, anon, authenticated;
revoke all on function public.resolve_movement_orders() from public, anon, authenticated;

grant execute on function public.resolve_movement_orders() to authenticated;
