import type { CampaignSnapshot, ResourceBundle } from "@/domain/campaign";

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

const factions: CampaignSnapshot["factions"] = [
  { id: "orcos", name: "Orcos", color: "#84cc16", capitalSystemId: "cinder-maw" },
  { id: "necrones", name: "Necrones", color: "#2dd4bf", capitalSystemId: "thokt-vault" },
  { id: "guardia-imperial", name: "Guardia Imperial", color: "#38bdf8", capitalSystemId: "kharon-prime" },
  { id: "culto-genestelar", name: "Culto Genestelar", color: "#c084fc", capitalSystemId: "blackglass" },
  { id: "sombra-emperador", name: "Sombra del Emperador", color: "#facc15", capitalSystemId: "sa-cea-gate" },
  { id: "guardia-muerte", name: "Guardia de la Muerte", color: "#b6c35a", capitalSystemId: "mordax" }
];

const systems: CampaignSnapshot["systems"] = [
  {
    id: "kharon-prime",
    name: "Kharon Prime",
    x: 90,
    y: 170,
    size: 1.2,
    starClass: "blue",
    type: "Capital fortificada",
    status: "controlled",
    controllerFactionId: "guardia-imperial",
    isCapital: true,
    publicDescription: "Bastion manufactorum y astropuerto militar del frente imperial.",
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
    controllerFactionId: "guardia-imperial",
    isCapital: false,
    publicDescription: "Asteroides ricos en mineral defendidos por baterias orbitales.",
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
    controllerFactionId: "guardia-imperial",
    isCapital: false,
    publicDescription: "Fortaleza avanzada que vigila las rutas hacia la Zanja Azul.",
    production: dailyProduction({ supply: 5, minerals: 3, uridium: 1 })
  },
  {
    id: "sa-cea-gate",
    name: "Sa'cea Gate",
    x: 910,
    y: 150,
    size: 1.2,
    starClass: "white",
    type: "Capital orbital",
    status: "controlled",
    controllerFactionId: "sombra-emperador",
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
    controllerFactionId: "sombra-emperador",
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
    controllerFactionId: "sombra-emperador",
    isCapital: false,
    publicDescription: "Complejo sacro con rutas de descenso peligrosas.",
    production: dailyProduction({ supply: 2, honor: 2, uridium: 1 })
  },
  {
    id: "blackglass",
    name: "Blackglass",
    x: 930,
    y: 440,
    size: 1.16,
    starClass: "white",
    type: "Capital cristalina",
    status: "controlled",
    controllerFactionId: "culto-genestelar",
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
    controllerFactionId: "culto-genestelar",
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
    controllerFactionId: "culto-genestelar",
    isCapital: false,
    publicDescription: "Estaciones gemelas que repiten senales falsas hacia el centro.",
    production: dailyProduction({ supply: 2, minerals: 2, honor: 1, uridium: 3 })
  },
  {
    id: "thokt-vault",
    name: "Thokt Vault",
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
    name: "Mordax",
    x: 150,
    y: 780,
    size: 1.18,
    starClass: "red",
    type: "Capital corrupta",
    status: "controlled",
    controllerFactionId: "guardia-muerte",
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
    controllerFactionId: "guardia-muerte",
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
    controllerFactionId: "guardia-muerte",
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
    type: "Capital volcanica",
    status: "controlled",
    controllerFactionId: "orcos",
    isCapital: true,
    publicDescription: "Forjas geotermicas y tormentas de ceniza.",
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
    status: "controlled",
    controllerFactionId: "orcos",
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
    status: "controlled",
    controllerFactionId: "orcos",
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
    publicDescription: "Corredor azul con pozos de gravedad inestables. Orcos e Imperiales han chocado aqui.",
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
    publicDescription: "Santuario velado donde la Sombra del Emperador combate una revuelta genestelar.",
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
  }
];

const edges: CampaignSnapshot["edges"] = [
  { id: "route-01", fromSystemId: "kharon-prime", toSystemId: "helios-drift", uridiumCost: 1 },
  { id: "route-02", fromSystemId: "helios-drift", toSystemId: "arx-solum", uridiumCost: 1 },
  { id: "route-03", fromSystemId: "arx-solum", toSystemId: "azur-trench", uridiumCost: 2 },
  { id: "route-04", fromSystemId: "arx-solum", toSystemId: "orison", uridiumCost: 2 },
  { id: "route-05", fromSystemId: "cinder-maw", toSystemId: "eclipse-forge", uridiumCost: 1 },
  { id: "route-06", fromSystemId: "eclipse-forge", toSystemId: "rustmaw-run", uridiumCost: 1 },
  { id: "route-07", fromSystemId: "rustmaw-run", toSystemId: "azur-trench", uridiumCost: 2 },
  { id: "route-08", fromSystemId: "rustmaw-run", toSystemId: "goregate", uridiumCost: 1 },
  { id: "route-09", fromSystemId: "sa-cea-gate", toSystemId: "lyra-terminus", uridiumCost: 1 },
  { id: "route-10", fromSystemId: "lyra-terminus", toSystemId: "narthex", uridiumCost: 1 },
  { id: "route-11", fromSystemId: "narthex", toSystemId: "saint-veil", uridiumCost: 2 },
  { id: "route-12", fromSystemId: "narthex", toSystemId: "vesper-halo", uridiumCost: 1 },
  { id: "route-13", fromSystemId: "blackglass", toSystemId: "red-sabbath", uridiumCost: 1 },
  { id: "route-14", fromSystemId: "red-sabbath", toSystemId: "mirrorcoil", uridiumCost: 1 },
  { id: "route-15", fromSystemId: "mirrorcoil", toSystemId: "saint-veil", uridiumCost: 2 },
  { id: "route-16", fromSystemId: "mirrorcoil", toSystemId: "pale-choir", uridiumCost: 1 },
  { id: "route-17", fromSystemId: "thokt-vault", toSystemId: "novem", uridiumCost: 1 },
  { id: "route-18", fromSystemId: "novem", toSystemId: "ghostlight", uridiumCost: 1 },
  { id: "route-19", fromSystemId: "ghostlight", toSystemId: "ossuary-reach", uridiumCost: 2 },
  { id: "route-20", fromSystemId: "ghostlight", toSystemId: "voidfall-anchor", uridiumCost: 1 },
  { id: "route-21", fromSystemId: "mordax", toSystemId: "drusus", uridiumCost: 1 },
  { id: "route-22", fromSystemId: "drusus", toSystemId: "plaguefall-bastion", uridiumCost: 1 },
  { id: "route-23", fromSystemId: "plaguefall-bastion", toSystemId: "ossuary-reach", uridiumCost: 2 },
  { id: "route-24", fromSystemId: "plaguefall-bastion", toSystemId: "sepulchre-nine", uridiumCost: 1 },
  { id: "route-25", fromSystemId: "azur-trench", toSystemId: "orison", uridiumCost: 2 },
  { id: "route-26", fromSystemId: "orison", toSystemId: "argent-rift", uridiumCost: 1 },
  { id: "route-27", fromSystemId: "argent-rift", toSystemId: "vesper-halo", uridiumCost: 1 },
  { id: "route-28", fromSystemId: "vesper-halo", toSystemId: "saint-veil", uridiumCost: 2 },
  { id: "route-29", fromSystemId: "saint-veil", toSystemId: "pale-choir", uridiumCost: 2 },
  { id: "route-30", fromSystemId: "pale-choir", toSystemId: "ashen-road", uridiumCost: 1 },
  { id: "route-31", fromSystemId: "ashen-road", toSystemId: "ossuary-reach", uridiumCost: 2 },
  { id: "route-32", fromSystemId: "ossuary-reach", toSystemId: "voidfall-anchor", uridiumCost: 2 },
  { id: "route-33", fromSystemId: "voidfall-anchor", toSystemId: "sepulchre-nine", uridiumCost: 1 },
  { id: "route-34", fromSystemId: "sepulchre-nine", toSystemId: "goregate", uridiumCost: 2 },
  { id: "route-35", fromSystemId: "goregate", toSystemId: "azur-trench", uridiumCost: 1 },
  { id: "route-36", fromSystemId: "nexus-aster", toSystemId: "orison", uridiumCost: 3 },
  { id: "route-37", fromSystemId: "nexus-aster", toSystemId: "azur-trench", uridiumCost: 3 },
  { id: "route-38", fromSystemId: "nexus-aster", toSystemId: "saint-veil", uridiumCost: 3 },
  { id: "route-39", fromSystemId: "nexus-aster", toSystemId: "ashen-road", uridiumCost: 3 },
  { id: "route-40", fromSystemId: "nexus-aster", toSystemId: "ossuary-reach", uridiumCost: 3 }
];

