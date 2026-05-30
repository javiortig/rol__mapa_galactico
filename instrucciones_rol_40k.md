# Especificación del proyecto: Mapa Estelar de Campaña Warhammer 40K

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
   - Piedra ancestral.
   - Uridium.
7. **Producción de recursos por sistemas controlados.**
8. **Movimiento de tropas entre sistemas.**
9. **Reclutamiento de tropas con cola temporizada estilo Grepolis.**
10. **Tropas reclutadas aparecen en la capital de la facción.**
11. **Misiones narrativas asociadas a sistemas**, con imagen del mapa de misión y explicación.
12. **Niebla de guerra para tropas y movimientos.**
13. **Panel de admin para resolver resultados, editar mapas, recursos, tropas, experiencia y bloqueos.**
14. **Backend autoritativo**: las reglas críticas nunca deben depender solo del frontend.
15. **Cronos gestionados por backend** para producción, movimiento y reclutamiento.

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
- Brillo diferenciado, por ejemplo violeta para Piedra ancestral o dorado/violeta para reliquia.

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

Hay cuatro recursos básicos:

| Recurso | Uso |
|---|---|
| Suministro vital | Reclutar y sostener tropas, especialmente infantería y presencia militar. |
| Mineral | Construir armamento, blindajes, vehículos, fortificaciones y equipamiento pesado. |
| Piedra ancestral | Recurso raro para unidades importantes, élites, personajes, superpesados, reliquias y elementos especiales. |
| Uridium | Recurso de movimiento estratégico entre sistemas. |

Más adelante se añadirán recursos secundarios, como:

- Tecnología.
- Reliquias.
- Enhancements narrativos.
- Objetos especiales.
- Intel/espionaje.
- Otros recursos narrativos.

### 4.1 Conversión inicial a puntos

La conversión para coste de unidades será:

| Recurso | Valor equivalente |
|---|---:|
| 1 Suministro vital | 5 puntos |
| 1 Mineral | 10 puntos |
| 1 Piedra ancestral | 25 puntos |

Fórmula:

```text
Coste en puntos = 5*Suministro + 10*Mineral + 25*PiedraAncestral
```

Uridium no se usa para comprar unidades normales. Uridium se usa principalmente para movimiento.

### 4.2 Uso de Piedra ancestral

Piedra ancestral debe ser rara y usarse para:

- Personajes.
- Élites.
- Unidades especiales.
- Dreadnoughts.
- Superpesados.
- Monstruos importantes.
- Unidades icónicas.
- Reliquias.
- Desbloqueos narrativos.

No todas las unidades básicas deben costar Piedra ancestral.

### 4.3 Producción

Cada sistema produce una cantidad diaria de recursos. En base de datos estos valores se guardan como campos `*_per_tick`, pero en la v1 del juego cada tick equivale a 24 horas reales:

- `supply_per_tick`
- `minerals_per_tick`
- `ancestral_stone_per_tick`
- `uridium_per_tick`

La producción diaria total de una facción es la suma de los sistemas que controla.

La cadencia de usuario para la v1 es diaria:

```text
24 horas
```

El admin podrá cambiar esta cadencia más adelante si la campaña necesita avanzar más rápido o más lento.

El panel superior debe mostrar solo los recursos actuales, centrados y sin texto de siguiente tick.

El panel detallado de recursos debe mostrar también:

- Producción diaria total.
- Cadencia actual de producción.
- Sistemas que producen cada recurso.
- Reliquias poseídas.
- Tecnología poseída.
- Objetos especiales.

---

## 5. Tiempo real de campaña

La campaña no usa turnos estratégicos.

Todo el avance importante funciona por tiempo real gestionado por backend:

- Producción de recursos.
- Reclutamiento.
- Movimiento.
- Bloqueos de sistemas.
- Resolución de colas vencidas.

### 5.1 Cronos automáticos

Los cronos deben ser gestionados por backend con timestamps reales:

- `started_at`
- `finishes_at`
- `arrival_at`
- `last_resource_tick_at`
- `next_resource_tick_at`
- `status`

El frontend solo muestra cuenta atrás.

### 5.2 Producción diaria

El backend ejecuta un tick de producción cada 24 horas en la v1.

Valor inicial recomendado:

```text
24 horas
```

En cada tick:

1. Se calcula producción de todos los sistemas controlados.
2. Se suma producción a cada facción.
3. Se registra un log de producción.
4. Se actualizan los paneles de recursos.
5. Se actualizan bloqueos vencidos si aplica.

La producción debe poder resolverse mediante cron y también mediante lazy processing al cargar la app o paneles importantes.

### 5.3 Resolución temporal por backend

El backend debe exponer funciones seguras para procesar tiempo vencido:

