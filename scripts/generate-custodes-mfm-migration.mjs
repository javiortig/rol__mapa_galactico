import { readFileSync, writeFileSync } from "node:fs";

const migrationPath = "supabase/migrations/0121_custodes_mfm_2026_catalog.sql";
const mockPath = "src/mocks/generated/40k-unit-templates.ts";
const sourcePath = "data/11th-custodes-current.json";
const optionsPath = "data/11th-unit-cost-options.json";
const treePath = "data/technology/faction-troop-trees.json";

const source = JSON.parse(readFileSync(sourcePath, "utf8"));
const options = JSON.parse(readFileSync(optionsPath, "utf8"));
const tree = JSON.parse(readFileSync(treePath, "utf8")).trees.find(
  (entry) => entry.factionSlug === "adeptus-custodes"
);
const mockText = readFileSync(mockPath, "utf8");
const mockPrefix = "export const generated40kUnitTemplates = ";
const mockStart = mockText.indexOf(mockPrefix);
const mockEnd = mockText.indexOf('] satisfies CampaignSnapshot["unitTemplates"]', mockStart);
if (!tree || mockStart < 0 || mockEnd < 0) throw new Error("Faltan plantillas o arbol Custodes");
const templates = JSON.parse(mockText.slice(mockStart + mockPrefix.length, mockEnd + 1));
const templatesBySlug = new Map(templates.map((template) => [template.id, template]));
const optionsBySlug = new Map(options.units.map((unit) => [`unit-${unit.factionSlug}-${unit.unitSlug}`, unit]));
const nodeBySlug = new Map();
for (const node of tree.nodes) {
  for (const slug of node.unitTemplateSlugs ?? []) {
    if (nodeBySlug.has(slug)) throw new Error(`Doble tecnologia: ${slug}`);
    nodeBySlug.set(slug, node.slug);
  }
}

const payload = source.units.map((unit) => {
  const slug = `unit-adeptus-custodes-${unit.unitSlug}`;
  const template = templatesBySlug.get(slug);
  const optionSet = optionsBySlug.get(slug);
  const technologyNodeSlug = nodeBySlug.get(slug);
  if (!template || !optionSet || !technologyNodeSlug) throw new Error(`Ficha incompleta: ${slug}`);
  if (template.points !== unit.points) throw new Error(`Puntos distintos en ${slug}`);
  const models = optionSet.modelOptions.map((option) => ({
    slug: `models-${option.minModels}-${option.maxModels}-copy-${option.copyRange.from}-${option.copyRange.to ?? "plus"}`,
    label: option.label,
    models: option.models,
    minModels: option.minModels,
    maxModels: option.maxModels,
    points: option.points,
    copyFrom: option.copyRange.from,
    copyTo: option.copyRange.to,
    changeDirection: option.change?.direction ?? null,
    changeAmount: option.change?.amount ?? null
  }));
  const wargear = optionSet.wargearOptions.map((option) => ({
    slug: option.slug,
    name: option.name,
    points: option.points,
    pricing: option.pricing,
    changeDirection: option.change?.direction ?? null,
    changeAmount: option.change?.amount ?? null
  }));
  return {
    slug, technologyNodeSlug,
    name: template.name, category: template.category,
    unitType: template.unitType, unitKeywords: template.unitKeywords,
    points: template.points, defaultQuantity: template.defaultQuantity,
    woundsPerModel: template.woundsPerModel,
    supplyCost: template.supplyCost, mineralsCost: template.mineralsCost,
    honorCost: template.honorCost, goldCost: template.goldCost,
    recruitmentTimeSeconds: template.recruitmentTimeSeconds,
    recruitmentBuildingType: template.recruitmentBuildingType,
    models, wargear
  };
});

