begin;

lock table
  public.faction_technologies,
  public.faction_resources,
  public.movement_orders,
  public.movement_order_units,
  public.movement_passage_requests,
  public.campaign_units,
  public.system_buildings,
  public.systems,
  public.conflicts,
  public.campaign_logs
in share row exclusive mode;

do $$
declare
  v_chaos_id uuid;
  v_cult_id uuid;
  v_shadow_id uuid;
  v_fasciata_id uuid;
  v_caronte_id uuid;
  v_yaracuby_id uuid;
  v_corona_id uuid;
  v_llamas_id uuid;
  v_asamblea_id uuid;
  v_conflict_id uuid := public.seed_uuid('conflict', 'corona-voss-cultos-caos-2026-09-24');
  v_blocked_until timestamptz;
  v_refund integer := 0;
  v_count integer;
  v_order record;
begin
  select id into strict v_chaos_id
  from public.factions
  where slug = 'legiones-daemonicas';

  select id into strict v_cult_id
  from public.factions
  where slug = 'cultos-genestealer';

  select id into strict v_shadow_id
  from public.factions
  where slug = 'space-marines';

  select id into strict v_fasciata_id
  from public.systems
  where slug = 'mordax' and name = 'Fasciata';

  select id into strict v_caronte_id
  from public.systems
  where slug = 'nebulosa-caronte' and name = 'Nebulosa Caronte';

  select id into strict v_yaracuby_id
  from public.systems
  where slug = 'blackglass' and name = 'Yaracuby77 Mina Abandonada';

  select id into strict v_corona_id
  from public.systems
  where slug = 'corona-voss' and name = 'Corona Voss'
  for update;

  if not exists (
    select 1
    from public.systems
    where id = v_corona_id
      and controller_faction_id = v_chaos_id
      and status = 'controlled'
  ) then
    raise exception 'Corona Voss ya no está controlada por El Caos o no está en estado controlado';
  end if;

  if exists (
    select 1
    from public.conflicts
    where system_id = v_corona_id
      and status = 'pending'
  ) then
    raise exception 'Corona Voss ya tiene un conflicto pendiente';
  end if;

  select id into strict v_llamas_id
  from public.technology_nodes
  where slug = 'daemonicas-mareas-rosadas'
    and name = 'Llamas Mutables';

  select id into strict v_asamblea_id
  from public.technology_nodes
  where slug = 'asamblea-planetaria';

  insert into public.faction_technologies (
    faction_id,
    technology_node_id,
    status,
    started_at,
    finishes_at,
    unlocked_at
  )
  values (
    v_chaos_id,
    v_llamas_id,
    'unlocked',
    null,
    null,
    now()
  )
  on conflict (faction_id, technology_node_id) do update
  set status = 'unlocked',
      started_at = null,
      finishes_at = null,
      unlocked_at = coalesce(public.faction_technologies.unlocked_at, now()),
      updated_at = now();

  insert into public.faction_technologies (
    faction_id,
    technology_node_id,
    status,
    started_at,
    finishes_at,
    unlocked_at
  )
  values (
    v_chaos_id,
    v_asamblea_id,
    'available',
    null,
    null,
    null
  )
  on conflict (faction_id, technology_node_id) do update
  set status = 'available',
      started_at = null,
      finishes_at = null,
      unlocked_at = null,
      updated_at = now();

  create temporary table chaos_active_orders on commit drop as
  select id
  from public.movement_orders
  where faction_id = v_chaos_id
    and status in ('pending_approval', 'moving');

  select count(*) into v_count from chaos_active_orders;
  if v_count <> 4 then
    raise exception 'Se esperaban 4 movimientos activos de El Caos y se encontraron %', v_count;
  end if;

  create temporary table chaos_moving_units on commit drop as
  select units.id, units.name
  from public.movement_order_units links
  join chaos_active_orders orders on orders.id = links.movement_order_id
  join public.campaign_units units on units.id = links.unit_id
  where units.faction_id = v_chaos_id
    and units.status = 'moving';

  select count(*) into v_count from chaos_moving_units;
  if v_count <> 5 then
    raise exception 'Se esperaban 5 unidades en movimiento de El Caos y se encontraron %', v_count;
  end if;

  if (select count(*) from chaos_moving_units where name = 'Blue Horrors') <> 1
    or (select count(*) from chaos_moving_units where name = 'Pink Horrors') <> 1
    or (select count(*) from chaos_moving_units where name = 'Flamers') <> 1
    or (select count(*) from chaos_moving_units where name = 'Chaos Spawn') <> 2 then
    raise exception 'La composición de los movimientos de El Caos no coincide con la orden administrativa';
  end if;

  for v_order in select id from chaos_active_orders loop
    perform public.cancel_reserved_movement_order(
      v_order.id,
      'Movimiento anulado por administración sin reembolso',
      0
    );
  end loop;

  update public.campaign_units
  set current_system_id = v_fasciata_id,
      status = 'ready',
      updated_at = now()
  where id in (
    select id
    from chaos_moving_units
    where name in ('Blue Horrors', 'Pink Horrors', 'Flamers')
  );

  update public.campaign_units
  set current_system_id = v_caronte_id,
      status = 'ready',
      updated_at = now()
  where id in (
    select id
    from chaos_moving_units
    where name = 'Chaos Spawn'
  );

  update public.faction_resources
  set uridium = uridium + 1,
      updated_at = now()
  where faction_id = v_shadow_id;

  if not found then
    raise exception 'No se encontraron los recursos de Sombra del Emperador';
  end if;

  update public.systems
  set blocked_until = null,
      updated_at = now()
  where slug in (
    'umbral-ceniza',
    'baluarte-sol',
    'vigilia-noctis',
    'pozo-khepra',
    'cicatriz-helion',
    'corona-voss'
  );

  get diagnostics v_count = row_count;
  if v_count <> 6 then
    raise exception 'Se esperaban 6 sistemas para retirar escudos y se encontraron %', v_count;
  end if;

  select coalesce(sum(templates.industrial_material_cost), 0)::integer
  into v_refund
  from public.system_buildings buildings
  join public.building_templates templates on templates.id = buildings.building_template_id
  where buildings.system_id = v_corona_id
    and buildings.status = 'constructing';

  select count(*) into v_count
  from public.system_buildings
  where system_id = v_corona_id
    and status = 'constructing';

  if v_count <> 3 or v_refund <> 75 then
    raise exception 'Las construcciones de Corona Voss han cambiado: % edificios, % materiales', v_count, v_refund;
  end if;

  delete from public.system_buildings
  where system_id = v_corona_id
    and status = 'constructing';

  update public.faction_resources
  set industrial_material = industrial_material + v_refund,
      updated_at = now()
  where faction_id = v_chaos_id;

  create temporary table corona_cult_units (id uuid primary key) on commit drop;

  insert into corona_cult_units (id)
  select id
  from public.campaign_units
  where faction_id = v_cult_id
    and current_system_id = v_yaracuby_id
    and status = 'ready'
    and quantity > 0
    and name in ('Aberrants', 'Abominant');

  if (select count(*) from corona_cult_units) <> 2 then
    raise exception 'No se encontraron Aberrants y Abominant disponibles en Yaracuby77 Mina Abandonada';
  end if;

  insert into corona_cult_units (id)
  select id
  from public.campaign_units
  where faction_id = v_cult_id
    and current_system_id = v_yaracuby_id
    and status = 'ready'
    and quantity > 0
    and name = 'Neophyte Hybrids'
  order by created_at, id
  limit 2;

  if (select count(*) from corona_cult_units) <> 4 then
    raise exception 'No hay dos unidades de Neophyte Hybrids disponibles en Yaracuby77 Mina Abandonada';
  end if;

  update public.campaign_units
  set current_system_id = v_corona_id,
      status = 'in_war',
      updated_at = now()
  where id in (select id from corona_cult_units);

  update public.campaign_units
  set status = 'in_war',
      updated_at = now()
  where current_system_id = v_corona_id
    and faction_id = v_chaos_id
    and status = 'ready'
    and quantity > 0;

  get diagnostics v_count = row_count;
  if v_count <> 2 then
    raise exception 'Se esperaban 2 unidades defensoras de El Caos en Corona Voss y se encontraron %', v_count;
  end if;

  select now() + make_interval(mins => conflict_block_duration_minutes)
  into v_blocked_until
  from public.campaign_settings
  where id = 'default';

  v_blocked_until := coalesce(v_blocked_until, now() + interval '14 days');

  update public.systems
  set status = 'war',
      controller_faction_id = null,
      blocked_until = v_blocked_until,
      updated_at = now()
  where id = v_corona_id;

  insert into public.conflicts (
    id,
    slug,
    system_id,
    attacker_faction_id,
    defender_faction_id,
    status,
    winner_faction_id,
    blocked_until,
    resolved_at,
    notes,
    movement_order_id,
    battle_operation_id
  )
  values (
    v_conflict_id,
    'corona-voss-cultos-contra-caos-2026-09-24',
    v_corona_id,
    v_cult_id,
    v_chaos_id,
    'pending',
    null,
    v_blocked_until,
    null,
    'El Culto Genestealer disputa Corona Voss a El Caos. El sistema permanece neutral hasta la resolución de la batalla.',
    null,
    null
  );

  insert into public.campaign_logs (faction_id, action_type, payload)
  values
    (
      v_chaos_id,
      'admin_live_campaign_adjustment',
      jsonb_build_object(
        'technologies', jsonb_build_object(
          'unlocked', 'daemonicas-mareas-rosadas',
          'locked_again', 'asamblea-planetaria'
        ),
        'cancelled_movements', 4,
        'movement_uridium_refund', 0,
        'industrial_material_refund', v_refund
      )
    ),
    (
      v_cult_id,
      'admin_battle_created',
      jsonb_build_object(
        'conflict_id', v_conflict_id,
        'system_id', v_corona_id,
        'opponent_faction_id', v_chaos_id,
        'unit_ids', (select jsonb_agg(id order by id) from corona_cult_units)
      )
    ),
    (
      v_shadow_id,
      'admin_resource_adjustment',
      jsonb_build_object('resource', 'uridium', 'amount', 1)
    );
end;
$$;

commit;
