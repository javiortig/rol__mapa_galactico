import type { CampaignSnapshot, ResourceBundle } from "@/domain/campaign";
import {
  generated40kFactions,
  generated40kInitialUnits,
  generated40kUnitTemplates
} from "@/mocks/generated/40k-unit-templates";

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

const factions: CampaignSnapshot["factions"] = generated40kFactions;

type BaseSystem = Omit<CampaignSnapshot["systems"][number], "systemKind" | "isConquerable" | "allowsSharedOccupation">;

const baseSystems: BaseSystem[] = [
  {
    id: "kharon-prime",
    name: "Kharon Prime",
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
    name: "Sa'cea Gate",
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
    name: "Blackglass",
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
    type: "Capital volcanica",
    status: "controlled",
    controllerFactionId: "aeldari",
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
    controllerFactionId: "aeldari",
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
    controllerFactionId: "aeldari",
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

const gaseousSystemIds = new Set(["nexus-aster", "ashen-road"]);

const systems: CampaignSnapshot["systems"] = baseSystems.map((system) => {
  const isGaseous = gaseousSystemIds.has(system.id);
  const isAgentsSystem = system.id === "argent-rift" || system.id === "orison" || system.id === "vesper-halo";

  return {
    ...system,
    status: isAgentsSystem ? "controlled" : system.status,
    controllerFactionId: isAgentsSystem ? "agentes-imperium" : system.controllerFactionId,
    isCapital: system.id === "argent-rift" ? true : system.isCapital,
    buildingSlots: system.id === "argent-rift" ? 6 : system.buildingSlots,
    systemKind: isGaseous ? "gaseous" : "standard",
    isConquerable: !isGaseous,
    allowsSharedOccupation: isGaseous
  };
});

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
    factionId: "adeptus-custodes",
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
    factionId: "aeldari",
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
    factionId: "cultos-genestealer",
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
    factionId: "space-marines",
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
    factionId: "legiones-daemonicas",
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

const units: CampaignSnapshot["units"] = generated40kInitialUnits;

const movements: CampaignSnapshot["movements"] = [
  {
    id: "move-custodes-helios",
    unitIds: ["custodes-arx-caladius"],
    unitSelections: [{ unitId: "custodes-arx-caladius", quantity: 1 }],
    factionId: "adeptus-custodes",
    fromSystemId: "arx-solum",
    toSystemId: "helios-drift",
    pathSystemIds: ["arx-solum", "helios-drift"],
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
    factionId: "aeldari",
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
    factionId: "space-marines",
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
    factionId: "cultos-genestealer",
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
    factionId: "legiones-daemonicas",
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
    recruitmentTimeSeconds: 120,
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
    recruitmentTimeSeconds: 240,
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
    recruitmentTimeSeconds: 120,
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
    recruitmentTimeSeconds: 240,
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
    recruitmentTimeSeconds: 420,
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
    recruitmentTimeSeconds: 120,
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
    recruitmentTimeSeconds: 240,
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
    recruitmentTimeSeconds: 360,
    notes: "Vehiculo de incursion y reconocimiento rapido.",
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
    recruitmentTimeSeconds: 180,
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
    recruitmentTimeSeconds: 360,
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
    recruitmentTimeSeconds: 480,
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
    recruitmentTimeSeconds: 120,
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
    recruitmentTimeSeconds: 240,
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
    recruitmentTimeSeconds: 420,
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
    recruitmentTimeSeconds: 30,
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
    recruitmentTimeSeconds: 30,
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
    recruitmentTimeSeconds: 30,
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
    recruitmentTimeSeconds: 30,
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
    recruitmentTimeSeconds: 30,
    notes: "Capitan de la Sombra del Emperador.",
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
    recruitmentTimeSeconds: 30,
    notes: "Campeon corrupto de resistencia sobrenatural.",
    isAvailable: true
  }
];

const unitTemplates: CampaignSnapshot["unitTemplates"] = generated40kUnitTemplates;

void baseUnits;
void characterUnits;
void unitTemplateBase;

const conflicts: CampaignSnapshot["conflicts"] = [
  {
    id: "conflict-azur-trench",
    systemId: "azur-trench",
    attackerFactionId: "aeldari",
    defenderFactionId: "adeptus-custodes",
    status: "pending",
    blockedUntil: inDays(14),
    notes: "Aeldari y Adeptus Custodes han colisionado en la ruta central de la Zanja Azul. Pendiente de batalla fisica."
  },
  {
    id: "conflict-ossuary-reach",
    systemId: "ossuary-reach",
    attackerFactionId: "legiones-daemonicas",
    defenderFactionId: "necrones",
    status: "pending",
    blockedUntil: inDays(14),
    notes: "La Guardia de la Muerte intenta profanar criptas que los Necrones estan reactivando. Pendiente de batalla fisica."
  },
  {
    id: "conflict-saint-veil",
    systemId: "saint-veil",
    attackerFactionId: "space-marines",
    defenderFactionId: "cultos-genestealer",
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
  makeTechnologyNode({ id: "fundacion-planetaria", slug: "fundacion-planetaria", name: "Fundacion Planetaria", description: "Protocolos basicos para levantar la primera infraestructura estable de campana.", branch: "Progreso", tier: 0, positionX: 46, positionY: 48, costTechnology: 0, researchTimeSeconds: 30, iconKey: "foundation", effectSummary: "Permite construir Barracones de Infanteria y Granjas Biologicas.", isStarter: true }),
  makeTechnologyNode({ id: "maquinaria-belica", slug: "maquinaria-belica", name: "Maquinaria Belica", description: "Talleres, elevadores y servosistemas para fabricar y mantener vehiculos.", branch: "Progreso", tier: 1, positionX: 36, positionY: 34, costTechnology: 1, researchTimeSeconds: 30, iconKey: "war_machine", effectSummary: "Permite construir Talleres de Guerra.", isStarter: false }),
  makeTechnologyNode({ id: "criadero-guerra", slug: "criadero-guerra", name: "Criadero de Guerra", description: "Jaulas, ritos de control y habitats adaptados para criaturas de guerra.", branch: "Progreso", tier: 1, positionX: 54, positionY: 34, costTechnology: 1, researchTimeSeconds: 30, iconKey: "beast", effectSummary: "Permite construir Nidos de Bestias.", isStarter: false }),
  makeTechnologyNode({ id: "asamblea-planetaria", slug: "asamblea-planetaria", name: "Asamblea Planetaria", description: "Estructura de mando local capaz de sostener oficiales, personajes y estados mayores.", branch: "Progreso", tier: 2, positionX: 45, positionY: 22, costTechnology: 2, researchTimeSeconds: 30, iconKey: "command", effectSummary: "Permite construir Cuarteles de Mando.", isStarter: false }),
  makeTechnologyNode({ id: "procesado-metalurgico", slug: "procesado-metalurgico", name: "Procesado Metalurgico", description: "Cadenas industriales para convertir mineral bruto en materiales de construccion.", branch: "Progreso", tier: 1, positionX: 63, positionY: 50, costTechnology: 0, researchTimeSeconds: 30, iconKey: "factory", effectSummary: "Permite construir Plantas de Fundicion.", isStarter: false }),
  makeTechnologyNode({ id: "cristalizacion-combustible-cuantico", slug: "cristalizacion-combustible-cuantico", name: "Cristalizacion de Combustible Cuantico", description: "Tecnicas de estabilizacion para refinar Iridium util en rutas de salto.", branch: "Progreso", tier: 2, positionX: 73, positionY: 39, costTechnology: 0, researchTimeSeconds: 30, iconKey: "uridium", effectSummary: "Permite construir Refinerias de Iridium.", isStarter: false }),
  makeTechnologyNode({ id: "extraccion-subterranea", slug: "extraccion-subterranea", name: "Extraccion Subterranea", description: "Sondeos profundos y maquinaria pesada para explotar vetas minerales.", branch: "Progreso", tier: 2, positionX: 73, positionY: 55, costTechnology: 1, researchTimeSeconds: 30, iconKey: "mine", effectSummary: "Permite construir Complejos Mineros.", isStarter: false }),
  makeTechnologyNode({ id: "monumentos-gloria", slug: "monumentos-gloria", name: "Monumentos a la Gloria", description: "Arquitectura ceremonial para convertir victorias y lealtad en Honor.", branch: "Progreso", tier: 2, positionX: 73, positionY: 71, costTechnology: 1, researchTimeSeconds: 30, iconKey: "honor", effectSummary: "Permite construir Monumentos.", isStarter: false }),
  makeTechnologyNode({ id: "fiebre-oro", slug: "fiebre-oro", name: "La Fiebre del Oro", description: "Prospeccion avanzada para localizar y explotar yacimientos preciosos.", branch: "Progreso", tier: 3, positionX: 86, positionY: 55, costTechnology: 1, researchTimeSeconds: 30, iconKey: "gold", effectSummary: "Permite construir Minas de Oro.", isStarter: false }),
  makeTechnologyNode({ id: "pactos-mercantiles", slug: "pactos-mercantiles", name: "Pactos Mercantiles", description: "Acuerdos y garantias para atraer camaras de comercio al frente.", branch: "Progreso", tier: 4, positionX: 91, positionY: 40, costTechnology: 1, researchTimeSeconds: 30, iconKey: "commerce", effectSummary: "Permite construir Camaras de Comercio.", isStarter: false }),
  makeTechnologyNode({ id: "contactos-economicos", slug: "contactos-economicos", name: "Contactos Economicos", description: "Red de intermediarios y agentes comerciales con acceso al mercader.", branch: "Progreso", tier: 5, positionX: 96, positionY: 30, costTechnology: 1, researchTimeSeconds: 30, iconKey: "merchant", effectSummary: "Permite comerciar con el Mercader.", isStarter: false }),
  makeTechnologyNode({ id: "tratos-preferentes", slug: "tratos-preferentes", name: "Tratos Preferentes", description: "Credenciales, favores y rutas protegidas que reducen las tasas del mercader.", branch: "Progreso", tier: 6, positionX: 96, positionY: 18, costTechnology: 2, researchTimeSeconds: 30, iconKey: "trade_discount", effectSummary: "Mejora precios del Mercader: compra a 1.5x y venta a 0.75x del valor.", isStarter: false }),
  makeTechnologyNode({ id: "mercado-galactico", slug: "mercado-galactico", name: "Mercado Galactico", description: "Acceso a tablones de oferta y rutas de intercambio entre jugadores.", branch: "Progreso", tier: 5, positionX: 96, positionY: 52, costTechnology: 1, researchTimeSeconds: 30, iconKey: "market", effectSummary: "Permite usar el Comercio Estelar.", isStarter: false }),
  makeTechnologyNode({ id: "aranceles-privilegiados", slug: "aranceles-privilegiados", name: "Aranceles Privilegiados", description: "Tratados fiscales que reducen la comision del comercio estelar.", branch: "Progreso", tier: 6, positionX: 96, positionY: 64, costTechnology: 2, researchTimeSeconds: 30, iconKey: "tariff", effectSummary: "Reduce tu comision de Comercio Estelar al 10%, minimo 1 oro.", isStarter: false }),
  makeTechnologyNode({ id: "oficina-inteligencia", slug: "oficina-inteligencia", name: "Oficina de Inteligencia", description: "Primer nucleo burocratico para futuras operaciones de espionaje.", branch: "Inteligencia", tier: 1, positionX: 18, positionY: 58, costTechnology: 0, researchTimeSeconds: 30, iconKey: "intelligence", effectSummary: "Proximamente: desbloqueara Nexos de Inteligencia.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "celulas-informacion", slug: "celulas-informacion", name: "Celulas de Informacion", description: "Redes discretas de observadores, informadores y escuchas.", branch: "Inteligencia", tier: 2, positionX: 14, positionY: 70, costTechnology: 2, researchTimeSeconds: 30, iconKey: "cells", effectSummary: "Proximamente: produccion de espionaje y Antenas de Reconocimiento.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "doctrina-clandestina", slug: "doctrina-clandestina", name: "Doctrina Clandestina", description: "Protocolos de infiltracion sostenida para operaciones encubiertas.", branch: "Inteligencia", tier: 3, positionX: 8, positionY: 82, costTechnology: 1, researchTimeSeconds: 30, iconKey: "cloak", effectSummary: "Proximamente: mejora de produccion de espionaje.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "doble-agente", slug: "doble-agente", name: "Doble Agente", description: "Contramedidas para detectar redes enemigas y operaciones infiltradas.", branch: "Inteligencia", tier: 3, positionX: 18, positionY: 86, costTechnology: 1, researchTimeSeconds: 30, iconKey: "agent", effectSummary: "Proximamente: probabilidad de detectar espionaje enemigo.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "tecnologia-sar", slug: "tecnologia-sar", name: "Tecnologia SAR", description: "Lectura de largo alcance para reconocimiento y triangulacion avanzada.", branch: "Inteligencia", tier: 3, positionX: 28, positionY: 82, costTechnology: 1, researchTimeSeconds: 30, iconKey: "radar", effectSummary: "Proximamente: duplicara alcance de Antenas de Reconocimiento.", isStarter: false, implementationStatus: "planned" }),
  makeTechnologyNode({ id: "entrenamiento-linea", slug: "entrenamiento-linea", name: "Entrenamiento de linea", description: "Organizacion minima para tropas basicas.", branch: "Mando militar", tier: 0, positionX: 22, positionY: 32, costTechnology: 0, researchTimeSeconds: 30, iconKey: "infantry", effectSummary: "Unidades basicas desbloqueadas.", isStarter: true }),
  makeTechnologyNode({ id: "logistica-frente", slug: "logistica-frente", name: "Logistica de frente", description: "Convoyes y reservas para mantener infanteria en movimiento.", branch: "Mando militar", tier: 1, positionX: 10, positionY: 22, costTechnology: 4, researchTimeSeconds: 30, iconKey: "supply", effectSummary: "-10% Suministro al reclutar Infanteria.", isStarter: false }),
  makeTechnologyNode({ id: "cadenas-mando", slug: "cadenas-mando", name: "Cadenas de mando", description: "Vox y oficiales de enlace reducen demoras de despliegue.", branch: "Mando militar", tier: 1, positionX: 25, positionY: 18, costTechnology: 4, researchTimeSeconds: 30, iconKey: "command", effectSummary: "-10% tiempo al reclutar Infanteria.", isStarter: false }),
  makeTechnologyNode({ id: "veteranos-guerra", slug: "veteranos-guerra", name: "Veteranos de guerra", description: "Cuadros veteranos, elites y tropas endurecidas.", branch: "Infanteria y elite", tier: 1, positionX: 30, positionY: 42, costTechnology: 4, researchTimeSeconds: 30, iconKey: "elite", effectSummary: "Desbloquea unidades elite actuales.", isStarter: false }),
  makeTechnologyNode({ id: "especializacion-elite", slug: "especializacion-elite", name: "Especializacion de elite", description: "Equipo y entrenamiento para unidades de alto valor.", branch: "Infanteria y elite", tier: 2, positionX: 18, positionY: 48, costTechnology: 8, researchTimeSeconds: 30, iconKey: "elite", effectSummary: "-10% Mineral al reclutar Elite.", isStarter: false }),
  makeTechnologyNode({ id: "motores-guerra", slug: "motores-guerra", name: "Motores de guerra", description: "Habilita blindados, dreadnoughts y maquinas de guerra.", branch: "Blindados y maquinas", tier: 2, positionX: 42, positionY: 15, costTechnology: 8, researchTimeSeconds: 30, iconKey: "vehicle", effectSummary: "Desbloquea vehiculos actuales.", isStarter: false }),
  makeTechnologyNode({ id: "blindaje-reforzado", slug: "blindaje-reforzado", name: "Blindaje reforzado", description: "Estandariza placas, chasis y blindajes de campana.", branch: "Blindados y maquinas", tier: 3, positionX: 55, positionY: 16, costTechnology: 12, researchTimeSeconds: 30, iconKey: "vehicle", effectSummary: "-10% Mineral al reclutar Vehiculos.", isStarter: false }),
  makeTechnologyNode({ id: "matrices-eficiencia", slug: "matrices-eficiencia", name: "Matrices de eficiencia", description: "Optimizacion transversal de costes militares.", branch: "Arqueotecnologia", tier: 3, positionX: 36, positionY: 62, costTechnology: 12, researchTimeSeconds: 30, iconKey: "matrix", effectSummary: "-5% coste general de reclutamiento.", isStarter: false })
];

const prerequisiteRows = [
  ["maquinaria-belica", "fundacion-planetaria", 1],
  ["criadero-guerra", "fundacion-planetaria", 1],
  ["asamblea-planetaria", "maquinaria-belica", 1],
  ["asamblea-planetaria", "criadero-guerra", 1],
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

const technologyPrerequisites: CampaignSnapshot["technologyPrerequisites"] = prerequisiteRows.map(
  ([technologyNodeId, requiredNodeId, prerequisiteGroup]) => ({ technologyNodeId, requiredNodeId, prerequisiteGroup })
);

const factionTechnologies: CampaignSnapshot["factionTechnologies"] = factions.flatMap((faction) => [
  { factionId: faction.id, technologyNodeId: "fundacion-planetaria", status: "unlocked", unlockedAt: new Date(now).toISOString() },
  { factionId: faction.id, technologyNodeId: "entrenamiento-linea", status: "unlocked", unlockedAt: new Date(now).toISOString() },
  { factionId: faction.id, technologyNodeId: "maquinaria-belica", status: "available" },
  { factionId: faction.id, technologyNodeId: "criadero-guerra", status: "available" },
  { factionId: faction.id, technologyNodeId: "procesado-metalurgico", status: "available" },
  { factionId: faction.id, technologyNodeId: "logistica-frente", status: "available" },
  { factionId: faction.id, technologyNodeId: "cadenas-mando", status: "available" },
  { factionId: faction.id, technologyNodeId: "veteranos-guerra", status: "available" }
]);

const technologyEffects: CampaignSnapshot["technologyEffects"] = [
  { id: "effect-logistica-frente", technologyNodeId: "logistica-frente", effectType: "recruitment_cost_discount", payload: { category: "Infanteria", resource: "supply", percent: 10 } },
  { id: "effect-cadenas-mando", technologyNodeId: "cadenas-mando", effectType: "recruitment_time_discount", payload: { category: "Infanteria", percent: 10 } },
  { id: "effect-veteranos-guerra", technologyNodeId: "veteranos-guerra", effectType: "unlock_unit_template", payload: { unitTemplateSlugs: ["unit-aeldari-meganobz", "unit-necrones-immortals", "unit-necrones-skorpekh", "unit-guardia-kasrkin", "unit-culto-acolytes", "unit-sombra-terminators", "unit-muerte-plague-marines"] } },
  { id: "effect-especializacion-elite", technologyNodeId: "especializacion-elite", effectType: "recruitment_cost_discount", payload: { category: "Elite", resource: "minerals", percent: 10 } },
  { id: "effect-motores-guerra", technologyNodeId: "motores-guerra", effectType: "unlock_unit_template", payload: { unitTemplateSlugs: ["unit-aeldari-deff-dread", "unit-guardia-leman-russ", "unit-culto-ridgerunner", "unit-sombra-redemptor", "unit-muerte-bloat-drone"] } },
  { id: "effect-blindaje-reforzado", technologyNodeId: "blindaje-reforzado", effectType: "recruitment_cost_discount", payload: { category: "Vehiculo", resource: "minerals", percent: 10 } },
  { id: "effect-matrices-eficiencia", technologyNodeId: "matrices-eficiencia", effectType: "recruitment_cost_discount", payload: { category: "all", resource: "all", percent: 5 } },
  { id: "effect-fundacion-buildings", technologyNodeId: "fundacion-planetaria", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["barracon-infanteria", "granja-biologica"] } },
  { id: "effect-maquinaria-building", technologyNodeId: "maquinaria-belica", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["taller-guerra"] } },
  { id: "effect-criadero-building", technologyNodeId: "criadero-guerra", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["nido-bestias"] } },
  { id: "effect-asamblea-building", technologyNodeId: "asamblea-planetaria", effectType: "unlock_building_template", payload: { buildingTemplateSlugs: ["cuartel-mando"] } },
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
];

const buildingTemplates: CampaignSnapshot["buildingTemplates"] = [
  makeBuildingTemplate({ id: "barracon-infanteria", name: "Barracon de Infanteria", category: "Reclutamiento", description: "Centro de instruccion para tropas de linea y cuadros veteranos.", buildingKind: "recruitment", supplyCost: 12, mineralsCost: 8, industrialMaterialCost: 4, constructionTimeSeconds: 240, allowedUnitCategories: ["Infanteria", "Elite"], requiredTechnologyNodeId: "fundacion-planetaria", iconKey: "infantry_barracks" }),
  makeBuildingTemplate({ id: "cuartel-mando", name: "Cuartel de Mando", category: "Reclutamiento", description: "Instalacion de oficiales, heroes y personajes de mando.", buildingKind: "recruitment", supplyCost: 10, mineralsCost: 10, honorCost: 1, industrialMaterialCost: 6, constructionTimeSeconds: 300, allowedUnitCategories: ["Personaje"], requiredTechnologyNodeId: "asamblea-planetaria", iconKey: "command_quarters" }),
  makeBuildingTemplate({ id: "taller-guerra", name: "Taller de Guerra", category: "Reclutamiento", description: "Bahias de reparacion y ensamblaje de vehiculos.", buildingKind: "recruitment", supplyCost: 6, mineralsCost: 16, industrialMaterialCost: 8, constructionTimeSeconds: 300, allowedUnitCategories: ["Vehiculo"], requiredTechnologyNodeId: "maquinaria-belica", iconKey: "war_workshop" }),
  makeBuildingTemplate({ id: "nido-bestias", name: "Nido de Bestias", category: "Reclutamiento", description: "Jaulas y rituales de control para monstruos de guerra.", buildingKind: "recruitment", supplyCost: 14, mineralsCost: 8, honorCost: 1, industrialMaterialCost: 6, constructionTimeSeconds: 300, allowedUnitCategories: ["Monstruo"], requiredTechnologyNodeId: "criadero-guerra", iconKey: "beast_lair" }),
  makeBuildingTemplate({ id: "camara-comercio", name: "Camara de Comercio", category: "Comercio", description: "Mercado orbital y punto de contacto con rutas mercantes.", buildingKind: "commerce", supplyCost: 8, mineralsCost: 8, goldCost: 1, industrialMaterialCost: 4, constructionTimeSeconds: 240, requiredTechnologyNodeId: "pactos-mercantiles", iconKey: "commerce" }),
  makeBuildingTemplate({ id: "nexo-inteligencia", name: "Nexo de Inteligencia", category: "Inteligencia", description: "Centro de analisis para operaciones de espionaje futuras.", buildingKind: "intelligence", supplyCost: 6, mineralsCost: 12, honorCost: 1, industrialMaterialCost: 6, constructionTimeSeconds: 300, requiredTechnologyNodeId: "oficina-inteligencia", iconKey: "intelligence" }),
  makeBuildingTemplate({ id: "antenas-reconocimiento", name: "Antenas de Reconocimiento", category: "Inteligencia", description: "Matrices de escucha y auspex de largo alcance.", buildingKind: "intelligence", supplyCost: 4, mineralsCost: 8, industrialMaterialCost: 5, uridiumCost: 2, constructionTimeSeconds: 240, requiredTechnologyNodeId: "celulas-informacion", iconKey: "recon" }),
  makeBuildingTemplate({ id: "granja-biologica", name: "Granja Biologica", category: "Produccion", description: "Complejos de biomasa y cultivos adaptados al frente.", buildingKind: "production", supplyCost: 4, mineralsCost: 4, industrialMaterialCost: 3, constructionTimeSeconds: 180, producedResourceKey: "supply", producedAmount: 10, requiredTechnologyNodeId: "fundacion-planetaria", iconKey: "biofarm" }),
  makeBuildingTemplate({ id: "complejo-minero", name: "Complejo Minero", category: "Produccion", description: "Pozos, excavadoras y refinerias de mineral bruto.", buildingKind: "production", supplyCost: 4, mineralsCost: 6, industrialMaterialCost: 4, constructionTimeSeconds: 180, producedResourceKey: "minerals", producedAmount: 6, requiredTechnologyNodeId: "extraccion-subterranea", iconKey: "mine" }),
  makeBuildingTemplate({ id: "refineria-iridium", name: "Refineria de Iridium", category: "Produccion", description: "Planta especializada para estabilizar cristales de salto.", buildingKind: "production", supplyCost: 4, mineralsCost: 8, industrialMaterialCost: 5, constructionTimeSeconds: 240, producedResourceKey: "uridium", producedAmount: 4, requiredTechnologyNodeId: "cristalizacion-combustible-cuantico", iconKey: "iridium_refinery" }),
  makeBuildingTemplate({ id: "mina-oro", name: "Mina de Oro", category: "Produccion", description: "Extraccion de metales preciosos para rutas comerciales.", buildingKind: "production", supplyCost: 4, mineralsCost: 8, industrialMaterialCost: 5, constructionTimeSeconds: 240, producedResourceKey: "gold", producedAmount: 3, requiredTechnologyNodeId: "fiebre-oro", iconKey: "gold_mine" }),
  makeBuildingTemplate({ id: "planta-fundicion", name: "Planta de Fundicion", category: "Produccion", description: "Produce Material Industrial para nuevas construcciones.", buildingKind: "production", supplyCost: 4, mineralsCost: 10, industrialMaterialCost: 3, constructionTimeSeconds: 240, producedResourceKey: "industrialMaterial", producedAmount: 5, requiredTechnologyNodeId: "procesado-metalurgico", iconKey: "foundry" }),
  makeBuildingTemplate({ id: "monumento", name: "Monumento", category: "Produccion", description: "Estructura ceremonial que transforma gloria local en Honor.", buildingKind: "production", supplyCost: 8, mineralsCost: 8, goldCost: 1, industrialMaterialCost: 5, constructionTimeSeconds: 300, producedResourceKey: "honor", producedAmount: 2, requiredTechnologyNodeId: "monumentos-gloria", iconKey: "monument" }),
  makeBuildingTemplate({ id: "santuario-reliquias", name: "Santuario de Reliquias", category: "Reliquias", description: "Camara sellada donde se custodian reliquias narrativas y se equipan a Caracteres veteranos.", buildingKind: "relic", supplyCost: 8, mineralsCost: 8, honorCost: 2, goldCost: 1, industrialMaterialCost: 5, constructionTimeSeconds: 30, requiredTechnologyNodeId: "monumentos-gloria", iconKey: "relic_sanctuary" })
];

type ProductionResourceKey = Exclude<CampaignSnapshot["systemResourceCapabilities"][number]["resourceKey"], "technology">;

const productionBuildingSlugByResource: Record<ProductionResourceKey, string> = {
  supply: "granja-biologica",
  minerals: "complejo-minero",
  honor: "monumento",
  gold: "mina-oro",
  industrialMaterial: "planta-fundicion",
  uridium: "refineria-iridium"
};

const productionResourceKeys = Object.keys(productionBuildingSlugByResource) as ProductionResourceKey[];

const systemResourceCapabilities: CampaignSnapshot["systemResourceCapabilities"] = systems.flatMap(getMockResourceCapabilities);

const systemBuildings: CampaignSnapshot["systemBuildings"] = systems.flatMap(getMockStartingBuildings);

const unitRecoveryQueue: CampaignSnapshot["unitRecoveryQueue"] = [];

const relics: CampaignSnapshot["relics"] = [
  makeMockRelic("relic-aeldari-krozius-chatarra", "aeldari", "cinder-maw", "Krozius de Chatarra Sagrada", "Trofeo brutal cubierto de sellos arrancados a enemigos imperiales.", "Reliquia narrativa: simboliza autoridad brutal y victorias de abordaje.", "hammer", "rare"),
  makeMockRelic("relic-aeldari-diente-gorko", "aeldari", "cinder-maw", "Diente de Gorko", "Colmillo enorme engarzado en hierro candente.", "Reliquia narrativa: inspira cargas temerarias y duelos de jefes.", "tooth", "common"),
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
  },
  {
    id: "trade-aeldari-buy-supply",
    creatorFactionId: "aeldari",
    offerType: "buy",
    resourceKey: "supply",
    resourceAmount: 20,
    goldAmount: 5,
    feeGold: 2,
    status: "open",
    isReserved: true,
    createdAt: inMinutes(-4)
  }
];

