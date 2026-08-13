import type { CampaignSnapshot, ResourceBundle } from "@/domain/campaign";
import {
  generated40kFactions,
  generated40kInitialUnits,
  generated40kUnitTemplates
} from "@/mocks/generated/40k-unit-templates";
import mfmCostOptions from "../../data/11th-unit-cost-options.json";
import troopTreeConfigJson from "../../data/technology/faction-troop-trees.json";

const emptyResources: ResourceBundle = {
  supply: 0,
  minerals: 0,
  honor: 0,
  gold: 0,
  industrialMaterial: 0,
  uridium: 0,
  technology: 0
};

const now = Date.now();
const inHours = (hours: number) => new Date(now + hours * 60 * 60 * 1000).toISOString();
const inMinutes = (minutes: number) => new Date(now + minutes * 60 * 1000).toISOString();
const inDays = (days: number) => new Date(now + days * 24 * 60 * 60 * 1000).toISOString();
const dailyProduction = (resources: Partial<ResourceBundle>): ResourceBundle => ({
  ...emptyResources,
  ...resources
});

const activePlayableFactionSlugs = [
  "legiones-daemonicas",
  "cultos-genestealer",
  "space-marines",
  "adeptus-custodes",
  "necrones"
] as const;

const activeFactionSlugs = new Set<string>([...activePlayableFactionSlugs, "orcos", "tiranidos"]);

const factionColorOverrides: Record<string, string> = {
  "legiones-daemonicas": "#ef4444",
  "cultos-genestealer": "#ec4899",
  "space-marines": "#3b82f6",
  "adeptus-custodes": "#d4af37",
  necrones: "#2dd4bf",
  orcos: "#84cc16",
  tiranidos: "#8b5cf6"
};

function isActiveFactionId(factionId: string | null | undefined) {
  return typeof factionId === "string" && activeFactionSlugs.has(factionId);
}

const factions: CampaignSnapshot["factions"] = [
  ...generated40kFactions
    .filter((faction) => activePlayableFactionSlugs.includes(faction.id as (typeof activePlayableFactionSlugs)[number]))
    .map((faction) => ({
      ...faction,
      color: factionColorOverrides[faction.id] ?? faction.color,
      isNarrative: false
    })),
  {
    id: "orcos",
    slug: "orcos",
    name: "Orcos",
    color: factionColorOverrides.orcos,
    capitalSystemId: null,
    isNarrative: true
  },
  {
    id: "tiranidos",
    slug: "tiranidos",
    name: "Tiranidos",
    color: factionColorOverrides.tiranidos,
    capitalSystemId: null,
    isNarrative: true
  }
];

type BaseSystem = Omit<CampaignSnapshot["systems"][number], "systemKind" | "isConquerable" | "allowsSharedOccupation">;

const baseSystems: BaseSystem[] = [
  {
    id: "kharon-prime",
    name: "Santa Terra",
    x: 90,
    y: 170,
    size: 1.2,
    starClass: "blue",
    type: "Capital fortificada",
    status: "controlled",
    controllerFactionId: "adeptus-custodes",
    isCapital: true,
    publicDescription: "Bastion aurico y astropuerto militar custodiado por los guardianes del Trono.",
    production: dailyProduction({ supply: 9, minerals: 6, uridium: 2 })
  },
  {
    id: "helios-drift",
    name: "Helios Drift",
    x: 215,
    y: 190,
    size: 0.9,
    starClass: "orange",
    type: "Cinturon minero",
    status: "controlled",
    controllerFactionId: "adeptus-custodes",
    isCapital: false,
    publicDescription: "Asteroides ricos en mineral defendidos por baterias orbitales custodes.",
    production: dailyProduction({ supply: 1, minerals: 7, uridium: 1 })
  },
  {
    id: "arx-solum",
    name: "Arx Solum",
    x: 315,
    y: 255,
    size: 0.82,
    starClass: "white",
    type: "Bastion exterior",
    status: "controlled",
    controllerFactionId: "adeptus-custodes",
    isCapital: false,
    publicDescription: "Fortaleza avanzada que vigila las rutas hacia la Zanja Azul.",
    production: dailyProduction({ supply: 5, minerals: 3, uridium: 1 })
  },
  {
    id: "sa-cea-gate",
    name: "Obscura Primus",
    x: 910,
    y: 150,
    size: 1.2,
    starClass: "white",
    type: "Capital orbital",
    status: "controlled",
    controllerFactionId: "space-marines",
    isCapital: true,
    publicDescription: "Estacion de paso con matrices de navegacion de largo alcance.",
    production: dailyProduction({ supply: 5, minerals: 4, uridium: 5 })
  },
  {
    id: "lyra-terminus",
    name: "Lyra Terminus",
    x: 790,
    y: 210,
    size: 0.88,
    starClass: "blue",
    type: "Puerto externo",
    status: "controlled",
    controllerFactionId: "space-marines",
    isCapital: false,
    publicDescription: "Puerto orbital en el borde del subsector.",
    production: dailyProduction({ supply: 3, minerals: 1, uridium: 4 })
  },
  {
    id: "narthex",
    name: "Narthex",
    x: 685,
    y: 285,
    size: 0.95,
    starClass: "yellow",
    type: "Santuario sellado",
    status: "controlled",
    controllerFactionId: "space-marines",
    isCapital: false,
    publicDescription: "Complejo sacro con rutas de descenso peligrosas.",
    production: dailyProduction({ supply: 2, honor: 2, uridium: 1 })
  },
  {
    id: "blackglass",
    name: "Yaracuby77 Mina Abandonada",
    x: 930,
    y: 440,
    size: 1.16,
    starClass: "white",
    type: "Capital cristalina",
    status: "controlled",
    controllerFactionId: "cultos-genestealer",
    isCapital: true,
    publicDescription: "Honor bajo oceanos de vidrio oscuro.",
    production: dailyProduction({ supply: 3, minerals: 4, honor: 2, uridium: 1 })
  },
  {
    id: "red-sabbath",
    name: "Red Sabbath",
    x: 805,
    y: 485,
    size: 0.88,
    starClass: "red",
    type: "Mundo sermonario",
    status: "controlled",
    controllerFactionId: "cultos-genestealer",
    isCapital: false,
    publicDescription: "Ciudades santuario infiltradas por redes de culto.",
    production: dailyProduction({ supply: 5, minerals: 2, honor: 1, uridium: 1 })
  },
  {
    id: "mirrorcoil",
    name: "Mirrorcoil",
    x: 685,
    y: 510,
    size: 0.82,
    starClass: "violet",
    type: "Enjambre orbital",
    status: "controlled",
    controllerFactionId: "cultos-genestealer",
    isCapital: false,
    publicDescription: "Estaciones gemelas que repiten senales falsas hacia el centro.",
    production: dailyProduction({ supply: 2, minerals: 2, honor: 1, uridium: 3 })
  },
  {
    id: "thokt-vault",
    name: "Necronpolis",
    x: 805,
    y: 800,
    size: 1.2,
    starClass: "green",
    type: "Capital tumba",
    status: "controlled",
    controllerFactionId: "necrones",
    isCapital: true,
    publicDescription: "Cripta silenciosa rodeada de energia verdosa.",
    production: dailyProduction({ minerals: 8, honor: 3, uridium: 2 })
  },
  {
    id: "novem",
    name: "Novem",
    x: 725,
    y: 700,
    size: 0.84,
    starClass: "white",
    type: "Luna industrial",
    status: "controlled",
    controllerFactionId: "necrones",
    isCapital: false,
    publicDescription: "Complejo lunar de extraccion automatizada.",
    production: dailyProduction({ minerals: 7, uridium: 1 })
  },
  {
    id: "ghostlight",
    name: "Ghostlight",
    x: 625,
    y: 645,
    size: 0.8,
    starClass: "green",
    type: "Faro perdido",
    status: "controlled",
    controllerFactionId: "necrones",
    isCapital: false,
    publicDescription: "Faro de navegacion que parpadea con luz fria.",
    production: dailyProduction({ minerals: 2, honor: 1, uridium: 3 })
  },
  {
    id: "mordax",
    name: "Fasciata",
    x: 150,
    y: 780,
    size: 1.18,
    starClass: "red",
    type: "Capital corrupta",
    status: "controlled",
    controllerFactionId: "legiones-daemonicas",
    isCapital: true,
    publicDescription: "Mundo industrial desgarrado por senales disformes.",
    production: dailyProduction({ supply: 5, minerals: 6, honor: 1, uridium: 2 })
  },
  {
    id: "drusus",
    name: "Drusus",
    x: 260,
    y: 700,
    size: 0.86,
    starClass: "orange",
    type: "Bastion menor",
    status: "controlled",
    controllerFactionId: "legiones-daemonicas",
    isCapital: false,
    publicDescription: "Fortaleza tomada tras una campana sangrienta.",
    production: dailyProduction({ supply: 4, minerals: 4, uridium: 1 })
  },
  {
    id: "plaguefall-bastion",
    name: "Plaguefall Bastion",
    x: 360,
    y: 640,
    size: 0.82,
    starClass: "green",
    type: "Bastion infectado",
    status: "controlled",
    controllerFactionId: "legiones-daemonicas",
    isCapital: false,
    publicDescription: "Plataformas de asedio cubiertas por esporas y ceniza.",
    production: dailyProduction({ supply: 3, minerals: 5, honor: 1, uridium: 1 })
  },
  {
    id: "cinder-maw",
    name: "Cinder Maw",
    x: 80,
    y: 430,
    size: 1.15,
    starClass: "orange",
    type: "Forja volcanica neutral",
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    publicDescription: "Forjas geotermicas sin dueno estable, acechadas por chatarra orka y tormentas de ceniza.",
    production: dailyProduction({ supply: 4, minerals: 7, uridium: 1 })
  },
  {
    id: "eclipse-forge",
    name: "Eclipse Forge",
    x: 185,
    y: 485,
    size: 0.86,
    starClass: "red",
    type: "Forja abandonada",
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    publicDescription: "Estructuras de manufactura latentes convertidas en talleres orkos.",
    production: dailyProduction({ supply: 1, minerals: 6, uridium: 1 })
  },
  {
    id: "rustmaw-run",
    name: "Rustmaw Run",
    x: 285,
    y: 430,
    size: 0.82,
    starClass: "orange",
    type: "Corredor chatarrero",
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    publicDescription: "Ruta de pecios saqueados que apunta hacia el centro.",
    production: dailyProduction({ supply: 3, minerals: 5, uridium: 2 })
  },
  {
    id: "azur-trench",
    name: "Azur Trench",
    x: 405,
    y: 390,
    size: 0.86,
    starClass: "blue",
    type: "Nebulosa navegable",
    status: "war",
    blockedUntil: inDays(14),
    isCapital: false,
    publicDescription: "Corredor azul con pozos de gravedad inestables. Una horda orka amenaza las rutas de avance custodes.",
    production: dailyProduction({ uridium: 5 })
  },
  {
    id: "ossuary-reach",
    name: "Ossuary Reach",
    x: 485,
    y: 625,
    size: 0.84,
    starClass: "violet",
    type: "Osario orbital",
    status: "war",
    blockedUntil: inDays(14),
    isCapital: false,
    publicDescription: "Campos funerarios en orbita baja, disputados por plaga y tecnologia necrona.",
    production: dailyProduction({ minerals: 2, honor: 2, uridium: 2 }),
    specialObjects: [{ id: "obj-ossuary-reach", name: "Cripta fracturada", type: "anomaly", isPublic: true }]
  },
  {
    id: "saint-veil",
    name: "Saint Veil",
    x: 650,
    y: 395,
    size: 0.86,
    starClass: "yellow",
    type: "Velo sagrado",
    status: "war",
    blockedUntil: inDays(14),
    isCapital: false,
    publicDescription: "Santuario velado donde los Space Marines combaten una revuelta genestelar.",
    production: dailyProduction({ supply: 2, honor: 2, uridium: 2 }),
    specialObjects: [{ id: "obj-saint-veil", name: "Reliquia velada", type: "relic", isPublic: true }]
  },
  {
    id: "orison",
    name: "Orison",
    x: 470,
    y: 310,
    size: 0.84,
    starClass: "yellow",
    type: "Colonia agricola",
    status: "neutral",
    isCapital: false,
    publicDescription: "Graneros presurizados y bastiones de defensa civil abandonados.",
    production: dailyProduction({ supply: 7, minerals: 1 })
  },
  {
    id: "vesper-halo",
    name: "Vesper Halo",
    x: 560,
    y: 220,
    size: 0.82,
    starClass: "violet",
    type: "Anillo orbital",
    status: "neutral",
    isCapital: false,
    publicDescription: "Ruinas orbitales con ecos de tecnologia antigua.",
    production: dailyProduction({ minerals: 2, honor: 1, uridium: 2 })
  },
  {
    id: "pale-choir",
    name: "Pale Choir",
    x: 690,
    y: 605,
    size: 0.78,
    starClass: "violet",
    type: "Anomalia psiquica",
    status: "neutral",
    isCapital: false,
    publicDescription: "Un coro de senales imposibles atraviesa el vacio.",
    production: dailyProduction({ honor: 2, uridium: 2 })
  },
  {
    id: "ashen-road",
    name: "Ashen Road",
    x: 560,
    y: 555,
    size: 0.78,
    starClass: "blue",
    type: "Nodo de transito",
    status: "neutral",
    isCapital: false,
    publicDescription: "Rutas estables entre corrientes de polvo orbital.",
    production: dailyProduction({ supply: 1, minerals: 1, uridium: 4 })
  },
  {
    id: "sepulchre-nine",
    name: "Sepulchre IX",
    x: 340,
    y: 780,
    size: 0.78,
    starClass: "violet",
    type: "Necropolis",
    status: "neutral",
    isCapital: false,
    publicDescription: "Tumbas y coordenadas contradictorias.",
    production: dailyProduction({ minerals: 2, honor: 2 })
  },
  {
    id: "nexus-aster",
    name: "Nexus Aster",
    x: 525,
    y: 455,
    size: 0.92,
    starClass: "green",
    type: "Nodo central",
    status: "neutral",
    isCapital: false,
    publicDescription: "Interseccion de corrientes de salto que todas las facciones desean controlar.",
    production: dailyProduction({ supply: 2, minerals: 2, honor: 1, uridium: 3 }),
    specialObjects: [{ id: "obj-nexus-aster", name: "Baliza del Nexus", type: "technology", isPublic: true }]
  },
  {
    id: "argent-rift",
    name: "Argent Rift",
    x: 500,
    y: 245,
    size: 0.76,
    starClass: "white",
    type: "Fisura plateada",
    status: "neutral",
    isCapital: false,
    publicDescription: "Brecha gravitatoria brillante, estable solo en ventanas cortas.",
    production: dailyProduction({ minerals: 1, uridium: 4 })
  },
  {
    id: "voidfall-anchor",
    name: "Voidfall Anchor",
    x: 510,
    y: 735,
    size: 0.78,
    starClass: "blue",
    type: "Ancla de vacio",
    status: "neutral",
    isCapital: false,
    publicDescription: "Macroestructura que estabiliza saltos en el borde inferior del mapa.",
    production: dailyProduction({ supply: 1, minerals: 2, uridium: 3 })
  },
  {
    id: "goregate",
    name: "Goregate",
    x: 260,
    y: 540,
    size: 0.78,
    starClass: "red",
    type: "Paso sangriento",
    status: "neutral",
    isCapital: false,
    publicDescription: "Paso estrecho entre chatarra orka y ruinas funerarias.",
    production: dailyProduction({ supply: 2, minerals: 3, uridium: 2 })
  },
  {
    id: "maelstrom-gas",
    name: "Maelstrom Gas",
    x: 500,
    y: 360,
    size: 1.08,
    starClass: "violet",
    type: "Anomalia gaseosa central",
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    publicDescription: "Una nube de plasma y gases ionizados abre un paso peligroso hacia el nucleo orko.",
    production: dailyProduction({}),
    specialObjects: [{ id: "obj-maelstrom-gas", name: "Marea ionizada", type: "anomaly", isPublic: true }]
  },
  {
    id: "voidmist-basin",
    name: "Voidmist Basin",
    x: 500,
    y: 640,
    size: 1.04,
    starClass: "blue",
    type: "Cuenca gaseosa central",
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    publicDescription: "Un oceano de niebla estelar permite rodear el centro sin reclamar territorio estable.",
    production: dailyProduction({}),
    specialObjects: [{ id: "obj-voidmist-basin", name: "Cuenca de vacio", type: "anomaly", isPublic: true }]
  }
];

