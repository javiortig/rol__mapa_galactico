begin;

do $$
declare
  v_leader uuid;
  v_ally uuid;
  v_defender uuid;
  v_target uuid;
  v_origin_leader uuid;
  v_origin_ally uuid;
  v_leader_unit uuid;
  v_ally_unit uuid;
  v_operation uuid;
  v_leader_order uuid;
  v_conflicts integer;
begin
  select id into strict v_leader from public.factions where slug = 'legiones-daemonicas';
  select id into strict v_ally from public.factions where slug = 'necrones';
  select id into strict v_defender from public.factions where slug = 'adeptus-custodes';
  select id into strict v_target from public.systems where slug = 'novem';
  select id into strict v_origin_leader from public.systems where slug = 'voidmist-basin';
  select id into strict v_origin_ally from public.systems where slug = 'thokt-vault';
  select id into strict v_leader_unit from public.campaign_units
  where faction_id = v_leader and name = 'Pink Horrors' and status = 'ready' limit 1;
  select id into strict v_ally_unit from public.campaign_units
  where faction_id = v_ally and name = 'Necron Warriors' and status = 'ready' limit 1;

  update public.campaign_units set current_system_id = v_origin_leader where id = v_leader_unit;
  update public.campaign_units set current_system_id = v_origin_ally where id = v_ally_unit;

  perform set_config('request.jwt.claim.sub', (
    select user_id::text from public.player_factions where faction_id = v_leader limit 1
  ), true);
  select public.create_coalition_attack_draft(
    jsonb_build_array(jsonb_build_object('unit_id', v_leader_unit, 'quantity',
      (select quantity from public.campaign_units where id = v_leader_unit))),
    v_origin_leader, v_target, array[v_ally]
  ) into v_operation;

  update public.battle_operation_members
  set invitation_status = 'accepted', responded_at = now()
  where operation_id = v_operation and faction_id = v_ally;

  perform set_config('request.jwt.claim.sub', (
    select user_id::text from public.player_factions where faction_id = v_ally limit 1
  ), true);
  perform public.join_battle_operation(
    v_operation,
    jsonb_build_array(jsonb_build_object('unit_id', v_ally_unit, 'quantity',
      (select quantity from public.campaign_units where id = v_ally_unit))),
    array[v_origin_ally]
  );

  if (select staging_system_id from public.battle_unit_commitments
    where operation_id = v_operation and faction_id = v_ally) <> v_origin_ally then
    raise exception 'El aliado no conserva su sistema de salida';
  end if;

  perform set_config('request.jwt.claim.sub', (
    select user_id::text from public.player_factions where faction_id = v_leader limit 1
  ), true);
  select public.launch_coalition_attack(v_operation) into v_leader_order;

  if (select count(*) from public.movement_orders
    where battle_operation_id = v_operation and movement_type = 'attack') <> 2 then
    raise exception 'Se esperaban dos rutas de ataque';
  end if;
  if (select count(distinct arrival_at) from public.movement_orders
    where battle_operation_id = v_operation and movement_type = 'attack') <> 1 then
    raise exception 'Las rutas no tienen llegada sincronizada';
  end if;
  if (select attack_movement_order_id from public.battle_operations where id = v_operation)
    <> v_leader_order then
    raise exception 'La operacion no conserva la orden del comandante';
  end if;

  perform set_config('request.jwt.claim.sub', (
    select user_id::text from public.player_factions where faction_id = v_defender limit 1
  ), true);
  if public.can_view_attack_force(v_operation) then
    raise exception 'El defensor puede ver el plantel antes de la llegada';
  end if;
  if (select count(*) from public.get_defender_incoming_attack_routes()
    where to_system_id = v_target) <> 2 then
    raise exception 'El defensor no ve ambas rutas de ataque';
  end if;
  if (select count(*) from public.movement_orders movement
    where movement.battle_operation_id = v_operation and movement.movement_type = 'attack'
      and public.can_select_movement_order(movement.id, movement.faction_id)) <> 0 then
    raise exception 'El defensor ve detalles de una ruta enemiga';
  end if;

  perform set_config('request.jwt.claim.sub', (
    select user_id::text from public.player_factions where faction_id = v_ally limit 1
  ), true);
  if not public.can_view_attack_force(v_operation) then
    raise exception 'El aliado atacante no ve el plantel completo';
  end if;

  update public.movement_orders set arrival_at = now() - interval '1 second'
  where battle_operation_id = v_operation and movement_type = 'attack';
  perform public.resolve_movement_orders();

  select count(*) into v_conflicts from public.conflicts where battle_operation_id = v_operation;
  if v_conflicts <> 1 then
    raise exception 'La coalicion genero % conflictos en lugar de uno', v_conflicts;
  end if;
  if (select count(*) from public.movement_orders
    where battle_operation_id = v_operation and movement_type = 'attack' and status = 'in_battle') <> 2 then
    raise exception 'No se resolvieron ambas rutas';
  end if;
  if (select count(*) from public.campaign_units
    where id in (v_leader_unit, v_ally_unit) and current_system_id = v_target and status = 'in_war') <> 2 then
    raise exception 'No llegaron ambas fuerzas al objetivo';
  end if;

  update public.conflicts set status = 'resolved', resolved_at = now()
  where battle_operation_id = v_operation;
  if (select count(*) from public.movement_orders
    where battle_operation_id = v_operation and movement_type = 'attack' and status = 'resolved') <> 2 then
    raise exception 'No se cerraron ambas rutas tras la batalla';
  end if;

  raise notice 'Coalicion multi-origen verificada: 2 rutas, 1 conflicto, vision privada y cierre completo';
end $$;

rollback;
