-- Campaign timing tweak: the common Progreso branch is intentionally faster
-- than the rest of the technology tree in real campaign mode.

do $$
declare
  v_definition text;
  v_patched text;
  v_old text := '    update public.technology_nodes
    set research_time_seconds = greatest(86400, greatest(cost_technology, 1) * 86400),
        updated_at = now()
    where research_time_seconds is distinct from greatest(86400, greatest(cost_technology, 1) * 86400);';
  v_new text := '    update public.technology_nodes
    set research_time_seconds = case
      when tree_key = ''common-v1'' and branch = ''Progreso'' and cost_technology <= 0 then 1800
      when tree_key = ''common-v1'' and branch = ''Progreso'' and cost_technology = 1 then 7200
      when tree_key = ''common-v1'' and branch = ''Progreso'' and cost_technology = 2 then 21600
      else greatest(86400, greatest(cost_technology, 1) * 86400)
    end,
        updated_at = now()
    where research_time_seconds is distinct from case
      when tree_key = ''common-v1'' and branch = ''Progreso'' and cost_technology <= 0 then 1800
      when tree_key = ''common-v1'' and branch = ''Progreso'' and cost_technology = 1 then 7200
      when tree_key = ''common-v1'' and branch = ''Progreso'' and cost_technology = 2 then 21600
      else greatest(86400, greatest(cost_technology, 1) * 86400)
    end;';
begin
  select pg_get_functiondef('public.apply_campaign_timing_mode(text)'::regprocedure)
  into v_definition;

  v_patched := replace(v_definition, v_old, v_new);

  if v_patched = v_definition then
    raise exception 'Could not patch apply_campaign_timing_mode technology timing block';
  end if;

  execute v_patched;
end $$;

revoke execute on function public.apply_campaign_timing_mode(text) from public;
revoke execute on function public.apply_campaign_timing_mode(text) from anon;
revoke execute on function public.apply_campaign_timing_mode(text) from authenticated;

do $$
begin
  if exists (
    select 1
    from public.campaign_settings
    where id = 'default'
      and timing_mode = 'campaign'
  ) then
    perform public.apply_campaign_timing_mode('campaign');
  end if;
end $$;
