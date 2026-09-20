import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { dirname } from "node:path";
import {
  applyUnitCostBalance,
  systemWarhammerPointValue,
  warhammerPointValue
} from "./lib/campaign-balance.mjs";

const SOURCE_PATH = "data/11th40kPoints.txt";
const MFM_COST_OPTIONS_PATH = "data/11th-unit-cost-options.json";
const FINAL_DAY_TYRANIDS_PATH = "data/11th-final-day-tyranids.json";
const SEED_PATH = "supabase/seed.sql";
const MOCK_PATH = "src/mocks/generated/40k-unit-templates.ts";
const REPORT_PATH = "docs/generated/40k-unit-import-report.md";
const BALANCE_CONFIG_PATH = "data/balance/faction-balance.json";
const TROOP_TREE_CONFIG_PATH = "data/technology/faction-troop-trees.json";
const BALANCE_REPORT_PATH = "docs/generated/faction-balance-report.md";
const COST_MIGRATION_PATH = "supabase/migrations/0103_unit_cost_profiles_and_monsters.sql";
const BSDATA_REPO_URL = "https://github.com/BSData/wh40k-10e.git";
const BSDATA_PATH = ".tmp/wh40k-10e";

const SECTION_LABELS = new Set([
  "PERSONAJE",
  "CHARACTERS",
  "LÍNEA DE BATALLA",
  "LINEA DE BATALLA",
  "TRANSPORTES DEDICADOS",
  "DEDICATED TRANSPORTS",
  "OTRAS HOJAS DE DATOS",
  "OTHER DATASHEETS",
  "UNIDADES ALIADAS"
]);

const CANONICAL_CATEGORIES = new Set([
  "Personaje",
  "Linea de batalla",
  "Transporte",
  "Otras hojas de datos",
  "Aliada"
]);

const REAL_KEYWORD_MAP = new Map([
  ["Infantry", "Infanteria"],
  ["Character", "Caracter"],
  ["Vehicle", "Vehiculo"],
  ["Aircraft", "Aeronave"],
  ["Fortification", "Fortificacion"],
  ["Mounted", "Montado"],
  ["Beast", "Bestia"],
  ["Monster", "Monstruo"],
  ["Swarm", "Bestia"]
]);

const REAL_KEYWORD_NAME_ALIASES = new Map([
  ["aeldari:vyper", "vypers"],
  ["space-marines:ancient in terminator armour", "ancient in terminator armor"],
  ["space-marines:eradicator squad with heavy bolters", "eradicator squad"]
]);

const FACTION_SOURCE_HINTS = {
  "legiones-daemonicas": ["Chaos - Chaos Daemons"],
  "agentes-imperium": [
    "Imperium - Agents of the Imperium",
    "Imperium - Adepta Sororitas",
    "Imperium - Deathwatch",
    "Imperium - Grey Knights",
    "Imperium - Imperial Knights",
    "Imperium - Adeptus Titanicus",
    "Library - Titans"
  ],
  "cultos-genestealer": ["Genestealer Cults"],
  aeldari: ["Aeldari"],
  "space-marines": ["Imperium - Space Marines"],
  "adeptus-custodes": [
    "Imperium - Adeptus Custodes",
    "Imperium - Agents of the Imperium",
    "Imperium - Imperial Knights",
    "Imperium - Adeptus Titanicus",
    "Library - Titans"
  ],
  necrones: ["Necrons"]
};

const PRIMARY_FACTION_SOURCE_HINTS = {
  "legiones-daemonicas": ["Chaos - Chaos Daemons"],
  "agentes-imperium": ["Imperium - Agents of the Imperium"],
  "cultos-genestealer": ["Genestealer Cults"],
  aeldari: ["Aeldari"],
  "space-marines": ["Imperium - Space Marines"],
  "adeptus-custodes": ["Imperium - Adeptus Custodes"],
  necrones: ["Necrons"]
};

const LEGACY_FACTION_DEFS = [
  {
    sourceName: "Legiones Daemónicas",
    slug: "legiones-daemonicas",
    name: "Legiones Daemónicas",
    color: "#ef4444",
    capitalSystemId: "mordax"
  },
  {
    sourceName: "Imperium - Agents of the Imperium",
    slug: "agentes-imperium",
    name: "Agentes del Imperium",
    color: "#f59e0b",
    capitalSystemId: "argent-rift"
  },
  {
    sourceName: "Xenos - Genestealer Cults",
    slug: "cultos-genestealer",
    name: "Cultos Genestealer",
    color: "#ec4899",
    capitalSystemId: "blackglass"
  },
  {
    sourceName: "Xenos - Aeldari",
    slug: "aeldari",
    name: "Aeldari",
    color: "#fb7185",
    capitalSystemId: "cinder-maw"
  },
  {
    sourceName: "Space Marines",
    slug: "space-marines",
    name: "Sombra del Emperador",
    color: "#facc15",
    capitalSystemId: "sa-cea-gate"
  },
  {
    sourceName: "Imperium - Adeptus Custodes",
    slug: "adeptus-custodes",
    name: "Adeptus Custodes",
    color: "#d4af37",
    capitalSystemId: "kharon-prime"
  },
  {
    sourceName: "Xenos - Necrons",
    slug: "necrones",
    name: "Necrones",
    color: "#2dd4bf",
    capitalSystemId: "thokt-vault"
  }
];

void LEGACY_FACTION_DEFS;

const FACTION_DEFS = [
  {
    sourceName: "Chaos - Chaos Daemons",
    slug: "legiones-daemonicas",
    name: "Legiones Daemonicas",
    color: "#ef4444",
    capitalSystemId: "mordax"
  },
  {
    sourceName: "Imperium - Agents of the Imperium",
    slug: "agentes-imperium",
    name: "Agentes del Imperium",
    color: "#f59e0b",
    capitalSystemId: "argent-rift"
  },
  {
    sourceName: "Xenos - Genestealer Cults",
    slug: "cultos-genestealer",
    name: "Cultos Genestealer",
    color: "#c084fc",
    capitalSystemId: "blackglass"
  },
  {
    sourceName: "Xenos - Aeldari",
    slug: "aeldari",
    name: "Aeldari",
    color: "#fb7185",
    capitalSystemId: "cinder-maw"
  },
  {
    sourceName: "Imperium - Adeptus Astartes - Space Marines",
    slug: "space-marines",
    name: "Sombra del Emperador",
    color: "#3b82f6",
    capitalSystemId: "sa-cea-gate"
  },
  {
    sourceName: "Imperium - Adeptus Custodes",
    slug: "adeptus-custodes",
    name: "Adeptus Custodes",
    color: "#d4af37",
    capitalSystemId: "kharon-prime"
  },
  {
    sourceName: "Xenos - Necrons",
    slug: "necrones",
    name: "Necrones",
    color: "#2dd4bf",
    capitalSystemId: "thokt-vault"
  }
];

const INITIAL_UNITS = [
  ["necron-plasmancer", "necrones", "Plasmancer", "thokt-vault", "ready", 2, null, 0, 1, 1, 55],
  ["necron-immortals-damaged", "necrones", "Immortals", "thokt-vault", "ready", 1, null, 0, 4, 5, 70],
  ["necron-warriors", "necrones", "Necron Warriors", "thokt-vault", "ready", 1, null, 0, 10, 10, 90],
  ["necron-tomb-blades-damaged", "necrones", "Tomb Blades", "thokt-vault", "ready", 1, null, 0, 2, 3, 75],
  ["daemon-flamers-damaged", "legiones-daemonicas", "Flamers", "mordax", "ready", 1, null, 0, 1, 3, 65],
  ["daemon-burning-chariot", "legiones-daemonicas", "Burning Chariot", "mordax", "ready", 1, null, 0, 1, 1, 115],
  ["daemon-pink-horrors-damaged", "legiones-daemonicas", "Pink Horrors", "mordax", "ready", 1, null, 0, 7, 10, 140],
  ["cult-neophyte-hybrids-damaged", "cultos-genestealer", "Neophyte Hybrids", "blackglass", "ready", 1, null, 0, 7, 10, 65],
  ["cult-abominant", "cultos-genestealer", "Abominant", "blackglass", "ready", 2, null, 0, 1, 1, 85],
  ["cult-aberrants", "cultos-genestealer", "Aberrants", "blackglass", "ready", 1, null, 0, 5, 5, 135],
  ["sombra-intercessors-damaged", "space-marines", "Intercessor Squad", "sa-cea-gate", "ready", 1, null, 0, 4, 5, 80],
  ["sombra-intercessors-large-damaged", "space-marines", "Intercessor Squad", "sa-cea-gate", "ready", 1, null, 0, 7, 10, 150],
  ["sombra-lieutenant", "space-marines", "Lieutenant", "sa-cea-gate", "ready", 2, null, 0, 1, 1, 55],
  ["sombra-bladeguard-damaged", "space-marines", "Bladeguard Veteran Squad", "sa-cea-gate", "ready", 1, null, 0, 1, 3, 80],
  ["custodes-blade-champion", "adeptus-custodes", "Blade Champion", "kharon-prime", "ready", 2, null, 0, 1, 1, 120],
  ["custodes-guard-damaged", "adeptus-custodes", "Custodian Guard", "kharon-prime", "ready", 1, null, 0, 3, 4, 160],
  ["custodes-prosecutor-damaged", "adeptus-custodes", "Prosecutors", "kharon-prime", "ready", 1, null, 0, 1, 4, 40]
];

