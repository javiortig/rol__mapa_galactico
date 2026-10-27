-- One-time Custodes campaign adjustment. Run only after migration 0121.
-- The DO statement is atomic and aborts if any expected live row has changed.

do $$
declare
  v_faction_id uuid;
  v_old_points integer;
  v_new_points integer;
  v_count integer;
  v_row record;
  v_template public.unit_templates%rowtype;
  v_option public.unit_template_model_options%rowtype;
begin
  select id into v_faction_id from public.factions where slug = 'adeptus-custodes';
  if v_faction_id is null then raise exception 'Faccion Custodes ausente'; end if;

  create temporary table custodes_live_changes (
    unit_id uuid primary key,
    old_name text not null,
    old_points integer not null,
    old_quantity integer not null,
    old_starting_quantity integer not null,
    new_slug text not null,
    new_quantity integer not null,
    new_starting_quantity integer not null,
    new_points integer not null
  ) on commit drop;

  insert into custodes_live_changes values
    ('26c21bf3-3abf-48da-8aa7-ced2001d713c', 'Custodian Guard', 215, 5, 5, 'unit-adeptus-custodes-custodian-guard-sodality', 3, 3, 240),
    ('49a5c5ca-3030-4193-9b98-b9e3fff426c5', 'Custodian Guard', 215, 5, 5, 'unit-adeptus-custodes-custodian-guard-sodality', 3, 3, 240),
    ('658b4403-3f5e-49f0-87fc-3c861bba9ec4', 'Witchseekers', 50, 4, 4, 'unit-adeptus-custodes-witchseeker-squad', 4, 4, 55),
    ('70f4b74b-5e6c-4086-8976-3e4cdaf19a09', 'Custodian Guard', 215, 5, 5, 'unit-adeptus-custodes-custodian-guard-sodality', 3, 3, 240),
    ('7c7e3ee1-f6ec-898d-cef4-4623676cb6e8', 'Custodian Guard', 170, 4, 4, 'unit-adeptus-custodes-custodian-guard-sodality', 3, 3, 240),
    ('7f12c16c-55a1-459f-b50f-cfcc7dc89a72', 'Custodian Guard', 170, 4, 4, 'unit-adeptus-custodes-custodian-guard-sodality', 3, 3, 240),
    ('93d33ef5-24cf-43fd-8a93-9b98443ddd1f', 'Custodian Wardens', 250, 2, 5, 'unit-adeptus-custodes-custodian-wardens', 1, 3, 295),
    ('ad3b8f28-b09f-4841-8b1f-8309c91fee42', 'Witchseekers', 50, 1, 4, 'unit-adeptus-custodes-witchseeker-squad', 1, 4, 55),
    ('e842fc8f-f0e1-9b73-d259-a5c5c4c78632', 'Blade Champion', 110, 1, 1, 'unit-adeptus-custodes-blade-champion', 1, 1, 175),
    ('f8453e19-28e1-43ac-91e1-27852800c2b2', 'Prosecutors', 75, 9, 9, 'unit-adeptus-custodes-prosecutor-squad', 9, 9, 80);

  perform 1
  from public.campaign_units as unit
  join custodes_live_changes as changes on changes.unit_id = unit.id
  for update of unit;

  select count(*), coalesce(sum(unit.points), 0)
  into v_count, v_old_points
  from public.campaign_units as unit
  join custodes_live_changes as changes on changes.unit_id = unit.id
  where unit.faction_id = v_faction_id
    and unit.name = changes.old_name
    and unit.points = changes.old_points
    and unit.quantity = changes.old_quantity
    and unit.starting_quantity = changes.old_starting_quantity
    and unit.status <> 'destroyed'
  ;
  if v_count <> 10 or v_old_points <> 1520 then
    raise exception 'El ejercito Custodes ha cambiado: % unidades, % puntos', v_count, v_old_points;
  end if;

  if not exists (
    select 1 from public.recruitment_queue
    where id = '8870f65f-05b9-4875-a9c4-33940cfe21d5'
      and faction_id = v_faction_id and status = 'queued'
      and selected_model_count = 4 and selected_points = 200 and quantity = 1
  ) then
    raise exception 'La cola Warden ya no coincide con el estado esperado';
  end if;

  for v_row in select * from custodes_live_changes loop
    select * into v_template
    from public.unit_templates
    where slug = v_row.new_slug and faction_id = v_faction_id and is_available
    for update;
    if not found then raise exception 'Falta plantilla %', v_row.new_slug; end if;
    select * into v_option
    from public.unit_template_model_options
    where unit_template_id = v_template.id
      and models = v_row.new_starting_quantity and copy_from = 1
      and points = v_row.new_points
    order by id limit 1;
    if not found then raise exception 'Falta coste MFM para %', v_row.new_slug; end if;

    update public.campaign_units
    set unit_template_id = v_template.id,
        name = v_template.name,
        category = v_template.category,
        unit_type = v_template.unit_type,
        unit_keywords = v_template.unit_keywords,
        points = v_row.new_points,
        quantity = v_row.new_quantity,
        starting_quantity = v_row.new_starting_quantity,
        wounds_taken = least(wounds_taken, v_row.new_quantity * v_template.wounds_per_model),
        selected_model_option_id = v_option.id,
        selected_wargear_points = 0,
        selected_wargear_options = '[]'::jsonb,
        point_cost_breakdown = coalesce(point_cost_breakdown, '{}'::jsonb) ||
          jsonb_build_object('basePoints', v_row.new_points, 'wargearPoints', 0),
        updated_at = now()
    where id = v_row.unit_id;
  end loop;

  update public.movement_order_units as moved
  set quantity_at_departure = 1
  from public.movement_orders as orders
  where moved.unit_id = '93d33ef5-24cf-43fd-8a93-9b98443ddd1f'
    and moved.movement_order_id = orders.id
    and orders.status = 'moving';

  select * into v_template from public.unit_templates
  where slug = 'unit-adeptus-custodes-custodian-wardens' and faction_id = v_faction_id;
  select * into v_option from public.unit_template_model_options
  where unit_template_id = v_template.id and models = 2 and points = 200 and copy_from = 1
  order by id limit 1;
  if not found then raise exception 'Falta opcion de 2 Wardens / 200 puntos'; end if;

  update public.recruitment_queue
  set selected_model_count = 2,
      selected_model_option_id = v_option.id,
      selected_points = 200,
      point_cost_breakdown = coalesce(point_cost_breakdown, '{}'::jsonb) ||
        jsonb_build_object('basePoints', 200, 'wargearPoints', 0),
      updated_at = now()
  where id = '8870f65f-05b9-4875-a9c4-33940cfe21d5';

  select coalesce(sum(points), 0) into v_new_points
  from public.campaign_units
  where faction_id = v_faction_id and status <> 'destroyed' and quantity > 0;
  if v_new_points <> 1860 then
    raise exception 'Puntos Custodes inesperados tras ajuste: %', v_new_points;
  end if;

  insert into public.campaign_logs (faction_id, action_type, payload)
  values (v_faction_id, 'admin_custodes_mfm_2026',
    jsonb_build_object('oldArmyPoints', 1520, 'newArmyPoints', 1860,
      'queuedPoints', 200, 'oldTotalPoints', 1720, 'newTotalPoints', 2060,
      'source', 'https://mfm.warhammer-community.com/en/adeptus-custodes'));
end $$;
