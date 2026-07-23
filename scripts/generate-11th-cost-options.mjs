import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

const SOURCE_PATH = "data/11th40kPoints.txt";
const OUTPUT_PATH = "data/11th-unit-cost-options.json";
const REPORT_PATH = "docs/generated/11th-unit-cost-options-report.md";
const SEED_PATH = "supabase/seed.sql";
const MFM_BASE_URL = "https://mfm.warhammer-community.com/en";
const SEED_BLOCK_START = "-- BEGIN GENERATED 11TH UNIT COST OPTIONS";
const SEED_BLOCK_END = "-- END GENERATED 11TH UNIT COST OPTIONS";

const FACTION_MAP = {
  "Xenos - Necrons": {
    slug: "necrones",
    name: "Necrones",
    mfmSlug: "necrons"
  },
  "Chaos - Chaos Daemons": {
    slug: "legiones-daemonicas",
    name: "Legiones Daemonicas",
    mfmSlug: "chaos-daemons"
  },
  "Imperium - Agents of the Imperium": {
    slug: "agentes-imperium",
    name: "Agentes del Imperium",
    mfmSlug: "imperial-agents"
  },
  "Xenos - Aeldari": {
    slug: "aeldari",
    name: "Aeldari",
    mfmSlug: "aeldari"
  },
  "Xenos - Genestealer Cults": {
    slug: "cultos-genestealer",
    name: "Cultos Genestealer",
    mfmSlug: "genestealer-cults"
  },
  "Imperium - Adeptus Astartes - Space Marines": {
    slug: "space-marines",
    name: "Space Marines",
    mfmSlug: "space-marines"
  },
  "Imperium - Adeptus Custodes": {
    slug: "adeptus-custodes",
    name: "Adeptus Custodes",
    mfmSlug: "adeptus-custodes"
  }
};

const NAME_ALIASES = new Map([
  ["necrones:transcendent ctan", "transcendent ctan"],
  ["necrones:ctan shard of the deceiver", "ctan shard of the deceiver"],
  ["necrones:ctan shard of the nightbringer", "ctan shard of the nightbringer"],
  ["necrones:ctan shard of the void dragon", "ctan shard of the void dragon"],
  ["aeldari:vypers", "vyper"],
  ["space-marines:ancient in terminator armor", "ancient in terminator armour"]
]);

const SOURCE_NOTE =
  "MFM oficial 11th edition. No se usa BSData/wh40k-10e como fuente de puntos, tamanos ni opciones.";

