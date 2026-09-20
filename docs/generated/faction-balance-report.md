# Informe de balance de facciones

Generado por `npm run units:generate`.

## Reglas aplicadas

- Conversion: `supply + 2*minerals + 5*honor + 5*gold = points`.
- Material Industrial y Uridium no se usan para reclutar unidades.
- Capital + adyacente objetivo: 19.5 puntos de reclutamiento/dia.
- Uridium y Material Industrial tienen economia separada.
- La campana empieza sin edificios construidos.
- Por defecto ninguna unidad cuesta Oro; solo lo hacen las excepciones de faccion y las aliadas que cumplen su umbral.
- El Oro ocupa un 25% del coste indicado, o un 20% para Shield-Captains y unidades aliadas elegibles.
- Las excepciones de infanteria basica indicadas cuestan exclusivamente Suministro vital.
- Honor solo aparece en unidades con keyword Caracter.
- Los Characters usan 50% de Honor; Legiones Daemonicas y Cultos Genestealer usan 40%.
- Vehiculos usan Mineral; Monstruos usan 80% Mineral y 20% Suministro; Bestias conservan su perfil de tropas organicas.
- Las variantes conservan exactamente los mismos tipos de recurso que su configuracion minima.
- Los redondeos se completan con el recurso mas barato ya presente en el perfil.

## Resumen por faccion jugable

| Faccion | Unidades | Unidades con oro | Puntos catalogo | Suministro | Mineral | Honor | Oro |
|---|---:|---:|---:|---:|---:|---:|---:|
| adeptus-custodes | 51 | 23 (45%) | 16160 | 2107 | 4468 | 535 | 489 |
| cultos-genestealer | 41 | 11 (27%) | 3395 | 1501 | 503 | 131 | 47 |
| legiones-daemonicas | 19 | 6 (32%) | 2720 | 1022 | 284 | 155 | 71 |
| necrones | 55 | 14 (25%) | 7570 | 1462 | 1677 | 357 | 195 |

## Distribucion de Oro por tipo principal

| Faccion | Tipo | Unidades | Con oro |
|---|---|---:|---:|
| adeptus-custodes | Caracter | 23 | 15 |
| adeptus-custodes | Infanteria | 10 | 2 |
| adeptus-custodes | Vehiculo | 18 | 6 |
| cultos-genestealer | Caracter | 23 | 9 |
| cultos-genestealer | Infanteria | 11 | 2 |
| cultos-genestealer | Monstruo | 3 | 0 |
| cultos-genestealer | Montado | 1 | 0 |
| cultos-genestealer | Vehiculo | 3 | 0 |
| legiones-daemonicas | Bestia | 1 | 0 |
| legiones-daemonicas | Caracter | 13 | 5 |
| legiones-daemonicas | Infanteria | 3 | 0 |
| legiones-daemonicas | Montado | 1 | 1 |
| legiones-daemonicas | Vehiculo | 1 | 0 |
| necrones | Bestia | 4 | 1 |
| necrones | Caracter | 25 | 6 |
| necrones | Infanteria | 9 | 2 |
| necrones | Montado | 3 | 1 |
| necrones | Vehiculo | 14 | 4 |

## Infanteria inicial solo suministro

- necrones: Immortals -> 70 Suministro
- necrones: Necron Warriors -> 80 Suministro
- necrones: Flayed Ones -> 55 Suministro
- legiones-daemonicas: Blue Horrors -> 125 Suministro
- legiones-daemonicas: Pink Horrors -> 150 Suministro
- cultos-genestealer: Acolyte Hybrids with Autopistols -> 70 Suministro
- cultos-genestealer: Neophyte Hybrids -> 70 Suministro
- cultos-genestealer: Hybrid Metamorphs -> 75 Suministro
- adeptus-custodes: Custodian Guard -> 170 Suministro
- adeptus-custodes: Prosecutors -> 45 Suministro
- adeptus-custodes: Vigilators -> 50 Suministro
- adeptus-custodes: Witchseekers -> 50 Suministro

## Unidades con Honor