const MOVEMENT_ORDERS = [];

function main() {
  const text = readFileSync(SOURCE_PATH, "utf8");
  const balanceConfig = readJson(BALANCE_CONFIG_PATH);
  const troopTreeConfig = readJson(TROOP_TREE_CONFIG_PATH);
  const preservedCostsBySlug = readPreservedTemplateCosts(MOCK_PATH);
  const keywordSource = buildBsDataKeywordSource();
  const mfmBasePointOverrides = buildMfmBasePointOverrides();
  const catalog = parseCatalog(text, keywordSource, mfmBasePointOverrides);
  const balance = applyUnitCostBalance(catalog.units, troopTreeConfig, balanceConfig, preservedCostsBySlug);
  const report = buildReport(catalog);
  writeText(REPORT_PATH, report);
  writeText(BALANCE_REPORT_PATH, buildBalanceReport(catalog, balance, balanceConfig));
  writeText(MOCK_PATH, buildMockFile(catalog.units));
  writeText(COST_MIGRATION_PATH, buildUnitCostMigrationSql(catalog.units, balanceConfig));
  updateSeed(catalog.units);

  console.log(`Catalogo generado: ${catalog.units.length} unidades reales.`);
  console.log(`Facciones procesadas: ${catalog.factionSummaries.length}.`);
}

function parseCatalog(text, keywordSource, mfmBasePointOverrides) {
  const segments = text
    .split(/(?=\+ FACTION KEYWORD: )/g)
    .map((segment) => segment.trim())
    .filter((segment) => segment.includes("+ FACTION KEYWORD:"));
  const units = [];
  const missingKeywordMatches = [];
  const keywordMatches = [];
  const mfmPointOverrides = [];
  const factionSummaries = [];

  for (const segment of segments) {
    const lines = segment.split(/\r?\n/).map((line) => line.trim());
    const sourceFactionName = extractRequired(segment, /\+ FACTION KEYWORD:\s*(.+)/, "FACTION KEYWORD");
    const expectedUnits = Number(extractRequired(segment, /\+ NUMBER OF UNITS:\s*(\d+)/, "NUMBER OF UNITS"));
    const totalPoints = Number(extractRequired(segment, /\+ TOTAL ARMY POINTS:\s*(\d+)pts/, "TOTAL ARMY POINTS"));
    const faction = FACTION_DEFS.find((item) => item.sourceName === sourceFactionName);

    if (!faction) {
      throw new Error(`No se pudo identificar la faccion del bloque: ${sourceFactionName}`);
    }

    let importedForFaction = 0;
    let pointsForFaction = 0;
    for (const trimmed of lines) {
      const unitMatch = trimmed.match(/^(Char\d+:\s*)?(\d+)x\s+(.+?)\s+\((\d+)\s+pts\)(?::.*)?$/);
      if (!unitMatch) {
        continue;
      }

      const isCharacterLine = Boolean(unitMatch[1]);
      const defaultQuantity = Number(unitMatch[2]);
      const name = unitMatch[3].trim();
      const providedPoints = Number(unitMatch[4]);
      const unitSlug = slugify(name);
      const pointOverride = findMfmBasePointOverride(mfmBasePointOverrides, faction.slug, unitSlug, defaultQuantity);
      const points = pointOverride?.points ?? providedPoints;
      const keywordMatch = findRealKeywordMatch(name, faction.slug, keywordSource.index);
      if (!keywordMatch) {
        missingKeywordMatches.push(`${faction.sourceName}: ${name}`);
        continue;
      }

      const unitKeywords = keywordMatch.keywords;
      const isAlliedUnit = isAlliedMatch(faction.slug, keywordMatch);
      const category = deriveCategory(isAlliedUnit, isCharacterLine, keywordMatch.rawKeywords);
      const sourceSection = deriveSourceSection(category, isCharacterLine);
      const slug = uniqueSlug(units, `unit-${faction.slug}-${unitSlug}`);
      keywordMatches.push(`${faction.sourceName}: ${name} -> ${unitKeywords.join(", ")} (${keywordMatch.fileName})`);
      if (pointOverride && points !== providedPoints) {
        mfmPointOverrides.push(
          `${faction.sourceName}: ${name} (${defaultQuantity} modelos) ${providedPoints} -> ${points} pts`
        );
      }

      units.push({
        slug,
        factionSlug: faction.slug,
        sourceFactionName: faction.sourceName,
        name,
        sourceSection,
        isAlliedUnit,
        category,
        unitKeywords,
        isNamedCharacter: keywordMatch.rawKeywords.includes("Epic Hero"),
        unitType: legacyUnitType(unitKeywords),
        points,
        defaultQuantity,
        woundsPerModel: inferWoundsPerModel(name, unitKeywords),
        recruitmentBuildingType: recruitmentBuildingType(name, unitKeywords),
        ...emptyCosts(points),
        notes: `${isAlliedUnit ? "Unidad aliada" : "Unidad"} importada desde data/11th40kPoints.txt (${sourceSection}).`,
        isAvailable: false
      });
      importedForFaction += 1;
      pointsForFaction += points;
    }

    factionSummaries.push({
      sourceFactionName: faction.sourceName,
      slug: faction.slug,
      expectedUnits,
      importedUnits: importedForFaction,
      totalPoints,
      importedPoints: pointsForFaction
    });

    if (importedForFaction !== expectedUnits) {
      throw new Error(
        `El bloque ${faction.sourceName} esperaba ${expectedUnits} unidades pero se importaron ${importedForFaction}.`
      );
    }
  }

  if (missingKeywordMatches.length > 0) {
    throw new Error(`Faltan cruces BSData para:\n${missingKeywordMatches.map((line) => `- ${line}`).join("\n")}`);
  }

  appendFinalDayTyranidUnits(units, factionSummaries, keywordMatches);

  return { units, factionSummaries, keywordSource, keywordMatches, missingKeywordMatches, mfmPointOverrides };
}

function appendFinalDayTyranidUnits(units, factionSummaries, keywordMatches) {
  const finalDay = readJson(FINAL_DAY_TYRANIDS_PATH);
  const addedUnits = [];
  let pointsForFaction = 0;

  for (const entry of finalDay.units ?? []) {
    const unitKeywords = sortUnitKeywords(entry.unitKeywords ?? []);
    if (unitKeywords.length === 0 || unitKeywords.length > 2) {
      throw new Error(`Final Day ${entry.name}: debe tener 1 o 2 keywords validas.`);
    }

    const slug = uniqueSlug(units, `unit-${finalDay.factionSlug}-${entry.unitSlug ?? slugify(entry.name)}`);
    const points = Number(entry.points);
    const defaultQuantity = Number(entry.defaultQuantity);

    if (!Number.isFinite(points) || points <= 0 || !Number.isFinite(defaultQuantity) || defaultQuantity <= 0) {
      throw new Error(`Final Day ${entry.name}: puntos o miniaturas invalidas.`);
    }

    const unit = {
      slug,
      factionSlug: finalDay.factionSlug,
      sourceFactionName: finalDay.sourceFactionName,
      name: entry.name,
      sourceSection: finalDay.sourceSection,
      isAlliedUnit: Boolean(finalDay.isAlliedUnit),
      category: entry.category ?? "Aliada",
      unitKeywords,
      isNamedCharacter: Boolean(entry.isNamedCharacter),
      unitType: legacyUnitType(unitKeywords),
      points,
      defaultQuantity,
      woundsPerModel: inferWoundsPerModel(entry.name, unitKeywords),
      recruitmentBuildingType: recruitmentBuildingType(entry.name, unitKeywords),
      ...emptyCosts(points),
      notes: `Unidad aliada Final Day importada desde ${FINAL_DAY_TYRANIDS_PATH}.`,
      isAvailable: false
    };

    units.push(unit);
    addedUnits.push(unit);
    pointsForFaction += points;
    keywordMatches.push(`Final Day Tyranids: ${entry.name} -> ${unitKeywords.join(", ")} (BSData/wh40k-11e)`);
  }

  factionSummaries.push({
    sourceFactionName: `${finalDay.factionName} - ${finalDay.sourceSection}`,
    slug: finalDay.factionSlug,
    expectedUnits: addedUnits.length,
    importedUnits: addedUnits.length,
    totalPoints: pointsForFaction,
    importedPoints: pointsForFaction
  });
}

function extractRequired(text, regex, label) {
  const match = text.match(regex);
  if (!match) {
    throw new Error(`No se encontro ${label} en un bloque del catalogo.`);
  }
  return match[1].trim();
}

