import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { scaleCostsFromTemplate } from "./lib/campaign-balance.mjs";

const ROOT = process.cwd();
const OUTPUT_DIR = path.join(ROOT, "docs", "generated", "unit-costs");
const TEMPLATE_PATH = path.join(ROOT, "src", "mocks", "generated", "40k-unit-templates.ts");
const OPTIONS_PATH = path.join(ROOT, "data", "11th-unit-cost-options.json");

const FACTIONS = [
  { slug: "adeptus-custodes", name: "Adeptus Custodes", file: "costes-adeptus-custodes.pdf", color: "#d4af37" },
  { slug: "space-marines", name: "Sombra del Emperador", subtitle: "Space Marines", file: "costes-sombra-del-emperador.pdf", color: "#3b82f6" },
  { slug: "cultos-genestealer", name: "Cultos Genestealer", file: "costes-cultos-genestealer.pdf", color: "#c084fc" },
  { slug: "necrones", name: "Necrones", file: "costes-necrones.pdf", color: "#2dd4bf" },
  { slug: "legiones-daemonicas", name: "El Caos", file: "costes-el-caos.pdf", color: "#ef4444" }
];

const requestedFactionSlugs = new Set(process.argv.slice(2));
const factionsToGenerate = requestedFactionSlugs.size > 0
  ? FACTIONS.filter((faction) => requestedFactionSlugs.has(faction.slug))
  : FACTIONS;

const GROUPS = [
  "Personajes",
  "Infantería",
  "Unidades montadas",
  "Bestias",
  "Monstruos",
  "Vehículos",
  "Aeronaves",
  "Fortificaciones",
  "Otras unidades"
];

const RESOURCE_ICONS = {
  supply: dataUri(path.join(ROOT, "icons", "resources", "life_essense.png")),
  minerals: dataUri(path.join(ROOT, "icons", "resources", "mineral.png")),
  honor: dataUri(path.join(ROOT, "icons", "resources", "honor.png")),
  gold: dataUri(path.join(ROOT, "icons", "resources", "gold.png"))
};

const templates = parseExportedJsonArray(
  fs.readFileSync(TEMPLATE_PATH, "utf8"),
  "export const generated40kUnitTemplates = ",
  '] satisfies CampaignSnapshot["unitTemplates"]'
);
const costOptions = JSON.parse(fs.readFileSync(OPTIONS_PATH, "utf8"));
const optionsByTemplateId = new Map(
  costOptions.units.map((unit) => [`unit-${unit.factionSlug}-${unit.unitSlug}`, unit])
);
const browserPath = findBrowser();
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "rol40k-unit-costs-"));

fs.mkdirSync(OUTPUT_DIR, { recursive: true });

try {
  for (const faction of factionsToGenerate) {
    const factionTemplates = templates
      .filter((template) => template.factionId === faction.slug)
      .sort(compareUnits);
    const html = renderDocument(faction, factionTemplates, costOptions.source);
    const htmlPath = path.join(tempDir, `${faction.slug}.html`);
    const pdfPath = path.join(OUTPUT_DIR, faction.file);

    fs.writeFileSync(htmlPath, html, "utf8");
    printPdf(browserPath, htmlPath, pdfPath, tempDir);

    const stat = fs.statSync(pdfPath);
    if (stat.size < 10_000 || !hasPdfHeader(pdfPath)) {
      throw new Error(`El PDF generado no es valido: ${pdfPath}`);
    }

    console.log(`OK ${faction.name}: ${factionTemplates.length} unidades -> ${path.relative(ROOT, pdfPath)}`);
  }

  fs.writeFileSync(path.join(OUTPUT_DIR, "README.md"), renderIndex(), "utf8");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}