async function main() {
  const fetchedAt = new Date().toISOString();
  const providedUnits = parseProvidedCatalog(readFileSync(SOURCE_PATH, "utf8"));
  const factionGroups = groupBy(providedUnits, (unit) => unit.factionSlug);
  const primaryMfmByFaction = new Map();
  const mfmSourcesBySlug = new Map();

  for (const faction of Object.values(FACTION_MAP)) {
    if (!factionGroups.has(faction.slug)) {
      continue;
    }
    const source = await loadMfmSource(mfmSourcesBySlug, faction.mfmSlug, faction.name);
    primaryMfmByFaction.set(faction.slug, source);
  }

  for (const slug of await fetchMfmIndexSlugs()) {
    await loadMfmSource(mfmSourcesBySlug, slug, toDisplayName(slug.replace(/-/g, " ")));
  }

  const globalUnitsByName = buildGlobalMfmIndex(mfmSourcesBySlug);
  const units = [];
  const unmatched = [];
  const conflicts = [];

  for (const provided of providedUnits) {
    const primaryMfm = primaryMfmByFaction.get(provided.factionSlug);
    const matchKey = resolveMatchKey(provided);
    const primaryMatch = primaryMfm?.unitsByName.get(matchKey);
    const fallbackMatch = primaryMatch
      ? null
      : resolveGlobalMfmMatch(globalUnitsByName, matchKey);
    const mfmUnit = primaryMatch?.unit ?? fallbackMatch?.unit ?? null;
    const mfmSource = primaryMatch?.source ?? fallbackMatch?.source ?? primaryMfm;
    const entry = buildUnitEntry({ provided, mfmUnit, mfmSource, fetchedAt });
    units.push(entry);

    if (!mfmUnit) {
      unmatched.push(entry);
      continue;
    }

    const providedCost = findCostForProvidedModels(entry.modelOptions, provided.models);
    if (providedCost && providedCost.points !== provided.points) {
      conflicts.push({
        factionName: provided.factionName,
        name: provided.name,
        providedModels: provided.models,
        providedPoints: provided.points,
        mfmPoints: providedCost.points
      });
    }
  }

  const variableUnits = units.filter(
    (unit) =>
      unit.modelOptions.length > 1 ||
      unit.wargearOptions.length > 0 ||
      unit.rosterModifiers.length > 0
  );

  const output = {
    schemaVersion: 1,
    source: {
      kind: "mfm",
      url: MFM_BASE_URL,
      fetchedAt,
      note: SOURCE_NOTE
    },
    summary: {
      providedUnits: providedUnits.length,
      matchedUnits: units.length - unmatched.length,
      unmatchedUnits: unmatched.length,
      variableUnits: variableUnits.length,
      conflicts: conflicts.length
    },
    units
  };

  writeText(OUTPUT_PATH, `${JSON.stringify(output, null, 2)}\n`);
  writeText(
    REPORT_PATH,
    buildReport({
      output,
      variableUnits,
      unmatched,
      conflicts,
      primaryMfmByFaction,
      mfmSourcesBySlug
    })
  );
  updateSeedCostOptions(units);

  console.log(`Opciones MFM generadas: ${OUTPUT_PATH}`);
  console.log(`Informe generado: ${REPORT_PATH}`);
  console.log(`Seed actualizado con opciones MFM: ${SEED_PATH}`);
  console.log(`Unidades base: ${providedUnits.length}`);
  console.log(`Unidades cruzadas con MFM: ${output.summary.matchedUnits}`);
  console.log(`Unidades variables/opciones: ${variableUnits.length}`);
  console.log(`Conflictos con el TXT aportado: ${conflicts.length}`);
  console.log(`Unidades no encontradas: ${unmatched.length}`);
}

function parseProvidedCatalog(text) {
  const units = [];
  let currentFaction = null;

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    const factionMatch = line.match(/^\+ FACTION KEYWORD:\s*(.+)$/);
    if (factionMatch) {
      const sourceName = factionMatch[1].trim();
      const faction = FACTION_MAP[sourceName];
      if (!faction) {
        throw new Error(`Faccion no configurada para MFM: ${sourceName}`);
      }
      currentFaction = { sourceName, ...faction };
      continue;
    }

    if (!currentFaction) {
      continue;
    }

    const unitMatch = line.match(/^(?:Char\d+:\s*)?(\d+)x\s+(.+?)\s+\((\d+)\s*pts\)/i);
    if (!unitMatch) {
      continue;
    }

    const models = Number(unitMatch[1]);
    const rawName = unitMatch[2].trim();
    const points = Number(unitMatch[3]);
    const name = rawName.replace(/\s*\[[^\]]+\]\s*/g, " ").replace(/\s+/g, " ").trim();

    units.push({
      factionSlug: currentFaction.slug,
      factionName: currentFaction.name,
      factionSourceName: currentFaction.sourceName,
      unitSlug: slugify(name),
      name,
      rawName,
      models,
      points
    });
  }

  return units;
}

async function fetchMfmIndexSlugs() {
  const html = await fetchText(`${MFM_BASE_URL}/`);
  return [
    ...new Set(
      [...html.matchAll(/href="\/en\/([a-z0-9-]+)"/g)]
        .map((match) => match[1])
        .filter((slug) => slug !== "")
    )
  ].sort();
}

