# Especificación del proyecto: Mapa Estelar de Campaña Warhammer 40K

## Arranque local de esta versión

Esta versión del proyecto usa **Next.js** para la web y **Supabase local/Postgres** como base de datos real de desarrollo.

Requisitos previos:

- Tener Docker Desktop abierto.
- Tener Node.js instalado.
- Ejecutar los comandos desde la carpeta raíz del proyecto:

```bash
cd "c:\Users\soyun\Desktop\rol 40k"
```

Abrir docker

Primer arranque o arranque después de clonar el proyecto:

```bash
npm install
npm run supabase:start
npm run db:sync-env
npm run db:reset
npm run db:seed:users
npm run dev
```

Arranque normal si la base ya está preparada:

```bash
npm run supabase:start
npm run dev
```

Si se cambian migraciones o `supabase/seed.sql`, resetear la base local:

```bash
npm run db:reset
npm run db:seed:users
```

Aviso: `npm run db:reset` borra y recrea la base local. Es correcto para desarrollo, pero elimina cambios manuales hechos en Studio.

Entornos:

- `.env.local` debe apuntar al Supabase local para testear en este ordenador.
- Para regenerarlo, usar:

```bash
npm run supabase:start
npm run db:sync-env
```

- `.env.cloud.local` guarda una copia privada de las claves cloud para consultarlas o copiarlas a Vercel.
- `.env.local` y `.env.cloud.local` no se suben a GitHub.

URLs locales:

```text
Web: http://localhost:3000
Supabase API: http://127.0.0.1:54321
Supabase Studio: http://127.0.0.1:54323
Base de datos: postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

Usuarios locales de prueba:

```text
admin@rol40k.local / admin-local-123
orcos@rol40k.local / rol40k-local-123
necrones@rol40k.local / rol40k-local-123
guardia-imperial@rol40k.local / rol40k-local-123
culto-genestelar@rol40k.local / rol40k-local-123
sombra-emperador@rol40k.local / rol40k-local-123
guardia-muerte@rol40k.local / rol40k-local-123
```

Si aparece un error de refresh token después de resetear Supabase, entrar de nuevo desde `/login`. Si el navegador conserva una sesión antigua, cerrar sesión o borrar el almacenamiento local del sitio.

---

## Publicacion web de esta version

La primera publicacion se hara como campana privada en **Vercel + Supabase Cloud**, usando inicialmente la URL generada por Vercel.

Flujo de publicacion:

```bash
npm run deploy:check
npx supabase link
npm run db:push:prod
```

Despues de aplicar migraciones y seed en Supabase Cloud:

- Sembrar usuarios con `npm run db:seed:users` usando `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` del proyecto cloud.
- Ejecutar el archivo `supabase/production-cron.sql` en el SQL Editor de Supabase Cloud.
- Importar el repositorio GitHub en Vercel.
- Configurar en Vercel:

```text
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
NEXT_PUBLIC_SITE_URL=https://tu-app.vercel.app
NEXT_PUBLIC_ALLOW_MOCK_FALLBACK=false
```

En PowerShell, para sembrar usuarios cloud:

```powershell
$env:SUPABASE_URL="https://tu-proyecto.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="..."
npm run db:seed:users
```

En produccion `NEXT_PUBLIC_ALLOW_MOCK_FALLBACK=false` es obligatorio para que la web no muestre datos mock si Supabase falla o si no hay sesion.

Configurar en Supabase Auth:

- Site URL: URL final de Vercel.
- Redirect URL de desarrollo: `http://localhost:3000/**`.
- Redirect URL de previews Vercel si se usan ramas de preview.

La version movil debe ser completamente utilizable: mapa tactil, panel de sistema como hoja inferior, barra de mando inferior, modales a pantalla completa y controles sin depender de hover.

Navegacion movil actual:

- La campana entra en modo mapa primero: no hay sistema seleccionado al cargar.
- Tocar una estrella abre la hoja del sistema; cerrar con X vuelve al mapa libre.
- La barra de recursos superior debe caber completa, con icono y numero compacto para los 6 recursos visibles: Suministro, Mineral, Honor, Oro, Material Industrial y Uridium.
- El movimiento movil funciona en dos fases: seleccion de unidades desde el sistema y trazado de ruta en el mapa.
- Al trazar ruta, el panel de sistema se cierra y queda una barra inferior con coste de Uridium, tiempo, cancelar, deshacer, reiniciar y confirmar.
- Tecnologia abre la constelacion a pantalla completa centrada en `fundacion-planetaria`, sin nodo seleccionado; tocar un nodo abre el detalle como drawer inferior.
- Reclutamiento, reportes, movimiento y tecnologia usan paneles con scroll tactil real compatible con iPhone Safari y Android Chrome.
- Cualquier cambio de UI movil debe probarse en iPhone Safari y Android Chrome, verificando que los paneles scrollean hasta el final y que los botones principales no quedan bajo las barras del navegador.

---

## Estado actual implementado para agentes IA

Ultima auditoria del documento: 2026-06-10. Esta seccion consolida el estado actual para que otro agente pueda orientarse rapido.

Estado tecnico actual:

- Proyecto Next.js + React + TypeScript con App Router.
- Mapa galactico WebGL en PixiJS.
- UI con Tailwind CSS y componentes locales.
- Estado local de mapa/UI con Zustand.
- Server state con TanStack Query.
- Backend autoritativo en Supabase/Postgres/Auth/RLS/RPC.
- Supabase local para desarrollo y Supabase Cloud + Vercel para produccion.
- Mocks siguen existiendo como fallback de desarrollo, pero produccion debe usar `NEXT_PUBLIC_ALLOW_MOCK_FALLBACK=false`.

Estado jugable actual:

- Campana en tiempo real, sin turnos estrategicos.
- Produccion diaria por tick temporal configurable, calculada desde edificios activos.
- Movimiento, reclutamiento e investigacion funcionan por timestamps y resolvers backend/lazy processing.
- Unidades jugables son `campaign_units`, no ejercitos abstractos.
- Las unidades tienen miniaturas actuales, miniaturas iniciales y heridas agregadas; no pueden separarse al mover.
- Construccion planetaria con slots por sistema: 6 en capitales y 3 en el resto.
- Reclutamiento desde edificios militares activos, no desde un boton global de capital.
- Reclutamiento usa `unit_templates`, costes, tiempos, cola, edificios compatibles y validacion tecnologica.
- Reabastecimiento completo de unidades danadas desde edificios militares compatibles a mitad del coste completo de la unidad.
- Cancelar reclutamiento, reabastecimiento o movimiento devuelve el 50% de los recursos gastados, redondeando hacia arriba.
- Arbol tecnologico comun `common-v1` con progreso independiente por faccion. Incluye rama `Progreso` funcional, rama `Inteligencia` visible pero bloqueada como contenido futuro, y una rama militar temporal para desbloqueos de unidades.
- Oro es un recurso principal visible en la barra superior y se usa sobre todo para comercio.
- Material Industrial es un recurso visible y comerciable usado principalmente para construccion.
- Componentes tecnologicos son un recurso especial del arbol tecnologico; no aparecen en la barra superior y no se producen en planetas ni por edificios de produccion.
- Honor sustituye a Piedra ancestral como recurso especial visible; las columnas SQL legacy `ancestral_stone` pueden existir temporalmente solo por compatibilidad de migraciones.
- El panel de mando operativo tiene entrada `Comercio`, no `Recursos`; abre Mercader y Comercio estelar.
- Batallas se juegan fuera de la app; la web gestiona conflicto, bloqueo, reportes, supervivientes, heridas restantes y control final.
- Comercio estelar usa reserva de recursos: publicar una oferta inmoviliza el recurso/oro y su comision; al aceptar solo se valida el coste del aceptante.
- Sistemas gaseosos compartidos: `Nexus Aster` y `Ashen Road` son no conquistables, no generan batalla al llegar y permiten coexistencia de facciones.

Estado visual actual:

- El mapa inicial tiene 30 sistemas, capitales en bordes del grafo, territorios iniciales contiguos, movimientos iniciales y 3 conflictos de prueba.
- Las aristas no muestran numeros por defecto; el coste de Uridium aparece en el flujo de movimiento.
- Si una arista no esta bloqueada y une dos sistemas controlados por la misma faccion, se colorea con el color de esa faccion.
- La animacion direccional de aristas se reserva solo para movimientos reales visibles para el usuario o admin.
- Capitales no tienen animacion ni marcador especial en el mapa; se distinguen en datos y panel.
- Sistemas con `specialObjects` publicos muestran un pequeno diamante/marcador bajo la estrella.
- La barra superior de recursos esta centrada y compacta; en movil muestra icono + numero.

Estado movil actual:

- En movil la experiencia es mapa primero.
- El panel de sistema no se abre al cargar; se abre solo al tocar una estrella.
- Al tocar una estrella en movil se aplica un bloqueo tactil muy corto para evitar tap fantasma/click-through sobre botones del panel recien abierto.
- El dock inferior se oculta cuando hay panel de sistema, movimiento, reclutamiento, tecnologia o reporte abierto.
- La app usa `--app-height` calculado con `visualViewport` para Safari iOS.
- Paneles largos usan scroll tactil real mediante clase `mobile-scroll`.
- El arbol tecnologico usa `tech-scroll`, abre centrado en `fundacion-planetaria`, sin nodo seleccionado, con zoom inicial reducido y controles de zoom/centrado.

Archivos clave actuales:

- `src/features/campaign/components/campaign-shell.tsx`: shell principal, recursos, panel sistema, movimiento y reportes.
- `src/features/galaxy-map/components/galaxy-map.tsx`: render PixiJS del mapa, rutas, sistemas, marcadores, movimientos y efectos.
- `src/features/buildings/components/construction-modal.tsx`: construccion de edificios.
- `src/features/buildings/components/building-action-modal.tsx`: acciones de edificio, reclutamiento, curacion, cola y placeholders.
- `src/features/recruitment/components/recruitment-modal.tsx`: componente legacy/fallback; el flujo principal actual recluta desde edificios.
- `src/features/technology/components/technology-tree-modal.tsx`: arbol tecnologico tipo constelacion.
- `src/lib/use-media-query.ts`: media queries cliente y `useViewportHeightCssVar`.
- `supabase/migrations`: esquema/RLS/RPCs.
- `supabase/seed.sql`: estado inicial jugable.
- `scripts/seed-local-users.mjs`: usuarios locales/cloud de prueba mediante service role.

Comprobaciones obligatorias antes de entregar cambios:

```bash
npm run typecheck
npm run lint
npm run build
```

Para cambios moviles, probar ademas en Android Chrome e iPhone Safari. En iPhone hay que validar especificamente scroll hasta el final en sistema, reclutamiento, movimiento, reportes y tecnologia.

---

## 0. Contexto general

Este documento describe una aplicación web privada para gestionar una campaña narrativa de Warhammer 40K entre amigos.

La web debe funcionar como un **mapa estelar interactivo de campaña**, con estética de videojuego/estrategia espacial. La aplicación no será comercial, no se publicará como producto ni usará monetización. Es una herramienta privada para una campaña entre jugadores.

La idea principal es que varios jugadores, cada uno asociado a una **facción**, compitan por controlar sistemas estelares conectados entre sí por rutas. Cada sistema conquistado produce recursos. Los jugadores gastan esos recursos para reclutar tropas, mover unidades Warhammer y disputar nuevos sistemas mediante partidas reales de Warhammer 40K.

La web no tiene que simular las reglas de combate de Warhammer 40K. Las batallas se juegan fuera de la aplicación, usando el juego físico normal. La web solo gestiona:

- Mapa estelar.
- Control territorial.
- Recursos.
- Reclutamiento.
- Movimiento.
- Cronos.
- Misiones narrativas.
- Información pública/oculta.
- Panel de administración.

---

## 1. Objetivo del proyecto

Crear una aplicación web privada con:

1. **Login por jugador/facción.**
2. **Mapa galáctico interactivo**, visualmente bonito y espacial.
3. **Sistemas estelares representados como nodos abstractos/tácticos**, no como planetas grandes.
4. **Rutas entre sistemas**, con coste de movimiento en Uridium.
5. **Panel lateral/modal de sistema** al seleccionar un nodo.
6. **Recursos por facción**:
   - Suministro vital.
   - Mineral.
   - Honor.
   - Oro.
   - Material Industrial.
   - Uridium.
   - Componentes tecnológicos.
7. **Produccion de recursos por edificios activos en sistemas controlados.**
8. **Movimiento de tropas entre sistemas.**
9. **Construccion de edificios con slots y cola temporizada.**
10. **Reclutamiento de tropas desde edificios militares con cola temporizada estilo Grepolis.**
11. **Tropas reclutadas aparecen en el sistema del edificio.**
12. **Arbol tecnologico por faccion**, con desbloqueo de unidades, edificios y bonos.
13. **Misiones narrativas asociadas a sistemas**, con imagen del mapa de mision y explicacion.
14. **Niebla de guerra para tropas y movimientos.**
15. **Panel de admin para resolver resultados, editar mapas, recursos, tropas, experiencia y bloqueos.**
16. **Backend autoritativo**: las reglas criticas nunca deben depender solo del frontend.
17. **Cronos gestionados por backend** para produccion, construccion, movimiento, reclutamiento, curacion e investigacion.

---

## 2. Stack tecnológico recomendado

### 2.1 Frontend

Usar:

- **Next.js**
- **React**
- **TypeScript**
- **Tailwind CSS**
- **shadcn/ui** o componentes propios estilizados
- **PixiJS** para el mapa galáctico
- **Zustand** para estado local de UI/mapa
- **TanStack Query** o equivalente para server state/cache

Motivo:

- Next.js permite estructurar la app, login, rutas, paneles y vistas.
- React sirve para los paneles, modales y menús.
- PixiJS da un mapa WebGL visualmente rico, con animaciones, partículas, glow y buena interacción.
- Tailwind permite construir UI rápida con estética consistente.
- Zustand ayuda a gestionar estado local como sistema seleccionado, modo movimiento, ruta activa, etc.
- TanStack Query ayuda con datos remotos, cache, invalidación y sincronización.

### 2.2 Backend

Usar preferiblemente:

- **Supabase**
  - PostgreSQL
  - Supabase Auth
  - Row Level Security
  - Realtime
  - Storage
  - Edge Functions o RPC SQL
  - Cron / pg_cron

Motivo:

- PostgreSQL encaja muy bien con facciones, sistemas, rutas, recursos, unidades, órdenes y colas.
- Supabase Auth simplifica login por jugador.
- RLS permite controlar qué ve o modifica cada usuario.
- Realtime permite actualizar frontend cuando cambian movimientos, recursos, colas, etc.
- Storage permite guardar imágenes de misiones narrativas y assets subidos por admin.
- Cron permite resolver producción, órdenes temporizadas y colas.

### 2.3 Principio técnico central

**El frontend nunca debe decidir si una acción es válida.**

El frontend puede mostrar posibilidades, pero el backend debe validar todo:

- Si el jugador puede mover esas unidades.
- Si tiene Uridium.
- Si la ruta existe.
- Si el sistema no está bloqueado.
- Si las unidades no están en guerra o moviéndose.
- Si el jugador es dueño de la facción.
- Si la cola de reclutamiento es válida.
- Si los recursos alcanzan.
- Si la tecnología requerida para una unidad está desbloqueada.
- Si la facción puede iniciar una investigación tecnológica.
- Si el sistema de destino permite la acción.

---

## 3. Dirección visual

### 3.1 Estética general

La web debe parecer una interfaz de campaña galáctica de videojuego:

- Grimdark espacial.
- Holograma táctico.
- UI de estrategia.
- Fondo oscuro.
- Efectos de glow.
- Nebulosas sutiles.
- Estrellas animadas.
- Paneles semitransparentes.
- Colores de facción.
- Animaciones suaves.
- Nada de aspecto cutre o excesivamente web/plano.

La app debe sentirse más como una interfaz de juego que como un dashboard empresarial.

### 3.2 Arte y assets

Los iconos de recursos, reliquias, tecnología, etc. pueden venir de packs como CraftPix.

Sin embargo, el **mapa galáctico** no debe basarse en assets cerrados de mapas ya hechos. Debe generarse en código con PixiJS.

Usar assets para:

- Iconos de recursos.
- Iconos de reliquias.
- Iconos de tecnología.
- Paneles/modales si encajan.
- Botones o marcos sci-fi.
- Fondos espaciales sutiles.
- Texturas de nebulosa o partículas si hacen falta.

Generar con código:

- Sistemas.
- Halos.
- Anillos.
- Rutas.
- Líneas.
- Selección.
- Movimiento.
- Pulsos de guerra.
- Bloqueos.
- Colores de facción.
- Niebla visual.
- Partículas de fondo.

### 3.3 Sistemas del mapa galáctico

Los sistemas NO se representarán como planetas grandes. Se representarán como nodos tácticos abstractos:

#### Sistema normal

- Punto luminoso central.
- Halo suave.
- Anillo exterior pequeño.
- Nombre visible en hover o según zoom.

#### Sistema controlado

- Anillo exterior con color de la facción controladora.
- Ligero glow del color de la facción.

#### Capital

- En el mapa se representa visualmente como cualquier otro sistema controlado.
- La condicion de capital se mantiene en datos y paneles para reclutamiento, pero no debe anadir animaciones, iconos o marcadores especiales sobre el nodo.

#### Sistema en guerra

- Pulso rojo.
- Icono de conflicto.
- Glow rojo temporal.
- Rutas cercanas con tensión visual.

#### Sistema bloqueado

- Icono pequeño de candado o escudo.
- Borde ámbar.
- Panel muestra tiempo restante de bloqueo.

#### Sistema con recurso especial/reliquia avistada

- Icono pequeño flotante.
- Brillo diferenciado, por ejemplo violeta para Honor o dorado/violeta para reliquia.

Nota implementada: en el mapa actual, si un sistema tiene algun `specialObjects` publico, PixiJS dibuja un pequeno diamante bajo la estrella. Ese diamante significa objeto especial, reliquia, anomalia o punto narrativo publico; no representa control, capital, bloqueo ni tropas.

### 3.4 Rutas/aristas

Las rutas entre sistemas se dibujan con PixiJS:

#### Ruta normal

- Línea azul/cian tenue.
- Ligero glow.
- Si la ruta no esta bloqueada y une dos sistemas controlados por la misma faccion, se dibuja con el color de esa faccion.
- El color de bloqueo siempre tiene prioridad sobre el color de faccion.

#### Ruta de mayor coste

- Mantiene el mismo grosor base que el resto de rutas.
- No muestra numeros de coste de forma permanente.
- El coste de Uridium aparece solo cuando el jugador esta preparando un movimiento o inspecciona la ruta desde una UI especifica.

#### Ruta bloqueada por evento

- Línea apagada, roja o discontinua.
- No se puede usar.

#### Ruta seleccionada

- Línea brillante.
- Realce estatico o pulso suave, sin sugerir direccion.

#### Movimiento de tropas

- Pequeña partícula, icono o marcador viajando de origen a destino.
- Solo visible para el jugador dueño de la tropa y admin, salvo que más adelante haya espionaje.
- La animacion direccional se reserva exclusivamente para `movement_orders` reales en estado `moving` que el usuario tenga permiso de ver.

### 3.5 Estado inicial del mapa

El seed local inicial debe representar una campana viva, no un reparto aleatorio:

- El mapa empieza con 30 sistemas.
- Cada faccion tiene capital en un borde dificil de alcanzar del grafo.
- Cada faccion controla 3 sistemas contiguos: capital, retaguardia y frontera.
- El centro del grafo permanece neutral y disputado.
- Existen corredores reconocibles desde cada capital hacia el centro.
- Hay 3 conflictos iniciales en sistemas neutrales fronterizos:
  - Orcos contra Guardia Imperial en `azur-trench`.
  - Guardia de la Muerte contra Necrones en `ossuary-reach`.
  - Sombra del Emperador contra Culto Genestelar en `saint-veil`.
- Los sistemas con conflicto inicial estan en estado `war`, bloqueados y pendientes de reporte de batalla fisica.
- Cada faccion empieza con unidades en capital, unidades de frontera, fuerza movil y presencia en el conflicto que le corresponde.
- Las ordenes de movimiento iniciales son visibles solo para la faccion propietaria y para admin.

---

## 4. Recursos de campaña

Hay seis recursos visibles de campaña y un recurso tecnológico especial:

| Recurso | Uso |
|---|---|
| Suministro vital | Reclutar y sostener tropas, especialmente infantería y presencia militar. |
| Mineral | Armamento, blindajes, vehículos, fortificaciones y equipamiento pesado. |
| Honor | Recurso especial para personajes, élites, monstruos importantes, dreadnoughts, reliquias y efectos narrativos. Sustituye completamente a Piedra ancestral en producto, UI y reglas. |
| Oro | Recurso económico usado principalmente para comercio. También puede usarse puntualmente en unidades de élite muy concretas. |
| Material Industrial | Recurso de construcción producido por edificios. También es comerciable. |
| Uridium | Recurso de movimiento estratégico entre sistemas. |
| Componentes tecnológicos | Recurso especial solo del árbol tecnológico. No se muestra en la barra superior y no se produce en planetas. |

Más adelante se añadirán recursos secundarios, como reliquias, enhancements narrativos, objetos especiales, intel/espionaje y otros recursos narrativos.

### 4.1 Conversión inicial a puntos

La conversión para coste de unidades será:

| Recurso | Valor equivalente |
|---|---:|
| 1 Suministro vital | 1 punto |
| 1 Mineral | 2 puntos |
| 1 Uridium | 2 puntos |
| 1 Honor | 5 puntos |
| 1 Oro | 5 puntos |

Fórmula:

```text
Coste en puntos = Suministro + 2*Mineral + 5*Honor + 5*Oro
```

Uridium equivale a 2 puntos a efectos económicos/comerciales, pero no se usa para generar tropas normales. Material Industrial no tiene conversión a puntos de ejército en v1; sirve principalmente para construcción.

### 4.2 Uso de Honor

Honor debe ser raro y usarse para:

- Personajes.
- Élites.
- Unidades especiales.
- Dreadnoughts.
- Superpesados.
- Monstruos importantes.
- Unidades icónicas.
- Reliquias.
- Desbloqueos narrativos.

No todas las unidades básicas deben costar Honor. Honor se genera mediante el edificio `Monumento` y no es comerciable ni con el mercader ni entre jugadores.

Nota técnica: las columnas SQL legacy `ancestral_stone` y `ancestral_stone_cost` pueden seguir existiendo temporalmente para despliegues seguros en cloud, pero no deben usarse como contrato nuevo. El frontend debe mapear valores legacy a `honor` solo como compatibilidad.

### 4.3 Producción

La producción diaria real ya no sale de producción planetaria manual. Sale de edificios activos construidos en sistemas controlados:

- `Granja Biológica` -> Suministro vital.
- `Complejo Minero` -> Mineral.
- `Refinería de Iridium` -> Uridium.
- `Mina de Oro` -> Oro.
- `Planta de Fundición` -> Material Industrial.
- `Monumento` -> Honor.

En base de datos, `system_production` queda como proyección visible/derivada de edificios activos, no como fuente de verdad manual. El resolver `refresh_system_production_from_buildings()` reconstruye esos valores desde `system_buildings`.

Los Componentes tecnológicos no se producen en planetas, sistemas ni edificios de producción.

La producción diaria total de una facción es la suma de los edificios de producción activos en sistemas que controla. La cadencia de usuario para la v1 es diaria:

```text
24 horas
```

El admin podrá cambiar esta cadencia más adelante si la campaña necesita avanzar más rápido o más lento.

El panel superior debe mostrar solo los recursos visibles, centrados y sin texto de siguiente tick:

```text
Suministro vital | Mineral | Honor | Oro | Material Industrial | Uridium
```

Los Componentes tecnológicos no aparecen en la barra superior. Solo se muestran dentro del panel/árbol de tecnologías.