```text
resolve_resource_ticks()
resolve_movement_orders()
resolve_recruitment_queue()
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

### 6.3 Reglas del bloqueo

Por ahora:

- Un sistema con batalla pendiente queda bloqueado.
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
  - Piedra ancestral.
  - Uridium.
- Información pública.
- Recursos u objetos especiales avistados.
- Botones de acción según permisos:
  - Mover tropas.
  - Ver misión.
  - Reclutar si aplica.
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

---

## 8. Movimiento de tropas

### 8.1 Principio general

Los jugadores mueven unidades Warhammer concretas, no destacamentos abstractos.

Una orden de movimiento puede incluir una o varias unidades propias que esten `ready`, pertenezcan a la misma faccion y esten en el mismo sistema de origen.

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
- Cadian Shock Troops x3 - 240 pts
- Kasrkin x2 - 210 pts

Acciones:
[Mover tropas]
[Ver misión]
```

#### Paso 2: pulsar "Mover tropas"

Se abre panel o modal:

```text
Mover tropas desde Kharon Prime

Selecciona unidades:
[ ] Cadian Shock Troops x3 - 240 pts
[ ] Kasrkin x2 - 210 pts
[ ] Leman Russ Battle Tank x1 - 145 pts
```

Primera version:

- Seleccion multiple de unidades Warhammer concretas.
- Todas deben estar en el sistema origen.
- Todas deben estar `ready`.
- No se dividen unidades en subunidades.

Mas adelante:

- Permitir dividir unidades si la campana lo necesita.

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
- Las unidades quedan `in_war`.
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
- Tropas supervivientes o bajas.
- Control final del sistema.
- XP o enhancements narrativos si aplica.
- Notas narrativas.
- Duración de bloqueo posterior.

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

Los jugadores pueden gastar recursos para crear tropas.

El reclutamiento tarda tiempo real, estilo Grepolis.

Para test local, los tiempos iniciales son de minutos, no horas.

Al completarse, las tropas aparecen en la capital de la facción.

### 9.2 Menú de reclutamiento

Debe haber un icono/botón fijo, por ejemplo:

```text
Reclutamiento
```

Al pulsarlo se abre un panel con:

- Recursos actuales.
- Lista de unidades disponibles.
- Coste.
- Tiempo de producción.
- Requisitos.
- Botón de reclutar.
- Cola actual.

### 9.3 Datos de una unidad reclutable

Cada unidad debe tener:

- Nombre.
- Facción a la que pertenece.
- Puntos.
- Coste en Suministro vital.
- Coste en Mineral.
- Coste en Piedra ancestral.
- Coste en Uridium si alguna unidad especial lo requiere, aunque normalmente no.
- Tiempo de producción.
- Requisitos opcionales.
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
- Requisitos cumplidos.
- No se exceden reglas de campaña si existen.
- Coste correcto.

Si todo es válido:

- Descuenta recursos.
- Crea fila en `recruitment_queue`.
- Guarda `started_at`.
- Guarda `finishes_at`.
- Estado `queued`.

### 9.5 Al completar reclutamiento

Cuando `now() >= finishes_at`:

- Backend marca la cola como `completed`.
- Crea una fila nueva en `campaign_units` en la capital.
- La unidad queda `ready` y disponible para movimiento.
- Frontend actualiza por Realtime o refetch.

### 9.6 Las bajas

Por ahora, si tropas mueren en batalla:

- Desaparecen.
- Se eliminan mediante reporte de batalla confirmado o edición admin.
- No se automatiza sistema de heridas/reparación.
- No se recuperan automáticamente.

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

## 12. Panel de recursos

### 12.1 Barra superior

Siempre visible:

```text
Suministro vital: 120 | Mineral: 85 | Piedra ancestral: 8 | Uridium: 14
```

Debe tener iconos bonitos.

### 12.2 Panel detallado

Al hacer click, abrir panel:

```text
Recursos actuales

Suministro vital: 120
Producción diaria: +18

Mineral: 85
Producción diaria: +11

Piedra ancestral: 8
Producción diaria: +2

Uridium: 14
Producción diaria: +4

Cadencia de producción: cada 24 horas
```

Debajo:

```text
Objetos especiales

Reliquias:
- Estandarte de la Cruzada Perdida
- Núcleo de Piedra Ancestral

Tecnología:
- Auspex orbital nivel I
- Forja de blindajes ligeros
```

### 12.3 Producción

La producción debe calcularse a partir de sistemas controlados.

No confiar en el frontend.