function buildBsDataKeywordSource() {
  ensureBsDataRepository();
  const files = execSync("git ls-files *.cat", {
    cwd: BSDATA_PATH,
    encoding: "utf8"
  })
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const commit = execSync("git rev-parse HEAD", {
    cwd: BSDATA_PATH,
    encoding: "utf8"
  }).trim();
  const index = new Map();
  let entriesScanned = 0;
  let entriesWithTrackedKeywords = 0;

  for (const fileName of files) {
    const content = readFileSync(`${BSDATA_PATH}/${fileName}`, "utf8");
    for (const entry of extractSelectionEntries(content)) {
      entriesScanned += 1;
      const rawKeywords = extractCategoryNames(entry.block);
      const keywords = normalizeRealKeywords(rawKeywords);
      if (keywords.length === 0) {
        continue;
      }
      entriesWithTrackedKeywords += 1;
      const key = normalizeUnitName(entry.name);
      if (!index.has(key)) {
        index.set(key, []);
      }
      index.get(key).push({
        name: entry.name,
        fileName,
        keywords,
        rawKeywords
      });
    }
  }

  return { commit, index, filesScanned: files.length, entriesScanned, entriesWithTrackedKeywords };
}

function ensureBsDataRepository() {
  if (existsSync(`${BSDATA_PATH}/.git`)) {
    execSync("git fetch --depth 1 origin", { cwd: BSDATA_PATH, stdio: "ignore" });
    const remoteHead = execSync("git symbolic-ref refs/remotes/origin/HEAD --short", {
      cwd: BSDATA_PATH,
      encoding: "utf8"
    }).trim();
    execSync(`git reset --hard ${remoteHead}`, { cwd: BSDATA_PATH, stdio: "ignore" });
    return;
  }
  mkdirSync(dirname(BSDATA_PATH), { recursive: true });
  execSync(`git clone --depth 1 ${BSDATA_REPO_URL} ${BSDATA_PATH}`, { stdio: "ignore" });
}

function extractSelectionEntries(content) {
  const lines = content.split(/\r?\n/);
  const entries = [];

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.includes("<selectionEntry")) {
      continue;
    }
    const tag = line.match(/<selectionEntry\b[^>]*>/)?.[0];
    if (!tag) {
      continue;
    }
    const attributes = parseXmlAttributes(tag);
    if (attributes.type !== "model" && attributes.type !== "unit") {
      continue;
    }
    if (!attributes.name) {
      continue;
    }

    const name = decodeXml(attributes.name);
    const blockLines = [line];
    let depth = countRegex(line, /<selectionEntry\b/g) - countOccurrences(line, "</selectionEntry>");

    while (depth > 0 && index + 1 < lines.length) {
      index += 1;
      const nextLine = lines[index];
      blockLines.push(nextLine);
      depth += countRegex(nextLine, /<selectionEntry\b/g) - countOccurrences(nextLine, "</selectionEntry>");
    }

    entries.push({
      name,
      block: blockLines.join("\n")
    });
  }

  return entries;
}

function parseXmlAttributes(tag) {
  return Object.fromEntries(
    [...tag.matchAll(/\b([A-Za-z_:][-A-Za-z0-9_:.]*)="([^"]*)"/g)].map((match) => [match[1], match[2]])
  );
}

function extractCategoryNames(block) {
  return [...block.matchAll(/<categoryLink\b[^>]*\bname="([^"]+)"/g)].map((match) => decodeXml(match[1]));
}

function normalizeRealKeywords(rawKeywords) {
  const keywords = [];
  for (const rawKeyword of rawKeywords) {
    const keyword = REAL_KEYWORD_MAP.get(rawKeyword);
    if (keyword && !keywords.includes(keyword)) {
      keywords.push(keyword);
    }
  }
  const sorted = sortUnitKeywords(keywords);
  if (sorted.length <= 2) {
    return sorted;
  }
  if (sorted.includes("Caracter")) {
    return [sorted.find((keyword) => keyword !== "Caracter"), "Caracter"].filter(Boolean);
  }
  return sorted.slice(0, 2);
}

function findRealKeywordMatch(name, factionSlug, index) {
  const key = normalizeUnitName(name);
  const lookupKey = REAL_KEYWORD_NAME_ALIASES.get(`${factionSlug}:${key}`) ?? key;
  const candidates = index.get(lookupKey) ?? [];
  if (candidates.length === 0) {
    return null;
  }
  const hints = FACTION_SOURCE_HINTS[factionSlug] ?? [];
  const preferred = candidates.find((candidate) => hints.some((hint) => candidate.fileName.includes(hint)));
  return preferred ?? candidates[0];
}

function isAlliedMatch(factionSlug, keywordMatch) {
  const primaryHints = PRIMARY_FACTION_SOURCE_HINTS[factionSlug] ?? [];
  return !primaryHints.some((hint) => keywordMatch.fileName.includes(hint));
}

function deriveCategory(isAlliedUnit, isCharacterLine, rawKeywords) {
  if (isAlliedUnit) return "Aliada";
  if (isCharacterLine || rawKeywords.includes("Character")) return "Personaje";
  if (rawKeywords.includes("Battleline")) return "Linea de batalla";
  if (rawKeywords.includes("Dedicated Transport") || rawKeywords.includes("Dedicated Transports")) return "Transporte";
  return "Otras hojas de datos";
}

function deriveSourceSection(category, isCharacterLine) {
  if (category === "Aliada") return "UNIDADES ALIADAS";
  if (isCharacterLine || category === "Personaje") return "CHARACTERS";
  if (category === "Linea de batalla") return "BATTLELINE";
  if (category === "Transporte") return "DEDICATED TRANSPORTS";
  return "OTHER DATASHEETS";
}

function normalizeUnitName(name) {
  return decodeXml(name)
    .replace(/\[[^\]]+\]/g, "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[’'`´]/g, "")
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function sortUnitKeywords(keywords) {
  const order = ["Infanteria", "Montado", "Bestia", "Monstruo", "Vehiculo", "Aeronave", "Fortificacion", "Caracter"];
  return [...keywords].sort((a, b) => order.indexOf(a) - order.indexOf(b));
}

function decodeXml(value) {
  return value
    .replace(/&apos;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, "&")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)));
}

function countOccurrences(value, needle) {
  return value.split(needle).length - 1;
}

function countRegex(value, regex) {
  return value.match(regex)?.length ?? 0;
}

function collectUnitLines(lines, startIndex) {
  const collected = [];
  for (let index = startIndex; index < lines.length; index += 1) {
    const trimmed = lines[index].trim();
    if (!trimmed) {
      break;
    }
    if (SECTION_LABELS.has(trimmed.toUpperCase()) || /^.+? \(\d+ puntos\)$/.test(trimmed)) {
      break;
    }
    collected.push(lines[index]);
  }
  return collected;
}

function mapCategory(section) {
  if (section === "UNIDADES ALIADAS") return "Aliada";
  if (section === "PERSONAJE" || section === "CHARACTERS") return "Personaje";
  if (section === "LÍNEA DE BATALLA" || section === "LINEA DE BATALLA") return "Linea de batalla";
  if (section === "TRANSPORTES DEDICADOS" || section === "DEDICATED TRANSPORTS") return "Transporte";
  if (section === "OTRAS HOJAS DE DATOS" || section === "OTHER DATASHEETS") return "Otras hojas de datos";
  throw new Error(`Categoria no mapeada para la seccion: ${section}`);
}

function inferKeywords(name, section) {
  const lower = name.toLowerCase();
  const keywords = [];

  const isCharacterSection = section === "PERSONAJE" || section === "CHARACTERS";
  const isTransportSection = section === "TRANSPORTES DEDICADOS" || section === "DEDICATED TRANSPORTS";

  if (isVehicleName(lower) || isTransportSection) {
    keywords.push("Vehiculo");
  } else if (isBeastName(lower)) {
    keywords.push("Bestia");
  } else if (isMountedName(lower)) {
    keywords.push("Montado");
  } else {
    keywords.push("Infanteria");
  }

  if (isCharacterSection) {
    if (keywords[0] === "Infanteria") {
      keywords.push("Caracter");
    } else {
      keywords.push("Caracter");
    }
  }

  return [...new Set(keywords)].slice(0, 2);
}

function isVehicleName(lower) {
  return /\b(tank|transport|rhino|chimera|taurox|impulsor|razorback|drop pod|serpent|starweaver|ark|barge|chariot|dreadnought|walker|sentinel|russ|baneblade|banehammer|banesword|doomhammer|stormlord|shadowsword|basilisk|wyvern|hydra|manticore|dorn|valkyrie|vendetta|thunderbolt|fighter|blackstar|immolator|armiger|cerastus|castigator|crusader|warden|gallant|errant|dominus|porphyrion|asterius|ravager|raider|venom|viper|falcon|prism|night spinner|hunter|hemlock|platform|doomstalker|reanimator|monolith|obelisk|vault|stalker|speeder|gladiator|predator|repulsor|vindicator|whirlwind|thunderhawk|stormhawk|stormraven|stormtalon|gunship|bunker|atv|warsuit|firestrike|astraeus|skorpius|sagitaur|land raider|rockgrinder|ridgerunner|truck)\b/.test(lower) || lower.includes("knight");
}

