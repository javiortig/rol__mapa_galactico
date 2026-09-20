import { readFileSync } from "node:fs";
import {
  buildTechnologyAssignmentMap,
  computeBalancedUnitCosts,
  getUnitCostRule,
  selectBasicSupplyOnlyInfantrySlugs,
  scaleCostsFromTemplate,
  systemWarhammerPointValue,
  warhammerPointValue
} from "./lib/campaign-balance.mjs";

const balanceConfig = readJson("data/balance/faction-balance.json");
const troopTreeConfig = readJson("data/technology/faction-troop-trees.json");
const unitTemplates = readGeneratedUnitTemplates("src/mocks/generated/40k-unit-templates.ts");
const assignmentByUnit = buildTechnologyAssignmentMap(troopTreeConfig);
const errors = [];
const targetFactionSlugs = new Set(balanceConfig.targetFactionSlugs ?? []);
const rebalanceFactionSlugs = new Set(balanceConfig.rebalanceFactionSlugs ?? []);
const preservedFactionSlugs = new Set(balanceConfig.preserveFactionCostSlugs ?? []);
const honorKeyword = balanceConfig.honorOnlyForKeyword ?? "Caracter";
const basicSupplyOnlySlugs = selectBasicSupplyOnlyInfantrySlugs(unitTemplates, assignmentByUnit, balanceConfig);
const templateById = new Map(unitTemplates.map((template) => [template.id, template]));

for (const slug of balanceConfig.supplyOnlyUnitSlugs ?? []) {
  if (!templateById.has(slug)) errors.push(`${slug}: excepcion de Suministro no encontrada en el catalogo.`);
}

for (const slug of Object.keys(balanceConfig.goldShareByUnitSlug ?? {})) {
  if (!templateById.has(slug)) errors.push(`${slug}: excepcion de Oro no encontrada en el catalogo.`);
}

for (const template of unitTemplates) {
  const pointValue = warhammerPointValue(template);

  if (!isValidRoundedPointValue(template, pointValue)) {
    errors.push(`${template.id}: coste ${pointValue} no coincide con ${template.points} pts.`);
  }

  if (template.industrialMaterialCost !== 0 || template.uridiumCost !== 0) {
    errors.push(`${template.id}: Material Industrial y Uridium deben ser 0.`);
  }

  if (template.unitType === "monster" && !(template.unitKeywords ?? []).includes("Monstruo")) {
    errors.push(`${template.id}: unit_type monster requiere keyword Monstruo.`);
  }

  if ((template.unitKeywords ?? []).includes("Monstruo") && (template.unitKeywords ?? []).includes("Bestia")) {
    errors.push(`${template.id}: Bestia y Monstruo no deben fusionarse en la misma clasificacion.`);
  }

  if (template.honorCost > 0 && !(template.unitKeywords ?? []).includes(honorKeyword)) {
    errors.push(`${template.id}: solo las unidades con ${honorKeyword} pueden costar Honor.`);
  }

  if (rebalanceFactionSlugs.has(template.factionId)) {
    const expected = computeBalancedUnitCosts(
      template,
      assignmentByUnit.get(template.id),
      balanceConfig
    );
    for (const key of ["supplyCost", "mineralsCost", "honorCost", "goldCost"]) {
      if (Number(template[key]) !== Number(expected[key])) {
        errors.push(`${template.id}: ${key}=${template[key]}, esperado ${expected[key]}.`);
      }
    }

    const rule = getUnitCostRule(template, balanceConfig);
    if (rule.supplyOnly && template.supplyCost !== template.points) {
      errors.push(`${template.id}: la excepcion de Suministro debe pagar todos sus puntos con Suministro.`);
    }
  }

  const scaled = scaleCostsFromTemplate(template, template.points);
  const scaledValue = scaled.supply + scaled.minerals * 2 + scaled.honor * 5 + scaled.gold * 5;
  if (!isValidRoundedPointValue(template, scaledValue)) {
    errors.push(`${template.id}: escalado de variantes invalido para puntos base.`);
  }
}

for (const factionSlug of rebalanceFactionSlugs) {
  const factionUnits = unitTemplates.filter((template) => template.factionId === factionSlug);
  const basicSupplyOnlyUnits = factionUnits.filter((template) => basicSupplyOnlySlugs.has(template.id));

  for (const template of basicSupplyOnlyUnits) {
    if (template.supplyCost !== template.points || template.mineralsCost > 0 || template.honorCost > 0 || template.goldCost > 0) {
      errors.push(`${template.id}: la infanteria basica seleccionada debe costar solo Suministro vital.`);
    }
  }
}

