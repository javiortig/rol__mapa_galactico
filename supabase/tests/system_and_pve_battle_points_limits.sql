\set ON_ERROR_STOP on
begin;

do $$
declare
  v_admin_id uuid;
  v_player_id uuid;
  v_custodes_id uuid;
  v_orcs_id uuid;
  v_target_id uuid;
  v_attack_id uuid;
  v_conflict_id uuid;
  v_mission_id uuid;
  v_limit integer;
begin
  select id into v_admin_id from public.profiles where role = 'admin' limit 1;
  select id into v_player_id from public.profiles where role = 'player' limit 1;
  select id into v_custodes_id from public.factions where slug = 'adeptus-custodes';
  select id into v_orcs_id from public.factions where slug = 'orcos';

  if v_admin_id is null or v_player_id is null then
    raise exception 'Faltan usuarios locales de prueba';
  end if;

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  insert into public.systems
    (slug, name, x, y, type, status, controller_faction_id, public_description)
  values
    ('test-pve-battle-limit', 'Test PVE battle limit', 2500, 2500,
     'Sistema de prueba', 'controlled', v_custodes_id, '')
  returning id into v_target_id;

  perform public.admin_set_system_battle_points_limit(v_target_id, 420);
  select battle_points_limit into v_limit from public.systems where id = v_target_id;
  if v_limit <> 420 then
    raise exception 'No se guardo el limite por sistema';
  end if;

  perform public.validate_system_battle_side_points(v_target_id, v_custodes_id, v_orcs_id, 420);
  begin
    perform public.validate_system_battle_side_points(v_target_id, v_custodes_id, v_orcs_id, 421);
    raise exception 'Se aceptaron 421 puntos en un sistema con limite 420';
  exception when others then
    if sqlerrm = 'Se aceptaron 421 puntos en un sistema con limite 420' then raise; end if;
  end;

  v_attack_id := public.admin_create_narrative_attack(
    v_target_id, v_orcs_id, 'Incursion de prueba con limite propio',
    now() + interval '1 day', 340
  );
  select battle_points_limit into v_limit from public.narrative_attacks where id = v_attack_id;
  if v_limit <> 340 then
    raise exception 'La incursion no conservo el limite elegido';
  end if;
  perform public.validate_system_battle_side_points(v_target_id, v_orcs_id, v_custodes_id, 340);
  begin
    perform public.validate_system_battle_side_points(v_target_id, v_orcs_id, v_custodes_id, 341);
    raise exception 'La incursion permitio superar su limite propio';
  exception when others then
    if sqlerrm = 'La incursion permitio superar su limite propio' then raise; end if;
  end;

  insert into public.conflicts
    (system_id, attacker_faction_id, defender_faction_id, status)
  values (v_target_id, v_orcs_id, v_custodes_id, 'pending')
  returning id into v_conflict_id;
  select battle_points_limit into v_limit from public.conflicts where id = v_conflict_id;
  if v_limit <> 340 then
    raise exception 'El conflicto no heredo el limite de la incursion';
  end if;
  perform public.validate_system_battle_side_points(v_target_id, v_orcs_id, v_custodes_id, 340);
  begin
    perform public.validate_system_battle_side_points(v_target_id, v_orcs_id, v_custodes_id, 341);
    raise exception 'El conflicto permitio superar su limite congelado';
  exception when others then
    if sqlerrm = 'El conflicto permitio superar su limite congelado' then raise; end if;
  end;

  v_mission_id := public.admin_create_narrative_mission(
    (select id from public.systems where slug = 'kharon-prime'),
    v_orcs_id, 'Mision de prueba', 'Descripcion de la mision de prueba',
    true, '[]'::jsonb, 2, true, 760
  );
  select battle_points_limit into v_limit from public.systems where id = v_mission_id;
  if v_limit <> 760 then
    raise exception 'La mision temporal no conservo su limite';
  end if;
  if not exists (
    select 1 from public.missions
    where system_id = v_mission_id and recommended_points = '760 pts por bando'
  ) then
    raise exception 'La ficha de la mision no muestra su limite';
  end if;

  perform set_config('request.jwt.claim.sub', v_player_id::text, true);
  begin
    perform public.admin_set_system_battle_points_limit(v_target_id, 1000);
    raise exception 'Un jugador pudo editar el limite';
  exception when others then
    if sqlerrm = 'Un jugador pudo editar el limite' then raise; end if;
  end;

  if (select battle_points_limit from public.systems where id = v_target_id) <> 420 then
    raise exception 'El intento no autorizado cambio el limite';
  end if;

  if (
    select count(*) from (
      values
        ('public.create_attack_order(jsonb,uuid,uuid)'::text),
        ('public.create_coalition_attack_draft(jsonb,uuid,uuid,uuid[])'),
        ('public.join_battle_operation(uuid,jsonb,uuid[])'),
        ('public.launch_coalition_attack(uuid)')
    ) as functions(signature)
    where pg_get_functiondef(to_regprocedure(signature)) like '%validate_system_battle_side_points%'
  ) <> 4 then
    raise exception 'Alguna ruta de ataque sigue usando el limite global';
  end if;
end $$;

rollback;
