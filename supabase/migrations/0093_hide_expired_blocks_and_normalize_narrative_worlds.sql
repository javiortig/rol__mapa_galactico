do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.get_visible_systems()'::regprocedure)
  into v_definition;

  if position('case when systems.blocked_until > now() then systems.blocked_until else null::timestamptz end as blocked_until' in v_definition) = 0 then
    v_patched := replace(
      v_definition,
      '    systems.blocked_until,',
      '    case when systems.blocked_until > now() then systems.blocked_until else null::timestamptz end as blocked_until,'
    );

    if v_patched = v_definition then
      raise exception 'No se pudo parchear get_visible_systems para ocultar bloqueos vencidos';
    end if;

    execute v_patched;
  end if;
end $$;

create or replace function public.normalize_conquered_narrative_world()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_narrative boolean := false;
  v_new_narrative boolean := false;
  v_had_narrative_metadata boolean := false;
begin
  if tg_op = 'UPDATE'
    and coalesce(old.is_temporary_mission, false) = false
    and new.status = 'controlled'
    and new.controller_faction_id is not null
    and new.controller_faction_id is distinct from old.controller_faction_id then
    select coalesce(factions.is_narrative, false)
    into v_old_narrative
    from public.factions
    where factions.id = old.controller_faction_id;

    select coalesce(factions.is_narrative, false)
    into v_new_narrative
    from public.factions
    where factions.id = new.controller_faction_id;

    v_had_narrative_metadata :=
      old.mission_id is not null
      or old.mission_threat_faction_id is not null
      or coalesce(jsonb_array_length(old.mission_enemy_units), 0) > 0;

    if not v_new_narrative and (v_old_narrative or v_had_narrative_metadata) then
      new.mission_id := null;
      new.mission_threat_faction_id := null;
      new.mission_enemy_units_visible := false;
      new.mission_enemy_units := '[]'::jsonb;
      new.mission_expires_at := null;
      new.mission_expires_after_battle := false;
      new.temporary_mission_status := 'active';
      new.temporary_mission_closed_at := null;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists normalize_conquered_narrative_world_trigger on public.systems;
create trigger normalize_conquered_narrative_world_trigger
before update of status, controller_faction_id on public.systems
for each row
execute function public.normalize_conquered_narrative_world();

insert into public.campaign_logs (action_type, payload)
values (
  'expired_blocks_hidden_from_snapshot',
  jsonb_build_object(
    'rule', 'Los bloqueos vencidos no se muestran como escudo ni como estado visible en la interfaz.'
  )
);