function renderDocument(faction, factionTemplates, source) {
  const grouped = new Map(GROUPS.map((group) => [group, []]));
  for (const template of factionTemplates) {
    grouped.get(groupForTemplate(template)).push(template);
  }

  const sections = GROUPS.map((group) => {
    const units = grouped.get(group);
    if (units.length === 0) return "";
    return `
      <section class="unit-group">
        <div class="section-heading">
          <div>
            <p class="section-kicker">Clase de unidad</p>
            <h2>${displayGroup(group)}</h2>
          </div>
          <span class="section-count">${units.length} ${units.length === 1 ? "unidad" : "unidades"}</span>
        </div>
        ${units.map((template) => renderUnit(template, optionsByTemplateId.get(template.id))).join("\n")}
      </section>`;
  }).join("\n");

  const groupSummary = GROUPS.map((group) => {
    const count = grouped.get(group).length;
    return count > 0 ? `<span><strong>${count}</strong> ${displayGroup(group)}</span>` : "";
  }).join("");

  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <title>Costes de unidades - ${escapeHtml(faction.name)}</title>
  <style>${styles(faction.color)}</style>
</head>
<body>
  <header class="cover">
    <div class="cover-mark"><span></span><i></i><span></span></div>
    <p class="eyebrow">Archivo de intendencia // Catálogo de reclutamiento</p>
    <h1>${escapeHtml(faction.name)}</h1>
    ${faction.subtitle ? `<p class="subtitle">${escapeHtml(faction.subtitle)}</p>` : ""}
    <p class="lead">Puntos oficiales, formaciones legales y costes de recursos de campaña.</p>
    <div class="cover-stats">
      <div><strong>${factionTemplates.length}</strong><span>hojas de unidad</span></div>
      <div><strong>${countVariants(factionTemplates)}</strong><span>configuraciones base</span></div>
      <div><strong>${countWargearOptions(factionTemplates)}</strong><span>opciones de equipo</span></div>
    </div>
    <div class="group-summary">${groupSummary}</div>
  </header>

  <aside class="rules">
    <div>
      <strong>Lectura del documento</strong>
      <p>Los costes mostrados son los de la primera copia de cada unidad. Repetir una hoja de datos no cambia su precio en la campaña.</p>
    </div>
    <div>
      <strong>Equivalencia de campaña</strong>
      <p>1 Suministro = 1 punto; 1 Mineral = 2 puntos; 1 Honor = 5 puntos; 1 Oro = 5 puntos.</p>
    </div>
    <div>
      <strong>Opciones pagadas</strong>
      <p>Las mejoras se suman a los puntos de la formación y el coste de recursos se recalcula sobre el total.</p>
    </div>
  </aside>

  <main>${sections}</main>

  <footer class="document-note">
    <p>Fuente de puntos: Munitorum Field Manual oficial (${formatSourceDate(source.fetchedAt)}). Costes internos generados con el balance actual de la campaña.</p>
    <p>Generado el ${new Intl.DateTimeFormat("es-ES", { dateStyle: "long" }).format(new Date())}.</p>
  </footer>
</body>
</html>`;
}

function renderUnit(template, optionData) {
  const modelChoices = getModelChoices(template, optionData);
  const paidOptions = optionData?.wargearOptions ?? [];
  const rows = [];

  for (const choice of modelChoices) {
    rows.push(renderVariantRow(template, choice.models, choice.points, "Formación base"));

    for (const option of paidOptions) {
      const maxQuantity = option.pricing === "per_option" ? Math.max(1, choice.models) : 1;
      for (let quantity = 1; quantity <= maxQuantity; quantity += 1) {
        const totalPoints = choice.points + option.points * quantity;
        rows.push(
          renderVariantRow(
            template,
            choice.models,
            totalPoints,
            `${quantity}x ${option.name}`,
            "paid"
          )
        );
      }
    }
  }

  const tags = [...new Set([...(template.unitKeywords ?? []), template.category])]
    .filter(Boolean)
    .map((tag) => `<span class="tag">${escapeHtml(displayKeyword(tag))}</span>`)
    .join("");
  const sourceState = optionData?.matchStatus === "matched" ? "MFM verificado" : "Coste base de campaña";

  return `<article class="unit-card">
    <div class="unit-heading">
      <div>
        <h3>${escapeHtml(cleanUnitName(template.name))}</h3>
        <div class="tags">${tags}</div>
      </div>
      <span class="source-state">${sourceState}</span>
    </div>
    <table>
      <thead>
        <tr>
          <th class="configuration">Version</th>
          <th>Miniaturas</th>
          <th>Puntos</th>
          ${resourceHeader("supply", "Suministro")}
          ${resourceHeader("minerals", "Mineral")}
          ${resourceHeader("honor", "Honor")}
          ${resourceHeader("gold", "Oro")}
        </tr>
      </thead>
      <tbody>${rows.join("")}</tbody>
    </table>
  </article>`;
}

function renderVariantRow(template, models, points, label, kind = "base") {
  const costs = computeRecruitmentCostsForPoints(template, points);
  if (!isValidRoundedPointCost(costs, points)) {
    throw new Error(`${template.name}: el coste de ${label} no equivale a ${points} puntos.`);
  }
  return `<tr class="${kind === "paid" ? "paid-option" : ""}">
    <td class="configuration">${kind === "paid" ? `<span class="option-mark">+</span>` : ""}${escapeHtml(label)}</td>
    <td>${models}</td>
    <td class="points">${points}</td>
    <td>${costCell(costs.supply)}</td>
    <td>${costCell(costs.minerals)}</td>
    <td>${costCell(costs.honor)}</td>
    <td>${costCell(costs.gold)}</td>
  </tr>`;
}

function getModelChoices(template, optionData) {
  const options = optionData?.modelOptions ?? [];
  if (options.length === 0) {
    return [{ models: template.defaultQuantity, points: template.points }];
  }

  const modelCounts = [...new Set(options.map((option) => Number(option.models)))].sort((a, b) => a - b);
  return modelCounts.map((models) => {
    const option = options
      .filter(
        (candidate) =>
          Number(candidate.minModels) <= models &&
          Number(candidate.maxModels) >= models &&
          Number(candidate.copyRange?.from ?? 1) <= 1 &&
          (candidate.copyRange?.to == null || Number(candidate.copyRange.to) >= 1)
      )
      .sort((left, right) =>
        Number(left.copyRange?.from ?? 1) - Number(right.copyRange?.from ?? 1) ||
        Number(left.maxModels) - Number(right.maxModels) ||
        Number(right.minModels) - Number(left.minModels)
      )[0];

    return { models, points: Number(option?.points ?? template.points) };
  });
}

function computeRecruitmentCostsForPoints(template, selectedPoints) {
  const scaled = scaleCostsFromTemplate(template, selectedPoints);
  return {
    supply: scaled.supply,
    minerals: scaled.minerals,
    honor: scaled.honor,
    gold: scaled.gold
  };
}

function campaignPointValue(costs) {
  return costs.supply + costs.minerals * 2 + costs.honor * 5 + costs.gold * 5;
}

function isValidRoundedPointCost(costs, points) {
  const value = campaignPointValue(costs);
  return value === points || (value === points + 1 && costs.supply === 0 && costs.minerals > 0);
}

function groupForTemplate(template) {
  const keywords = template.unitKeywords ?? [];
  if (keywords.includes("Caracter")) return "Personajes";
  if (keywords.includes("Aeronave")) return "Aeronaves";
  if (keywords.includes("Fortificacion")) return "Fortificaciones";
  if (keywords.includes("Vehiculo")) return "Vehículos";
  if (keywords.includes("Montado")) return "Unidades montadas";
  if (keywords.includes("Monstruo")) return "Monstruos";
  if (keywords.includes("Bestia")) return "Bestias";
  if (keywords.includes("Infanteria")) return "Infantería";
  return "Otras unidades";
}

function compareUnits(left, right) {
  const groupDifference = GROUPS.indexOf(groupForTemplate(left)) - GROUPS.indexOf(groupForTemplate(right));
  return groupDifference || left.name.localeCompare(right.name, "es", { sensitivity: "base" });
}

function countVariants(factionTemplates) {
  return factionTemplates.reduce(
    (total, template) => total + getModelChoices(template, optionsByTemplateId.get(template.id)).length,
    0
  );
}

function countWargearOptions(factionTemplates) {
  return factionTemplates.reduce(
    (total, template) => total + (optionsByTemplateId.get(template.id)?.wargearOptions?.length ?? 0),
    0
  );
}

function resourceHeader(resource, label) {
  return `<th><span class="resource-label"><img src="${RESOURCE_ICONS[resource]}" alt="" />${label}</span></th>`;
}

function costCell(value) {
  return value > 0 ? `<strong>${value}</strong>` : '<span class="zero">-</span>';
}

function displayGroup(group) {
  return group;
}

function displayKeyword(keyword) {
  return {
    Caracter: "Carácter",
    Infanteria: "Infantería",
    Vehiculo: "Vehículo",
    Fortificacion: "Fortificación",
    Linea: "Línea de batalla"
  }[keyword] ?? keyword;
}

function cleanUnitName(name) {
  return name.replace(/\s*\[Crucible\]\s*/gi, "").trim();
}

function formatSourceDate(value) {
  if (!value) return "fecha no disponible";
  return new Intl.DateTimeFormat("es-ES", { day: "2-digit", month: "2-digit", year: "numeric" }).format(new Date(value));
}

function renderIndex() {
  const links = FACTIONS
    .filter((faction) => fs.existsSync(path.join(OUTPUT_DIR, faction.file)))
    .map((faction) => `- [${faction.name}](./${faction.file})`)
    .join("\n");
  return `# Costes de unidades por facción\n\n${links}\n\nGenerar de nuevo con \`npm run docs:unit-costs\`.\n`;
}

