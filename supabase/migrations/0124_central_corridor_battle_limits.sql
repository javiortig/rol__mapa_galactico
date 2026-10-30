do $$
declare
  v_updated integer;
begin
  update public.systems
  set battle_points_limit = 800,
      updated_at = now()
  where slug in ('corona-voss', 'nadir-kappa', 'cicatriz-helion')
    and battle_points_limit = 500;

  get diagnostics v_updated = row_count;
  if v_updated <> 3 then
    raise exception 'Se esperaban tres sistemas con limite de 500 puntos; se actualizaron %', v_updated;
  end if;
end $$;
