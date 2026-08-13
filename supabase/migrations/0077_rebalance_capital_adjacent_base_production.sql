-- Rebalance player capital and adjacent-system natural production.

create or replace function public.base_system_capacity(
  system_slug text,
  system_kind text,
  is_capital boolean,
  resource_key text
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_slug text := coalesce(system_slug, '');
begin
  if coalesce(system_kind, 'standard') = 'gaseous' then
    return 0;
  end if;

  return case v_slug
    when 'mordax' then case resource_key when 'supply' then 8 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'drusus' then case resource_key when 'minerals' then 3 when 'uridium' then 0.3 else 0 end
    when 'sa-cea-gate' then case resource_key when 'supply' then 8 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'lyra-terminus' then case resource_key when 'minerals' then 3 when 'uridium' then 0.3 else 0 end
    when 'thokt-vault' then case resource_key when 'supply' then 8 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'novem' then case resource_key when 'minerals' then 3 when 'uridium' then 0.3 else 0 end
    when 'kharon-prime' then case resource_key when 'supply' then 8 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'helios-drift' then case resource_key when 'minerals' then 3 when 'uridium' then 0.3 else 0 end
    when 'blackglass' then case resource_key when 'supply' then 8 when 'honor' then 1 when 'industrial_material' then 5 else 0 end
    when 'red-sabbath' then case resource_key when 'minerals' then 3 when 'uridium' then 0.3 else 0 end
    when 'nexus-aster' then case resource_key when 'supply' then 10 when 'minerals' then 3 when 'industrial_material' then 5 when 'uridium' then 0.3 else 0 end
    when 'goregate' then case resource_key when 'supply' then 5 when 'minerals' then 5 when 'industrial_material' then 6 when 'uridium' then 0.3 else 0 end
    else 0
  end;
end;
$$;

select public.rebuild_system_resource_capabilities();
select public.refresh_system_production_from_buildings();
