import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

const SOURCE_PATH = "40kPoints.txt";
const SEED_PATH = "supabase/seed.sql";
const MOCK_PATH = "src/mocks/generated/40k-unit-templates.ts";
const REPORT_PATH = "docs/generated/40k-unit-import-report.md";

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

const FACTION_DEFS = [
  {
    sourceName: "Legiones Daemónicas",
    slug: "legiones-daemonicas",
    name: "Legiones Daemónicas",
    color: "#ef4444",
    capitalSystemId: "mordax"
  },
  {
    sourceName: "Agentes del Imperium",
    slug: "agentes-imperium",
    name: "Agentes del Imperium",
    color: "#f59e0b",
    capitalSystemId: "argent-rift"
  },
  {
    sourceName: "Cultos Genestealer",
    slug: "cultos-genestealer",
    name: "Cultos Genestealer",
    color: "#c084fc",
    capitalSystemId: "blackglass"
  },
  {
    sourceName: "Aeldari",
    slug: "aeldari",
    name: "Aeldari",
    color: "#fb7185",
    capitalSystemId: "cinder-maw"
  },
  {
    sourceName: "Space Marines",
    slug: "space-marines",
    name: "Space Marines",
    color: "#facc15",
    capitalSystemId: "sa-cea-gate"
  },
  {
    sourceName: "Astra Militarum",
    slug: "astra-militarum",
    name: "Astra Militarum",
    color: "#38bdf8",
    capitalSystemId: "kharon-prime"
  },
  {
    sourceName: "Necrones",
    slug: "necrones",
    name: "Necrones",
    color: "#2dd4bf",
    capitalSystemId: "thokt-vault"
  }
];

const INITIAL_UNITS = [
  ["astra-kharon-cadians", "astra-militarum", "Cadian Shock Troops", "kharon-prime", "ready", 1, null, 0],
  ["astra-arx-leman", "astra-militarum", "Leman Russ Battle Tank", "arx-solum", "moving", 1, null, 0],
  ["astra-castellan", "astra-militarum", "Cadian Castellan", "kharon-prime", "ready", 3, null, 0],
  ["astra-azur-cadians", "astra-militarum", "Cadian Shock Troops", "azur-trench", "in_war", 1, null, 0],
  ["aeldari-cinder-guardians", "aeldari", "Guardian Defenders", "cinder-maw", "ready", 1, null, 0],
  ["aeldari-rust-dire-avengers", "aeldari", "Dire Avengers", "rustmaw-run", "moving", 1, null, 0],
  ["aeldari-farseer", "aeldari", "Farseer", "cinder-maw", "ready", 3, null, 0],
  ["aeldari-azur-guardians", "aeldari", "Guardian Defenders", "azur-trench", "in_war", 1, null, 0],
  ["space-gate-intercessors", "space-marines", "Intercessor Squad", "sa-cea-gate", "ready", 1, null, 0],
  ["space-narthex-rhino", "space-marines", "Rhino", "narthex", "moving", 1, null, 0],
  ["space-captain", "space-marines", "Captain", "sa-cea-gate", "ready", 3, null, 0],
  ["space-saint-intercessors", "space-marines", "Intercessor Squad", "saint-veil", "in_war", 1, null, 0],
  ["cult-blackglass-neophytes", "cultos-genestealer", "Neophyte Hybrids", "blackglass", "ready", 1, null, 0],
  ["cult-mirror-ridgerunner", "cultos-genestealer", "Achilles Ridgerunners", "mirrorcoil", "moving", 1, null, 0],
  ["cult-primus", "cultos-genestealer", "Primus", "blackglass", "ready", 3, null, 0],
  ["cult-saint-neophytes", "cultos-genestealer", "Neophyte Hybrids", "saint-veil", "in_war", 1, null, 0],
  ["necron-thokt-warriors", "necrones", "Necron Warriors", "thokt-vault", "ready", 1, null, 0],
  ["necron-ghost-wraiths", "necrones", "Canoptek Wraiths", "ghostlight", "moving", 1, null, 0],
  ["necron-overlord", "necrones", "Overlord", "thokt-vault", "ready", 3, null, 0],
  ["necron-ossuary-warriors", "necrones", "Necron Warriors", "ossuary-reach", "in_war", 1, null, 0],
  ["daemon-mordax-horrors", "legiones-daemonicas", "Pink Horrors", "mordax", "ready", 1, null, 0],
  ["daemon-plaguefall-screamers", "legiones-daemonicas", "Screamers", "plaguefall-bastion", "moving", 1, null, 0],
  ["daemon-lord-change", "legiones-daemonicas", "Lord of Change", "mordax", "ready", 3, null, 0],
  ["daemon-ossuary-horrors", "legiones-daemonicas", "Blue Horrors", "ossuary-reach", "in_war", 1, null, 0],
  ["agents-argent-breachers", "agentes-imperium", "Imperial Navy Breachers", "argent-rift", "ready", 1, null, 0],
  ["agents-orison-deathwatch", "agentes-imperium", "Deathwatch Kill Team", "orison", "moving", 1, null, 0],
  ["agents-inquisitor", "agentes-imperium", "Inquisitor", "argent-rift", "ready", 3, null, 0]
];

