do $$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef('public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb)'::regprocedure);

  v_definition := replace(
    v_definition,
    'from public.campaign_units
      where faction_id = v_faction_id
        and unit_template_id = v_template.id
        and status <> ''destroyed''',
    'from public.campaign_units
      where faction_id = v_faction_id
        and campaign_units.unit_template_id = v_template.id
        and status <> ''destroyed'''
  );

  v_definition := replace(
    v_definition,
    'from public.recruitment_queue
      where faction_id = v_faction_id
        and unit_template_id = v_template.id
        and status = ''queued''',
    'from public.recruitment_queue
      where faction_id = v_faction_id
        and recruitment_queue.unit_template_id = v_template.id
        and status = ''queued'''
  );

  v_definition := replace(
    v_definition,
    'from public.unit_template_model_options
  where unit_template_id = v_template.id
    and min_models <= v_model_count',
    'from public.unit_template_model_options
  where unit_template_model_options.unit_template_id = v_template.id
    and min_models <= v_model_count'
  );

  v_definition := replace(
    v_definition,
    'exists (select 1 from public.unit_template_model_options where unit_template_id = v_template.id)',
    'exists (select 1 from public.unit_template_model_options where unit_template_model_options.unit_template_id = v_template.id)'
  );

  v_definition := replace(
    v_definition,
    'from public.unit_template_wargear_options
    where unit_template_id = v_template.id
      and slug = v_wargear_slug',
    'from public.unit_template_wargear_options
    where unit_template_wargear_options.unit_template_id = v_template.id
      and slug = v_wargear_slug'
  );

  execute v_definition;
end;
$$;

revoke execute on function public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb) from public;
revoke execute on function public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb) from anon;
grant execute on function public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb) to authenticated;