El panel de sistema debe mostrar producción diaria derivada de sus edificios activos.

### 4.4 Componentes tecnológicos

Los Componentes tecnológicos son un recurso especial de la campaña.

Uso principal:

- Pagar investigaciones del árbol tecnológico.
- Representar piezas de arqueotecnología, datos tácticos, núcleos de cogitador y conocimiento industrial recuperado.
- Desbloquear nuevas unidades reclutables, edificios futuros y bonos pasivos.

Reglas v1:

- El campo interno del recurso es `technology`.
- El icono visual es `icons/resources/tech_component.png`.
- Los costes tecnológicos se pagan en `start_technology_research()`.
- No se gastan directamente al reclutar unidades normales.
- No se producen mediante `system_production` ni ticks diarios de recursos.
- Deben obtenerse mediante recompensas narrativas, reliquias, eventos, misiones, hallazgos, comercio futuro o edición/admin.
- El backend valida siempre que la tecnología necesaria esté desbloqueada antes de permitir `recruit_unit_at_building()`.

### 4.5 Oro y comercio

El Oro es un recurso principal visible en la barra superior.

Uso principal:

- Comerciar con el mercader.
- Comerciar con otros jugadores.
- Pagar costes puntuales de unidades de élite muy concretas.

Reglas de valor económico:

- 1 Oro equivale a 5 puntos.
- 1 Uridium equivale a 2 puntos, aunque no se usa para generar tropas normales.
- Los Componentes tecnológicos no son comerciables en v1.

#### Mercader

El panel de mando operativo muestra `Comercio` en lugar de `Recursos`.

Al abrir comercio, la pestaña por defecto es `Mercader`.

El mercader:

- Usa el avatar `icons/resources/merchant1.png`.
- Permite comprar y vender `supply`, `minerals`, `industrialMaterial` y `uridium`.
- No comercia Honor ni Componentes tecnológicos.
- Requiere que la facción tenga al menos una `Cámara de Comercio` activa.
- Requiere tecnologia `Contactos Economicos` para operar.
- Vende recursos al doble de su valor por defecto.
- Compra recursos a mitad de precio por defecto, redondeando hacia arriba.
- Con `Tratos Preferentes`, vende a 1.5x y compra a 0.75x del valor.

Ejemplos de fórmulas:

```text
Compra al mercader = ceil(valor_puntos_recurso * cantidad * multiplicador_compra / 5) Oro
Venta al mercader = ceil(valor_puntos_recurso * cantidad * multiplicador_venta / 5) Oro
```

#### Comercio estelar entre jugadores

El comercio entre jugadores usa ofertas abiertas de recurso contra Oro:

- Oferta de compra: "Compro X de recurso por Y de Oro".
- Oferta de venta: "Vendo X de recurso por Y de Oro".
- Recursos comerciables: Suministro, Mineral, Material Industrial y Uridium.
- No se comercia Oro como recurso objetivo; Oro es la moneda.
- No se comercian Honor ni Componentes tecnológicos.
- Requiere que la facción tenga al menos una `Cámara de Comercio` activa.
- Requiere tecnologia `Mercado Galactico`.
- Cada transacción cobra una comisión del 30% del Oro de la oferta, redondeada hacia arriba.
- Cada jugador paga su propia comisión en Oro.
- Con `Aranceles Privilegiados`, la comision propia baja al 10%, minimo 1 Oro.

Regla vigente: el comercio estelar reserva recursos al publicar.

- Oferta de compra: el creador reserva `gold_amount + fee_gold`.
- Oferta de venta: el creador reserva `resource_amount` y `fee_gold`.
- Al cancelar una oferta propia abierta, se devuelve toda la reserva.
- Al aceptar, el aceptante paga su coste y su propia comision; el creador no vuelve a validar recursos porque ya los tenia reservados.
- Cualquier texto anterior que diga que las ofertas no reservan recursos queda obsoleto.

Texto legacy obsoleto: antes las ofertas no reservaban recursos; ya no debe implementarse asi.

---

## 5. Tiempo real de campaña

La campaña no usa turnos estratégicos.

Todo el avance importante funciona por tiempo real gestionado por backend:

- Producción de recursos.
- Reclutamiento.
- Movimiento.
- Investigación tecnológica.
- Bloqueos de sistemas.
- Resolución de colas vencidas.

### 5.1 Cronos automáticos

Los cronos deben ser gestionados por backend con timestamps reales:

- `started_at`
- `finishes_at`
- `arrival_at`
- `last_resource_tick_at`
- `next_resource_tick_at`
- `unlocked_at`
- `status`

El frontend solo muestra cuenta atrás.

### 5.2 Producción diaria

El backend ejecuta un tick de producción cada 24 horas en la v1.

Valor inicial recomendado:

```text
24 horas
```

En cada tick:

1. Se completa cualquier construcción vencida.
2. Se calcula producción desde edificios activos de todos los sistemas controlados.
3. Se suma producción a cada facción.
4. Se registra un log de producción.
5. Se actualizan los paneles de recursos.
6. Se actualizan bloqueos vencidos si aplica.

La producción debe poder resolverse mediante cron y también mediante lazy processing al cargar la app o paneles importantes.

### 5.3 Resolución temporal por backend

El backend debe exponer funciones seguras para procesar tiempo vencido:

```text
resolve_resource_ticks()
resolve_building_construction()
resolve_movement_orders()
resolve_recruitment_queue()
resolve_unit_recovery_queue()
resolve_technology_research()
```

Así, aunque un cron se retrase, el estado se corrige cuando alguien entra a la campaña o ejecuta una acción importante.

---

## 6. Sistemas estelares

### 6.1 Estados base

Cada sistema tiene uno de estos estados:

```text
neutral
controlled
war
```

Significado:

| Estado | Significado |
|---|---|
| neutral | Nadie controla el sistema. |
| controlled | Una facción controla el sistema. |
| war | El sistema está en guerra o tiene conflicto pendiente. |

### 6.2 Bloqueo temporal

Además del estado, un sistema puede tener:

```text
blocked_until
```

Esto significa que el sistema no puede ser atacado hasta esa fecha/hora.

Ejemplo:

```text
Estado: controlled
Controlador: T'au
blocked_until: 2026-06-02T18:00:00
```

El sistema sigue siendo controlado, pero temporalmente no atacable.

Visualmente:

- Candado.
- Borde ámbar.
- Tooltip con tiempo restante.
- Panel del sistema muestra "Bloqueado durante X días/horas".
- Si `blocked_until` ya ha vencido, la UI debe mostrar `Expirado` y el marcador visual pasa a un estado gris/apagado.

### 6.3 Reglas del bloqueo

Por ahora:

- Un sistema con batalla pendiente queda bloqueado.
- La duración estándar del bloqueo inicial de batalla es de 14 días (`conflict_block_duration_minutes = 20160`).
- Durante el bloqueo no puede ser atacado.
- Puede seguir mostrando su controlador públicamente.
- El bloqueo puede mantenerse hasta que los jugadores participantes o el admin reporten el resultado.
- El admin puede definir una duración adicional de bloqueo después de resolver la batalla.
- Puede producir recursos si se decide así.
- Se puede permitir mover tropas propias dentro/fuera, salvo que el admin lo bloquee manualmente.

### 6.4 Información pública

La información pública de un sistema incluye:

- Nombre.
- Estado.
- Controlador.
- Producción del sistema.
- Tipo de sistema.
- Si está bloqueado.
- Tiempo restante de bloqueo.
- Recursos especiales avistados si están marcados como públicos.
- Misión narrativa principal si existe.

### 6.5 Información privada / niebla de guerra

La información oculta incluye:

- Tropas presentes enemigas.
- Movimientos enemigos.
- Tropas reclutadas por otros jugadores.
- Colas de producción enemigas.
- Tropas exactas en sistemas controlados por otros.
- Objetos secretos no revelados.
- Notas privadas de admin.

Más adelante puede añadirse un sistema de espionaje para revelar parte de esta información.

---

## 7. Panel del sistema

Al hacer click en un sistema, se abre un panel lateral o modal.

### 7.1 Contenido mínimo

Debe mostrar:

- Nombre del sistema.
- Tipo de sistema.
- Estado:
  - Neutral.
  - Controlado.
  - En guerra.
- Controlador actual, si existe.
- Bloqueo temporal, si existe.
- Producción:
  - Suministro vital.
  - Mineral.
  - Honor.
  - Oro.
  - Material Industrial.
  - Uridium.
- Slots de edificio usados/libres.
- Edificios activos o en construcción.
- Información pública.
- Recursos u objetos especiales avistados.
- Botones de acción según permisos:
  - Mover tropas.
  - Ver misión.
  - Construir si aplica.
  - Administrar si es admin.

### 7.2 Si el sistema es propio

El jugador puede ver:

- Tropas propias estacionadas.
- Ejércitos propios en el sistema.
- Posibles movimientos.
- Acciones disponibles.
- Si hay construcción/reclutamiento relacionado.

### 7.3 Si el sistema es enemigo

El jugador ve:

- Controlador.
- Estado.
- Producción pública.
- Información pública.
- Si está en guerra o bloqueado.
- Misión pública.
- No ve tropas exactas salvo que más adelante haya espionaje.

### 7.4 Si el sistema es neutral

El jugador ve:

- Producción.
- Descripción.
- Posibles reliquias avistadas si públicas.
- Misión.
- Si puede mover tropas allí para disputar/conquistar.

### 7.5 Construcciones y edificios

Cada sistema tiene slots limitados de edificios:

- Capitales: 6 slots.
- Resto de sistemas: 3 slots.

Reglas v1:

- Solo se puede construir en sistemas controlados por la facción del jugador.
- No se puede construir en sistemas neutrales, enemigos, en guerra o bloqueados.
- Solo se permite un edificio de cada tipo por sistema.
- Las capitales pueden construir cualquier edificio si la tecnología está desbloqueada y hay slot.
- En sistemas no capitales, los edificios de producción solo pueden construirse si `system_resource_capabilities` permite ese recurso.
- Los edificios pertenecen al sistema. Si cambia el controlador, el nuevo controlador puede usar los edificios activos.
- No hay demolición, mejoras ni destrucción de edificios en v1 salvo edición admin/base de datos.

Catálogo inicial:

| Edificio | Tipo | Uso |
|---|---|---|
| Barracón de Infantería | Reclutamiento | Recluta Infantería y Élite compatible. |
| Cuartel de Mando | Reclutamiento | Recluta Personajes. |
| Taller de Guerra | Reclutamiento | Recluta Vehículos. |
| Nido de Bestias | Reclutamiento | Recluta Monstruos. |
| Cámara de Comercio | Comercio | Abre Mercader y Comercio estelar. |
| Nexo de Inteligencia | Inteligencia | Placeholder de espionaje futuro. |
| Antenas de Reconocimiento | Inteligencia | Placeholder de información/espionaje futuro. |
| Granja Biológica | Producción | Genera Suministro vital. |
| Complejo Minero | Producción | Genera Mineral. |
| Refinería de Iridium | Producción | Genera Uridium. |
| Mina de Oro | Producción | Genera Oro. |
| Planta de Fundición | Producción | Genera Material Industrial. |
| Monumento | Producción | Genera Honor. |

Las capitales del seed empiezan con 4 edificios activos: Barracón de Infantería, Cámara de Comercio, Planta de Fundición y Monumento.

RPCs principales:

```text
start_building_construction(system_id, building_template_id)
resolve_building_construction()
```

Los iconos propios de edificios quedan pendientes para una iteración posterior; mientras tanto se usan placeholders coherentes con Tailwind/Lucide.

---

## 8. Movimiento de tropas

### 8.1 Principio general

Los jugadores mueven unidades Warhammer concretas, no destacamentos abstractos.

Una orden de movimiento puede incluir una o varias unidades propias que esten `ready`, pertenezcan a la misma faccion y esten en el mismo sistema de origen.

