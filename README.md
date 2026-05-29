# Mapa Estelar de Campana 40K

Interfaz web privada para gestionar una campana narrativa de Warhammer 40K con mapa estelar, recursos, movimiento, reclutamiento y reportes de batalla.

## Stack

- Next.js App Router + React + TypeScript.
- Tailwind CSS para la UI.
- PixiJS para el mapa estelar WebGL.
- Zustand para estado local del mapa.
- TanStack Query para server state.
- Supabase como backend autoritativo local/cloud.

## Esqueleto actual

- App principal en `/`.
- Login local con Supabase Auth en `/login`.
- Admin placeholder en `/admin`.
- Datos mock en `src/mocks/campaign-data.ts` como fallback si Supabase no esta configurado.
- Tipos de dominio en `src/domain/campaign.ts`.
- Contrato Supabase en `supabase/migrations`.
- Seed local en `supabase/seed.sql`.

## Comandos

```bash
npm install
npm run supabase:start
npm run db:reset
npm run db:sync-env
npm run db:seed:users
npm run dev
```

Supabase Studio local queda en `http://127.0.0.1:54323`.

Usuarios locales:

```text
admin@rol40k.local / admin-local-123
orcos@rol40k.local / rol40k-local-123
necrones@rol40k.local / rol40k-local-123
guardia-imperial@rol40k.local / rol40k-local-123
culto-genestelar@rol40k.local / rol40k-local-123
sombra-emperador@rol40k.local / rol40k-local-123
guardia-muerte@rol40k.local / rol40k-local-123
```

La produccion de recursos funciona con tick diario de backend, no por turno estrategico.
