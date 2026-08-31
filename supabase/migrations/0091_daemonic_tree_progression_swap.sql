create or replace function public.apply_daemonic_tree_progression_swap()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_daemon_faction_id uuid;
begin
  update public.technology_nodes nodes
  set name = data.name,
      description = data.description,
      branch = data.branch,
      tier = data.tier,
      position_x = data.position_x,
      position_y = data.position_y,
      cost_technology = data.cost_technology,
      research_time_seconds = 30,
      icon_key = data.icon_key,
      effect_summary = data.effect_summary,
      implementation_status = 'active',
      updated_at = now()
  from (
    values
      ('daemonicas-chispas-inmaterium', 'Coros de Horrores', 'Los primeros coros de Tzeentch se dividen, chillan y se recomponen en una pantalla de magia viva. Desbloquea: Blue Horrors y Pink Horrors.', 'Hordas del Velo', 1, 1, 2, 2, 'daemon_horror', 'Desbloquea: Blue Horrors, Pink Horrors.'),
      ('daemonicas-carros-fuego-mutante', 'Rayas del Velo', 'Bestias aullantes cruzan la batalla como meteoros de hambre y hechiceria. Desbloquea: Screamers.', 'Hordas del Velo', 2, 1, 1, 2, 'daemon_beast', 'Desbloquea: Screamers.'),
      ('daemonicas-mareas-rosadas', 'Llamas Mutables', 'Las llamas del cambio aprenden a perseguir objetivos con voluntad propia, convirtiendo trincheras y rituales enemigos en ceniza irreal. Desbloquea: Flamers.', 'Hordas del Velo', 3, 1, 1, 2, 'daemon_flame', 'Desbloquea: Flamers.'),
      ('daemonicas-llamas-imposibles', 'Incendio Exaltado', 'Una llama con nombre propio cruza el velo y convierte la artilleria menor en una presencia de mando ardiente. Desbloquea: Exalted Flamer.', 'Hordas del Velo', 3, 1, 3, 2, 'daemon_pyro', 'Desbloquea: Exalted Flamer.'),
      ('daemonicas-carros-ardientes', 'Carros Ardientes', 'Plataformas de fuego cambiante cabalgan sobre la tormenta para abrir brechas en la linea real. Desbloquea: Burning Chariot.', 'Hordas del Velo', 4, 1, 3, 2, 'daemon_chariot', 'Desbloquea: Burning Chariot.'),
      ('daemonicas-forja-almas-tzeentch', 'Forja de Almas de Tzeentch', 'La disformidad encadena maquinas infernales y las empuja al frente como artilleria blasfema. Desbloquea: Tzeentch Soul Grinder.', 'Hordas del Velo', 5, 1, 2, 3, 'daemon_soul_grinder', 'Desbloquea: Tzeentch Soul Grinder.'),
      ('daemonicas-piras-cambio', 'Conjuradores del Cambio', 'Los horrores reciben maestros de hechiceria menor capaces de doblar la marea y convertir caos bruto en plan. Desbloquea: Changecaster.', 'Corte del Cambiante', 1, 2, 2, 1, 'daemon_herald', 'Desbloquea: Changecaster.'),
      ('daemonicas-voces-velo', 'Voces del Velo', 'Los heraldos sin nombre traducen augurios imposibles en ordenes que incluso los mortales pueden temer. Desbloquea: Daemonic Herald [Crucible].', 'Corte del Cambiante', 2, 2, 1, 1, 'daemon_herald', 'Desbloquea: Daemonic Herald [Crucible].'),
      ('daemonicas-discos-sortilegio', 'Discos de Sortilegio', 'Augures montados y senores de disco sobrevuelan el frente para torcer rutas, destinos y cargas enemigas. Desbloquea: Fluxmaster y Fateskimmer.', 'Corte del Cambiante', 2, 2, 3, 2, 'daemon_disc', 'Desbloquea: Fluxmaster, Fateskimmer.'),
      ('daemonicas-escribas-destino', 'Escribas del Destino', 'Los nombres verdaderos, rutas de invasion y fracasos inevitables quedan inscritos antes de que ocurran. Desbloquea: The Blue Scribes.', 'Corte del Cambiante', 3, 2, 1, 2, 'daemon_scribes', 'Desbloquea: The Blue Scribes.'),
      ('daemonicas-mascaras-engano', 'Mascaras del Engano', 'La corte aprende a ganar guerras con apariciones, aurigas imposibles y senuelos que rompen toda certeza. Desbloquea: The Changeling y Daemonic Charioteer [Crucible].', 'Corte del Cambiante', 4, 2, 2, 3, 'daemon_changeling', 'Desbloquea: The Changeling, Daemonic Charioteer [Crucible].')
  ) as data(slug, name, description, branch, tier, position_x, position_y, cost_technology, icon_key, effect_summary)
  where nodes.tree_key = 'troops-legiones-daemonicas-v1'
    and nodes.slug = data.slug;

  delete from public.technology_prerequisites prerequisites
  using public.technology_nodes nodes
  where prerequisites.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-legiones-daemonicas-v1';

  insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
  select tech.id, required.id, data.prerequisite_group
  from (
    values
      ('daemonicas-chispas-inmaterium', 'fundacion-planetaria', 1),
      ('daemonicas-carros-fuego-mutante', 'daemonicas-chispas-inmaterium', 1),
      ('daemonicas-carros-fuego-mutante', 'criadero-guerra', 2),
      ('daemonicas-mareas-rosadas', 'daemonicas-carros-fuego-mutante', 1),
      ('daemonicas-mareas-rosadas', 'daemonicas-piras-cambio', 2),
      ('daemonicas-llamas-imposibles', 'daemonicas-mareas-rosadas', 1),
      ('daemonicas-llamas-imposibles', 'daemonicas-piras-cambio', 2),
      ('daemonicas-carros-ardientes', 'daemonicas-mareas-rosadas', 1),
      ('daemonicas-carros-ardientes', 'daemonicas-carros-fuego-mutante', 2),
      ('daemonicas-forja-almas-tzeentch', 'daemonicas-carros-ardientes', 1),
      ('daemonicas-forja-almas-tzeentch', 'maquinaria-belica', 2),
      ('daemonicas-piras-cambio', 'asamblea-planetaria', 1),
      ('daemonicas-piras-cambio', 'daemonicas-chispas-inmaterium', 2),
      ('daemonicas-voces-velo', 'daemonicas-piras-cambio', 1),
      ('daemonicas-discos-sortilegio', 'daemonicas-piras-cambio', 1),
      ('daemonicas-discos-sortilegio', 'daemonicas-carros-fuego-mutante', 2),
      ('daemonicas-escribas-destino', 'daemonicas-voces-velo', 1),
      ('daemonicas-mascaras-engano', 'daemonicas-escribas-destino', 1),
      ('daemonicas-mascaras-engano', 'daemonicas-discos-sortilegio', 2),
      ('daemonicas-ascension-demonica', 'asamblea-planetaria', 1),
      ('daemonicas-ascension-demonica', 'criadero-guerra', 2),
      ('daemonicas-senor-cambio', 'daemonicas-ascension-demonica', 1),
      ('daemonicas-senor-cambio', 'daemonicas-piras-cambio', 2),
      ('daemonicas-kairos-teje-destinos', 'daemonicas-senor-cambio', 1),
      ('daemonicas-kairos-teje-destinos', 'daemonicas-escribas-destino', 2),
      ('daemonicas-primer-principe', 'daemonicas-kairos-teje-destinos', 1),
      ('daemonicas-primer-principe', 'daemonicas-ascension-demonica', 2),
      ('daemonicas-primer-principe', 'daemonicas-forja-almas-tzeentch', 3)
  ) as data(technology_slug, required_slug, prerequisite_group)
  join public.technology_nodes tech on tech.slug = data.technology_slug
  join public.technology_nodes required on required.slug = data.required_slug
  on conflict (technology_node_id, required_node_id) do update
  set prerequisite_group = excluded.prerequisite_group;

  select id into v_daemon_faction_id
  from public.factions
  where slug = 'legiones-daemonicas';

  if v_daemon_faction_id is not null then
    insert into public.faction_technologies (faction_id, technology_node_id, status, unlocked_at)
    select v_daemon_faction_id, nodes.id, 'unlocked', now()
    from public.technology_nodes nodes
    where nodes.slug in ('criadero-guerra', 'daemonicas-carros-fuego-mutante')
    on conflict (faction_id, technology_node_id) do update
    set status = excluded.status,
        unlocked_at = excluded.unlocked_at,
        started_at = null,
        finishes_at = null,
        updated_at = now();

    insert into public.faction_technologies (faction_id, technology_node_id, status)
    select v_daemon_faction_id, nodes.id, 'available'
    from public.technology_nodes nodes
    where nodes.slug = 'maquinaria-belica'
    on conflict (faction_id, technology_node_id) do update
    set status = excluded.status,
        unlocked_at = null,
        started_at = null,
        finishes_at = null,
        updated_at = now();

    delete from public.faction_technologies progress
    using public.technology_nodes nodes
    where progress.faction_id = v_daemon_faction_id
      and progress.technology_node_id = nodes.id
      and nodes.slug = 'daemonicas-mareas-rosadas';

    perform public.refresh_available_technologies(v_daemon_faction_id);
  end if;

  insert into public.campaign_logs (action_type, payload)
  values (
    'daemonic_tree_progression_swapped',
    jsonb_build_object(
      'faction_slug', 'legiones-daemonicas',
      'unlocked', jsonb_build_array('criadero-guerra', 'daemonicas-carros-fuego-mutante'),
      'locked_again', jsonb_build_array('maquinaria-belica', 'daemonicas-mareas-rosadas'),
      'cost_changes', jsonb_build_object('daemonicas-voces-velo', 1, 'daemonicas-piras-cambio', 1)
    )
  );
end;
$$;

revoke execute on function public.apply_daemonic_tree_progression_swap() from public;
revoke execute on function public.apply_daemonic_tree_progression_swap() from anon;
revoke execute on function public.apply_daemonic_tree_progression_swap() from authenticated;

select public.apply_daemonic_tree_progression_swap();