export const mockCampaignSnapshot: CampaignSnapshot = {
  currentUser: {
    id: "user-cadia",
    displayName: "Alto Mando Imperial",
    role: "admin",
    factionId: null
  },
  resourceTickIntervalHours: 24,
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
  missions
};

function getMockResourceCapabilities(system: CampaignSnapshot["systems"][number]): CampaignSnapshot["systemResourceCapabilities"] {
  if (system.systemKind === "gaseous") {
    return [];
  }

  if (system.isCapital) {
    return productionResourceKeys.map((resourceKey) => ({
      systemId: system.id,
      resourceKey,
      productionAmount: getCapitalCapability(resourceKey)
    }));
  }

  return productionResourceKeys
    .map((resourceKey) => ({
      systemId: system.id,
      resourceKey,
      productionAmount: getMockDeterministicCapability(system.id, resourceKey)
    }))
    .filter((capability) => capability.productionAmount > 0);
}

function getMockStartingBuildings(system: CampaignSnapshot["systems"][number]): CampaignSnapshot["systemBuildings"] {
  if (system.status !== "controlled" || !system.controllerFactionId) {
    return [];
  }

  if (system.isCapital) {
    return ["barracon-infanteria", "camara-comercio", "planta-fundicion", "monumento", "santuario-reliquias"].map((slug) =>
      makeSystemBuilding(system.id, slug)
    );
  }

  const capability = getPreferredMockCapability(system.id);
  const slug = capability ? productionBuildingSlugByResource[capability.resourceKey as ProductionResourceKey] : null;

  return slug ? [makeSystemBuilding(system.id, slug)] : [];
}