Cada fila de `campaign_units` representa una unidad Warhammer persistente e indivisible. El campo `quantity` representa cuantas miniaturas actuales quedan vivas en esa unidad, `starting_quantity` representa su tamano completo y `wounds_taken` representa heridas agregadas en miniaturas supervivientes. Por ejemplo, una unidad de `Boyz` puede empezar como `10/10`, quedar `6/10` y `2 heridas` tras una batalla, pero no puede separarse en grupos hijos para moverse por otra ruta.

Cada unidad movible es una unidad real de faccion, por ejemplo `Boyz`, `Meganobz`, `Deff Dread`, `Necron Warriors`, `Kasrkin`, `Leman Russ Battle Tank`, `Intercessor Squad`, `Plague Marines` o `Foetid Bloat-drone`.

El coste se paga con Uridium.

Por ahora no hay riesgos aleatorios en rutas. Algunas rutas simplemente pueden costar mas.

Para test local, la duracion inicial recomendada es `2 minutos por arista`.

### 8.2 Coste de movimiento

Cada arista/ruta tiene:

```text
uridium_cost
```

Ejemplos:

| Tipo de ruta | Coste |
|---|---:|
| Ruta normal | 1 Uridium |
| Ruta larga/importante | 2 Uridium |
| Ruta complicada | 3 Uridium |
| Ruta bloqueada | No disponible |

Cancelacion de movimiento:

- RPC: `cancel_movement_order(order_id)`.
- Solo puede cancelar el propietario de la faccion o un admin.
- Solo se puede cancelar si la orden sigue en estado `moving` y `arrival_at` no ha vencido.
- Al cancelar, las unidades vuelven completas al sistema de origen en estado `ready`.
- Se devuelve el 50% del `uridium_cost`, redondeado hacia arriba.
- El UI debe mostrar el reembolso previsto antes de confirmar la cancelacion.

### 8.3 Flujo de interfaz para mover tropas

El flujo debe ser claro y visual.

#### Paso 1: seleccionar sistema propio

El jugador pincha un sistema donde tenga unidades propias `ready`.

Se abre el panel de sistema.

Ejemplo:

```text
Sistema: Kharon Prime
Controlador: Guardia Imperial
Estado: Controlado

Tropas presentes:
- Cadian Shock Troops 10/10 miniaturas - 80 pts
- Kasrkin 10/10 miniaturas - 105 pts

Acciones:
[Mover tropas]
[Ver misión]
```

#### Paso 2: pulsar "Mover tropas"

Se abre panel o modal:

```text
Mover tropas desde Kharon Prime

Selecciona unidades:
[ ] Cadian Shock Troops - 10/10 miniaturas - 80 pts
[ ] Kasrkin - 10/10 miniaturas - 105 pts
[ ] Leman Russ Battle Tank - 1/1 miniaturas - 145 pts
```

Primera version:

- Seleccion multiple de unidades Warhammer concretas.
- Cada unidad se selecciona completa; no se pueden mover miniaturas sueltas.
- El backend rechaza cualquier `unit_selection.quantity` distinto al `campaign_units.quantity` actual.
- Las filas `parent_unit_id` pueden existir como legacy, pero no se crean nuevas unidades hijas en el flujo actual.
- Todas deben estar en el sistema origen.
- Todas deben estar `ready`.
- La accion de fusionar/reorganizar unidades queda oculta porque el sistema actual no crea separaciones futuras.

#### Paso 3: seleccionar ruta

Al elegir una o mas unidades, el mapa entra en modo movimiento:

- Resalta sistemas alcanzables.
- Ilumina rutas válidas.
- Oscurece destinos inválidos.
- Muestra candado sobre sistemas bloqueados.
- Muestra coste de Uridium en hover.
- Muestra aviso si no hay Uridium suficiente.
- Permite ruta optima y ruta manual.

Modo ruta optima:

- Hover sobre destino dibuja la ruta mas barata por Dijkstra.
- El coste total y tiempo estimado se muestran en la UI.
- Click fija destino y prepara confirmacion.

Modo ruta manual:

- El jugador va pasando o clicando sistema a sistema.
- Solo acepta tramos conectados y no bloqueados.
- Permite deshacer el ultimo tramo.
- La ruta confirmada puede no ser la mas barata.

#### Paso 4: seleccionar destino

El jugador pincha destino.

Se abre confirmacion compacta:

```text
Mover unidades

Origen: Kharon Prime
Destino: Helios Drift
Ruta: Kharon Prime -> Helios Drift
Coste: 1 Uridium
Llegada: 2 minutos

Al llegar:
- Si es propio: quedará estacionado.
- Si es neutral: podrá iniciar conflicto/conquista.
- Si es enemigo: el sistema pasará a En guerra.

[Confirmar movimiento]
[Cancelar]
```

#### Paso 5: backend valida

El backend debe comprobar:

- El usuario pertenece a la faccion.
- Las unidades existen.
- Las unidades pertenecen a la faccion.
- Las unidades estan en el sistema origen.
- Las unidades estan `ready`.
- Las unidades no estan moviendose ni bloqueadas en guerra.
- Todos los sistemas de la ruta existen.
- La ruta es continua por aristas existentes.
- Las aristas de la ruta no estan bloqueadas.
- El sistema destino no esta bloqueado para ataque si el destino es enemigo o neutral disputable.
- La faccion tiene suficiente Uridium.
- El coste calculado por backend coincide.
- No hay otra orden contradictoria.

#### Paso 6: crear orden

Si todo es válido:

- Se descuenta Uridium.
- Se crea `movement_orders`.
- Se crean filas en `movement_order_units`.
- Las unidades pasan a estado `moving`.
- Se guarda la ruta completa en `path_system_ids`.
- Se guarda `arrival_at`.
- El frontend muestra cuenta atrás.
- El mapa muestra animación direccional solo para órdenes de movimiento visibles por el usuario.

### 8.4 Llegada

Cuando `now() >= arrival_at`, backend procesa la llegada.

#### Si llega a sistema propio

- Las unidades pasan a `ready`.
- `current_system_id = destino`.
- No se crea guerra.

#### Si llega a sistema neutral

- Sistema pasa a `war`.
- Queda bloqueado mientras haya batalla pendiente.
- Se crea conflicto pendiente.
- Las unidades quedan `in_war`.
- Los participantes juegan la batalla en la vida real si corresponde.
- Los jugadores participantes o el admin reportan el resultado.

#### Si llega a sistema enemigo

- Sistema pasa a `war`.
- Queda bloqueado mientras haya batalla pendiente.
- Se crea conflicto.
- Las unidades atacantes quedan `in_war`.
- Las unidades defensoras presentes en el sistema que estaban `ready` tambien pasan a `in_war`.
- Los participantes juegan la batalla en la vida real.
- Los jugadores participantes o el admin reportan el resultado.

### 8.5 Reporte de batalla

La web no simula el combate de Warhammer 40K.

Cuando exista un conflicto:

- La batalla se juega fuera de la aplicación.
- Los jugadores participantes pueden enviar un reporte de resultado.
- El admin puede escribir y confirmar directamente el resultado completo.
- Si los reportes de los participantes coinciden, el backend puede aplicar automáticamente el resultado.
- Si los reportes no coinciden, el conflicto queda pendiente de decisión del admin.

El reporte debe permitir registrar:

- Facción ganadora.
- Supervivientes por unidad, expresados como miniaturas restantes.
- Bajas calculadas por backend a partir de los supervivientes reportados.
- Control final del sistema.
- XP o enhancements narrativos si aplica.
- Notas narrativas.
- Duración de bloqueo posterior.

Al aplicar el resultado:

- Las unidades con `0` supervivientes pasan a `destroyed`.
- Las unidades de la faccion que conserva/controla el sistema quedan `ready` en el sistema.
- Las unidades supervivientes que pierden el sistema se retiran al sistema controlado mas cercano de su faccion si existe.
- Si no hay ruta de retirada valida, quedan en estado `retreat_pending` para que el admin las coloque o resuelva narrativamente.

### 8.6 Visibilidad del movimiento

- El dueño ve sus movimientos.
- Admin ve todos los movimientos.
- Otros jugadores no ven movimientos enemigos.
- Más adelante espionaje podrá revelar movimientos.
- Las rutas base no deben sugerir dirección ni movimiento por sí mismas.
- La animación direccional sobre una ruta se reserva para `movement_orders` en estado `moving` que el usuario tenga permiso de ver.

---

## 9. Reclutamiento

### 9.1 Principio general

Los jugadores pueden gastar recursos para crear tropas desde edificios militares activos.

El reclutamiento tarda tiempo real, estilo Grepolis.

Para test local, los tiempos iniciales son de minutos, no horas.

Al completarse, las tropas aparecen en el sistema donde está el edificio que inició el reclutamiento.

El flujo legacy `recruit_unit(unit_template_id, quantity)` queda bloqueado con error claro. El flujo principal es:

```text
recruit_unit_at_building(system_building_id, unit_template_id, quantity)
```

### 9.2 Menú de reclutamiento

El reclutamiento ya no se abre desde un botón global de capital.

Flujo actual:

```text
Seleccionar sistema propio -> clicar edificio militar activo -> pestaña Reclutar
```

El panel del edificio militar muestra:

- Recursos actuales.
- Lista de unidades disponibles para ese edificio.
- Coste.
- Tiempo de producción.
- Requisitos tecnológicos.
- Botón de reclutar.
- Pestaña de cola.
- Pestaña de curación.

Edificios de reclutamiento v1:

| Edificio | Permite |
|---|---|
| Barracón de Infantería | Infantería y élites de infantería. |
| Cuartel de Mando | Personajes. |
| Taller de Guerra | Vehículos. |
| Nido de Bestias | Monstruos. |

### 9.3 Datos de una unidad reclutable

Cada unidad debe tener:

- Nombre.
- Facción a la que pertenece.
- Puntos.
- Coste en Suministro vital.
- Coste en Mineral.
- Coste en Honor.
- Coste en Oro si es una unidad de élite o especial que lo requiera.
- Coste en Material Industrial si alguna unidad especial lo requiere.
- Coste en Uridium si alguna unidad especial lo requiere, aunque normalmente no.
- Tiempo de producción.
- Requisitos opcionales.
- Edificio/categoría de reclutamiento compatible.
- Categoría:
  - Infantería.
  - Élite.
  - Personaje.
  - Vehículo.
  - Monstruo.
  - Superpesado.
  - Otro.
- Notas.

### 9.4 Al reclutar

El backend valida:

- Usuario/facción correcta.
- Recursos suficientes.
- Unidad disponible para esa facción.
- Edificio activo.
- Sistema controlado por la facción.
- Categoría compatible con el edificio.
- Requisitos tecnológicos cumplidos.
- No se exceden reglas de campaña si existen.
- Coste correcto.

Si todo es válido:

- Descuenta recursos.
- Crea fila en `recruitment_queue`.
- Guarda `system_building_id`.
- Guarda `origin_system_id`.
- Guarda `started_at`.
- Guarda `finishes_at`.
- Estado `queued`.

### 9.5 Al completar reclutamiento

Cuando `now() >= finishes_at`:

- Backend marca la cola como `completed`.
- Crea una fila nueva en `campaign_units` en el sistema del edificio.
- La fila se crea con `quantity = unit_templates.default_quantity` y `starting_quantity = unit_templates.default_quantity`.
- La unidad queda `ready` y disponible para movimiento.
- Frontend actualiza por Realtime o refetch.

### 9.6 Las bajas

Regla vigente:

- El reporte confirmado indica miniaturas supervivientes y heridas restantes por unidad.
- Backend actualiza `campaign_units.quantity` y `campaign_units.wounds_taken`.
- Si `quantity = 0`, la unidad pasa a `destroyed` y `wounds_taken = 0`.
- Validacion: `wounds_taken <= quantity * unit_templates.wounds_per_model`.
- Las unidades son indivisibles: las miniaturas no se separan ni para movimiento ni para reabastecimiento.
- `resupply_unit_at_building(system_building_id, campaign_unit_id)` reabastece una unidad completa desde un edificio militar compatible.
- El reabastecimiento exige unidad propia `ready`, mismo sistema que el edificio, edificio activo compatible y `quantity < starting_quantity` o `wounds_taken > 0`.
- Coste de reabastecimiento: mitad del coste completo original de la unidad, redondeado hacia arriba por recurso.
- Al completarse, `resolve_unit_recovery_queue()` deja `quantity = starting_quantity` y `wounds_taken = 0`.
- Cada edificio solo puede tener una cola activa total: reclutamiento o reabastecimiento.
- Cancelar reclutamiento o reabastecimiento devuelve el 50% de los recursos gastados, redondeado hacia arriba.