const MOVEMENT_ORDERS = [
  ["move-astra-helios", "astra-militarum", "astra-arx-leman", "arx-solum", "helios-drift"],
  ["move-aeldari-eclipse", "aeldari", "aeldari-rust-dire-avengers", "rustmaw-run", "eclipse-forge"],
  ["move-space-lyra", "space-marines", "space-narthex-rhino", "narthex", "lyra-terminus"],
  ["move-cult-red-sabbath", "cultos-genestealer", "cult-mirror-ridgerunner", "mirrorcoil", "red-sabbath"],
  ["move-necron-novem", "necrones", "necron-ghost-wraiths", "ghostlight", "novem"],
  ["move-daemon-drusus", "legiones-daemonicas", "daemon-plaguefall-screamers", "plaguefall-bastion", "drusus"],
  ["move-agents-vesper", "agentes-imperium", "agents-orison-deathwatch", "orison", "vesper-halo"]
];

function main() {
  const text = readFileSync(SOURCE_PATH, "utf8");
  const catalog = parseCatalog(text);
  const report = buildReport(catalog);
  writeText(REPORT_PATH, report);
  writeText(MOCK_PATH, buildMockFile(catalog.units));
  updateSeed(catalog.units);

  console.log(`Catalogo generado: ${catalog.units.length} unidades reales.`);
  console.log(`Lineas de cabecera omitidas: ${catalog.skippedHeaders.length}.`);
}