async function loadMfmSource(sourcesBySlug, mfmSlug, name) {
  if (sourcesBySlug.has(mfmSlug)) {
    return sourcesBySlug.get(mfmSlug);
  }

  const url = `${MFM_BASE_URL}/${mfmSlug}`;
  const html = await fetchText(url);
  const parsed = parseMfmFactionPage(html);
  const source = {
    slug: mfmSlug,
    name,
    url,
    units: parsed.units,
    unitsByName: new Map(),
    unitCount: parsed.units.length
  };
  source.unitsByName = new Map(
    source.units.map((unit) => [unit.normalizedName, { unit, source }])
  );
  sourcesBySlug.set(mfmSlug, source);
  return source;
}

function buildGlobalMfmIndex(sourcesBySlug) {
  const index = new Map();
  for (const source of sourcesBySlug.values()) {
    for (const unit of source.units) {
      if (!index.has(unit.normalizedName)) {
        index.set(unit.normalizedName, []);
      }
      index.get(unit.normalizedName).push({ unit, source });
    }
  }
  return index;
}

function resolveGlobalMfmMatch(globalUnitsByName, matchKey) {
  const matches = globalUnitsByName.get(matchKey) ?? [];
  if (matches.length === 0) {
    return null;
  }
  if (matches.length === 1) {
    return matches[0];
  }
  const nonChapterSpecific = matches.find(
    (match) =>
      ![
        "black-templars",
        "blood-angels",
        "dark-angels",
        "death-guard",
        "space-wolves",
        "thousand-sons",
        "world-eaters"
      ].includes(match.source.slug)
  );
  return nonChapterSpecific ?? matches[0];
}

function parseMfmFactionPage(html) {
  const replacements = new Map();
  const hiddenRegex =
    /<div hidden id="S:([^"]+)">([\s\S]*?)<\/div><script>\$RS\("S:\1","P:([^"]+)"\)<\/script>/g;

  for (const match of html.matchAll(hiddenRegex)) {
    replacements.set(match[3], match[2]);
  }

  const resolveTemplates = (fragment, depth = 0) => {
    if (depth > 12) {
      return fragment;
    }
    return fragment.replace(/<template id="P:([^"]+)"><\/template>/g, (_, id) =>
      resolveTemplates(replacements.get(id) ?? "", depth + 1)
    );
  };

  const resolvedHtml = resolveTemplates(html);
  const units = [];
  const seen = new Set();

  for (const block of extractUnitBlocks(resolvedHtml)) {
    const unit = parseMfmUnitFragment(block);
    if (!unit || seen.has(unit.normalizedName)) {
      continue;
    }
    seen.add(unit.normalizedName);
    units.push(unit);
  }

  return {
    units,
    unitsByName: new Map(units.map((unit) => [unit.normalizedName, unit]))
  };
}

function extractUnitBlocks(html) {
  const blocks = [];
  const marker = '<div class="flex flex-col space-y-1 m-1 print:break-inside-avoid-page">';
  let searchFrom = 0;

  while (true) {
    const start = html.indexOf(marker, searchFrom);
    if (start === -1) {
      break;
    }
    const end = findMatchingDivEnd(html, start);
    if (end === -1) {
      break;
    }
    blocks.push(html.slice(start, end));
    searchFrom = end;
  }

  return blocks;
}

function parseMfmUnitFragment(fragment) {
  const titleMatch =
    fragment.match(/<span[^>]*class="[^"]*text-xl[^"]*"[^>]*>([\s\S]*?)<\/span>/) ??
    fragment.match(/font-bold text-xl[^>]*>([\s\S]*?)<\/div>/);
  if (!titleMatch) {
    return null;
  }

  const name = cleanText(titleMatch[1]);
  const sections = parseMfmSections(fragment);
  const modelOptions = [];
  const wargearOptions = [];

  for (const section of sections) {
    if (section.header.includes("WARGEAR OPTIONS")) {
      for (const row of section.rows) {
        wargearOptions.push({
          slug: slugify(row.label.replace(/^per\s+/i, "")),
          name: toDisplayName(row.label.replace(/^per\s+/i, "")),
          points: row.points,
          pricing: /^per\s+/i.test(row.label) ? "per_option" : "flat",
          source: "mfm",
          change: row.change
        });
      }
      continue;
    }

    if (!/UNITS?\s+COST/.test(section.header)) {
      continue;
    }

    const copyRange = parseCopyRange(section.header);
    for (const row of section.rows) {
      const models = parseModelLabel(row.label);
      if (!models) {
        continue;
      }
      modelOptions.push({
        models: models.maxModels,
        minModels: models.minModels,
        maxModels: models.maxModels,
        label: row.label,
        points: row.points,
        copyRange,
        source: "mfm",
        change: row.change
      });
    }
  }

  return {
    name,
    normalizedName: normalizeName(name),
    modelOptions,
    wargearOptions,
    rosterModifiers: buildRosterModifiers(modelOptions)
  };
}

