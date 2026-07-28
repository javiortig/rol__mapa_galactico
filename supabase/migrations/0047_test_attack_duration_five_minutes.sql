update public.campaign_settings
set
  attack_duration_seconds = 300,
  updated_at = now()
where id = 'default';

update public.movement_orders
set
  duration_seconds = 300,
  arrival_at = now() + interval '5 minutes'
where status = 'moving'
  and movement_type = 'attack'
  and arrival_at is not null;

update public.battle_operations
set
  attack_arrival_at = now() + interval '5 minutes',
  updated_at = now()
where status = 'moving'
  and attack_arrival_at is not null;
