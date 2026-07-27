alter table public.factions
  add column if not exists is_narrative boolean not null default false;

with final_factions(slug, name, color, is_narrative) as (
  values
    ('legiones-daemonicas', 'Legiones Daemonicas', '#ef4444', false),
    ('cultos-genestealer', 'Cultos Genestealer', '#ec4899', false),
    ('space-marines', 'Space Marines', '#3b82f6', false),
    ('adeptus-custodes', 'Adeptus Custodes', '#d4af37', false),
    ('necrones', 'Necrones', '#2dd4bf', false),
    ('orcos', 'Orcos', '#84cc16', true),
    ('tiranidos', 'Tiranidos', '#8b5cf6', true)
)
insert into public.factions (slug, name, color, capital_system_id, is_narrative)
select slug, name, color, null, is_narrative
from final_factions
where is_narrative
on conflict (slug) do update
set
  name = excluded.name,
  color = excluded.color,
  capital_system_id = null,
  is_narrative = true;

with final_factions(slug, name, color, is_narrative) as (
  values
    ('legiones-daemonicas', 'Legiones Daemonicas', '#ef4444', false),
    ('cultos-genestealer', 'Cultos Genestealer', '#ec4899', false),
    ('space-marines', 'Space Marines', '#3b82f6', false),
    ('adeptus-custodes', 'Adeptus Custodes', '#d4af37', false),
    ('necrones', 'Necrones', '#2dd4bf', false),
    ('orcos', 'Orcos', '#84cc16', true),
    ('tiranidos', 'Tiranidos', '#8b5cf6', true)
)
update public.factions
set
  name = final_factions.name,
  color = final_factions.color,
  is_narrative = final_factions.is_narrative,
  capital_system_id = case
    when final_factions.is_narrative then null
    else public.factions.capital_system_id
  end
from final_factions
where public.factions.slug = final_factions.slug;

do $$
declare
  v_retired_faction_ids uuid[];
begin
  select array_agg(id)
  into v_retired_faction_ids
  from public.factions
  where slug in ('aeldari', 'agentes-imperium');

  if v_retired_faction_ids is null then
    return;
  end if;

  update public.systems
  set
    status = 'neutral',
    controller_faction_id = null,
    is_capital = false,
    blocked_until = null,
    updated_at = now()
  where controller_faction_id = any(v_retired_faction_ids)
     or slug in ('cinder-maw', 'eclipse-forge', 'rustmaw-run', 'argent-rift', 'orison', 'vesper-halo');

  update public.systems
  set
    type = 'Forja volcanica neutral',
    public_description = 'Forjas geotermicas sin dueno estable, acechadas por chatarra orka y tormentas de ceniza.'
  where slug = 'cinder-maw';

  update public.systems
  set
    public_description = 'Estructuras de manufactura latentes, hoy convertidas en un corredor neutral de alto valor.'
  where slug = 'eclipse-forge';

  update public.systems
  set
    public_description = 'Ruta de pecios saqueados que apunta hacia el centro sin dominio estable.'
  where slug = 'rustmaw-run';

  update public.systems
  set
    public_description = 'Corredor azul con pozos de gravedad inestables. Una horda orka amenaza las rutas de avance custodes.'
  where slug = 'azur-trench';

  update public.systems
  set public_description = 'Santuario velado donde los Space Marines combaten una revuelta genestelar.'
  where slug = 'saint-veil';

  delete from public.system_buildings
  where system_id in (
    select id
    from public.systems
    where slug in ('cinder-maw', 'eclipse-forge', 'rustmaw-run', 'argent-rift', 'orison', 'vesper-halo')
  );

  update public.conflicts
  set
    attacker_faction_id = (select id from public.factions where slug = 'orcos'),
    defender_faction_id = (select id from public.factions where slug = 'adeptus-custodes'),
    winner_faction_id = null,
    notes = 'Una horda orka amenaza el corredor de la Zanja Azul frente a las lineas de Kharon. Pendiente de batalla fisica.',
    blocked_until = coalesce(blocked_until, now() + interval '14 days')
  where slug = 'conflict-azur-trench';

  delete from public.movement_order_units
  where movement_order_id in (
    select id
    from public.movement_orders
    where faction_id = any(v_retired_faction_ids)
       or defender_faction_id = any(v_retired_faction_ids)
  );

  delete from public.movement_orders
  where faction_id = any(v_retired_faction_ids)
     or defender_faction_id = any(v_retired_faction_ids);

  delete from public.battle_unit_commitments
  where faction_id = any(v_retired_faction_ids);

  delete from public.battle_operation_members
  where faction_id = any(v_retired_faction_ids)
     or invited_by_faction_id = any(v_retired_faction_ids);

  delete from public.battle_operations
  where leader_faction_id = any(v_retired_faction_ids)
     or defender_faction_id = any(v_retired_faction_ids);

  update public.battle_reports
  set reporter_faction_id = null
  where reporter_faction_id = any(v_retired_faction_ids);

  update public.battle_reports
  set winner_faction_id = null
  where winner_faction_id = any(v_retired_faction_ids);

  update public.battle_reports
  set final_controller_faction_id = null
  where final_controller_faction_id = any(v_retired_faction_ids);

  update public.campaign_logs
  set faction_id = null
  where faction_id = any(v_retired_faction_ids);

  update public.trade_offers
  set accepted_by_faction_id = null
  where accepted_by_faction_id = any(v_retired_faction_ids);

  delete from public.trade_offers
  where creator_faction_id = any(v_retired_faction_ids);

  delete from public.conflicts
  where attacker_faction_id = any(v_retired_faction_ids)
     or defender_faction_id = any(v_retired_faction_ids)
     or winner_faction_id = any(v_retired_faction_ids);

  delete from public.relics
  where faction_id = any(v_retired_faction_ids);

  delete from public.campaign_units
  where faction_id = any(v_retired_faction_ids);

  delete from public.unit_templates
  where faction_id = any(v_retired_faction_ids);

  delete from public.player_factions
  where faction_id = any(v_retired_faction_ids);

  delete from public.faction_resources
  where faction_id = any(v_retired_faction_ids);

  delete from public.faction_technologies
  where faction_id = any(v_retired_faction_ids);

  delete from public.factions
  where id = any(v_retired_faction_ids);
end $$;
