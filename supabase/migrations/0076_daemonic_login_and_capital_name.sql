-- Final campaign naming update for Daemonic Legions.

update public.systems
set
  name = 'Fasciata',
  updated_at = now()
where slug = 'mordax';