const finalMapSystemIds = new Set([
  "mordax",
  "drusus",
  "sa-cea-gate",
  "lyra-terminus",
  "thokt-vault",
  "novem",
  "kharon-prime",
  "helios-drift",
  "blackglass",
  "red-sabbath",
  "maelstrom-gas",
  "voidmist-basin",
  "nexus-aster",
  "goregate"
]);

const finalSystemOverrides: Record<string, Partial<BaseSystem>> = {
  "kharon-prime": { x: 145, y: 850, status: "controlled", controllerFactionId: "adeptus-custodes", isCapital: true },
  "helios-drift": {
    x: 285,
    y: 735,
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    type: "Cinturon minero neutral",
    publicDescription: "Primer corredor desde Kharon: asteroides ricos en mineral y rutas abiertas hacia el centro."
  },
  "arx-solum": {
    x: 350,
    y: 110,
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    type: "Bastion exterior neutral",
    publicDescription: "Fortaleza avanzada abandonada sobre una ruta alta hacia los nodos centrales."
  },
  "azur-trench": {
    x: 360,
    y: 270,
    status: "neutral",
    controllerFactionId: null,
    blockedUntil: undefined,
    isCapital: false,
    publicDescription: "Corredor azul con pozos de gravedad inestables y lecturas de patrullas orkas lejanas."
  },
  "sa-cea-gate": { x: 910, y: 150, status: "controlled", controllerFactionId: "space-marines", isCapital: true },
  "lyra-terminus": {
    x: 770,
    y: 190,
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    type: "Puerto externo neutral",
    publicDescription: "Puerto orbital sin mando estable, demasiado cercano al frente para ser ignorado."
  },
  narthex: {
    x: 650,
    y: 110,
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    type: "Santuario sellado neutral",
    publicDescription: "Complejo sacro con rutas de descenso peligrosas hacia el nucleo del mapa."
  },
  "vesper-halo": { x: 640, y: 270, status: "neutral", controllerFactionId: null, isCapital: false },
  blackglass: { x: 930, y: 500, status: "controlled", controllerFactionId: "cultos-genestealer", isCapital: true },
  "red-sabbath": {
    x: 785,
    y: 500,
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    type: "Mundo sermonario neutral",
    publicDescription: "Ciudades santuario sin autoridad estable, llenas de rutas subterraneas y ruido civil."
  },
  mirrorcoil: { x: 660, y: 415, status: "neutral", controllerFactionId: null, isCapital: false },
  "saint-veil": {
    x: 650,
    y: 585,
    status: "neutral",
    controllerFactionId: null,
    blockedUntil: undefined,
    isCapital: false,
    publicDescription: "Santuario velado donde los augurios se confunden con sabotajes y plegarias.",
    specialObjects: undefined
  },
  "thokt-vault": { x: 820, y: 850, status: "controlled", controllerFactionId: "necrones", isCapital: true },
  novem: {
    x: 705,
    y: 735,
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    type: "Luna industrial neutral",
    publicDescription: "Complejo lunar de extraccion automatizada a la espera de un nuevo amo."
  },
  ghostlight: { x: 610, y: 650, status: "neutral", controllerFactionId: null, isCapital: false },
  "ossuary-reach": {
    x: 585,
    y: 815,
    status: "neutral",
    controllerFactionId: null,
    blockedUntil: undefined,
    isCapital: false,
    publicDescription: "Campos funerarios en orbita baja donde la tecnologia antigua sigue respondiendo.",
    specialObjects: undefined
  },
  mordax: { x: 90, y: 150, status: "controlled", controllerFactionId: "legiones-daemonicas", isCapital: true },
  drusus: {
    x: 230,
    y: 190,
    status: "neutral",
    controllerFactionId: null,
    isCapital: false,
    type: "Bastion menor neutral",
    publicDescription: "Fortaleza abandonada en una ruta baja hacia los fuegos centrales."
  },
  "plaguefall-bastion": { x: 395, y: 650, status: "neutral", controllerFactionId: null, isCapital: false },
  "sepulchre-nine": { x: 385, y: 815, status: "neutral", controllerFactionId: null, isCapital: false },
  "nexus-aster": {
    x: 420,
    y: 500,
    size: 0.96,
    status: "controlled",
    controllerFactionId: "orcos",
    type: "Enclave orko central",
    publicDescription: "Un nudo de rutas tomado por senales de guerra orkas y chatarra militar.",
    specialObjects: [{ id: "obj-nexus-aster", name: "Totem del Nexus", type: "anomaly", isPublic: true }]
  },
  goregate: {
    x: 580,
    y: 500,
    size: 0.96,
    status: "controlled",
    controllerFactionId: "orcos",
    type: "Portal de guerra orko",
    publicDescription: "Paso sangriento convertido en puerta de saqueo para incursiones orkas.",
    specialObjects: [{ id: "obj-goregate", name: "Puerta de la Waaagh", type: "anomaly", isPublic: true }]
  }
};

const gaseousSystemIds = new Set<string>(["maelstrom-gas", "voidmist-basin"]);

const systems: CampaignSnapshot["systems"] = baseSystems.filter((system) => finalMapSystemIds.has(system.id)).map((system) => {
  const isGaseous = gaseousSystemIds.has(system.id);
  const finalSystem = { ...system, ...finalSystemOverrides[system.id] };

  return {
    ...finalSystem,
    systemKind: isGaseous ? "gaseous" : "standard",
    isConquerable: !isGaseous,
    allowsSharedOccupation: isGaseous
  };
});

const edges: CampaignSnapshot["edges"] = [
  { id: "route-01", fromSystemId: "mordax", toSystemId: "drusus", uridiumCost: 1 },
  { id: "route-02", fromSystemId: "drusus", toSystemId: "maelstrom-gas", uridiumCost: 1 },
  { id: "route-03", fromSystemId: "sa-cea-gate", toSystemId: "lyra-terminus", uridiumCost: 1 },
  { id: "route-04", fromSystemId: "lyra-terminus", toSystemId: "maelstrom-gas", uridiumCost: 1 },
  { id: "route-05", fromSystemId: "thokt-vault", toSystemId: "novem", uridiumCost: 1 },
  { id: "route-06", fromSystemId: "novem", toSystemId: "voidmist-basin", uridiumCost: 1 },
  { id: "route-07", fromSystemId: "kharon-prime", toSystemId: "helios-drift", uridiumCost: 1 },
  { id: "route-08", fromSystemId: "helios-drift", toSystemId: "voidmist-basin", uridiumCost: 1 },
  { id: "route-09", fromSystemId: "blackglass", toSystemId: "red-sabbath", uridiumCost: 1 },
  { id: "route-10", fromSystemId: "red-sabbath", toSystemId: "maelstrom-gas", uridiumCost: 1 },
  { id: "route-11", fromSystemId: "maelstrom-gas", toSystemId: "nexus-aster", uridiumCost: 1 },
  { id: "route-12", fromSystemId: "maelstrom-gas", toSystemId: "goregate", uridiumCost: 1 },
  { id: "route-13", fromSystemId: "voidmist-basin", toSystemId: "nexus-aster", uridiumCost: 1 },
  { id: "route-14", fromSystemId: "voidmist-basin", toSystemId: "goregate", uridiumCost: 1 }
];

