# Informe de balance de facciones

Generado por `npm run units:generate`.

## Reglas aplicadas

- Conversion: `supply + 2*minerals + 5*honor + 5*gold = points`.
- Material Industrial y Uridium no se usan para reclutar unidades.
- Capital + adyacente objetivo: 19 puntos de reclutamiento/dia.
- Uridium y Material Industrial tienen economia separada.
- La campana empieza sin edificios construidos.
- Objetivo de unidades con oro: 40% por faccion.
- Las primeras infanterias de tier 1 cuestan solo Suministro vital.
- Las variantes de miniaturas/equipo escalan desde el perfil de coste de la plantilla base.

## Resumen por faccion jugable

| Faccion | Unidades | Unidades con oro | Puntos catalogo | Suministro | Mineral | Honor | Oro |
|---|---:|---:|---:|---:|---:|---:|---:|
| adeptus-custodes | 51 | 20/20 (39%) | 16160 | 3731 | 4077 | 556 | 299 |
| cultos-genestealer | 41 | 16/16 (39%) | 3395 | 1691 | 337 | 166 | 40 |
| legiones-daemonicas | 19 | 8/8 (42%) | 2720 | 1234 | 223 | 170 | 38 |
| necrones | 55 | 22/22 (40%) | 7570 | 2567 | 1369 | 334 | 119 |
| space-marines | 85 | 34/34 (40%) | 10565 | 3990 | 2415 | 226 | 123 |

## Infanteria inicial solo suministro

- necrones: Immortals -> 70 Suministro
- necrones: Necron Warriors -> 80 Suministro
- legiones-daemonicas: Blue Horrors -> 125 Suministro
- legiones-daemonicas: Pink Horrors -> 150 Suministro
- cultos-genestealer: Neophyte Hybrids -> 70 Suministro
- cultos-genestealer: Hybrid Metamorphs -> 75 Suministro
- space-marines: Assault Intercessor Squad -> 75 Suministro
- space-marines: Heavy Intercessor Squad -> 100 Suministro
- space-marines: Intercessor Squad -> 80 Suministro
- space-marines: Tactical Squad -> 140 Suministro
- space-marines: Incursor Squad -> 85 Suministro
- space-marines: Infiltrator Squad -> 110 Suministro
- space-marines: Scout Squad -> 65 Suministro
- adeptus-custodes: Custodian Guard -> 170 Suministro
- adeptus-custodes: Prosecutors -> 45 Suministro
- adeptus-custodes: Vigilators -> 50 Suministro
- adeptus-custodes: Witchseekers -> 50 Suministro

## Produccion natural inicial

| Faccion | Capital | Pts capital | Adyacente | Pts adyacente | Total | Material capital | Uridium adyacente |
|---|---|---:|---|---:|---:|---:|---:|
| legiones-daemonicas | mordax | 13 | drusus | 6 | 19 | 5 | 0.3 |
| space-marines | sa-cea-gate | 13 | lyra-terminus | 6 | 19 | 5 | 0.3 |
| necrones | thokt-vault | 13 | novem | 6 | 19 | 5 | 0.3 |
| adeptus-custodes | kharon-prime | 13 | helios-drift | 6 | 19 | 5 | 0.3 |
| cultos-genestealer | blackglass | 13 | red-sabbath | 6 | 19 | 5 | 0.3 |

## Validaciones rapidas

- Unidades con conversion de puntos invalida: 0.
- Unidades con Material Industrial o Uridium: 0.
- Facciones importadas desde catalogo: 8.
