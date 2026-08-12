do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text)'::regprocedure)
  into v_definition;

  v_patched := replace(
    v_definition,
    '  if v_conflict.battle_operation_id is not null then
    update public.battle_operations',
    '  if apply_battle_outcome.final_controller_faction_id is not null
    and v_conflict.attacker_faction_id is not null
    and apply_battle_outcome.final_controller_faction_id = v_conflict.attacker_faction_id then
    update public.recruitment_queue
    set
      status = ''cancelled'',
      updated_at = now()
    where status = ''queued''
      and system_building_id in (
        select id
        from public.system_buildings
        where system_id = v_conflict.system_id
      );

    update public.unit_recovery_queue
    set
      status = ''cancelled'',
      updated_at = now()
    where status = ''queued''
      and system_building_id in (
        select id
        from public.system_buildings
        where system_id = v_conflict.system_id
      );

    with destroyed_buildings as (
      delete from public.system_buildings
      where system_id = v_conflict.system_id
      returning id, building_template_id, status
    )
    insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
    select
      apply_battle_outcome.actor_user_id,
      apply_battle_outcome.actor_faction_id,
      ''system_buildings_destroyed_by_conquest'',
      jsonb_build_object(
        ''conflict_id'', target_conflict_id,
        ''system_id'', v_conflict.system_id,
        ''attacker_faction_id'', v_conflict.attacker_faction_id,
        ''final_controller_faction_id'', apply_battle_outcome.final_controller_faction_id,
        ''destroyed_count'', count(*),
        ''building_ids'', coalesce(jsonb_agg(destroyed_buildings.id), ''[]''::jsonb),
        ''building_template_ids'', coalesce(jsonb_agg(destroyed_buildings.building_template_id), ''[]''::jsonb)
      )
    from destroyed_buildings
    having count(*) > 0;

    perform public.refresh_system_production_from_buildings();
  end if;

  if v_conflict.battle_operation_id is not null then
    update public.battle_operations'
  );

  if v_patched = v_definition then
    raise exception 'No se pudo parchear apply_battle_outcome para destruir edificios al conquistar';
  end if;

  execute v_patched;
end $$;

revoke execute on function public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text) from public;
grant execute on function public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text) to authenticated;
