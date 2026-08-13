create or replace function public.admin_set_campaign_timing_mode(target_mode text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mode text := lower(trim(coalesce(target_mode, '')));
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Solo admin puede cambiar el modo de tiempos';
  end if;

  if v_mode <> 'campaign' then
    raise exception 'La campana real esta activa; solo se puede aplicar el perfil campaign';
  end if;

  v_mode := public.apply_campaign_timing_mode('campaign');

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    auth.uid(),
    'admin_campaign_timing_mode_updated',
    jsonb_build_object('timing_mode', v_mode)
  );

  return v_mode;
end;
$$;

revoke execute on function public.admin_set_campaign_timing_mode(text) from public;
revoke execute on function public.admin_set_campaign_timing_mode(text) from anon;
grant execute on function public.admin_set_campaign_timing_mode(text) to authenticated;
