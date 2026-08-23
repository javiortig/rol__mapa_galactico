update public.systems
set public_description = case slug
  when 'nexus-aster' then 'Un nudo central de rutas sepultado por ventiscas perpetuas. Entre los cráteres de hielo sobreviven asentamientos fortificados, torres de combustible y campamentos orkos semienterrados.'
  when 'goregate' then 'Un paso glacial de nieve negra y cañones helados, salpicado por pequeños asentamientos blindados que resisten bajo la sombra de las hogueras orkas.'
  else public_description
end
where slug in ('nexus-aster', 'goregate');

insert into public.campaign_events (
  slug,
  title,
  content,
  event_type,
  is_public
)
values (
  'prismatic-uridium-refinement',
  'Refinado prismático de Uridium',
  'Comandante, hemos conseguido refinar nuestros conocimientos de extracción de Uridium mediante tecnología prismática. Gracias a esta tecnología, podremos extraer el doble de combustible. Con este avance, deberíamos poder atacar finalmente a los orkos, aunque quizás deberíamos unir fuerzas.',
  'narrative',
  true
)
on conflict (slug) do update
set title = excluded.title,
    content = excluded.content,
    event_type = excluded.event_type,
    is_public = excluded.is_public,
    updated_at = now();

insert into public.campaign_logs (action_type, payload)
values (
  'campaign_lore_update',
  jsonb_build_object(
    'systems', jsonb_build_array('nexus-aster', 'goregate'),
    'event_slug', 'prismatic-uridium-refinement'
  )
);