function parseMfmSections(fragment) {
  const sections = [];

  for (const block of extractSectionBlocks(fragment)) {
    const header = extractSectionHeader(block);
    if (!header) {
      continue;
    }
    const rows = [];
    for (const rowMatch of block.matchAll(/<li><span>([\s\S]*?)<\/span>([\s\S]*?)<\/li>/g)) {
      const label = cleanText(rowMatch[1]);
      const valueText = cleanText(rowMatch[2]);
      const pointsMatch = valueText.match(/([\d,]+)\s*pts/i);
      if (!pointsMatch) {
        continue;
      }
      const changeMatch = valueText.match(/([▲▼])\s*\(([+-]?\d+)\)/);
      rows.push({
        label,
        points: Number(pointsMatch[1].replace(/,/g, "")),
        change: changeMatch
          ? {
              direction: changeMatch[1] === "▲" ? "up" : "down",
              amount: Number(changeMatch[2])
            }
          : null
      });
    }

    if (rows.length > 0) {
      sections.push({ header, rows });
    }
  }

  return sections;
}

function extractSectionBlocks(fragment) {
  const blocks = [];
  const marker = '<div class="space-y-1">';
  let searchFrom = 0;

  while (true) {
    const start = fragment.indexOf(marker, searchFrom);
    if (start === -1) {
      break;
    }
    const end = findMatchingDivEnd(fragment, start);
    if (end === -1) {
      break;
    }
    blocks.push(fragment.slice(start, end));
    searchFrom = end;
  }

  return blocks;
}

function extractSectionHeader(block) {
  const outerEnd = block.indexOf(">");
  const headerStart = block.indexOf("<div", outerEnd + 1);
  if (headerStart === -1) {
    return null;
  }
  const headerEnd = findMatchingDivEnd(block, headerStart);
  if (headerEnd === -1) {
    return null;
  }
  return cleanText(block.slice(headerStart, headerEnd)).toUpperCase();
}

function findMatchingDivEnd(html, startIndex) {
  const tagRegex = /<\/?div\b[^>]*>/g;
  tagRegex.lastIndex = startIndex;
  let depth = 0;

  let match;
  while ((match = tagRegex.exec(html)) !== null) {
    const tag = match[0];
    if (tag.startsWith("</")) {
      depth -= 1;
      if (depth === 0) {
        return match.index + tag.length;
      }
    } else {
      depth += 1;
    }
  }

  return -1;
}

function parseCopyRange(header) {
  if (header === "YOUR UNIT COSTS") {
    return { from: 1, to: null, label: "default" };
  }

  const single = header.match(/^YOUR\s+(\d+)(?:ST|ND|RD|TH)\s+UNIT COSTS?$/);
  if (single) {
    const value = Number(single[1]);
    return { from: value, to: value, label: `${value}` };
  }

  const range = header.match(
    /^YOUR\s+(\d+)(?:ST|ND|RD|TH)\s+TO\s+(\d+)(?:ST|ND|RD|TH)\s+UNITS?\s+COSTS?$/
  );
  if (range) {
    return { from: Number(range[1]), to: Number(range[2]), label: `${range[1]}-${range[2]}` };
  }

  const plus = header.match(/^YOUR\s+(\d+)(?:ST|ND|RD|TH)\s*\+\s+UNITS?\s+COSTS?$/);
  if (plus) {
    return { from: Number(plus[1]), to: null, label: `${plus[1]}+` };
  }

  return { from: 1, to: null, label: header.toLowerCase() };
}

