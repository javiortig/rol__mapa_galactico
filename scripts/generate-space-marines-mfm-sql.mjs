import { readFileSync, writeFileSync } from "node:fs";

const catalog = JSON.parse(readFileSync("data/11th-unit-cost-options.json", "utf8"));
const migrationPath = "supabase/migrations/0114_space_marines_mfm_enchanted_characters.sql";
const markerStart = "  -- BEGIN GENERATED SPACE MARINES MFM PAYLOAD";
const markerEnd = "  -- END GENERATED SPACE MARINES MFM PAYLOAD";

const units = catalog.units.filter((unit) =>
  unit.factionSlug === "space-marines" &&
  unit.matchStatus === "matched" &&
  unit.source?.fetchedAt === catalog.source.spaceMarinesRefreshedAt
);
if (units.length < 60 || units.some((unit) => unit.source?.pageSlug !== "space-marines")) {
  throw new Error("El catalogo oficial de Space Marines no esta completo");
}

const payload = units.map((unit) => {
  const base = unit.modelOptions.find(
    (option) => option.copyRange.from === 1 && option.models === unit.provided.models
  );
  if (!base) {
    throw new Error(`Falta precio MFM para ${unit.name} (${unit.provided.models} modelos)`);
  }

  return {
    slug: `unit-space-marines-${unit.unitSlug}`,
    points: base.points,
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

const source = readFileSync(migrationPath, "utf8");
const start = source.indexOf(markerStart);
const end = source.indexOf(markerEnd);
if (start < 0 || end <= start) {
  throw new Error("No se encontro el marcador MFM en la migracion");
}

const replacement = `${markerStart}\n  v_items jsonb := $mfm$${JSON.stringify(payload)}$mfm$::jsonb;\n  `;
writeFileSync(migrationPath, source.slice(0, start) + replacement + source.slice(end));
console.log(`Migracion MFM: ${units.length} fichas, ${payload.reduce((total, unit) => total + unit.models.length, 0)} opciones de tamano`);
