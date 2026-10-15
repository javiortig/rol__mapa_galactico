import { readFileSync, writeFileSync } from "node:fs";

const catalog = JSON.parse(readFileSync("data/11th-unit-cost-options.json", "utf8"));
const mockSource = readFileSync("src/mocks/generated/40k-unit-templates.ts", "utf8");
const mockMatch = mockSource.match(/export const generated40kUnitTemplates = (\[[\s\S]*?\]) satisfies CampaignSnapshot\["unitTemplates"\];/);
if (!mockMatch) throw new Error("No se encontro el catalogo JSON generado de plantillas");
const templates = new Map(JSON.parse(mockMatch[1]).map((template) => [template.id, template]));
const migrationPath = "supabase/migrations/0115_necron_mfm_points.sql";
const sourcePath = "supabase/migrations/0114_space_marines_mfm_enchanted_characters.sql";
const units = catalog.units.filter((unit) =>
  unit.factionSlug === "necrones" && unit.matchStatus === "matched" &&
  unit.source?.fetchedAt === catalog.source.necronsRefreshedAt
);
if (units.length < 50 || units.some((unit) => unit.source?.pageSlug !== "necrons")) {
  throw new Error("El catalogo oficial Necrones no esta completo");
}

const payload = units.map((unit) => {
  const slug = `unit-necrones-${unit.unitSlug}`;
  const template = templates.get(slug);
  const base = unit.modelOptions.find((option) =>
    option.copyRange.from === 1 && option.models === unit.provided.models
  );
  if (!template || !base || template.points !== base.points) {
    throw new Error(`Precio MFM o costes generados no coinciden para ${unit.name}`);
  }
  return {
    slug,
    points: base.points,
    costs: {
      supply: template.supplyCost,
      minerals: template.mineralsCost,
      honor: template.honorCost,
      gold: template.goldCost
    },
    models: unit.modelOptions.map((option) => ({
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
    })),
    wargear: unit.wargearOptions.map((option) => ({
      slug: option.slug,
      name: option.name,
      points: option.points,
      pricing: option.pricing,
      changeDirection: option.change?.direction ?? null,
      changeAmount: option.change?.amount ?? null
    }))
  };
});

const reference = readFileSync(sourcePath, "utf8");
const markerStart = "  -- BEGIN GENERATED SPACE MARINES MFM PAYLOAD";
const markerEnd = "  -- END GENERATED SPACE MARINES MFM PAYLOAD";
const blockEnd = reference.indexOf("\n$$;\n\nalter table public.recruitment_queue");
if (blockEnd < 0) throw new Error("No se encontro el bloque MFM de referencia");
let sql = reference.slice(0, blockEnd + "\n$$;".length);
const start = sql.indexOf(markerStart);
const end = sql.indexOf(markerEnd);
if (start < 0 || end <= start) throw new Error("No se encontro el payload MFM de referencia");
sql = sql.slice(0, start) +
  `  -- BEGIN GENERATED NECRONS MFM PAYLOAD\n  v_items jsonb := $mfm$${JSON.stringify(payload)}$mfm$::jsonb;\n  ` +
  sql.slice(end).replace(markerEnd, "-- END GENERATED NECRONS MFM PAYLOAD");
sql = sql
  .replace("-- Space Marines prices from the official MFM, refreshed on 2026-10-13.",
    `-- Necron prices from the official MFM, refreshed on ${catalog.source.necronsRefreshedAt.slice(0, 10)}.`)
  .replaceAll("space-marines", "necrones")
  .replace("  v_cost record;\n", "")
  .replace(/    select \* into v_cost\n    from public\.recruitment_cost_bundle_for_template\(v_template\.id, \(v_item->>'points'\)::integer\);\n\n/, "")
  .replace("supply_cost = v_cost.supply_cost,", "supply_cost = (v_item->'costs'->>'supply')::integer,")
  .replace("minerals_cost = v_cost.minerals_cost,", "minerals_cost = (v_item->'costs'->>'minerals')::integer,")
  .replace("honor_cost = v_cost.honor_cost,", "honor_cost = (v_item->'costs'->>'honor')::integer,")
  .replace("gold_cost = v_cost.gold_cost", "gold_cost = (v_item->'costs'->>'gold')::integer");
if (sql.includes("v_cost") || sql.includes("space-marines")) {
  throw new Error("La migracion Necron contiene referencias al bloque antiguo");
}
writeFileSync(migrationPath, `${sql}\n`);
console.log(`Migracion Necron: ${units.length} fichas, ${payload.reduce((sum, item) => sum + item.models.length, 0)} opciones de tamano`);