if (payload.length !== 29) throw new Error(`Se esperaban 29 fichas, recibidas ${payload.length}`);
const startMarker = "  -- BEGIN GENERATED CUSTODES MFM PAYLOAD";
const endMarker = "  -- END GENERATED CUSTODES MFM PAYLOAD";
const migration = readFileSync(migrationPath, "utf8");
const start = migration.indexOf(startMarker);
const end = migration.indexOf(endMarker);
if (start < 0 || end < start) throw new Error("Marcadores de migracion ausentes");
const block = `${startMarker}\n  v_items jsonb := $mfm$${JSON.stringify(payload)}$mfm$::jsonb;\n`;
let generated = migration.slice(0, start) + block + migration.slice(end);
const techStartMarker = "  -- BEGIN GENERATED CUSTODES TECH PAYLOAD";
const techEndMarker = "  -- END GENERATED CUSTODES TECH PAYLOAD";
const techStart = generated.indexOf(techStartMarker);
const techEnd = generated.indexOf(techEndMarker);
if (techStart < 0 || techEnd < techStart) throw new Error("Marcadores de tecnologia ausentes");
const techPayload = tree.nodes.map((node) => ({
  slug: node.slug,
  description: node.description,
  effectSummary: node.effectSummary,
  unitTemplateSlugs: node.unitTemplateSlugs
}));
const techBlock = `${techStartMarker}\n  v_nodes jsonb := $nodes$${JSON.stringify(techPayload)}$nodes$::jsonb;\n`;
generated = generated.slice(0, techStart) + techBlock + generated.slice(techEnd);
writeFileSync(migrationPath, generated);
console.log(`Migracion Custodes generada: ${payload.length} fichas MFM`);

const alliedPath = "supabase/migrations/0122_custodes_allied_mfm_2026.sql";
const alliedNames = ["Knight Defender", "Knight Valiant", "Knight Warden", "Canis Rex"];
const alliedPayload = alliedNames.map((name) => {
  const template = templates.find((entry) => entry.factionId === "adeptus-custodes" && entry.name === name);
  if (!template) throw new Error(`Falta aliado Custodes ${name}`);
  const optionSet = optionsBySlug.get(template.id);
  if (!optionSet?.modelOptions.length) throw new Error(`Faltan opciones MFM para ${name}`);
  return {
    slug: template.id, points: template.points,
    defaultQuantity: template.defaultQuantity,
    supplyCost: template.supplyCost, mineralsCost: template.mineralsCost,
    honorCost: template.honorCost, goldCost: template.goldCost,
    models: optionSet.modelOptions.map((option) => ({
      slug: `models-${option.minModels}-${option.maxModels}-copy-${option.copyRange.from}-${option.copyRange.to ?? "plus"}`,
      label: option.label,
      models: option.models,
      minModels: option.minModels,
      maxModels: option.maxModels,
      points: option.points,
      copyFrom: option.copyRange.from,
      copyTo: option.copyRange.to,
      changeDirection: option.change?.direction ?? null,
      changeAmount: option.change?.amount ?? null
    }))
  };
});
const alliedStartMarker = "  -- BEGIN GENERATED CUSTODES ALLIED MFM PAYLOAD";
const alliedEndMarker = "  -- END GENERATED CUSTODES ALLIED MFM PAYLOAD";
const alliedMigration = readFileSync(alliedPath, "utf8");
const alliedStart = alliedMigration.indexOf(alliedStartMarker);
const alliedEnd = alliedMigration.indexOf(alliedEndMarker);
if (alliedStart < 0 || alliedEnd < alliedStart) throw new Error("Marcadores de aliados ausentes");
const alliedBlock = `${alliedStartMarker}\n  v_items jsonb := $mfm$${JSON.stringify(alliedPayload)}$mfm$::jsonb;\n`;
writeFileSync(alliedPath, alliedMigration.slice(0, alliedStart) + alliedBlock + alliedMigration.slice(alliedEnd));
console.log(`Migracion aliada generada: ${alliedPayload.length} fichas`);
