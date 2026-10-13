\set ON_ERROR_STOP on
begin;

select id as faction_id from public.factions where slug = 'space-marines' \gset
select capital_system_id as capital_id from public.factions where slug = 'space-marines' \gset
select user_id from public.player_factions where faction_id = :'faction_id' limit 1 \gset
select id as command_template_id from public.building_templates where slug = 'cuartel-mando' \gset
select id as lieutenant_id from public.unit_templates where slug = 'unit-space-marines-lieutenant' \gset
select id as intercessor_id from public.unit_templates where slug = 'unit-space-marines-intercessor-squad' \gset

select set_config('request.jwt.claim.sub', :'user_id', true);

insert into public.system_buildings (system_id, building_template_id, status, constructed_at)
values (:'capital_id', :'command_template_id', 'active', now())
on conflict (system_id, building_template_id) do update set status = 'active'
returning id as command_building_id \gset

insert into public.faction_technologies (faction_id, technology_node_id, status, unlocked_at)
select :'faction_id', required_technology_node_id, 'unlocked', now()
from public.unit_templates where id = :'lieutenant_id'
on conflict (faction_id, technology_node_id) do update set status = 'unlocked', unlocked_at = now();

update public.faction_resources set supply = 500, minerals = 500, honor = 500
where faction_id = :'faction_id';

select public.recruit_unit_variant_at_building(
  :'command_building_id', :'lieutenant_id', 1, '[]'::jsonb, true
) as enchanted_queue_id \gset
select set_config('test.enchanted_queue_id', :'enchanted_queue_id', true);
select set_config('test.faction_id', :'faction_id', true);
select set_config('test.command_building_id', :'command_building_id', true);
select set_config('test.intercessor_id', :'intercessor_id', true);

do $$
begin
  if not exists (
    select 1 from public.unit_template_model_options
    where unit_template_id = current_setting('test.intercessor_id')::uuid
      and models = 5 and points = 85 and copy_from = 1
  ) or not exists (
    select 1 from public.unit_template_model_options
    where unit_template_id = current_setting('test.intercessor_id')::uuid
      and models = 10 and points = 170 and copy_from = 1
  ) then
    raise exception 'Current Intercessor MFM size prices are missing';
  end if;
end $$;

do $$
declare
  v_queue public.recruitment_queue%rowtype;
  v_honor numeric;
begin
  select * into v_queue from public.recruitment_queue where id = current_setting('test.enchanted_queue_id')::uuid;
  select honor into v_honor from public.faction_resources where faction_id = current_setting('test.faction_id')::uuid;
  if not v_queue.is_enchanted or v_queue.honor_cost < 4 then
    raise exception 'Enchanted recruitment was not persisted with honor surcharge';
  end if;
  if v_honor <> 500 - v_queue.honor_cost then
    raise exception 'Enchanted recruitment charged wrong honor amount: %', v_honor;
  end if;
end $$;

update public.recruitment_queue set finishes_at = now() - interval '1 second'
where id = :'enchanted_queue_id';
select public.resolve_recruitment_queue();

do $$
begin
  if not exists (
    select 1 from public.campaign_units
    where slug = 'recruited-' || current_setting('test.enchanted_queue_id') || '-1'
      and is_enchanted and points = 50
  ) then
    raise exception 'Enchantment or MFM points did not reach recruited unit';
  end if;
end $$;

select public.recruit_unit_variant_at_building(
  :'command_building_id', :'lieutenant_id', 1, '[]'::jsonb, false
) as normal_queue_id \gset
select set_config('test.normal_queue_id', :'normal_queue_id', true);

do $$
begin
  if exists (
    select 1 from public.recruitment_queue
    where id = current_setting('test.normal_queue_id')::uuid and is_enchanted
  ) then
    raise exception 'Normal recruitment was enchanted';
  end if;
end $$;

update public.recruitment_queue set finishes_at = now() - interval '1 second'
where id = :'normal_queue_id';
select public.resolve_recruitment_queue();

update public.faction_resources
set honor = (select honor_cost from public.recruitment_queue where id = :'normal_queue_id')
where faction_id = :'faction_id';

do $$
declare
  v_before numeric;
  v_after numeric;
begin
  select honor into v_before from public.faction_resources
  where faction_id = current_setting('test.faction_id')::uuid;
  begin
    perform public.recruit_unit_variant_at_building(
      current_setting('test.command_building_id')::uuid,
      (select id from public.unit_templates where slug = 'unit-space-marines-lieutenant'),
      1, '[]'::jsonb, true
    );
    raise exception 'Insufficient enchantment honor was accepted';
  exception when others then
    if SQLERRM = 'Insufficient enchantment honor was accepted' then raise; end if;
  end;
  select honor into v_after from public.faction_resources
  where faction_id = current_setting('test.faction_id')::uuid;
  if v_after <> v_before or exists (
    select 1 from public.recruitment_queue
    where faction_id = current_setting('test.faction_id')::uuid and status = 'queued'
  ) then
    raise exception 'Rejected enchantment left resource or queue changes behind';
  end if;
end $$;

do $$
begin
  begin
    perform public.recruit_unit_variant_at_building(
      current_setting('test.command_building_id')::uuid,
      current_setting('test.intercessor_id')::uuid, 5, '[]'::jsonb, true
    );
    raise exception 'Non-character enchantment was accepted';
  exception when others then
    if SQLERRM = 'Non-character enchantment was accepted' then raise; end if;
  end;
end $$;

rollback;