Si una unidad sufre bajas en batalla:

- Texto legacy obsoleto: el reporte confirmado debe indicar miniaturas supervivientes y heridas restantes por unidad.
- Backend actualiza `campaign_units.quantity`.
- Si `quantity` queda en `0`, la unidad pasa a `destroyed` y conserva `destroyed_at`.
- Texto legacy obsoleto: las unidades danadas se reabastecen completas desde edificios militares compatibles.

Curación v1:

- Texto legacy obsoleto: usar `resupply_unit_at_building(system_building_id, campaign_unit_id)`; `heal_unit_at_building(...)` solo queda como alias compatible.
- La unidad debe ser propia, estar `ready`, estar en el mismo sistema que el edificio y tener `quantity < starting_quantity`.
- El edificio debe ser militar y compatible con la categoría de la unidad.
- Texto legacy obsoleto: coste = mitad del coste completo original de la unidad, redondeado hacia arriba por recurso.
- La unidad queda `recovering` mientras dura la cola.
- `resolve_unit_recovery_queue()` completa reabastecimientos vencidos y deja `quantity = starting_quantity`, `wounds_taken = 0`.

### 9.7 Árbol tecnológico y desbloqueos de reclutamiento

El reclutamiento está conectado al árbol tecnológico.

V1 usa un árbol común `common-v1` para todas las facciones, pero cada facción tiene progreso independiente.

Estados de una tecnología:

```text
locked
available
researching
unlocked
```

Reglas:

- Solo puede haber una investigación activa por facción.
- Cada tecnología puede tener coste en Componentes tecnológicos.
- Cada tecnología puede tener tiempo de investigación en minutos para test local.
- Los requisitos se definen como prerequisitos entre nodos.
- Al completarse una investigación, el nodo pasa a `unlocked`.
- `resolve_technology_research()` completa investigaciones vencidas.
- El frontend puede mostrar unidades bloqueadas en gris, pero el backend es quien decide si se pueden reclutar.

Efectos v1:

- `unlock_unit`: una tecnología permite reclutar plantillas de unidad asociadas.
- `unlock_building_template`: permite construir plantillas de edificio asociadas si la faccion tiene la tecnologia desbloqueada.
- `recruitment_cost_discount`: reduce costes de reclutamiento por recurso y categoría.
- `recruitment_time_discount`: reduce tiempo de reclutamiento por categoría.

Unidades iniciales desbloqueadas sin tecnología:

- Boyz.
- Necron Warriors.
- Cadian Shock Troops.
- Neophyte Hybrids.
- Intercessor Squad.
- Poxwalkers.

Unidades bloqueadas por `veteranos-guerra`:

- Meganobz.
- Immortals.
- Skorpekh Destroyers.
- Kasrkin.
- Acolyte Hybrids.
- Terminator Squad.
- Plague Marines.

Unidades bloqueadas por `motores-guerra`:

- Deff Dread.
- Leman Russ Battle Tank.
- Achilles Ridgerunner.
- Redemptor Dreadnought.
- Foetid Bloat-drone.

Ramas del árbol común v1:

- Mando y doctrina.
- Infantería y élite.
- Blindados y máquinas.
- Infraestructura.
- Arqueotecnología.

La pantalla de tecnología debe sentirse como interfaz de videojuego:

- Modal grande, casi a pantalla completa.
- Fondo espacial táctico oscuro.
- Árbol tipo constelación tecnológica, no tabla lineal.
- Nodos circulares o hexagonales basados en iconos PNG propios.
- Iconos coherentes por tecnología en `public/tech-icons/common-v1/{slug}.png`.
- Conectores curvos luminosos tipo rutas estelares.
- Hover que resalta prerequisitos y dependientes directos.
- Tooltip breve al pasar el ratón.
- Estados visuales claros.
- Panel lateral con descripción, coste, tiempo, requisitos y efectos.
- Botón `Tecnología` en el dock de mando.

Regla vigente del arbol comun:

- La descripcion anterior de ramas antiguas queda obsoleta donde choque con esta lista.
- `common-v1` tiene rama `Progreso` funcional, rama `Inteligencia` visible pero bloqueada como `planned`, y rama militar temporal.
- Todas las investigaciones de test duran 30 segundos.
- `technology_nodes.implementation_status` puede ser `active`, `planned` o `deprecated`.
- `technology_prerequisites.prerequisite_group` permite requisitos `OR`: todos los grupos deben cumplirse, pero dentro de un mismo grupo basta una tecnologia desbloqueada.
- `Asamblea Planetaria` requiere `Maquinaria Belica` o `Criadero de Guerra`.
- `La Fiebre del Oro` requiere Cristalizacion de Combustible Cuantico, Extraccion Subterranea y Monumentos a la Gloria.
- `fundacion-planetaria` desbloquea Barracon de Infanteria y Granja Biologica.
- `maquinaria-belica` desbloquea Taller de Guerra.
- `criadero-guerra` desbloquea Nido de Bestias.
- `asamblea-planetaria` desbloquea Cuartel de Mando.
- `procesado-metalurgico` desbloquea Planta de Fundicion.
- `cristalizacion-combustible-cuantico` desbloquea Refineria de Iridium.
- `extraccion-subterranea` desbloquea Complejo Minero.
- `monumentos-gloria` desbloquea Monumento.
- `fiebre-oro` desbloquea Mina de Oro.
- `pactos-mercantiles` desbloquea Camara de Comercio.
- `contactos-economicos` desbloquea el Mercader.
- `tratos-preferentes` mejora precios del Mercader.
- `mercado-galactico` desbloquea Comercio Estelar.
- `aranceles-privilegiados` baja la comision propia de Comercio Estelar al 10%, minimo 1 Oro.
- La pantalla abre centrada en `fundacion-planetaria`, sin nodo seleccionado por defecto.

---

## 10. Experiencia y enhancements narrativos

Algunas tropas que sobrevivan a combates pueden ganar experiencia.

La experiencia servirá para que el admin les asigne buffs narrativos llamados enhancements narrativos.

No se automatizan reglas complejas. Solo se guardan como datos editables.

### 10.1 Campos recomendados para unidades

- `experience`
- `rank`
- `enhancement_text`
- `notes`
- `battle_history`

### 10.2 Ejemplo

```text
Unidad: Veteranos de Kharon
XP: 3
Rango: Curtidos
Enhancement narrativo:
"Juramento de venganza: una vez por batalla pueden repetir una tirada de carga contra Necrones."
```

### 10.3 Admin

El admin puede:

- Sumar XP.
- Cambiar rango.
- Añadir enhancement.
- Cambiar nombre narrativo.
- Escribir notas.
- Registrar historia de batalla.

---

## 11. Misiones narrativas

### 11.1 Concepto

Cada sistema puede tener una misión narrativa principal.

La misión no necesita editor interno.

El admin editará el mapa fuera de la web y lo subirá/pegará tal cual como imagen, similar a layouts de misiones de libros de Warhammer.

La web solo debe mostrarlo de forma bonita.

### 11.2 Contenido de misión

Cada misión debe tener:

- Título.
- Sistema asociado.
- Imagen del mapa/layout.
- Descripción narrativa.
- Tamaño recomendado de batalla.
- Objetivos.
- Reglas especiales.
- Condiciones de victoria.
- Recompensa si aplica.
- Notas del admin.

### 11.3 Consecuencias

En general, las misiones narrativas no tienen consecuencias especiales de derrota más allá de:

- Tropas muertas.
- Sistema conquistado o defendido.
- Resultado narrativo que decida el admin.

### 11.4 Vista de misión

Al seleccionar sistema, hay botón:

```text
Ver misión
```

Vista recomendada:

- Imagen grande del mapa a la izquierda o arriba.
- Panel de reglas a la derecha o debajo.
- Botón para ampliar imagen.
- Texto narrativo separado de reglas mecánicas.
- Estética de briefing militar/codex.

### 11.5 Storage

Guardar imágenes en Supabase Storage.

Tabla `missions` guarda URL pública/privada según diseño.

---

## 12. Barra superior y comercio

### 12.1 Barra superior

Siempre visible:

```text
Suministro vital: 120 | Mineral: 85 | Honor: 8 | Oro: 30 | Material Industrial: 90 | Uridium: 14
```

Debe tener iconos bonitos. La version implementada muestra: Suministro vital, Mineral, Honor, Oro, Material Industrial y Uridium. Los Componentes tecnologicos solo se ven dentro del panel de Tecnologia.

### 12.2 Panel de comercio

El panel de mando operativo muestra `Comercio` en lugar de `Recursos`.

Al abrir comercio:

- La pestana por defecto es `Mercader`.
- La segunda pestana es `Comercio estelar`.

Mercader:

- Avatar en `icons/resources/merchant1.png`.
- Compra y venta de Suministro, Mineral, Material Industrial y Uridium usando Oro.
- No comercia Honor ni Componentes tecnologicos.
- Requiere al menos una Camara de Comercio activa de la faccion.
- Requiere `Contactos Economicos`.
- Vende al doble de valor por defecto.
- Compra a mitad de valor por defecto, redondeando hacia arriba.
- `Tratos Preferentes` mejora precios: compra a 1.5x y venta a 0.75x.

Comercio estelar:

- Crear oferta de compra o venta de recurso contra Oro.
- Aceptar ofertas de otras facciones.
- Cancelar ofertas propias.
- Solo se comercian Suministro, Mineral, Material Industrial y Uridium.
- No se comercian Honor ni Componentes tecnologicos.
- Requiere al menos una Camara de Comercio activa de la faccion.
- Requiere `Mercado Galactico`.
- Cada transaccion cobra una comision en Oro del 30%, redondeada hacia arriba, a cada jugador por separado.
- `Aranceles Privilegiados` reduce la comision propia al 10%, minimo 1 Oro.
- Publicar una oferta reserva inmediatamente los recursos/oro comprometidos y la comision del creador.
- Cancelar una oferta devuelve la reserva completa.

El bloque antiguo de panel detallado de recursos queda solo como referencia historica y no debe implementarse como vista principal:

```text
Recursos actuales

Suministro vital: 120
Producción diaria: +18

Mineral: 85
Producción diaria: +11

Honor: 8
Producción diaria: +2

Material Industrial: 90
Produccion diaria: +5

Uridium: 14
Producción diaria: +4

Componentes tecnológicos: 16

Cadencia de producción: cada 24 horas
```

Debajo:

```text
Objetos especiales

Reliquias:
- Estandarte de la Cruzada Perdida
- Núcleo de Piedra Ancestral

Tecnologías desbloqueadas:
- Doctrina de campaña
- Entrenamiento de línea
```

### 12.3 Producción

La producción debe calcularse a partir de sistemas controlados.

No confiar en el frontend.

La cadencia de producción debe ser configurable por admin y gestionada por backend.

Nota actual de v1: aunque este bloque historico hable de sistemas, la regla vigente es que `resolve_resource_ticks()` suma produccion desde edificios activos en sistemas controlados. `system_production` es una proyeccion visible derivada, no la fuente de verdad manual.

---

## 13. Roles y permisos

### 13.1 Roles

- `admin`
- `player`
- Opcional futuro: `spectator`

### 13.2 Admin

Puede:

- Crear/editar sistemas.
- Crear/editar rutas.
- Cambiar control territorial.
- Cambiar estado de sistema.
- Bloquear sistemas.
- Subir misiones.
- Editar recursos de facciones.
- Crear/editar/borrar tropas.
- Inspeccionar y corregir progreso tecnológico.
- Resolver batallas.
- Confirmar reportes de batalla.
- Añadir XP.
- Añadir enhancements.
- Ver toda la niebla de guerra.
- Configurar cadencia de producción.
- Ver logs.