function parseModelLabel(label) {
  const range = label.match(/(\d+)\s*-\s*(\d+)\s*models?/i);
  if (range) {
    return { minModels: Number(range[1]), maxModels: Number(range[2]) };
  }

  const single = label.match(/(\d+)\s*models?/i);
  if (single) {
    const value = Number(single[1]);
    return { minModels: value, maxModels: value };
  }

  return null;
}

function buildRosterModifiers(modelOptions) {
  const modifiers = [];
  const baseOptions = modelOptions.filter((option) => option.copyRange.from === 1);
  const thresholdOptions = modelOptions.filter((option) => option.copyRange.from > 1);

  for (const option of thresholdOptions) {
    const base = baseOptions.find(
      (candidate) =>
        candidate.minModels === option.minModels && candidate.maxModels === option.maxModels
    );
    if (!base) {
      continue;
    }
    const delta = option.points - base.points;
    if (delta === 0) {
      continue;
    }
    modifiers.push({
      type: delta > 0 ? "nth_copy_surcharge" : "nth_copy_discount",
      threshold: option.copyRange.from,
      points: delta,
      resultingPoints: option.points,
      minModels: option.minModels,
      maxModels: option.maxModels,
      source: "mfm"
    });
  }

  return modifiers;
}

function buildUnitEntry({ provided, mfmUnit, mfmSource, fetchedAt }) {
  return {
    factionSlug: provided.factionSlug,
    factionName: provided.factionName,
    unitSlug: provided.unitSlug,
    name: provided.name,
    mfmName: mfmUnit?.name ?? null,
    provided: {
      models: provided.models,
      points: provided.points
    },
    modelOptions: mfmUnit?.modelOptions ?? [],
    wargearOptions: mfmUnit?.wargearOptions ?? [],
    rosterModifiers: mfmUnit?.rosterModifiers ?? [],
    matchStatus: mfmUnit ? "matched" : "unmatched",
    source: {
      kind: "mfm",
      url: mfmSource?.url ?? null,
      pageSlug: mfmSource?.slug ?? null,
      fetchedAt
    }
  };
}

function findCostForProvidedModels(modelOptions, models) {
  const baseOptions = modelOptions.filter((option) => option.copyRange.from === 1);
  return (
    baseOptions.find((option) => option.models === models) ??
    baseOptions.find((option) => option.minModels <= models && option.maxModels >= models) ??
    null
  );
}

function resolveMatchKey(unit) {
  const normalized = normalizeName(unit.name);
  return NAME_ALIASES.get(`${unit.factionSlug}:${normalized}`) ?? normalized;
}

async function fetchText(url) {
  const response = await fetch(url, {
    headers: {
      accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "user-agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126 Safari/537.36"
    },
    redirect: "follow"
  });
  if (!response.ok) {
    throw new Error(`No se pudo descargar ${url}: ${response.status} ${response.statusText}`);
  }
  return response.text();
}