La cadencia de producción debe ser configurable por admin y gestionada por backend.

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
- Reclutar unidades disponibles.
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
create_movement_order(unit_ids, path_system_ids)
```

El backend calcula y valida.

### 14.2 Funciones backend recomendadas

Crear funciones RPC o endpoints equivalentes:

```text
create_movement_order(unit_ids, path_system_ids)
recruit_unit(unit_template_id, quantity)
resolve_resource_ticks()
resolve_movement_orders()
resolve_recruitment_queue()
submit_battle_report(conflict_id, report_payload)
admin_confirm_battle_report(conflict_id, final_payload)
admin_resolve_battle(conflict_id, winner_faction_id, blocked_days)
admin_update_system_control(system_id, faction_id)
admin_add_experience(unit_id, amount)
admin_delete_unit(unit_id)
admin_create_or_update_mission(...)
```

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
- Insert seguro en cola.

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
```

Así, aunque un cron se retrase, el estado se corrige.

---

## 16. Modelo de datos recomendado

Este es un esquema inicial. Puede adaptarse.

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
- uridium integer default 0
- technology integer default 0
- updated_at timestamptz
```

Aunque Tecnología sea secundaria/futura, se puede dejar campo.

### 16.7 system_production

```sql
system_production
- system_id uuid primary key references systems(id)
- supply_per_tick integer default 0
- minerals_per_tick integer default 0
- ancestral_stone_per_tick integer default 0
- uridium_per_tick integer default 0
- technology_per_tick integer default 0
```

La cadencia global de producción se puede guardar en una tabla de configuración:

```sql
campaign_settings
- id text primary key default 'default'
- resource_tick_interval_hours integer default 24
- movement_edge_duration_seconds integer default 120
- conflict_block_duration_minutes integer default 30
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
- quantity integer default 1
- experience integer default 0
- rank text nullable
- enhancement_text text nullable
- notes text nullable
- current_system_id uuid nullable references systems(id)
- status text check in ('ready', 'moving', 'in_war')
- is_visible_publicly boolean default false
- created_at timestamptz
- updated_at timestamptz
```

Cada fila representa una unidad Warhammer concreta movible en el mapa.

### 16.9 movement_order_units

```sql
movement_order_units
- movement_order_id uuid references movement_orders(id)
- unit_id uuid references campaign_units(id)
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
- supply_cost integer
- minerals_cost integer
- ancestral_stone_cost integer
- uridium_cost integer default 0
- technology_cost integer default 0
- recruitment_time_seconds integer
- requirements jsonb nullable
- notes text nullable
- is_available boolean default true
```

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
- uridium_cost integer
- technology_cost integer default 0
- started_at timestamptz
- finishes_at timestamptz
- status text check in ('queued', 'completed', 'cancelled')
- created_at timestamptz
```

### 16.12 movement_orders

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
- created_at timestamptz
```

### 16.13 conflicts

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

### 16.14 battle_reports

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

### 16.15 missions

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

### 16.16 relics / special objects

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

### 16.17 logs

```sql
campaign_logs
- id uuid primary key
- actor_user_id uuid nullable references profiles(id)
- faction_id uuid nullable references factions(id)
- action_type text
- payload jsonb
- created_at timestamptz
```

### 16.18 Implementacion local real

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
resolve_movement_orders()
resolve_recruitment_queue()
recruit_unit(unit_template_id, quantity)
create_movement_order(unit_ids, path_system_ids)
submit_battle_report(conflict_id, report_payload)
admin_resolve_battle(target_conflict_id, winner_faction_id, final_controller_faction_id, post_battle_blocked_until, narrative_notes)
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
- Cola activa.
- Cuenta atrás.

### 17.5 Panel de recursos

Muestra:

- Recursos actuales.
- Producción diaria.
- Cadencia temporal de producción.
- Sistemas que producen.
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
- Panel de recursos.
- Producción diaria por tick backend de 24h.
- Cron/lazy processing de recursos.
- Admin puede configurar cadencia de producción.
- Logs de ticks de producción.

### Fase 5: Reclutamiento

- Unit templates.
- Menú de reclutamiento.
- Descuento de recursos vía RPC.
- Cola temporizada.
- Cron/lazy resolve.
- Aparición en capital.

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
- Tecnología.
- Reliquias con efectos.
- Mejoras de sistemas.
- Construcciones.
- Eventos narrativos.
- Diplomacia.
- Historial de campaña público.

---

## 22. No objetivos actuales

No implementar por ahora:

- Editor interno de mapas narrativos.
- Simulador de combate de Warhammer 40K.
- Automatización de bajas.
- Sistema complejo de heridas/reparación.
- Espionaje.
- IA de enemigos.
- Generación procedural completa del mapa de campaña.
- Mercado entre jugadores.
- Monetización.
- Uso público.
- Integración oficial con Games Workshop.

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
- `Piedra ancestral`
- `Uridium`
- `Tecnología` como recurso secundario/futuro

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
  - Piedra ancestral,
  - Uridium.
- Producción diaria por sistemas controlados mediante tick backend de 24h.
- Reclutamiento temporizado.
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
