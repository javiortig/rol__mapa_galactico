---
title: "Chuleta Para Explicar El Proyecto"
subtitle: "Mapa Galactico Rol 40K"
author: "Guion rápido para video y onboarding técnico"
date: "2026-06-11"
lang: es
geometry: margin=15mm
fontsize: 10pt
colorlinks: true
---

# 1. Qué Es Este Proyecto

**Idea en una frase:** una app web para gestionar una campaña de Warhammer 40K en tiempo real, con mapa galáctico, facciones, recursos, unidades, edificios, tecnología, comercio y reportes de batalla.

**Puntos clave para decir en el video:**

- No es un simulador automático de combate.
- Las batallas se juegan fuera de la app, en mesa o en la vida real.
- La app gestiona el estado persistente de la campaña.
- Todo lo importante lo valida el backend.
- La interfaz está pensada como videojuego táctico: mapa primero, paneles, colas, tiempos y recursos.

**Qué enseñar en pantalla:**

- Login.
- Mapa galáctico.
- Panel de un sistema.
- Recursos superiores.
- Edificios.
- Tecnología.
- Comercio.

\newpage

# 2. Stack Tecnico

**Frontend**

- Next.js + React + TypeScript.
- Tailwind CSS.
- Componentes UI locales.
- PixiJS para el mapa galáctico.
- Zustand para estado local de UI/mapa.
- TanStack Query para estado de servidor.

**Backend y datos**

- Supabase local y cloud.
- Postgres.
- Supabase Auth.
- RLS.
- RPCs SQL autoritativas.
- Seeds para estado inicial.

**Archivos importantes**

```text
src/domain/campaign.ts
src/features/campaign/api/campaign-repository.ts
src/features/campaign/components/campaign-shell.tsx
src/features/galaxy-map/components/galaxy-map.tsx
supabase/migrations
supabase/seed.sql
instrucciones_rol_40k.md
```

**Mensaje para el equipo:** antes de implementar una feature grande, leer `instrucciones_rol_40k.md`.

\newpage

# 3. Cómo Arrancar En Local

**Requisitos**

- Docker Desktop instalado y abierto.
- Node.js instalado.
- Estar en la raíz del proyecto.

```bash
cd "c:\Users\soyun\Desktop\rol 40k"
```

**Primer arranque**

```bash
npm install
npm run supabase:start
npm run db:sync-env
npm run db:reset
npm run db:seed:users
npm run dev
```

**Arranque normal**

```bash
npm run supabase:start
npm run dev
```

**URLs locales**

