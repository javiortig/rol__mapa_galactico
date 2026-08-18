# Informe de balance de facciones

Generado por `npm run units:generate`.

## Reglas aplicadas

- Conversion: `supply + 2*minerals + 5*honor + 5*gold = points`.
- Material Industrial y Uridium no se usan para reclutar unidades.
- Capital + adyacente objetivo: 19 puntos de reclutamiento/dia.
- Uridium y Material Industrial tienen economia separada.
- La campana empieza sin edificios construidos.
- Objetivo de unidades con oro: 25% por tipo principal y faccion.
- Las unidades con Oro tienen entre 20% y 30% de su coste equivalente en Oro.
- Objetivo de infanteria no character solo Suministro: 25% por faccion.
- Honor solo aparece en unidades con keyword Caracter.
- Los Characters tienen entre 40% y 50% de su coste equivalente en Honor.
- Las variantes de miniaturas/equipo escalan desde el perfil de coste de la plantilla base.

## Resumen por faccion jugable

| Faccion | Unidades | Unidades con oro | Puntos catalogo | Suministro | Mineral | Honor | Oro |
|---|---:|---:|---:|---:|---:|---:|---:|
| adeptus-custodes | 51 | 14/14 (27%) | 16160 | 2846 | 4272 | 490 | 464 |
| cultos-genestealer | 41 | 11/11 (27%) | 3395 | 1558 | 366 | 159 | 62 |
| legiones-daemonicas | 19 | 4/4 (21%) | 2720 | 1107 | 249 | 180 | 43 |
| necrones | 55 | 14/14 (25%) | 7570 | 2102 | 1419 | 328 | 198 |
| space-marines | 85 | 23/23 (27%) | 10565 | 3494 | 2578 | 161 | 222 |

## Oro por tipo principal

| Faccion | Tipo | Unidades | Con oro | Objetivo |
|---|---|---:|---:|---:|
| adeptus-custodes | Caracter | 23 | 6 | 6 |
| adeptus-custodes | Infanteria | 10 | 3 | 3 |
| adeptus-custodes | Vehiculo | 18 | 5 | 5 |
| cultos-genestealer | Bestia | 3 | 1 | 1 |
| cultos-genestealer | Caracter | 23 | 6 | 6 |
| cultos-genestealer | Infanteria | 11 | 3 | 3 |
| cultos-genestealer | Montado | 1 | 0 | 0 |
| cultos-genestealer | Vehiculo | 3 | 1 | 1 |
| legiones-daemonicas | Bestia | 1 | 0 | 0 |
| legiones-daemonicas | Caracter | 13 | 3 | 3 |
| legiones-daemonicas | Infanteria | 3 | 1 | 1 |
| legiones-daemonicas | Montado | 1 | 0 | 0 |
| legiones-daemonicas | Vehiculo | 1 | 0 | 0 |
| necrones | Bestia | 4 | 1 | 1 |
| necrones | Caracter | 25 | 6 | 6 |
| necrones | Infanteria | 9 | 2 | 2 |
| necrones | Montado | 3 | 1 | 1 |
| necrones | Vehiculo | 14 | 4 | 4 |
| space-marines | Caracter | 26 | 7 | 7 |
| space-marines | Infanteria | 26 | 7 | 7 |
| space-marines | Montado | 2 | 1 | 1 |
| space-marines | Vehiculo | 31 | 8 | 8 |

## Infanteria inicial solo suministro

- necrones: Immortals -> 70 Suministro
- necrones: Necron Warriors -> 80 Suministro
- necrones: Flayed Ones -> 55 Suministro
- legiones-daemonicas: Blue Horrors -> 125 Suministro
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

## Unidades con Honor

