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

### Entornos local y cloud

- `.env.local` se usa para probar en local. Para regenerarlo con Supabase local:

```bash
npm run supabase:start
npm run db:sync-env
```

- `.env.cloud.local` queda como copia privada de las claves cloud para consultarlas o copiarlas a Vercel.
- Ambos archivos estan ignorados por Git.
- En Vercel hay que configurar las variables manualmente desde la web de Vercel.

## Despliegue v1

La primera version web se publica como campana privada en Vercel + Supabase Cloud.

1. Crear un proyecto Supabase Cloud.
2. Vincular el proyecto local:

```bash
npx supabase link
npm run db:push:prod
```

3. Sembrar usuarios contra Supabase Cloud usando `SUPABASE_SERVICE_ROLE_KEY` del proyecto cloud:

```bash
SUPABASE_URL=https://tu-proyecto.supabase.co SUPABASE_SERVICE_ROLE_KEY=... npm run db:seed:users
```

En PowerShell:

```powershell
$env:SUPABASE_URL="https://tu-proyecto.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="..."
npm run db:seed:users
```

4. Ejecutar `supabase/production-cron.sql` en Supabase SQL Editor para programar resolvers cada minuto.
5. Importar el repositorio GitHub en Vercel y configurar:

```text
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
NEXT_PUBLIC_SITE_URL=https://tu-app.vercel.app
NEXT_PUBLIC_ALLOW_MOCK_FALLBACK=false
```

6. En Supabase Auth, configurar Site URL con la URL de Vercel y permitir `http://localhost:3000/**` para desarrollo.
7. Validar antes de publicar:

```bash
npm run deploy:check
```

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

## Uso movil v1

En movil la experiencia es mapa primero:

- Al entrar se ve el mapa libre, sin sistema seleccionado.
- Tocar una estrella abre la hoja del sistema; la X cierra la hoja y devuelve al mapa.
- La barra superior muestra los 5 recursos como icono + numero compacto, sin scroll horizontal.
- Para mover tropas: seleccionar sistema, pulsar `Mover tropas`, elegir miniaturas y despues `Trazar ruta en el mapa`.
- En modo ruta se toca el destino para ruta optima, o sistemas conectados si se usa ruta manual, y se confirma desde la barra inferior.
- Reclutamiento y tecnologia usan modales/drawers a pantalla completa para que los botones principales queden accesibles con el pulgar.
