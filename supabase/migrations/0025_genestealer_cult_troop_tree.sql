create or replace function public.seed_genestealer_cult_troop_technology_tree()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cult_faction_id uuid;
begin
  insert into public.technology_nodes (
    id, slug, tree_key, name, description, branch, tier, position_x, position_y,
    cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
  )
  values
    (public.seed_uuid('technology_node', 'culto-celulas-mineras'), 'culto-celulas-mineras', 'troops-cultos-genestealer-v1', 'Celulas Mineras', 'Las primeras celulas obreras toman armas ocultas y convierten manufactorums en cuarteles secretos. Desbloquea: Neophyte Hybrids.', 'Red de Insurreccion', 1, 1, 2, 1, 30, 'cult_cell', 'Desbloquea: Neophyte Hybrids.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-iconos-alzamiento'), 'culto-iconos-alzamiento', 'troops-cultos-genestealer-v1', 'Iconos del Alzamiento', 'Los acolitos salen de los santuarios industriales con iconos y armas rituales para dirigir masas insurgentes. Desbloquea: Acolyte Hybrids with Autopistols y Acolyte Iconward.', 'Red de Insurreccion', 2, 1, 1, 1, 30, 'cult_icon', 'Desbloquea: Acolyte Hybrids with Autopistols, Acolyte Iconward.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-purga-prometio'), 'culto-purga-prometio', 'troops-cultos-genestealer-v1', 'Purga de Prometio', 'Las cuadrillas de tunel aprenden a limpiar bunkeres y corredores con fuego industrial. Desbloquea: Acolyte Hybrids with Hand Flamers.', 'Red de Insurreccion', 2, 1, 3, 1, 30, 'cult_flame', 'Desbloquea: Acolyte Hybrids with Hand Flamers.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-convoy-subterraneo'), 'culto-convoy-subterraneo', 'troops-cultos-genestealer-v1', 'Convoy Subterraneo', 'Rutas mineras, talleres ocultos y conductores juramentados convierten vehiculos civiles en columnas de guerra. Desbloquea: Goliath Truck y Achilles Ridgerunners.', 'Red de Insurreccion', 3, 1, 1, 2, 30, 'cult_convoy', 'Desbloquea: Goliath Truck, Achilles Ridgerunners.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-muelas-industriales'), 'culto-muelas-industriales', 'troops-cultos-genestealer-v1', 'Muelas Industriales', 'Las maquinas de extraccion pesada se blindan, se arman y se lanzan contra fortalezas de superficie. Desbloquea: Goliath Rockgrinder.', 'Red de Insurreccion', 4, 1, 1, 2, 30, 'cult_rockgrinder', 'Desbloquea: Goliath Rockgrinder.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-mando-insurreccional'), 'culto-mando-insurreccional', 'troops-cultos-genestealer-v1', 'Mando Insurreccional', 'El culto coordina celulas abiertas, reservas dormidas y golpes sincronizados de conquista planetaria. Desbloquea: Primus, Nexos y Cult Insurrectionist [Crucible].', 'Red de Insurreccion', 4, 1, 3, 3, 30, 'cult_command', 'Desbloquea: Primus, Nexos, Cult Insurrectionist [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-vox-cuarta-generacion'), 'culto-vox-cuarta-generacion', 'troops-cultos-genestealer-v1', 'Vox de Cuarta Generacion', 'Predicadores, psiquicos y transmisores clandestinos convierten rumores de colmena en mandato sagrado. Desbloquea: Clamavus, Magus.', 'Sombras del Culto', 1, 2, 2, 1, 30, 'cult_vox', 'Desbloquea: Clamavus, Magus.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-cuchillos-bajo-ciudad'), 'culto-cuchillos-bajo-ciudad', 'troops-cultos-genestealer-v1', 'Cuchillos Bajo la Ciudad', 'Custodios personales y asesinos de culto eliminan objetivos clave antes de que la revuelta sea visible. Desbloquea: Locus y Sanctus.', 'Sombras del Culto', 2, 2, 1, 1, 30, 'cult_blade', 'Desbloquea: Locus, Sanctus.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-mito-pistolero'), 'culto-mito-pistolero', 'troops-cultos-genestealer-v1', 'Mito Pistolero', 'Heroes callejeros y especialistas en demoliciones vuelven cada callejon una trampa propagandistica. Desbloquea: Kelermorph y Reductus Saboteur.', 'Sombras del Culto', 2, 2, 3, 1, 30, 'cult_guns', 'Desbloquea: Kelermorph, Reductus Saboteur.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-guerrilla-crucible'), 'culto-guerrilla-crucible', 'troops-cultos-genestealer-v1', 'Guerrilla Crucible', 'Escuadras de reconocimiento, motos de tunel y celulas [Crucible] golpean flancos y rutas de retirada. Desbloquea: Atalan Jackals, Jackal Alphus y Cult Guerrilla [Crucible].', 'Sombras del Culto', 3, 2, 2, 2, 30, 'cult_guerrilla', 'Desbloquea: Atalan Jackals, Jackal Alphus, Cult Guerrilla [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-profetas-dia-ascension'), 'culto-profetas-dia-ascension', 'troops-cultos-genestealer-v1', 'Profetas del Dia de la Ascension', 'Voces bendecidas y mentes sinapticas anuncian el momento exacto en que la ciudad debe caer. Desbloquea: Benefictus y Voice of the Patriarch [Crucible].', 'Sombras del Culto', 4, 2, 2, 3, 30, 'cult_prophet', 'Desbloquea: Benefictus, Voice of the Patriarch [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-savia-mutagena'), 'culto-savia-mutagena', 'troops-cultos-genestealer-v1', 'Savia Mutagena', 'Cirujanos de culto y mutantes de primera linea aceleran la transformacion de la progenie hibrida. Desbloquea: Biophagus y Hybrid Metamorphs.', 'Ascension del Patriarca', 1, 3, 1, 1, 30, 'cult_mutation', 'Desbloquea: Biophagus, Hybrid Metamorphs.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-pureza-genetica'), 'culto-pureza-genetica', 'troops-cultos-genestealer-v1', 'Pureza Genetica', 'Los descendientes mas puros del beso genestealer salen de madrigueras selladas para romper lineas enemigas. Desbloquea: Purestrain Genestealers.', 'Ascension del Patriarca', 2, 3, 1, 2, 30, 'cult_genestealer', 'Desbloquea: Purestrain Genestealers.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-musculo-aberrante'), 'culto-musculo-aberrante', 'troops-cultos-genestealer-v1', 'Musculo Aberrante', 'La fuerza mutante del culto se convierte en ariete vivo protegido por amos deformes. Desbloquea: Aberrants y Abominant.', 'Ascension del Patriarca', 2, 3, 3, 2, 30, 'cult_aberrant', 'Desbloquea: Aberrants, Abominant.', false, 'active'),
    (public.seed_uuid('technology_node', 'culto-trono-patriarca'), 'culto-trono-patriarca', 'troops-cultos-genestealer-v1', 'Trono del Patriarca', 'La progenie, los profetas y los aberrantes reconocen una unica voluntad sinaptica al final del alzamiento. Desbloquea: Patriarch.', 'Ascension del Patriarca', 3, 3, 2, 3, 30, 'cult_patriarch', 'Desbloquea: Patriarch.', false, 'active')
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
  where tree_key = 'troops-cultos-genestealer-v1'
    and slug not in (
      'culto-celulas-mineras',
      'culto-iconos-alzamiento',
      'culto-purga-prometio',
      'culto-convoy-subterraneo',
      'culto-muelas-industriales',
      'culto-mando-insurreccional',
      'culto-vox-cuarta-generacion',
      'culto-cuchillos-bajo-ciudad',
      'culto-mito-pistolero',
      'culto-guerrilla-crucible',
      'culto-profetas-dia-ascension',
      'culto-savia-mutagena',
      'culto-pureza-genetica',
      'culto-musculo-aberrante',
      'culto-trono-patriarca'
    );

  delete from public.technology_prerequisites prerequisites
  using public.technology_nodes nodes
  where prerequisites.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-cultos-genestealer-v1';

  insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
  select tech.id, required.id, data.prerequisite_group
  from (
    values
      ('culto-celulas-mineras', 'fundacion-planetaria', 1),
      ('culto-iconos-alzamiento', 'culto-celulas-mineras', 1),
      ('culto-purga-prometio', 'culto-celulas-mineras', 1),
      ('culto-convoy-subterraneo', 'culto-iconos-alzamiento', 1),
      ('culto-convoy-subterraneo', 'maquinaria-belica', 2),
      ('culto-muelas-industriales', 'culto-convoy-subterraneo', 1),
      ('culto-mando-insurreccional', 'culto-iconos-alzamiento', 1),
      ('culto-mando-insurreccional', 'culto-vox-cuarta-generacion', 2),
      ('culto-mando-insurreccional', 'asamblea-planetaria', 3),
      ('culto-vox-cuarta-generacion', 'asamblea-planetaria', 1),
      ('culto-cuchillos-bajo-ciudad', 'culto-vox-cuarta-generacion', 1),
      ('culto-mito-pistolero', 'culto-vox-cuarta-generacion', 1),
      ('culto-guerrilla-crucible', 'culto-mito-pistolero', 1),
      ('culto-guerrilla-crucible', 'culto-convoy-subterraneo', 2),
      ('culto-profetas-dia-ascension', 'culto-guerrilla-crucible', 1),
      ('culto-profetas-dia-ascension', 'culto-mando-insurreccional', 2),
      ('culto-savia-mutagena', 'criadero-guerra', 1),
      ('culto-pureza-genetica', 'culto-savia-mutagena', 1),
      ('culto-musculo-aberrante', 'culto-savia-mutagena', 1),
      ('culto-musculo-aberrante', 'culto-iconos-alzamiento', 2),
      ('culto-trono-patriarca', 'culto-pureza-genetica', 1),
      ('culto-trono-patriarca', 'culto-musculo-aberrante', 2),
      ('culto-trono-patriarca', 'culto-profetas-dia-ascension', 3)
  ) as data(technology_slug, required_slug, prerequisite_group)
  join public.technology_nodes tech on tech.slug = data.technology_slug
  join public.technology_nodes required on required.slug = data.required_slug
  on conflict (technology_node_id, required_node_id) do update
  set prerequisite_group = excluded.prerequisite_group;

  delete from public.technology_effects effects
  using public.technology_nodes nodes
  where effects.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-cultos-genestealer-v1'
    and effects.effect_type = 'unlock_unit_template';

  insert into public.technology_effects (id, technology_node_id, effect_type, payload)
  select
    public.seed_uuid('technology_effect', data.technology_slug || '-units'),
    technology_nodes.id,
    'unlock_unit_template',
    jsonb_build_object('unit_template_slugs', data.unit_template_slugs)
  from (
    values
      ('culto-celulas-mineras', array['unit-cultos-genestealer-neophyte-hybrids']::text[]),
      ('culto-iconos-alzamiento', array['unit-cultos-genestealer-acolyte-hybrids-with-autopistols','unit-cultos-genestealer-acolyte-iconward']::text[]),
      ('culto-purga-prometio', array['unit-cultos-genestealer-acolyte-hybrids-with-hand-flamers']::text[]),
      ('culto-convoy-subterraneo', array['unit-cultos-genestealer-goliath-truck','unit-cultos-genestealer-achilles-ridgerunners']::text[]),
      ('culto-muelas-industriales', array['unit-cultos-genestealer-goliath-rockgrinder']::text[]),
      ('culto-mando-insurreccional', array['unit-cultos-genestealer-primus','unit-cultos-genestealer-nexos','unit-cultos-genestealer-cult-insurrectionist-crucible']::text[]),
      ('culto-vox-cuarta-generacion', array['unit-cultos-genestealer-clamavus','unit-cultos-genestealer-magus']::text[]),
      ('culto-cuchillos-bajo-ciudad', array['unit-cultos-genestealer-locus','unit-cultos-genestealer-sanctus']::text[]),
      ('culto-mito-pistolero', array['unit-cultos-genestealer-kelermorph','unit-cultos-genestealer-reductus-saboteur']::text[]),
      ('culto-guerrilla-crucible', array['unit-cultos-genestealer-atalan-jackals','unit-cultos-genestealer-jackal-alphus','unit-cultos-genestealer-cult-guerrilla-crucible']::text[]),
      ('culto-profetas-dia-ascension', array['unit-cultos-genestealer-benefictus','unit-cultos-genestealer-voice-of-the-patriarch-crucible']::text[]),
      ('culto-savia-mutagena', array['unit-cultos-genestealer-biophagus','unit-cultos-genestealer-hybrid-metamorphs']::text[]),
      ('culto-pureza-genetica', array['unit-cultos-genestealer-purestrain-genestealers']::text[]),
      ('culto-musculo-aberrante', array['unit-cultos-genestealer-aberrants','unit-cultos-genestealer-abominant']::text[]),
      ('culto-trono-patriarca', array['unit-cultos-genestealer-patriarch']::text[])
  ) as data(technology_slug, unit_template_slugs)
  join public.technology_nodes on technology_nodes.slug = data.technology_slug
  on conflict (id) do update
  set technology_node_id = excluded.technology_node_id,
      effect_type = excluded.effect_type,
      payload = excluded.payload;

  select id into v_cult_faction_id
  from public.factions
  where slug = 'cultos-genestealer';

  if v_cult_faction_id is not null then
    update public.unit_templates
    set is_available = false,
        required_technology_node_id = null
    where faction_id = v_cult_faction_id;

    update public.unit_templates templates
    set is_available = true,
        required_technology_node_id = technology_nodes.id
    from (
      values
        ('unit-cultos-genestealer-neophyte-hybrids', 'culto-celulas-mineras'),
        ('unit-cultos-genestealer-acolyte-hybrids-with-autopistols', 'culto-iconos-alzamiento'),
        ('unit-cultos-genestealer-acolyte-iconward', 'culto-iconos-alzamiento'),
        ('unit-cultos-genestealer-acolyte-hybrids-with-hand-flamers', 'culto-purga-prometio'),
        ('unit-cultos-genestealer-goliath-truck', 'culto-convoy-subterraneo'),
        ('unit-cultos-genestealer-achilles-ridgerunners', 'culto-convoy-subterraneo'),
        ('unit-cultos-genestealer-goliath-rockgrinder', 'culto-muelas-industriales'),
        ('unit-cultos-genestealer-primus', 'culto-mando-insurreccional'),
        ('unit-cultos-genestealer-nexos', 'culto-mando-insurreccional'),
        ('unit-cultos-genestealer-cult-insurrectionist-crucible', 'culto-mando-insurreccional'),
        ('unit-cultos-genestealer-clamavus', 'culto-vox-cuarta-generacion'),
        ('unit-cultos-genestealer-magus', 'culto-vox-cuarta-generacion'),
        ('unit-cultos-genestealer-locus', 'culto-cuchillos-bajo-ciudad'),
        ('unit-cultos-genestealer-sanctus', 'culto-cuchillos-bajo-ciudad'),
        ('unit-cultos-genestealer-kelermorph', 'culto-mito-pistolero'),
        ('unit-cultos-genestealer-reductus-saboteur', 'culto-mito-pistolero'),
        ('unit-cultos-genestealer-atalan-jackals', 'culto-guerrilla-crucible'),
        ('unit-cultos-genestealer-jackal-alphus', 'culto-guerrilla-crucible'),
        ('unit-cultos-genestealer-cult-guerrilla-crucible', 'culto-guerrilla-crucible'),
        ('unit-cultos-genestealer-benefictus', 'culto-profetas-dia-ascension'),
        ('unit-cultos-genestealer-voice-of-the-patriarch-crucible', 'culto-profetas-dia-ascension'),
        ('unit-cultos-genestealer-biophagus', 'culto-savia-mutagena'),
        ('unit-cultos-genestealer-hybrid-metamorphs', 'culto-savia-mutagena'),
        ('unit-cultos-genestealer-purestrain-genestealers', 'culto-pureza-genetica'),
        ('unit-cultos-genestealer-aberrants', 'culto-musculo-aberrante'),
        ('unit-cultos-genestealer-abominant', 'culto-musculo-aberrante'),
        ('unit-cultos-genestealer-patriarch', 'culto-trono-patriarca')
    ) as assignments(unit_slug, technology_slug)
    join public.technology_nodes on technology_nodes.slug = assignments.technology_slug
    where templates.slug = assignments.unit_slug
      and templates.faction_id = v_cult_faction_id;

    perform public.refresh_available_technologies(v_cult_faction_id);
  end if;
end;
$$;

revoke execute on function public.seed_genestealer_cult_troop_technology_tree() from public;
revoke execute on function public.seed_genestealer_cult_troop_technology_tree() from anon;
revoke execute on function public.seed_genestealer_cult_troop_technology_tree() from authenticated;

select public.seed_genestealer_cult_troop_technology_tree();
