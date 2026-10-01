\set ON_ERROR_STOP on
begin;

create function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if not coalesce(condition, false) then
    raise exception '%', message;
  end if;
end $$;

select id as attacker_faction from public.factions where slug = 'adeptus-custodes' \gset
select id as defender_faction from public.factions where slug = 'legiones-daemonicas' \gset
select id as observer_faction from public.factions where slug = 'necrones' \gset
select id as cult_faction from public.factions where slug = 'cultos-genestealer' \gset
select id as attacker_user from auth.users where email = 'adeptus-custodes@rol40k.local' \gset
select id as defender_user from auth.users where email = 'legiones-daemonicas@rol40k.local' \gset
select id as observer_user from auth.users where email = 'necrones@rol40k.local' \gset
select id as cult_user from auth.users where email = 'cultos-genestealer@rol40k.local' \gset
select id as origin_system from public.systems where slug = 'kharon-prime' \gset
select id as target_system from public.systems where slug = 'drusus' \gset
select id as presence_system from public.systems where slug = 'helios-drift' \gset
select id as necron_origin from public.systems where slug = 'thokt-vault' \gset
select id as other_target from public.systems where slug = 'red-sabbath' \gset
select id as attacker_unit from public.campaign_units where faction_id = :'attacker_faction' and status = 'ready' limit 1 \gset
select id as observer_unit from public.campaign_units where faction_id = :'observer_faction' and status = 'ready' limit 1 \gset
select id as cult_unit from public.campaign_units where faction_id = :'cult_faction' and status = 'ready' limit 1 \gset
select id as attack_id from (select gen_random_uuid() as id) ids \gset
select id as movement_id from (select gen_random_uuid() as id) ids \gset
select id as inbound_id from (select gen_random_uuid() as id) ids \gset
select id as outbound_id from (select gen_random_uuid() as id) ids \gset
select id as origin_witness_attack_id from (select gen_random_uuid() as id) ids \gset
select id as operation_id from (select gen_random_uuid() as id) ids \gset
select id as witness_operation_id from (select gen_random_uuid() as id) ids \gset

insert into public.movement_orders
  (id, faction_id, from_system_id, to_system_id, uridium_cost, status, path_system_ids,
   segment_count, duration_seconds, movement_type, movement_purpose, departure_at, arrival_at)
values
  (:'attack_id', :'attacker_faction', :'origin_system', :'target_system', 1, 'moving',
   array[:'origin_system'::uuid, :'target_system'::uuid], 1, 7200, 'attack', 'attack', now() - interval '1 hour', now() + interval '1 hour'),
  (:'movement_id', :'attacker_faction', :'origin_system', :'necron_origin', 1, 'moving',
   array[:'origin_system'::uuid, :'target_system'::uuid, :'necron_origin'::uuid], 2, 7200, 'move', 'normal', now() - interval '30 minutes', now() + interval '90 minutes'),
  (:'inbound_id', :'observer_faction', :'necron_origin', :'target_system', 1, 'moving',
   array[:'necron_origin'::uuid, :'presence_system'::uuid, :'target_system'::uuid], 2, 7200, 'move', 'normal', now() - interval '30 minutes', now() + interval '90 minutes'),
  (:'outbound_id', :'observer_faction', :'necron_origin', :'target_system', 1, 'moving',
   array[:'necron_origin'::uuid, :'presence_system'::uuid, :'target_system'::uuid], 2, 7200, 'move', 'normal', now() - interval '90 minutes', now() + interval '30 minutes'),
  (:'origin_witness_attack_id', :'observer_faction', :'presence_system', :'other_target', 1, 'moving',
   array[:'presence_system'::uuid, :'other_target'::uuid], 1, 7200, 'attack', 'attack', now() - interval '1 hour', now() + interval '1 hour');

insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
values
  (:'attack_id', :'attacker_unit', 1),
  (:'movement_id', :'attacker_unit', 1),
  (:'inbound_id', :'observer_unit', 1),
  (:'outbound_id', :'observer_unit', 1),
  (:'origin_witness_attack_id', :'observer_unit', 1);

