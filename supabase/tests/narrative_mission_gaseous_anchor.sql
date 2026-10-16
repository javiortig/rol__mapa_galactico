\set ON_ERROR_STOP on
begin;

do $$
declare
  v_admin_id uuid;
  v_gaseous_id uuid;
  v_narrative_faction_id uuid;
  v_mission_id uuid;
begin
  select id into v_admin_id from public.profiles where role = 'admin' limit 1;
  select id into v_gaseous_id from public.systems
  where system_kind = 'gaseous' and not is_temporary_mission limit 1;
  select id into v_narrative_faction_id from public.factions
  where is_narrative limit 1;

  if v_admin_id is null or v_gaseous_id is null or v_narrative_faction_id is null then
    raise exception 'Faltan datos locales de prueba';
  end if;

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);
  v_mission_id := public.admin_create_narrative_mission(
    v_gaseous_id,
    v_narrative_faction_id,
    'Incursion del corredor gaseoso',
    'Una fuerza enemiga emerge de la nube de gas.',
    false,
    '[]'::jsonb,
    3,
    true,
    750
  );

  if not exists (
    select 1 from public.systems
    where id = v_mission_id and is_temporary_mission and battle_points_limit = 750
  ) then
    raise exception 'No se creo la mision con su limite de batalla';
  end if;

  if not exists (
    select 1 from public.system_edges
    where (from_system_id = v_gaseous_id and to_system_id = v_mission_id)
       or (from_system_id = v_mission_id and to_system_id = v_gaseous_id)
  ) then
    raise exception 'La mision no quedo conectada al sistema gaseoso';
  end if;

  begin
    perform public.admin_create_narrative_mission(
      v_mission_id,
      v_narrative_faction_id,
      'Mision enlazada a otra mision',
      'Este anclaje temporal no debe permitirse.',
      false,
      '[]'::jsonb,
      3,
      true,
      750
    );
    raise exception 'Se permitio anclar una mision a otra mision';
  exception when others then
    if sqlerrm = 'Se permitio anclar una mision a otra mision' then raise; end if;
  end;
end $$;

rollback;
