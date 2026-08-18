import { readFileSync } from "node:fs";
import {
  buildTechnologyAssignmentMap,
  primaryUnitType,
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
const goldToleranceByType = Number(balanceConfig.goldUnitToleranceByType ?? balanceConfig.goldUnitTolerance ?? 1);
const targetGoldRatioByType = Number(balanceConfig.targetGoldUnitRatioByType ?? balanceConfig.targetGoldUnitRatio ?? 0.25);
const basicInfantrySupplyOnlyRatio = Number(balanceConfig.basicInfantrySupplyOnlyRatio ?? 0.25);
const honorKeyword = balanceConfig.honorOnlyForKeyword ?? "Caracter";
const basicSupplyOnlySlugs = selectBasicSupplyOnlyInfantrySlugs(unitTemplates, assignmentByUnit, balanceConfig);

for (const template of unitTemplates) {
  const pointValue = warhammerPointValue(template);

  if (pointValue !== template.points) {
    errors.push(`${template.id}: coste ${pointValue} no coincide con ${template.points} pts.`);
  }

  if (template.industrialMaterialCost !== 0 || template.uridiumCost !== 0) {
    errors.push(`${template.id}: Material Industrial y Uridium deben ser 0.`);
  }

  if (template.honorCost > 0 && !(template.unitKeywords ?? []).includes(honorKeyword)) {
    errors.push(`${template.id}: solo las unidades con ${honorKeyword} pueden costar Honor.`);
  }

  if ((template.unitKeywords ?? []).includes(honorKeyword)) {
    const honorShare = resourceShare(template.honorCost, template.points);
    if (!isBetween(honorShare, 0.4, 0.5)) {
      errors.push(`${template.id}: los Characters deben tener 40%-50% de coste en Honor; recibido ${Math.round(honorShare * 100)}%.`);
    }
  }

  if (template.goldCost > 0) {
    const goldShare = resourceShare(template.goldCost, template.points);
    if (!isBetween(goldShare, 0.2, 0.3)) {
      errors.push(`${template.id}: las unidades con Oro deben tener 20%-30% de coste en Oro; recibido ${Math.round(goldShare * 100)}%.`);
    }
  }

  const scaled = scaleCostsFromTemplate(template, template.points);
  const scaledValue = scaled.supply + scaled.minerals * 2 + scaled.honor * 5 + scaled.gold * 5;
  if (scaledValue !== template.points) {
    errors.push(`${template.id}: escalado de variantes invalido para puntos base.`);
  }
}

for (const factionSlug of targetFactionSlugs) {
  const factionUnits = unitTemplates.filter((template) => template.factionId === factionSlug);
  const unitsByType = groupBy(factionUnits, primaryUnitType);

  for (const [type, typedUnits] of unitsByType.entries()) {
    const goldUnits = typedUnits.filter((template) => template.goldCost > 0).length;
    const targetGoldUnits = Math.round(typedUnits.length * targetGoldRatioByType);

    if (Math.abs(goldUnits - targetGoldUnits) > goldToleranceByType) {
      errors.push(`${factionSlug}/${type}: ${goldUnits} unidades con oro, objetivo ${targetGoldUnits} +/- ${goldToleranceByType}.`);
    }
  }

  const basicInfantryCandidates = factionUnits
    .filter((template) => primaryUnitType(template) === "Infanteria")
    .filter((template) => template.category !== "Aliada" && !template.isAlliedUnit);
  const targetBasicSupplyOnly = Math.ceil(basicInfantryCandidates.length * basicInfantrySupplyOnlyRatio);
  const basicSupplyOnlyUnits = basicInfantryCandidates.filter((template) => basicSupplyOnlySlugs.has(template.id));

  if (basicSupplyOnlyUnits.length < targetBasicSupplyOnly) {
    errors.push(`${factionSlug}: ${basicSupplyOnlyUnits.length} infanterias basicas solo Suministro, minimo ${targetBasicSupplyOnly}.`);
  }

  for (const template of basicSupplyOnlyUnits) {
    if (template.supplyCost !== template.points || template.mineralsCost > 0 || template.honorCost > 0 || template.goldCost > 0) {
      errors.push(`${template.id}: la infanteria basica seleccionada debe costar solo Suministro vital.`);
    }
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

  if (!almostEqual(Number(adjacent.uridium ?? 0), 0.3)) {
    errors.push(`${pair.factionSlug}: el adyacente ${pair.adjacentSlug} debe producir 0.3 Uridium/dia.`);
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

function resourceShare(resourceAmount, points) {
  return (Number(resourceAmount ?? 0) * 5) / Math.max(1, Number(points ?? 0));
}

function isBetween(value, min, max) {
  const epsilon = 0.0001;
  return value + epsilon >= min && value - epsilon <= max;
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

function groupBy(items, selector) {
  const grouped = new Map();
  for (const item of items) {
    const key = selector(item);
    const group = grouped.get(key) ?? [];
    group.push(item);
    grouped.set(key, group);
  }
  return grouped;
}
