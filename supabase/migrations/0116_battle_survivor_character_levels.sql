-- Experience is awarded when the battle outcome is applied, regardless of
-- whether players validated the report or an admin resolved it directly.
do $$
declare
  v_definition text;
  v_patched text;
  v_anchor text := '    v_wounds := (wounds_remaining->>v_unit.id::text)::integer;';
begin
  select pg_get_functiondef(
    'public.apply_battle_outcome(uuid, uuid, uuid, timestamptz, jsonb, jsonb, uuid, uuid, text)'::regprocedure
  ) into v_definition;

  if (length(v_definition) - length(replace(v_definition, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception 'No se encontro una unica posicion para premiar experiencia de batalla';
  end if;

  v_patched := replace(
    v_definition,
    v_anchor,
    v_anchor || $award$

    if v_survivors > 0
      and (v_unit.unit_type = 'character' or 'Caracter' = any(v_unit.unit_keywords)) then
      update public.campaign_units
      set experience = least(10, greatest(1, coalesce(experience, 1)) + 1),
          updated_at = now()
      where id = v_unit.id;
    end if;$award$
  );

  v_anchor := '  perform public.validate_battle_survivors_and_wounds(target_conflict_id, survivors, wounds_remaining);';
  if (length(v_patched) - length(replace(v_patched, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception 'No se encontro una unica validacion del reporte de batalla';
  end if;

  v_patched := replace(
    v_patched,
    v_anchor,
    $guard$  if v_conflict.status <> 'pending' then
    raise exception 'La batalla ya no esta pendiente';
  end if;

$guard$ || v_anchor
  );

  execute v_patched;
end $$;

-- Both live characters were level 2 before this change. Do not lower a unit
-- that has already gained a level while the migration was being prepared.
update public.campaign_units
set experience = greatest(experience, 3),
    updated_at = now()
where slug in ('necron-plasmancer', 'custodes-blade-champion')
  and quantity > 0
  and status <> 'destroyed'
  and experience < 3;