### 13.3 Jugador

Puede:

- Ver mapa público.
- Ver recursos propios.
- Ver tropas propias.
- Ver movimientos propios.
- Construir edificios en sistemas propios.
- Reclutar y curar unidades desde edificios compatibles.
- Investigar tecnologías disponibles.
- Comerciar con el mercader si tiene Camara de Comercio activa.
- Crear, aceptar y cancelar ofertas propias de comercio estelar.
- Mover tropas propias.
- Ver misiones públicas.
- Ver paneles de sus sistemas.
- Enviar reportes de batalla en conflictos donde participe.
- No puede editar manualmente recursos, tropas o control.

---

## 14. Seguridad y backend autoritativo

### 14.1 Regla absoluta

El frontend no debe modificar directamente valores críticos.

No permitir que el cliente haga directamente:

```sql
UPDATE faction_resources SET uridium = uridium - 3;
```

Debe llamar a una función segura:

```text
create_movement_order(unit_selections, path_system_ids)
```

El backend calcula y valida.

### 14.2 Funciones backend recomendadas

Crear funciones RPC o endpoints equivalentes:

```text
create_movement_order(unit_selections, path_system_ids)
cancel_movement_order(order_id)
start_building_construction(system_id, building_template_id)
resolve_building_construction()
recruit_unit_at_building(system_building_id, unit_template_id, quantity)
resupply_unit_at_building(system_building_id, campaign_unit_id)
heal_unit_at_building(system_building_id, campaign_unit_id, heal_quantity) -- alias legacy
resolve_unit_recovery_queue()
cancel_recruitment_queue(queue_id)
cancel_unit_recovery_queue(queue_id)
start_technology_research(technology_node_id)
merchant_trade(resource_key, direction, trade_quantity)
create_trade_offer(offer_type, resource_key, resource_amount, gold_amount)
accept_trade_offer(offer_id)
cancel_trade_offer(offer_id)
resolve_resource_ticks()
resolve_movement_orders()
resolve_recruitment_queue()
resolve_technology_research()
submit_battle_report(conflict_id, report_payload) -- incluye survivors y wounds_remaining
admin_confirm_battle_report(conflict_id, final_payload)
admin_resolve_battle(conflict_id, winner_faction_id, blocked_days)
admin_update_system_control(system_id, faction_id)
admin_add_experience(unit_id, amount)
admin_delete_unit(unit_id)
admin_create_or_update_mission(...)
```

`recruit_unit(unit_template_id, quantity)` existe solo como RPC legacy temporal y debe devolver error claro: "El reclutamiento ahora requiere seleccionar un edificio activo".

### 14.3 Validaciones mínimas

Para movimiento:

- Facción correcta.
- Unidades propias.
- Unidades listas y en el mismo origen.
- Ruta continua y valida.
- Uridium suficiente.
- Sistema no bloqueado.
- No duplicar órdenes.

Para reclutamiento:

- Facción correcta.
- Unidad disponible.
- Recursos suficientes.
- Coste correcto.
- Requisitos cumplidos.
- Tecnología requerida desbloqueada.
- Descuentos tecnológicos aplicados por backend.
- Insert seguro en cola.

Para tecnología:

- Facción correcta.
- Nodo existente y disponible.
- Prerequisitos desbloqueados.
- Componentes tecnológicos suficientes.
- Solo una investigación activa por facción.
- `finishes_at` calculado por backend.

Para comercio:

- FacciÃ³n correcta.
- Recurso comerciable: Suministro, Mineral, Material Industrial o Uridium.
- Honor y Componentes tecnologicos no comerciables.
- Camara de Comercio activa para la faccion.
- `Contactos Economicos` para Mercader.
- `Mercado Galactico` para Comercio Estelar.
- Oro suficiente para compras y comisiones.
- Recursos suficientes para ventas.
- Comision calculada por backend: 30% por defecto, 10% minimo 1 Oro con `Aranceles Privilegiados`.
- Aceptacion atomica: se revalidan recursos antes de aplicar transferencia.
- Un jugador no puede aceptar su propia oferta.

Para reportes de batalla:

- Conflicto existente y pendiente.
- Usuario participante del conflicto o admin.
- Sistema asociado bloqueado/en guerra.
- Ganador válido entre facciones participantes, neutral o resultado narrativo permitido por admin.
- Bajas/supervivientes coherentes con tropas implicadas.
- No aplicar cambios críticos hasta que los reportes coincidan o el admin confirme.

Para admin:

- Usuario role `admin`.
- Logs de cambios importantes.

### 14.4 Logs

Registrar acciones importantes:

- Movimiento creado.
- Movimiento completado.
- Reclutamiento iniciado.
- Reclutamiento completado.
- Investigación tecnológica iniciada.
- Investigación tecnológica completada.
- Tick de recursos aplicado.
- Conflicto creado.
- Reporte de batalla enviado.
- Reporte confirmado automáticamente.
- Reporte resuelto por admin.
- Sistema conquistado.
- Sistema bloqueado.
- Sistema desbloqueado.
- Batalla resuelta.
- Unidad eliminada.
- XP añadida.
- Enhancement añadido.

---

## 15. Realtime y coherencia frontend

### 15.1 Qué debe actualizarse en tiempo real

- Recursos propios.
- Órdenes de movimiento propias.
- Cola de reclutamiento propia.
- Progreso tecnológico propio.
- Reportes de batalla propios.
- Estado público de sistemas.
- Cambios de control.
- Estado en guerra.
- Bloqueos.
- Misiones si admin las edita.

### 15.2 Estrategia

Usar combinación de:

1. Supabase Realtime para cambios.
2. Refetch con TanStack Query tras acciones.
3. Cron backend para completar tiempos y ticks de recursos.
4. Lazy processing al cargar pantallas importantes.

### 15.3 Lazy processing

Cuando el jugador abre la app o paneles importantes, el backend puede ejecutar:

```text
resolve_resource_ticks()
resolve_movement_orders()
resolve_recruitment_queue()
resolve_technology_research()
```

Así, aunque un cron se retrase, el estado se corrige.

---

## 16. Modelo de datos recomendado

Este es un esquema inicial. Puede adaptarse.

### 16.0 Contrato vigente de construcciones y recursos

La version actual añade el sistema de edificios en `supabase/migrations/0009_buildings_honor_industrial_material.sql`.

Recursos vigentes en frontend:

```text
supply
minerals
honor
gold
industrialMaterial
uridium
technology
```

Recursos comerciables:

```text
supply
minerals
industrialMaterial
uridium
```

`technology` solo se muestra dentro del arbol tecnologico. `honor` no es comerciable. `ancestral_stone` y `ancestral_stone_cost` son columnas legacy temporales para compatibilidad y no deben usarse como contrato nuevo.

Tablas nuevas/vigentes:

- `system_resource_capabilities`: recursos que un sistema no capital puede explotar mediante edificios de produccion.
- `building_templates`: catalogo de edificios con coste, tipo, duracion, tecnologia requerida, recurso producido y categorias reclutables.
- `system_buildings`: edificios construidos/en construccion por sistema.
- `unit_recovery_queue`: cola de curacion de miniaturas.

Campos nuevos principales:

- `systems.building_slots`.
- `faction_resources.honor`.
- `faction_resources.industrial_material`.
- `system_production.honor_per_tick`.
- `system_production.industrial_material_per_tick`.
- `unit_templates.honor_cost`.
- `unit_templates.industrial_material_cost`.
- `unit_templates.recruitment_building_type`.
- `recruitment_queue.system_building_id`.
- `recruitment_queue.origin_system_id`.

Produccion:

- `system_buildings` activos son la fuente de verdad.
- `system_production` es una proyeccion derivada para UI/consultas.
- `resolve_resource_ticks()` suma edificios activos de sistemas controlados.

RPCs de edificios:

```text
start_building_construction(system_id, building_template_id)
resolve_building_construction()
recruit_unit_at_building(system_building_id, unit_template_id, quantity)
heal_unit_at_building(system_building_id, campaign_unit_id, heal_quantity)
resolve_unit_recovery_queue()
```

### 16.1 users / profiles

Supabase Auth ya gestiona usuarios. Crear tabla de perfil:

```sql
profiles
- id uuid primary key references auth.users(id)
- display_name text
- role text check in ('admin', 'player', 'spectator')
- created_at timestamptz
```

### 16.2 factions

```sql
factions
- id uuid primary key
- name text
- color text
- emblem_url text nullable
- capital_system_id uuid nullable references systems(id)
- created_at timestamptz
```

### 16.3 player_factions

Relación usuario-facción.

```sql
player_factions
- id uuid primary key
- user_id uuid references profiles(id)
- faction_id uuid references factions(id)
- created_at timestamptz
```

### 16.4 systems

```sql
systems
- id uuid primary key
- name text
- x numeric
- y numeric
- size numeric default 1
- type text
- status text check in ('neutral', 'controlled', 'war')
- controller_faction_id uuid nullable references factions(id)
- blocked_until timestamptz nullable
- public_description text
- secret_admin_notes text nullable
- mission_id uuid nullable
- is_capital boolean default false
- created_at timestamptz
- updated_at timestamptz
```

### 16.5 system_edges

```sql
system_edges
- id uuid primary key
- from_system_id uuid references systems(id)
- to_system_id uuid references systems(id)
- uridium_cost integer default 1
- is_blocked boolean default false
- created_at timestamptz
```

Considerar que la ruta puede tratarse como no dirigida. En ese caso, validar ambos sentidos o guardar siempre `from < to`.

### 16.6 faction_resources

```sql
faction_resources
- faction_id uuid primary key references factions(id)
- supply integer default 0
- minerals integer default 0
- ancestral_stone integer default 0
- gold integer default 0
- uridium integer default 0
- technology integer default 0 -- Componentes tecnológicos
- updated_at timestamptz
```

`technology` representa Componentes tecnológicos y se usa principalmente para el árbol tecnológico.

### 16.7 system_production

```sql
system_production
- system_id uuid primary key references systems(id)
- supply_per_tick integer default 0
- minerals_per_tick integer default 0
- ancestral_stone_per_tick integer default 0
- gold_per_tick integer default 0 -- en seed v1 empieza a 0; oro es principalmente comercial
- uridium_per_tick integer default 0
- technology_per_tick integer default 0 -- debe permanecer en 0; los Componentes tecnológicos no son producción planetaria
```

La cadencia global de producción se puede guardar en una tabla de configuración:

```sql
campaign_settings
- id text primary key default 'default'
- resource_tick_interval_hours integer default 24
- movement_edge_duration_seconds integer default 120
- conflict_block_duration_minutes integer default 20160 -- 14 dias
- last_resource_tick_at timestamptz nullable
- next_resource_tick_at timestamptz nullable
- updated_at timestamptz
```

### 16.8 campaign_units

```sql
campaign_units
- id uuid primary key
- slug text unique
- faction_id uuid references factions(id)
- unit_template_id uuid nullable references unit_templates(id)
- name text
- category text
- points integer
- quantity integer default 1 -- miniaturas actuales
- starting_quantity integer default 1 -- tamano completo de la unidad
- wounds_taken integer default 0 -- heridas agregadas en miniaturas supervivientes
- parent_unit_id uuid nullable references campaign_units(id) -- legacy, no se crean hijos nuevos
- destroyed_at timestamptz nullable
- experience integer default 0
- rank text nullable
- enhancement_text text nullable
- notes text nullable
- current_system_id uuid nullable references systems(id)
- status text check in ('ready', 'moving', 'in_war', 'destroyed', 'retreat_pending', 'recovering')
- is_visible_publicly boolean default false
- created_at timestamptz
- updated_at timestamptz
```

Cada fila representa una unidad Warhammer concreta movible en el mapa. Las unidades son indivisibles: no se separan miniaturas al mover y no se crean nuevas filas hijas en el flujo actual. La validacion de heridas es `wounds_taken <= quantity * unit_templates.wounds_per_model`.

### 16.9 movement_order_units