const resources: CampaignSnapshot["resources"] = [
  {
    factionId: "adeptus-custodes",
    supply: 100,
    minerals: 40,
    honor: 0,
    gold: 0,
    industrialMaterial: 150,
    uridium: 10,
    technology: 6,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "necrones",
    supply: 100,
    minerals: 40,
    honor: 0,
    gold: 0,
    industrialMaterial: 150,
    uridium: 10,
    technology: 6,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "cultos-genestealer",
    supply: 100,
    minerals: 40,
    honor: 0,
    gold: 0,
    industrialMaterial: 150,
    uridium: 10,
    technology: 6,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "space-marines",
    supply: 100,
    minerals: 40,
    honor: 0,
    gold: 0,
    industrialMaterial: 150,
    uridium: 10,
    technology: 6,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "legiones-daemonicas",
    supply: 100,
    minerals: 40,
    honor: 0,
    gold: 0,
    industrialMaterial: 150,
    uridium: 10,
    technology: 6,
    updatedAt: new Date(now).toISOString()
  }
];

type MockUnitGroup = {
  id: string;
  factionId: string;
  name: string;
  currentSystemId: string;
  status: CampaignSnapshot["units"][number]["status"];
  pointsTotal: number;
  isVisiblePublicly: boolean;
  units: Array<{
    id: string;
    name: string;
    points: number;
    quantity: number;
    startingQuantity?: number;
    woundsTaken?: number;
    experience: number;
    rank?: string | null;
    enhancementText?: string | null;
  }>;
};

const unitGroups: MockUnitGroup[] = [
  {
    id: "imperial-kharon-garrison",
    factionId: "adeptus-custodes",
    name: "Guarnicion de Kharon",
    currentSystemId: "kharon-prime",
    status: "ready",
    pointsTotal: 510,
    isVisiblePublicly: false,
    units: [
      {
        id: "imperial-kharon-cadians",
        name: "Custodian Guard",
        points: 80,
        quantity: 3,
        experience: 1,
        rank: "Linea"
      }
    ]
  },
  {
    id: "imperial-arx-front",
    factionId: "adeptus-custodes",
    name: "117o Grupo de Choque",
    currentSystemId: "arx-solum",
    status: "ready",
    pointsTotal: 760,
    isVisiblePublicly: false,
    units: [
      {
        id: "imperial-arx-kasrkin",
        name: "Kasrkin",
        points: 105,
        quantity: 7,
        startingQuantity: 10,
        woundsTaken: 2,
        experience: 2,
        rank: "Veteranos",
        enhancementText: "Doctrina de frontera"
      }
    ]
  },
  {
    id: "imperial-helios-column",
    factionId: "adeptus-custodes",
    name: "Columna Helios",
    currentSystemId: "kharon-prime",
    status: "moving",
    pointsTotal: 360,
    isVisiblePublicly: false,
    units: [
      {
        id: "imperial-helios-cadians",
        name: "Custodian Guard",
        points: 80,
        quantity: 2,
        experience: 0,
        rank: "Reconocimiento"
      }
    ]
  },
  {
    id: "imperial-azur-line",
    factionId: "adeptus-custodes",
    name: "Linea de Azur",
    currentSystemId: "azur-trench",
    status: "in_war",
    pointsTotal: 690,
    isVisiblePublicly: false,
    units: [
      {
        id: "imperial-azur-tank",
        name: "Caladius Grav-tank",
        points: 145,
        quantity: 2,
        experience: 1,
        rank: "Blindados"
      }
    ]
  },
  {
    id: "ork-cinder-garrison",
    factionId: "aeldari",
    name: "Kampamento de Cinder Maw",
    currentSystemId: "cinder-maw",
    status: "ready",
    pointsTotal: 560,
    isVisiblePublicly: false,
    units: [
      {
        id: "ork-cinder-boyz",
        name: "Boyz",
        points: 80,
        quantity: 4,
        experience: 1,
        rank: "Marea"
      }
    ]
  },
  {
    id: "ork-rustmaw-front",
    factionId: "aeldari",
    name: "Peaje de Rustmaw",
    currentSystemId: "rustmaw-run",
    status: "ready",
    pointsTotal: 790,
    isVisiblePublicly: false,
    units: [
      {
        id: "ork-rustmaw-meganobz",
        name: "Meganobz",
        points: 105,
        quantity: 2,
        experience: 2,
        rank: "Noblez",
        enhancementText: "Armaduras remachadas"
      }
    ]
  },
  {
    id: "ork-eclipse-riders",
    factionId: "aeldari",
    name: "Jinetes de Eclipse",
    currentSystemId: "cinder-maw",
    status: "moving",
    pointsTotal: 380,
    isVisiblePublicly: false,
    units: [
      {
        id: "ork-eclipse-boyz",
        name: "Boyz",
        points: 80,
        quantity: 3,
        experience: 0,
        rank: "Movil"
      }
    ]
  },
  {
    id: "ork-azur-waaagh",
    factionId: "aeldari",
    name: "Waaagh de la Zanja Azul",
    currentSystemId: "azur-trench",
    status: "in_war",
    pointsTotal: 720,
    isVisiblePublicly: false,
    units: [
      {
        id: "ork-azur-dread",
        name: "Deff Dread",
        points: 135,
        quantity: 2,
        experience: 1,
        rank: "Chatarreros"
      }
    ]
  },
  {
    id: "sombra-gate-watch",
    factionId: "space-marines",
    name: "Guardia de Sa'cea Gate",
    currentSystemId: "sa-cea-gate",
    status: "ready",
    pointsTotal: 620,
    isVisiblePublicly: false,
    units: [
      {
        id: "sombra-gate-intercessors",
        name: "Intercessor Squad",
        points: 105,
        quantity: 2,
        experience: 1,
        rank: "Linea"
      }
    ]
  },
  {
    id: "sombra-narthex-spear",
    factionId: "space-marines",
    name: "Punta de Lanza Narthex",
    currentSystemId: "narthex",
    status: "ready",
    pointsTotal: 830,
    isVisiblePublicly: false,
    units: [
      {
        id: "sombra-narthex-terminators",
        name: "Terminator Squad",
        points: 160,
        quantity: 2,
        experience: 2,
        rank: "Veteranos",
        enhancementText: "Juramento del santuario"
      }
    ]
  },
  {
    id: "sombra-lyra-talon",
    factionId: "space-marines",
    name: "Garra de Lyra",
    currentSystemId: "sa-cea-gate",
    status: "moving",
    pointsTotal: 430,
    isVisiblePublicly: false,
    units: [
      {
        id: "sombra-lyra-intercessors",
        name: "Intercessor Squad",
        points: 105,
        quantity: 1,
        experience: 0,
        rank: "Asalto"
      }
    ]
  },
  {
    id: "sombra-saint-veil",
    factionId: "space-marines",
    name: "Escuadra del Velo",
    currentSystemId: "saint-veil",
    status: "in_war",
    pointsTotal: 760,
    isVisiblePublicly: false,
    units: [
      {
        id: "sombra-saint-redemptor",
        name: "Redemptor Dreadnought",
        points: 185,
        quantity: 1,
        experience: 1,
        rank: "Anciano"
      }
    ]
  },
  {
    id: "cult-blackglass-garrison",
    factionId: "cultos-genestealer",
    name: "Celula de Blackglass",
    currentSystemId: "blackglass",
    status: "ready",
    pointsTotal: 520,
    isVisiblePublicly: false,
    units: [
      {
        id: "cult-blackglass-neophytes",
        name: "Neophyte Hybrids",
        points: 80,
        quantity: 4,
        experience: 1,
        rank: "Celula"
      }
    ]
  },
  {
    id: "cult-mirrorcoil-front",
    factionId: "cultos-genestealer",
    name: "Alzamiento de Mirrorcoil",
    currentSystemId: "mirrorcoil",
    status: "ready",
    pointsTotal: 740,
    isVisiblePublicly: false,
    units: [
      {
        id: "cult-mirrorcoil-acolytes",
        name: "Acolyte Hybrids",
        points: 95,
        quantity: 3,
        experience: 2,
        rank: "Alzados",
        enhancementText: "Red de tuneles"
      }
    ]
  },
  {
    id: "cult-sabbath-convoy",
    factionId: "cultos-genestealer",
    name: "Convoy del Sabbath",
    currentSystemId: "blackglass",
    status: "moving",
    pointsTotal: 340,
    isVisiblePublicly: false,
    units: [
      {
        id: "cult-sabbath-ridgerunner",
        name: "Achilles Ridgerunner",
        points: 120,
        quantity: 1,
        experience: 0,
        rank: "Movil"
      }
    ]
  },
  {
    id: "cult-saint-revolt",
    factionId: "cultos-genestealer",
    name: "Revuelta del Velo",
    currentSystemId: "saint-veil",
    status: "in_war",
    pointsTotal: 700,
    isVisiblePublicly: false,
    units: [
      {
        id: "cult-saint-neophytes",
        name: "Neophyte Hybrids",
        points: 80,
        quantity: 5,
        experience: 1,
        rank: "Insurgentes"
      }
    ]
  },
  {
    id: "necron-thokt-phalanx",
    factionId: "necrones",
    name: "Falange Thokt",
    currentSystemId: "thokt-vault",
    status: "ready",
    pointsTotal: 620,
    isVisiblePublicly: false,
    units: [
      {
        id: "necron-thokt-warriors",
        name: "Necron Warriors",
        points: 80,
        quantity: 3,
        experience: 1,
        rank: "Linea"
      }
    ]
  },
  {
    id: "necron-ghostlight-front",
    factionId: "necrones",
    name: "Cohorte Ghostlight",
    currentSystemId: "ghostlight",
    status: "ready",
    pointsTotal: 810,
    isVisiblePublicly: false,
    units: [
      {
        id: "necron-ghostlight-skorpekh",
        name: "Skorpekh Destroyers",
        points: 140,
        quantity: 2,
        experience: 2,
        rank: "Destructores",
        enhancementText: "Protocolos de cosecha"
      }
    ]
  },
  {
    id: "necron-novem-cohort",
    factionId: "necrones",
    name: "Cohorte Novem",
    currentSystemId: "thokt-vault",
    status: "moving",
    pointsTotal: 420,
    isVisiblePublicly: false,
    units: [
      {
        id: "necron-novem-immortals",
        name: "Immortals",
        points: 105,
        quantity: 2,
        experience: 0,
        rank: "Escolta"
      }
    ]
  },
  {
    id: "necron-ossuary-reclaimers",
    factionId: "necrones",
    name: "Reclamadores del Osario",
    currentSystemId: "ossuary-reach",
    status: "in_war",
    pointsTotal: 760,
    isVisiblePublicly: false,
    units: [
      {
        id: "necron-ossuary-warriors",
        name: "Necron Warriors",
        points: 80,
        quantity: 4,
        experience: 1,
        rank: "Reclamadores"
      }
    ]
  },
  {
    id: "death-mordax-vector",
    factionId: "legiones-daemonicas",
    name: "Vector de Mordax",
    currentSystemId: "mordax",
    status: "ready",
    pointsTotal: 610,
    isVisiblePublicly: false,
    units: [
      {
        id: "death-mordax-poxwalkers",
        name: "Poxwalkers",
        points: 70,
        quantity: 4,
        experience: 1,
        rank: "Marea"
      }
    ]
  },
  {
    id: "death-plaguefall-front",
    factionId: "legiones-daemonicas",
    name: "Hueste Plaguefall",
    currentSystemId: "plaguefall-bastion",
    status: "ready",
    pointsTotal: 830,
    isVisiblePublicly: false,
    units: [
      {
        id: "death-plaguefall-marines",
        name: "Plague Marines",
        points: 115,
        quantity: 3,
        experience: 2,
        rank: "Veteranos",
        enhancementText: "Nube toxica"
      }
    ]
  },
  {
    id: "death-drusus-procession",
    factionId: "legiones-daemonicas",
    name: "Procesion de Drusus",
    currentSystemId: "mordax",
    status: "moving",
    pointsTotal: 390,
    isVisiblePublicly: false,
    units: [
      {
        id: "death-drusus-drone",
        name: "Foetid Bloat-drone",
        points: 145,
        quantity: 1,
        experience: 0,
        rank: "Movil"
      }
    ]
  },
  {
    id: "death-ossuary-pox",
    factionId: "legiones-daemonicas",
    name: "Marea Pox del Osario",
    currentSystemId: "ossuary-reach",
    status: "in_war",
    pointsTotal: 710,
    isVisiblePublicly: false,
    units: [
      {
        id: "death-ossuary-marines",
        name: "Plague Marines",
        points: 115,
        quantity: 2,
        experience: 1,
        rank: "Plaga"
      }
    ]
  }
];