function getMockBaseProduction(systemId: string): ResourceBundle {
  const production = { ...emptyResources };
  const capabilities = systemResourceCapabilities.filter((capability) => capability.systemId === systemId);

  for (const capability of capabilities) {
    production[capability.resourceKey] = capability.productionAmount;
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

function getCapitalCapability(resourceKey: ProductionResourceKey) {
  const capitalCapabilities: Record<ProductionResourceKey, number> = {
    supply: 10,
    minerals: 5,
    industrialMaterial: 20,
    uridium: 5,
    honor: 3,
    gold: 3
  };

  return capitalCapabilities[resourceKey];
}

function getMockDeterministicCapability(systemId: string, resourceKey: ProductionResourceKey) {
  const profile = deterministicInt(`${systemId}:profile`, 0, 4);

  if (profile === 0) {
    return capabilityRange(systemId, resourceKey, {
      supply: [5, 9],
      minerals: [2, 5],
      industrialMaterial: [4, 9],
      uridium: [1, 3],
      honor: [1, 3],
      gold: [1, 3]
    });
  }

  if (profile === 1) {
    return capabilityRange(systemId, resourceKey, {
      supply: [2, 5],
      minerals: [6, 10],
      industrialMaterial: [8, 13],
      uridium: [1, 4],
      honor: [0, 2],
      gold: [1, 3]
    });
  }

  if (profile === 2) {
    return capabilityRange(systemId, resourceKey, {
      supply: [3, 6],
      minerals: [2, 5],
      industrialMaterial: [3, 7],
      uridium: [5, 9],
      honor: [1, 3],
      gold: [1, 4]
    });
  }

  if (profile === 3) {
    return capabilityRange(systemId, resourceKey, {
      supply: [3, 6],
      minerals: [1, 4],
      industrialMaterial: [2, 6],
      uridium: [1, 3],
      honor: [4, 7],
      gold: [2, 5]
    });
  }

  return capabilityRange(systemId, resourceKey, {
    supply: [4, 7],
    minerals: [3, 6],
    industrialMaterial: [5, 10],
    uridium: [2, 5],
    honor: [2, 4],
    gold: [2, 4]
  });
}

function capabilityRange(
  systemId: string,
  resourceKey: ProductionResourceKey,
  ranges: Record<ProductionResourceKey, [number, number]>
) {
  const [min, max] = ranges[resourceKey];
  return deterministicInt(`${systemId}:${resourceKey}`, min, max);
}

function deterministicInt(seed: string, min: number, max: number) {
  let hash = 2166136261;

  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }

  const normalized = (hash >>> 0) % (max - min + 1);
  return min + normalized;
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
    rank: "Campeon",
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