insert into public.battle_operations
  (id, mode, status, leader_faction_id, defender_faction_id, origin_system_id,
   target_system_id, attack_movement_order_id, attack_arrival_at)
values
  (:'operation_id', 'solo', 'moving', :'attacker_faction', :'defender_faction',
   :'origin_system', :'target_system', :'attack_id', now() + interval '1 hour'),
  (:'witness_operation_id', 'coalition', 'moving', :'observer_faction', :'cult_faction',
   :'presence_system', :'other_target', :'origin_witness_attack_id', now() + interval '1 hour');

update public.movement_orders
set battle_operation_id = case
  when id = :'attack_id' then :'operation_id'::uuid
  else :'witness_operation_id'::uuid end
where id in (:'attack_id', :'origin_witness_attack_id');

insert into public.battle_operation_members
  (operation_id, faction_id, side, role, invitation_status)
values
  (:'operation_id', :'attacker_faction', 'attacker', 'commander', 'accepted'),
  (:'operation_id', :'defender_faction', 'defender', 'commander', 'accepted'),
  (:'witness_operation_id', :'observer_faction', 'attacker', 'commander', 'accepted'),
  (:'witness_operation_id', :'cult_faction', 'defender', 'commander', 'accepted');

insert into public.battle_unit_commitments
  (operation_id, unit_id, faction_id, side, role, home_system_id,
   staging_system_id, outbound_path_system_ids, quantity_at_commitment,
   points_at_commitment, status)
values
  (:'operation_id', :'attacker_unit', :'attacker_faction', 'attacker', 'leader',
   :'origin_system', :'target_system', array[:'origin_system'::uuid, :'target_system'::uuid],
   1, 99, 'en_route'),
  (:'witness_operation_id', :'observer_unit', :'observer_faction', 'attacker', 'leader',
   :'presence_system', :'other_target', array[:'presence_system'::uuid, :'other_target'::uuid],
   1, 88, 'en_route');

set local role authenticated;

select set_config('request.jwt.claim.sub', :'defender_user', true);
select pg_temp.assert_true(not exists (select 1 from public.movement_orders where id = :'attack_id'), 'Defender can read the incoming attack order');
select pg_temp.assert_true(not exists (select 1 from public.get_visible_movement_order_units() where movement_order_id in (:'attack_id', :'movement_id')), 'Defender can read concealed units');
select pg_temp.assert_true(not exists (select 1 from public.battle_unit_commitments where operation_id = :'operation_id' and side = 'attacker'), 'Defender can read attack points');
select pg_temp.assert_true(not exists (select 1 from public.campaign_units where id = :'attacker_unit'), 'Defender can read attacker unit directly');
select pg_temp.assert_true(exists (select 1 from public.get_visible_movement_orders() where id = :'movement_id' and cardinality(path_system_ids) = 2), 'System owner cannot see the adjacent movement edge');
select pg_temp.assert_true(exists (select 1 from public.get_public_incoming_attack_alerts() where system_id = :'target_system' and :'attacker_faction'::uuid = any(attacker_faction_ids)), 'Defender cannot see attacker faction');
select pg_temp.assert_true(exists (select 1 from public.get_defender_incoming_attack_routes() where from_system_id = :'origin_system' and to_system_id = :'target_system'), 'Defender cannot see redacted incoming attack route');

select set_config('request.jwt.claim.sub', :'attacker_user', true);
select pg_temp.assert_true(exists (select 1 from public.get_visible_movement_orders() where id = :'attack_id' and cardinality(path_system_ids) = 2), 'Attack owner cannot see full order');
select pg_temp.assert_true(exists (select 1 from public.get_visible_movement_order_units() where movement_order_id = :'attack_id'), 'Attack owner cannot see units');
select pg_temp.assert_true(exists (select 1 from public.movement_orders where id = :'origin_witness_attack_id'), 'Troop presence at attack origin cannot see full attack');
select pg_temp.assert_true(exists (select 1 from public.campaign_units where id = :'observer_unit'), 'Troop presence at attack origin cannot read attack unit');
select pg_temp.assert_true(exists (select 1 from public.battle_unit_commitments where operation_id = :'witness_operation_id' and points_at_commitment = 88), 'Troop presence at attack origin cannot read coalition force');
select pg_temp.assert_true(exists (select 1 from public.get_visible_movement_orders() where id = :'outbound_id'), 'Troop presence cannot see outgoing movement');
select pg_temp.assert_true(not exists (select 1 from public.get_visible_movement_orders() where id = :'inbound_id'), 'Troop presence can see incoming movement');
select pg_temp.assert_true(not exists (select 1 from public.get_visible_movement_order_units() where movement_order_id = :'outbound_id'), 'Troop presence can read outgoing movement units');