```sql
movement_order_units
- movement_order_id uuid references movement_orders(id)
- unit_id uuid references campaign_units(id)
- quantity_at_departure integer
- created_at timestamptz
- primary key (movement_order_id, unit_id)
```

### 16.10 unit_templates

```sql
unit_templates
- id uuid primary key
- faction_id uuid references factions(id)
- name text
- category text
- points integer
- default_quantity integer default 1
- wounds_per_model integer default 1
- supply_cost integer
- minerals_cost integer
- ancestral_stone_cost integer
- gold_cost integer default 0
- uridium_cost integer default 0
- technology_cost integer default 0
- recruitment_time_seconds integer
- required_technology_node_id uuid nullable references technology_nodes(id)
- requirements jsonb nullable
- notes text nullable
- is_available boolean default true
```

### 16.10.1 technology_nodes

```sql
technology_nodes
- id uuid primary key
- slug text unique
- tree_key text
- name text
- description text
- branch text
- tier integer
- position_x integer
- position_y integer
- cost_technology integer
- research_time_seconds integer
- icon_key text nullable
- effect_summary text nullable
- is_starter boolean default false
- implementation_status text check in ('active', 'planned', 'deprecated')
- created_at timestamptz
```

### 16.10.2 technology_prerequisites

```sql
technology_prerequisites
- technology_node_id uuid references technology_nodes(id)
- required_node_id uuid references technology_nodes(id)
- prerequisite_group integer default 1
- primary key (technology_node_id, required_node_id)
```

### 16.10.3 faction_technologies

```sql
faction_technologies
- faction_id uuid references factions(id)
- technology_node_id uuid references technology_nodes(id)
- status text check in ('available', 'researching', 'unlocked')
- started_at timestamptz nullable
- finishes_at timestamptz nullable
- unlocked_at timestamptz nullable
- primary key (faction_id, technology_node_id)
```

### 16.10.4 technology_effects

```sql
technology_effects
- id uuid primary key
- technology_node_id uuid references technology_nodes(id)
- effect_type text
- payload jsonb
- created_at timestamptz
```

Los efectos se consultan al calcular acciones. No se copian como datos permanentes en la facción salvo que una regla futura lo necesite.

### 16.10.5 building_templates

```sql
building_templates
- id uuid primary key
- slug text unique
- name text
- description text
- category text
- required_technology_node_id uuid nullable references technology_nodes(id)
- is_available boolean default true
- created_at timestamptz
```

La construccion ya esta implementada. El arbol tecnologico desbloquea `building_templates`, y `start_building_construction()` valida tecnologia, slots, duplicados, control del sistema, bloqueo y capacidades de recurso.

### 16.11 recruitment_queue

```sql
recruitment_queue
- id uuid primary key
- faction_id uuid references factions(id)
- unit_template_id uuid references unit_templates(id)
- quantity integer default 1
- supply_cost integer
- minerals_cost integer
- ancestral_stone_cost integer
- gold_cost integer default 0
- uridium_cost integer
- technology_cost integer default 0
- started_at timestamptz
- finishes_at timestamptz
- status text check in ('queued', 'completed', 'cancelled')
- created_at timestamptz
```

### 16.12 trade_offers

```sql
trade_offers
- id uuid primary key
- creator_faction_id uuid references factions(id)
- offer_type text check in ('buy', 'sell')
- resource_key text check in ('supply', 'minerals', 'industrial_material', 'uridium')
- resource_amount integer
- gold_amount integer
- fee_gold integer -- ceil(gold_amount * 0.30)
- is_reserved boolean default false
- status text check in ('open', 'accepted', 'cancelled')
- accepted_by_faction_id uuid nullable references factions(id)
- created_at timestamptz
- accepted_at timestamptz nullable
- cancelled_at timestamptz nullable
- updated_at timestamptz
```

`trade_offers` usa reserva de recursos:

- `is_reserved boolean default false`.
- Ofertas abiertas nuevas deben tener `is_reserved = true`.
- Compra: reserva `gold_amount + fee_gold`.
- Venta: reserva `resource_amount` y `fee_gold`.
- Aceptar oferta aplica transferencia usando la reserva del creador y valida solo el pago/comision del aceptante.
- Cancelar oferta devuelve toda la reserva del creador.

### 16.13 movement_orders

```sql
movement_orders
- id uuid primary key
- faction_id uuid references factions(id)
- from_system_id uuid references systems(id)
- to_system_id uuid references systems(id)
- path_system_ids uuid[]
- uridium_cost integer
- segment_count integer
- duration_seconds integer
- started_at timestamptz
- arrival_at timestamptz
- status text check in ('moving', 'arrived', 'cancelled')
- cancelled_at timestamptz nullable
- created_at timestamptz
```

### 16.14 conflicts

```sql
conflicts
- id uuid primary key
- system_id uuid references systems(id)
- attacker_faction_id uuid references factions(id)
- defender_faction_id uuid nullable references factions(id)
- status text check in ('pending', 'resolved', 'cancelled')
- winner_faction_id uuid nullable references factions(id)
- blocked_until timestamptz nullable
- created_at timestamptz
- resolved_at timestamptz nullable
- notes text nullable
```

### 16.15 battle_reports

```sql
battle_reports
- id uuid primary key
- conflict_id uuid references conflicts(id)
- reporter_user_id uuid references profiles(id)
- reporter_faction_id uuid nullable references factions(id)
- winner_faction_id uuid nullable references factions(id)
- final_controller_faction_id uuid nullable references factions(id)
- casualties jsonb nullable
- survivors jsonb nullable
- xp_awards jsonb nullable
- enhancements jsonb nullable
- post_battle_blocked_until timestamptz nullable
- narrative_notes text nullable
- status text check in ('submitted', 'auto_confirmed', 'admin_confirmed', 'disputed', 'rejected')
- created_at timestamptz
- resolved_at timestamptz nullable
```

Si los reportes de los participantes coinciden, el backend puede marcarlos como `auto_confirmed` y aplicar el resultado. Si no coinciden, quedan como `disputed` hasta que el admin confirme el resultado final.

### 16.16 missions

```sql
missions
- id uuid primary key
- system_id uuid references systems(id)
- title text
- narrative_description text
- recommended_points text nullable
- objectives text
- special_rules text
- victory_conditions text
- rewards text nullable
- map_image_url text nullable
- admin_notes text nullable
- created_at timestamptz
- updated_at timestamptz
```

### 16.17 relics / special objects

```sql
relics
- id uuid primary key
- faction_id uuid nullable references factions(id)
- system_id uuid nullable references systems(id)
- name text
- description text
- effect_text text nullable
- is_public boolean default false
- created_at timestamptz
```

También puede existir:

```sql
system_special_objects
- id uuid primary key
- system_id uuid references systems(id)
- name text
- type text check in ('relic', 'technology', 'resource', 'anomaly')
- public_description text
- secret_description text nullable
- is_public boolean default true
- created_at timestamptz
```

### 16.18 logs

```sql
campaign_logs
- id uuid primary key
- actor_user_id uuid nullable references profiles(id)
- faction_id uuid nullable references factions(id)
- action_type text
- payload jsonb
- created_at timestamptz
```

### 16.19 Implementacion local real

El proyecto debe poder ejecutarse contra una base Supabase/Postgres local equivalente a produccion para que el despliegue cloud sea sencillo.

Backend local:

- Supabase CLI como dependencia de desarrollo del proyecto.
- Docker como runtime local.
- Configuracion en `supabase/config.toml`.
- Migraciones en `supabase/migrations`.
- Seed de campana en `supabase/seed.sql`.
- Usuarios locales mediante script con service role.

El seed local inicial representa el estado jugable de prueba:

- 30 sistemas con capitales en los bordes del grafo.
- 3 sistemas contiguos controlados por cada faccion.
- 3 conflictos iniciales en sistemas neutrales fronterizos.
- Unidades iniciales por faccion: capital, frontera, movimiento y conflicto.
- 6 ordenes de movimiento activas, una por faccion.
- Sin reportes de batalla precargados; los conflictos esperan resultados reales o resolucion admin.

Puertos locales estandar:

```text
API: http://127.0.0.1:54321
Studio: http://127.0.0.1:54323
DB: postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

Comandos de trabajo:

```bash
npm run supabase:start
npm run db:reset
npm run db:sync-env
npm run db:seed:users
npm run dev
```

Usuarios locales de prueba:

```text
admin@rol40k.local / admin-local-123
orcos@rol40k.local / rol40k-local-123
necrones@rol40k.local / rol40k-local-123
guardia-imperial@rol40k.local / rol40k-local-123
culto-genestelar@rol40k.local / rol40k-local-123
sombra-emperador@rol40k.local / rol40k-local-123
guardia-muerte@rol40k.local / rol40k-local-123
```

Las entidades principales mantienen UUID como clave primaria real y anaden `slug` unico para seeds reproducibles:

- `factions.slug`
- `systems.slug`
- `system_edges.slug`
- `campaign_units.slug`
- `unit_templates.slug`
- `conflicts.slug`

La aplicacion carga Supabase si hay `.env.local` y una sesion autenticada. Si Supabase no esta configurado o no hay sesion, usa los mocks como fallback visual de desarrollo.

RLS local:

- Datos publicos del mapa visibles para `anon` y `authenticated`.
- Recursos, unidades, colas y movimientos visibles solo para miembros de faccion o admin.
- Admin con acceso total.
- Jugadores sin escritura directa sobre recursos, tropas o control territorial.
- Mutaciones criticas solo mediante RPC segura.

Funciones implementadas para backend autoritativo:

```text
resolve_resource_ticks()
resolve_building_construction()
resolve_movement_orders()
resolve_recruitment_queue()
resolve_unit_recovery_queue()
resolve_technology_research()
start_building_construction(system_id, building_template_id)
recruit_unit_at_building(system_building_id, unit_template_id, quantity)
resupply_unit_at_building(system_building_id, campaign_unit_id)
heal_unit_at_building(system_building_id, campaign_unit_id, heal_quantity) -- alias legacy
cancel_recruitment_queue(queue_id)
cancel_unit_recovery_queue(queue_id)
start_technology_research(technology_node_id)
create_movement_order(unit_selections, path_system_ids)
cancel_movement_order(order_id)
merchant_trade(resource_key, direction, trade_quantity)
create_trade_offer(offer_type, resource_key, resource_amount, gold_amount)
accept_trade_offer(offer_id)
cancel_trade_offer(offer_id)
submit_battle_report(conflict_id, report_payload)
admin_resolve_battle(target_conflict_id, winner_faction_id, final_controller_faction_id, survivors, wounds_remaining, post_battle_blocked_until, narrative_notes)
```

Supabase Studio en `http://127.0.0.1:54323` es la herramienta recomendada para ver y editar la base local durante desarrollo.

---

## 17. Vistas principales

### 17.1 Login

Pantalla simple:

- Email/password o magic link.
- Al entrar se carga facción asociada.
- Si admin, mostrar acceso a panel admin.

### 17.2 Dashboard principal / mapa galáctico

Contiene:

- Barra superior de recursos.
- Mapa PixiJS fullscreen.
- Botón/panel de reclutamiento.
- Botón/panel de tecnología.
- Botón/panel de tropas.
- Botón/panel de recursos.
- Panel lateral de sistema.
- Indicadores de colas activas.
- Indicadores de movimientos propios activos.

### 17.3 Panel de tropas

Muestra:

- Ejércitos propios.
- Ubicación.
- Estado:
  - Listo.
  - Moviéndose.
  - En guerra.
- Puntos totales.
- Unidades dentro.
- XP y enhancements.

### 17.4 Panel de reclutamiento

Muestra:

- Recursos disponibles.
- Catálogo de unidades.
- Costes.
- Tiempo.
- Requisitos tecnológicos.
- Unidades bloqueadas mostradas en gris con su requisito.
- Cola activa.
- Cuenta atrás.

### 17.4.1 Panel de tecnología

Muestra:

