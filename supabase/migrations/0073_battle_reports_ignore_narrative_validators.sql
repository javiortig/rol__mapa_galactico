create or replace function public.get_battle_report_required_faction_ids(target_conflict_id uuid)
returns table (faction_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select distinct participants.participant_id as faction_id
  from (
    select conflicts.attacker_faction_id as participant_id
    from public.conflicts
    where conflicts.id = target_conflict_id

    union all

    select conflicts.defender_faction_id as participant_id
    from public.conflicts
    where conflicts.id = target_conflict_id

    union all

    select campaign_units.faction_id as participant_id
    from public.conflicts
    join public.campaign_units
      on campaign_units.current_system_id = conflicts.system_id
      and campaign_units.status = 'in_war'
      and campaign_units.quantity > 0
    where conflicts.id = target_conflict_id

    union all

    select battle_unit_commitments.faction_id as participant_id
    from public.conflicts
    join public.battle_unit_commitments
      on battle_unit_commitments.operation_id = conflicts.battle_operation_id
      and battle_unit_commitments.status not in ('returned', 'destroyed', 'cancelled')
    where conflicts.id = target_conflict_id
  ) participants
  join public.factions
    on factions.id = participants.participant_id
  where participants.participant_id is not null
    and coalesce(factions.is_narrative, false) = false;
$$;

revoke execute on function public.get_battle_report_required_faction_ids(uuid) from public;
grant execute on function public.get_battle_report_required_faction_ids(uuid) to authenticated;
