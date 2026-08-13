# Informe de balance de facciones

Generado por `npm run units:generate`.

## Reglas aplicadas

- Conversion: `supply + 2*minerals + 5*honor + 5*gold = points`.
- Material Industrial y Uridium no se usan para reclutar unidades.
- Capital + adyacente objetivo: 16 puntos de reclutamiento/dia.
- Uridium y Material Industrial tienen economia separada.
- La campana empieza sin edificios construidos.
- Objetivo de unidades con oro: 40% por faccion.
- Las primeras infanterias de tier 1 cuestan solo Suministro vital.
- Las variantes de miniaturas/equipo escalan desde el perfil de coste de la plantilla base.

## Resumen por faccion jugable

| Faccion | Unidades | Unidades con oro | Puntos catalogo | Suministro | Mineral | Honor | Oro |
|---|---:|---:|---:|---:|---:|---:|---:|
| adeptus-custodes | 51 | 20/20 (39%) | 16160 | 3727 | 4084 | 557 | 296 |
| cultos-genestealer | 41 | 16/16 (39%) | 3360 | 1661 | 337 | 165 | 40 |
| legiones-daemonicas | 19 | 8/8 (42%) | 2655 | 1210 | 220 | 166 | 35 |
| necrones | 55 | 22/22 (40%) | 7575 | 2604 | 1383 | 326 | 115 |
| space-marines | 85 | 34/34 (40%) | 10785 | 4067 | 2454 | 232 | 130 |

## Infanteria inicial solo suministro

- necrones: Immortals -> 70 Suministro
- necrones: Necron Warriors -> 90 Suministro
- legiones-daemonicas: Blue Horrors -> 125 Suministro
- legiones-daemonicas: Pink Horrors -> 140 Suministro
- cultos-genestealer: Neophyte Hybrids -> 65 Suministro
- cultos-genestealer: Hybrid Metamorphs -> 70 Suministro
- space-marines: Assault Intercessor Squad -> 75 Suministro
- space-marines: Heavy Intercessor Squad -> 100 Suministro
- space-marines: Intercessor Squad -> 80 Suministro
- space-marines: Tactical Squad -> 140 Suministro
- space-marines: Incursor Squad -> 80 Suministro
- space-marines: Infiltrator Squad -> 100 Suministro
- space-marines: Scout Squad -> 70 Suministro
- adeptus-custodes: Custodian Guard -> 160 Suministro
- adeptus-custodes: Prosecutors -> 40 Suministro
- adeptus-custodes: Vigilators -> 45 Suministro
- adeptus-custodes: Witchseekers -> 45 Suministro

## Produccion natural inicial

| Faccion | Capital | Pts capital | Adyacente | Pts adyacente | Total | Material capital | Uridium adyacente |
|---|---|---:|---|---:|---:|---:|---:|
| legiones-daemonicas | mordax | 12 | drusus | 4 | 16 | 5 | 0.3 |
| space-marines | sa-cea-gate | 11 | lyra-terminus | 5 | 16 | 5 | 0.3 |
| necrones | thokt-vault | 13 | novem | 3 | 16 | 5 | 0.3 |
| adeptus-custodes | kharon-prime | 11 | helios-drift | 5 | 16 | 5 | 0.3 |
| cultos-genestealer | blackglass | 10 | red-sabbath | 6 | 16 | 5 | 0.3 |

## Validaciones rapidas

- Unidades con conversion de puntos invalida: 0.
- Unidades con Material Industrial o Uridium: 0.
- Facciones importadas desde catalogo: 8.
