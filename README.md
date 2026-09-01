# Mapa Estelar de Campaña 40K

Interfaz web privada para gestionar una campaña narrativa de Warhammer 40K con mapa estelar, recursos, comercio, movimiento, reclutamiento, tecnología y reportes de batalla.

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
- Facciones narrativas de admin: `Orcos` y `Tiranidos`, sin capital, usuario, recursos ni tropas iniciales.
- Datos mock en `src/mocks/campaign-data.ts` como fallback si Supabase no está configurado.
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
- Ambos archivos están ignorados por Git.
- En Vercel hay que configurar las variables manualmente desde la web de Vercel.

## Despliegue v1

La primera versión web se publica como campaña privada en Vercel + Supabase Cloud.

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

Para regenerar el catálogo final de unidades desde `data/11th40kPoints.txt`:

```bash
npm run units:generate
```

Para regenerar las opciones oficiales MFM de tamaños y equipo pagado sin tocar el TXT base:

```bash
npm run units:generate-options
```

Para validar la estructura declarativa de futuros árboles de tropas por facción:

```bash
npm run tech:validate-troops
```

Usuarios locales:

```text
admin@rol40k.local / Admin2000
legiones-daemonicas@rol40k.local / pollito
cultos-genestealer@rol40k.local / tattoosummum
space-marines@rol40k.local / Sombra97
adeptus-custodes@rol40k.local / Penedorado
necrones@rol40k.local / necron1996
```

Orcos y Tiranidos existen como facciones narrativas controladas desde admin, sin usuario de login propio. La facción `space-marines` se muestra como `Sombra del Emperador` en la interfaz.

La producción de recursos funciona con tick diario de backend, no por turno estratégico.

## Visión, límites y sesión

- Por defecto cada jugador ve sus sistemas, sus tropas y la información pública.
- Si una facción tiene tropas en un sistema, ve todas las tropas y edificios de ese sistema, aunque sea enemigo o está en guerra.
- En sistemas sin presencia propia, los edificios ajenos se muestran solo como slots ocupados sin revelar el edificio.
- Las tropas visibles en un sistema se agrupan como aliadas y enemigas; las enemigas se separan por facción.
- La sesión caduca a los 7 días y obliga a iniciar sesión otra vez.
- Los límites globales iniciales son 500 por recurso y 2000 puntos de ejército.
- El limite de puntos cuenta unidades vivas mas reclutamientos en cola.
- El admin puede cambiar límites de recursos y puntos desde `/admin`.
- Los jugadores pueden retirar unidades propias listas desde el panel del sistema; no hay reembolso.

## Construcciones v1

- Los sistemas tienen slots de edificio: 6 en capitales y 3 en el resto.
- El panel del sistema muestra la capacidad natural diaria; la producción real sale de edificios activos que explotan esa capacidad.
- El reclutamiento se hace clicando un edificio militar activo: Barracon, Cuartel, Taller, Nido o Cámara de Leyendas.
- El reclutamiento admite variantes oficiales MFM: tamaños legales y opciones de equipo pagadas. Si MFM trae recargos por copias repetidas, la campaña los ignora y usa siempre el coste de producir la primera copia.
- La Cámara de Leyendas recluta unidades `[Crucible]`; su tecnología existe después de Asamblea Planetaria, pero está bloqueada por ahora.
- Las unidades heridas pueden curarse desde edificios militares compatibles a mitad de coste proporcional.
- La Cámara de Comercio desbloquea el acceso al mercader y comercio estelar.
- Los edificios propios pueden destruirse sin reembolso; no se puede destruir un edificio con cola activa.
- Si el atacante conquista un sistema tras resolver una batalla, todos los edificios existentes se destruyen sin reembolso y se cancelan las colas de reclutamiento, reabastecimiento y construcción de ese sistema.
- Honor sustituye a Piedra ancestral en UI/reglas; columnas legacy pueden existir solo por compatibilidad.
- Material Industrial se produce en Planta de Fundición y se usa principalmente para construir.

## Balance económico v1

