update public.systems
set
  status = 'war',
  controller_faction_id = null,
  is_capital = false,
  blocked_until = coalesce(blocked_until, now() + interval '14 days'),
  public_description = 'Corredor azul con pozos de gravedad inestables. Una horda orka amenaza las rutas de avance custodes.',
  updated_at = now()
where slug = 'azur-trench';

update public.conflicts
set
  attacker_faction_id = (select id from public.factions where slug = 'orcos'),
  defender_faction_id = (select id from public.factions where slug = 'adeptus-custodes'),
  winner_faction_id = null,
  notes = 'Una horda orka amenaza el corredor de la Zanja Azul frente a las lineas de Kharon. Pendiente de batalla fisica.',
  blocked_until = coalesce(blocked_until, now() + interval '14 days')
where slug = 'conflict-azur-trench';
