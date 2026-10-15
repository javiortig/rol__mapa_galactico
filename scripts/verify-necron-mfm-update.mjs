import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

function templatesFrom(source) {
  const match = source.match(/export const generated40kUnitTemplates = (\[[\s\S]*?\]) satisfies CampaignSnapshot\["unitTemplates"\];/);
  if (!match) throw new Error("No se encontro el catalogo generado");
  return JSON.parse(match[1]);
}

const catalog = JSON.parse(readFileSync("data/11th-unit-cost-options.json", "utf8"));
const current = templatesFrom(readFileSync("src/mocks/generated/40k-unit-templates.ts", "utf8"));
const previous = templatesFrom(execFileSync("git", ["show", "HEAD:src/mocks/generated/40k-unit-templates.ts"], { encoding: "utf8" }));
const previousById = new Map(previous.map((template) => [template.id, template]));
const currentById = new Map(current.map((template) => [template.id, template]));
const refreshed = catalog.units.filter((unit) =>
  unit.factionSlug === "necrones" && unit.source?.fetchedAt === catalog.source.necronsRefreshedAt
);
if (refreshed.length !== 52 || current.length !== previous.length) {
  throw new Error("El numero de plantillas MFM o del catalogo ha cambiado inesperadamente");
}

for (const template of current) {
  const old = previousById.get(template.id);
  if (!old) throw new Error(`Plantilla nueva inesperada: ${template.id}`);
  if (template.factionId !== "necrones" && JSON.stringify(template) !== JSON.stringify(old)) {
    throw new Error(`Plantilla ajena modificada: ${template.id}`);
  }
  if (template.factionId !== "necrones") continue;
  const points = template.supplyCost + template.mineralsCost * 2 + template.honorCost * 5 + template.goldCost * 5;
  const roundingAllowed = points === template.points + 1 && template.supplyCost === 0 && template.mineralsCost > 0;
  if ((points !== template.points && !roundingAllowed)
    || template.industrialMaterialCost !== 0 || template.uridiumCost !== 0) {
    throw new Error(`Coste necron incoherente: ${template.name}`);
  }
}

for (const unit of refreshed) {
  const template = currentById.get(`unit-necrones-${unit.unitSlug}`);
  const base = unit.modelOptions.find((option) =>
    option.copyRange.from === 1 && option.models === unit.provided.models
  );
  if (!template || !base || template.points !== base.points) {
    throw new Error(`Precio MFM incorrecto: ${unit.name}`);
  }
}

const absent = catalog.units.filter((unit) => unit.factionSlug === "necrones"
  && unit.source?.fetchedAt !== catalog.source.necronsRefreshedAt);
for (const unit of absent) {
  const template = currentById.get(`unit-necrones-${unit.unitSlug}`)
    ?? currentById.get(`unit-necrones-${unit.unitSlug}-crucible`);
  const old = previousById.get(template?.id);
  if (!template || !old || JSON.stringify(template) !== JSON.stringify(old)) {
    throw new Error(`Ficha sin MFM modificada: ${unit.name}`);
  }
}

console.log(`Necrones: ${refreshed.length} fichas MFM, ${absent.length} sin fuente vigente, resto de facciones intacto.`);