const resources: CampaignSnapshot["resources"] = [
  {
    factionId: "guardia-imperial",
    supply: 180,
    minerals: 130,
    honor: 12,
    gold: 34,
    industrialMaterial: 90,
    uridium: 24,
    technology: 16,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "orcos",
    supply: 190,
    minerals: 135,
    honor: 7,
    gold: 26,
    industrialMaterial: 90,
    uridium: 20,
    technology: 16,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "necrones",
    supply: 115,
    minerals: 155,
    honor: 18,
    gold: 32,
    industrialMaterial: 90,
    uridium: 22,
    technology: 16,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "culto-genestelar",
    supply: 185,
    minerals: 115,
    honor: 13,
    gold: 30,
    industrialMaterial: 90,
    uridium: 22,
    technology: 16,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "sombra-emperador",
    supply: 135,
    minerals: 130,
    honor: 18,
    gold: 38,
    industrialMaterial: 90,
    uridium: 26,
    technology: 16,
    updatedAt: new Date(now).toISOString()
  },
  {
    factionId: "guardia-muerte",
    supply: 155,
    minerals: 135,
    honor: 15,
    gold: 28,
    industrialMaterial: 90,
    uridium: 20,
    technology: 16,
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
    experience: number;
    rank?: string | null;
    enhancementText?: string | null;
  }>;
};

