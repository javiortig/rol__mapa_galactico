-- Custodes-only allied Knight prices and legal Canis Rex size from current MFM.
do $$
declare
  -- BEGIN GENERATED CUSTODES ALLIED MFM PAYLOAD
  v_items jsonb := $mfm$[{"slug":"unit-adeptus-custodes-knight-defender","points":385,"defaultQuantity":1,"supplyCost":74,"mineralsCost":23,"honorCost":38,"goldCost":15,"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":385,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":405,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}]},{"slug":"unit-adeptus-custodes-knight-valiant","points":390,"defaultQuantity":1,"supplyCost":74,"mineralsCost":23,"honorCost":39,"goldCost":15,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":390,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":405,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}]},{"slug":"unit-adeptus-custodes-knight-warden","points":365,"defaultQuantity":1,"supplyCost":73,"mineralsCost":21,"honorCost":36,"goldCost":14,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":365,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":380,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}]},{"slug":"unit-adeptus-custodes-canis-rex","points":415,"defaultQuantity":1,"supplyCost":82,"mineralsCost":24,"honorCost":41,"goldCost":16,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":415,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}]}]$mfm$::jsonb;
  -- END GENERATED CUSTODES ALLIED MFM PAYLOAD
  v_item jsonb;
  v_option jsonb;
  v_template public.unit_templates%rowtype;
begin
  if jsonb_array_length(v_items) <> 4 then
    raise exception 'Se esperaban cuatro ajustes de aliados Custodes';
  end if;

  if exists (
    select 1
    from public.campaign_units as unit
    join public.unit_templates as template on template.id = unit.unit_template_id
    where template.slug in (
      select item.value->>'slug' from jsonb_array_elements(v_items) as item(value)
    )
  ) or exists (
    select 1
    from public.recruitment_queue as queue
    join public.unit_templates as template on template.id = queue.unit_template_id
    where template.slug in (
      select item.value->>'slug' from jsonb_array_elements(v_items) as item(value)
    )
  ) then
    raise exception 'Una unidad aliada Custodes ya existe; revisar antes de actualizar puntos';
  end if;

  for v_item in select value from jsonb_array_elements(v_items) loop
    select * into v_template from public.unit_templates
    where slug = v_item->>'slug'
      and faction_id = (select id from public.factions where slug = 'adeptus-custodes')
    for update;
    if not found then raise exception 'Falta ficha aliada %', v_item->>'slug'; end if;

    update public.unit_templates
    set points = (v_item->>'points')::integer,
        default_quantity = (v_item->>'defaultQuantity')::integer,
        supply_cost = (v_item->>'supplyCost')::integer,
        minerals_cost = (v_item->>'mineralsCost')::integer,
        honor_cost = (v_item->>'honorCost')::integer,
        gold_cost = (v_item->>'goldCost')::integer
    where id = v_template.id;

    for v_option in select value from jsonb_array_elements(v_item->'models') loop
      insert into public.unit_template_model_options (
        id, unit_template_id, slug, label, models, min_models, max_models,
        points, copy_from, copy_to, source, points_change_direction,
        points_change_amount
      ) values (
        public.seed_uuid('unit_template_model_option', (v_item->>'slug') || ':' || (v_option->>'slug')),
        v_template.id, v_option->>'slug', v_option->>'label',
        (v_option->>'models')::integer, (v_option->>'minModels')::integer,
        (v_option->>'maxModels')::integer, (v_option->>'points')::integer,
        (v_option->>'copyFrom')::integer, (v_option->>'copyTo')::integer,
        'mfm', v_option->>'changeDirection', (v_option->>'changeAmount')::integer
      ) on conflict (unit_template_id, slug) do update set
        label = excluded.label, models = excluded.models,
        min_models = excluded.min_models, max_models = excluded.max_models,
        points = excluded.points, copy_from = excluded.copy_from,
        copy_to = excluded.copy_to, source = excluded.source,
        points_change_direction = excluded.points_change_direction,
        points_change_amount = excluded.points_change_amount,
        updated_at = now();
    end loop;

    delete from public.unit_template_model_options as option
    where option.unit_template_id = v_template.id
      and not exists (
        select 1 from jsonb_array_elements(v_item->'models') as listed(value)
        where listed.value->>'slug' = option.slug
      );
  end loop;
end $$;