const baseUnits: CampaignSnapshot["units"] = unitGroups.flatMap((group) =>
  group.units.map((unit) => {
    const startingQuantity = unit.startingQuantity ?? getMockDefaultQuantity(unit.name);
    const category = getMockUnitCategory(unit.name);
    const unitKeywords = getMockUnitKeywords(category);

    return {
      id: unit.id,
      factionId: group.factionId,
      unitTemplateId: getMockUnitTemplateId(unit.name),
      name: unit.name,
      currentSystemId: group.currentSystemId,
      status: group.status,
      category,
      unitType: getMockUnitType(category),
      unitKeywords,
      points: unit.points,
      quantity: unit.quantity,
      startingQuantity,
      woundsTaken: unit.woundsTaken ?? 0,
      experience: unit.experience,
      isVisiblePublicly: group.isVisiblePublicly,
      parentUnitId: null,
      destroyedAt: null,
      rank: unit.rank ?? null,
      enhancementText: unit.enhancementText ?? null,
      notes: null
    };
  })
);

const characterUnits: CampaignSnapshot["units"] = [
  makeMockCharacterUnit("character-aeldari-warboss", "aeldari", "Warboss Gorbad Krumpa", "unit-aeldari-warboss", "cinder-maw", 110),
  makeMockCharacterUnit("character-necrones-overlord", "necrones", "Overlord Sekh-Nemesor", "unit-necrones-overlord", "thokt-vault", 100),
  makeMockCharacterUnit("character-custodes-shield-captain", "adeptus-custodes", "Shield-Captain Valerian Kha", "unit-adeptus-custodes-shield-captain", "kharon-prime", 120),
  makeMockCharacterUnit("character-culto-primus", "cultos-genestealer", "Primus Korda Vhal", "unit-culto-primus", "blackglass", 80),
  makeMockCharacterUnit("character-sombra-captain", "space-marines", "Captain Aster Valen", "unit-sombra-captain", "sa-cea-gate", 95),
  makeMockCharacterUnit("character-muerte-lord-contagion", "legiones-daemonicas", "Lord Morbus Vane", "unit-muerte-lord-contagion", "mordax", 100)
];

const units: CampaignSnapshot["units"] = generated40kInitialUnits.filter((unit) => isActiveFactionId(unit.factionId));

const movements: CampaignSnapshot["movements"] = [];

type MockUnitTemplate = Omit<CampaignSnapshot["unitTemplates"][number], "defaultQuantity" | "woundsPerModel" | "unitType" | "unitKeywords">;

const unitTemplateBase: MockUnitTemplate[] = [
  {
    id: "unit-aeldari-boyz",
    factionId: "aeldari",
    name: "Boyz",
    category: "Infanteria",
    points: 80,
    supplyCost: 12,
    mineralsCost: 2,
    honorCost: 0,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Masa brutal de combate cercano.",
    isAvailable: true
  },
  {
    id: "unit-aeldari-meganobz",
    factionId: "aeldari",
    name: "Meganobz",
    category: "Elite",
    points: 105,
    supplyCost: 6,
    mineralsCost: 5,
    honorCost: 1,
    goldCost: 1,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Noblez armados con servoarmaduras improvisadas.",
    isAvailable: true
  },
  {
    id: "unit-aeldari-deff-dread",
    factionId: "aeldari",
    name: "Deff Dread",
    category: "Vehiculo",
    points: 135,
    supplyCost: 2,
    mineralsCost: 10,
    honorCost: 1,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Maquina andante de metal, humo y mala intencion.",
    isAvailable: true
  },
  {
    id: "unit-necrones-warriors",
    factionId: "necrones",
    name: "Necron Warriors",
    category: "Infanteria",
    points: 80,
    supplyCost: 8,
    mineralsCost: 4,
    honorCost: 0,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Linea inmortal reanimada desde las criptas.",
    isAvailable: true
  },
  {
    id: "unit-necrones-immortals",
    factionId: "necrones",
    name: "Immortals",
    category: "Elite",
    points: 105,
    supplyCost: 6,
    mineralsCost: 5,
    honorCost: 1,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Guerreros superiores con protocolos de elite.",
    isAvailable: true
  },
  {
    id: "unit-necrones-skorpekh",
    factionId: "necrones",
    name: "Skorpekh Destroyers",
    category: "Elite",
    points: 140,
    supplyCost: 4,
    mineralsCost: 7,
    honorCost: 2,
    goldCost: 1,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Asesinos de fase con cuerpos disenados para la destruccion.",
    isAvailable: true
  },
  {
    id: "unit-guardia-cadian",
    factionId: "adeptus-custodes",
    name: "Custodian Guard",
    category: "Infanteria",
    points: 80,
    supplyCost: 12,
    mineralsCost: 2,
    honorCost: 0,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Infanteria disciplinada lista para sostener la linea.",
    isAvailable: true
  },
  {
    id: "unit-guardia-kasrkin",
    factionId: "adeptus-custodes",
    name: "Kasrkin",
    category: "Elite",
    points: 105,
    supplyCost: 8,
    mineralsCost: 4,
    honorCost: 1,
    goldCost: 1,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Veteranos de asalto con equipo especializado.",
    isAvailable: true
  },
  {
    id: "unit-guardia-leman-russ",
    factionId: "adeptus-custodes",
    name: "Caladius Grav-tank",
    category: "Vehiculo",
    points: 145,
    supplyCost: 2,
    mineralsCost: 11,
    honorCost: 1,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Blindado pesado de batalla para romper frentes.",
    isAvailable: true
  },
  {
    id: "unit-culto-neophytes",
    factionId: "cultos-genestealer",
    name: "Neophyte Hybrids",
    category: "Infanteria",
    points: 80,
    supplyCost: 12,
    mineralsCost: 2,
    honorCost: 0,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Celulas insurgentes armadas desde las profundidades.",
    isAvailable: true
  },
  {
    id: "unit-culto-acolytes",
    factionId: "cultos-genestealer",
    name: "Acolyte Hybrids",
    category: "Elite",
    points: 95,
    supplyCost: 8,
    mineralsCost: 3,
    honorCost: 1,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Fanaticos hibridos preparados para ataques decisivos.",
    isAvailable: true
  },
  {
    id: "unit-culto-ridgerunner",
    factionId: "cultos-genestealer",
    name: "Achilles Ridgerunner",
    category: "Vehiculo",
    points: 120,
    supplyCost: 3,
    mineralsCost: 8,
    honorCost: 1,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Vehículo de incursión y reconocimiento rápido.",
    isAvailable: true
  },
  {
    id: "unit-sombra-intercessors",
    factionId: "space-marines",
    name: "Intercessor Squad",
    category: "Infanteria",
    points: 105,
    supplyCost: 8,
    mineralsCost: 4,
    honorCost: 1,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Astartes de linea con doctrina flexible.",
    isAvailable: true
  },
  {
    id: "unit-sombra-terminators",
    factionId: "space-marines",
    name: "Terminator Squad",
    category: "Elite",
    points: 160,
    supplyCost: 5,
    mineralsCost: 6,
    honorCost: 3,
    goldCost: 2,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Veteranos con armadura tactica dreadnought.",
    isAvailable: true
  },
  {
    id: "unit-sombra-redemptor",
    factionId: "space-marines",
    name: "Redemptor Dreadnought",
    category: "Vehiculo",
    points: 185,
    supplyCost: 2,
    mineralsCost: 10,
    honorCost: 3,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Dreadnought pesado para rupturas de linea.",
    isAvailable: true
  },
  {
    id: "unit-muerte-poxwalkers",
    factionId: "legiones-daemonicas",
    name: "Poxwalkers",
    category: "Infanteria",
    points: 70,
    supplyCost: 12,
    mineralsCost: 1,
    honorCost: 0,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Multitud infectada que avanza sin miedo.",
    isAvailable: true
  },
  {
    id: "unit-muerte-plague-marines",
    factionId: "legiones-daemonicas",
    name: "Plague Marines",
    category: "Infanteria",
    points: 115,
    supplyCost: 8,
    mineralsCost: 5,
    honorCost: 1,
    goldCost: 1,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Marines de plaga resistentes y metodicos.",
    isAvailable: true
  },
  {
    id: "unit-muerte-bloat-drone",
    factionId: "legiones-daemonicas",
    name: "Foetid Bloat-drone",
    category: "Vehiculo",
    points: 145,
    supplyCost: 3,
    mineralsCost: 8,
    honorCost: 2,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Dron demoniaco de apoyo y hostigamiento.",
    isAvailable: true
  },
  {
    id: "unit-aeldari-warboss",
    factionId: "aeldari",
    name: "Warboss",
    category: "Personaje",
    points: 110,
    supplyCost: 8,
    mineralsCost: 5,
    honorCost: 2,
    goldCost: 1,
    industrialMaterialCost: 2,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Jefe de guerra preparado para portar trofeos sagrados.",
    isAvailable: true
  },
  {
    id: "unit-necrones-overlord",
    factionId: "necrones",
    name: "Overlord",
    category: "Personaje",
    points: 100,
    supplyCost: 6,
    mineralsCost: 6,
    honorCost: 2,
    goldCost: 1,
    industrialMaterialCost: 2,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Noble inmortal con protocolos de mando dinastico.",
    isAvailable: true
  },
  {
    id: "unit-guardia-castellan",
    factionId: "adeptus-custodes",
    name: "Shield-Captain",
    category: "Personaje",
    points: 70,
    supplyCost: 8,
    mineralsCost: 4,
    honorCost: 1,
    goldCost: 1,
    industrialMaterialCost: 1,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Oficial veterano de campana y enlace de mando.",
    isAvailable: true
  },
  {
    id: "unit-culto-primus",
    factionId: "cultos-genestealer",
    name: "Primus",
    category: "Personaje",
    points: 80,
    supplyCost: 7,
    mineralsCost: 4,
    honorCost: 2,
    goldCost: 1,
    industrialMaterialCost: 1,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Lider de celula capaz de guiar la insurreccion.",
    isAvailable: true
  },
  {
    id: "unit-sombra-captain",
    factionId: "space-marines",
    name: "Captain",
    category: "Personaje",
    points: 95,
    supplyCost: 6,
    mineralsCost: 6,
    honorCost: 3,
    goldCost: 1,
    industrialMaterialCost: 2,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Capitán de la Sombra del Emperador.",
    isAvailable: true
  },
  {
    id: "unit-muerte-lord-contagion",
    factionId: "legiones-daemonicas",
    name: "Lord of Contagion",
    category: "Personaje",
    points: 100,
    supplyCost: 7,
    mineralsCost: 6,
    honorCost: 3,
    goldCost: 1,
    industrialMaterialCost: 2,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 86400,
    notes: "Campeón corrupto de resistencia sobrenatural.",
    isAvailable: true
  }
];

