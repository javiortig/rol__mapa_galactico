update public.technology_nodes
set
  description = 'Arquitectura ceremonial para convertir victorias, lealtad y reliquias en poder de campaña.',
  effect_summary = 'Desbloquea Monumento y Santuario de Reliquias.'
where slug = 'monumentos-gloria'
  and tree_key = 'common-v1';

insert into public.campaign_logs (action_type, payload)
values (
  'technology_summary_updated',
  jsonb_build_object(
    'technology_slug', 'monumentos-gloria',
    'clarification', 'Monumentos a la Gloria desbloquea Monumento y Santuario de Reliquias.'
  )
);
