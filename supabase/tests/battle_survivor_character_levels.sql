\set ON_ERROR_STOP on
begin;

do $$
declare
  v_conflict public.conflicts%rowtype;
  v_defender uuid;
  v_attacker uuid;
  v_veteran uuid;
  v_destroyed uuid;
  v_infantry uuid;
  v_survivors jsonb;
  v_wounds jsonb;
begin
  insert into public.conflicts (system_id, attacker_faction_id, defender_faction_id, status)
  select systems.id, attacker.id, defender.id, 'pending'
  from public.systems
  cross join public.factions attacker
  cross join public.factions defender
  where systems.system_kind = 'gaseous'
    and attacker.slug = 'necrones'
    and defender.slug = 'adeptus-custodes'
    and not exists (
      select 1 from public.campaign_units
      where current_system_id = systems.id and status = 'in_war'
    )
  order by systems.slug
  limit 1
  returning * into v_conflict;

  if v_conflict.id is null then
    raise exception 'Falta un sistema gaseoso libre para probar la batalla';
  end if;

  insert into public.campaign_units
    (slug, faction_id, name, category, points, quantity, starting_quantity,
     unit_type, unit_keywords, experience, current_system_id, status)
  values
    ('test-defender-character-level-2', v_conflict.defender_faction_id, 'Test defender',
     'Personaje', 50, 1, 1, 'character', array['Infanteria', 'Caracter'], 2, v_conflict.system_id, 'in_war')
  returning id into v_defender;

  insert into public.campaign_units
    (slug, faction_id, name, category, points, quantity, starting_quantity,
     unit_type, unit_keywords, experience, current_system_id, status)
  values
    ('test-attacker-character-level-2', v_conflict.attacker_faction_id, 'Test attacker',
     'Personaje', 50, 1, 1, 'character', array['Infanteria', 'Caracter'], 2, v_conflict.system_id, 'in_war')
  returning id into v_attacker;

  insert into public.campaign_units
    (slug, faction_id, name, category, points, quantity, starting_quantity,
     unit_type, unit_keywords, experience, current_system_id, status)
  values
    ('test-attacker-character-level-10', v_conflict.attacker_faction_id, 'Test veteran',
     'Personaje', 50, 1, 1, 'character', array['Infanteria', 'Caracter'], 10, v_conflict.system_id, 'in_war')
  returning id into v_veteran;

  insert into public.campaign_units
    (slug, faction_id, name, category, points, quantity, starting_quantity,
     unit_type, unit_keywords, experience, current_system_id, status)
  values
    ('test-destroyed-character', v_conflict.defender_faction_id, 'Test casualty',
     'Personaje', 50, 1, 1, 'character', array['Infanteria', 'Caracter'], 2, v_conflict.system_id, 'in_war')
  returning id into v_destroyed;

  insert into public.campaign_units
    (slug, faction_id, name, category, points, quantity, starting_quantity,
     unit_type, unit_keywords, experience, current_system_id, status)
  values
    ('test-infantry-survivor', v_conflict.defender_faction_id, 'Test infantry',
     'Linea de batalla', 50, 1, 1, 'infantry', array['Infanteria'], 0, v_conflict.system_id, 'in_war')
  returning id into v_infantry;

  select jsonb_object_agg(id::text, case when id = v_destroyed then 0 else quantity end),
         jsonb_object_agg(id::text, 0)
  into v_survivors, v_wounds
  from public.campaign_units
  where current_system_id = v_conflict.system_id and status = 'in_war';

  perform public.apply_battle_outcome(
    v_conflict.id, v_conflict.defender_faction_id, null, null,
    v_survivors, v_wounds, null, null, 'Prueba de experiencia'
  );

  if not exists (select 1 from public.campaign_units where id = v_defender
      and experience = 3 and rank = public.character_rank_for_level(3)) then
    raise exception 'El personaje defensor superviviente no subio de nivel y rango';
  end if;
  if not exists (select 1 from public.campaign_units where id = v_attacker
      and experience = 3 and rank = public.character_rank_for_level(3)) then
    raise exception 'El personaje atacante superviviente no subio de nivel y rango';
  end if;
  if not exists (select 1 from public.campaign_units where id = v_veteran and experience = 10) then
    raise exception 'El personaje de nivel 10 supero el limite';
  end if;
  if not exists (select 1 from public.campaign_units where id = v_destroyed
      and experience = 2 and status = 'destroyed') then
    raise exception 'Un personaje destruido recibio experiencia';
  end if;
  if not exists (select 1 from public.campaign_units where id = v_infantry and experience = 0) then
    raise exception 'Una unidad que no es personaje recibio experiencia';
  end if;

  begin
    perform public.apply_battle_outcome(
      v_conflict.id, v_conflict.defender_faction_id, null, null,
      v_survivors, v_wounds, null, null, 'Intento duplicado'
    );
    raise exception 'Se pudo aplicar dos veces la misma batalla';
  exception when others then
    if sqlerrm = 'Se pudo aplicar dos veces la misma batalla' then
      raise;
    end if;
  end;
end $$;

rollback;
