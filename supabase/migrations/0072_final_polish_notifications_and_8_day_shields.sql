create or replace function public.apply_neutral_conquest_shield()
returns trigger
language plpgsql
as $$
begin
  if old.status = 'neutral'
    and new.status = 'controlled'
    and old.controller_faction_id is null
    and new.controller_faction_id is not null
    and new.blocked_until is null
    and coalesce(new.is_capital, false) = false
    and coalesce(new.is_temporary_mission, false) = false then
    new.blocked_until := now() + interval '8 days';
  end if;

  return new;
end;
$$;

update public.systems
set name = 'Yaracuby77 Mina Abandonada',
    updated_at = now()
where slug = 'blackglass';

update public.systems
set blocked_until = least(blocked_until, now() + interval '8 days'),
    updated_at = now()
where status = 'controlled'
  and blocked_until is not null
  and blocked_until > now()
  and coalesce(is_capital, false) = false
  and coalesce(is_temporary_mission, false) = false;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.submit_battle_report(uuid, jsonb)'::regprocedure)
  into v_definition;

  v_patched := replace(v_definition, 'now() + interval ''14 days''', 'now() + interval ''8 days''');

  if v_patched = v_definition then
    raise exception 'No se pudo parchear submit_battle_report a escudo de 8 dias';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.validate_battle_report(uuid)'::regprocedure)
  into v_definition;

  v_patched := replace(v_definition, 'now() + interval ''14 days''', 'now() + interval ''8 days''');

  if v_patched = v_definition then
    raise exception 'No se pudo parchear validate_battle_report a escudo de 8 dias';
  end if;

  execute v_patched;
end $$;

do $$
declare
  v_definition text;
  v_patched text;
begin
  select pg_get_functiondef('public.admin_confirm_battle_report(uuid, jsonb)'::regprocedure)
  into v_definition;

  v_patched := replace(v_definition, 'now() + interval ''14 days''', 'now() + interval ''8 days''');

  if v_patched = v_definition then
    raise exception 'No se pudo parchear admin_confirm_battle_report a escudo de 8 dias';
  end if;

  execute v_patched;
end $$;

revoke execute on function public.submit_battle_report(uuid, jsonb) from public;
revoke execute on function public.validate_battle_report(uuid) from public;
revoke execute on function public.admin_confirm_battle_report(uuid, jsonb) from public;

grant execute on function public.submit_battle_report(uuid, jsonb) to authenticated;
grant execute on function public.validate_battle_report(uuid) to authenticated;
grant execute on function public.admin_confirm_battle_report(uuid, jsonb) to authenticated;
