create or replace function public.validate_battle_survivors_and_wounds(
  target_conflict_id uuid,
  survivors jsonb,
  wounds_remaining jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conflict public.conflicts%rowtype;
  v_unit record;
  v_survivors integer;
  v_wounds integer;
  v_casualties jsonb := '{}'::jsonb;
begin
  select *
  into v_conflict
  from public.conflicts
  where id = target_conflict_id;

  if not found then
    raise exception 'Conflicto no encontrado';
  end if;

  if survivors is null or jsonb_typeof(survivors) <> 'object' then
    raise exception 'El reporte debe indicar supervivientes por unidad';
  end if;

  if wounds_remaining is null or jsonb_typeof(wounds_remaining) <> 'object' then
    raise exception 'El reporte debe indicar heridas por unidad';
  end if;

  for v_unit in
    select
      campaign_units.*,
      coalesce(unit_templates.wounds_per_model, 1) as wounds_per_model
    from public.campaign_units
    left join public.unit_templates on unit_templates.id = campaign_units.unit_template_id
    where campaign_units.current_system_id = v_conflict.system_id
      and campaign_units.status = 'in_war'
    order by campaign_units.created_at, campaign_units.id
  loop
    if not (survivors ? v_unit.id::text) then
      raise exception 'Faltan supervivientes para una unidad en guerra';
    end if;

    if not (wounds_remaining ? v_unit.id::text) then
      raise exception 'Faltan heridas restantes para una unidad en guerra';
    end if;

    v_survivors := nullif(survivors->>v_unit.id::text, '')::integer;
    v_wounds := nullif(wounds_remaining->>v_unit.id::text, '')::integer;

    if v_survivors is null or v_survivors < 0 or v_survivors > v_unit.starting_quantity then
      raise exception 'Cantidad de supervivientes no valida';
    end if;

    if v_wounds is null or v_wounds < 0 or v_wounds > v_survivors * v_unit.wounds_per_model then
      raise exception 'Cantidad de heridas no valida';
    end if;

    if v_survivors = 0 and v_wounds <> 0 then
      raise exception 'Una unidad destruida no puede conservar heridas';
    end if;

    v_casualties := v_casualties || jsonb_build_object(
      v_unit.id::text,
      v_unit.starting_quantity - v_survivors
    );
  end loop;

  return v_casualties;
end;
$$;

revoke execute on function public.validate_battle_survivors_and_wounds(uuid, jsonb, jsonb) from public;