function parseExportedJsonArray(source, marker, terminator) {
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) throw new Error(`No se encontro ${marker}`);
  const start = source.indexOf("[", markerIndex + marker.length);
  const endMarker = source.indexOf(terminator, start);
  if (start < 0 || endMarker < 0) throw new Error(`No se pudo leer el array de ${TEMPLATE_PATH}`);
  const end = source.lastIndexOf("]", endMarker + 1);
  return JSON.parse(source.slice(start, end + 1));
}

function dataUri(filePath) {
  const extension = path.extname(filePath).slice(1);
  return `data:image/${extension};base64,${fs.readFileSync(filePath).toString("base64")}`;
}

function findBrowser() {
  const candidates = [
    process.env.CHROME_PATH,
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium"
  ].filter(Boolean);
  const found = candidates.find((candidate) => fs.existsSync(candidate));
  if (!found) throw new Error("No se encontro Edge o Chrome para generar los PDF.");
  return found;
}

function printPdf(executable, htmlPath, pdfPath, profileRoot) {
  const profilePath = path.join(profileRoot, `browser-${path.basename(htmlPath, ".html")}`);
  const result = spawnSync(
    executable,
    [
      "--headless=new",
      "--disable-gpu",
      "--no-pdf-header-footer",
      `--user-data-dir=${profilePath}`,
      `--print-to-pdf=${pdfPath}`,
      pathToFileURL(htmlPath).href
    ],
    { encoding: "utf8", timeout: 120_000 }
  );

  if (result.error || result.status !== 0) {
    throw new Error(`No se pudo generar ${pdfPath}: ${result.error?.message ?? result.stderr ?? result.stdout}`);
  }
}

