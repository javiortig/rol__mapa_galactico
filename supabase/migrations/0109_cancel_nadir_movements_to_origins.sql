-- Live campaign correction: cancel the two inspected movements to Nadir Kappa
-- without refunding Uridium, returning their units to the declared origins.
do $$
declare
  v_nadir_id uuid;
  v_voidmist_id uuid;
  v_caronte_id uuid;
  v_necron_faction_id uuid;
  v_chaos_faction_id uuid;
  v_necron_order_id constant uuid := 'c636a289-4b37-4820-92a0-08598ee5b237';
  v_chaos_order_id constant uuid := '788c13df-e075-4b1f-bc34-894cbcb30cd1';
  v_unit_count integer;
begin
  select id into strict v_nadir_id
  from public.systems
  where slug = 'nadir-kappa';

  select id into strict v_voidmist_id
  from public.systems
  where slug = 'voidmist-basin';

  select id into strict v_caronte_id
  from public.systems
  where slug = 'nebulosa-caronte';

  select id into strict v_necron_faction_id
  from public.factions
  where slug = 'necrones';

  select id into strict v_chaos_faction_id
  from public.factions
  where slug = 'legiones-daemonicas';

  if not exists (
    select 1
    from public.movement_orders
    where id = v_necron_order_id
      and faction_id = v_necron_faction_id
      and from_system_id = v_voidmist_id
      and to_system_id = v_nadir_id
      and status = 'moving'
      and movement_type = 'move'
      and movement_purpose = 'normal'
      and battle_operation_id is null
  ) then
    raise exception 'La orden necrona hacia Nadir Kappa ya no coincide con el estado inspeccionado';
  end if;

  if not exists (
    select 1
    from public.movement_orders
    where id = v_chaos_order_id
      and faction_id = v_chaos_faction_id
      and from_system_id = v_caronte_id
      and to_system_id = v_nadir_id
      and status = 'moving'
      and movement_type = 'move'
      and movement_purpose = 'normal'
      and battle_operation_id is null
  ) then
    raise exception 'La orden del Caos hacia Nadir Kappa ya no coincide con el estado inspeccionado';
  end if;

  select count(*) into v_unit_count
  from public.movement_order_units
  where movement_order_units.movement_order_id = v_necron_order_id;

  if v_unit_count <> 2 or exists (
    select 1
    from public.movement_order_units
    join public.campaign_units
      on campaign_units.id = movement_order_units.unit_id
    where movement_order_units.movement_order_id = v_necron_order_id
      and (
        campaign_units.id not in (
          '75f477ea-f734-44fd-9252-57dca17fb8e5'::uuid,
          'dea01eb9-821d-5c0e-8880-1fed2a92470f'::uuid
        )
        or campaign_units.faction_id is distinct from v_necron_faction_id
        or campaign_units.current_system_id is distinct from v_voidmist_id
        or campaign_units.status <> 'moving'
      )
  ) then
    raise exception 'La orden necrona ya no contiene exactamente las dos unidades inspeccionadas';
  end if;

  select count(*) into v_unit_count
  from public.movement_order_units
  where movement_order_units.movement_order_id = v_chaos_order_id;

  if v_unit_count <> 2 or exists (
    select 1
    from public.movement_order_units
    join public.campaign_units
      on campaign_units.id = movement_order_units.unit_id
    where movement_order_units.movement_order_id = v_chaos_order_id
      and (
        campaign_units.id not in (
          '2926e3f1-967a-4707-90bf-6ad3433f7147'::uuid,
          '2144a8a4-ba4d-42d0-a865-1bd93041b40d'::uuid
        )
        or campaign_units.faction_id is distinct from v_chaos_faction_id
        or campaign_units.current_system_id is distinct from v_caronte_id
        or campaign_units.status <> 'moving'
      )
  ) then
    raise exception 'La orden del Caos ya no contiene exactamente las dos unidades inspeccionadas';
  end if;

  perform public.cancel_reserved_movement_order(
    v_necron_order_id,
    'Ajuste de campana: unidades estacionadas en Voidmist Basin',
    0
  );

  perform public.cancel_reserved_movement_order(
    v_chaos_order_id,
    'Ajuste de campana: unidades estacionadas en Nebulosa Caronte',
    0
  );

  if exists (
    select 1
    from public.movement_order_units
    join public.campaign_units
      on campaign_units.id = movement_order_units.unit_id
    where movement_order_units.movement_order_id = v_necron_order_id
      and (
        campaign_units.current_system_id is distinct from v_voidmist_id
        or campaign_units.status <> 'ready'
      )
  ) then
    raise exception 'No se pudieron estacionar todas las unidades necronas en Voidmist Basin';
  end if;

  if exists (
    select 1
    from public.movement_order_units
    join public.campaign_units
      on campaign_units.id = movement_order_units.unit_id
    where movement_order_units.movement_order_id = v_chaos_order_id
      and (
        campaign_units.current_system_id is distinct from v_caronte_id
        or campaign_units.status <> 'ready'
      )
  ) then
    raise exception 'No se pudieron estacionar todas las unidades del Caos en Nebulosa Caronte';
  end if;

  insert into public.campaign_logs (faction_id, action_type, payload)
  values
    (
      v_necron_faction_id,
      'admin_live_movement_repositioned',
      jsonb_build_object(
        'movement_order_id', v_necron_order_id,
        'destination_system_id', v_voidmist_id,
        'cancelled_target_system_id', v_nadir_id,
        'uridium_refund', 0
      )
    ),
    (
      v_chaos_faction_id,
      'admin_live_movement_repositioned',
      jsonb_build_object(
        'movement_order_id', v_chaos_order_id,
        'destination_system_id', v_caronte_id,
        'cancelled_target_system_id', v_nadir_id,
        'uridium_refund', 0
      )
    );
end;
$$;
