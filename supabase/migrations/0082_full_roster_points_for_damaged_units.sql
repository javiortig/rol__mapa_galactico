create or replace function public.unit_roster_points(unit_points integer, unit_quantity integer)
returns integer
language sql
immutable
as $$
  select case
    when coalesce(unit_quantity, 0) <= 0 then 0
    else greatest(coalesce(unit_points, 0), 0)
  end;
$$;

do $$
declare
  v_signature regprocedure;
  v_definition text;
  v_patched text;
begin
  foreach v_signature in array array[
    'public.create_attack_order(jsonb, uuid, uuid)'::regprocedure,
    'public.create_coalition_attack_draft(jsonb, uuid, uuid, uuid[])'::regprocedure,
    'public.join_battle_operation(uuid, jsonb, uuid[])'::regprocedure,
    'public.capture_arrived_defense_support_units()'::regprocedure
  ]
  loop
    select pg_get_functiondef(v_signature::oid) into v_definition;
    v_patched := v_definition;

    v_patched := regexp_replace(
      v_patched,
      'greatest\(\s*1,\s*ceil\(\(v_unit\.points::numeric \* v_unit\.quantity\) / greatest\(v_unit\.starting_quantity, 1\)\)::integer\s*\)',
      'public.unit_roster_points(v_unit.points, v_unit.quantity)',
      'g'
    );

    v_patched := regexp_replace(
      v_patched,
      'greatest\(\s*1,\s*ceil\(\(units\.points::numeric \* units\.quantity\) / greatest\(units\.starting_quantity, 1\)\)::integer\s*\)',
      'public.unit_roster_points(units.points, units.quantity)',
      'g'
    );

    v_patched := regexp_replace(
      v_patched,
      'ceil\(\(units\.points::numeric \* units\.quantity\) / greatest\(units\.starting_quantity, 1\)\)::integer',
      'public.unit_roster_points(units.points, units.quantity)',
      'g'
    );

    if v_patched <> v_definition then
      execute v_patched;
    end if;

    if position('(v_unit.points::numeric * v_unit.quantity)' in pg_get_functiondef(v_signature::oid)) > 0
      or position('(units.points::numeric * units.quantity)' in pg_get_functiondef(v_signature::oid)) > 0 then
      raise exception 'No se pudo eliminar el prorrateo de puntos en %', v_signature::text;
    end if;
  end loop;
end $$;

update public.battle_unit_commitments
set
  points_at_commitment = public.unit_roster_points(campaign_units.points, battle_unit_commitments.quantity_at_commitment),
  updated_at = now()
from public.campaign_units
where campaign_units.id = battle_unit_commitments.unit_id
  and battle_unit_commitments.points_at_commitment
    is distinct from public.unit_roster_points(campaign_units.points, battle_unit_commitments.quantity_at_commitment);

insert into public.campaign_logs (action_type, payload)
values (
  'unit_roster_points_rule_enforced',
  jsonb_build_object(
    'rule', 'Las unidades vivas cuentan siempre sus puntos completos de ficha aunque pierdan miniaturas o heridas.'
  )
);
