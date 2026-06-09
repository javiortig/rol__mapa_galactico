alter table public.campaign_settings
  alter column conflict_block_duration_minutes set default 20160;

update public.campaign_settings
set
  conflict_block_duration_minutes = 20160,
  updated_at = now()
where id = 'default';
