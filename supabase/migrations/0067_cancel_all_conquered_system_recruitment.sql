do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text)'::regprocedure)
  into v_definition;

  v_patched := replace(
    v_definition,
    '    update public.recruitment_queue
    set
      status = ''cancelled'',
      updated_at = now()
    where status = ''queued''
      and system_building_id in (
        select id
        from public.system_buildings
        where system_id = v_conflict.system_id
      );',
    '    update public.recruitment_queue
    set
      status = ''cancelled'',
      updated_at = now()
    where status = ''queued''
      and (
        origin_system_id = v_conflict.system_id
        or system_building_id in (
          select id
          from public.system_buildings
          where system_id = v_conflict.system_id
        )
      );'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo parchear apply_battle_outcome para cancelar reclutamientos del sistema conquistado';
  end if;

  execute v_patched;
end $$;

revoke execute on function public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text) from public;
grant execute on function public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text) to authenticated;