function parseCatalog(text) {
  const segments = text.split(/\r?\n\.\.\.\.\.\r?\n/g);
  const units = [];
  const skippedHeaders = [];

  for (const segment of segments) {
    const rawLines = segment.split(/\r?\n/);
    const lines = rawLines.map((line) => line.trimEnd());
    const nonEmpty = lines.map((line) => line.trim()).filter(Boolean);
    const sourceFactionName = nonEmpty.find((line) => FACTION_DEFS.some((faction) => faction.sourceName === line));
    const faction = FACTION_DEFS.find((item) => item.sourceName === sourceFactionName);

    if (!faction) {
      throw new Error(`No se pudo identificar la faccion del segmento: ${nonEmpty.slice(0, 4).join(" | ")}`);
    }

    let section = "";
    for (let index = 0; index < lines.length; index += 1) {
      const trimmed = lines[index].trim();
      const normalized = trimmed.toUpperCase();

      if (SECTION_LABELS.has(normalized)) {
        section = normalized;
        continue;
      }

      const unitMatch = trimmed.match(/^(.+?) \((\d+) puntos\)$/);
      if (!unitMatch) {
        continue;
      }

      if (!section) {
        skippedHeaders.push(`${faction.sourceName}: ${trimmed}`);
        continue;
      }

      const [, name, pointsText] = unitMatch;
      const unitLines = collectUnitLines(lines, index + 1);
      const points = Number(pointsText);
      const isAlliedUnit = section === "UNIDADES ALIADAS";
      const category = mapCategory(section);
      const unitKeywords = inferKeywords(name, section);
      const defaultQuantity = inferModelCount(name, section, unitLines);
      const costs = computeCosts(points, unitKeywords, category);
      const slug = uniqueSlug(units, `unit-${faction.slug}-${slugify(name)}`);

      units.push({
        slug,
        factionSlug: faction.slug,
        sourceFactionName: faction.sourceName,
        name,
        sourceSection: section,
        isAlliedUnit,
        category,
        unitKeywords,
        unitType: legacyUnitType(unitKeywords),
        points,
        defaultQuantity,
        woundsPerModel: inferWoundsPerModel(name, unitKeywords),
        recruitmentBuildingType: recruitmentBuildingType(unitKeywords),
        ...costs,
        notes: `${isAlliedUnit ? "Unidad aliada" : "Unidad"} importada desde 40kPoints.txt (${section}).`,
        isAvailable: false
      });
    }
  }

  return { units, skippedHeaders };
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
  return "Hoja de datos";
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

function computeCosts(points, unitKeywords, category) {
  const profile = costProfile(unitKeywords, category);
  const minerals = Math.floor((points * profile.minerals) / 2);
  const honor = Math.floor((points * profile.honor) / 5);
  const gold = Math.floor((points * profile.gold) / 5);
  const supply = points - minerals * 2 - honor * 5 - gold * 5;

  return {
    supplyCost: supply,
    mineralsCost: minerals,
    honorCost: honor,
    goldCost: gold,
    industrialMaterialCost: 0,
    uridiumCost: 0,
    technologyCost: 0
  };
}

function costProfile(unitKeywords, category) {
  if (unitKeywords.includes("Caracter") && unitKeywords.includes("Vehiculo")) {
    return { minerals: 0.45, honor: 0.3, gold: 0.1 };
  }
  if (unitKeywords.includes("Caracter")) {
    return { minerals: 0.25, honor: 0.35, gold: 0.15 };
  }
  if (unitKeywords.includes("Vehiculo")) {
    return { minerals: 0.7, honor: 0.1, gold: category === "Aliada" ? 0.1 : 0.05 };
  }
  if (unitKeywords.includes("Bestia")) {
    return { minerals: 0.15, honor: 0.3, gold: category === "Aliada" ? 0.05 : 0 };
  }
  if (unitKeywords.includes("Montado")) {
    return { minerals: 0.45, honor: 0.1, gold: category === "Aliada" ? 0.05 : 0 };
  }
  if (category === "Aliada") {
    return { minerals: 0.25, honor: 0.15, gold: 0.1 };
  }
  return { minerals: 0.25, honor: 0.1, gold: 0 };
}

function inferWoundsPerModel(name, unitKeywords) {
  const lower = name.toLowerCase();
  if (unitKeywords.includes("Vehiculo")) return lower.includes("knight") || lower.includes("baneblade") ? 24 : 10;
  if (unitKeywords.includes("Bestia")) return unitKeywords.includes("Caracter") ? 8 : 3;
  if (unitKeywords.includes("Montado")) return 3;
  if (unitKeywords.includes("Caracter")) return 5;
  if (/\b(terminator|gravis|ogryn|bullgryn|wraith)\b/.test(lower)) return 3;
  if (/\b(space marine|intercessor|plague|rubric|thousand sons)\b/.test(lower)) return 2;
  return 1;
}

function legacyUnitType(unitKeywords) {
  if (unitKeywords.includes("Caracter")) return "character";
  if (unitKeywords.includes("Vehiculo")) return "vehicle";
  if (unitKeywords.includes("Bestia")) return "beast";
  if (unitKeywords.includes("Montado")) return "mounted";
  return "infantry";
}

function recruitmentBuildingType(unitKeywords) {
  if (unitKeywords.includes("Caracter")) return "cuartel-mando";
  if (unitKeywords.includes("Vehiculo")) return "taller-guerra";
  if (unitKeywords.includes("Bestia")) return "nido-bestias";
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
      return `    (${sql(unit.slug)}, ${sql(unit.factionSlug)}, ${sql(unit.name)}, ${sql(unit.category)}, ${sql(unit.unitType)}, ${sqlArray(unit.unitKeywords)}, ${unit.points}, ${unit.defaultQuantity}, ${unit.woundsPerModel}, ${unit.supplyCost}, ${unit.mineralsCost}, 0, ${unit.honorCost}, ${unit.goldCost}, 0, 0, 0, 30, ${sql(unit.recruitmentBuildingType)}, ${sql(unit.notes)}, false, null, ${sql(unit.sourceSection)}, ${sql(unit.sourceFactionName)}, ${unit.isAlliedUnit})`;
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

function buildInitialUnitsSql(units) {
  const byFactionAndName = new Map(units.map((unit) => [`${unit.factionSlug}:${unit.name}`, unit]));
  const values = INITIAL_UNITS.map(([slug, factionSlug, templateName, systemSlug, status, level, rank, wounds]) => {
    const template = byFactionAndName.get(`${factionSlug}:${templateName}`);
    if (!template) {
      throw new Error(`No existe la plantilla inicial ${factionSlug}:${templateName}`);
    }
    return `    (${sql(slug)}, ${sql(factionSlug)}, ${sql(template.slug)}, ${sql(template.name)}, ${sql(template.category)}, ${sql(template.unitType)}, ${sqlArray(template.unitKeywords)}, ${template.points}, ${template.defaultQuantity}, ${template.defaultQuantity}, ${wounds}, ${level}, ${rank === null ? "null" : sql(rank)}, ${sql(systemSlug)}, ${sql(status)})`;
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
  const orders = MOVEMENT_ORDERS.map(([slug, factionSlug, , from, to]) =>
    `  (public.seed_uuid('movement_order', ${sql(slug)}), public.seed_uuid('faction', ${sql(factionSlug)}), public.seed_uuid('system', ${sql(from)}), public.seed_uuid('system', ${sql(to)}), 1, now() - interval '10 seconds', now() + interval '30 seconds', 'moving', array[public.seed_uuid('system', ${sql(from)}), public.seed_uuid('system', ${sql(to)})]::uuid[], 1, 30)`
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

  if (unitsStart === -1 || relicStart === -1 || movementStart === -1 || tradeStart === -1) {
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

  const withUnits = `${seed.slice(0, unitsStart)}${unitsBlock}${seed.slice(relicStart, movementStart)}${movementBlock}${seed.slice(tradeStart)}`;
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
    recruitmentTimeSeconds: 30,
    recruitmentBuildingType: unit.recruitmentBuildingType,
    notes: unit.notes,
    isAvailable: false,
    requiredTechnologyNodeId: null,
    sourceSection: unit.sourceSection,
    sourceFactionName: unit.sourceFactionName,
    isAlliedUnit: unit.isAlliedUnit
  }));

  const unitByKey = new Map(units.map((unit) => [`${unit.factionSlug}:${unit.name}`, unit]));
  const initialUnits = INITIAL_UNITS.map(([slug, factionSlug, templateName, systemSlug, status, level, , wounds]) => {
    const template = unitByKey.get(`${factionSlug}:${templateName}`);
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
      points: template.points,
      quantity: template.defaultQuantity,
      startingQuantity: template.defaultQuantity,
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
  for (const unit of catalog.units) {
    byFaction.set(unit.sourceFactionName, (byFaction.get(unit.sourceFactionName) ?? 0) + 1);
  }

  const lines = [
    "# Informe de importacion de unidades 40K",
    "",
    "Generado por `npm run units:generate` desde `40kPoints.txt`.",
    "",
    `- Hojas de unidad importadas: ${catalog.units.length}.`,
    `- Cabeceras/totales omitidos: ${catalog.skippedHeaders.length}.`,
    "- Material Industrial y Uridium: siempre 0 en costes de unidades.",
    "- Disponibilidad inicial: todas las plantillas importadas quedan bloqueadas (`is_available = false`).",
    "",
    "## Unidades por faccion",
    "",
    ...[...byFaction.entries()].map(([name, count]) => `- ${name}: ${count}`),
    "",
    "## Cabeceras omitidas",
    "",
    ...catalog.skippedHeaders.map((line) => `- ${line}`)
  ];

  return `${lines.join("\n")}\n`;
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

main();
