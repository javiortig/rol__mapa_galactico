create or replace function public.apply_daemonic_legions_horror_tree_adjustment()
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
      ('daemonicas-chispas-inmaterium', 'Coros de Horrores', 'Los primeros coros de Tzeentch se dividen, chillan y se recomponen en una pantalla de magia viva. Desbloquea: Blue Horrors y Pink Horrors.', 'Hordas del Velo', 1, 1, 2, 1, 'daemon_horror', 'Desbloquea: Blue Horrors, Pink Horrors.'),
      ('daemonicas-mareas-rosadas', 'Llamas Mutables', 'Las llamas del cambio aprenden a perseguir objetivos con voluntad propia, convirtiendo trincheras y rituales enemigos en ceniza irreal. Desbloquea: Flamers.', 'Hordas del Velo', 2, 1, 1, 2, 'daemon_flame', 'Desbloquea: Flamers.'),
      ('daemonicas-llamas-imposibles', 'Incendio Exaltado', 'Una llama con nombre propio cruza el velo y convierte la artilleria menor en una presencia de mando ardiente. Desbloquea: Exalted Flamer.', 'Hordas del Velo', 2, 1, 3, 2, 'daemon_pyro', 'Desbloquea: Exalted Flamer.'),
      ('daemonicas-carros-fuego-mutante', 'Rayas del Velo', 'Bestias aullantes cruzan la batalla como meteoros de hambre y hechiceria. Desbloquea: Screamers.', 'Hordas del Velo', 3, 1, 1, 2, 'daemon_beast', 'Desbloquea: Screamers.'),
      ('daemonicas-carros-ardientes', 'Carros Ardientes', 'Plataformas de fuego cambiante cabalgan sobre la tormenta para abrir brechas en la linea real. Desbloquea: Burning Chariot.', 'Hordas del Velo', 3, 1, 3, 2, 'daemon_chariot', 'Desbloquea: Burning Chariot.'),
      ('daemonicas-forja-almas-tzeentch', 'Forja de Almas de Tzeentch', 'La disformidad encadena maquinas infernales y las empuja al frente como artilleria blasfema. Desbloquea: Tzeentch Soul Grinder.', 'Hordas del Velo', 4, 1, 2, 3, 'daemon_soul_grinder', 'Desbloquea: Tzeentch Soul Grinder.'),
      ('daemonicas-voces-velo', 'Voces del Velo', 'Los heraldos sin nombre traducen augurios imposibles en ordenes que incluso los mortales pueden temer. Desbloquea: Daemonic Herald [Crucible].', 'Corte del Cambiante', 1, 2, 2, 1, 'daemon_herald', 'Desbloquea: Daemonic Herald [Crucible].'),
      ('daemonicas-piras-cambio', 'Conjuradores del Cambio', 'Los horrores reciben maestros de hechiceria menor capaces de doblar la marea y convertir caos bruto en plan. Desbloquea: Changecaster.', 'Corte del Cambiante', 2, 2, 1, 2, 'daemon_herald', 'Desbloquea: Changecaster.'),
      ('daemonicas-discos-sortilegio', 'Discos de Sortilegio', 'Augures montados y senores de disco sobrevuelan el frente para torcer rutas, destinos y cargas enemigas. Desbloquea: Fluxmaster y Fateskimmer.', 'Corte del Cambiante', 2, 2, 3, 2, 'daemon_disc', 'Desbloquea: Fluxmaster, Fateskimmer.'),
      ('daemonicas-escribas-destino', 'Escribas del Destino', 'Los nombres verdaderos, rutas de invasion y fracasos inevitables quedan inscritos antes de que ocurran. Desbloquea: The Blue Scribes.', 'Corte del Cambiante', 3, 2, 1, 2, 'daemon_scribes', 'Desbloquea: The Blue Scribes.'),
      ('daemonicas-mascaras-engano', 'Mascaras del Engano', 'La corte aprende a ganar guerras con apariciones, aurigas imposibles y senuelos que rompen toda certeza. Desbloquea: The Changeling y Daemonic Charioteer [Crucible].', 'Corte del Cambiante', 4, 2, 2, 3, 'daemon_changeling', 'Desbloquea: The Changeling, Daemonic Charioteer [Crucible].'),
      ('daemonicas-ascension-demonica', 'Ascension Demonica', 'La carne mortal deja de importar cuando la voluntad de la disformidad moldea principes capaces de mandar legiones. Desbloquea: Daemon Prince of Chaos y Daemon Prince of Chaos with wings.', 'Tronos de la Disformidad', 1, 3, 2, 2, 'daemon_prince', 'Desbloquea: Daemon Prince of Chaos, Daemon Prince of Chaos with wings.'),
      ('daemonicas-senor-cambio', 'Senor del Cambio', 'Un Gran Demonio de Tzeentch atraviesa el velo y convierte el frente en un tablero de paradojas. Desbloquea: Lord of Change.', 'Tronos de la Disformidad', 3, 3, 2, 2, 'daemon_lord_change', 'Desbloquea: Lord of Change.'),
      ('daemonicas-kairos-teje-destinos', 'Kairos Teje-Destinos', 'La campana queda atrapada entre futuros contradictorios cuando Kairos abre ambos ojos al sector. Desbloquea: Kairos Fateweaver.', 'Tronos de la Disformidad', 4, 3, 2, 2, 'daemon_kairos', 'Desbloquea: Kairos Fateweaver.'),
      ('daemonicas-primer-principe', 'El Primer Principe', 'Las sendas rivales de la disformidad se inclinan ante una sombra que no pertenece a ningun dios por completo. Desbloquea: Be''lakor.', 'Tronos de la Disformidad', 5, 3, 2, 2, 'daemon_belakor', 'Desbloquea: Be''lakor.')
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
      ('daemonicas-mareas-rosadas', 'daemonicas-chispas-inmaterium', 1),
      ('daemonicas-llamas-imposibles', 'daemonicas-mareas-rosadas', 1),
      ('daemonicas-llamas-imposibles', 'daemonicas-voces-velo', 2),
      ('daemonicas-carros-fuego-mutante', 'daemonicas-chispas-inmaterium', 1),
      ('daemonicas-carros-fuego-mutante', 'criadero-guerra', 2),
      ('daemonicas-carros-ardientes', 'daemonicas-mareas-rosadas', 1),
      ('daemonicas-carros-ardientes', 'daemonicas-carros-fuego-mutante', 2),
      ('daemonicas-forja-almas-tzeentch', 'daemonicas-carros-ardientes', 1),
      ('daemonicas-forja-almas-tzeentch', 'maquinaria-belica', 2),
      ('daemonicas-voces-velo', 'asamblea-planetaria', 1),
      ('daemonicas-piras-cambio', 'daemonicas-voces-velo', 1),
      ('daemonicas-piras-cambio', 'daemonicas-chispas-inmaterium', 2),
      ('daemonicas-discos-sortilegio', 'daemonicas-voces-velo', 1),
      ('daemonicas-discos-sortilegio', 'daemonicas-carros-fuego-mutante', 2),
      ('daemonicas-escribas-destino', 'daemonicas-piras-cambio', 1),
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

  delete from public.technology_effects effects
  using public.technology_nodes nodes
  where effects.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-legiones-daemonicas-v1'
    and effects.effect_type = 'unlock_unit_template';

  insert into public.technology_effects (id, technology_node_id, effect_type, payload)
  select
    public.seed_uuid('technology_effect', data.technology_slug || '-units'),
    technology_nodes.id,
    'unlock_unit_template',
    jsonb_build_object('unit_template_slugs', data.unit_template_slugs)
  from (
    values
      ('daemonicas-chispas-inmaterium', array['unit-legiones-daemonicas-blue-horrors','unit-legiones-daemonicas-pink-horrors']::text[]),
      ('daemonicas-mareas-rosadas', array['unit-legiones-daemonicas-flamers']::text[]),
      ('daemonicas-llamas-imposibles', array['unit-legiones-daemonicas-exalted-flamer']::text[]),
      ('daemonicas-carros-fuego-mutante', array['unit-legiones-daemonicas-screamers']::text[]),
      ('daemonicas-carros-ardientes', array['unit-legiones-daemonicas-burning-chariot']::text[]),
      ('daemonicas-forja-almas-tzeentch', array['unit-legiones-daemonicas-tzeentch-soul-grinder']::text[]),
      ('daemonicas-voces-velo', array['unit-legiones-daemonicas-daemonic-herald-crucible']::text[]),
      ('daemonicas-piras-cambio', array['unit-legiones-daemonicas-changecaster']::text[]),
      ('daemonicas-discos-sortilegio', array['unit-legiones-daemonicas-fluxmaster','unit-legiones-daemonicas-fateskimmer']::text[]),
      ('daemonicas-escribas-destino', array['unit-legiones-daemonicas-the-blue-scribes']::text[]),
      ('daemonicas-mascaras-engano', array['unit-legiones-daemonicas-the-changeling','unit-legiones-daemonicas-daemonic-charioteer-crucible']::text[]),
      ('daemonicas-ascension-demonica', array['unit-legiones-daemonicas-daemon-prince-of-chaos','unit-legiones-daemonicas-daemon-prince-of-chaos-with-wings']::text[]),
      ('daemonicas-senor-cambio', array['unit-legiones-daemonicas-lord-of-change']::text[]),
      ('daemonicas-kairos-teje-destinos', array['unit-legiones-daemonicas-kairos-fateweaver']::text[]),
      ('daemonicas-primer-principe', array['unit-legiones-daemonicas-belakor']::text[])
  ) as data(technology_slug, unit_template_slugs)
  join public.technology_nodes on technology_nodes.slug = data.technology_slug
  on conflict (id) do update
  set technology_node_id = excluded.technology_node_id,
      effect_type = excluded.effect_type,
      payload = excluded.payload;

  select id into v_daemon_faction_id
  from public.factions
  where slug = 'legiones-daemonicas';

  if v_daemon_faction_id is not null then
    update public.unit_templates
    set is_available = false,
        required_technology_node_id = null
    where faction_id = v_daemon_faction_id;

    update public.unit_templates templates
    set is_available = true,
        required_technology_node_id = technology_nodes.id
    from (
      values
        ('unit-legiones-daemonicas-blue-horrors', 'daemonicas-chispas-inmaterium'),
        ('unit-legiones-daemonicas-pink-horrors', 'daemonicas-chispas-inmaterium'),
        ('unit-legiones-daemonicas-flamers', 'daemonicas-mareas-rosadas'),
        ('unit-legiones-daemonicas-exalted-flamer', 'daemonicas-llamas-imposibles'),
        ('unit-legiones-daemonicas-screamers', 'daemonicas-carros-fuego-mutante'),
        ('unit-legiones-daemonicas-burning-chariot', 'daemonicas-carros-ardientes'),
        ('unit-legiones-daemonicas-tzeentch-soul-grinder', 'daemonicas-forja-almas-tzeentch'),
        ('unit-legiones-daemonicas-daemonic-herald-crucible', 'daemonicas-voces-velo'),
        ('unit-legiones-daemonicas-changecaster', 'daemonicas-piras-cambio'),
        ('unit-legiones-daemonicas-fluxmaster', 'daemonicas-discos-sortilegio'),
        ('unit-legiones-daemonicas-fateskimmer', 'daemonicas-discos-sortilegio'),
        ('unit-legiones-daemonicas-the-blue-scribes', 'daemonicas-escribas-destino'),
        ('unit-legiones-daemonicas-the-changeling', 'daemonicas-mascaras-engano'),
        ('unit-legiones-daemonicas-daemonic-charioteer-crucible', 'daemonicas-mascaras-engano'),
        ('unit-legiones-daemonicas-daemon-prince-of-chaos', 'daemonicas-ascension-demonica'),
        ('unit-legiones-daemonicas-daemon-prince-of-chaos-with-wings', 'daemonicas-ascension-demonica'),
        ('unit-legiones-daemonicas-lord-of-change', 'daemonicas-senor-cambio'),
        ('unit-legiones-daemonicas-kairos-fateweaver', 'daemonicas-kairos-teje-destinos'),
        ('unit-legiones-daemonicas-belakor', 'daemonicas-primer-principe')
    ) as assignments(unit_slug, technology_slug)
    join public.technology_nodes on technology_nodes.slug = assignments.technology_slug
    where templates.slug = assignments.unit_slug
      and templates.faction_id = v_daemon_faction_id;

    perform public.refresh_available_technologies(v_daemon_faction_id);
  end if;
end;
$$;

revoke execute on function public.apply_daemonic_legions_horror_tree_adjustment() from public;
revoke execute on function public.apply_daemonic_legions_horror_tree_adjustment() from anon;
revoke execute on function public.apply_daemonic_legions_horror_tree_adjustment() from authenticated;

select public.apply_daemonic_legions_horror_tree_adjustment();
