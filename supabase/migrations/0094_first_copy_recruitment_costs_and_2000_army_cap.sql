alter table public.campaign_settings
  alter column max_army_points set default 2000;

insert into public.campaign_settings (id, max_army_points, updated_at)
values ('default', 2000, now())
on conflict (id) do update
set
  max_army_points = 2000,
  updated_at = now();

create or replace function public.max_army_points()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select campaign_settings.max_army_points from public.campaign_settings where id = 'default'),
    2000
  );
$$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb)'::regprocedure)
  into v_definition;

  v_patched := v_definition;
  v_patched := replace(v_patched, 'and copy_from <= v_copy_index', 'and copy_from <= 1');
  v_patched := replace(v_patched, 'and unit_template_model_options.copy_from <= v_copy_index', 'and unit_template_model_options.copy_from <= 1');
  v_patched := replace(v_patched, 'and (copy_to is null or v_copy_index <= copy_to)', 'and (copy_to is null or 1 <= copy_to)');
  v_patched := replace(
    v_patched,
    'and (unit_template_model_options.copy_to is null or v_copy_index <= unit_template_model_options.copy_to)',
    'and (unit_template_model_options.copy_to is null or 1 <= unit_template_model_options.copy_to)'
  );
  v_patched := replace(v_patched, '''copyIndex'', v_copy_index', '''copyIndex'', 1');

  if v_patched <> v_definition then
    execute v_patched;
  elsif position('copy_from <= 1' in v_definition) = 0 and position('unit_template_model_options.copy_from <= 1' in v_definition) = 0 then
    raise exception 'No se pudo parchear recruit_unit_variant_at_building para usar siempre coste de primera copia';
  end if;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.enforce_recruitment_points_cap()'::regprocedure)
  into v_definition;

  v_patched := replace(v_definition, 'coalesce(max_army_points, 1000)', 'coalesce(max_army_points, 2000)');
  v_patched := replace(v_patched, 'coalesce(v_max_points, 1000)', 'coalesce(v_max_points, 2000)');

  if v_patched <> v_definition then
    execute v_patched;
  end if;
end $$;

grant execute on function public.max_army_points() to authenticated;

insert into public.campaign_logs (action_type, payload)
values (
  'first_copy_recruitment_costs_enabled',
  jsonb_build_object(
    'max_army_points', 2000,
    'unit_copy_pricing', 'first_copy_only',
    'changed_at', now()
  )
);