function buildReport({
  output,
  variableUnits,
  unmatched,
  conflicts,
  primaryMfmByFaction,
  mfmSourcesBySlug
}) {
  const lines = [];
  lines.push("# Informe de opciones y puntos variables 11th");
  lines.push("");
  lines.push(`Generado: ${output.source.fetchedAt}`);
  lines.push(`Fuente primaria: ${output.source.url}`);
  lines.push("");
  lines.push(`> ${SOURCE_NOTE}`);
  lines.push("");
  lines.push("## Resumen");
  lines.push("");
  lines.push(`- Unidades del TXT base: ${output.summary.providedUnits}`);
  lines.push(`- Unidades cruzadas con MFM: ${output.summary.matchedUnits}`);
  lines.push(`- Unidades con tamanos/opciones/thresholds: ${output.summary.variableUnits}`);
  lines.push(`- Conflictos de puntos con el TXT base: ${output.summary.conflicts}`);
  lines.push(`- Unidades no encontradas: ${output.summary.unmatchedUnits}`);
  lines.push("");
  lines.push("## Fuentes MFM consultadas");
  lines.push("");
  lines.push(`- Paginas oficiales consultadas: ${mfmSourcesBySlug.size}`);
  lines.push("- Paginas primarias de las facciones del rol:");
  for (const { name, url, unitCount } of primaryMfmByFaction.values()) {
    lines.push(`  - ${name}: ${url} (${unitCount} entradas MFM)`);
  }
  lines.push("");
  lines.push("## Ejemplos de validacion");
  lines.push("");
  appendExample(lines, output.units, "adeptus-custodes", "Caladius Grav-tank");
  appendExample(lines, output.units, "adeptus-custodes", "Custodian Wardens");
  lines.push("");
  lines.push("## Unidades enriquecidas");
  lines.push("");
  lines.push("| Faccion | Unidad | Base aportada | Costes MFM | Wargear | Thresholds |");
  lines.push("|---|---|---:|---|---|---|");
  for (const unit of variableUnits) {
    lines.push(
      `| ${unit.factionName} | ${escapeMarkdown(unit.name)} | ${unit.provided.models} modelos / ${unit.provided.points} pts | ${summarizeModelOptions(unit.modelOptions)} | ${summarizeWargear(unit.wargearOptions)} | ${summarizeModifiers(unit.rosterModifiers)} |`
    );
  }
  lines.push("");
  lines.push("## Conflictos con el TXT aportado");
  lines.push("");
  if (conflicts.length === 0) {
    lines.push("- Ninguno.");
  } else {
    lines.push("| Faccion | Unidad | TXT | MFM |");
    lines.push("|---|---|---:|---:|");
    for (const conflict of conflicts) {
      lines.push(
        `| ${conflict.factionName} | ${escapeMarkdown(conflict.name)} | ${conflict.providedModels} modelos / ${conflict.providedPoints} pts | ${conflict.mfmPoints} pts |`
      );
    }
  }
  lines.push("");
  lines.push("## No encontradas");
  lines.push("");
  if (unmatched.length === 0) {
    lines.push("- Ninguna.");
  } else {
    for (const unit of unmatched) {
      lines.push(`- ${unit.factionName}: ${unit.name}`);
    }
  }
  lines.push("");

  return `${lines.join("\n")}\n`;
}

function updateSeedCostOptions(units) {
  const seed = readFileSync(SEED_PATH, "utf8");
  const block = buildSeedCostOptionsBlock(units);
  const existingStart = seed.indexOf(SEED_BLOCK_START);
  const existingEnd = seed.indexOf(SEED_BLOCK_END);

  if (existingStart !== -1 && existingEnd !== -1 && existingEnd > existingStart) {
    const afterExistingEnd = seed.indexOf("\n", existingEnd);
    const replaceEnd = afterExistingEnd === -1 ? seed.length : afterExistingEnd + 1;
    writeText(SEED_PATH, `${seed.slice(0, existingStart)}${block}${seed.slice(replaceEnd)}`);
    return;
  }

  const unitCatalogEnd = seed.indexOf("-- END GENERATED 40K UNIT CATALOG");
  if (unitCatalogEnd === -1) {
    throw new Error("No se encontro -- END GENERATED 40K UNIT CATALOG en supabase/seed.sql.");
  }
  const insertAt = seed.indexOf("\n", unitCatalogEnd);
  if (insertAt === -1) {
    throw new Error("No se pudo insertar el bloque de opciones MFM en supabase/seed.sql.");
  }

  writeText(SEED_PATH, `${seed.slice(0, insertAt + 1)}${block}${seed.slice(insertAt + 1)}`);
}