function hasPdfHeader(filePath) {
  const descriptor = fs.openSync(filePath, "r");
  const buffer = Buffer.alloc(5);
  fs.readSync(descriptor, buffer, 0, 5, 0);
  fs.closeSync(descriptor);
  return buffer.toString("ascii") === "%PDF-";
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function styles(accent) {
  return `
    @page { size: A4; margin: 10mm 9mm 12mm; }
    * { box-sizing: border-box; }
    html { background: #071019; }
    body {
      margin: 0;
      color: #e8edf3;
      background:
        radial-gradient(circle at 8% 2%, ${accent}22 0, transparent 24%),
        radial-gradient(circle at 92% 14%, #3b82f615 0, transparent 21%),
        #071019;
      font-family: "Segoe UI", Arial, sans-serif;
      font-size: 9.2px;
      line-height: 1.35;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .cover {
      min-height: 103mm;
      display: flex;
      flex-direction: column;
      justify-content: center;
      padding: 12mm 13mm;
      border: 1px solid ${accent}70;
      border-top: 4px solid ${accent};
      background: linear-gradient(135deg, ${accent}1f, #0d1823 48%, #09131d);
      position: relative;
      overflow: hidden;
    }
    .cover::after {
      content: "";
      position: absolute;
      width: 78mm;
      height: 78mm;
      right: -24mm;
      top: -28mm;
      border: 1px solid ${accent}42;
      border-radius: 50%;
      box-shadow: 0 0 0 8mm #ffffff04, 0 0 0 18mm ${accent}08;
    }
    .cover-mark { display: flex; align-items: center; gap: 5px; width: 46mm; margin-bottom: 7mm; }
    .cover-mark span { height: 1px; flex: 1; background: ${accent}; }
    .cover-mark i { width: 8px; height: 8px; transform: rotate(45deg); border: 1px solid ${accent}; background: #08111a; }
    .eyebrow, .section-kicker { margin: 0 0 2mm; color: ${accent}; font-size: 8px; font-weight: 700; letter-spacing: 1.8px; text-transform: uppercase; }
    h1 { margin: 0; max-width: 150mm; font-size: 31px; line-height: 1; letter-spacing: .3px; text-transform: uppercase; }
    .subtitle { margin: 2mm 0 0; color: #9fb0c1; font-size: 13px; }
    .lead { margin: 6mm 0 8mm; color: #b8c6d4; font-size: 12px; }
    .cover-stats { display: flex; gap: 7mm; }
    .cover-stats div { min-width: 30mm; padding-left: 3mm; border-left: 2px solid ${accent}; }
    .cover-stats strong { display: block; color: #fff; font-size: 19px; line-height: 1; }
    .cover-stats span { display: block; margin-top: 1.5mm; color: #8ea0b2; font-size: 8px; text-transform: uppercase; }
    .group-summary { display: flex; flex-wrap: wrap; gap: 2mm 5mm; margin-top: 9mm; color: #91a2b4; font-size: 8px; }
    .group-summary strong { color: ${accent}; }
    .rules { display: grid; grid-template-columns: repeat(3, 1fr); gap: 3mm; margin: 5mm 0 7mm; }
    .rules div { padding: 3mm; border: 1px solid #213344; background: #0c1721; }
    .rules strong { color: #fff; font-size: 8.5px; text-transform: uppercase; }
    .rules p { margin: 1.2mm 0 0; color: #9fb0c1; font-size: 7.5px; }
    .unit-group { margin: 0 0 7mm; }
    .section-heading {
      display: flex;
      align-items: end;
      justify-content: space-between;
      margin: 0 0 3mm;
      padding: 2.5mm 1mm 2mm 3mm;
      border-left: 3px solid ${accent};
      border-bottom: 1px solid #26394a;
      break-after: avoid;
    }
    .section-heading h2 { margin: 0; font-size: 17px; line-height: 1; }
    .section-heading .section-kicker { margin-bottom: 1mm; font-size: 6.5px; }
    .section-count { color: #8295a8; font-size: 8px; }
    .unit-card {
      margin: 0 0 3mm;
      border: 1px solid #203243;
      border-radius: 3px;
      background: #0b1620;
      overflow: hidden;
      break-inside: avoid;
    }
    .unit-heading { display: flex; align-items: start; justify-content: space-between; gap: 4mm; padding: 2.5mm 3mm 2mm; }
    .unit-heading h3 { margin: 0 0 1.2mm; color: #fff; font-size: 11.5px; line-height: 1.15; }
    .tags { display: flex; flex-wrap: wrap; gap: 1mm; }
    .tag { padding: .5mm 1.5mm; border: 1px solid #2a4053; border-radius: 20px; color: #9fb0c1; font-size: 6.4px; text-transform: uppercase; }
    .source-state { flex: none; color: #71869a; font-size: 6.5px; text-transform: uppercase; }
    table { width: 100%; border-collapse: collapse; table-layout: fixed; }
    th, td { border-top: 1px solid #1b2b3a; padding: 1.5mm 1.8mm; text-align: center; vertical-align: middle; }
    th { color: #8fa2b5; background: #101e2a; font-size: 6.5px; font-weight: 700; text-transform: uppercase; }
    td { color: #dce5ed; font-size: 8px; }
    th.configuration, td.configuration { width: 30%; text-align: left; }
    td.points { color: ${accent}; font-weight: 800; }
    .resource-label { display: inline-flex; align-items: center; justify-content: center; gap: 1mm; white-space: nowrap; }
    .resource-label img { width: 4mm; height: 4mm; object-fit: contain; }
    .zero { color: #415466; }
    .paid-option td { background: ${accent}0b; }
    .option-mark { display: inline-grid; place-items: center; width: 3.5mm; height: 3.5mm; margin-right: 1mm; border: 1px solid ${accent}; border-radius: 50%; color: ${accent}; font-size: 8px; }
    .document-note { margin-top: 7mm; padding: 4mm 0 0; border-top: 1px solid #26394a; color: #71869a; font-size: 7px; }
    .document-note p { margin: 0 0 1mm; }
  `;
}
