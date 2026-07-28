update public.systems
set
  x = case slug
    when 'blackglass' then 930
    when 'red-sabbath' then 785
    when 'thokt-vault' then 820
    when 'novem' then 705
    else x
  end,
  y = case slug
    when 'blackglass' then 500
    when 'red-sabbath' then 500
    when 'thokt-vault' then 850
    when 'novem' then 735
    else y
  end,
  updated_at = now()
where slug in ('blackglass', 'red-sabbath', 'thokt-vault', 'novem');

update public.system_edges
set
  from_system_id = public.seed_uuid('system', 'novem'),
  to_system_id = public.seed_uuid('system', 'voidmist-basin')
where slug = 'route-06';

update public.system_edges
set
  from_system_id = public.seed_uuid('system', 'red-sabbath'),
  to_system_id = public.seed_uuid('system', 'maelstrom-gas')
where slug = 'route-10';

insert into public.campaign_logs (faction_id, action_type, payload)
values (
  null,
  'necron_genestealer_map_positions_swapped',
  jsonb_build_object(
    'necrones', jsonb_build_object('capital', 'thokt-vault', 'branch', 'lower-right', 'gas_route', 'voidmist-basin'),
    'cultos_genestealer', jsonb_build_object('capital', 'blackglass', 'branch', 'mid-right', 'gas_route', 'maelstrom-gas'),
    'applied_at', now()
  )
);
