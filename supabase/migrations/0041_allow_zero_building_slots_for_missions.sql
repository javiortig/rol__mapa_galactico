alter table public.systems
  drop constraint if exists systems_building_slots_check;

alter table public.systems
  add constraint systems_building_slots_check
  check (building_slots >= 0);