function isBeastName(lower) {
  return /\b(beast|beasts|horror|horrors|daemon|prince|avatar|ctan|c'tan|shard|genestealer|genestealers|lictor|mawloc|raveners|swarms|spyders|scarab|screamer|screamers|flamers|flamer|nurglings|spawn|wraithlord|wraithguard|wraithblades)\b/.test(lower);
}

function isMountedName(lower) {
  return /\b(mounted|riders|rider|bikes|bike|outriders|skyrunner|skyrunners|jetbike|rough riders|jackals|windriders|wraiths)\b/.test(lower);
}

function inferModelCount(name, section, unitLines) {
  const lower = name.toLowerCase();
  const topLevel = unitLines
    .map((line) => line.match(/^  • (\d+) (.+)$/))
    .filter(Boolean)
    .map((match) => ({ count: Number(match[1]), label: match[2].trim() }));

  if (section === "TRANSPORTES DEDICADOS" || section === "DEDICATED TRANSPORTS") {
    return 1;
  }

  if ((section === "PERSONAJE" || section === "CHARACTERS") && !isMultiModelCharacter(lower)) {
    return 1;
  }

  const modelLike = topLevel.filter((item) => !looksLikeWargear(item.label));
  const count = modelLike.reduce((sum, item) => sum + item.count, 0);
  return Math.max(1, count || 1);
}

function isMultiModelCharacter(lower) {
  return /\b(entourage|command squad|court|conclave|council|gaunt's ghosts)\b/.test(lower);
}

function looksLikeWargear(label) {
  return /\b(pistol|rifle|weapon|weapons|blade|sword|claw|claws|teeth|cannon|bolter|gun|flamer|staff|stave|hammer|lance|launcher|melta|plasma|grenade|shield|bite|fire|blast|gateway|gaze|orb|laspistol|shotgun|carbine|fist|gauntlet|whip|spear|bow|catapult|spinner|cutter|volley|mortar|autogun|stubber|chainsword)\b/i.test(label);
}

function emptyCosts(points) {
  return {
    supplyCost: points,
    mineralsCost: 0,
    honorCost: 0,
    goldCost: 0,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0
  };
}

function campaignRecruitmentTimeSeconds(points) {
  if (points <= 90) return 86400;
  if (points <= 180) return 172800;
  if (points <= 300) return 259200;
  return 345600;
}

function inferWoundsPerModel(name, unitKeywords) {
  const lower = name.toLowerCase();
  if (unitKeywords.includes("Fortificacion")) return 12;
  if (unitKeywords.includes("Vehiculo") || unitKeywords.includes("Aeronave")) return lower.includes("knight") || lower.includes("baneblade") ? 24 : 10;
  if (unitKeywords.includes("Monstruo")) return unitKeywords.includes("Caracter") ? 10 : 8;
  if (unitKeywords.includes("Bestia")) return unitKeywords.includes("Caracter") ? 6 : 3;
  if (unitKeywords.includes("Montado")) return 3;
  if (unitKeywords.includes("Caracter")) return 5;
  if (/\b(terminator|gravis|ogryn|bullgryn|wraith)\b/.test(lower)) return 3;
  if (/\b(space marine|intercessor|plague|rubric|thousand sons)\b/.test(lower)) return 2;
  return 1;
}

function legacyUnitType(unitKeywords) {
  if (unitKeywords.includes("Caracter")) return "character";
  if (unitKeywords.includes("Vehiculo") || unitKeywords.includes("Aeronave") || unitKeywords.includes("Fortificacion")) return "vehicle";
  if (unitKeywords.includes("Monstruo")) return "monster";
  if (unitKeywords.includes("Bestia")) return "beast";
  if (unitKeywords.includes("Montado")) return "mounted";
  return "infantry";
}

function recruitmentBuildingType(name, unitKeywords) {
  if (name.includes("[Crucible]")) return "camara-leyendas";
  if (unitKeywords.includes("Caracter")) return "cuartel-mando";
  if (unitKeywords.includes("Vehiculo") || unitKeywords.includes("Aeronave") || unitKeywords.includes("Fortificacion")) return "taller-guerra";
  if (unitKeywords.includes("Bestia") || unitKeywords.includes("Monstruo")) return "nido-bestias";
  return "barracon-infanteria";
}

function uniqueSlug(units, baseSlug) {
  let slug = baseSlug;
  let index = 2;
  const used = new Set(units.map((unit) => unit.slug));
  while (used.has(slug)) {
    slug = `${baseSlug}-${index}`;
    index += 1;
  }
  return slug;
}

function slugify(value) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function buildUnitTemplateSql(units) {
  const values = units
    .map((unit) => {
      return `    (${sql(unit.slug)}, ${sql(unit.factionSlug)}, ${sql(unit.name)}, ${sql(unit.category)}, ${sql(unit.unitType)}, ${sqlArray(unit.unitKeywords)}, ${unit.points}, ${unit.defaultQuantity}, ${unit.woundsPerModel}, ${unit.supplyCost}, ${unit.mineralsCost}, 0, ${unit.honorCost}, ${unit.goldCost}, 0, 0, 0, ${campaignRecruitmentTimeSeconds(unit.points)}, ${sql(unit.recruitmentBuildingType)}, ${sql(unit.notes)}, false, null, ${sql(unit.sourceSection)}, ${sql(unit.sourceFactionName)}, ${unit.isAlliedUnit})`;
    })
    .join(",\n");

  return `insert into public.unit_templates (
  id, slug, faction_id, name, category, unit_type, unit_keywords, points, default_quantity, wounds_per_model, supply_cost, minerals_cost, ancestral_stone_cost, honor_cost, gold_cost, industrial_material_cost, uridium_cost, technology_cost, recruitment_time_seconds, recruitment_building_type, notes, is_available, required_technology_node_id, source_section, source_faction_name, is_allied_unit
)
select
  public.seed_uuid('unit_template', data.slug),
  data.slug,
  factions.id,
  data.name,
  data.category,
  data.unit_type,
  data.unit_keywords,
  data.points,
  data.default_quantity,
  data.wounds_per_model,
  data.supply_cost,
  data.minerals_cost,
  data.ancestral_stone_cost,
  data.honor_cost,
  data.gold_cost,
  data.industrial_material_cost,
  data.uridium_cost,
  data.technology_cost,
  data.recruitment_time_seconds,
  data.recruitment_building_type,
  data.notes,
  data.is_available,
  data.required_technology_node_id::uuid,
  data.source_section,
  data.source_faction_name,
  data.is_allied_unit
from (
  values
${values}
) as data(slug, faction_slug, name, category, unit_type, unit_keywords, points, default_quantity, wounds_per_model, supply_cost, minerals_cost, ancestral_stone_cost, honor_cost, gold_cost, industrial_material_cost, uridium_cost, technology_cost, recruitment_time_seconds, recruitment_building_type, notes, is_available, required_technology_node_id, source_section, source_faction_name, is_allied_unit)
join public.factions on factions.slug = data.faction_slug
on conflict (slug) do update
set faction_id = excluded.faction_id, name = excluded.name, category = excluded.category, unit_type = excluded.unit_type, unit_keywords = excluded.unit_keywords, points = excluded.points, default_quantity = excluded.default_quantity, wounds_per_model = excluded.wounds_per_model, supply_cost = excluded.supply_cost, minerals_cost = excluded.minerals_cost, ancestral_stone_cost = excluded.ancestral_stone_cost, honor_cost = excluded.honor_cost, gold_cost = excluded.gold_cost, industrial_material_cost = excluded.industrial_material_cost, uridium_cost = excluded.uridium_cost, technology_cost = excluded.technology_cost, recruitment_time_seconds = excluded.recruitment_time_seconds, recruitment_building_type = excluded.recruitment_building_type, notes = excluded.notes, is_available = excluded.is_available, required_technology_node_id = excluded.required_technology_node_id, source_section = excluded.source_section, source_faction_name = excluded.source_faction_name, is_allied_unit = excluded.is_allied_unit;`;
}

function buildUnitCostMigrationSql(units, balanceConfig) {
  const targetFactions = new Set(balanceConfig.rebalanceFactionSlugs ?? []);
  const values = units
    .filter((unit) => targetFactions.has(unit.factionSlug))
    .map((unit) => (
      `    (${sql(unit.slug)}, ${sql(unit.unitType)}, ${sqlArray(unit.unitKeywords)}, ${unit.supplyCost}, ${unit.mineralsCost}, ${unit.honorCost}, ${unit.goldCost}, ${sql(unit.recruitmentBuildingType)})`
    ))
    .join(",\n");

  return `-- Generated by npm run units:generate.
-- Rebalances only Custodes, Daemonic Legions, Genestealer Cults and Necrons.
-- Space Marines and live campaign state are intentionally left untouched.

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname, conrelid::regclass as table_name
    from pg_constraint
    where conrelid in ('public.unit_templates'::regclass, 'public.campaign_units'::regclass)
      and pg_get_constraintdef(oid) ilike '%unit_type%'
  loop
    execute format('alter table %s drop constraint %I', v_constraint.table_name, v_constraint.conname);
  end loop;
end;
$$;

alter table public.unit_templates
  add constraint unit_templates_unit_type_check
  check (unit_type in ('beast', 'monster', 'vehicle', 'character', 'infantry', 'mounted'));

alter table public.campaign_units
  add constraint campaign_units_unit_type_check
  check (unit_type in ('beast', 'monster', 'vehicle', 'character', 'infantry', 'mounted'));

create or replace function public.normalize_unit_keyword(keyword text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when lower(coalesce(keyword, '')) in ('vehiculo', 'vehicle', 'vehiculos', 'superpesado') then 'Vehiculo'
    when lower(coalesce(keyword, '')) in ('aeronave', 'aeronaves', 'aircraft', 'flyer', 'flyers') then 'Aeronave'
    when lower(coalesce(keyword, '')) in ('fortificacion', 'fortificaciones', 'fortification', 'fortifications') then 'Fortificacion'
    when lower(coalesce(keyword, '')) in ('caracter', 'character', 'characters', 'personaje', 'personajes') then 'Caracter'
    when lower(coalesce(keyword, '')) in ('infanteria', 'infantry', 'elite', 'elites') then 'Infanteria'
    when lower(coalesce(keyword, '')) in ('monstruo', 'monster', 'monsters') then 'Monstruo'
    when lower(coalesce(keyword, '')) in ('bestia', 'beast', 'swarm') then 'Bestia'
    when lower(coalesce(keyword, '')) in ('montado', 'montada', 'montados', 'montadas', 'mounted') then 'Montado'
    when lower(coalesce(keyword, '')) like '%fortif%' then 'Fortificacion'
    when lower(coalesce(keyword, '')) like '%aircraft%' or lower(coalesce(keyword, '')) like '%aeronav%' then 'Aeronave'
    when lower(coalesce(keyword, '')) like '%veh%' then 'Vehiculo'
    when lower(coalesce(keyword, '')) like '%character%' or lower(coalesce(keyword, '')) like '%person%' or lower(coalesce(keyword, '')) like '%caracter%' then 'Caracter'
    when lower(coalesce(keyword, '')) like '%monstru%' or lower(coalesce(keyword, '')) like '%monster%' then 'Monstruo'
    when lower(coalesce(keyword, '')) like '%beast%' then 'Bestia'
    when lower(coalesce(keyword, '')) like '%mount%' or lower(coalesce(keyword, '')) like '%montad%' then 'Montado'
    when lower(coalesce(keyword, '')) like '%infan%' or lower(coalesce(keyword, '')) like '%elite%' then 'Infanteria'
    else null
  end;
$$;

create or replace function public.unit_keywords_are_valid(keywords text[])
returns boolean
language sql
immutable
set search_path = public
as $$
  select coalesce(array_length(keywords, 1), 0) between 1 and 2
    and not exists (
      select 1
      from unnest(coalesce(keywords, array[]::text[])) as item(keyword)
      where item.keyword not in ('Vehiculo', 'Caracter', 'Infanteria', 'Bestia', 'Monstruo', 'Montado', 'Aeronave', 'Fortificacion')
    )
    and cardinality(keywords) = (select count(distinct item.keyword) from unnest(keywords) as item(keyword));
$$;

create or replace function public.unit_keywords_from_category(category text, legacy_unit_type text default null)
returns text[]
language sql
immutable
set search_path = public
as $$
  select case
    when public.normalize_unit_keyword(legacy_unit_type) = 'Caracter'
      or public.normalize_unit_keyword(category) = 'Caracter'
      then array['Infanteria', 'Caracter']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Fortificacion'
      or public.normalize_unit_keyword(category) = 'Fortificacion'
      then array['Fortificacion']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Aeronave'
      or public.normalize_unit_keyword(category) = 'Aeronave'
      then array['Vehiculo', 'Aeronave']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Vehiculo'
      or public.normalize_unit_keyword(category) = 'Vehiculo'
      then array['Vehiculo']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Monstruo'
      or public.normalize_unit_keyword(category) = 'Monstruo'
      then array['Monstruo']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Bestia'
      or public.normalize_unit_keyword(category) = 'Bestia'
      then array['Bestia']::text[]
    when public.normalize_unit_keyword(legacy_unit_type) = 'Montado'
      or public.normalize_unit_keyword(category) = 'Montado'
      then array['Montado']::text[]
    else array['Infanteria']::text[]
  end;
$$;

create or replace function public.legacy_unit_type_from_keywords(keywords text[])
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when 'Caracter' = any(coalesce(keywords, array[]::text[])) then 'character'
    when 'Vehiculo' = any(coalesce(keywords, array[]::text[]))
      or 'Aeronave' = any(coalesce(keywords, array[]::text[]))
      or 'Fortificacion' = any(coalesce(keywords, array[]::text[])) then 'vehicle'
    when 'Monstruo' = any(coalesce(keywords, array[]::text[])) then 'monster'
    when 'Bestia' = any(coalesce(keywords, array[]::text[])) then 'beast'
    when 'Montado' = any(coalesce(keywords, array[]::text[])) then 'mounted'
    else 'infantry'
  end;
$$;

create or replace function public.map_unit_category_to_type(category text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when lower(coalesce(category, '')) in ('monster', 'monstruo', 'monsters') then 'monster'
    when lower(coalesce(category, '')) in ('beast', 'bestia', 'swarm') then 'beast'
    when lower(coalesce(category, '')) in ('vehicle', 'vehiculo', 'vehiculos', 'superpesado') then 'vehicle'
    when lower(coalesce(category, '')) in ('character', 'characters', 'personaje', 'personajes') then 'character'
    when lower(coalesce(category, '')) in ('mounted', 'montada', 'montado', 'montados', 'montadas') then 'mounted'
    when lower(coalesce(category, '')) like '%veh%' then 'vehicle'
    when lower(coalesce(category, '')) like '%person%' or lower(coalesce(category, '')) like '%character%' then 'character'
    when lower(coalesce(category, '')) like '%monstru%' or lower(coalesce(category, '')) like '%monster%' then 'monster'
    when lower(coalesce(category, '')) like '%beast%' then 'beast'
    when lower(coalesce(category, '')) like '%mount%' or lower(coalesce(category, '')) like '%montad%' then 'mounted'
    else 'infantry'
  end;
$$;

with desired_costs(slug, unit_type, unit_keywords, supply_cost, minerals_cost, honor_cost, gold_cost, recruitment_building_type) as (
  values
${values}
)
update public.unit_templates
set
  unit_type = desired_costs.unit_type,
  unit_keywords = desired_costs.unit_keywords,
  supply_cost = desired_costs.supply_cost,
  minerals_cost = desired_costs.minerals_cost,
  honor_cost = desired_costs.honor_cost,
  gold_cost = desired_costs.gold_cost,
  industrial_material_cost = 0,
  uridium_cost = 0,
  technology_cost = 0,
  recruitment_building_type = desired_costs.recruitment_building_type
from desired_costs
where unit_templates.slug = desired_costs.slug;

update public.campaign_units
set
  unit_type = unit_templates.unit_type,
  unit_keywords = unit_templates.unit_keywords
from public.unit_templates
join public.factions on factions.id = unit_templates.faction_id
where campaign_units.unit_template_id = unit_templates.id
  and factions.slug in ('adeptus-custodes', 'legiones-daemonicas', 'cultos-genestealer', 'necrones');

create or replace function public.recruitment_cost_bundle_for_template(
  target_unit_template_id uuid,
  selected_points integer
)
returns table (
  supply_cost integer,
  minerals_cost integer,
  honor_cost integer,
  gold_cost integer,
  industrial_material_cost integer,
  uridium_cost integer,
  technology_cost integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_template public.unit_templates%rowtype;
  v_faction_slug text;
  v_points integer;
  v_base_value integer;
  v_allocated integer;
begin
  select * into v_template
  from public.unit_templates
  where id = target_unit_template_id;

  if not found then
    raise exception 'Unidad no encontrada';
  end if;

  select factions.slug into v_faction_slug
  from public.factions
  where factions.id = v_template.faction_id;

  v_points := greatest(coalesce(selected_points, v_template.points, 0), 0);

  if v_points = v_template.points then
    supply_cost := coalesce(v_template.supply_cost, 0);
    minerals_cost := coalesce(v_template.minerals_cost, 0);
    honor_cost := coalesce(v_template.honor_cost, 0);
    gold_cost := coalesce(v_template.gold_cost, 0);
  elsif v_faction_slug = 'space-marines' then
    minerals_cost := floor(((v_points::numeric * coalesce(v_template.minerals_cost, 0) * 2) / greatest(v_template.points, 1)) / 2)::integer;
    honor_cost := floor(((v_points::numeric * coalesce(v_template.honor_cost, 0) * 5) / greatest(v_template.points, 1)) / 5)::integer;
    gold_cost := floor(((v_points::numeric * coalesce(v_template.gold_cost, 0) * 5) / greatest(v_template.points, 1)) / 5)::integer;
    if coalesce(v_template.gold_cost, 0) > 0 and v_points >= 5 then
      gold_cost := greatest(1, gold_cost);
    end if;
    while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and gold_cost > 0 loop
      gold_cost := gold_cost - 1;
    end loop;
    while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and honor_cost > 0 loop
      honor_cost := honor_cost - 1;
    end loop;
    while minerals_cost * 2 + honor_cost * 5 + gold_cost * 5 > v_points and minerals_cost > 0 loop
      minerals_cost := minerals_cost - 1;
    end loop;
    supply_cost := v_points - minerals_cost * 2 - honor_cost * 5 - gold_cost * 5;
  else
    v_base_value := coalesce(v_template.supply_cost, 0)
      + coalesce(v_template.minerals_cost, 0) * 2
      + coalesce(v_template.honor_cost, 0) * 5
      + coalesce(v_template.gold_cost, 0) * 5;

    supply_cost := 0;
    minerals_cost := 0;
    honor_cost := 0;
    gold_cost := 0;

    if v_base_value <= 0 then
      supply_cost := v_points;
    elsif coalesce(v_template.supply_cost, 0) > 0 then
      if coalesce(v_template.minerals_cost, 0) > 0 then
        minerals_cost := greatest(1, floor((v_points::numeric * v_template.minerals_cost) / v_base_value)::integer);
      end if;
      if coalesce(v_template.honor_cost, 0) > 0 then
        honor_cost := greatest(1, floor((v_points::numeric * v_template.honor_cost) / v_base_value)::integer);
      end if;
      if coalesce(v_template.gold_cost, 0) > 0 then
        gold_cost := greatest(1, floor((v_points::numeric * v_template.gold_cost) / v_base_value)::integer);
      end if;
      v_allocated := minerals_cost * 2 + honor_cost * 5 + gold_cost * 5;
      supply_cost := greatest(1, v_points - v_allocated);
    elsif coalesce(v_template.minerals_cost, 0) > 0 then
      if coalesce(v_template.honor_cost, 0) > 0 then
        honor_cost := greatest(1, floor((v_points::numeric * v_template.honor_cost) / v_base_value)::integer);
      end if;
      if coalesce(v_template.gold_cost, 0) > 0 then
        gold_cost := greatest(1, floor((v_points::numeric * v_template.gold_cost) / v_base_value)::integer);
      end if;
      v_allocated := honor_cost * 5 + gold_cost * 5;
      minerals_cost := greatest(1, ceil(greatest(0, v_points - v_allocated)::numeric / 2)::integer);
    elsif coalesce(v_template.honor_cost, 0) > 0 then
      if coalesce(v_template.gold_cost, 0) > 0 then
        gold_cost := greatest(1, floor((v_points::numeric * v_template.gold_cost) / v_base_value)::integer);
      end if;
      honor_cost := greatest(1, ceil(greatest(0, v_points - gold_cost * 5)::numeric / 5)::integer);
    else
      gold_cost := greatest(1, ceil(v_points::numeric / 5)::integer);
    end if;
  end if;

  industrial_material_cost := 0;
  uridium_cost := 0;
  technology_cost := 0;
  return next;
end;
$$;

insert into public.campaign_logs (action_type, payload)
values (
  'unit_cost_profiles_rebalanced',
  jsonb_build_object(
    'factions', array['adeptus-custodes', 'legiones-daemonicas', 'cultos-genestealer', 'necrones'],
    'space_marines_preserved', true,
    'monster_keyword_separated', true,
    'changed_at', now()
  )
);
`;
}

function buildInitialUnitsSql(units) {
  const byFactionAndName = new Map(units.map((unit) => [`${unit.factionSlug}:${unit.name}`, unit]));
  const values = INITIAL_UNITS.map(([slug, factionSlug, templateName, systemSlug, status, level, rank, wounds, quantityOverride, startingQuantityOverride, pointsOverride]) => {
    const template = byFactionAndName.get(`${factionSlug}:${templateName}`);
    if (!template) {
      throw new Error(`No existe la plantilla inicial ${factionSlug}:${templateName}`);
    }
    const quantity = quantityOverride ?? template.defaultQuantity;
    const startingQuantity = startingQuantityOverride ?? template.defaultQuantity;
    const points = resolveInitialUnitPoints(template, startingQuantity, pointsOverride);
    return `    (${sql(slug)}, ${sql(factionSlug)}, ${sql(template.slug)}, ${sql(template.name)}, ${sql(template.category)}, ${sql(template.unitType)}, ${sqlArray(template.unitKeywords)}, ${points}, ${quantity}, ${startingQuantity}, ${wounds}, ${level}, ${rank === null ? "null" : sql(rank)}, ${sql(systemSlug)}, ${sql(status)})`;
  }).join(",\n");

  return `insert into public.campaign_units (
  id, slug, faction_id, unit_template_id, name, category, unit_type, unit_keywords, points, quantity, starting_quantity, wounds_taken, experience, rank, current_system_id, status, is_visible_publicly
)
select
  public.seed_uuid('campaign_unit', data.slug),
  data.slug,
  factions.id,
  unit_templates.id,
  data.name,
  data.category,
  data.unit_type,
  data.unit_keywords,
  data.points,
  data.quantity,
  data.starting_quantity,
  data.wounds_taken,
  data.experience,
  case when data.unit_keywords @> array['Caracter']::text[] then public.character_rank_for_level(data.experience) else data.rank end,
  public.seed_uuid('system', data.system_slug),
  data.status,
  false
from (
  values
${values}
) as data(slug, faction_slug, template_slug, name, category, unit_type, unit_keywords, points, quantity, starting_quantity, wounds_taken, experience, rank, system_slug, status)
join public.factions on factions.slug = data.faction_slug
join public.unit_templates on unit_templates.slug = data.template_slug
on conflict (slug) do update
set faction_id = excluded.faction_id, unit_template_id = excluded.unit_template_id, name = excluded.name, category = excluded.category, unit_type = excluded.unit_type, unit_keywords = excluded.unit_keywords, points = excluded.points, quantity = excluded.quantity, starting_quantity = excluded.starting_quantity, wounds_taken = excluded.wounds_taken, experience = excluded.experience, rank = excluded.rank, current_system_id = excluded.current_system_id, status = excluded.status, is_visible_publicly = excluded.is_visible_publicly, updated_at = now();`;
}

function buildMovementSql() {
  if (MOVEMENT_ORDERS.length === 0) {
    return "-- El mapa final no arranca con movimientos precargados.";
  }

  const orders = MOVEMENT_ORDERS.map(([slug, factionSlug, , from, to]) =>
    `  (public.seed_uuid('movement_order', ${sql(slug)}), public.seed_uuid('faction', ${sql(factionSlug)}), public.seed_uuid('system', ${sql(from)}), public.seed_uuid('system', ${sql(to)}), 1, now() - interval '1 second', now() + interval '3 seconds', 'moving', array[public.seed_uuid('system', ${sql(from)}), public.seed_uuid('system', ${sql(to)})]::uuid[], 1, 3)`
  ).join(",\n");

  const orderUnits = MOVEMENT_ORDERS.map(([slug, , unitSlug]) =>
    `  (public.seed_uuid('movement_order', ${sql(slug)}), public.seed_uuid('campaign_unit', ${sql(unitSlug)}), (select quantity from public.campaign_units where slug = ${sql(unitSlug)}))`
  ).join(",\n");

  return `insert into public.movement_orders (
  id, faction_id, from_system_id, to_system_id, uridium_cost, started_at, arrival_at, status, path_system_ids, segment_count, duration_seconds
)
values
${orders}
on conflict (id) do update
set faction_id = excluded.faction_id, from_system_id = excluded.from_system_id, to_system_id = excluded.to_system_id, uridium_cost = excluded.uridium_cost, started_at = excluded.started_at, arrival_at = excluded.arrival_at, status = excluded.status, path_system_ids = excluded.path_system_ids, segment_count = excluded.segment_count, duration_seconds = excluded.duration_seconds;

insert into public.movement_order_units (movement_order_id, unit_id, quantity_at_departure)
values
${orderUnits}
on conflict (movement_order_id, unit_id) do update
set quantity_at_departure = excluded.quantity_at_departure;`;
}

function updateSeed(units) {
  const seed = readFileSync(SEED_PATH, "utf8");
  const seedAnchor = seed.indexOf("select public.refresh_system_production_from_buildings();");
  const unitsMarkerStart = seed.indexOf("-- BEGIN GENERATED 40K UNIT CATALOG", seedAnchor);
  const unitsStart = unitsMarkerStart === -1
    ? seed.indexOf("insert into public.unit_templates (", seedAnchor)
    : unitsMarkerStart;
  const relicStart = seed.indexOf("insert into public.relics (", unitsStart);
  const movementMarkerStart = seed.indexOf("-- BEGIN GENERATED 40K MOVEMENTS", relicStart);
  const movementStart = movementMarkerStart === -1
    ? seed.indexOf("insert into public.movement_orders (", relicStart)
    : movementMarkerStart;
  const tradeStart = seed.indexOf("insert into public.trade_offers (", movementStart);
  const unitsMarkerEnd = seed.indexOf("-- END GENERATED 40K UNIT CATALOG", unitsStart);
  const postUnitHooksStart = unitsMarkerEnd === -1 ? -1 : seed.indexOf("\n", unitsMarkerEnd);
  const postUnitHooks = postUnitHooksStart === -1 ? "" : seed.slice(postUnitHooksStart + 1, relicStart);

  if (unitsStart === -1 || relicStart === -1 || movementStart === -1 || tradeStart === -1 || unitsMarkerEnd === -1) {
    throw new Error("No se encontraron los bloques esperados en supabase/seed.sql.");
  }

  const unitsBlock = [
    "-- BEGIN GENERATED 40K UNIT CATALOG",
    buildUnitTemplateSql(units),
    "",
    buildInitialUnitsSql(units),
    "-- END GENERATED 40K UNIT CATALOG",
    ""
  ].join("\n");

  const movementBlock = [
    "-- BEGIN GENERATED 40K MOVEMENTS",
    buildMovementSql(),
    "-- END GENERATED 40K MOVEMENTS",
    ""
  ].join("\n");

  const withUnits = `${seed.slice(0, unitsStart)}${unitsBlock}${postUnitHooks}${seed.slice(relicStart, movementStart)}${movementBlock}${seed.slice(tradeStart)}`;
  writeFileSync(SEED_PATH, withUnits);
}

function buildMockFile(units) {
  const factions = FACTION_DEFS.map((faction) => ({
    id: faction.slug,
    name: faction.name,
    color: faction.color,
    capitalSystemId: faction.capitalSystemId
  }));

  const templates = units.map((unit) => ({
    id: unit.slug,
    factionId: unit.factionSlug,
    name: unit.name,
    category: unit.category,
    unitType: unit.unitType,
    unitKeywords: unit.unitKeywords,
    points: unit.points,
    defaultQuantity: unit.defaultQuantity,
    woundsPerModel: unit.woundsPerModel,
    supplyCost: unit.supplyCost,
    mineralsCost: unit.mineralsCost,
    honorCost: unit.honorCost,
    goldCost: unit.goldCost,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0,
    recruitmentTimeSeconds: campaignRecruitmentTimeSeconds(unit.points),
    recruitmentBuildingType: unit.recruitmentBuildingType,
    notes: unit.notes,
    isAvailable: false,
    requiredTechnologyNodeId: null,
    sourceSection: unit.sourceSection,
    sourceFactionName: unit.sourceFactionName,
    isAlliedUnit: unit.isAlliedUnit
  }));

  const unitByKey = new Map(units.map((unit) => [`${unit.factionSlug}:${unit.name}`, unit]));
  const initialUnits = INITIAL_UNITS.map(([slug, factionSlug, templateName, systemSlug, status, level, , wounds, quantityOverride, startingQuantityOverride, pointsOverride]) => {
    const template = unitByKey.get(`${factionSlug}:${templateName}`);
    const quantity = quantityOverride ?? template.defaultQuantity;
    const startingQuantity = startingQuantityOverride ?? template.defaultQuantity;
    const points = resolveInitialUnitPoints(template, startingQuantity, pointsOverride);
    return {
      id: slug,
      factionId: factionSlug,
      unitTemplateId: template.slug,
      name: template.name,
      currentSystemId: systemSlug,
      status,
      category: template.category,
      unitType: template.unitType,
      unitKeywords: template.unitKeywords,
      points,
      quantity,
      startingQuantity,
      woundsTaken: wounds,
      experience: level,
      isVisiblePublicly: false,
      parentUnitId: null,
      destroyedAt: null,
      rank: template.unitKeywords.includes("Caracter") ? null : null,
      enhancementText: null,
      notes: null
    };
  });

  return `import type { CampaignSnapshot } from "@/domain/campaign";

export const generated40kFactions = ${JSON.stringify(factions, null, 2)} satisfies CampaignSnapshot["factions"];

export const generated40kUnitTemplates = ${JSON.stringify(templates, null, 2)} satisfies CampaignSnapshot["unitTemplates"];

export const generated40kInitialUnits = ${JSON.stringify(initialUnits, null, 2)} satisfies CampaignSnapshot["units"];
`;
}

function buildReport(catalog) {
  const byFaction = new Map();
  const byCategory = new Map();
  for (const unit of catalog.units) {
    byFaction.set(unit.sourceFactionName, (byFaction.get(unit.sourceFactionName) ?? 0) + 1);
    byCategory.set(unit.category, (byCategory.get(unit.category) ?? 0) + 1);
    if (!CANONICAL_CATEGORIES.has(unit.category)) {
      throw new Error(`Categoria no canonica detectada: ${unit.category}`);
    }
  }
  const astraCount = catalog.units.filter((unit) => unit.factionSlug === "astra-militarum").length;
  const custodesCount = catalog.units.filter((unit) => unit.factionSlug === "adeptus-custodes").length;

  const lines = [
    "# Informe de importacion de unidades 40K",
    "",
    "Generado por `npm run units:generate` desde `data/11th40kPoints.txt`.",
    "",
    `- Hojas de unidad importadas: ${catalog.units.length}.`,
    `- Adeptus Custodes: ${custodesCount}.`,
    `- Astra Militarum: ${astraCount}.`,
    `- Fuente de keywords reales: BSData/wh40k-10e @ ${catalog.keywordSource.commit}.`,
    `- Archivos BSData escaneados: ${catalog.keywordSource.filesScanned}.`,
    `- Entradas BSData escaneadas: ${catalog.keywordSource.entriesScanned}.`,
    `- Entradas BSData con keywords de tipo usadas por el rol: ${catalog.keywordSource.entriesWithTrackedKeywords}.`,
    `- Unidades con keywords reales cruzadas: ${catalog.keywordMatches.length}.`,
    `- Cruces BSData faltantes: ${catalog.missingKeywordMatches.length}.`,
    "- Fallback heuristico: 0.",
    `- Puntos base actualizados desde MFM: ${catalog.mfmPointOverrides.length}.`,
    "- Material Industrial y Uridium: siempre 0 en costes de unidades.",
    "- Disponibilidad inicial: todas las plantillas importadas quedan bloqueadas (`is_available = false`).",
    "",
    "## Validacion por bloque",
    "",
    ...catalog.factionSummaries.map(
      (summary) =>
        `- ${summary.sourceFactionName}: ${summary.importedUnits}/${summary.expectedUnits} unidades, ${summary.importedPoints}/${summary.totalPoints} puntos.`
    ),
    "",
    "## Unidades por faccion",
    "",
    ...[...byFaction.entries()].map(([name, count]) => `- ${name}: ${count}`),
    "",
    "## Unidades por categoria",
    "",
    ...[...byCategory.entries()].map(([name, count]) => `- ${name}: ${count}`),
    "",
    "## Cruces BSData faltantes",
    "",
    ...(catalog.missingKeywordMatches.length > 0 ? catalog.missingKeywordMatches.map((line) => `- ${line}`) : ["- Ninguno."]),
    "",
    "## Puntos base actualizados desde MFM",
    "",
    ...(catalog.mfmPointOverrides.length > 0 ? catalog.mfmPointOverrides.map((line) => `- ${line}`) : ["- Ninguno."])
  ];

  return `${lines.join("\n")}\n`;
}

function buildBalanceReport(catalog, balance, balanceConfig) {
  const targetFactionSlugs = new Set(balanceConfig.rebalanceFactionSlugs ?? []);
  const summaryLines = balance.factionSummaries
    .filter((summary) => targetFactionSlugs.has(summary.factionSlug))
    .map((summary) => {
      const values = summary.totals;
      return `| ${summary.factionSlug} | ${summary.unitCount} | ${summary.goldUnits} (${summary.goldUnitPercent}%) | ${values.points} | ${values.supply} | ${values.minerals} | ${values.honor} | ${values.gold} |`;
    });
  const typeGoldLines = balance.factionSummaries
    .filter((summary) => targetFactionSlugs.has(summary.factionSlug))
    .flatMap((summary) => summary.byType.map((typeSummary) => (
      `| ${summary.factionSlug} | ${typeSummary.type} | ${typeSummary.unitCount} | ${typeSummary.goldUnits} |`
    )));

  const initialInfantry = balance.summaries
    .filter((item) => targetFactionSlugs.has(item.factionSlug) && item.isInitialBasicInfantry)
    .map((item) => `- ${item.factionSlug}: ${item.name} -> ${item.costs.supplyCost} Suministro`);
  const honorUnits = catalog.units
    .filter((unit) => targetFactionSlugs.has(unit.factionSlug) && unit.honorCost > 0)
    .map((unit) => `- ${unit.factionSlug}: ${unit.name} -> ${unit.honorCost} Honor (${Math.round(resourceShare(unit.honorCost, unit.points) * 100)}%, ${unit.unitKeywords.join(", ")})`);

  const invalidPointValues = balance.summaries.filter((item) => {
    const value = warhammerPointValue(item.costs);
    return value !== item.points && !(value === item.points + 1 && item.costs.supplyCost === 0 && item.costs.mineralsCost > 0);
  });
  const invalidMilitaryCosts = balance.summaries.filter(
    (item) => (item.costs.industrialMaterialCost ?? 0) !== 0 || (item.costs.uridiumCost ?? 0) !== 0
  );
  const invalidHonorCosts = catalog.units.filter(
    (unit) => unit.honorCost > 0 && !unit.unitKeywords.includes(balanceConfig.honorOnlyForKeyword ?? "Caracter")
  );
  const pairLines = (balanceConfig.initialPairs ?? []).map((pair) => {
    const capital = balanceConfig.systemCapacities?.[pair.capitalSlug] ?? {};
    const adjacent = balanceConfig.systemCapacities?.[pair.adjacentSlug] ?? {};
    return `| ${pair.factionSlug} | ${pair.capitalSlug} | ${systemWarhammerPointValue(capital)} | ${pair.adjacentSlug} | ${systemWarhammerPointValue(adjacent)} | ${systemWarhammerPointValue(capital) + systemWarhammerPointValue(adjacent)} | ${capital.industrial_material ?? 0} | ${adjacent.uridium ?? 0} |`;
  });

  const lines = [
    "# Informe de balance de facciones",
    "",
    "Generado por `npm run units:generate`.",
    "",
    "## Reglas aplicadas",
    "",
    "- Conversion: `supply + 2*minerals + 5*honor + 5*gold = points`.",
    "- Material Industrial y Uridium no se usan para reclutar unidades.",
    `- Capital + adyacente objetivo: ${balanceConfig.dailyInitialPairRecruitmentPoints} puntos de reclutamiento/dia.`,
    "- Uridium y Material Industrial tienen economia separada.",
    "- La campana empieza sin edificios construidos.",
    "- Por defecto ninguna unidad cuesta Oro; solo lo hacen las excepciones de faccion y las aliadas que cumplen su umbral.",
    "- El Oro ocupa un 25% del coste indicado, o un 20% para Shield-Captains y unidades aliadas elegibles.",
    "- Las excepciones de infanteria basica indicadas cuestan exclusivamente Suministro vital.",
    `- Honor solo aparece en unidades con keyword ${balanceConfig.honorOnlyForKeyword ?? "Caracter"}.`,
    "- Los Characters usan 50% de Honor; Legiones Daemonicas y Cultos Genestealer usan 40%.",
    "- Vehiculos usan Mineral; Monstruos usan 80% Mineral y 20% Suministro; Bestias conservan su perfil de tropas organicas.",
    "- Las variantes conservan exactamente los mismos tipos de recurso que su configuracion minima.",
    "- Los redondeos se completan con el recurso mas barato ya presente en el perfil.",
    "",
    "## Resumen por faccion jugable",
    "",
    "| Faccion | Unidades | Unidades con oro | Puntos catalogo | Suministro | Mineral | Honor | Oro |",
    "|---|---:|---:|---:|---:|---:|---:|---:|",
    ...summaryLines,
    "",
    "## Distribucion de Oro por tipo principal",
    "",
    "| Faccion | Tipo | Unidades | Con oro |",
    "|---|---|---:|---:|",
    ...typeGoldLines,
    "",
    "## Infanteria inicial solo suministro",
    "",
    ...initialInfantry,
    "",
    "## Unidades con Honor",
    "",
    ...honorUnits,
    "",
    "## Produccion natural inicial",
    "",
    "| Faccion | Capital | Pts capital | Adyacente | Pts adyacente | Total | Material capital | Uridium adyacente |",
    "|---|---|---:|---|---:|---:|---:|---:|",
    ...pairLines,
    "",
    "## Validaciones rapidas",
    "",
    `- Unidades con conversion de puntos invalida: ${invalidPointValues.length}.`,
    `- Unidades con Material Industrial o Uridium: ${invalidMilitaryCosts.length}.`,
    `- Unidades no character con Honor: ${invalidHonorCosts.length}.`,
    "- Sombra del Emperador: costes preservados sin cambios.",
    `- Facciones importadas desde catalogo: ${catalog.factionSummaries.length}.`
  ];

  return `${lines.join("\n")}\n`;
}

function resourceShare(resourceAmount, points) {
  return (Number(resourceAmount ?? 0) * 5) / Math.max(1, Number(points ?? 0));
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function readPreservedTemplateCosts(path) {
  let source;
  try {
    source = execSync(`git show HEAD:${path.replaceAll("\\", "/")}`, { encoding: "utf8" });
  } catch {
    if (!existsSync(path)) return new Map();
    source = readFileSync(path, "utf8");
  }
  const marker = "export const generated40kUnitTemplates = ";
  const markerIndex = source.indexOf(marker);
  const arrayStart = source.indexOf("[", markerIndex + marker.length);
  const arrayEnd = source.indexOf("] satisfies CampaignSnapshot[\"unitTemplates\"]", arrayStart);

  if (markerIndex < 0 || arrayStart < 0 || arrayEnd < 0) {
    throw new Error(`No se pudieron leer los costes existentes de ${path}.`);
  }

  const templates = JSON.parse(source.slice(arrayStart, arrayEnd + 1));
  return new Map(templates.map((template) => [template.id, template]));
}

function buildMfmBasePointOverrides() {
  if (!existsSync(MFM_COST_OPTIONS_PATH)) {
    return new Map();
  }

  const payload = readJson(MFM_COST_OPTIONS_PATH);
  const units = Array.isArray(payload.units) ? payload.units : Array.isArray(payload) ? payload : [];
  const overrides = new Map();

  for (const unit of units) {
    const factionSlug = unit.factionSlug;
    const unitSlug = unit.unitSlug;
    const providedModels = Number(unit.provided?.models);
    const providedPoints = Number(unit.provided?.points);
    if (!factionSlug || !unitSlug || !Number.isFinite(providedModels) || !Number.isFinite(providedPoints)) {
      continue;
    }

    const modelOptions = Array.isArray(unit.modelOptions) ? unit.modelOptions : [];
    const baseOption = modelOptions
      .filter((option) => Number(option.models) === providedModels && Number.isFinite(Number(option.points)))
      .sort(compareMfmModelOptions)[0];

    if (!baseOption) {
      continue;
    }

    const points = Number(baseOption.points);
    if (points <= 0 || points === providedPoints) {
      continue;
    }

    overrides.set(`${factionSlug}:${unitSlug}:${providedModels}`, {
      points,
      providedPoints,
      models: providedModels,
      label: baseOption.label ?? `${providedModels} modelos`
    });
  }

  return overrides;
}

function compareMfmModelOptions(left, right) {
  const leftFrom = Number(left.copyRange?.from ?? 1);
  const rightFrom = Number(right.copyRange?.from ?? 1);
  if (leftFrom !== rightFrom) {
    return leftFrom - rightFrom;
  }

  const leftTo = left.copyRange?.to == null ? Number.MAX_SAFE_INTEGER : Number(left.copyRange.to);
  const rightTo = right.copyRange?.to == null ? Number.MAX_SAFE_INTEGER : Number(right.copyRange.to);
  if (leftTo !== rightTo) {
    return leftTo - rightTo;
  }

  return Number(left.points) - Number(right.points);
}

function findMfmBasePointOverride(overrides, factionSlug, unitSlug, defaultQuantity) {
  return overrides.get(`${factionSlug}:${unitSlug}:${defaultQuantity}`) ?? null;
}

function resolveInitialUnitPoints(template, startingQuantity, pointsOverride) {
  if (pointsOverride == null || Number(startingQuantity) === Number(template.defaultQuantity)) {
    return template.points;
  }

  return pointsOverride;
}

function sql(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function sqlArray(values) {
  return `array[${values.map(sql).join(", ")}]::text[]`;
}

function writeText(path, content) {
  const directory = dirname(path);
  if (directory && directory !== "." && !existsSync(directory)) {
    mkdirSync(directory, { recursive: true });
  }
  writeFileSync(path, content);
}

void SECTION_LABELS;
void collectUnitLines;
void mapCategory;
void inferKeywords;
void isVehicleName;
void isBeastName;
void isMountedName;
void inferModelCount;
void isMultiModelCharacter;
void looksLikeWargear;

main();