function buildSeedCostOptionsBlock(units) {
  const modelRows = [];
  const wargearRows = [];

  for (const unit of units) {
    if (unit.matchStatus !== "matched") {
      continue;
    }

    const templateSlug = getUnitTemplateSlug(unit);
    for (const option of unit.modelOptions) {
      modelRows.push({
        templateSlug,
        slug: getModelOptionSlug(option),
        label: option.label,
        models: option.models,
        minModels: option.minModels,
        maxModels: option.maxModels,
        points: option.points,
        copyFrom: option.copyRange.from,
        copyTo: option.copyRange.to,
        source: option.source,
        pointsChangeDirection: option.change?.direction ?? null,
        pointsChangeAmount: option.change?.amount ?? null
      });
    }

    for (const option of unit.wargearOptions) {
      wargearRows.push({
        templateSlug,
        slug: option.slug,
        name: option.name,
        points: option.points,
        pricing: option.pricing,
        source: option.source,
        pointsChangeDirection: option.change?.direction ?? null,
        pointsChangeAmount: option.change?.amount ?? null
      });
    }
  }

  return [
    `${SEED_BLOCK_START}\n`,
    buildModelOptionsSql(modelRows),
    "",
    buildWargearOptionsSql(wargearRows),
    `${SEED_BLOCK_END}\n`
  ].join("\n");
}

function buildModelOptionsSql(rows) {
  if (rows.length === 0) {
    return "-- No hay opciones de tamano MFM generadas.";
  }

  const values = rows
    .map(
      (row) =>
        `    (${sql(row.templateSlug)}, ${sql(row.slug)}, ${sql(row.label)}, ${row.models}, ${row.minModels}, ${row.maxModels}, ${row.points}, ${row.copyFrom}, ${row.copyTo === null ? "null" : row.copyTo}, ${sql(row.source)}, ${sql(row.pointsChangeDirection)}, ${row.pointsChangeAmount === null ? "null" : row.pointsChangeAmount})`
    )
    .join(",\n");

  return `insert into public.unit_template_model_options (
  id, unit_template_id, slug, label, models, min_models, max_models, points, copy_from, copy_to, source, points_change_direction, points_change_amount
)
select
  public.seed_uuid('unit_template_model_option', data.template_slug || ':' || data.slug),
  unit_templates.id,
  data.slug,
  data.label,
  data.models,
  data.min_models,
  data.max_models,
  data.points,
  data.copy_from,
  data.copy_to::integer,
  data.source,
  data.points_change_direction::text,
  data.points_change_amount::integer
from (
  values
${values}
) as data(template_slug, slug, label, models, min_models, max_models, points, copy_from, copy_to, source, points_change_direction, points_change_amount)
join public.unit_templates on unit_templates.slug = data.template_slug
on conflict (unit_template_id, slug) do update
set label = excluded.label,
    models = excluded.models,
    min_models = excluded.min_models,
    max_models = excluded.max_models,
    points = excluded.points,
    copy_from = excluded.copy_from,
    copy_to = excluded.copy_to,
    source = excluded.source,
    points_change_direction = excluded.points_change_direction,
    points_change_amount = excluded.points_change_amount,
    updated_at = now();`;
}

function buildWargearOptionsSql(rows) {
  if (rows.length === 0) {
    return "-- No hay opciones de wargear MFM generadas.";
  }

  const values = rows
    .map(
      (row) =>
        `    (${sql(row.templateSlug)}, ${sql(row.slug)}, ${sql(row.name)}, ${row.points}, ${sql(row.pricing)}, ${sql(row.source)}, ${sql(row.pointsChangeDirection)}, ${row.pointsChangeAmount === null ? "null" : row.pointsChangeAmount})`
    )
    .join(",\n");

  return `insert into public.unit_template_wargear_options (
  id, unit_template_id, slug, name, points, pricing, source, points_change_direction, points_change_amount
)
select
  public.seed_uuid('unit_template_wargear_option', data.template_slug || ':' || data.slug),
  unit_templates.id,
  data.slug,
  data.name,
  data.points,
  data.pricing,
  data.source,
  data.points_change_direction::text,
  data.points_change_amount::integer
from (
  values
${values}
) as data(template_slug, slug, name, points, pricing, source, points_change_direction, points_change_amount)
join public.unit_templates on unit_templates.slug = data.template_slug
on conflict (unit_template_id, slug) do update
set name = excluded.name,
    points = excluded.points,
    pricing = excluded.pricing,
    source = excluded.source,
    points_change_direction = excluded.points_change_direction,
    points_change_amount = excluded.points_change_amount,
    updated_at = now();`;
}