- Las unidades siempre cumplen `Suministro + 2*Mineral + 5*Honor + 5*Oro = puntos Warhammer`.
- Las unidades no cuestan Material Industrial ni Uridium; Material Industrial es para edificios y Uridium para movimiento.
- La progresión de costes sigue el árbol de tropas: infantería inicial solo Suministro, infantería avanzada con Mineral, Caracteres con más Honor, Vehículos/Aeronaves/Fortificaciones con más Mineral, y oro para unidades avanzadas, aliadas, Crucible, épicas o finales de rama.
- Aproximadamente el 40% de las plantillas de cada facción jugable cuestan oro.
- Capital + sistema neutral adyacente está balanceado para producir 19 puntos/día potenciales en recursos de reclutamiento. Material Industrial y Uridium no cuentan en ese cálculo.
- La campaña empieza sin edificios construidos: la capacidad natural existe, pero la producción real solo empieza cuando se construyen edificios activos.
- Recursos iniciales de cada facción jugable: 100 Suministro vital, 40 Mineral, 0 Honor, 0 Oro, 150 Material Industrial y 10 Uridium.
- Las capitales tienen 5 Material Industrial/día de capacidad natural y 0 Uridium. Los sistemas adyacentes tienen 0 Material Industrial y 0.3 Uridium/día.
- Los edificios básicos cuestan 20 Material Industrial, así que una capital con Planta de Fundición activa genera un edificio básico cada 4 días.
- Solo `nexus-aster` y `goregate` tienen capacidad natural de oro en el mapa final.
- La configuración vive en `data/balance/faction-balance.json`; el informe generado vive en `docs/generated/faction-balance-report.md`.
- Validación: `npm run balance:validate`.

Antes de desplegar frontend que lea estos campos, aplica migraciones Supabase incluida `0009_buildings_honor_industrial_material.sql` y después actualiza/ejecuta `supabase/production-cron.sql`.

## Movimientos, permisos y ataques

- `movement_orders` es la entidad única para desplazamientos y ataques. `movement_type = 'move'` representa movimiento logístico; `movement_type = 'attack'` representa ataque militar.
- `Mover` solo puede terminar en sistema propio o neutral. Si la ruta cruza sistemas controlados por rivales, queda en `pending_approval` y crea una fila en `movement_passage_requests` por facción propietaria atravesada.
- Las unidades seleccionadas quedan con estado `moving` mientras el movimiento está viajando o pendiente de permiso, por lo que no pueden reutilizarse en otra acción.
- Los permisos de paso se responden desde `Reportes`. Una aceptación inicia el movimiento solo cuando todas las facciones afectadas han aceptado; un rechazo cancela el movimiento y devuelve unidades y Uridium.
- `Atacar` permite cualquier origen no bloqueado donde tengas unidades propias listas, incluido territorio de otro jugador si te dejó entrar, destino enemigo y adyacencia directa. El ataque viaja exactamente 7 días calculados en Supabase y al llegar crea un conflicto pendiente sin resolver combate automáticamente.
- Las capitales no son objetivos atacables. La UI las oculta como destino y Supabase rechaza ataques normales, coaliciones, conflictos pendientes y amenazas narrativas contra capitales.
- Los límites de batalla se validan en servidor y se recargan cada 35 días: máximo 3 participaciones por ventana, máximo 2 ataques iniciados, máximo 2 ataques recibidos y máximo 3 batallas activas simultáneas.
- Las batallas entre facciones jugadoras tienen límite de 500 puntos por bando. Las batallas narrativas contra `Orcos` o `Tiranidos` quedan fuera de ese límite.
- El botón `Ver misión` abre el briefing estándar de Combat Patrol equilibrada: máximo 500 puntos por bando y misiones de combat patrol.
- Los escudos de protección vencidos no se muestran en el mapa ni en el panel del sistema.
- `resolve_movement_orders()` sigue siendo el resolver temporal central. Es idempotente para ataques porque vincula el conflicto generado con `movement_order_id`.
- Las incursiones narrativas de `Orcos` y `Tiranidos` se programan desde `/admin`: el admin elige sistema, descripción pública y días hasta llegada. Hasta que llega se muestra como amenaza entrante; al resolver, crea conflicto pendiente y bloquea el sistema como guerra.
- El admin puede crear misiones temporales controladas por `Orcos` o `Tiranidos`: aparecen como sistemas especiales conectados a un sistema normal, se colocan automáticamente en una zona libre del grafo para evitar colisiones visuales, pueden ser atacadas individualmente o en coalición, no sirven como rutas logísticas normales y pueden mostrar u ocultar una lista manual de tropas enemigas.
- Al crear una misión temporal, el admin elige cuántos días existe y si desaparece automáticamente al resolverse la batalla. El admin también puede eliminarla manualmente desde `/admin`.
- Cuando una misión temporal desaparece por expiración, resolución o eliminación, las tropas de jugadores presentes o en camino se evacuan al sistema propio más cercano que no está en batalla ni bajo ataque entrante; si no hay destino seguro quedan en `retreat_pending` para resolución admin.
- Si un sistema normal controlado por una facción narrativa pasa a una facción jugadora, se limpian sus metadatos narrativos y funciona como un sistema normal.

### Coaliciones y apoyos