- necrones: C'tan Shard of the Deceiver -> 33 Honor (50%, Monstruo, Caracter)
- necrones: C'tan Shard of the Nightbringer -> 36 Honor (50%, Monstruo, Caracter)
- necrones: C'tan Shard of the Void Dragon -> 34 Honor (49%, Monstruo, Caracter)
- necrones: Catacomb Command Barge -> 12 Honor (50%, Vehiculo, Caracter)
- necrones: Chronomancer -> 7 Honor (50%, Infanteria, Caracter)
- necrones: Dynastic Conqueror [Crucible] -> 8 Honor (47%, Infanteria, Caracter)
- necrones: Geomancer -> 7 Honor (47%, Infanteria, Caracter)
- necrones: Hexmark Destroyer -> 7 Honor (47%, Infanteria, Caracter)
- necrones: Hyperscientist [Crucible] -> 8 Honor (47%, Infanteria, Caracter)
- necrones: Illuminor Szeras -> 17 Honor (49%, Infanteria, Caracter)
- necrones: Imotekh the Stormlord -> 10 Honor (50%, Infanteria, Caracter)
- necrones: Lokhust Lord -> 7 Honor (50%, Montado, Caracter)
- necrones: Nekrosor Ammentar -> 18 Honor (49%, Infanteria, Caracter)
- necrones: Orikan the Diviner -> 9 Honor (50%, Infanteria, Caracter)
- necrones: Overlord -> 9 Honor (50%, Infanteria, Caracter)
- necrones: Overlord with Translocation Shroud -> 9 Honor (50%, Infanteria, Caracter)
- necrones: Plasmancer -> 5 Honor (45%, Infanteria, Caracter)
- necrones: Psychomancer -> 5 Honor (45%, Infanteria, Caracter)
- necrones: Royal Warden -> 5 Honor (50%, Infanteria, Caracter)
- necrones: Skorpekh Lord -> 9 Honor (50%, Infanteria, Caracter)
- necrones: Technomancer -> 8 Honor (50%, Infanteria, Caracter)
- necrones: The Silent King -> 42 Honor (50%, Vehiculo, Caracter)
- necrones: Transcendent C'tan -> 34 Honor (50%, Monstruo, Caracter)
- necrones: Trazyn the Infinite -> 6 Honor (46%, Infanteria, Caracter)
- necrones: Triarchal Overseer [Crucible] -> 12 Honor (50%, Vehiculo, Caracter)
- legiones-daemonicas: Be'lakor -> 30 Honor (40%, Monstruo, Caracter)
- legiones-daemonicas: Changecaster -> 4 Honor (33%, Infanteria, Caracter)
- legiones-daemonicas: Daemon Prince of Chaos -> 13 Honor (39%, Monstruo, Caracter)
- legiones-daemonicas: Daemon Prince of Chaos with wings -> 15 Honor (39%, Monstruo, Caracter)
- legiones-daemonicas: Daemonic Charioteer [Crucible] -> 9 Honor (38%, Montado, Caracter)
- legiones-daemonicas: Daemonic Herald [Crucible] -> 4 Honor (33%, Infanteria, Caracter)
- legiones-daemonicas: Exalted Flamer -> 5 Honor (38%, Infanteria, Caracter)
- legiones-daemonicas: Fateskimmer -> 7 Honor (37%, Montado, Caracter)
- legiones-daemonicas: Fluxmaster -> 5 Honor (36%, Montado, Caracter)
- legiones-daemonicas: Kairos Fateweaver -> 24 Honor (39%, Monstruo, Caracter)
- legiones-daemonicas: Lord of Change -> 25 Honor (39%, Monstruo, Caracter)
- legiones-daemonicas: The Blue Scribes -> 6 Honor (40%, Montado, Caracter)
- legiones-daemonicas: The Changeling -> 8 Honor (38%, Infanteria, Caracter)
- cultos-genestealer: Abominant -> 6 Honor (35%, Infanteria, Caracter)
- cultos-genestealer: Acolyte Iconward -> 4 Honor (40%, Infanteria, Caracter)
- cultos-genestealer: Benefictus -> 6 Honor (40%, Infanteria, Caracter)
- cultos-genestealer: Biophagus -> 4 Honor (40%, Infanteria, Caracter)
- cultos-genestealer: Clamavus -> 4 Honor (40%, Infanteria, Caracter)
- cultos-genestealer: Cult Guerrilla [Crucible] -> 4 Honor (33%, Infanteria, Caracter)
- cultos-genestealer: Cult Insurrectionist [Crucible] -> 6 Honor (38%, Infanteria, Caracter)
- cultos-genestealer: Jackal Alphus -> 4 Honor (36%, Montado, Caracter)
- cultos-genestealer: Kelermorph -> 4 Honor (33%, Infanteria, Caracter)
- cultos-genestealer: Locus -> 2 Honor (29%, Infanteria, Caracter)
- cultos-genestealer: Magus -> 4 Honor (40%, Infanteria, Caracter)
- cultos-genestealer: Nexos -> 4 Honor (33%, Infanteria, Caracter)
- cultos-genestealer: Patriarch -> 6 Honor (38%, Infanteria, Caracter)
- cultos-genestealer: Primus -> 5 Honor (36%, Infanteria, Caracter)
- cultos-genestealer: Reductus Saboteur -> 5 Honor (36%, Infanteria, Caracter)
- cultos-genestealer: Sanctus -> 5 Honor (38%, Infanteria, Caracter)
- cultos-genestealer: Voice of the Patriarch [Crucible] -> 5 Honor (36%, Infanteria, Caracter)
- adeptus-custodes: Aleya -> 5 Honor (45%, Infanteria, Caracter)
- adeptus-custodes: Blade Champion -> 11 Honor (50%, Infanteria, Caracter)
- adeptus-custodes: Guardian of the Throne [Crucible] -> 13 Honor (50%, Infanteria, Caracter)
- adeptus-custodes: Kataphraktoi Exemplar [Crucible] -> 15 Honor (50%, Montado, Caracter)
- adeptus-custodes: Knight-Centura -> 5 Honor (45%, Infanteria, Caracter)
- adeptus-custodes: Null Maiden [Crucible] -> 6 Honor (46%, Infanteria, Caracter)
- adeptus-custodes: Shield-Captain -> 11 Honor (50%, Infanteria, Caracter)
- adeptus-custodes: Shield-Captain in Allarus Terminator Armour -> 13 Honor (50%, Infanteria, Caracter)
- adeptus-custodes: Shield-Captain on Dawneagle Jetbike -> 14 Honor (50%, Montado, Caracter)
- adeptus-custodes: Trajann Valoris -> 13 Honor (48%, Infanteria, Caracter)
- adeptus-custodes: Valerian -> 11 Honor (50%, Infanteria, Caracter)
- adeptus-custodes: Canis Rex -> 41 Honor (49%, Infanteria, Caracter)
- adeptus-custodes: Cerastus Knight Lancer -> 41 Honor (49%, Vehiculo, Caracter)
- adeptus-custodes: Knight Castellan -> 42 Honor (49%, Vehiculo, Caracter)
- adeptus-custodes: Knight Crusader -> 39 Honor (49%, Vehiculo, Caracter)
- adeptus-custodes: Knight Defender -> 40 Honor (50%, Vehiculo, Caracter)
- adeptus-custodes: Knight Destrier -> 26 Honor (49%, Vehiculo, Caracter)
- adeptus-custodes: Knight Gallant -> 35 Honor (49%, Vehiculo, Caracter)
- adeptus-custodes: Knight Paladin -> 37 Honor (49%, Vehiculo, Caracter)
- adeptus-custodes: Knight Preceptor -> 36 Honor (49%, Vehiculo, Caracter)
- adeptus-custodes: Knight Valiant -> 40 Honor (50%, Vehiculo, Caracter)
- adeptus-custodes: Knight Warden -> 37 Honor (49%, Vehiculo, Caracter)
- adeptus-custodes: Ministorum Priest -> 4 Honor (50%, Infanteria, Caracter)
- cultos-genestealer: Winged Hive Tyrant -> 14 Honor (38%, Monstruo, Caracter)
- cultos-genestealer: Winged Tyranid Prime -> 5 Honor (38%, Infanteria, Caracter)
- cultos-genestealer: Deathleaper -> 6 Honor (38%, Infanteria, Caracter)
- cultos-genestealer: Hyperadapted Raveners -> 13 Honor (39%, Infanteria, Caracter)
- cultos-genestealer: Parasite of Mortrex -> 5 Honor (36%, Infanteria, Caracter)
- cultos-genestealer: The Red Terror -> 10 Honor (38%, Monstruo, Caracter)

## Produccion natural inicial

| Faccion | Capital | Pts capital | Adyacente | Pts adyacente | Total | Material capital | Uridium adyacente |
|---|---|---:|---|---:|---:|---:|---:|
| legiones-daemonicas | mordax | 13.5 | drusus | 6 | 19.5 | 5 | 0.6 |
| space-marines | sa-cea-gate | 13.5 | lyra-terminus | 6 | 19.5 | 5 | 0.6 |
| necrones | thokt-vault | 13.5 | novem | 6 | 19.5 | 5 | 0.6 |
| adeptus-custodes | kharon-prime | 13.5 | helios-drift | 6 | 19.5 | 5 | 0.6 |
| cultos-genestealer | blackglass | 13.5 | red-sabbath | 6 | 19.5 | 5 | 0.6 |

## Validaciones rapidas

- Unidades con conversion de puntos invalida: 0.
- Unidades con Material Industrial o Uridium: 0.
- Unidades no character con Honor: 0.
- Sombra del Emperador: costes preservados sin cambios.
- Facciones importadas desde catalogo: 8.