function getUnitTemplateSlug(unit) {
  return `unit-${unit.factionSlug}-${unit.unitSlug}`;
}

function getModelOptionSlug(option) {
  const copyTo = option.copyRange.to === null ? "plus" : option.copyRange.to;
  return slugify(
    `models-${option.minModels}-${option.maxModels}-copy-${option.copyRange.from}-${copyTo}`
  );
}

function appendExample(lines, units, factionSlug, name) {
  const unit = units.find(
    (candidate) => candidate.factionSlug === factionSlug && candidate.name === name
  );
  if (!unit) {
    lines.push(`- ${name}: no existe en el TXT base.`);
    return;
  }
  lines.push(
    `- ${unit.name}: ${summarizeModelOptions(unit.modelOptions)}; wargear ${summarizeWargear(
      unit.wargearOptions
    )}; thresholds ${summarizeModifiers(unit.rosterModifiers)}.`
  );
}

function summarizeModelOptions(options) {
  if (options.length === 0) {
    return "sin datos";
  }
  return options
    .map((option) => {
      const models =
        option.minModels === option.maxModels
          ? `${option.models}`
          : `${option.minModels}-${option.maxModels}`;
      const copy =
        option.copyRange.label === "default" || option.copyRange.from === 1
          ? ""
          : ` ${option.copyRange.label}`;
      return `${models}m${copy}: ${option.points}`;
    })
    .join(", ");
}

function summarizeWargear(options) {
  if (options.length === 0) {
    return "-";
  }
  return options.map((option) => `${option.name}: +${option.points}`).join(", ");
}

function summarizeModifiers(modifiers) {
  if (modifiers.length === 0) {
    return "-";
  }
  return modifiers
    .map((modifier) => {
      const models =
        modifier.minModels === modifier.maxModels
          ? `${modifier.maxModels}m`
          : `${modifier.minModels}-${modifier.maxModels}m`;
      return `${modifier.threshold}+ ${models}: ${modifier.points > 0 ? "+" : ""}${
        modifier.points
      }`;
    })
    .join(", ");
}

function writeText(path, content) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content, "utf8");
}

function sql(value) {
  if (value === null || value === undefined) {
    return "null";
  }

  return `'${String(value).replace(/'/g, "''")}'`;
}

function groupBy(items, getKey) {
  const groups = new Map();
  for (const item of items) {
    const key = getKey(item);
    if (!groups.has(key)) {
      groups.set(key, []);
    }
    groups.get(key).push(item);
  }
  return groups;
}

function cleanText(value) {
  return decodeHtml(value.replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function decodeHtml(value) {
  return value
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&#x27;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&rsquo;/g, "’")
    .replace(/&ldquo;/g, "“")
    .replace(/&rdquo;/g, "”");
}

function normalizeName(value) {
  return decodeHtml(value)
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\[[^\]]+\]/g, " ")
    .replace(/[’‘`]/g, "'")
    .replace(/c['’]tan/gi, "ctan")
    .replace(/æ/gi, "ae")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\bthe\b/g, "the")
    .trim()
    .replace(/\s+/g, " ");
}

function slugify(value) {
  return normalizeName(value).replace(/\s+/g, "-");
}

function toDisplayName(value) {
  return cleanText(value)
    .toLowerCase()
    .replace(/\b\w/g, (match) => match.toUpperCase())
    .replace(/\bCtan\b/g, "C'tan");
}

function escapeMarkdown(value) {
  return String(value).replace(/\|/g, "\\|");
}

await main();