type TroopTreeConfigNode = {
  slug: string;
  name: string;
  description: string;
  branchSlug: string;
  tier: number;
  positionX: number;
  positionY: number;
  costTechnology: number;
  researchTimeSeconds: number;
  iconKey: string;
  effectSummary: string;
  prerequisiteSlugs?: string[];
  unitTemplateSlugs?: string[];
};

type TroopTreeConfigTree = {
  factionSlug: string;
  treeKey: string;
  status: "draft" | "ready";
  branches: Array<{ slug: string; name: string }>;
  nodes: TroopTreeConfigNode[];
};

const troopTreeConfig = troopTreeConfigJson as { trees: TroopTreeConfigTree[] };
const readyTroopTrees = troopTreeConfig.trees.filter((tree) => tree.status === "ready");
const troopTechnologyNodes: CampaignSnapshot["technologyNodes"] = readyTroopTrees.flatMap((tree) =>
  tree.nodes.map((node) => {
    const branch = tree.branches.find((candidate) => candidate.slug === node.branchSlug);

    return makeTechnologyNode({
      id: node.slug,
      slug: node.slug,
      treeKey: tree.treeKey,
      name: node.name,
      description: node.description,
      branch: branch?.name ?? node.branchSlug,
      tier: node.tier,
      positionX: node.positionX,
      positionY: node.positionY,
      costTechnology: node.costTechnology,
      researchTimeSeconds: node.researchTimeSeconds,
      iconKey: node.iconKey,
      effectSummary: node.effectSummary,
      isStarter: false
    });
  })
);
const troopTechnologyPrerequisites: CampaignSnapshot["technologyPrerequisites"] = readyTroopTrees.flatMap((tree) =>
  tree.nodes.flatMap((node) =>
    (node.prerequisiteSlugs ?? []).map((requiredNodeId, index) => ({
      technologyNodeId: node.slug,
      requiredNodeId,
      prerequisiteGroup: index + 1
    }))
  )
);
const troopTechnologyEffects: CampaignSnapshot["technologyEffects"] = readyTroopTrees.flatMap((tree) =>
  tree.nodes.map((node) => ({
    id: `effect-${node.slug}-units`,
    technologyNodeId: node.slug,
    effectType: "unlock_unit_template",
    payload: { unitTemplateSlugs: node.unitTemplateSlugs ?? [] }
  }))
);
const troopTechnologyByUnitSlug = new Map(
  readyTroopTrees.flatMap((tree) =>
    tree.nodes.flatMap((node) => (node.unitTemplateSlugs ?? []).map((unitSlug) => [unitSlug, node.slug] as const))
  )
);
type MfmCostOptionsUnit = (typeof mfmCostOptions.units)[number];
type MfmChange = { direction?: unknown; amount?: unknown } | null | undefined;

const mfmOptionsByTemplateId = new Map<string, MfmCostOptionsUnit>(
  mfmCostOptions.units.map((unit) => [`unit-${unit.factionSlug}-${unit.unitSlug}`, unit])
);

function getMfmChangeDirection(change: MfmChange): "up" | "down" | null {
  return change?.direction === "up" || change?.direction === "down" ? change.direction : null;
}

function getMfmChangeAmount(change: MfmChange) {
  return typeof change?.amount === "number" ? change.amount : null;
}

const unitTemplates: CampaignSnapshot["unitTemplates"] = generated40kUnitTemplates.filter((template) => isActiveFactionId(template.factionId)).map((template) => {
  const requiredTechnologyNodeId = troopTechnologyByUnitSlug.get(template.id);
  const mfmOptions = mfmOptionsByTemplateId.get(template.id);
  const withMfmOptions = {
    ...template,
    modelOptions:
      mfmOptions?.modelOptions.map((option, index) => ({
        id: `${template.id}-model-option-${index}`,
        unitTemplateId: template.id,
        slug: `${option.minModels}-${option.maxModels}-${option.copyRange.from}-${option.copyRange.to ?? "plus"}`,
        label: option.label,
        models: option.models,
        minModels: option.minModels,
        maxModels: option.maxModels,
        points: option.points,
        copyFrom: option.copyRange.from,
        copyTo: option.copyRange.to,
        source: option.source,
        pointsChangeDirection: getMfmChangeDirection((option as { change?: MfmChange }).change),
        pointsChangeAmount: getMfmChangeAmount((option as { change?: MfmChange }).change)
      })) ?? [],
    wargearOptions:
      mfmOptions?.wargearOptions.map((option) => ({
        id: `${template.id}-wargear-${option.slug}`,
        unitTemplateId: template.id,
        slug: option.slug,
        name: option.name,
        points: option.points,
        pricing: option.pricing,
        source: option.source,
        pointsChangeDirection: getMfmChangeDirection((option as { change?: MfmChange }).change),
        pointsChangeAmount: getMfmChangeAmount((option as { change?: MfmChange }).change)
      })) ?? []
  };

  return requiredTechnologyNodeId
    ? {
        ...withMfmOptions,
        isAvailable: true,
        requiredTechnologyNodeId
      }
    : withMfmOptions;
});

void baseUnits;
void characterUnits;
void unitTemplateBase;

const conflicts: CampaignSnapshot["conflicts"] = [];

const missions: CampaignSnapshot["missions"] = [];