- `battle_operations` representa el ciclo completo: reunión, ataque en camino, plantel cerrado, resolución y cancelación.
- Un ataque de coalición reserva las unidades del comandante, invita facciones atacantes y recibe sus tropas en el sistema de origen antes de lanzar. Esto es reunión previa, no refuerzo durante el conflicto.
- Una vez el ataque está en camino, el bando atacante no puede añadir tropas ni mover refuerzos hacia el conflicto.
- El defensor sí puede invitar apoyos mientras el ataque está en camino. Supabase calcula la ruta con el tiempo restante real y rechaza cualquier fuerza cuya llegada supere `attack_arrival_at`.
- Al llegar el ataque se congela el plantel. El sistema queda en guerra y ningún movimiento posterior puede terminar allí, aunque una ruta normal sí puede atravesarlo como sistema intermedio.
- Las unidades de apoyo conservan su planeta de origen. Tras resolver la batalla, los supervivientes regresan mediante una orden `battle_return`; si el origen ya no pertenece a su facción quedan en `return_pending`.
- El modo activo es `Campaña`: movimiento 3 días por arista, ataques 7 días hasta la batalla, producción diaria, rama `Progreso` a 30 min/2 h/6 h según coste 0/1/2, reclutamiento por potencia de unidad y construcción por coste de edificio.
- Prueba integral local: `npm run db:test:coalitions` después de `npm run db:reset` y `npm run db:seed:users`.

## Uso móvil v1

En móvil la experiencia es mapa primero:

- Al entrar se ve el mapa libre, sin sistema seleccionado.
- Tocar una estrella abre la hoja del sistema; la X cierra la hoja y devuelve al mapa.
- La barra superior muestra Suministro, Mineral, Honor, Oro, Material Industrial y Uridium como icono + número compacto, sin scroll horizontal.
- Los Componentes tecnológicos solo se ven dentro del panel de Tecnología.
- El panel `Comercio` permite usar el mercader o publicar/aceptar ofertas estelares entre facciones si la facción tiene Cámara de Comercio activa.
- Para mover tropas: seleccionar sistema, pulsar `Mover tropas`, elegir miniaturas y después `Trazar ruta en el mapa`.
- En modo ruta se toca el destino para ruta óptima, o sistemas conectados si se usa ruta manual, y se confirma desde la barra inferior.
- Reclutamiento, reportes, movimiento y tecnología usan paneles con scroll táctil real compatible con iPhone Safari y Android Chrome.
- El árbol tecnológico muestra siempre `common-v1` y, cuando exista, solo el árbol de tropas de la facción activa con convención `troops-{faction_slug}-v1`; admin puede inspeccionar una facción desde un selector.
- El árbol tecnológico usa una constelación radial simple: núcleo central de facción, círculos pequeños con iconos Lucide, ramas desde el centro y scroll nativo sin zoom ni pan custom.
- Cada árbol militar `ready` cuesta exactamente 30 Componentes tecnológicos en total. Sus nodos solo pueden costar 1, 2 o 3; el coste 3 se reserva al nodo final de las dos ramas más grandes de esa facción.
- `troops-necrones-v1` ya está implementado como primer árbol militar completo: 3 ramas asimétricas, 15 nodos de 3s, bifurcaciones/convergencias y las 55 plantillas Necron asignadas exactamente una vez. Cada nodo lista en su descripción las unidades exactas que desbloquea.
- `troops-cultos-genestealer-v1` también está implementado: 3 ramas asimétricas, 15 nodos de 3s, bifurcaciones/convergencias y las 27 plantillas del Culto asignadas exactamente una vez. Cada nodo lista en su descripción las unidades exactas que desbloquea.
- `troops-space-marines-v1` también está implementado: 3 ramas asimétricas, 15 nodos de 3s, bifurcaciones/convergencias y las 85 plantillas de Space Marines asignadas exactamente una vez. Cada nodo lista en su descripción las unidades exactas que desbloquea.
- `troops-legiones-daemonicas-v1` también está implementado: 3 ramas asimétricas, 15 nodos de 3s, bifurcaciones/convergencias y las 19 plantillas de Legiones Daemónicas asignadas exactamente una vez. Cada nodo lista en su descripción las unidades exactas que desbloquea.
- `troops-adeptus-custodes-v1` también está implementado: 3 ramas asimétricas, 15 nodos de 3s, bifurcaciones/convergencias y las 51 plantillas de Adeptus Custodes asignadas exactamente una vez. Cada nodo lista en su descripción las unidades exactas que desbloquea.
- Antes de desplegar cambios de UI móvil hay que probar al menos iPhone Safari y Android Chrome, verificando que todos los paneles scrollean hasta el final y que los botones no quedan bajo la barra del navegador.
