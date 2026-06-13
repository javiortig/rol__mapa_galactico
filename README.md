# Mapa Estelar de Campana 40K

Interfaz web privada para gestionar una campana narrativa de Warhammer 40K con mapa estelar, recursos, comercio, movimiento, reclutamiento, tecnologia y reportes de batalla.

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

## Vision, limites y sesion

- Por defecto cada jugador ve sus sistemas, sus tropas y la informacion publica.
- Si una faccion tiene tropas en un sistema, ve todas las tropas y edificios de ese sistema, aunque sea enemigo o este en guerra.
- En sistemas sin presencia propia, los edificios ajenos se muestran solo como slots ocupados sin revelar el edificio.
- Las tropas visibles en un sistema se agrupan como aliadas y enemigas; las enemigas se separan por faccion.
- La sesion caduca a los 7 dias y obliga a iniciar sesion otra vez.
- Los limites globales iniciales son 500 por recurso y 1000 puntos de ejercito.
- El limite de puntos cuenta unidades vivas mas reclutamientos en cola.
- El admin puede cambiar limites de recursos y puntos desde `/admin`.
- Los jugadores pueden retirar unidades propias listas desde el panel del sistema; no hay reembolso.

## Construcciones v1

- Los sistemas tienen slots de edificio: 6 en capitales y 3 en el resto.
- La produccion diaria sale de edificios activos, no de valores planetarios manuales.
- El reclutamiento se hace clicando un edificio militar activo: Barracon, Cuartel, Taller o Nido.
- Las unidades heridas pueden curarse desde edificios militares compatibles a mitad de coste proporcional.
- La Camara de Comercio desbloquea el acceso al mercader y comercio estelar.
- Honor sustituye a Piedra ancestral en UI/reglas; columnas legacy pueden existir solo por compatibilidad.
- Material Industrial se produce en Planta de Fundicion y se usa principalmente para construir.

Antes de desplegar frontend que lea estos campos, aplica migraciones Supabase incluida `0009_buildings_honor_industrial_material.sql` y despues actualiza/ejecuta `supabase/production-cron.sql`.

## Uso movil v1

En movil la experiencia es mapa primero:

- Al entrar se ve el mapa libre, sin sistema seleccionado.
- Tocar una estrella abre la hoja del sistema; la X cierra la hoja y devuelve al mapa.
- La barra superior muestra Suministro, Mineral, Honor, Oro, Material Industrial y Uridium como icono + numero compacto, sin scroll horizontal.
- Los Componentes tecnologicos solo se ven dentro del panel de Tecnologia.
- El panel `Comercio` permite usar el mercader o publicar/aceptar ofertas estelares entre facciones si la faccion tiene Camara de Comercio activa.
- Para mover tropas: seleccionar sistema, pulsar `Mover tropas`, elegir miniaturas y despues `Trazar ruta en el mapa`.
- En modo ruta se toca el destino para ruta optima, o sistemas conectados si se usa ruta manual, y se confirma desde la barra inferior.
- Reclutamiento, reportes, movimiento y tecnologia usan paneles con scroll tactil real compatible con iPhone Safari y Android Chrome.
- El arbol tecnologico usa una constelacion radial simple: nucleo central de faccion, circulos pequenos con iconos Lucide, ramas desde el centro y scroll nativo sin zoom ni pan custom.
- Antes de desplegar cambios de UI movil hay que probar al menos iPhone Safari y Android Chrome, verificando que todos los paneles scrollean hasta el final y que los botones no quedan bajo la barra del navegador.