const technologyNodes: CampaignSnapshot["technologyNodes"] = [
  makeTechnologyNode({ id: "fundacion-planetaria", slug: "fundacion-planetaria", name: "Fundacion Planetaria", description: "Protocolos básicos para levantar la primera infraestructura estable de campana.", branch: "Progreso", tier: 0, positionX: 46, positionY: 48, costTechnology: 0, researchTimeSeconds: 1800, iconKey: "foundation", effectSummary: "Permite construir Barracones de Infanteria y Granjas Biologicas.", isStarter: true }),
  makeTechnologyNode({ id: "maquinaria-belica", slug: "maquinaria-belica", name: "Maquinaria Belica", description: "Talleres, elevadores y servosistemas para fabricar y mantener vehiculos.", branch: "Progreso", tier: 1, positionX: 36, positionY: 34, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "war_machine", effectSummary: "Permite construir Talleres de Guerra.", isStarter: false }),
  makeTechnologyNode({ id: "criadero-guerra", slug: "criadero-guerra", name: "Criadero de Guerra", description: "Jaulas, ritos de control y habitats adaptados para criaturas de guerra.", branch: "Progreso", tier: 1, positionX: 54, positionY: 34, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "beast", effectSummary: "Permite construir Nidos de Bestias.", isStarter: false }),
  makeTechnologyNode({ id: "asamblea-planetaria", slug: "asamblea-planetaria", name: "Asamblea Planetaria", description: "Estructura de mando local capaz de sostener oficiales, personajes y estados mayores.", branch: "Progreso", tier: 2, positionX: 45, positionY: 22, costTechnology: 2, researchTimeSeconds: 21600, iconKey: "command", effectSummary: "Permite construir Cuarteles de Mando.", isStarter: false }),
  makeTechnologyNode({ id: "camara-leyendas", slug: "camara-leyendas", name: "Camara de Leyendas", description: "Archivo sellado de gestas imposibles y protocolos excepcionales para reclutar unidades [Crucible]. Bloqueada por ahora.", branch: "Progreso", tier: 3, positionX: 55, positionY: 22, costTechnology: 2, researchTimeSeconds: 21600, iconKey: "legend_chamber", effectSummary: "Permitira construir Camaras de Leyendas para reclutar unidades [Crucible].", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "procesado-metalurgico", slug: "procesado-metalurgico", name: "Procesado Metalurgico", description: "Cadenas industriales para convertir mineral bruto en materiales de construccion.", branch: "Progreso", tier: 1, positionX: 63, positionY: 50, costTechnology: 0, researchTimeSeconds: 1800, iconKey: "factory", effectSummary: "Permite construir Plantas de Fundicion.", isStarter: false }),
  makeTechnologyNode({ id: "cristalizacion-combustible-cuantico", slug: "cristalizacion-combustible-cuantico", name: "Cristalizacion de Combustible Cuantico", description: "Tecnicas de estabilizacion para refinar Iridium util en rutas de salto.", branch: "Progreso", tier: 2, positionX: 73, positionY: 39, costTechnology: 0, researchTimeSeconds: 1800, iconKey: "uridium", effectSummary: "Permite construir Refinerias de Iridium.", isStarter: false }),
  makeTechnologyNode({ id: "extraccion-subterranea", slug: "extraccion-subterranea", name: "Extraccion Subterranea", description: "Sondeos profundos y maquinaria pesada para explotar vetas minerales.", branch: "Progreso", tier: 2, positionX: 73, positionY: 55, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "mine", effectSummary: "Permite construir Complejos Mineros.", isStarter: false }),
  makeTechnologyNode({ id: "monumentos-gloria", slug: "monumentos-gloria", name: "Monumentos a la Gloria", description: "Arquitectura ceremonial para convertir victorias, lealtad y reliquias en poder de campaña.", branch: "Progreso", tier: 2, positionX: 73, positionY: 71, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "honor", effectSummary: "Desbloquea Monumento y Santuario de Reliquias.", isStarter: false }),
  makeTechnologyNode({ id: "fiebre-oro", slug: "fiebre-oro", name: "La Fiebre del Oro", description: "Prospeccion avanzada para localizar y explotar yacimientos preciosos.", branch: "Progreso", tier: 3, positionX: 86, positionY: 55, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "gold", effectSummary: "Permite construir Minas de Oro.", isStarter: false }),
  makeTechnologyNode({ id: "pactos-mercantiles", slug: "pactos-mercantiles", name: "Pactos Mercantiles", description: "Acuerdos y garantias para atraer camaras de comercio al frente.", branch: "Progreso", tier: 4, positionX: 91, positionY: 40, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "commerce", effectSummary: "Permite construir Camaras de Comercio.", isStarter: false }),
  makeTechnologyNode({ id: "contactos-economicos", slug: "contactos-economicos", name: "Contactos Economicos", description: "Red de intermediarios y agentes comerciales con acceso al mercader.", branch: "Progreso", tier: 5, positionX: 96, positionY: 30, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "merchant", effectSummary: "Permite comerciar con el Mercader.", isStarter: false }),
  makeTechnologyNode({ id: "tratos-preferentes", slug: "tratos-preferentes", name: "Tratos Preferentes", description: "Credenciales, favores y rutas protegidas que reducen las tasas del mercader.", branch: "Progreso", tier: 6, positionX: 96, positionY: 18, costTechnology: 2, researchTimeSeconds: 21600, iconKey: "trade_discount", effectSummary: "Mejora precios del Mercader: compra a 1.5x y venta a 0.75x del valor.", isStarter: false }),
  makeTechnologyNode({ id: "mercado-galactico", slug: "mercado-galactico", name: "Mercado Galáctico", description: "Acceso a tablones de oferta y rutas de intercambio entre jugadores.", branch: "Progreso", tier: 5, positionX: 96, positionY: 52, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "market", effectSummary: "Permite usar el Comercio Estelar.", isStarter: false }),
  makeTechnologyNode({ id: "aranceles-privilegiados", slug: "aranceles-privilegiados", name: "Aranceles Privilegiados", description: "Tratados fiscales que reducen la comision del comercio estelar.", branch: "Progreso", tier: 6, positionX: 96, positionY: 64, costTechnology: 2, researchTimeSeconds: 21600, iconKey: "tariff", effectSummary: "Reduce tu comision de Comercio Estelar al 10%, minimo 1 oro.", isStarter: false }),
  makeTechnologyNode({ id: "oficina-inteligencia", slug: "oficina-inteligencia", name: "Oficina de Inteligencia", description: "Primer nucleo burocratico para futuras operaciones de espionaje.", branch: "Inteligencia", tier: 1, positionX: 18, positionY: 58, costTechnology: 0, researchTimeSeconds: 1800, iconKey: "intelligence", effectSummary: "Proximamente: desbloqueara Nexos de Inteligencia.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "celulas-informacion", slug: "celulas-informacion", name: "Celulas de Informacion", description: "Redes discretas de observadores, informadores y escuchas.", branch: "Inteligencia", tier: 2, positionX: 14, positionY: 70, costTechnology: 2, researchTimeSeconds: 21600, iconKey: "cells", effectSummary: "Proximamente: produccion de espionaje y Antenas de Reconocimiento.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "doctrina-clandestina", slug: "doctrina-clandestina", name: "Doctrina Clandestina", description: "Protocolos de infiltracion sostenida para operaciones encubiertas.", branch: "Inteligencia", tier: 3, positionX: 8, positionY: 82, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "cloak", effectSummary: "Proximamente: mejora de produccion de espionaje.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "doble-agente", slug: "doble-agente", name: "Doble Agente", description: "Contramedidas para detectar redes enemigas y operaciones infiltradas.", branch: "Inteligencia", tier: 3, positionX: 18, positionY: 86, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "agent", effectSummary: "Proximamente: probabilidad de detectar espionaje enemigo.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "tecnologia-sar", slug: "tecnologia-sar", name: "Tecnologia SAR", description: "Lectura de largo alcance para reconocimiento y triangulacion avanzada.", branch: "Inteligencia", tier: 3, positionX: 28, positionY: 82, costTechnology: 1, researchTimeSeconds: 7200, iconKey: "radar", effectSummary: "Proximamente: duplicara alcance de Antenas de Reconocimiento.", isStarter: false, implementationStatus: "planned" }),
  ...troopTechnologyNodes,
  makeTechnologyNode({ id: "entrenamiento-linea", slug: "entrenamiento-linea", name: "Entrenamiento de linea", description: "Nodo militar común legacy sustituido por árboles de tropas por facción.", branch: "Mando militar", tier: 0, positionX: 22, positionY: 32, costTechnology: 0, researchTimeSeconds: 1800, iconKey: "infantry", effectSummary: "Obsoleto.", isStarter: true, implementationStatus: "deprecated" }),
  makeTechnologyNode({ id: "logistica-frente", slug: "logistica-frente", name: "Logistica de frente", description: "Nodo militar común legacy sustituido por árboles de tropas por facción.", branch: "Mando militar", tier: 1, positionX: 10, positionY: 22, costTechnology: 4, researchTimeSeconds: 345600, iconKey: "supply", effectSummary: "Obsoleto.", isStarter: false, implementationStatus: "deprecated" }),
  makeTechnologyNode({ id: "cadenas-mando", slug: "cadenas-mando", name: "Cadenas de mando", description: "Nodo militar común legacy sustituido por árboles de tropas por facción.", branch: "Mando militar", tier: 1, positionX: 25, positionY: 18, costTechnology: 4, researchTimeSeconds: 345600, iconKey: "command", effectSummary: "Obsoleto.", isStarter: false, implementationStatus: "deprecated" }),
  makeTechnologyNode({ id: "veteranos-guerra", slug: "veteranos-guerra", name: "Veteranos de guerra", description: "Nodo militar común legacy sustituido por árboles de tropas por facción.", branch: "Infanteria y elite", tier: 1, positionX: 30, positionY: 42, costTechnology: 4, researchTimeSeconds: 345600, iconKey: "elite", effectSummary: "Obsoleto.", isStarter: false, implementationStatus: "deprecated" }),
  makeTechnologyNode({ id: "especializacion-elite", slug: "especializacion-elite", name: "Especializacion de elite", description: "Nodo militar común legacy sustituido por árboles de tropas por facción.", branch: "Infanteria y elite", tier: 2, positionX: 18, positionY: 48, costTechnology: 8, researchTimeSeconds: 691200, iconKey: "elite", effectSummary: "Obsoleto.", isStarter: false, implementationStatus: "deprecated" }),
  makeTechnologyNode({ id: "motores-guerra", slug: "motores-guerra", name: "Motores de guerra", description: "Nodo militar común legacy sustituido por árboles de tropas por facción.", branch: "Blindados y maquinas", tier: 2, positionX: 42, positionY: 15, costTechnology: 8, researchTimeSeconds: 691200, iconKey: "vehicle", effectSummary: "Obsoleto.", isStarter: false, implementationStatus: "deprecated" }),
  makeTechnologyNode({ id: "blindaje-reforzado", slug: "blindaje-reforzado", name: "Blindaje reforzado", description: "Nodo militar común legacy sustituido por árboles de tropas por facción.", branch: "Blindados y maquinas", tier: 3, positionX: 55, positionY: 16, costTechnology: 12, researchTimeSeconds: 1036800, iconKey: "vehicle", effectSummary: "Obsoleto.", isStarter: false, implementationStatus: "deprecated" }),
  makeTechnologyNode({ id: "matrices-eficiencia", slug: "matrices-eficiencia", name: "Matrices de eficiencia", description: "Nodo militar común legacy sustituido por árboles de tropas por facción.", branch: "Arqueotecnologia", tier: 3, positionX: 36, positionY: 62, costTechnology: 12, researchTimeSeconds: 1036800, iconKey: "matrix", effectSummary: "Obsoleto.", isStarter: false, implementationStatus: "deprecated" })
];

const prerequisiteRows = [
  ["maquinaria-belica", "fundacion-planetaria", 1],
  ["criadero-guerra", "fundacion-planetaria", 1],
  ["asamblea-planetaria", "maquinaria-belica", 1],
  ["asamblea-planetaria", "criadero-guerra", 1],
  ["camara-leyendas", "asamblea-planetaria", 1],
  ["procesado-metalurgico", "fundacion-planetaria", 1],
  ["cristalizacion-combustible-cuantico", "procesado-metalurgico", 1],
  ["extraccion-subterranea", "procesado-metalurgico", 1],
  ["monumentos-gloria", "procesado-metalurgico", 1],
  ["fiebre-oro", "cristalizacion-combustible-cuantico", 1],
  ["fiebre-oro", "extraccion-subterranea", 2],
  ["fiebre-oro", "monumentos-gloria", 3],
  ["pactos-mercantiles", "fiebre-oro", 1],
  ["contactos-economicos", "pactos-mercantiles", 1],
  ["tratos-preferentes", "contactos-economicos", 1],
  ["mercado-galactico", "pactos-mercantiles", 1],
  ["aranceles-privilegiados", "mercado-galactico", 1],
  ["celulas-informacion", "oficina-inteligencia", 1],
  ["doctrina-clandestina", "celulas-informacion", 1],
  ["doble-agente", "celulas-informacion", 1],
  ["tecnologia-sar", "celulas-informacion", 1],
  ["logistica-frente", "entrenamiento-linea", 1],
  ["cadenas-mando", "entrenamiento-linea", 1],
  ["veteranos-guerra", "entrenamiento-linea", 1],
  ["especializacion-elite", "veteranos-guerra", 1],
  ["motores-guerra", "maquinaria-belica", 1],
  ["blindaje-reforzado", "motores-guerra", 1],
  ["matrices-eficiencia", "procesado-metalurgico", 1]
] as const;

const technologyPrerequisites: CampaignSnapshot["technologyPrerequisites"] = [
  ...prerequisiteRows.map(
    ([technologyNodeId, requiredNodeId, prerequisiteGroup]): CampaignSnapshot["technologyPrerequisites"][number] => ({
      technologyNodeId,
      requiredNodeId,
      prerequisiteGroup
    })
  ),
  ...troopTechnologyPrerequisites
];

const factionTechnologies: CampaignSnapshot["factionTechnologies"] = factions.flatMap((faction) => [
  { factionId: faction.id, technologyNodeId: "fundacion-planetaria", status: "unlocked", unlockedAt: new Date(now).toISOString() },
  { factionId: faction.id, technologyNodeId: "maquinaria-belica", status: "available" },
  { factionId: faction.id, technologyNodeId: "criadero-guerra", status: "available" },
  { factionId: faction.id, technologyNodeId: "procesado-metalurgico", status: "available" }
]);

const technologyEffects: CampaignSnapshot["technologyEffects"] = [
  { id: "effect-fundacion-buildings", technologyNodeId: "fundacion-planetaria", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["barracon-infanteria", "granja-biologica"] } },
  { id: "effect-maquinaria-building", technologyNodeId: "maquinaria-belica", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["taller-guerra"] } },
  { id: "effect-criadero-building", technologyNodeId: "criadero-guerra", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["nido-bestias"] } },
  { id: "effect-asamblea-building", technologyNodeId: "asamblea-planetaria", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["cuartel-mando"] } },
  { id: "effect-camara-leyendas-building", technologyNodeId: "camara-leyendas", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["camara-leyendas"] } },
  { id: "effect-procesado-building", technologyNodeId: "procesado-metalurgico", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["planta-fundicion"] } },
  { id: "effect-cristalizacion-building", technologyNodeId: "cristalizacion-combustible-cuantico", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["refineria-iridium"] } },
  { id: "effect-extraccion-building", technologyNodeId: "extraccion-subterranea", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["complejo-minero"] } },
  { id: "effect-monumentos-building", technologyNodeId: "monumentos-gloria", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["monumento"] } },
  { id: "effect-monumentos-relic-sanctuary", technologyNodeId: "monumentos-gloria", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["santuario-reliquias"] } },
  { id: "effect-fiebre-building", technologyNodeId: "fiebre-oro", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["mina-oro"] } },
  { id: "effect-pactos-building", technologyNodeId: "pactos-mercantiles", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["camara-comercio"] } },
  { id: "effect-contactos-merchant", technologyNodeId: "contactos-economicos", effectType: "unlock_merchant_trade", payload: {} },
  { id: "effect-tratos-merchant", technologyNodeId: "tratos-preferentes", effectType: "merchant_rate_modifier", payload: { buyMultiplier: 1.5, sellMultiplier: 0.75 } },
  { id: "effect-mercado-stellar", technologyNodeId: "mercado-galactico", effectType: "unlock_stellar_trade", payload: {} },
  { id: "effect-aranceles-fee", technologyNodeId: "aranceles-privilegiados", effectType: "stellar_trade_fee_discount", payload: { percent: 10, minimumGold: 1 } }
].concat(troopTechnologyEffects);

