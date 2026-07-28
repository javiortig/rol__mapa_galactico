create or replace function public.admin_set_campaign_limits(
  max_supply integer,
  max_minerals integer,
  max_honor integer,
  max_gold integer,
  max_industrial_material integer,
  max_uridium integer,
  max_technology integer,
  max_army_points integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or not public.is_admin() then
    raise exception 'Solo admin puede modificar limites de campana';
  end if;

  update public.campaign_settings
  set
    max_supply = greatest(coalesce(admin_set_campaign_limits.max_supply, public.campaign_settings.max_supply), 0),
    max_minerals = greatest(coalesce(admin_set_campaign_limits.max_minerals, public.campaign_settings.max_minerals), 0),
    max_honor = greatest(coalesce(admin_set_campaign_limits.max_honor, public.campaign_settings.max_honor), 0),
    max_gold = greatest(coalesce(admin_set_campaign_limits.max_gold, public.campaign_settings.max_gold), 0),
    max_industrial_material = greatest(coalesce(admin_set_campaign_limits.max_industrial_material, public.campaign_settings.max_industrial_material), 0),
    max_uridium = greatest(coalesce(admin_set_campaign_limits.max_uridium, public.campaign_settings.max_uridium), 0),
    max_technology = greatest(coalesce(admin_set_campaign_limits.max_technology, public.campaign_settings.max_technology), 0),
    max_army_points = greatest(coalesce(admin_set_campaign_limits.max_army_points, public.campaign_settings.max_army_points), 0),
    updated_at = now()
  where id = 'default';

  update public.faction_resources
  set
    supply = supply,
    minerals = minerals,
    honor = honor,
    gold = gold,
    industrial_material = industrial_material,
    uridium = uridium,
    technology = technology,
    updated_at = now()
  where true;

  insert into public.campaign_logs (actor_user_id, action_type, payload)
  values (
    v_user_id,
    'admin_campaign_limits_updated',
    jsonb_build_object(
      'max_supply', admin_set_campaign_limits.max_supply,
      'max_minerals', admin_set_campaign_limits.max_minerals,
      'max_honor', admin_set_campaign_limits.max_honor,
      'max_gold', admin_set_campaign_limits.max_gold,
      'max_industrial_material', admin_set_campaign_limits.max_industrial_material,
      'max_uridium', admin_set_campaign_limits.max_uridium,
      'max_technology', admin_set_campaign_limits.max_technology,
      'max_army_points', admin_set_campaign_limits.max_army_points
    )
  );
end;
$$;

revoke execute on function public.admin_set_campaign_limits(integer, integer, integer, integer, integer, integer, integer, integer) from public;
grant execute on function public.admin_set_campaign_limits(integer, integer, integer, integer, integer, integer, integer, integer) to authenticated;
