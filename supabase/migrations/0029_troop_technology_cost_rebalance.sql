create or replace function public.apply_troop_technology_cost_rebalance()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.technology_nodes nodes
  set cost_technology = data.cost_technology,
      updated_at = now()
  from (
    values
      ('troops-adeptus-custodes-v1', 'custodes-blindados-auramita', 2),
      ('troops-adeptus-custodes-v1', 'custodes-campeones-escudo', 2),
      ('troops-adeptus-custodes-v1', 'custodes-casas-questoris', 2),
      ('troops-adeptus-custodes-v1', 'custodes-centuras-vigilia', 2),
      ('troops-adeptus-custodes-v1', 'custodes-custodia-auramita', 1),
      ('troops-adeptus-custodes-v1', 'custodes-escuadras-nulas', 1),
      ('troops-adeptus-custodes-v1', 'custodes-grav-ligero', 2),
      ('troops-adeptus-custodes-v1', 'custodes-hueste-victoria', 3),
      ('troops-adeptus-custodes-v1', 'custodes-lanzas-especialistas', 2),
      ('troops-adeptus-custodes-v1', 'custodes-naves-trono', 2),
      ('troops-adeptus-custodes-v1', 'custodes-procesion-juramentada', 2),
      ('troops-adeptus-custodes-v1', 'custodes-rhino-psykana', 2),
      ('troops-adeptus-custodes-v1', 'custodes-sarcofagos-venerables', 2),
      ('troops-adeptus-custodes-v1', 'custodes-terminadores-auricos', 2),
      ('troops-adeptus-custodes-v1', 'custodes-titanes-terra', 3),
      ('troops-cultos-genestealer-v1', 'culto-celulas-mineras', 1),
      ('troops-cultos-genestealer-v1', 'culto-convoy-subterraneo', 2),
      ('troops-cultos-genestealer-v1', 'culto-cuchillos-bajo-ciudad', 2),
      ('troops-cultos-genestealer-v1', 'culto-guerrilla-crucible', 2),
      ('troops-cultos-genestealer-v1', 'culto-iconos-alzamiento', 2),
      ('troops-cultos-genestealer-v1', 'culto-mando-insurreccional', 3),
      ('troops-cultos-genestealer-v1', 'culto-mito-pistolero', 2),
      ('troops-cultos-genestealer-v1', 'culto-muelas-industriales', 2),
      ('troops-cultos-genestealer-v1', 'culto-musculo-aberrante', 2),
      ('troops-cultos-genestealer-v1', 'culto-profetas-dia-ascension', 3),
      ('troops-cultos-genestealer-v1', 'culto-pureza-genetica', 2),
      ('troops-cultos-genestealer-v1', 'culto-purga-prometio', 2),
      ('troops-cultos-genestealer-v1', 'culto-savia-mutagena', 2),
      ('troops-cultos-genestealer-v1', 'culto-trono-patriarca', 2),
      ('troops-cultos-genestealer-v1', 'culto-vox-cuarta-generacion', 1),
      ('troops-legiones-daemonicas-v1', 'daemonicas-ascension-demonica', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-carros-ardientes', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-carros-fuego-mutante', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-chispas-inmaterium', 1),
      ('troops-legiones-daemonicas-v1', 'daemonicas-discos-sortilegio', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-escribas-destino', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-forja-almas-tzeentch', 3),
      ('troops-legiones-daemonicas-v1', 'daemonicas-kairos-teje-destinos', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-llamas-imposibles', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-mareas-rosadas', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-mascaras-engano', 3),
      ('troops-legiones-daemonicas-v1', 'daemonicas-piras-cambio', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-primer-principe', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-senor-cambio', 2),
      ('troops-legiones-daemonicas-v1', 'daemonicas-voces-velo', 1),
      ('troops-necrones-v1', 'necrones-arcas-tumba', 2),
      ('troops-necrones-v1', 'necrones-camaras-acecho', 2),
      ('troops-necrones-v1', 'necrones-concilio-cryptek', 1),
      ('troops-necrones-v1', 'necrones-cultos-destructores', 2),
      ('troops-necrones-v1', 'necrones-dioses-fragmentados', 2),
      ('troops-necrones-v1', 'necrones-enjambres-canoptek', 2),
      ('troops-necrones-v1', 'necrones-guadanas-noche', 2),
      ('troops-necrones-v1', 'necrones-guardia-triarca', 2),
      ('troops-necrones-v1', 'necrones-matrices-reparacion', 2),
      ('troops-necrones-v1', 'necrones-megaestructuras-vivientes', 3),
      ('troops-necrones-v1', 'necrones-nobles-exterminio', 3),
      ('troops-necrones-v1', 'necrones-nobleza-dinastica', 2),
      ('troops-necrones-v1', 'necrones-oraculos-eternidad', 2),
      ('troops-necrones-v1', 'necrones-protocolos-reanimacion', 1),
      ('troops-necrones-v1', 'necrones-senores-tormenta', 2),
      ('troops-space-marines-v1', 'marines-alas-tormenta', 2),
      ('troops-space-marines-v1', 'marines-asalto-orbital', 2),
      ('troops-space-marines-v1', 'marines-bastiones-apoyo', 2),
      ('troops-space-marines-v1', 'marines-cazadores-motorizados', 2),
      ('troops-space-marines-v1', 'marines-despliegue-mecanizado', 2),
      ('troops-space-marines-v1', 'marines-eliminacion-silenciosa', 2),
      ('troops-space-marines-v1', 'marines-escuadras-batalla', 1),
      ('troops-space-marines-v1', 'marines-gravis-fuego-pesado', 2),
      ('troops-space-marines-v1', 'marines-lanzas-blindadas', 2),
      ('troops-space-marines-v1', 'marines-oficiales-compania', 2),
      ('troops-space-marines-v1', 'marines-patrullas-phobos', 1),
      ('troops-space-marines-v1', 'marines-primera-compania', 3),
      ('troops-space-marines-v1', 'marines-reliquias-cruzada', 3),
      ('troops-space-marines-v1', 'marines-sarcofagos-guerra', 2),
      ('troops-space-marines-v1', 'marines-veteranos-capitulo', 2)
  ) as data(tree_key, slug, cost_technology)
  where nodes.tree_key = data.tree_key
    and nodes.slug = data.slug;
end;
$$;

revoke execute on function public.apply_troop_technology_cost_rebalance() from public;
revoke execute on function public.apply_troop_technology_cost_rebalance() from anon;
revoke execute on function public.apply_troop_technology_cost_rebalance() from authenticated;

select public.apply_troop_technology_cost_rebalance();