const buildingTemplates: CampaignSnapshot["buildingTemplates"] = [
  makeBuildingTemplate({ id: "barracon-infanteria", name: "Barracon de Infanteria", category: "Reclutamiento", description: "Centro de instruccion para tropas de linea y cuadros veteranos.", buildingKind: "recruitment", industrialMaterialCost: 20, constructionTimeSeconds: 86400, allowedUnitCategories: ["Infanteria", "Elite"], requiredTechnologyNodeId: "fundacion-planetaria", iconKey: "infantry_barracks" }),
  makeBuildingTemplate({ id: "cuartel-mando", name: "Cuartel de Mando", category: "Reclutamiento", description: "Instalacion de oficiales, heroes y personajes de mando.", buildingKind: "recruitment", industrialMaterialCost: 42, constructionTimeSeconds: 259200, allowedUnitCategories: ["Personaje"], requiredTechnologyNodeId: "asamblea-planetaria", iconKey: "command_quarters" }),
  makeBuildingTemplate({ id: "camara-leyendas", name: "Camara de Leyendas", category: "Reclutamiento", description: "Camara sellada para reclutar unidades [Crucible] cuando su tecnologia deje de estar bloqueada.", buildingKind: "recruitment", industrialMaterialCost: 56, constructionTimeSeconds: 259200, allowedUnitCategories: ["Personaje", "Linea de batalla", "Transporte", "Otras hojas de datos", "Aliada", "Infanteria", "Elite", "Vehiculo", "Monstruo", "Hoja de datos", "Otro", "Superpesado"], requiredTechnologyNodeId: "camara-leyendas", iconKey: "legend_chamber" }),
  makeBuildingTemplate({ id: "taller-guerra", name: "Taller de Guerra", category: "Reclutamiento", description: "Bahias de reparacion y ensamblaje de vehiculos.", buildingKind: "recruitment", industrialMaterialCost: 38, constructionTimeSeconds: 259200, allowedUnitCategories: ["Vehiculo"], requiredTechnologyNodeId: "maquinaria-belica", iconKey: "war_workshop" }),
  makeBuildingTemplate({ id: "nido-bestias", name: "Nido de Bestias", category: "Reclutamiento", description: "Jaulas y rituales de control para monstruos de guerra.", buildingKind: "recruitment", industrialMaterialCost: 38, constructionTimeSeconds: 259200, allowedUnitCategories: ["Monstruo"], requiredTechnologyNodeId: "criadero-guerra", iconKey: "beast_lair" }),
  makeBuildingTemplate({ id: "camara-comercio", name: "Camara de Comercio", category: "Comercio", description: "Mercado orbital y punto de contacto con rutas mercantes.", buildingKind: "commerce", industrialMaterialCost: 30, constructionTimeSeconds: 172800, requiredTechnologyNodeId: "pactos-mercantiles", iconKey: "commerce" }),
  makeBuildingTemplate({ id: "nexo-inteligencia", name: "Nexo de Inteligencia", category: "Inteligencia", description: "Centro de analisis para operaciones de espionaje futuras.", buildingKind: "intelligence", industrialMaterialCost: 38, constructionTimeSeconds: 259200, requiredTechnologyNodeId: "oficina-inteligencia", iconKey: "intelligence" }),
  makeBuildingTemplate({ id: "antenas-reconocimiento", name: "Antenas de Reconocimiento", category: "Inteligencia", description: "Matrices de escucha y auspex de largo alcance.", buildingKind: "intelligence", industrialMaterialCost: 30, constructionTimeSeconds: 172800, requiredTechnologyNodeId: "celulas-informacion", iconKey: "recon" }),
  makeBuildingTemplate({ id: "granja-biologica", name: "Granja Biologica", category: "Produccion", description: "Complejos de biomasa y cultivos adaptados al frente.", buildingKind: "production", industrialMaterialCost: 20, constructionTimeSeconds: 86400, producedResourceKey: "supply", producedAmount: 0, requiredTechnologyNodeId: "fundacion-planetaria", iconKey: "biofarm" }),
  makeBuildingTemplate({ id: "complejo-minero", name: "Complejo Minero", category: "Produccion", description: "Pozos, excavadoras y refinerias de mineral bruto.", buildingKind: "production", industrialMaterialCost: 20, constructionTimeSeconds: 86400, producedResourceKey: "minerals", producedAmount: 0, requiredTechnologyNodeId: "extraccion-subterranea", iconKey: "mine" }),
  makeBuildingTemplate({ id: "refineria-iridium", name: "Refineria de Iridium", category: "Produccion", description: "Planta especializada para estabilizar cristales de salto.", buildingKind: "production", industrialMaterialCost: 26, constructionTimeSeconds: 172800, producedResourceKey: "uridium", producedAmount: 0, requiredTechnologyNodeId: "cristalizacion-combustible-cuantico", iconKey: "iridium_refinery" }),
  makeBuildingTemplate({ id: "mina-oro", name: "Mina de Oro", category: "Produccion", description: "Extraccion de metales preciosos para rutas comerciales.", buildingKind: "production", industrialMaterialCost: 34, constructionTimeSeconds: 172800, producedResourceKey: "gold", producedAmount: 0, requiredTechnologyNodeId: "fiebre-oro", iconKey: "gold_mine" }),
  makeBuildingTemplate({ id: "planta-fundicion", name: "Planta de Fundicion", category: "Produccion", description: "Produce Material Industrial para nuevas construcciones.", buildingKind: "production", industrialMaterialCost: 20, constructionTimeSeconds: 86400, producedResourceKey: "industrialMaterial", producedAmount: 0, requiredTechnologyNodeId: "procesado-metalurgico", iconKey: "foundry" }),
  makeBuildingTemplate({ id: "monumento", name: "Monumento", category: "Produccion", description: "Estructura ceremonial que transforma gloria local en Honor.", buildingKind: "production", industrialMaterialCost: 24, constructionTimeSeconds: 172800, producedResourceKey: "honor", producedAmount: 0, requiredTechnologyNodeId: "monumentos-gloria", iconKey: "monument" }),
  makeBuildingTemplate({ id: "santuario-reliquias", name: "Santuario de Reliquias", category: "Reliquias", description: "Camara sellada donde se custodian reliquias narrativas y se equipan a Caracteres veteranos.", buildingKind: "relic", industrialMaterialCost: 44, constructionTimeSeconds: 259200, requiredTechnologyNodeId: "monumentos-gloria", iconKey: "relic_sanctuary" })
];

type ProductionResourceKey = Exclude<CampaignSnapshot["systemResourceCapabilities"][number]["resourceKey"], "technology">;

const productionResourceKeys: ProductionResourceKey[] = [
  "supply",
  "minerals",
  "honor",
  "gold",
  "industrialMaterial",
  "uridium"
];

const balancedSystemCapacities: Record<string, Partial<Record<ProductionResourceKey, number>>> = {
  "mordax": { supply: 8, honor: 1, industrialMaterial: 5 },
  "drusus": { minerals: 3, uridium: 0.3 },
  "sa-cea-gate": { supply: 8, honor: 1, industrialMaterial: 5 },
  "lyra-terminus": { minerals: 3, uridium: 0.3 },
  "thokt-vault": { supply: 8, honor: 1, industrialMaterial: 5 },
  "novem": { minerals: 3, uridium: 0.3 },
  "kharon-prime": { supply: 8, honor: 1, industrialMaterial: 5 },
  "helios-drift": { minerals: 3, uridium: 0.3 },
  "blackglass": { supply: 8, honor: 1, industrialMaterial: 5 },
  "red-sabbath": { minerals: 3, uridium: 0.3 },
  "nexus-aster": { supply: 10, minerals: 3, industrialMaterial: 5, uridium: 0.3 },
  "goregate": { supply: 5, minerals: 5, industrialMaterial: 6, uridium: 0.3 }
};

const systemResourceCapabilities: CampaignSnapshot["systemResourceCapabilities"] = systems.flatMap(getMockResourceCapabilities);

const systemBuildings: CampaignSnapshot["systemBuildings"] = [];

const unitRecoveryQueue: CampaignSnapshot["unitRecoveryQueue"] = [];

const relics: CampaignSnapshot["relics"] = [
  makeMockRelic("relic-necrones-orbe-hekatep", "necrones", "thokt-vault", "Orbe de Hekatep", "Esfera de mando que pulsa con codigo dinastico verde.", "Reliquia narrativa: ancla protocolos de reanimacion y autoridad de tumba.", "orb", "rare"),
  makeMockRelic("relic-necrones-cetro-fase", "necrones", "thokt-vault", "Cetro de Fase", "Baston de nobleza con filo que vibra entre realidades.", "Reliquia narrativa: marca derecho de conquista sobre mundos dormidos.", "scepter", "common"),
  makeMockRelic("relic-custodes-aquila-aurica", "adeptus-custodes", "kharon-prime", "Aquila Aurica", "Fragmento dorado de una camara de juramento sellada.", "Reliquia narrativa: representa vigilancia, pureza y autoridad del Trono.", "aquila", "rare"),
  makeMockRelic("relic-custodes-sello-auramita", "adeptus-custodes", "kharon-prime", "Sello de Auramita", "Placa votiva marcada con juramentos de defensa imposibles.", "Reliquia narrativa: inspira duelos ceremoniales y defensa inquebrantable.", "shield", "common"),
  makeMockRelic("relic-culto-garra-patriarca", "cultos-genestealer", "blackglass", "Garra del Patriarca", "Taliman oseo oculto en un relicario de manufactorum.", "Reliquia narrativa: refuerza la fe de celulas insurgentes.", "claw", "rare"),
  makeMockRelic("relic-culto-mascara-vidrio", "cultos-genestealer", "blackglass", "Mascara de Vidrio Negro", "Mascara ritual usada por predicadores de la cuarta generacion.", "Reliquia narrativa: simboliza infiltracion y control de masas.", "mask", "common"),
  makeMockRelic("relic-sombra-crux-eclipsada", "space-marines", "sa-cea-gate", "Crux Eclipsada", "Insignia de honor ennegrecida por la luz de un sol muerto.", "Reliquia narrativa: recuerda juramentos de purga y defensa del sector.", "crux", "rare"),
  makeMockRelic("relic-sombra-fragmento-narthex", "space-marines", "sa-cea-gate", "Fragmento del Narthex", "Pieza de un altar sellado antes de la guerra actual.", "Reliquia narrativa: legitima campanas de recuperacion sagrada.", "reliquary", "common"),
  makeMockRelic("relic-muerte-campana-putrida", "legiones-daemonicas", "mordax", "Campana Putrida", "Campana menor cubierta de oxido y letanias enfermas.", "Reliquia narrativa: anuncia avances inevitables de la plaga.", "bell", "rare"),
  makeMockRelic("relic-muerte-incensario-morbus", "legiones-daemonicas", "mordax", "Incensario de Morbus", "Artefacto que exhala niebla toxica en susurros.", "Reliquia narrativa: acompana procesiones de corrupcion y asedio.", "censer", "common")
];

const systemsWithBaseProduction: CampaignSnapshot["systems"] = systems.map((system) => ({
  ...system,
  buildingSlots: system.isCapital ? 6 : 3,
  production: getMockBaseProduction(system.id)
}));

