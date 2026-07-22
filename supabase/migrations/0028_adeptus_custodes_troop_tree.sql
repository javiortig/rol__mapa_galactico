create or replace function public.seed_adeptus_custodes_troop_technology_tree()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_custodes_faction_id uuid;
begin
  insert into public.technology_nodes (
    id, slug, tree_key, name, description, branch, tier, position_x, position_y,
    cost_technology, research_time_seconds, icon_key, effect_summary, is_starter, implementation_status
  )
  values
    (public.seed_uuid('technology_node', 'custodes-custodia-auramita'), 'custodes-custodia-auramita', 'troops-adeptus-custodes-v1', 'Custodia Auramita', 'La guardia basica del Trono forma la primera linea de defensa perfecta y ofensiva disciplinada. Desbloquea: Custodian Guard.', 'Guardia Auramita', 1, 1, 2, 1, 30, 'custodes_guard', 'Desbloquea: Custodian Guard.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-lanzas-especialistas'), 'custodes-lanzas-especialistas', 'troops-adeptus-custodes-v1', 'Lanzas Especialistas', 'Las formaciones de guardianes se diversifican en escoltas, fuego pesado y armas exoticas de auramita. Desbloquea: Custodian Wardens, Sagittarum Custodians y Custodian Guard with Adrasite and Pyrithite spears.', 'Guardia Auramita', 2, 1, 1, 1, 30, 'custodes_spear', 'Desbloquea: Custodian Wardens, Sagittarum Custodians, Custodian Guard with Adrasite and Pyrithite spears.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-campeones-escudo'), 'custodes-campeones-escudo', 'troops-adeptus-custodes-v1', 'Campeones del Escudo', 'El mando individual del Adeptus Custodes despliega duelistas, capitanes y custodios de autoridad excepcional. Desbloquea: Blade Champion, Shield-Captain, Guardian of the Throne [Crucible] y Valerian.', 'Guardia Auramita', 2, 1, 3, 1, 30, 'custodes_command', 'Desbloquea: Blade Champion, Shield-Captain, Guardian of the Throne [Crucible], Valerian.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-terminadores-auricos'), 'custodes-terminadores-auricos', 'troops-adeptus-custodes-v1', 'Terminadores Auricos', 'Las armaduras mas pesadas de la Guardia avanzan como camaras acorazadas vivas contra objetivos imposibles. Desbloquea: Allarus Custodians, Aquilon Custodians y Shield-Captain in Allarus Terminator Armour.', 'Guardia Auramita', 3, 1, 2, 2, 30, 'custodes_terminator', 'Desbloquea: Allarus Custodians, Aquilon Custodians, Shield-Captain in Allarus Terminator Armour.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-hueste-victoria'), 'custodes-hueste-victoria', 'troops-adeptus-custodes-v1', 'Hueste de la Victoria', 'La elite movil y los heroes mayores del Trono transforman cualquier frente en un juramento cumplido. Desbloquea: Trajann Valoris, Venatari Custodians, Kataphraktoi Exemplar [Crucible] y Shield-Captain on Dawneagle Jetbike.', 'Guardia Auramita', 4, 1, 2, 3, 30, 'custodes_victory', 'Desbloquea: Trajann Valoris, Venatari Custodians, Kataphraktoi Exemplar [Crucible], Shield-Captain on Dawneagle Jetbike.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-escuadras-nulas'), 'custodes-escuadras-nulas', 'troops-adeptus-custodes-v1', 'Escuadras Nulas', 'Las Hermanas del Silencio sellan rutas psiquicas y cazan brujas antes de que contaminen la campana. Desbloquea: Prosecutors, Vigilators y Witchseekers.', 'Camara Anathema', 1, 2, 2, 1, 30, 'custodes_null', 'Desbloquea: Prosecutors, Vigilators, Witchseekers.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-centuras-vigilia'), 'custodes-centuras-vigilia', 'troops-adeptus-custodes-v1', 'Centuras de la Vigilia', 'La cadena de mando Anathema despliega ejecutoras, heroes de la Vigilia y protocolos [Crucible]. Desbloquea: Knight-Centura, Aleya y Null Maiden [Crucible].', 'Camara Anathema', 2, 2, 1, 1, 30, 'custodes_silent_command', 'Desbloquea: Knight-Centura, Aleya, Null Maiden [Crucible].', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-rhino-psykana'), 'custodes-rhino-psykana', 'troops-adeptus-custodes-v1', 'Rhino Psykana', 'Transportes sellados permiten que las cazadoras nulas lleguen a santuarios, frentes y brechas psiquicas. Desbloquea: Anathema Psykana Rhino.', 'Camara Anathema', 2, 2, 3, 1, 30, 'custodes_rhino', 'Desbloquea: Anathema Psykana Rhino.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-procesion-juramentada'), 'custodes-procesion-juramentada', 'troops-adeptus-custodes-v1', 'Procesion Juramentada', 'Auxiliares imperiales autorizados acompanan a la Camara como voz ritual, testigo y penitencia armada. Desbloquea: Ministorum Priest.', 'Camara Anathema', 3, 2, 2, 2, 30, 'custodes_priest', 'Desbloquea: Ministorum Priest.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-grav-ligero'), 'custodes-grav-ligero', 'troops-adeptus-custodes-v1', 'Grav-Vehiculos Ligeros', 'Los primeros chasis grav aseguran rutas, evacuaciones tacticas y golpes quirurgicos en la frontera. Desbloquea: Pallas Grav-attack y Coronus Grav-carrier.', 'Arsenal del Trono', 1, 3, 2, 1, 30, 'custodes_grav', 'Desbloquea: Pallas Grav-attack, Coronus Grav-carrier.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-sarcofagos-venerables'), 'custodes-sarcofagos-venerables', 'troops-adeptus-custodes-v1', 'Sarcofagos Venerables', 'Los heroes caidos del Trono vuelven a caminar en chasis Contemptor para duelos, brechas y guardiania eterna. Desbloquea: Contemptor-Achillus Dreadnought, Contemptor-Galatus Dreadnought y Venerable Contemptor Dreadnought.', 'Arsenal del Trono', 2, 3, 1, 1, 30, 'custodes_dreadnought', 'Desbloquea: Contemptor-Achillus Dreadnought, Contemptor-Galatus Dreadnought, Venerable Contemptor Dreadnought.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-blindados-auramita'), 'custodes-blindados-auramita', 'troops-adeptus-custodes-v1', 'Blindados de Auramita', 'Tanques grav, reliquias Land Raider y dreadnoughts pesados forman la respuesta dorada a una guerra total. Desbloquea: Caladius Grav-tank, Venerable Land Raider y Telemon Heavy Dreadnought.', 'Arsenal del Trono', 3, 3, 1, 2, 30, 'custodes_tank', 'Desbloquea: Caladius Grav-tank, Venerable Land Raider, Telemon Heavy Dreadnought.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-naves-trono'), 'custodes-naves-trono', 'troops-adeptus-custodes-v1', 'Naves del Trono', 'Aeronaves de asalto y supremacia orbital permiten llevar la guerra del Trono a cualquier mundo rebelde. Desbloquea: Ares Gunship y Orion Assault Dropship.', 'Arsenal del Trono', 3, 3, 3, 2, 30, 'custodes_air', 'Desbloquea: Ares Gunship, Orion Assault Dropship.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-casas-questoris'), 'custodes-casas-questoris', 'troops-adeptus-custodes-v1', 'Casas Questoris', 'Juramentos de sangre y deuda abren el apoyo de Armigers, Barones y Knights aliados para guerras que superan una guarnicion. Desbloquea: Armiger Helverin, Armiger Warglaive, Armiger Moirax, Knight Destrier, Knight Gallant, Knight Preceptor, Knight Paladin, Knight Warden, Knight Crusader, Knight Defender, Knight Castellan, Knight Valiant, Cerastus Knight Lancer y Canis Rex.', 'Arsenal del Trono', 4, 3, 2, 3, 30, 'custodes_knight', 'Desbloquea: Armiger Helverin, Armiger Warglaive, Armiger Moirax, Knight Destrier, Knight Gallant, Knight Preceptor, Knight Paladin, Knight Warden, Knight Crusader, Knight Defender, Knight Castellan, Knight Valiant, Cerastus Knight Lancer, Canis Rex.', false, 'active'),
    (public.seed_uuid('technology_node', 'custodes-titanes-terra'), 'custodes-titanes-terra', 'troops-adeptus-custodes-v1', 'Titanes de Terra', 'Los pactos mas extremos movilizan Acastus, maquinas dios y Titanes como simbolos absolutos de intervencion imperial. Desbloquea: Acastus Knight Porphyrion, Acastus Knight Asterius, Warhound Titan y Warlord Titan.', 'Arsenal del Trono', 5, 3, 2, 4, 30, 'custodes_titan', 'Desbloquea: Acastus Knight Porphyrion, Acastus Knight Asterius, Warhound Titan, Warlord Titan.', false, 'active')
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
  where tree_key = 'troops-adeptus-custodes-v1'
    and slug not in (
      'custodes-custodia-auramita',
      'custodes-lanzas-especialistas',
      'custodes-campeones-escudo',
      'custodes-terminadores-auricos',
      'custodes-hueste-victoria',
      'custodes-escuadras-nulas',
      'custodes-centuras-vigilia',
      'custodes-rhino-psykana',
      'custodes-procesion-juramentada',
      'custodes-grav-ligero',
      'custodes-sarcofagos-venerables',
      'custodes-blindados-auramita',
      'custodes-naves-trono',
      'custodes-casas-questoris',
      'custodes-titanes-terra'
    );

  delete from public.technology_prerequisites prerequisites
  using public.technology_nodes nodes
  where prerequisites.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-adeptus-custodes-v1';

  insert into public.technology_prerequisites (technology_node_id, required_node_id, prerequisite_group)
  select tech.id, required.id, data.prerequisite_group
  from (
    values
      ('custodes-custodia-auramita', 'fundacion-planetaria', 1),
      ('custodes-lanzas-especialistas', 'custodes-custodia-auramita', 1),
      ('custodes-campeones-escudo', 'custodes-custodia-auramita', 1),
      ('custodes-campeones-escudo', 'asamblea-planetaria', 2),
      ('custodes-terminadores-auricos', 'custodes-lanzas-especialistas', 1),
      ('custodes-terminadores-auricos', 'custodes-campeones-escudo', 2),
      ('custodes-hueste-victoria', 'custodes-terminadores-auricos', 1),
      ('custodes-hueste-victoria', 'maquinaria-belica', 2),
      ('custodes-escuadras-nulas', 'fundacion-planetaria', 1),
      ('custodes-centuras-vigilia', 'custodes-escuadras-nulas', 1),
      ('custodes-centuras-vigilia', 'asamblea-planetaria', 2),
      ('custodes-rhino-psykana', 'custodes-escuadras-nulas', 1),
      ('custodes-rhino-psykana', 'maquinaria-belica', 2),
      ('custodes-procesion-juramentada', 'custodes-centuras-vigilia', 1),
      ('custodes-procesion-juramentada', 'custodes-rhino-psykana', 2),
      ('custodes-grav-ligero', 'maquinaria-belica', 1),
      ('custodes-sarcofagos-venerables', 'custodes-grav-ligero', 1),
      ('custodes-sarcofagos-venerables', 'custodes-campeones-escudo', 2),
      ('custodes-blindados-auramita', 'custodes-sarcofagos-venerables', 1),
      ('custodes-naves-trono', 'custodes-grav-ligero', 1),
      ('custodes-naves-trono', 'maquinaria-belica', 2),
      ('custodes-casas-questoris', 'custodes-blindados-auramita', 1),
      ('custodes-casas-questoris', 'custodes-naves-trono', 2),
      ('custodes-titanes-terra', 'custodes-casas-questoris', 1)
  ) as data(technology_slug, required_slug, prerequisite_group)
  join public.technology_nodes tech on tech.slug = data.technology_slug
  join public.technology_nodes required on required.slug = data.required_slug
  on conflict (technology_node_id, required_node_id) do update
  set prerequisite_group = excluded.prerequisite_group;

  delete from public.technology_effects effects
  using public.technology_nodes nodes
  where effects.technology_node_id = nodes.id
    and nodes.tree_key = 'troops-adeptus-custodes-v1'
    and effects.effect_type = 'unlock_unit_template';

  insert into public.technology_effects (id, technology_node_id, effect_type, payload)
  select
    public.seed_uuid('technology_effect', data.technology_slug || '-units'),
    technology_nodes.id,
    'unlock_unit_template',
    jsonb_build_object('unit_template_slugs', data.unit_template_slugs)
  from (
    values
      ('custodes-custodia-auramita', array['unit-adeptus-custodes-custodian-guard']::text[]),
      ('custodes-lanzas-especialistas', array['unit-adeptus-custodes-custodian-wardens','unit-adeptus-custodes-sagittarum-custodians','unit-adeptus-custodes-custodian-guard-with-adrasite-and-pyrithite-spears']::text[]),
      ('custodes-campeones-escudo', array['unit-adeptus-custodes-blade-champion','unit-adeptus-custodes-shield-captain','unit-adeptus-custodes-guardian-of-the-throne-crucible','unit-adeptus-custodes-valerian']::text[]),
      ('custodes-terminadores-auricos', array['unit-adeptus-custodes-allarus-custodians','unit-adeptus-custodes-aquilon-custodians','unit-adeptus-custodes-shield-captain-in-allarus-terminator-armour']::text[]),
      ('custodes-hueste-victoria', array['unit-adeptus-custodes-trajann-valoris','unit-adeptus-custodes-venatari-custodians','unit-adeptus-custodes-kataphraktoi-exemplar-crucible','unit-adeptus-custodes-shield-captain-on-dawneagle-jetbike']::text[]),
      ('custodes-escuadras-nulas', array['unit-adeptus-custodes-prosecutors','unit-adeptus-custodes-vigilators','unit-adeptus-custodes-witchseekers']::text[]),
      ('custodes-centuras-vigilia', array['unit-adeptus-custodes-knight-centura','unit-adeptus-custodes-aleya','unit-adeptus-custodes-null-maiden-crucible']::text[]),
      ('custodes-rhino-psykana', array['unit-adeptus-custodes-anathema-psykana-rhino']::text[]),
      ('custodes-procesion-juramentada', array['unit-adeptus-custodes-ministorum-priest']::text[]),
      ('custodes-grav-ligero', array['unit-adeptus-custodes-pallas-grav-attack','unit-adeptus-custodes-coronus-grav-carrier']::text[]),
      ('custodes-sarcofagos-venerables', array['unit-adeptus-custodes-contemptor-achillus-dreadnought','unit-adeptus-custodes-contemptor-galatus-dreadnought','unit-adeptus-custodes-venerable-contemptor-dreadnought']::text[]),
      ('custodes-blindados-auramita', array['unit-adeptus-custodes-caladius-grav-tank','unit-adeptus-custodes-venerable-land-raider','unit-adeptus-custodes-telemon-heavy-dreadnought']::text[]),
      ('custodes-naves-trono', array['unit-adeptus-custodes-ares-gunship','unit-adeptus-custodes-orion-assault-dropship']::text[]),
      ('custodes-casas-questoris', array['unit-adeptus-custodes-armiger-helverin','unit-adeptus-custodes-armiger-warglaive','unit-adeptus-custodes-armiger-moirax','unit-adeptus-custodes-knight-destrier','unit-adeptus-custodes-knight-gallant','unit-adeptus-custodes-knight-preceptor','unit-adeptus-custodes-knight-paladin','unit-adeptus-custodes-knight-warden','unit-adeptus-custodes-knight-crusader','unit-adeptus-custodes-knight-defender','unit-adeptus-custodes-knight-castellan','unit-adeptus-custodes-knight-valiant','unit-adeptus-custodes-cerastus-knight-lancer','unit-adeptus-custodes-canis-rex']::text[]),
      ('custodes-titanes-terra', array['unit-adeptus-custodes-acastus-knight-porphyrion','unit-adeptus-custodes-acastus-knight-asterius','unit-adeptus-custodes-warhound-titan','unit-adeptus-custodes-warlord-titan']::text[])
  ) as data(technology_slug, unit_template_slugs)
  join public.technology_nodes on technology_nodes.slug = data.technology_slug
  on conflict (id) do update
  set technology_node_id = excluded.technology_node_id,
      effect_type = excluded.effect_type,
      payload = excluded.payload;

  select id into v_custodes_faction_id
  from public.factions
  where slug = 'adeptus-custodes';

  if v_custodes_faction_id is not null then
    update public.unit_templates
    set is_available = false,
        required_technology_node_id = null
    where faction_id = v_custodes_faction_id;

    update public.unit_templates templates
    set is_available = true,
        required_technology_node_id = technology_nodes.id
    from (
      values
        ('unit-adeptus-custodes-custodian-guard', 'custodes-custodia-auramita'),
        ('unit-adeptus-custodes-custodian-wardens', 'custodes-lanzas-especialistas'),
        ('unit-adeptus-custodes-sagittarum-custodians', 'custodes-lanzas-especialistas'),
        ('unit-adeptus-custodes-custodian-guard-with-adrasite-and-pyrithite-spears', 'custodes-lanzas-especialistas'),
        ('unit-adeptus-custodes-blade-champion', 'custodes-campeones-escudo'),
        ('unit-adeptus-custodes-shield-captain', 'custodes-campeones-escudo'),
        ('unit-adeptus-custodes-guardian-of-the-throne-crucible', 'custodes-campeones-escudo'),
        ('unit-adeptus-custodes-valerian', 'custodes-campeones-escudo'),
        ('unit-adeptus-custodes-allarus-custodians', 'custodes-terminadores-auricos'),
        ('unit-adeptus-custodes-aquilon-custodians', 'custodes-terminadores-auricos'),
        ('unit-adeptus-custodes-shield-captain-in-allarus-terminator-armour', 'custodes-terminadores-auricos'),
        ('unit-adeptus-custodes-trajann-valoris', 'custodes-hueste-victoria'),
        ('unit-adeptus-custodes-venatari-custodians', 'custodes-hueste-victoria'),
        ('unit-adeptus-custodes-kataphraktoi-exemplar-crucible', 'custodes-hueste-victoria'),
        ('unit-adeptus-custodes-shield-captain-on-dawneagle-jetbike', 'custodes-hueste-victoria'),
        ('unit-adeptus-custodes-prosecutors', 'custodes-escuadras-nulas'),
        ('unit-adeptus-custodes-vigilators', 'custodes-escuadras-nulas'),
        ('unit-adeptus-custodes-witchseekers', 'custodes-escuadras-nulas'),
        ('unit-adeptus-custodes-knight-centura', 'custodes-centuras-vigilia'),
        ('unit-adeptus-custodes-aleya', 'custodes-centuras-vigilia'),
        ('unit-adeptus-custodes-null-maiden-crucible', 'custodes-centuras-vigilia'),
        ('unit-adeptus-custodes-anathema-psykana-rhino', 'custodes-rhino-psykana'),
        ('unit-adeptus-custodes-ministorum-priest', 'custodes-procesion-juramentada'),
        ('unit-adeptus-custodes-pallas-grav-attack', 'custodes-grav-ligero'),
        ('unit-adeptus-custodes-coronus-grav-carrier', 'custodes-grav-ligero'),
        ('unit-adeptus-custodes-contemptor-achillus-dreadnought', 'custodes-sarcofagos-venerables'),
        ('unit-adeptus-custodes-contemptor-galatus-dreadnought', 'custodes-sarcofagos-venerables'),
        ('unit-adeptus-custodes-venerable-contemptor-dreadnought', 'custodes-sarcofagos-venerables'),
        ('unit-adeptus-custodes-caladius-grav-tank', 'custodes-blindados-auramita'),
        ('unit-adeptus-custodes-venerable-land-raider', 'custodes-blindados-auramita'),
        ('unit-adeptus-custodes-telemon-heavy-dreadnought', 'custodes-blindados-auramita'),
        ('unit-adeptus-custodes-ares-gunship', 'custodes-naves-trono'),
        ('unit-adeptus-custodes-orion-assault-dropship', 'custodes-naves-trono'),
        ('unit-adeptus-custodes-armiger-helverin', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-armiger-warglaive', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-armiger-moirax', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-destrier', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-gallant', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-preceptor', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-paladin', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-warden', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-crusader', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-defender', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-castellan', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-knight-valiant', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-cerastus-knight-lancer', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-canis-rex', 'custodes-casas-questoris'),
        ('unit-adeptus-custodes-acastus-knight-porphyrion', 'custodes-titanes-terra'),
        ('unit-adeptus-custodes-acastus-knight-asterius', 'custodes-titanes-terra'),
        ('unit-adeptus-custodes-warhound-titan', 'custodes-titanes-terra'),
        ('unit-adeptus-custodes-warlord-titan', 'custodes-titanes-terra')
    ) as assignments(unit_slug, technology_slug)
    join public.technology_nodes on technology_nodes.slug = assignments.technology_slug
    where templates.slug = assignments.unit_slug
      and templates.faction_id = v_custodes_faction_id;

    perform public.refresh_available_technologies(v_custodes_faction_id);
  end if;
end;
$$;

revoke execute on function public.seed_adeptus_custodes_troop_technology_tree() from public;
revoke execute on function public.seed_adeptus_custodes_troop_technology_tree() from anon;
revoke execute on function public.seed_adeptus_custodes_troop_technology_tree() from authenticated;

select public.seed_adeptus_custodes_troop_technology_tree();
