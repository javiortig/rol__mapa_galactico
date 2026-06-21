alter table public.unit_templates
  add column if not exists source_section text,
  add column if not exists source_faction_name text,
  add column if not exists is_allied_unit boolean not null default false;

create index if not exists unit_templates_source_faction_idx on public.unit_templates (source_faction_name);
create index if not exists unit_templates_is_allied_unit_idx on public.unit_templates (is_allied_unit);
