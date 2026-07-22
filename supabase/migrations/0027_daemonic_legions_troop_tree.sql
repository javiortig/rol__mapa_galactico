create or replace function public.seed_daemonic_legions_troop_technology_tree()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_daemon_faction_id uuid;
begin
  insert into public.technology_nodes (
    id, slug, tree_key, name, description, branch, tier, position_x, position_y,
    cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
  )
  values
    (public.seed_uuid('technology_node', 'daemonicas-chispas-inmaterium'), 'daemonicas-chispas-inmaterium', 'troops-legiones-daemonicas-v1', 'Chispas del Inmaterium', 'Los horrores menores brotan como fragmentos chillones de magia pura y saturan los primeros frentes. Desbloquea: Blue Horrors.', 'Hordas del Velo', 1, 1, 2, 1, 30, 'daemon_horror', 'Desbloquea: Blue Horrors.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-mareas-rosadas'), 'daemonicas-mareas-rosadas', 'troops-legiones-daemonicas-v1', 'Mareas Rosadas', 'La marea inicial se condensa en coros de horrores mayores, utiles para fijar objetivos y desgastar lineas. Desbloquea: Pink Horrors.', 'Hordas del Velo', 2, 1, 1, 1, 30, 'daemon_horror', 'Desbloquea: Pink Horrors.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-llamas-imposibles'), 'daemonicas-llamas-imposibles', 'troops-legiones-daemonicas-v1', 'Llamas Imposibles', 'Las piras cambiantes se desatan como proyectiles vivos capaces de limpiar trincheras y rituales enemigos. Desbloquea: Flamers.', 'Hordas del Velo', 2, 1, 3, 1, 30, 'daemon_flame', 'Desbloquea: Flamers.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-carros-fuego-mutante'), 'daemonicas-carros-fuego-mutante', 'troops-legiones-daemonicas-v1', 'Rayas del Velo', 'Bestias aullantes cruzan la batalla como meteoros de hambre y hechiceria. Desbloquea: Screamers.', 'Hordas del Velo', 3, 1, 1, 2, 30, 'daemon_beast', 'Desbloquea: Screamers.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-carros-ardientes'), 'daemonicas-carros-ardientes', 'troops-legiones-daemonicas-v1', 'Carros Ardientes', 'Plataformas de fuego cambiante cabalgan sobre la tormenta para abrir brechas en la linea real. Desbloquea: Burning Chariot.', 'Hordas del Velo', 3, 1, 3, 2, 30, 'daemon_chariot', 'Desbloquea: Burning Chariot.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-forja-almas-tzeentch'), 'daemonicas-forja-almas-tzeentch', 'troops-legiones-daemonicas-v1', 'Forja de Almas de Tzeentch', 'La disformidad encadena maquinas infernales y las empuja al frente como artilleria blasfema. Desbloquea: Tzeentch Soul Grinder.', 'Hordas del Velo', 4, 1, 2, 3, 30, 'daemon_soul_grinder', 'Desbloquea: Tzeentch Soul Grinder.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-voces-velo'), 'daemonicas-voces-velo', 'troops-legiones-daemonicas-v1', 'Voces del Velo', 'Los primeros heraldos traducen augurios imposibles en ordenes que incluso los mortales pueden temer. Desbloquea: Changecaster y Daemonic Herald [Crucible].', 'Corte del Cambiante', 1, 2, 2, 1, 30, 'daemon_herald', 'Desbloquea: Changecaster, Daemonic Herald [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-piras-cambio'), 'daemonicas-piras-cambio', 'troops-legiones-daemonicas-v1', 'Piras del Cambio', 'La corte invoca campeones ardientes capaces de convertir hechizos menores en salvas abrasadoras. Desbloquea: Exalted Flamer.', 'Corte del Cambiante', 2, 2, 1, 1, 30, 'daemon_pyro', 'Desbloquea: Exalted Flamer.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-discos-sortilegio'), 'daemonicas-discos-sortilegio', 'troops-legiones-daemonicas-v1', 'Discos de Sortilegio', 'Augures montados y senores de disco sobrevuelan el frente para torcer rutas, destinos y cargas enemigas. Desbloquea: Fluxmaster y Fateskimmer.', 'Corte del Cambiante', 2, 2, 3, 1, 30, 'daemon_disc', 'Desbloquea: Fluxmaster, Fateskimmer.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-escribas-destino'), 'daemonicas-escribas-destino', 'troops-legiones-daemonicas-v1', 'Escribas del Destino', 'Los nombres verdaderos, rutas de invasion y fracasos inevitables quedan inscritos antes de que ocurran. Desbloquea: The Blue Scribes.', 'Corte del Cambiante', 3, 2, 1, 2, 30, 'daemon_scribes', 'Desbloquea: The Blue Scribes.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-mascaras-engano'), 'daemonicas-mascaras-engano', 'troops-legiones-daemonicas-v1', 'Mascaras del Engano', 'La corte aprende a ganar guerras con apariciones, aurigas imposibles y senuelos que rompen toda certeza. Desbloquea: The Changeling y Daemonic Charioteer [Crucible].', 'Corte del Cambiante', 4, 2, 2, 2, 30, 'daemon_changeling', 'Desbloquea: The Changeling, Daemonic Charioteer [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-ascension-demonica'), 'daemonicas-ascension-demonica', 'troops-legiones-daemonicas-v1', 'Ascension Demonica', 'La carne mortal deja de importar cuando la voluntad de la disformidad moldea principes capaces de mandar legiones. Desbloquea: Daemon Prince of Chaos y Daemon Prince of Chaos with wings.', 'Tronos de la Disformidad', 1, 3, 2, 1, 30, 'daemon_prince', 'Desbloquea: Daemon Prince of Chaos, Daemon Prince of Chaos with wings.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-senor-cambio'), 'daemonicas-senor-cambio', 'troops-legiones-daemonicas-v1', 'Senor del Cambio', 'Un Gran Demonio de Tzeentch atraviesa el velo y convierte el frente en un tablero de paradojas. Desbloquea: Lord of Change.', 'Tronos de la Disformidad', 3, 3, 2, 3, 30, 'daemon_lord_change', 'Desbloquea: Lord of Change.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-kairos-teje-destinos'), 'daemonicas-kairos-teje-destinos', 'troops-legiones-daemonicas-v1', 'Kairos Teje-Destinos', 'La campana queda atrapada entre futuros contradictorios cuando Kairos abre ambos ojos al sector. Desbloquea: Kairos Fateweaver.', 'Tronos de la Disformidad', 4, 3, 2, 3, 30, 'daemon_kairos', 'Desbloquea: Kairos Fateweaver.', false, 'active'),
    (public.seed_uuid('technology_node', 'daemonicas-primer-principe'), 'daemonicas-primer-principe', 'troops-legiones-daemonicas-v1', 'El Primer Principe', 'Las sendas rivales de la disformidad se inclinan ante una sombra que no pertenece a ningun dios por completo. Desbloquea: Be''lakor.', 'Tronos de la Disformidad', 5, 3, 2, 4, 30, 'daemon_belakor', 'Desbloquea: Be''lakor.', false, 'active')
  on conflict (slug) do update
  set tree_key = excluded.tree_key,
      name = excluded.name,
      description = excluded.description,
      branch = excluded.branch,
      tier = excluded.tier,
      position_x = excluded.position_x,
      position_y = excluded.position_y,
      cost_technology = excluded.cost_technology,
      research_time_seconds = excluded.research_time_seconds,
      icon_key = excluded.icon_key,
      effect_summary = excluded.effect_summary,
      is_starter = excluded.is_starter,
      implementation_status = excluded.implementation_status,
      updated_at = now();

  delete from public.technology_nodes
  where tree_key = 'troops-legiones-daemonicas-v1'
    and slug not in (
      'daemonicas-chispas-inmaterium',
      'daemonicas-mareas-rosadas',
      'daemonicas-llamas-imposibles',
      'daemonicas-carros-fuego-mutante',
      'daemonicas-carros-ardientes',
      'daemonicas-forja-almas-tzeentch',
      'daemonicas-voces-velo',
      'daemonicas-piras-cambio',
      'daemonicas-discos-sortilegio',
      'daemonicas-escribas-destino',
      'daemonicas-mascaras-engano',
      'daemonicas-ascension-demonica',
      'daemonicas-senor-cambio',
      'daemonicas-kairos-teje-destinos',
      'daemonicas-primer-principe'
    );

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
      ('daemonicas-llamas-imposibles', 'daemonicas-chispas-inmaterium', 1),
      ('daemonicas-carros-fuego-mutante', 'daemonicas-mareas-rosadas', 1),
      ('daemonicas-carros-fuego-mutante', 'criadero-guerra', 2),
      ('daemonicas-carros-ardientes', 'daemonicas-llamas-imposibles', 1),
      ('daemonicas-carros-ardientes', 'daemonicas-carros-fuego-mutante', 2),
      ('daemonicas-forja-almas-tzeentch', 'daemonicas-carros-ardientes', 1),
      ('daemonicas-forja-almas-tzeentch', 'maquinaria-belica', 2),
      ('daemonicas-voces-velo', 'asamblea-planetaria', 1),
      ('daemonicas-piras-cambio', 'daemonicas-voces-velo', 1),
      ('daemonicas-piras-cambio', 'daemonicas-llamas-imposibles', 2),
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
      ('daemonicas-chispas-inmaterium', array['unit-legiones-daemonicas-blue-horrors']::text[]),
      ('daemonicas-mareas-rosadas', array['unit-legiones-daemonicas-pink-horrors']::text[]),
      ('daemonicas-llamas-imposibles', array['unit-legiones-daemonicas-flamers']::text[]),
      ('daemonicas-carros-fuego-mutante', array['unit-legiones-daemonicas-screamers']::text[]),
      ('daemonicas-carros-ardientes', array['unit-legiones-daemonicas-burning-chariot']::text[]),
      ('daemonicas-forja-almas-tzeentch', array['unit-legiones-daemonicas-tzeentch-soul-grinder']::text[]),
      ('daemonicas-voces-velo', array['unit-legiones-daemonicas-changecaster','unit-legiones-daemonicas-daemonic-herald-crucible']::text[]),
      ('daemonicas-piras-cambio', array['unit-legiones-daemonicas-exalted-flamer']::text[]),
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
        ('unit-legiones-daemonicas-pink-horrors', 'daemonicas-mareas-rosadas'),
        ('unit-legiones-daemonicas-flamers', 'daemonicas-llamas-imposibles'),
        ('unit-legiones-daemonicas-screamers', 'daemonicas-carros-fuego-mutante'),
        ('unit-legiones-daemonicas-burning-chariot', 'daemonicas-carros-ardientes'),
        ('unit-legiones-daemonicas-tzeentch-soul-grinder', 'daemonicas-forja-almas-tzeentch'),
        ('unit-legiones-daemonicas-changecaster', 'daemonicas-voces-velo'),
        ('unit-legiones-daemonicas-daemonic-herald-crucible', 'daemonicas-voces-velo'),
        ('unit-legiones-daemonicas-exalted-flamer', 'daemonicas-piras-cambio'),
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

revoke execute on function public.seed_daemonic_legions_troop_technology_tree() from public;
revoke execute on function public.seed_daemonic_legions_troop_technology_tree() from anon;
revoke execute on function public.seed_daemonic_legions_troop_technology_tree() from authenticated;

select public.seed_daemonic_legions_troop_technology_tree();