- necrones: C'tan Shard of the Deceiver -> 30 Honor (45%, Bestia, Caracter)
- necrones: C'tan Shard of the Nightbringer -> 32 Honor (44%, Bestia, Caracter)
- necrones: C'tan Shard of the Void Dragon -> 31 Honor (45%, Bestia, Caracter)
- necrones: Catacomb Command Barge -> 11 Honor (46%, Vehiculo, Caracter)
- necrones: Chronomancer -> 6 Honor (43%, Infanteria, Caracter)
- necrones: Dynastic Conqueror [Crucible] -> 8 Honor (47%, Infanteria, Caracter)
- necrones: Geomancer -> 7 Honor (47%, Infanteria, Caracter)
- necrones: Hexmark Destroyer -> 7 Honor (47%, Infanteria, Caracter)
- necrones: Hyperscientist [Crucible] -> 8 Honor (47%, Infanteria, Caracter)
- necrones: Illuminor Szeras -> 16 Honor (46%, Infanteria, Caracter)
- necrones: Imotekh the Stormlord -> 9 Honor (45%, Infanteria, Caracter)
- necrones: Lokhust Lord -> 6 Honor (43%, Montado, Caracter)
- necrones: Nekrosor Ammentar -> 17 Honor (46%, Infanteria, Caracter)
- necrones: Orikan the Diviner -> 8 Honor (44%, Infanteria, Caracter)
- necrones: Overlord -> 8 Honor (44%, Infanteria, Caracter)
- necrones: Overlord with Translocation Shroud -> 8 Honor (44%, Infanteria, Caracter)
- necrones: Plasmancer -> 5 Honor (45%, Infanteria, Caracter)
- necrones: Psychomancer -> 5 Honor (45%, Infanteria, Caracter)
- necrones: Royal Warden -> 5 Honor (50%, Infanteria, Caracter)
- necrones: Skorpekh Lord -> 8 Honor (44%, Infanteria, Caracter)
- necrones: Technomancer -> 7 Honor (44%, Infanteria, Caracter)
- necrones: The Silent King -> 38 Honor (45%, Vehiculo, Caracter)
- necrones: Transcendent C'tan -> 31 Honor (46%, Bestia, Caracter)
- necrones: Trazyn the Infinite -> 6 Honor (46%, Infanteria, Caracter)
- necrones: Triarchal Overseer [Crucible] -> 11 Honor (46%, Vehiculo, Caracter)
- legiones-daemonicas: Be'lakor -> 34 Honor (45%, Bestia, Caracter)
- legiones-daemonicas: Changecaster -> 5 Honor (42%, Infanteria, Caracter)
- legiones-daemonicas: Daemon Prince of Chaos -> 15 Honor (45%, Bestia, Caracter)
- legiones-daemonicas: Daemon Prince of Chaos with wings -> 17 Honor (45%, Bestia, Caracter)
- legiones-daemonicas: Daemonic Charioteer [Crucible] -> 11 Honor (46%, Montado, Caracter)
- legiones-daemonicas: Daemonic Herald [Crucible] -> 5 Honor (42%, Infanteria, Caracter)
- legiones-daemonicas: Exalted Flamer -> 6 Honor (46%, Infanteria, Caracter)
- legiones-daemonicas: Fateskimmer -> 9 Honor (47%, Montado, Caracter)
- legiones-daemonicas: Fluxmaster -> 6 Honor (43%, Montado, Caracter)
- legiones-daemonicas: Kairos Fateweaver -> 27 Honor (44%, Bestia, Caracter)
- legiones-daemonicas: Lord of Change -> 29 Honor (45%, Bestia, Caracter)
- legiones-daemonicas: The Blue Scribes -> 7 Honor (47%, Montado, Caracter)
- legiones-daemonicas: The Changeling -> 9 Honor (43%, Infanteria, Caracter)
- cultos-genestealer: Abominant -> 8 Honor (47%, Infanteria, Caracter)
- cultos-genestealer: Acolyte Iconward -> 5 Honor (50%, Infanteria, Caracter)
- cultos-genestealer: Benefictus -> 7 Honor (47%, Infanteria, Caracter)
- cultos-genestealer: Biophagus -> 5 Honor (50%, Infanteria, Caracter)
- cultos-genestealer: Clamavus -> 5 Honor (50%, Infanteria, Caracter)
- cultos-genestealer: Cult Guerrilla [Crucible] -> 5 Honor (42%, Infanteria, Caracter)
- cultos-genestealer: Cult Insurrectionist [Crucible] -> 7 Honor (44%, Infanteria, Caracter)
- cultos-genestealer: Jackal Alphus -> 5 Honor (45%, Montado, Caracter)
- cultos-genestealer: Kelermorph -> 5 Honor (42%, Infanteria, Caracter)
- cultos-genestealer: Locus -> 3 Honor (43%, Infanteria, Caracter)
- cultos-genestealer: Magus -> 5 Honor (50%, Infanteria, Caracter)
- cultos-genestealer: Nexos -> 5 Honor (42%, Infanteria, Caracter)
- cultos-genestealer: Patriarch -> 7 Honor (44%, Infanteria, Caracter)
- cultos-genestealer: Primus -> 6 Honor (43%, Infanteria, Caracter)
- cultos-genestealer: Reductus Saboteur -> 6 Honor (43%, Infanteria, Caracter)
- cultos-genestealer: Sanctus -> 6 Honor (46%, Infanteria, Caracter)
- cultos-genestealer: Voice of the Patriarch [Crucible] -> 6 Honor (43%, Infanteria, Caracter)
- space-marines: Ancient -> 4 Honor (50%, Infanteria, Caracter)
- space-marines: Ancient in Terminator Armor -> 6 Honor (46%, Infanteria, Caracter)
- space-marines: Apothecary -> 5 Honor (50%, Infanteria, Caracter)
- space-marines: Apothecary Biologis -> 6 Honor (43%, Infanteria, Caracter)
- space-marines: Bladeguard Ancient -> 4 Honor (50%, Infanteria, Caracter)
- space-marines: Captain -> 7 Honor (44%, Infanteria, Caracter)
- space-marines: Captain in Gravis Armour -> 7 Honor (44%, Infanteria, Caracter)
- space-marines: Captain in Phobos Armour -> 6 Honor (43%, Infanteria, Caracter)
- space-marines: Captain in Terminator Armour -> 8 Honor (47%, Infanteria, Caracter)
- space-marines: Captain with Jump Pack -> 7 Honor (47%, Infanteria, Caracter)
- space-marines: Champion of the Chapter [Crucible] -> 6 Honor (43%, Infanteria, Caracter)
- space-marines: Chaplain -> 5 Honor (42%, Infanteria, Caracter)
- space-marines: Chaplain in Terminator Armour -> 7 Honor (47%, Infanteria, Caracter)
- space-marines: Chaplain on Bike -> 6 Honor (43%, Montado, Caracter)
- space-marines: Chaplain with Jump Pack -> 7 Honor (47%, Infanteria, Caracter)
- space-marines: Judiciar -> 5 Honor (45%, Infanteria, Caracter)
- space-marines: Librarian -> 6 Honor (43%, Infanteria, Caracter)
- space-marines: Librarian in Phobos Armour -> 6 Honor (43%, Infanteria, Caracter)
- space-marines: Librarian in Terminator Armour -> 7 Honor (47%, Infanteria, Caracter)
- space-marines: Librarius Adept [Crucible] -> 6 Honor (43%, Infanteria, Caracter)
- space-marines: Lieutenant -> 4 Honor (44%, Infanteria, Caracter)
- space-marines: Lieutenant in Phobos Armour -> 4 Honor (44%, Infanteria, Caracter)
- space-marines: Lieutenant in Reiver Armour -> 4 Honor (44%, Infanteria, Caracter)
- space-marines: Lieutenant with Combi-weapon -> 9 Honor (47%, Infanteria, Caracter)
- space-marines: Techmarine -> 5 Honor (45%, Infanteria, Caracter)
- space-marines: Venerable Battle-Brother [Crucible] -> 14 Honor (44%, Vehiculo, Caracter)
- adeptus-custodes: Aleya -> 5 Honor (45%, Infanteria, Caracter)
- adeptus-custodes: Blade Champion -> 10 Honor (45%, Infanteria, Caracter)
- adeptus-custodes: Guardian of the Throne [Crucible] -> 12 Honor (46%, Infanteria, Caracter)
- adeptus-custodes: Kataphraktoi Exemplar [Crucible] -> 14 Honor (47%, Montado, Caracter)
- adeptus-custodes: Knight-Centura -> 5 Honor (45%, Infanteria, Caracter)
- adeptus-custodes: Null Maiden [Crucible] -> 6 Honor (46%, Infanteria, Caracter)
- adeptus-custodes: Shield-Captain -> 10 Honor (45%, Infanteria, Caracter)
- adeptus-custodes: Shield-Captain in Allarus Terminator Armour -> 12 Honor (46%, Infanteria, Caracter)
- adeptus-custodes: Shield-Captain on Dawneagle Jetbike -> 13 Honor (46%, Montado, Caracter)
- adeptus-custodes: Trajann Valoris -> 12 Honor (44%, Infanteria, Caracter)
- adeptus-custodes: Valerian -> 10 Honor (45%, Infanteria, Caracter)
- adeptus-custodes: Canis Rex -> 37 Honor (45%, Infanteria, Caracter)
- adeptus-custodes: Cerastus Knight Lancer -> 37 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Knight Castellan -> 38 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Knight Crusader -> 36 Honor (46%, Vehiculo, Caracter)
- adeptus-custodes: Knight Defender -> 36 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Knight Destrier -> 24 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Knight Gallant -> 32 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Knight Paladin -> 34 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Knight Preceptor -> 33 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Knight Valiant -> 36 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Knight Warden -> 34 Honor (45%, Vehiculo, Caracter)
- adeptus-custodes: Ministorum Priest -> 4 Honor (50%, Infanteria, Caracter)
- cultos-genestealer: Winged Hive Tyrant -> 17 Honor (46%, Bestia, Caracter)
- cultos-genestealer: Winged Tyranid Prime -> 6 Honor (46%, Infanteria, Caracter)
- cultos-genestealer: Deathleaper -> 7 Honor (44%, Infanteria, Caracter)
- cultos-genestealer: Hyperadapted Raveners -> 15 Honor (45%, Infanteria, Caracter)
- cultos-genestealer: Parasite of Mortrex -> 6 Honor (43%, Infanteria, Caracter)
- cultos-genestealer: The Red Terror -> 12 Honor (46%, Bestia, Caracter)

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
- Unidades no character con Honor: 0.
- Characters fuera de rango 40%-50% Honor: 0.
- Unidades con Oro fuera de rango 20%-30%: 0.
- Facciones importadas desde catalogo: 8.
