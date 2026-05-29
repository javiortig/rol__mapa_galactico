create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

create or replace function public.is_faction_member(target_faction_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.player_factions
    where user_id = auth.uid()
      and faction_id = target_faction_id
  );
$$;

create or replace function public.seed_uuid(prefix text, slug text)
returns uuid
language plpgsql
immutable
as $$
declare
  hash text := md5(prefix || ':' || slug);
begin
  return (
    substr(hash, 1, 8) || '-' ||
    substr(hash, 9, 4) || '-' ||
    substr(hash, 13, 4) || '-' ||
    substr(hash, 17, 4) || '-' ||
    substr(hash, 21, 12)
  )::uuid;
end;
$$;

alter table public.factions add column if not exists slug text;
alter table public.systems add column if not exists slug text;
alter table public.system_edges add column if not exists slug text;
alter table public.armies add column if not exists slug text;
alter table public.unit_templates add column if not exists slug text;
alter table public.conflicts add column if not exists slug text;

alter table public.factions add constraint factions_slug_key unique (slug);
alter table public.systems add constraint systems_slug_key unique (slug);
alter table public.system_edges add constraint system_edges_slug_key unique (slug);
alter table public.armies add constraint armies_slug_key unique (slug);
alter table public.unit_templates add constraint unit_templates_slug_key unique (slug);
alter table public.conflicts add constraint conflicts_slug_key unique (slug);

create index if not exists systems_controller_faction_id_idx on public.systems (controller_faction_id);
create index if not exists system_edges_from_system_id_idx on public.system_edges (from_system_id);
create index if not exists system_edges_to_system_id_idx on public.system_edges (to_system_id);
create index if not exists armies_faction_id_idx on public.armies (faction_id);
create index if not exists armies_current_system_id_idx on public.armies (current_system_id);
create index if not exists army_units_army_id_idx on public.army_units (army_id);
create index if not exists recruitment_queue_faction_status_idx on public.recruitment_queue (faction_id, status);
create index if not exists recruitment_queue_finishes_at_idx on public.recruitment_queue (finishes_at);
create index if not exists movement_orders_faction_status_idx on public.movement_orders (faction_id, status);
create index if not exists movement_orders_arrival_at_idx on public.movement_orders (arrival_at);
create index if not exists conflicts_system_status_idx on public.conflicts (system_id, status);
create index if not exists battle_reports_conflict_id_idx on public.battle_reports (conflict_id);
create index if not exists campaign_logs_created_at_idx on public.campaign_logs (created_at desc);

grant usage on schema public to anon, authenticated;

grant select on
  public.factions,
  public.systems,
  public.system_edges,
  public.system_production,
  public.campaign_settings,
  public.unit_templates,
  public.conflicts,
  public.missions,
  public.system_special_objects
to anon, authenticated;

grant select on
  public.profiles,
  public.player_factions,
  public.faction_resources,
  public.armies,
  public.army_units,
  public.recruitment_queue,
  public.movement_orders,
  public.battle_reports,
  public.relics,
  public.campaign_logs
to authenticated;

grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.is_faction_member(uuid) to authenticated;

create policy profiles_select_own_or_admin
on public.profiles
for select
to authenticated
using (id = auth.uid() or public.is_admin());

create policy profiles_admin_all
on public.profiles
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy factions_select_public
on public.factions
for select
to anon, authenticated
using (true);

create policy factions_admin_all
on public.factions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy player_factions_select_own_or_admin
on public.player_factions
for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy player_factions_admin_all
on public.player_factions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy systems_select_public
on public.systems
for select
to anon, authenticated
using (true);

create policy systems_admin_all
on public.systems
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy system_edges_select_public
on public.system_edges
for select
to anon, authenticated
using (true);

create policy system_edges_admin_all
on public.system_edges
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy faction_resources_select_member_or_admin
on public.faction_resources
for select
to authenticated
using (public.is_admin() or public.is_faction_member(faction_id));

create policy faction_resources_admin_all
on public.faction_resources
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy system_production_select_public
on public.system_production
for select
to anon, authenticated
using (true);

create policy system_production_admin_all
on public.system_production
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy campaign_settings_select_public
on public.campaign_settings
for select
to anon, authenticated
using (true);

create policy campaign_settings_admin_all
on public.campaign_settings
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy armies_select_visible_member_or_admin
on public.armies
for select
to authenticated
using (public.is_admin() or public.is_faction_member(faction_id) or is_visible_publicly);

create policy armies_admin_all
on public.armies
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy army_units_select_visible_member_or_admin
on public.army_units
for select
to authenticated
using (
  exists (
    select 1
    from public.armies
    where armies.id = army_units.army_id
      and (
        public.is_admin()
        or public.is_faction_member(armies.faction_id)
        or armies.is_visible_publicly
      )
  )
);

create policy army_units_admin_all
on public.army_units
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy unit_templates_select_public
on public.unit_templates
for select
to anon, authenticated
using (true);

create policy unit_templates_admin_all
on public.unit_templates
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy recruitment_queue_select_member_or_admin
on public.recruitment_queue
for select
to authenticated
using (public.is_admin() or public.is_faction_member(faction_id));

create policy recruitment_queue_admin_all
on public.recruitment_queue
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy movement_orders_select_member_or_admin
on public.movement_orders
for select
to authenticated
using (public.is_admin() or public.is_faction_member(faction_id));

create policy movement_orders_admin_all
on public.movement_orders
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy conflicts_select_public
on public.conflicts
for select
to anon, authenticated
using (true);

create policy conflicts_admin_all
on public.conflicts
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy battle_reports_select_owner_participant_or_admin
on public.battle_reports
for select
to authenticated
using (
  public.is_admin()
  or reporter_user_id = auth.uid()
  or (reporter_faction_id is not null and public.is_faction_member(reporter_faction_id))
);

create policy battle_reports_admin_all
on public.battle_reports
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy missions_select_public
on public.missions
for select
to anon, authenticated
using (true);

create policy missions_admin_all
on public.missions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy relics_select_owner_public_or_admin
on public.relics
for select
to authenticated
using (public.is_admin() or is_public or (faction_id is not null and public.is_faction_member(faction_id)));

create policy relics_admin_all
on public.relics
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy system_special_objects_select_public
on public.system_special_objects
for select
to anon, authenticated
using (is_public);

create policy system_special_objects_admin_all
on public.system_special_objects
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy campaign_logs_select_own_or_admin
on public.campaign_logs
for select
to authenticated
using (public.is_admin() or actor_user_id = auth.uid());

create policy campaign_logs_admin_all
on public.campaign_logs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());