```text
Web: http://localhost:3000
Supabase Studio: http://127.0.0.1:54323
Supabase API: http://127.0.0.1:54321
DB: postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

**Usuarios de prueba**

```text
admin@rol40k.local / admin-local-123
legiones-daemonicas@rol40k.local / rol40k-local-123
agentes-imperium@rol40k.local / rol40k-local-123
cultos-genestealer@rol40k.local / rol40k-local-123
aeldari@rol40k.local / rol40k-local-123
space-marines@rol40k.local / rol40k-local-123
adeptus-custodes@rol40k.local / rol40k-local-123
necrones@rol40k.local / rol40k-local-123
```

\newpage

# 4. Estructura Del Repositorio

```text
src/app
```

Rutas Next.js: home, login y admin.

```text
src/domain
```

Tipos centrales de campaña. Si una entidad cambia, normalmente empieza aquí.

```text
src/features
```

Cada feature tiene su carpeta:

- `campaign`: shell principal, snapshot, paneles generales.
- `galaxy-map`: mapa PixiJS.
- `movement`: rutas, pathfinding y RPC de movimiento.
- `buildings`: construcción, edificios, reclutamiento y reabastecimiento.
- `technology`: árbol tecnológico.
- `trade`: mercader y comercio estelar.
- `battle-reports`: reportes de batalla.
- `admin`: herramientas admin.

```text
src/components/ui
```

Botones, badges, paneles, iconos de recursos.

```text
src/mocks/campaign-data.ts
```

Fallback visual de desarrollo. No es fuente de verdad.

```text
supabase
```

Migraciones, seed, configuración local y cron de producción.

\newpage

# 5. Flujo De Datos

**Lectura principal**

```text
Supabase -> campaign-repository.ts -> CampaignSnapshot -> TanStack Query -> UI
```

**Archivo clave**

```text
src/features/campaign/api/campaign-repository.ts
```

Este archivo:

- llama a Supabase;
- ejecuta resolvers lazy;
- lee tablas;
- transforma `snake_case` SQL a `camelCase` frontend;
- devuelve `CampaignSnapshot`.

**Mutaciones**

El frontend no modifica tablas críticas directamente. Llama RPCs:

```text
create_movement_order(...)
cancel_movement_order(...)
recruit_unit_at_building(...)
resupply_unit_at_building(...)
cancel_recruitment_queue(...)
start_building_construction(...)
start_technology_research(...)
create_trade_offer(...)
accept_trade_offer(...)
submit_battle_report(...)
```

Tras una mutacion:

```text
queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] })
```

\newpage

# 6. Reglas De Juego Implementadas

**Tiempo real**

- No hay turnos estratégicos.
- Movimiento, reclutamiento, construcción, tecnología y bloqueos funcionan con timestamps.
- Los resolvers backend completan colas vencidas.

**Unidades**

- Las unidades son `campaign_units`.
- No hay ejércitos abstractos como entidad jugable principal.
- Cada unidad tiene:
  - miniaturas actuales: `quantity`;
  - tamaño completo: `startingQuantity`;
  - heridas agregadas: `woundsTaken`;
  - estado: `ready`, `moving`, `in_war`, `recovering`, etc.
- Las unidades no se dividen al mover.

**Movimiento**

- Selecciónas sistema.
- Pulsas mover.
- Selecciónas unidades completas.
- Trazas ruta óptima o manual.
- Pagas Uridium.
- Puedes cancelar movimiento con 50% de reembolso.

**Batallas**

- Se juegan fuera de la app.
- El sistema queda bloqueado.
- Se reportan supervivientes y heridas.
- Si reportes coinciden, se resuelve automáticamente.
- Si no, decide admin.

\newpage

# 7. Recursos, Edificios Y Producción

**Recursos visibles**

- Suministro vital.
- Mineral.
- Honor.
- Oro.
- Material Industrial.
- Uridium.

**Componentes tecnológicos**

- Solo se ven dentro del árbol tecnológico.
- No se producen en planetas.

**Edificios**

- Cada sistema tiene slots.
- Capitales: 6 slots.
- Resto: 3 slots.
- No se puede construir mas de un edificio del mismo tipo por planeta.
- Producción diaria viene de edificios activos.

**Edificios militares**

- Barracon de Infanteria.
- Cuartel de Mando.
- Taller de Guerra.
- Nido de Bestias.

Desde ellos se recluta y se reabastecen unidades compatibles.

**Reabastecimiento**

- Restaura la unidad completa.
- `quantity = startingQuantity`.
- `woundsTaken = 0`.
- Coste: mitad del coste completo original, redondeando hacia arriba.

\newpage

# 8. Comercio Y Tecnología

**Comercio**

Requiere Cámara de Comercio activa.

**Mercader**

- Compra/vende suministro, mineral, material industrial y Uridium.
- No comercia Honor ni componentes tecnológicos.
- Vende al doble.
- Compra a mitad de valor.

**Comercio estelar**

- Ofertas entre jugadores.
- Recurso contra Oro.
- Recursos comerciables:
  - Suministro.
  - Mineral.
  - Material Industrial.
  - Uridium.
- Publicar oferta reserva recursos.
- Aceptar oferta solo valida coste del aceptante.
- Cancelar oferta devuelve reserva.

**Tecnología**

- Árbol común `common-v1`.
- Progreso independiente por facción.
- Desbloquea unidades, edificios y bonos.
- Solo una investigación activa por facción.

\newpage

# 9. Base De Datos

**Carpetas**

```text
supabase/migrations
supabase/seed.sql
supabase/production-cron.sql
```

**Regla de oro:** si cambia el esquema, crear una migracion nueva.

**No editar producción a mano salvo urgencia.**

**Seed**

`supabase/seed.sql` define:

- facciones;
- sistemas;
- rutas;
- edificios iniciales;
- recursos;
- unidades;
- movimientos;
- conflictos;
- tecnologías;
- ofertas de comercio demo.

**Supabase Studio**

Usar para inspeccionar datos locales:

```text
http://127.0.0.1:54323
```

**Cuando cambiar seed**

- Si cambia el estado inicial de campaña.
- Si se añaden nuevas facciones, sistemas o plantillas.
- Si una feature necesita datos demo.

\newpage

# 10. Proceso De Trabajo Con Ramas

**Crear feature branch**

```bash
git checkout main
git pull
git checkout -b feature/nombre-corto
```

**Durante el desarrollo**

- Mantener cambios pequeños y coherentes.
- Si se toca backend, crear migracion.
- Si se toca contrato de datos, actualizar tipos y mapper.
- Si se toca gameplay, actualizar `instrucciones_rol_40k.md`.

**Antes de PR**

```bash
npm run typecheck
npm run lint
npm run build
```

Si se toca base de datos:

```bash
npm run db:reset
npm run db:seed:users
```

**Subir rama**

```bash
git add .
git commit -m "feat: descripcion corta"
git push origin feature/nombre-corto
```

Crear PR hacia `main`.

\newpage

# 11. Checklist Para Cada Feature

**Si cambio UI**

- Revisar desktop.
- Revisar móvil.
- Revisar iPhone Safari si hay paneles o scroll.
- Evitar modales anidados raros.

**Si cambio datos**

- `src/domain/campaign.ts`.
- `campaign-repository.ts`.
- migracion SQL.
- `seed.sql`.
- mocks si aplica.

**Si cambio reglas**

- Actualizar `instrucciones_rol_40k.md`.
- Confirmar que backend valida la regla.
- No confiar solo en UI.

**Si cambio una RPC**

- Migracion nueva.
- API frontend en `src/features/*/api`.
- Invalidar snapshot tras exito.
- Probar usuario normal y admin.

**Checks finales**

```bash
npm run typecheck
npm run lint
npm run build
```

\newpage

# 12. Guion Rapido Para El Video

1. "Este proyecto es una campaña 40K persistente en tiempo real."
2. "La app no resuelve combates; registra mapa, recursos, tropas y resultados."
3. "El frontend está en Next/React y el backend en Supabase/Postgres."
4. "El mapa usa PixiJS y se alimenta de un snapshot de campaña."
5. "Toda mutacion importante va por RPC, no por updates directos."
6. "Las features viven separadas en `src/features`."
7. "La base se controla con migraciones y seed."
8. "Para arrancar local solo hace falta Docker Desktop abierto y los comandos del README."
9. "Cada feature nueva debe ir en su propia rama."
10. "Antes de mergear: typecheck, lint, build y, si toca DB, reset local."

**Cierre recomendado**

"La prioridad al colaborar aquí es no romper el contrato entre reglas de campaña, base de datos y UI. Si cambia una regla, debe cambiar backend, frontend, seed y documentacion juntos."