const tradeOffers: CampaignSnapshot["tradeOffers"] = [
  {
    id: "trade-custodes-sell-minerals",
    creatorFactionId: "adeptus-custodes",
    offerType: "sell",
    resourceKey: "minerals",
    resourceAmount: 15,
    goldAmount: 8,
    feeGold: 3,
    status: "open",
    isReserved: true,
    createdAt: inMinutes(-8)
  }
];

export const mockCampaignSnapshot: CampaignSnapshot = {
  currentUser: {
    id: "user-cadia",
    displayName: "Alto Mando Imperial",
    role: "admin",
    factionId: null
  },
  timingMode: "campaign",
  resourceTickIntervalHours: 24,
  movementEdgeDurationSeconds: 259200,
  attackDurationSeconds: 604800,
  nextResourceTickAt: inHours(24),
  resourceCaps: {
    supply: 500,
    minerals: 500,
    honor: 500,
    gold: 500,
    industrialMaterial: 500,
    uridium: 500,
    technology: 500
  },
  maxArmyPoints: 1000,
  factions,
  systems: systemsWithBaseProduction,
  edges,
  resources,
  units,
  movements,
  passageRequests: [],
  battleLimits: {
    factionId: null,
    monthStart: new Date().toISOString(),
    monthEnd: inHours(24 * 33),
    startedAttacks: 0,
    receivedAttacks: 0,
    totalParticipations: 0,
    activeBattles: 0,
    maxStartedAttacks: 2,
    maxReceivedAttacks: 2,
    maxTotalParticipations: 3,
    maxActiveBattles: 3
  },
  battleOperations: [],
  battleOperationMembers: [],
  battleUnitCommitments: [],
  unitTemplates,
  recruitmentQueue: [],
  technologyNodes,
  technologyPrerequisites,
  factionTechnologies,
  technologyEffects,
  buildingTemplates,
  systemBuildings,
  systemResourceCapabilities,
  unitRecoveryQueue,
  relics,
  tradeOffers,
  conflicts,
  battleReports: [],
  narrativeAttacks: [],
  missions,
  campaignEvents: []
};

function getMockResourceCapabilities(system: CampaignSnapshot["systems"][number]): CampaignSnapshot["systemResourceCapabilities"] {
  const capacities = balancedSystemCapacities[system.id] ?? {};

  return productionResourceKeys
    .map((resourceKey) => ({
      systemId: system.id,
      resourceKey,
      productionAmount: capacities[resourceKey] ?? 0
    }))
    .filter((capability) => capability.productionAmount > 0);
}

function getMockBaseProduction(systemId: string): ResourceBundle {
  void systemId;
  return { ...emptyResources };
}

function makeMockCharacterUnit(
  id: string,
  factionId: string,
  name: string,
  unitTemplateId: string,
  currentSystemId: string,
  points: number
): CampaignSnapshot["units"][number] {
  return {
    id,
    factionId,
    unitTemplateId,
    name,
    currentSystemId,
    status: "ready",
    category: "Personaje",
    unitType: "character",
    unitKeywords: ["Infanteria", "Caracter"],
    points,
    quantity: 1,
    startingQuantity: 1,
    woundsTaken: 0,
    experience: 3,
    isVisiblePublicly: false,
    parentUnitId: null,
    destroyedAt: null,
    rank: "Campeón",
    enhancementText: null,
    notes: null
  };
}

function makeMockRelic(
  id: string,
  factionId: string,
  systemId: string,
  name: string,
  description: string,
  effectText: string,
  iconKey: string,
  rarity: CampaignSnapshot["relics"][number]["rarity"]
): CampaignSnapshot["relics"][number] {
  return {
    id,
    slug: id,
    factionId,
    systemId,
    equippedUnitId: null,
    name,
    description,
    effectText,
    iconKey,
    rarity,
    isPublic: false,
    equippedAt: null,
    createdAt: inMinutes(-30)
  };
}

function makeTechnologyNode(
  node: Omit<CampaignSnapshot["technologyNodes"][number], "treeKey" | "implementationStatus"> &
    Partial<Pick<CampaignSnapshot["technologyNodes"][number], "treeKey" | "implementationStatus">>
): CampaignSnapshot["technologyNodes"][number] {
  return {
    treeKey: "common-v1",
    implementationStatus: "active",
    ...node
  };
}

function makeBuildingTemplate(
  template: Omit<
    Partial<CampaignSnapshot["buildingTemplates"][number]>,
    "id" | "name" | "category" | "description" | "buildingKind"
  > &
    Pick<CampaignSnapshot["buildingTemplates"][number], "id" | "name" | "category" | "description" | "buildingKind">
): CampaignSnapshot["buildingTemplates"][number] {
  return {
    slug: template.id,
    supplyCost: 0,
    mineralsCost: 0,
    honorCost: 0,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    constructionTimeSeconds: 86400,
    producedResourceKey: null,
    producedAmount: 0,
    allowedUnitCategories: [],
    iconKey: null,
    requiredTechnologyNodeId: null,
    isAvailable: true,
    ...template
  };
}

function getMockUnitCategory(name: string): CampaignSnapshot["units"][number]["category"] {
  if (["Warboss", "Overlord", "Shield-Captain", "Primus", "Captain", "Lord of Contagion"].includes(name)) {
    return "Personaje";
  }

  if (["Deff Dread", "Caladius Grav-tank", "Achilles Ridgerunner", "Redemptor Dreadnought", "Foetid Bloat-drone"].includes(name)) {
    return "Vehiculo";
  }

  if (["Meganobz", "Immortals", "Skorpekh Destroyers", "Kasrkin", "Acolyte Hybrids", "Terminator Squad"].includes(name)) {
    return "Elite";
  }

  return "Infanteria";
}

function getMockUnitType(category: CampaignSnapshot["unitTemplates"][number]["category"]): CampaignSnapshot["unitTemplates"][number]["unitType"] {
  if (String(category).toLowerCase().startsWith("veh")) {
    return "vehicle";
  }

  if (category === "Personaje") {
    return "character";
  }

  if (category === "Monstruo") {
    return "beast";
  }

  return "infantry";
}

function getMockUnitKeywords(category: CampaignSnapshot["unitTemplates"][number]["category"]): CampaignSnapshot["unitTemplates"][number]["unitKeywords"] {
  if (String(category).toLowerCase().startsWith("veh")) {
    return ["Vehiculo"];
  }

  if (category === "Personaje") {
    return ["Infanteria", "Caracter"];
  }

  if (category === "Monstruo") {
    return ["Bestia"];
  }

  return ["Infanteria"];
}

function getRecruitmentBuildingType(category: CampaignSnapshot["unitTemplates"][number]["category"]) {
  if (String(category).toLowerCase().startsWith("veh")) {
    return "taller-guerra";
  }

  if (category === "Personaje") {
    return "cuartel-mando";
  }

  if (category === "Monstruo") {
    return "nido-bestias";
  }

  return "barracon-infanteria";
}

function getMockUnitTemplateId(name: string) {
  const templateIds: Record<string, string> = {
    Boyz: "unit-aeldari-boyz",
    Meganobz: "unit-aeldari-meganobz",
    "Deff Dread": "unit-aeldari-deff-dread",
    "Necron Warriors": "unit-necrones-warriors",
    Immortals: "unit-necrones-immortals",
    "Skorpekh Destroyers": "unit-necrones-skorpekh",
    "Custodian Guard": "unit-adeptus-custodes-custodian-guard",
    Kasrkin: "unit-guardia-kasrkin",
    "Caladius Grav-tank": "unit-adeptus-custodes-caladius-grav-tank",
    "Neophyte Hybrids": "unit-culto-neophytes",
    "Acolyte Hybrids": "unit-culto-acolytes",
    "Achilles Ridgerunner": "unit-culto-ridgerunner",
    "Intercessor Squad": "unit-sombra-intercessors",
    "Terminator Squad": "unit-sombra-terminators",
    "Redemptor Dreadnought": "unit-sombra-redemptor",
    Poxwalkers: "unit-muerte-poxwalkers",
    "Plague Marines": "unit-muerte-plague-marines",
    "Foetid Bloat-drone": "unit-muerte-bloat-drone",
    Warboss: "unit-aeldari-warboss",
    Overlord: "unit-necrones-overlord",
    "Shield-Captain": "unit-adeptus-custodes-shield-captain",
    Primus: "unit-culto-primus",
    Captain: "unit-sombra-captain",
    "Lord of Contagion": "unit-muerte-lord-contagion"
  };

  return templateIds[name] ?? null;
}

function getMockDefaultQuantity(name: string) {
  const defaultQuantities: Record<string, number> = {
    Boyz: 10,
    Meganobz: 3,
    "Deff Dread": 1,
    "Necron Warriors": 10,
    Immortals: 5,
    "Skorpekh Destroyers": 3,
    "Custodian Guard": 4,
    Kasrkin: 10,
    "Caladius Grav-tank": 1,
    "Neophyte Hybrids": 10,
    "Acolyte Hybrids": 5,
    "Achilles Ridgerunner": 1,
    "Intercessor Squad": 5,
    "Terminator Squad": 5,
    "Redemptor Dreadnought": 1,
    Poxwalkers: 10,
    "Plague Marines": 7,
    "Foetid Bloat-drone": 1,
    Warboss: 1,
    Overlord: 1,
    "Shield-Captain": 1,
    Primus: 1,
    Captain: 1,
    "Lord of Contagion": 1
  };

  return defaultQuantities[name] ?? 1;
}

function getMockWoundsPerModel(name: string) {
  const wounds: Record<string, number> = {
    Boyz: 1,
    Meganobz: 3,
    "Deff Dread": 8,
    "Necron Warriors": 1,
    Immortals: 1,
    "Skorpekh Destroyers": 3,
    "Custodian Guard": 1,
    Kasrkin: 1,
    "Caladius Grav-tank": 10,
    "Neophyte Hybrids": 1,
    "Acolyte Hybrids": 1,
    "Achilles Ridgerunner": 8,
    "Intercessor Squad": 2,
    "Terminator Squad": 3,
    "Redemptor Dreadnought": 12,
    Poxwalkers: 1,
    "Plague Marines": 2,
    "Foetid Bloat-drone": 10,
    Warboss: 6,
    Overlord: 5,
    "Shield-Captain": 5,
    Primus: 4,
    Captain: 6,
    "Lord of Contagion": 6
  };

  return wounds[name] ?? 1;
}

function getRequiredTechnologyForUnit(name: string) {
  const veteranUnits = new Set([
    "Meganobz",
    "Immortals",
    "Skorpekh Destroyers",
    "Kasrkin",
    "Acolyte Hybrids",
    "Terminator Squad",
    "Plague Marines"
  ]);
  const vehicleUnits = new Set([
    "Deff Dread",
    "Caladius Grav-tank",
    "Achilles Ridgerunner",
    "Redemptor Dreadnought",
    "Foetid Bloat-drone"
  ]);
  const characterUnits = new Set(["Warboss", "Overlord", "Shield-Captain", "Primus", "Captain", "Lord of Contagion"]);

  if (veteranUnits.has(name)) {
    return "veteranos-guerra";
  }

  if (vehicleUnits.has(name)) {
    return "motores-guerra";
  }

  if (characterUnits.has(name)) {
    return "asamblea-planetaria";
  }

  return null;
}

void getMockUnitType;
void getMockUnitKeywords;
void getRecruitmentBuildingType;
void getMockDefaultQuantity;
void getMockWoundsPerModel;
void getRequiredTechnologyForUnit;
