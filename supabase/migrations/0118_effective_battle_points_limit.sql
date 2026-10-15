-- An incoming narrative attack may set a stricter limit than its target system.
-- Once a conflict exists, its limit is frozen for the duration of that battle.
create or replace function public.validate_system_battle_side_points(
  target_system_id uuid,
  attacker_faction_id uuid,
  defender_faction_id uuid,
  side_points integer,
  side_label text default 'bando'
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit integer;
begin
  select coalesce(
    (
      select conflicts.battle_points_limit
      from public.conflicts
      where conflicts.system_id = target_system_id
        and conflicts.status = 'pending'
      order by conflicts.created_at desc
      limit 1
    ),
    (
      select narrative_attacks.battle_points_limit
      from public.narrative_attacks
      where narrative_attacks.system_id = target_system_id
        and narrative_attacks.status = 'incoming'
      order by narrative_attacks.created_at desc
      limit 1
    ),
    (select systems.battle_points_limit from public.systems where systems.id = target_system_id)
  ) into v_limit;

  if v_limit is null then
    raise exception 'Sistema objetivo no encontrado';
  end if;

  if coalesce(side_points, 0) > v_limit then
    raise exception 'El % supera el limite de % puntos (% pts)',
      coalesce(side_label, 'bando'), v_limit, side_points;
  end if;
end;
$$;
