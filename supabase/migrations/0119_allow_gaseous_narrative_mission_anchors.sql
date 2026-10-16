-- A temporary mission can branch from a gaseous corridor, but never from
-- another temporary mission. Keep the rest of the placement logic unchanged.
do $$
declare
  v_definition text;
  v_patched text;
  v_old text := 'if coalesce(v_anchor.system_kind, ''standard'') = ''gaseous''
    or coalesce(v_anchor.is_temporary_mission, false) then
    raise exception ''La mision debe conectarse a un sistema normal'';';
  v_new text := 'if coalesce(v_anchor.is_temporary_mission, false) then
    raise exception ''La mision no puede conectarse a otra mision temporal'';';
begin
  select pg_get_functiondef(
    'public.admin_create_narrative_mission(uuid,uuid,text,text,boolean,jsonb,integer,boolean)'::regprocedure
  ) into v_definition;

  if v_definition is null or position(v_old in v_definition) = 0 then
    raise exception 'No se encontro la validacion original del anclaje de mision';
  end if;

  v_patched := replace(v_definition, v_old, v_new);
  execute v_patched;
end $$;