const unitGroups: MockUnitGroup[] = [
  {
    id: "imperial-kharon-garrison",
    factionId: "guardia-imperial",
    name: "Guarnicion de Kharon",
    currentSystemId: "kharon-prime",
    status: "ready",
    pointsTotal: 510,
    isVisiblePublicly: false,
    units: [
      {
        id: "imperial-kharon-cadians",
        name: "Cadian Shock Troops",
        points: 80,
        quantity: 3,
        experience: 1,
        rank: "Linea"
      }
    ]
  },
  {
    id: "imperial-arx-front",
    factionId: "guardia-imperial",
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
        quantity: 2,
        experience: 2,
        rank: "Veteranos",
        enhancementText: "Doctrina de frontera"
      }
    ]
  },
  {
    id: "imperial-helios-column",
    factionId: "guardia-imperial",
    name: "Columna Helios",
    currentSystemId: "kharon-prime",
    status: "moving",
    pointsTotal: 360,
    isVisiblePublicly: false,
    units: [
      {
        id: "imperial-helios-cadians",
        name: "Cadian Shock Troops",
        points: 80,
        quantity: 2,
        experience: 0,
        rank: "Reconocimiento"
      }
    ]
  },
  {
    id: "imperial-azur-line",
    factionId: "guardia-imperial",
    name: "Linea de Azur",
    currentSystemId: "azur-trench",
    status: "in_war",
    pointsTotal: 690,
    isVisiblePublicly: false,
    units: [
      {
        id: "imperial-azur-tank",
        name: "Leman Russ Battle Tank",
        points: 145,
        quantity: 2,
        experience: 1,
        rank: "Blindados"
      }
    ]
  },
  {
    id: "ork-cinder-garrison",
    factionId: "orcos",
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
    factionId: "orcos",
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
    factionId: "orcos",
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
    factionId: "orcos",
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
    factionId: "sombra-emperador",
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
    factionId: "sombra-emperador",
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
    factionId: "sombra-emperador",
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
    factionId: "sombra-emperador",
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
    factionId: "culto-genestelar",
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
    factionId: "culto-genestelar",
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
    factionId: "culto-genestelar",
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
    factionId: "culto-genestelar",
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
    factionId: "guardia-muerte",
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
    factionId: "guardia-muerte",
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
    factionId: "guardia-muerte",
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
    factionId: "guardia-muerte",
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

const units: CampaignSnapshot["units"] = unitGroups.flatMap((group) =>
  group.units.map((unit) => {
    const startingQuantity = unit.startingQuantity ?? getMockDefaultQuantity(unit.name);

    return {
      id: unit.id,
      factionId: group.factionId,
      unitTemplateId: getMockUnitTemplateId(unit.name),
      name: unit.name,
      currentSystemId: group.currentSystemId,
      status: group.status,
      category: getMockUnitCategory(unit.name),
      points: unit.points,
      quantity: unit.quantity,
      startingQuantity,
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

const movements: CampaignSnapshot["movements"] = [
  {
    id: "move-imperial-helios",
    unitIds: ["imperial-helios-cadians"],
    unitSelections: [{ unitId: "imperial-helios-cadians", quantity: 2 }],
    factionId: "guardia-imperial",
    fromSystemId: "kharon-prime",
    toSystemId: "helios-drift",
    pathSystemIds: ["kharon-prime", "helios-drift"],
    uridiumCost: 1,
    segmentCount: 1,
    durationSeconds: 120,
    startedAt: inMinutes(-0.5),
    arrivalAt: inMinutes(1.5),
    status: "moving"
  },
  {
    id: "move-ork-eclipse",
    unitIds: ["ork-eclipse-boyz"],
    unitSelections: [{ unitId: "ork-eclipse-boyz", quantity: 3 }],
    factionId: "orcos",
    fromSystemId: "cinder-maw",
    toSystemId: "eclipse-forge",
    pathSystemIds: ["cinder-maw", "eclipse-forge"],
    uridiumCost: 1,
    segmentCount: 1,
    durationSeconds: 120,
    startedAt: inMinutes(-0.5),
    arrivalAt: inMinutes(1.5),
    status: "moving"
  },
  {
    id: "move-sombra-lyra",
    unitIds: ["sombra-lyra-intercessors"],
    unitSelections: [{ unitId: "sombra-lyra-intercessors", quantity: 1 }],
    factionId: "sombra-emperador",
    fromSystemId: "sa-cea-gate",
    toSystemId: "lyra-terminus",
    pathSystemIds: ["sa-cea-gate", "lyra-terminus"],
    uridiumCost: 1,
    segmentCount: 1,
    durationSeconds: 120,
    startedAt: inMinutes(-0.5),
    arrivalAt: inMinutes(1.5),
    status: "moving"
  },
  {
    id: "move-cult-sabbath",
    unitIds: ["cult-sabbath-ridgerunner"],
    unitSelections: [{ unitId: "cult-sabbath-ridgerunner", quantity: 1 }],
    factionId: "culto-genestelar",
    fromSystemId: "blackglass",
    toSystemId: "red-sabbath",
    pathSystemIds: ["blackglass", "red-sabbath"],
    uridiumCost: 1,
    segmentCount: 1,
    durationSeconds: 120,
    startedAt: inMinutes(-0.5),
    arrivalAt: inMinutes(1.5),
    status: "moving"
  },
  {
    id: "move-necron-novem",
    unitIds: ["necron-novem-immortals"],
    unitSelections: [{ unitId: "necron-novem-immortals", quantity: 2 }],
    factionId: "necrones",
    fromSystemId: "thokt-vault",
    toSystemId: "novem",
    pathSystemIds: ["thokt-vault", "novem"],
    uridiumCost: 1,
    segmentCount: 1,
    durationSeconds: 120,
    startedAt: inMinutes(-0.5),
    arrivalAt: inMinutes(1.5),
    status: "moving"
  },
  {
    id: "move-death-drusus",
    unitIds: ["death-drusus-drone"],
    unitSelections: [{ unitId: "death-drusus-drone", quantity: 1 }],
    factionId: "guardia-muerte",
    fromSystemId: "mordax",
    toSystemId: "drusus",
    pathSystemIds: ["mordax", "drusus"],
    uridiumCost: 1,
    segmentCount: 1,
    durationSeconds: 120,
    startedAt: inMinutes(-0.5),
    arrivalAt: inMinutes(1.5),
    status: "moving"
  }
];

type MockUnitTemplate = Omit<CampaignSnapshot["unitTemplates"][number], "defaultQuantity">;

const unitTemplateBase: MockUnitTemplate[] = [
  {
    id: "unit-orcos-boyz",
    factionId: "orcos",
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
    recruitmentTimeSeconds: 120,
    notes: "Masa brutal de combate cercano.",
    isAvailable: true
  },
  {
    id: "unit-orcos-meganobz",
    factionId: "orcos",
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
    recruitmentTimeSeconds: 240,
    notes: "Noblez armados con servoarmaduras improvisadas.",
    isAvailable: true
  },
  {
    id: "unit-orcos-deff-dread",
    factionId: "orcos",
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
    recruitmentTimeSeconds: 360,
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
    recruitmentTimeSeconds: 120,
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
    recruitmentTimeSeconds: 240,
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
    recruitmentTimeSeconds: 360,
    notes: "Asesinos de fase con cuerpos disenados para la destruccion.",
    isAvailable: true
  },
  {
    id: "unit-guardia-cadian",
    factionId: "guardia-imperial",
    name: "Cadian Shock Troops",
    category: "Infanteria",
    points: 80,
    supplyCost: 12,
    mineralsCost: 2,
    honorCost: 0,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 120,
    notes: "Infanteria disciplinada lista para sostener la linea.",
    isAvailable: true
  },
  {
    id: "unit-guardia-kasrkin",
    factionId: "guardia-imperial",
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
    recruitmentTimeSeconds: 240,
    notes: "Veteranos de asalto con equipo especializado.",
    isAvailable: true
  },
  {
    id: "unit-guardia-leman-russ",
    factionId: "guardia-imperial",
    name: "Leman Russ Battle Tank",
    category: "Vehiculo",
    points: 145,
    supplyCost: 2,
    mineralsCost: 11,
    honorCost: 1,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: 420,
    notes: "Blindado pesado de batalla para romper frentes.",
    isAvailable: true
  },
  {
    id: "unit-culto-neophytes",
    factionId: "culto-genestelar",
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
    recruitmentTimeSeconds: 120,
    notes: "Celulas insurgentes armadas desde las profundidades.",
    isAvailable: true
  },
  {
    id: "unit-culto-acolytes",
    factionId: "culto-genestelar",
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
    recruitmentTimeSeconds: 240,
    notes: "Fanaticos hibridos preparados para ataques decisivos.",
    isAvailable: true
  },
  {
    id: "unit-culto-ridgerunner",
    factionId: "culto-genestelar",
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
    recruitmentTimeSeconds: 360,
    notes: "Vehiculo de incursion y reconocimiento rapido.",
    isAvailable: true
  },
  {
    id: "unit-sombra-intercessors",
    factionId: "sombra-emperador",
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
    recruitmentTimeSeconds: 180,
    notes: "Astartes de linea con doctrina flexible.",
    isAvailable: true
  },
  {
    id: "unit-sombra-terminators",
    factionId: "sombra-emperador",
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
    recruitmentTimeSeconds: 360,
    notes: "Veteranos con armadura tactica dreadnought.",
    isAvailable: true
  },
  {
    id: "unit-sombra-redemptor",
    factionId: "sombra-emperador",
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
    recruitmentTimeSeconds: 480,
    notes: "Dreadnought pesado para rupturas de linea.",
    isAvailable: true
  },
  {
    id: "unit-muerte-poxwalkers",
    factionId: "guardia-muerte",
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
    recruitmentTimeSeconds: 120,
    notes: "Multitud infectada que avanza sin miedo.",
    isAvailable: true
  },
  {
    id: "unit-muerte-plague-marines",
    factionId: "guardia-muerte",
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
    recruitmentTimeSeconds: 240,
    notes: "Marines de plaga resistentes y metodicos.",
    isAvailable: true
  },
  {
    id: "unit-muerte-bloat-drone",
    factionId: "guardia-muerte",
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
    recruitmentTimeSeconds: 420,
    notes: "Dron demoniaco de apoyo y hostigamiento.",
    isAvailable: true
  }
];

const unitTemplates: CampaignSnapshot["unitTemplates"] = unitTemplateBase.map((template) => ({
  ...template,
  defaultQuantity: getMockDefaultQuantity(template.name),
  recruitmentBuildingType: getRecruitmentBuildingType(template.category),
  requiredTechnologyNodeId: getRequiredTechnologyForUnit(template.name)
}));

const conflicts: CampaignSnapshot["conflicts"] = [
  {
    id: "conflict-azur-trench",
    systemId: "azur-trench",
    attackerFactionId: "orcos",
    defenderFactionId: "guardia-imperial",
    status: "pending",
    blockedUntil: inDays(14),
    notes: "Orcos e Imperiales han colisionado en la ruta central de la Zanja Azul. Pendiente de batalla fisica."
  },
  {
    id: "conflict-ossuary-reach",
    systemId: "ossuary-reach",
    attackerFactionId: "guardia-muerte",
    defenderFactionId: "necrones",
    status: "pending",
    blockedUntil: inDays(14),
    notes: "La Guardia de la Muerte intenta profanar criptas que los Necrones estan reactivando. Pendiente de batalla fisica."
  },
  {
    id: "conflict-saint-veil",
    systemId: "saint-veil",
    attackerFactionId: "sombra-emperador",
    defenderFactionId: "culto-genestelar",
    status: "pending",
    blockedUntil: inDays(14),
    notes: "La Sombra del Emperador ha descubierto una insurreccion genestelar en el santuario. Pendiente de batalla fisica."
  }
];

const missions: CampaignSnapshot["missions"] = [
  {
    id: "mission-azur-trench",
    systemId: "azur-trench",
    title: "La Zanja Azul",
    narrativeDescription: "Una nebulosa de gases ionizados parte el campo de batalla en corredores estrechos.",
    objectives: "Controlar las balizas de navegacion al final de la batalla fisica.",
    specialRules: "Las unidades que avancen por el centro cuentan como expuestas por la luz azul.",
    victoryConditions: "El ganador decide el control final de Azur Trench."
  },
  {
    id: "mission-ossuary-reach",
    systemId: "ossuary-reach",
    title: "Ecos del Osario",
    narrativeDescription: "Criptas rotas y fosas contaminadas hacen que cada metro sea una amenaza.",
    objectives: "Asegurar tres criptas antes del final de la partida.",
    specialRules: "El terreno central se considera peligroso por emanaciones toxicas y energia necrodermis.",
    victoryConditions: "El ganador decide el control final de Ossuary Reach."
  },
  {
    id: "mission-saint-veil",
    systemId: "saint-veil",
    title: "El Velo Sagrado",
    narrativeDescription: "Un santuario en sombra se convierte en campo de purga e insurreccion.",
    objectives: "Mantener el altar central y dos accesos laterales.",
    specialRules: "La primera ronda usa visibilidad reducida por incienso, humo y apagones.",
    victoryConditions: "El ganador decide el control final de Saint Veil."
  }
];

const technologyNodes: CampaignSnapshot["technologyNodes"] = [
  { id: "doctrina-campana", slug: "doctrina-campana", treeKey: "common-v1", name: "Doctrina de campana", description: "Protocolos basicos para sostener una campana galactica.", branch: "Mando y doctrina", tier: 0, positionX: 48, positionY: 46, costTechnology: 0, researchTimeSeconds: 0, iconKey: "command", effectSummary: "Base doctrinal desbloqueada.", isStarter: true },
  { id: "logistica-frente", slug: "logistica-frente", treeKey: "common-v1", name: "Logistica de frente", description: "Convoyes y reservas para mantener infanteria en movimiento.", branch: "Mando y doctrina", tier: 1, positionX: 30, positionY: 34, costTechnology: 4, researchTimeSeconds: 120, iconKey: "supply", effectSummary: "-10% Suministro al reclutar Infanteria.", isStarter: false },
  { id: "cadenas-mando", slug: "cadenas-mando", treeKey: "common-v1", name: "Cadenas de mando", description: "Vox y oficiales de enlace reducen demoras de despliegue.", branch: "Mando y doctrina", tier: 1, positionX: 56, positionY: 28, costTechnology: 4, researchTimeSeconds: 120, iconKey: "command", effectSummary: "-10% tiempo al reclutar Infanteria.", isStarter: false },
  { id: "estado-mayor-cruzada", slug: "estado-mayor-cruzada", treeKey: "common-v1", name: "Estado mayor de cruzada", description: "Coordinacion estable para una campana prolongada.", branch: "Mando y doctrina", tier: 3, positionX: 44, positionY: 14, costTechnology: 12, researchTimeSeconds: 360, iconKey: "command", effectSummary: "Desbloquea Bastion de mando.", isStarter: false },
  { id: "entrenamiento-linea", slug: "entrenamiento-linea", treeKey: "common-v1", name: "Entrenamiento de linea", description: "Organizacion minima para tropas basicas.", branch: "Infanteria y elite", tier: 0, positionX: 42, positionY: 56, costTechnology: 0, researchTimeSeconds: 0, iconKey: "infantry", effectSummary: "Unidades basicas desbloqueadas.", isStarter: true },
  { id: "veteranos-guerra", slug: "veteranos-guerra", treeKey: "common-v1", name: "Veteranos de guerra", description: "Cuadros veteranos, elites y tropas endurecidas.", branch: "Infanteria y elite", tier: 1, positionX: 28, positionY: 62, costTechnology: 4, researchTimeSeconds: 120, iconKey: "elite", effectSummary: "Desbloquea unidades elite actuales.", isStarter: false },
  { id: "especializacion-elite", slug: "especializacion-elite", treeKey: "common-v1", name: "Especializacion de elite", description: "Equipo y entrenamiento para unidades de alto valor.", branch: "Infanteria y elite", tier: 2, positionX: 17, positionY: 76, costTechnology: 8, researchTimeSeconds: 240, iconKey: "elite", effectSummary: "-10% Mineral al reclutar Elite.", isStarter: false },
  { id: "honores-batalla", slug: "honores-batalla", treeKey: "common-v1", name: "Honores de batalla", description: "Registros y juramentos para mejoras narrativas futuras.", branch: "Infanteria y elite", tier: 3, positionX: 31, positionY: 88, costTechnology: 12, researchTimeSeconds: 360, iconKey: "honor", effectSummary: "Reserva para mejoras narrativas.", isStarter: false },
  { id: "talleres-campana", slug: "talleres-campana", treeKey: "common-v1", name: "Talleres de campana", description: "Mantenimiento para maquinas, vehiculos y andadores.", branch: "Blindados y maquinas", tier: 1, positionX: 61, positionY: 60, costTechnology: 4, researchTimeSeconds: 120, iconKey: "forge", effectSummary: "Desbloquea Taller de campana.", isStarter: false },
  { id: "dominio-bestial", slug: "dominio-bestial", treeKey: "common-v1", name: "Dominio bestial", description: "Instalaciones, jaulas y ritos de control para criaturas de guerra.", branch: "Blindados y maquinas", tier: 2, positionX: 66, positionY: 74, costTechnology: 8, researchTimeSeconds: 240, iconKey: "beast", effectSummary: "Desbloquea Nido de Bestias.", isStarter: false },
  { id: "motores-guerra", slug: "motores-guerra", treeKey: "common-v1", name: "Motores de guerra", description: "Habilita blindados, dreadnoughts y maquinas de guerra.", branch: "Blindados y maquinas", tier: 2, positionX: 75, positionY: 70, costTechnology: 8, researchTimeSeconds: 240, iconKey: "vehicle", effectSummary: "Desbloquea vehiculos actuales.", isStarter: false },
  { id: "blindaje-reforzado", slug: "blindaje-reforzado", treeKey: "common-v1", name: "Blindaje reforzado", description: "Estandariza placas, chasis y blindajes de campana.", branch: "Blindados y maquinas", tier: 3, positionX: 84, positionY: 54, costTechnology: 12, researchTimeSeconds: 360, iconKey: "vehicle", effectSummary: "-10% Mineral al reclutar Vehiculos.", isStarter: false },
  { id: "arsenal-pesado", slug: "arsenal-pesado", treeKey: "common-v1", name: "Arsenal pesado", description: "Infraestructura reservada para superpesados futuros.", branch: "Blindados y maquinas", tier: 4, positionX: 91, positionY: 78, costTechnology: 18, researchTimeSeconds: 600, iconKey: "arsenal", effectSummary: "Reserva para superpesados futuros.", isStarter: false },
  { id: "nodo-logistico", slug: "nodo-logistico", treeKey: "common-v1", name: "Nodo logistico", description: "Hangares, almacenes y puntos de transferencia orbital.", branch: "Infraestructura", tier: 1, positionX: 68, positionY: 40, costTechnology: 4, researchTimeSeconds: 120, iconKey: "infrastructure", effectSummary: "Desbloquea Nodo logistico.", isStarter: false },
  { id: "manufactorum-local", slug: "manufactorum-local", treeKey: "common-v1", name: "Manufactorum local", description: "Fabricacion y ensamblaje en sistemas controlados.", branch: "Infraestructura", tier: 2, positionX: 80, positionY: 30, costTechnology: 8, researchTimeSeconds: 240, iconKey: "factory", effectSummary: "Desbloquea Manufactorum.", isStarter: false },
  { id: "red-suministro", slug: "red-suministro", treeKey: "common-v1", name: "Red de suministro", description: "Futura mejora de produccion territorial.", branch: "Infraestructura", tier: 3, positionX: 88, positionY: 42, costTechnology: 12, researchTimeSeconds: 360, iconKey: "supply", effectSummary: "Reserva para bonus de produccion.", isStarter: false },
  { id: "puerto-uridium", slug: "puerto-uridium", treeKey: "common-v1", name: "Puerto de Uridium", description: "Optimizacion futura de rutas de salto.", branch: "Infraestructura", tier: 4, positionX: 78, positionY: 16, costTechnology: 18, researchTimeSeconds: 600, iconKey: "uridium", effectSummary: "Reserva para bonus de movimiento.", isStarter: false },
  { id: "auspex-reliquias", slug: "auspex-reliquias", treeKey: "common-v1", name: "Auspex de reliquias", description: "Patrones de lectura para artefactos antiguos.", branch: "Arqueotecnologia", tier: 1, positionX: 46, positionY: 74, costTechnology: 4, researchTimeSeconds: 120, iconKey: "auspex", effectSummary: "Reserva para deteccion de reliquias.", isStarter: false },
  { id: "nucleos-datos", slug: "nucleos-datos", treeKey: "common-v1", name: "Nucleos de datos", description: "Matrices para exprimir componentes recuperados.", branch: "Arqueotecnologia", tier: 2, positionX: 53, positionY: 88, costTechnology: 8, researchTimeSeconds: 240, iconKey: "data", effectSummary: "Reserva para bonus tecnologico.", isStarter: false },
  { id: "matrices-eficiencia", slug: "matrices-eficiencia", treeKey: "common-v1", name: "Matrices de eficiencia", description: "Optimizacion transversal de costes militares.", branch: "Arqueotecnologia", tier: 3, positionX: 62, positionY: 80, costTechnology: 12, researchTimeSeconds: 360, iconKey: "matrix", effectSummary: "-5% coste general de reclutamiento.", isStarter: false },
  { id: "cifra-negra", slug: "cifra-negra", treeKey: "common-v1", name: "Cifra negra", description: "Tecnologia avanzada sellada para fases futuras.", branch: "Arqueotecnologia", tier: 4, positionX: 68, positionY: 94, costTechnology: 18, researchTimeSeconds: 600, iconKey: "cipher", effectSummary: "Reserva avanzada futura.", isStarter: false }
];

const prerequisitePairs = [
  ["logistica-frente", "doctrina-campana"],
  ["cadenas-mando", "doctrina-campana"],
  ["estado-mayor-cruzada", "cadenas-mando"],
  ["veteranos-guerra", "entrenamiento-linea"],
  ["especializacion-elite", "veteranos-guerra"],
  ["honores-batalla", "especializacion-elite"],
  ["talleres-campana", "doctrina-campana"],
  ["dominio-bestial", "talleres-campana"],
  ["motores-guerra", "talleres-campana"],
  ["blindaje-reforzado", "motores-guerra"],
  ["arsenal-pesado", "blindaje-reforzado"],
  ["nodo-logistico", "doctrina-campana"],
  ["manufactorum-local", "nodo-logistico"],
  ["red-suministro", "manufactorum-local"],
  ["puerto-uridium", "red-suministro"],
  ["auspex-reliquias", "doctrina-campana"],
  ["nucleos-datos", "auspex-reliquias"],
  ["matrices-eficiencia", "nucleos-datos"],
  ["cifra-negra", "matrices-eficiencia"]
] as const;

const technologyPrerequisites: CampaignSnapshot["technologyPrerequisites"] = prerequisitePairs.map(
  ([technologyNodeId, requiredNodeId]) => ({ technologyNodeId, requiredNodeId })
);

const factionTechnologies: CampaignSnapshot["factionTechnologies"] = factions.flatMap((faction) => [
  { factionId: faction.id, technologyNodeId: "doctrina-campana", status: "unlocked", unlockedAt: new Date(now).toISOString() },
  { factionId: faction.id, technologyNodeId: "entrenamiento-linea", status: "unlocked", unlockedAt: new Date(now).toISOString() },
  { factionId: faction.id, technologyNodeId: "logistica-frente", status: "available" },
  { factionId: faction.id, technologyNodeId: "cadenas-mando", status: "available" },
  { factionId: faction.id, technologyNodeId: "veteranos-guerra", status: "available" },
  { factionId: faction.id, technologyNodeId: "talleres-campana", status: "available" },
  { factionId: faction.id, technologyNodeId: "nodo-logistico", status: "available" },
  { factionId: faction.id, technologyNodeId: "auspex-reliquias", status: "available" }
]);

const technologyEffects: CampaignSnapshot["technologyEffects"] = [
  { id: "effect-logistica-frente", technologyNodeId: "logistica-frente", effectType: "recruitment_cost_discount", payload: { category: "Infanteria", resource: "supply", percent: 10 } },
  { id: "effect-cadenas-mando", technologyNodeId: "cadenas-mando", effectType: "recruitment_time_discount", payload: { category: "Infanteria", percent: 10 } },
  { id: "effect-especializacion-elite", technologyNodeId: "especializacion-elite", effectType: "recruitment_cost_discount", payload: { category: "Elite", resource: "minerals", percent: 10 } },
  { id: "effect-blindaje-reforzado", technologyNodeId: "blindaje-reforzado", effectType: "recruitment_cost_discount", payload: { category: "Vehiculo", resource: "minerals", percent: 10 } },
  { id: "effect-matrices-eficiencia", technologyNodeId: "matrices-eficiencia", effectType: "recruitment_cost_discount", payload: { category: "all", resource: "all", percent: 5 } },
  { id: "effect-talleres-campana-building", technologyNodeId: "talleres-campana", effectType: "unlock_building", payload: { buildingSlug: "taller-guerra" } },
  { id: "effect-estado-mayor-building", technologyNodeId: "estado-mayor-cruzada", effectType: "unlock_building", payload: { buildingSlug: "cuartel-mando" } },
  { id: "effect-auspex-building", technologyNodeId: "auspex-reliquias", effectType: "unlock_building", payload: { buildingSlugs: ["nexo-inteligencia", "antenas-reconocimiento"] } },
  { id: "effect-puerto-uridium-building", technologyNodeId: "puerto-uridium", effectType: "unlock_building", payload: { buildingSlug: "refineria-iridium" } },
  { id: "effect-manufactorum-building", technologyNodeId: "manufactorum-local", effectType: "unlock_building", payload: { buildingSlug: "mina-oro" } },
  { id: "effect-dominio-bestial-building", technologyNodeId: "dominio-bestial", effectType: "unlock_building", payload: { buildingSlug: "nido-bestias" } }
];

const buildingTemplates: CampaignSnapshot["buildingTemplates"] = [
  makeBuildingTemplate({ id: "barracon-infanteria", name: "Barracon de Infanteria", category: "Reclutamiento", description: "Centro de instruccion para tropas de linea y cuadros veteranos.", buildingKind: "recruitment", supplyCost: 12, mineralsCost: 8, industrialMaterialCost: 4, constructionTimeSeconds: 240, allowedUnitCategories: ["Infanteria", "Elite"], iconKey: "infantry_barracks" }),
  makeBuildingTemplate({ id: "cuartel-mando", name: "Cuartel de Mando", category: "Reclutamiento", description: "Instalacion de oficiales, heroes y personajes de mando.", buildingKind: "recruitment", supplyCost: 10, mineralsCost: 10, honorCost: 1, industrialMaterialCost: 6, constructionTimeSeconds: 300, allowedUnitCategories: ["Personaje"], requiredTechnologyNodeId: "estado-mayor-cruzada", iconKey: "command_quarters" }),
  makeBuildingTemplate({ id: "taller-guerra", name: "Taller de Guerra", category: "Reclutamiento", description: "Bahias de reparacion y ensamblaje de vehiculos.", buildingKind: "recruitment", supplyCost: 6, mineralsCost: 16, industrialMaterialCost: 8, constructionTimeSeconds: 300, allowedUnitCategories: ["Vehiculo"], requiredTechnologyNodeId: "talleres-campana", iconKey: "war_workshop" }),
  makeBuildingTemplate({ id: "nido-bestias", name: "Nido de Bestias", category: "Reclutamiento", description: "Jaulas y rituales de control para monstruos de guerra.", buildingKind: "recruitment", supplyCost: 14, mineralsCost: 8, honorCost: 1, industrialMaterialCost: 6, constructionTimeSeconds: 300, allowedUnitCategories: ["Monstruo"], requiredTechnologyNodeId: "dominio-bestial", iconKey: "beast_lair" }),
  makeBuildingTemplate({ id: "camara-comercio", name: "Camara de Comercio", category: "Comercio", description: "Mercado orbital y punto de contacto con rutas mercantes.", buildingKind: "commerce", supplyCost: 8, mineralsCost: 8, goldCost: 1, industrialMaterialCost: 4, constructionTimeSeconds: 240, iconKey: "commerce" }),
  makeBuildingTemplate({ id: "nexo-inteligencia", name: "Nexo de Inteligencia", category: "Inteligencia", description: "Centro de analisis para operaciones de espionaje futuras.", buildingKind: "intelligence", supplyCost: 6, mineralsCost: 12, honorCost: 1, industrialMaterialCost: 6, constructionTimeSeconds: 300, requiredTechnologyNodeId: "auspex-reliquias", iconKey: "intelligence" }),
  makeBuildingTemplate({ id: "antenas-reconocimiento", name: "Antenas de Reconocimiento", category: "Inteligencia", description: "Matrices de escucha y auspex de largo alcance.", buildingKind: "intelligence", supplyCost: 4, mineralsCost: 8, industrialMaterialCost: 5, uridiumCost: 2, constructionTimeSeconds: 240, requiredTechnologyNodeId: "auspex-reliquias", iconKey: "recon" }),
  makeBuildingTemplate({ id: "granja-biologica", name: "Granja Biologica", category: "Produccion", description: "Complejos de biomasa y cultivos adaptados al frente.", buildingKind: "production", supplyCost: 4, mineralsCost: 4, industrialMaterialCost: 3, constructionTimeSeconds: 180, producedResourceKey: "supply", producedAmount: 10, iconKey: "biofarm" }),
  makeBuildingTemplate({ id: "complejo-minero", name: "Complejo Minero", category: "Produccion", description: "Pozos, excavadoras y refinerias de mineral bruto.", buildingKind: "production", supplyCost: 4, mineralsCost: 6, industrialMaterialCost: 4, constructionTimeSeconds: 180, producedResourceKey: "minerals", producedAmount: 6, iconKey: "mine" }),
  makeBuildingTemplate({ id: "refineria-iridium", name: "Refineria de Iridium", category: "Produccion", description: "Planta especializada para estabilizar cristales de salto.", buildingKind: "production", supplyCost: 4, mineralsCost: 8, industrialMaterialCost: 5, constructionTimeSeconds: 240, producedResourceKey: "uridium", producedAmount: 4, requiredTechnologyNodeId: "puerto-uridium", iconKey: "iridium_refinery" }),
  makeBuildingTemplate({ id: "mina-oro", name: "Mina de Oro", category: "Produccion", description: "Extraccion de metales preciosos para rutas comerciales.", buildingKind: "production", supplyCost: 4, mineralsCost: 8, industrialMaterialCost: 5, constructionTimeSeconds: 240, producedResourceKey: "gold", producedAmount: 3, requiredTechnologyNodeId: "manufactorum-local", iconKey: "gold_mine" }),
  makeBuildingTemplate({ id: "planta-fundicion", name: "Planta de Fundicion", category: "Produccion", description: "Produce Material Industrial para nuevas construcciones.", buildingKind: "production", supplyCost: 4, mineralsCost: 10, industrialMaterialCost: 3, constructionTimeSeconds: 240, producedResourceKey: "industrialMaterial", producedAmount: 5, iconKey: "foundry" }),
  makeBuildingTemplate({ id: "senado", name: "Senado", category: "Produccion", description: "Institucion politica que convierte influencia local en Honor.", buildingKind: "production", supplyCost: 8, mineralsCost: 8, goldCost: 1, industrialMaterialCost: 5, constructionTimeSeconds: 300, producedResourceKey: "honor", producedAmount: 2, iconKey: "senate" })
];

type ProductionResourceKey = Exclude<CampaignSnapshot["systemResourceCapabilities"][number]["resourceKey"], "technology">;

const productionBuildingSlugByResource: Record<ProductionResourceKey, string> = {
  supply: "granja-biologica",
  minerals: "complejo-minero",
  honor: "senado",
  gold: "mina-oro",
  industrialMaterial: "planta-fundicion",
  uridium: "refineria-iridium"
};

const productionResourceKeys = Object.keys(productionBuildingSlugByResource) as ProductionResourceKey[];

const systemResourceCapabilities: CampaignSnapshot["systemResourceCapabilities"] = systems.flatMap(getMockResourceCapabilities);

const systemBuildings: CampaignSnapshot["systemBuildings"] = systems.flatMap(getMockStartingBuildings);

const unitRecoveryQueue: CampaignSnapshot["unitRecoveryQueue"] = [];

const systemsWithBuildingProduction: CampaignSnapshot["systems"] = systems.map((system) => ({
  ...system,
  buildingSlots: system.isCapital ? 6 : 3,
  production: getMockBuildingProduction(system.id)
}));

const tradeOffers: CampaignSnapshot["tradeOffers"] = [
  {
    id: "trade-imperial-sell-minerals",
    creatorFactionId: "guardia-imperial",
    offerType: "sell",
    resourceKey: "minerals",
    resourceAmount: 15,
    goldAmount: 8,
    feeGold: 3,
    status: "open",
    createdAt: inMinutes(-8)
  },
  {
    id: "trade-orcos-buy-supply",
    creatorFactionId: "orcos",
    offerType: "buy",
    resourceKey: "supply",
    resourceAmount: 20,
    goldAmount: 5,
    feeGold: 2,
    status: "open",
    createdAt: inMinutes(-4)
  }
];

export const mockCampaignSnapshot: CampaignSnapshot = {
  currentUser: {
    id: "user-cadia",
    displayName: "Alto Mando Imperial",
    role: "admin",
    factionId: "guardia-imperial"
  },
  resourceTickIntervalHours: 24,
  nextResourceTickAt: inHours(24),
  factions,
  systems: systemsWithBuildingProduction,
  edges,
  resources,
  units,
  movements,
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
  tradeOffers,
  conflicts,
  battleReports: [],
  missions
};

function getMockResourceCapabilities(system: CampaignSnapshot["systems"][number]): CampaignSnapshot["systemResourceCapabilities"] {
  if (system.isCapital) {
    return productionResourceKeys.map((resourceKey) => ({
      systemId: system.id,
      resourceKey,
      productionAmount: getMockProductionAmount(resourceKey)
    }));
  }

  return productionResourceKeys
    .filter((resourceKey) => {
      if (resourceKey === "industrialMaterial") {
        return system.status === "controlled" && system.production.minerals >= 5;
      }

      return system.production[resourceKey] > 0;
    })
    .map((resourceKey) => ({
      systemId: system.id,
      resourceKey,
      productionAmount: getMockProductionAmount(resourceKey)
    }));
}

function getMockStartingBuildings(system: CampaignSnapshot["systems"][number]): CampaignSnapshot["systemBuildings"] {
  if (system.status !== "controlled" || !system.controllerFactionId) {
    return [];
  }

  if (system.isCapital) {
    return ["barracon-infanteria", "camara-comercio", "planta-fundicion", "senado"].map((slug) =>
      makeSystemBuilding(system.id, slug)
    );
  }

  const capability = getPreferredMockCapability(system.id);
  const slug = capability ? productionBuildingSlugByResource[capability.resourceKey as ProductionResourceKey] : null;

  return slug ? [makeSystemBuilding(system.id, slug)] : [];
}

function getMockBuildingProduction(systemId: string): ResourceBundle {
  const production = { ...emptyResources };

  for (const building of systemBuildings) {
    if (building.systemId !== systemId || building.status !== "active") {
      continue;
    }

    const template = buildingTemplates.find((item) => item.id === building.buildingTemplateId);

    if (!template?.producedResourceKey) {
      continue;
    }

    production[template.producedResourceKey] += template.producedAmount;
  }

  return production;
}

function getPreferredMockCapability(systemId: string) {
  const priority: ProductionResourceKey[] = ["supply", "minerals", "industrialMaterial", "uridium", "gold", "honor"];
  const capabilities = systemResourceCapabilities.filter((capability) => capability.systemId === systemId);

  return priority
    .map((resourceKey) => capabilities.find((capability) => capability.resourceKey === resourceKey))
    .find(Boolean);
}

function getMockProductionAmount(resourceKey: ProductionResourceKey) {
  const template = buildingTemplates.find((item) => item.slug === productionBuildingSlugByResource[resourceKey]);
  return template?.producedAmount ?? 0;
}

function makeSystemBuilding(systemId: string, buildingTemplateSlug: string): CampaignSnapshot["systemBuildings"][number] {
  return {
    id: `building-${systemId}-${buildingTemplateSlug}`,
    systemId,
    buildingTemplateId: buildingTemplateSlug,
    status: "active",
    startedAt: inMinutes(-30),
    finishesAt: inMinutes(-25),
    constructedAt: inMinutes(-25)
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
    constructionTimeSeconds: 0,
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
  if (["Deff Dread", "Leman Russ Battle Tank", "Achilles Ridgerunner", "Redemptor Dreadnought", "Foetid Bloat-drone"].includes(name)) {
    return "Vehiculo";
  }

  if (["Meganobz", "Immortals", "Skorpekh Destroyers", "Kasrkin", "Acolyte Hybrids", "Terminator Squad"].includes(name)) {
    return "Elite";
  }

  return "Infanteria";
}

function getRecruitmentBuildingType(category: CampaignSnapshot["unitTemplates"][number]["category"]) {
  if (category === "Vehiculo" || category === "Vehículo") {
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
    Boyz: "unit-orcos-boyz",
    Meganobz: "unit-orcos-meganobz",
    "Deff Dread": "unit-orcos-deff-dread",
    "Necron Warriors": "unit-necrones-warriors",
    Immortals: "unit-necrones-immortals",
    "Skorpekh Destroyers": "unit-necrones-skorpekh",
    "Cadian Shock Troops": "unit-guardia-cadian",
    Kasrkin: "unit-guardia-kasrkin",
    "Leman Russ Battle Tank": "unit-guardia-leman-russ",
    "Neophyte Hybrids": "unit-culto-neophytes",
    "Acolyte Hybrids": "unit-culto-acolytes",
    "Achilles Ridgerunner": "unit-culto-ridgerunner",
    "Intercessor Squad": "unit-sombra-intercessors",
    "Terminator Squad": "unit-sombra-terminators",
    "Redemptor Dreadnought": "unit-sombra-redemptor",
    Poxwalkers: "unit-muerte-poxwalkers",
    "Plague Marines": "unit-muerte-plague-marines",
    "Foetid Bloat-drone": "unit-muerte-bloat-drone"
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
    "Cadian Shock Troops": 10,
    Kasrkin: 10,
    "Leman Russ Battle Tank": 1,
    "Neophyte Hybrids": 10,
    "Acolyte Hybrids": 5,
    "Achilles Ridgerunner": 1,
    "Intercessor Squad": 5,
    "Terminator Squad": 5,
    "Redemptor Dreadnought": 1,
    Poxwalkers: 10,
    "Plague Marines": 7,
    "Foetid Bloat-drone": 1
  };

  return defaultQuantities[name] ?? 1;
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
    "Leman Russ Battle Tank",
    "Achilles Ridgerunner",
    "Redemptor Dreadnought",
    "Foetid Bloat-drone"
  ]);

  if (veteranUnits.has(name)) {
    return "veteranos-guerra";
  }

  if (vehicleUnits.has(name)) {
    return "motores-guerra";
  }

  return null;
}
