\set ON_ERROR_STOP on
begin;

select id as faction_id from public.factions where slug = 'necrones' \gset
select capital_system_id as capital_id from public.factions where slug = 'necrones' \gset
select user_id from public.player_factions where faction_id = :'faction_id' limit 1 \gset
select id as barracks_template_id from public.building_templates where slug = 'barracon-infanteria' \gset
select id as immortals_id from public.unit_templates where slug = 'unit-necrones-immortals' \gset

select set_config('request.jwt.claim.sub', :'user_id', true);

insert into public.system_buildings (system_id, building_template_id, status, constructed_at)
values (:'capital_id', :'barracks_template_id', 'active', now())
on conflict (system_id, building_template_id) do update set status = 'active'
returning id as barracks_id \gset

insert into public.faction_technologies (faction_id, technology_node_id, status, unlocked_at)
select :'faction_id', required_technology_node_id, 'unlocked', now()
from public.unit_templates where id = :'immortals_id'
on conflict (faction_id, technology_node_id) do update set status = 'unlocked', unlocked_at = now();

update public.faction_resources set supply = 500 where faction_id = :'faction_id';

select public.recruit_unit_variant_at_building(
  :'barracks_id', :'immortals_id', 10, '[]'::jsonb, false
) as queue_id \gset

select set_config('test.necron_queue_id', :'queue_id', true);

do $$
declare
  v_queue public.recruitment_queue%rowtype;
  v_cost record;
begin
  select * into v_queue from public.recruitment_queue
  where id = current_setting('test.necron_queue_id')::uuid;
  select * into v_cost from public.recruitment_cost_bundle_for_template(v_queue.unit_template_id, 130);
  if v_queue.selected_points <> 130 or v_queue.selected_model_count <> 10 then
    raise exception 'Immortals 10-model MFM price was not used';
  end if;
  if v_queue.supply_cost <> v_cost.supply_cost or v_cost.supply_cost <> 130
    or v_queue.minerals_cost <> 0 or v_queue.honor_cost <> 0 or v_queue.gold_cost <> 0 then
    raise exception 'Immortals recruitment cost no longer matches its supply-only profile';
  end if;
end $$;

rollback;