select set_config('request.jwt.claim.sub', :'observer_user', true);
select pg_temp.assert_true(exists (select 1 from public.get_public_incoming_attack_alerts() where system_id = :'target_system' and cardinality(attacker_faction_ids) = 0), 'Unrelated faction cannot see a redacted public attack alert');
select pg_temp.assert_true(not exists (select 1 from public.get_defender_incoming_attack_routes() where to_system_id = :'target_system'), 'Unrelated faction can inspect defender attack route');

-- A joined attacker sees the complete coalition roster, not only the leader's units.
reset role;
update public.battle_operations set mode = 'coalition' where id = :'operation_id';
insert into public.battle_operation_members
  (operation_id, faction_id, side, role, invitation_status)
values (:'operation_id', :'cult_faction', 'attacker', 'supporter', 'accepted');
update public.campaign_units set current_system_id = :'origin_system', status = 'moving' where id = :'cult_unit';
insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
values (:'attack_id', :'cult_unit', 1);
insert into public.battle_unit_commitments
  (operation_id, unit_id, faction_id, side, role, home_system_id,
   staging_system_id, outbound_path_system_ids, quantity_at_commitment,
   points_at_commitment, status)
values (:'operation_id', :'cult_unit', :'cult_faction', 'attacker', 'supporter',
  :'origin_system', :'target_system', array[:'origin_system'::uuid, :'target_system'::uuid],
  1, 77, 'en_route');
set local role authenticated;
select set_config('request.jwt.claim.sub', :'cult_user', true);
select pg_temp.assert_true(exists (select 1 from public.get_visible_movement_orders() where id = :'attack_id'), 'Accepted coalition supporter cannot see the attack order');
select pg_temp.assert_true((select count(*) from public.get_visible_movement_order_units() where movement_order_id = :'attack_id') = 2, 'Accepted coalition supporter cannot see every attack unit link');
select pg_temp.assert_true(exists (select 1 from public.campaign_units where id = :'attacker_unit'), 'Accepted coalition supporter cannot see leader unit');
select pg_temp.assert_true(exists (select 1 from public.campaign_units where id = :'cult_unit'), 'Accepted coalition supporter cannot see own unit');

-- Arriving at the origin after departure must not reveal the attack force.
reset role;
update public.campaign_units
set current_system_id = :'origin_system', status = 'moving'
where id = :'attacker_unit';
update public.campaign_units
set current_system_id = :'origin_system', status = 'ready'
where id = :'observer_unit';
set local role authenticated;
select set_config('request.jwt.claim.sub', :'observer_user', true);
select pg_temp.assert_true(public.user_has_presence_in_system(:'origin_system'), 'Late observer is not present at the origin');
select pg_temp.assert_true(not exists (select 1 from public.movement_orders where id = :'attack_id'), 'Late observer can read attack order');
select pg_temp.assert_true(not exists (select 1 from public.get_visible_movement_orders() where id = :'attack_id'), 'Late observer can read attack through visible orders');
select pg_temp.assert_true(not exists (select 1 from public.get_visible_movement_order_units() where movement_order_id = :'attack_id'), 'Late observer can read attack unit links');
select pg_temp.assert_true(not exists (select 1 from public.battle_unit_commitments where operation_id = :'operation_id' and side = 'attacker'), 'Late observer can read attack points');
select pg_temp.assert_true(not exists (select 1 from public.campaign_units where id = :'attacker_unit'), 'Late observer can read moving attacker as garrison');

rollback;