- Árbol tecnológico común `common-v1`.
- Progreso propio de la facción.
- Coste en Componentes tecnológicos.
- Tiempo de investigación.
- Requisitos entre nodos.
- Efectos y desbloqueos.
- Estado visual: bloqueada, disponible, investigando, desbloqueada.
- Botón para iniciar investigación mediante RPC segura.

Comportamiento implementado actual del arbol:

- El arbol se abre centrado en `fundacion-planetaria`.
- No debe abrir con ningun nodo seleccionado por defecto; el usuario decide que nodo consultar.
- Incluye controles compactos de zoom, alejamiento y recentrado.
- En movil el detalle del nodo se abre como drawer/panel inferior con scroll tactil real y boton de investigar accesible.

### 17.5 Panel de comercio

Muestra:

- Mercader con avatar.
- Compra/venta de Suministro, Mineral, Material Industrial y Uridium contra Oro.
- Bloqueo si la faccion no tiene Camara de Comercio activa.
- Comercio estelar entre jugadores.
- Creacion de ofertas de compra/venta.
- Listado de ofertas abiertas.
- Aceptar o cancelar ofertas segun permisos.
- Comision de Oro visible.

El listado antiguo de recursos detallados queda obsoleto:

- Recursos actuales.
- Producción diaria.
- Cadencia temporal de producción.
- Sistemas que producen recursos planetarios.
- Reliquias.
- Tecnología.
- Objetos especiales.

### 17.6 Vista de misión

Muestra:

- Título.
- Mapa de misión subido por admin.
- Descripción.
- Objetivos.
- Reglas especiales.
- Victoria.
- Recompensas/notas.

### 17.7 Admin panel

Debe permitir:

- Editar sistemas.
- Editar rutas.
- Editar producción.
- Editar recursos.
- Editar facciones.
- Editar tropas.
- Subir/editar misiones.
- Resolver conflictos y reportes.
- Revisar y confirmar reportes de batalla.
- Bloquear sistemas.
- Configurar cadencia de producción.
- Ver logs.

---

## 18. PixiJS: comportamiento del mapa

### 18.1 Capas recomendadas

El mapa PixiJS debería tener capas:

1. `backgroundLayer`
   - fondo oscuro,
   - estrellas,
   - nebulosas.

2. `routesLayer`
   - aristas/rutas.

3. `systemsLayer`
   - nodos de sistemas.

4. `effectsLayer`
   - glow,
   - pulsos,
   - guerra,
   - selección.

5. `movementLayer`
   - movimientos propios animados.

6. `labelsLayer`
   - nombres de sistemas,
   - costes,
   - tooltips ligeros si procede.

### 18.2 Interacción

- Zoom con rueda.
- Pan arrastrando.
- Hover en sistema.
- Click en sistema.
- Click en ruta opcional.
- Modo movimiento.
- Escape cancela modo movimiento.
- Click fuera cierra panel si procede.

### 18.3 Selección de sistema

Al seleccionar:

- Sistema gana anillo pulsante.
- Rutas adyacentes se resaltan.
- Panel lateral se abre.
- Cámara puede hacer pequeño focus/zoom, sin ser molesto.

### 18.4 Modo movimiento

Cuando se activa modo movimiento:

- Sistema origen destacado.
- Destinos válidos iluminados.
- Destinos inválidos apagados.
- Rutas válidas resaltadas.
- Coste de Uridium visible.
- Sistema bloqueado con candado.
- Al click destino, abrir confirmación React.

---

## 19. Assets y diseño visual

### 19.1 Fuentes de assets

Se pueden usar:

- CraftPix para iconos de recursos, reliquias, tecnología y UI sci-fi si encaja.
- Kenney como fuente secundaria de assets CC0 si falta algo.
- Game-icons.net solo si hacen falta iconos puntuales, respetando créditos.
- Fondos espaciales sutiles de packs con licencia clara.

### 19.2 Qué buscar

Para UI:

```text
space game UI
sci-fi GUI
sci-fi game interface
space HUD
futuristic UI
holographic UI
sci-fi panel
sci-fi modal window
```

Para iconos:

```text
sci-fi resource icons
cyberpunk resource icons
space resource icons
mineral icon game
crystal resource icon
energy crystal icon
oxygen supply icon
artifact icon sci-fi
technology icon game
```

Para fondo:

```text
dark space background
nebula background game
space parallax background
starfield background
seamless space background
galaxy background 2D
```

Para marcadores:

```text
sci-fi map markers
holographic map markers
target marker UI
radar blip icon
navigation marker
space map icons
faction marker
```

### 19.3 Reglas de coherencia

No mezclar demasiados packs.

Ideal:

- 1 pack principal de UI.
- 1 pack principal de iconos.
- 1 fondo o textura espacial.
- El mapa se genera con código.

Evitar collage visual.

---

## 20. Reglas de campaña implementadas en la web

### 20.1 Control territorial

- Un sistema puede ser neutral, controlado o en guerra.
- El controlador es siempre público.
- El control se ajusta tras el reporte de batalla.
- Si atacante gana, el sistema puede pasar al atacante.
- Si defensor gana, mantiene controlador.
- Si los reportes coinciden, el backend puede aplicar el resultado automáticamente.
- Si hay discrepancia, el admin decide.
- Admin puede poner bloqueo temporal posterior.

### 20.2 Guerra

Cuando tropas llegan a un sistema enemigo:

- El sistema pasa a `war`.
- Se crea conflicto.
- El sistema queda bloqueado mientras exista batalla pendiente.
- La batalla se juega fuera de la aplicación.
- Los participantes o el admin reportan el resultado.

### 20.3 Neutral

Cuando tropas llegan a neutral:

- Puede crearse conflicto o evento de conquista.
- El sistema queda bloqueado si requiere batalla.
- Los participantes o el admin reportan el resultado.
- El admin decide si hay discrepancias.
- En primera versión, tratar como `war` pendiente si requiere batalla.

### 20.4 Bajas

- No automatizar.
- Se ajustan mediante reporte de batalla o edición admin.

### 20.5 XP

- Admin añade XP manualmente.
- Admin añade enhancements narrativos manualmente.
- También se pueden registrar XP y enhancements dentro del reporte de batalla si el admin lo confirma.

---

## 21. Roadmap de implementación

### Fase 1: Prototipo visual offline

Objetivo:

- Mapa PixiJS con datos mock.
- 20 sistemas.
- Rutas.
- Zoom/pan.
- Selección de sistema.
- Panel lateral React.
- Estados visuales:
  - neutral,
  - controlled,
  - war,
  - blocked.

Sin login todavía.

### Fase 2: Supabase y datos reales

- Crear tablas base.
- Cargar sistemas desde DB.
- Cargar rutas desde DB.
- Cargar facciones.
- Cargar control territorial.
- Cargar producción.

### Fase 3: Login y facciones

- Supabase Auth.
- Perfil.
- Asociación usuario-facción.
- Vista distinta para admin/player.
- RLS inicial.

### Fase 4: Recursos

- Barra superior.
- Oro como recurso visible.
- Comercio en el panel de mando operativo.
- Mercader con compra/venta contra Oro.
- Comercio estelar entre jugadores con ofertas y comision.
- Producción diaria por tick backend de 24h.
- Cron/lazy processing de recursos.
- Admin puede configurar cadencia de producción.
- Logs de ticks de producción.

### Fase 5: Reclutamiento

- Unit templates.
- Menú de reclutamiento.
- Descuento de recursos vía RPC.
- Validación de tecnologías requeridas.
- Cola temporizada.
- Cron/lazy resolve.
- Aparición en capital.

### Fase 5.5: Árbol tecnológico

- Componentes tecnologicos como recurso especial del arbol.
- Tabla de nodos, prerequisitos, progreso por facción y efectos.
- Pantalla visual de árbol tecnológico.
- `start_technology_research()`.
- `resolve_technology_research()`.
- Desbloqueo real de unidades reclutables.
- Bonos pasivos de coste y tiempo de reclutamiento.
- Catálogo mínimo de edificios futuros desbloqueables.

### Fase 6: Tropas y movimiento

- Crear unidades Warhammer.
- Ver tropas propias.
- Modo movimiento.
- Validación backend.
- Coste Uridium.
- Movement orders.
- Cron/lazy arrival.
- Sistema pasa a guerra si corresponde.

### Fase 7: Misiones narrativas

- Tabla missions.
- Subida de imagen.
- Vista de misión.
- Panel admin para editar misión.

### Fase 8: Admin avanzado

- Resolver batalla.
- Confirmar reportes de batalla.
- Cambiar controlador.
- Bloquear sistema.
- Borrar tropas.
- Añadir XP.
- Añadir enhancements.
- Logs.

### Fase 9: Polish visual

- Animaciones.
- Partículas.
- Sonidos opcionales.
- Mejora de paneles.
- Responsive.
- Optimización PixiJS.

### Fase 10: Futuro

- Espionaje.
- Reliquias con efectos.
- Mejoras de sistemas.
- Construcciones.
- Eventos narrativos.
- Diplomacia.
- Historial de campaña público.

---

## 23. Consideraciones legales/prácticas

Es una web privada para amigos y sin comercialización.

Aun así:

- Evitar publicar la web de forma abierta.
- Evitar usar arte oficial de Games Workshop si se puede.
- Si se usan imágenes privadas, mantener acceso cerrado.
- Preferir assets con licencia clara.
- Si se usan logos/facciones por comodidad privada, que no se comercialice ni se presente como producto oficial.
- No usar textos oficiales copiados extensamente.

---

## 24. Nomenclatura importante

Usar estos nombres de recursos:

- `Suministro vital`
- `Mineral`
- `Honor`
- `Oro`
- `Material Industrial`
- `Uridium`
- `Componentes tecnológicos`

Estados de sistema:

- `Neutral`
- `Controlado`
- `En guerra`

Estados internos sugeridos:

```text
neutral
controlled
war
```

Estados de unidad:

```text
ready
moving
in_war
recovering
destroyed
```

Estados de reclutamiento:

```text
queued
completed
cancelled
```

Estados de movimiento:

```text
moving
arrived
cancelled
```

Estados de tecnología:

```text
available
researching
unlocked
```

---

## 25. Requisitos de calidad

La aplicación debe priorizar:

1. Claridad de interfaz.
2. Seguridad de acciones.
3. Coherencia visual.
4. Fluidez del mapa.
5. Simplicidad administrativa.
6. Fácil edición manual por admin.
7. No sobreautomatizar Warhammer.
8. Mantener el juego narrativo y flexible.

La web debe ser una herramienta para potenciar la campaña, no un sistema rígido que obligue a adaptar toda la campaña a la app.

---

## 26. Resumen final para implementación

Construir una aplicación web privada de campaña Warhammer 40K con:

- Next.js + React + TypeScript.
- PixiJS para mapa galáctico WebGL.
- Supabase/Postgres/Auth/RLS/Realtime/Cron para backend.
- Mapa táctico abstracto:
  - nodos luminosos,
  - halos,
  - anillos de facción,
  - rutas con coste de Uridium,
  - estados visuales,
  - selección interactiva.
- Login por jugador/facción.
- Recursos:
  - Suministro vital,
  - Mineral,
  - Honor,
  - Oro,
  - Material Industrial,
  - Uridium,
  - Componentes tecnológicos.
- Produccion diaria por edificios activos mediante tick backend de 24h.
- Construccion planetaria con slots, costes y cola.
- Edificios de sistemas enemigos ocultos por niebla de guerra: el jugador ve slot ocupado, no el edificio concreto.
- Reclutamiento temporizado desde edificios militares.
- Curacion de miniaturas heridas desde edificios militares.
- Comercio ligado a Camara de Comercio.
- Arbol tecnologico con desbloqueo de unidades, edificios y bonos.
- Movimiento temporizado.
- Reportes de batalla por jugadores/admin.
- Sistemas bloqueados mientras haya batalla pendiente.
- Tropas ocultas por niebla de guerra.
- Control territorial público.
- Misiones narrativas con imagen subida por admin.
- Admin panel para gestionar campaña, conflictos y reportes.
- Backend autoritativo con RPC/funciones seguras.
- Cronos controlados por servidor.
- UX de videojuego, no dashboard cutre.

Fin del documento.
