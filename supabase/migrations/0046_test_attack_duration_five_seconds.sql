update public.campaign_settings
set
  attack_duration_seconds = 5,
  updated_at = now()
where id = 'default';

update public.movement_orders
set
  duration_seconds = 5,
  arrival_at = least(arrival_at, now() + interval '5 seconds')
where status = 'moving'
  and movement_type = 'attack'
  and arrival_at is not null
  and arrival_at > now() + interval '5 seconds';

update public.battle_operations
set
  attack_arrival_at = least(attack_arrival_at, now() + interval '5 seconds'),
  updated_at = now()
where status = 'moving'
  and attack_arrival_at is not null
  and attack_arrival_at > now() + interval '5 seconds';