for (const factionSlug of preservedFactionSlugs) {
  if (!targetFactionSlugs.has(factionSlug)) {
    errors.push(`${factionSlug}: una faccion preservada debe seguir formando parte del catalogo objetivo.`);
  }
}

for (const pair of balanceConfig.initialPairs ?? []) {
  const capital = balanceConfig.systemCapacities?.[pair.capitalSlug] ?? {};
  const adjacent = balanceConfig.systemCapacities?.[pair.adjacentSlug] ?? {};
  const total = systemWarhammerPointValue(capital) + systemWarhammerPointValue(adjacent);

  if (total !== balanceConfig.dailyInitialPairRecruitmentPoints) {
    errors.push(`${pair.factionSlug}: ${pair.capitalSlug}+${pair.adjacentSlug} producen ${total} pts/dia.`);
  }

  if ((capital.gold ?? 0) > 0 || (adjacent.gold ?? 0) > 0) {
    errors.push(`${pair.factionSlug}: capital o adyacente tienen oro.`);
  }

  if (Number(capital.uridium ?? 0) !== 0) {
    errors.push(`${pair.factionSlug}: la capital ${pair.capitalSlug} no debe tener Uridium.`);
  }

  if (!almostEqual(Number(adjacent.uridium ?? 0), 0.6)) {
    errors.push(`${pair.factionSlug}: el adyacente ${pair.adjacentSlug} debe producir 0.6 Uridium/dia.`);
  }

  if (!almostEqual(Number(capital.industrial_material ?? 0), 5)) {
    errors.push(`${pair.factionSlug}: la capital ${pair.capitalSlug} debe tener 5 Material Industrial/dia.`);
  }

  if (Number(adjacent.industrial_material ?? 0) !== 0) {
    errors.push(`${pair.factionSlug}: el adyacente ${pair.adjacentSlug} no debe tener Material Industrial.`);
  }
}

const goldSystemSlugs = Object.entries(balanceConfig.systemCapacities ?? {})
  .filter(([, capacity]) => Number(capacity.gold ?? 0) > 0)
  .map(([slug]) => slug)
  .sort();

if (goldSystemSlugs.length > 0) {
  errors.push(`Ningun sistema debe tener Oro natural en el balance actual; recibido ${goldSystemSlugs.join(", ")}.`);
}

if (balanceConfig.initialBuildings !== "none") {
  errors.push("La campana debe empezar sin edificios iniciales.");
}

for (const slug of balanceConfig.basicBuildingSlugs ?? []) {
  const cost = Number(balanceConfig.buildingCosts?.[slug] ?? 0);
  if (cost !== 20) {
    errors.push(`${slug}: los edificios basicos deben costar 20 Material Industrial.`);
  }
}

for (const [slug, cost] of Object.entries(balanceConfig.buildingCosts ?? {})) {
  if (!Number.isInteger(Number(cost)) || Number(cost) <= 0) {
    errors.push(`${slug}: coste de edificio invalido.`);
  }
}

if (errors.length > 0) {
  console.error("Validacion de balance fallida:");
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`Balance validado: ${unitTemplates.length} plantillas, ${targetFactionSlugs.size} facciones jugables.`);

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function almostEqual(left, right) {
  return Math.abs(left - right) < 0.0001;
}

function isValidRoundedPointValue(template, value) {
  return value === template.points || (
    value === template.points + 1 &&
    Number(template.supplyCost ?? 0) === 0 &&
    Number(template.mineralsCost ?? 0) > 0
  );
}

function readGeneratedUnitTemplates(path) {
  const source = readFileSync(path, "utf8");
  const marker = "export const generated40kUnitTemplates = ";
  const start = source.indexOf(marker);
  const arrayStart = source.indexOf("[", start);
  const arrayEnd = source.indexOf("] satisfies CampaignSnapshot[\"unitTemplates\"];", arrayStart);

  if (start === -1 || arrayStart === -1 || arrayEnd === -1) {
    throw new Error("No se pudo extraer generated40kUnitTemplates.");
  }

  return JSON.parse(source.slice(arrayStart, arrayEnd + 1));
}
