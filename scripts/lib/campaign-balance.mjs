export const COST_RESOURCE_KEYS = ["supplyCost", "mineralsCost", "honorCost", "goldCost"];

export function warhammerPointValue(costs) {
  return (
    Number(costs.supplyCost ?? 0) +
    Number(costs.mineralsCost ?? 0) * 2 +
    Number(costs.honorCost ?? 0) * 5 +
    Number(costs.goldCost ?? 0) * 5
  );
}

export function buildTechnologyAssignmentMap(troopTreeConfig) {
  const assignments = new Map();

  for (const tree of troopTreeConfig.trees ?? []) {
    const nodes = tree.nodes ?? [];
    const nodesByBranch = new Map();

    for (const node of nodes) {
      const branchNodes = nodesByBranch.get(node.branchSlug) ?? [];
      branchNodes.push(node);
      nodesByBranch.set(node.branchSlug, branchNodes);
    }

    const finalNodeSlugs = new Set();
    for (const branchNodes of nodesByBranch.values()) {
      const sorted = [...branchNodes].sort(sortNodesByProgression);
      const finalNode = sorted.at(-1);
      if (finalNode) {
        finalNodeSlugs.add(finalNode.slug);
      }
    }

    for (const node of nodes) {
      for (const unitTemplateSlug of node.unitTemplateSlugs ?? []) {
        assignments.set(unitTemplateSlug, {
          factionSlug: tree.factionSlug,
          treeKey: tree.treeKey,
          nodeSlug: node.slug,
          nodeName: node.name,
          branchSlug: node.branchSlug,
          tier: Number(node.tier ?? 3),
          costTechnology: Number(node.costTechnology ?? 0),
          isBranchFinal: finalNodeSlugs.has(node.slug),
          isAssignedToTroopTree: true
        });
      }
    }
  }

  return assignments;
}

export function applyUnitCostBalance(units, troopTreeConfig, balanceConfig) {
  const assignmentByUnit = buildTechnologyAssignmentMap(troopTreeConfig);
  const targetRatioByType = Number(balanceConfig.targetGoldUnitRatioByType ?? balanceConfig.targetGoldUnitRatio ?? 0.25);
  const basicSupplyOnlySlugs = selectBasicSupplyOnlyInfantrySlugs(units, assignmentByUnit, balanceConfig);
  const unitsByFactionAndType = groupBy(units, (unit) => `${factionSlugForUnit(unit)}:${primaryUnitType(unit)}`);
  const forcedGoldUnitSlugs = new Set(balanceConfig.forceGoldUnitSlugs ?? []);
  const forcedNoGoldUnitSlugs = new Set(balanceConfig.forceNoGoldUnitSlugs ?? []);
  const goldUnitSlugs = new Set();

  for (const slug of forcedGoldUnitSlugs) {
    if (forcedNoGoldUnitSlugs.has(slug)) {
      throw new Error(`${slug} no puede estar a la vez en forceGoldUnitSlugs y forceNoGoldUnitSlugs.`);
    }
  }

  for (const typedUnits of unitsByFactionAndType.values()) {
    const targetGoldUnits = Math.round(typedUnits.length * targetRatioByType);
    const forcedTypedGoldUnits = typedUnits.filter((unit) => forcedGoldUnitSlugs.has(unitSlug(unit)) && !basicSupplyOnlySlugs.has(unitSlug(unit)));
    for (const unit of forcedTypedGoldUnits) {
      goldUnitSlugs.add(unitSlug(unit));
    }

    const scored = typedUnits
      .map((unit) => {
        const assignment = assignmentByUnit.get(unitSlug(unit)) ?? fallbackAssignment(unit);
        return {
          unit,
          assignment,
          score: goldCandidateScore(unit, assignment)
        };
      })
      .filter((item) => !basicSupplyOnlySlugs.has(unitSlug(item.unit)))
      .filter((item) => !forcedGoldUnitSlugs.has(unitSlug(item.unit)))
      .filter((item) => !forcedNoGoldUnitSlugs.has(unitSlug(item.unit)))
      .sort((left, right) => {
        if (left.score !== right.score) {
          return right.score - left.score;
        }
        if (left.assignment.tier !== right.assignment.tier) {
          return right.assignment.tier - left.assignment.tier;
        }
        if (left.unit.points !== right.unit.points) {
          return right.unit.points - left.unit.points;
        }
        return unitSlug(left.unit).localeCompare(unitSlug(right.unit));
      });

    const remainingTarget = Math.max(0, targetGoldUnits - forcedTypedGoldUnits.length);
    for (const item of scored.slice(0, remainingTarget)) {
      goldUnitSlugs.add(unitSlug(item.unit));
    }
  }

  const summaries = [];

  for (const unit of units) {
    const assignment = assignmentByUnit.get(unitSlug(unit)) ?? fallbackAssignment(unit);
    const isBasicSupplyOnlyInfantry = basicSupplyOnlySlugs.has(unitSlug(unit));
    const costs = computeBalancedUnitCosts(unit, assignment, goldUnitSlugs.has(unitSlug(unit)), isBasicSupplyOnlyInfantry);

    unit.supplyCost = costs.supplyCost;
    unit.mineralsCost = costs.mineralsCost;
    unit.honorCost = costs.honorCost;
    unit.goldCost = costs.goldCost;
    unit.industrialMaterialCost = 0;
    unit.uridiumCost = 0;
    unit.technologyCost = 0;

    summaries.push({
      slug: unitSlug(unit),
      factionSlug: factionSlugForUnit(unit),
      name: unit.name,
      points: unit.points,
      assignment,
      primaryType: primaryUnitType(unit),
      costs,
      hasGold: unit.goldCost > 0,
      isInitialBasicInfantry: isBasicSupplyOnlyInfantry,
      isBasicSupplyOnlyInfantry
    });
  }

  return {
    assignmentByUnit,
    goldUnitSlugs,
    summaries,
    factionSummaries: buildFactionBalanceSummaries(units, balanceConfig)
  };
}

export function computeBalancedUnitCosts(
  unit,
  assignment = fallbackAssignment(unit),
  hasGold = false,
  isBasicSupplyOnlyInfantry = isInitialBasicInfantry(unit, assignment)
) {
  if (isBasicSupplyOnlyInfantry) {
    return emptyUnitCosts(unit.points);
  }

  const profile = balanceProfileForUnit(unit, assignment, hasGold);
  return costsFromProfile(unit.points, profile, hasGold, primaryUnitType(unit) === "Caracter");
}

export function scaleCostsFromTemplate(template, selectedPoints) {
  const points = Math.max(0, Math.trunc(Number(selectedPoints ?? template.points ?? 0)));
  const basePoints = Math.max(0, Math.trunc(Number(template.points ?? 0)));

  if (basePoints <= 0 || points === basePoints) {
    return {
      supply: Number(template.supplyCost ?? 0),
      minerals: Number(template.mineralsCost ?? 0),
      honor: Number(template.honorCost ?? 0),
      gold: Number(template.goldCost ?? 0),
      industrialMaterial: 0,
      uridium: 0,
      technology: 0
    };
  }

  const minerals = Math.floor(((points * Number(template.mineralsCost ?? 0) * 2) / basePoints) / 2);
  const honor = Math.floor(((points * Number(template.honorCost ?? 0) * 5) / basePoints) / 5);
  const rawGold = Math.floor(((points * Number(template.goldCost ?? 0) * 5) / basePoints) / 5);
  const gold = Number(template.goldCost ?? 0) > 0 && points >= 5 ? Math.max(1, rawGold) : rawGold;
  const normalized = normalizeCosts(points, {
    supplyCost: 0,
    mineralsCost: minerals,
    honorCost: honor,
    goldCost: gold
  });

  return {
    supply: normalized.supplyCost,
    minerals: normalized.mineralsCost,
    honor: normalized.honorCost,
    gold: normalized.goldCost,
    industrialMaterial: 0,
    uridium: 0,
    technology: 0
  };
}

export function buildFactionBalanceSummaries(units, balanceConfig) {
  const unitsByFaction = groupBy(units, factionSlugForUnit);
  const targetRatioByType = Number(balanceConfig.targetGoldUnitRatioByType ?? balanceConfig.targetGoldUnitRatio ?? 0.25);

  return [...unitsByFaction.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([factionSlug, factionUnits]) => {
      const goldUnits = factionUnits.filter((unit) => unit.goldCost > 0).length;
      const byType = [...groupBy(factionUnits, primaryUnitType).entries()]
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([type, typedUnits]) => ({
          type,
          unitCount: typedUnits.length,
          goldUnits: typedUnits.filter((unit) => unit.goldCost > 0).length,
          targetGoldUnits: Math.round(typedUnits.length * targetRatioByType)
        }));
      const totals = factionUnits.reduce(
        (sum, unit) => ({
          points: sum.points + Number(unit.points ?? 0),
          supply: sum.supply + Number(unit.supplyCost ?? 0),
          minerals: sum.minerals + Number(unit.mineralsCost ?? 0),
          honor: sum.honor + Number(unit.honorCost ?? 0),
          gold: sum.gold + Number(unit.goldCost ?? 0)
        }),
        { points: 0, supply: 0, minerals: 0, honor: 0, gold: 0 }
      );

      return {
        factionSlug,
        unitCount: factionUnits.length,
        targetGoldUnits: byType.reduce((sum, item) => sum + item.targetGoldUnits, 0),
        goldUnits,
        goldUnitPercent: factionUnits.length === 0 ? 0 : Math.round((goldUnits / factionUnits.length) * 100),
        byType,
        totals
      };
    });
}

export function systemWarhammerPointValue(capacity) {
  return (
    Number(capacity.supply ?? 0) +
    Number(capacity.minerals ?? 0) * 2 +
    Number(capacity.honor ?? 0) * 5 +
    Number(capacity.gold ?? 0) * 5
  );
}

export function isInitialBasicInfantry(unit, assignment = fallbackAssignment(unit)) {
  const keywords = unit.unitKeywords ?? [];
  return (
    assignment.tier === 1 &&
    keywords.includes("Infanteria") &&
    !keywords.includes("Caracter") &&
    !keywords.includes("Vehiculo") &&
    !keywords.includes("Aeronave") &&
    !keywords.includes("Fortificacion") &&
    !keywords.includes("Bestia") &&
    !keywords.includes("Montado")
  );
}

export function selectBasicSupplyOnlyInfantrySlugs(units, assignmentByUnit, balanceConfig) {
  const ratio = Number(balanceConfig.basicInfantrySupplyOnlyRatio ?? 0.25);
  const selected = new Set();
  const unitsByFaction = groupBy(units, factionSlugForUnit);

  for (const factionUnits of unitsByFaction.values()) {
    const candidates = factionUnits
      .filter((unit) => primaryUnitType(unit) === "Infanteria")
      .filter((unit) => unit.category !== "Aliada" && !unit.isAlliedUnit)
      .map((unit) => ({
        unit,
        assignment: assignmentByUnit.get(unitSlug(unit)) ?? fallbackAssignment(unit)
      }))
      .sort((left, right) => basicInfantryScore(left.unit, left.assignment) - basicInfantryScore(right.unit, right.assignment));
    const target = Math.ceil(candidates.length * ratio);

    for (const item of candidates.slice(0, target)) {
      selected.add(unitSlug(item.unit));
    }
  }

  return selected;
}

export function primaryUnitType(unit) {
  const keywords = unit.unitKeywords ?? [];
  if (keywords.includes("Caracter")) return "Caracter";
  if (keywords.includes("Vehiculo") || keywords.includes("Aeronave") || keywords.includes("Fortificacion")) return "Vehiculo";
  if (keywords.includes("Bestia")) return "Bestia";
  if (keywords.includes("Montado")) return "Montado";
  if (keywords.includes("Infanteria")) return "Infanteria";
  return "Otro";
}

function balanceProfileForUnit(unit, assignment, hasGold) {
  const keywords = unit.unitKeywords ?? [];
  const tier = Number(assignment.tier ?? 3);
  const isAdvanced = tier >= 3 || assignment.isBranchFinal || unit.points >= 200;
  const isAllied = unit.category === "Aliada" || unit.isAlliedUnit;
  const isCrucible = unit.name.includes("[Crucible]");
  let minerals = 0.2;
  let honor = 0;
  let gold = 0;

  if (keywords.includes("Caracter") && keywords.includes("Vehiculo")) {
    minerals = 0.35;
    honor = isAdvanced ? 0.35 : 0.3;
  } else if (keywords.includes("Caracter")) {
    minerals = isAdvanced ? 0.15 : 0.1;
    honor = isAdvanced || isCrucible ? 0.45 : 0.35;
  } else if (keywords.includes("Vehiculo") || keywords.includes("Aeronave") || keywords.includes("Fortificacion")) {
    minerals = isAdvanced ? 0.75 : 0.65;
    honor = 0;
  } else if (keywords.includes("Bestia")) {
    minerals = isAdvanced ? 0.2 : 0.12;
    honor = 0;
  } else if (keywords.includes("Montado")) {
    minerals = isAdvanced ? 0.45 : 0.35;
    honor = 0;
  } else if (keywords.includes("Infanteria")) {
    minerals = tier <= 2 ? 0.2 : 0.3;
    honor = 0;
  } else if (isAllied) {
    minerals = 0.25;
    honor = 0;
  }

  if (hasGold) {
    if (isAllied || assignment.isBranchFinal || /titan|warlord|knight|silent king|c'tan|ctan|be'lakor|kairos/i.test(unit.name)) {
      gold = 0.15;
    } else if (keywords.includes("Caracter")) {
      gold = 0.1;
    } else if (keywords.includes("Vehiculo") || keywords.includes("Aeronave") || keywords.includes("Fortificacion")) {
      gold = 0.08;
    } else {
      gold = 0.05;
    }
  }

  return clampProfile({ minerals, honor, gold });
}

function costsFromProfile(points, profile, hasGold, isCharacter = false) {
  const honor = isCharacter ? boundedResourceUnits(points, 0.45, 0.4, 0.5) : 0;
  const gold = hasGold ? boundedResourceUnits(points, 0.25, 0.2, 0.3) : 0;
  const remainingPoints = Math.max(0, points - honor * 5 - gold * 5);
  const minerals = Math.min(
    Math.floor((points * profile.minerals) / 2),
    Math.floor(remainingPoints / 2)
  );

  return normalizeCosts(points, {
    supplyCost: 0,
    mineralsCost: minerals,
    honorCost: honor,
    goldCost: gold
  });
}

function boundedResourceUnits(points, targetRatio, minRatio, maxRatio) {
  const minUnits = Math.ceil((points * minRatio) / 5);
  const maxUnits = Math.floor((points * maxRatio) / 5);
  const targetUnits = Math.round((points * targetRatio) / 5);

  if (minUnits <= maxUnits) {
    return Math.max(minUnits, Math.min(maxUnits, targetUnits));
  }

  return Math.max(0, targetUnits);
}

function normalizeCosts(points, costs) {
  const normalized = {
    supplyCost: 0,
    mineralsCost: Math.max(0, Math.trunc(costs.mineralsCost ?? 0)),
    honorCost: Math.max(0, Math.trunc(costs.honorCost ?? 0)),
    goldCost: Math.max(0, Math.trunc(costs.goldCost ?? 0))
  };

  while (warhammerPointValue(normalized) > points && normalized.goldCost > 0) {
    normalized.goldCost -= 1;
  }
  while (warhammerPointValue(normalized) > points && normalized.honorCost > 0) {
    normalized.honorCost -= 1;
  }
  while (warhammerPointValue(normalized) > points && normalized.mineralsCost > 0) {
    normalized.mineralsCost -= 1;
  }

  normalized.supplyCost = points - normalized.mineralsCost * 2 - normalized.honorCost * 5 - normalized.goldCost * 5;
  return normalized;
}

function emptyUnitCosts(points) {
  return {
    supplyCost: Math.max(0, Math.trunc(Number(points ?? 0))),
    mineralsCost: 0,
    honorCost: 0,
    goldCost: 0
  };
}

function goldCandidateScore(unit, assignment) {
  const keywords = unit.unitKeywords ?? [];
  let score = 0;

  if (unit.category === "Aliada" || unit.isAlliedUnit) score += 120;
  if (unit.name.includes("[Crucible]")) score += 95;
  if (assignment.isBranchFinal) score += 85;
  if (/titan|warlord|knight|silent king|c'tan|ctan|be'lakor|kairos|primarch|trajann/i.test(unit.name)) score += 70;
  if (unit.points >= 300) score += 55;
  else if (unit.points >= 200) score += 35;
  if (keywords.includes("Caracter")) score += 35;
  if (keywords.includes("Vehiculo") || keywords.includes("Aeronave") || keywords.includes("Fortificacion")) score += 30;
  if (keywords.includes("Bestia")) score += 20;
  score += Math.max(0, Number(assignment.tier ?? 1) - 1) * 10;

  return score;
}

function basicInfantryScore(unit, assignment) {
  let score = 0;
  const tier = Number(assignment.tier ?? 3);

  score += tier * 1000;
  if (unit.category !== "Linea de batalla") score += 250;
  if (assignment.isBranchFinal) score += 250;
  score += Number(assignment.costTechnology ?? 0) * 50;
  score += Number(unit.points ?? 0);
  return score;
}

function fallbackAssignment(unit) {
  return {
    factionSlug: factionSlugForUnit(unit),
    treeKey: null,
    nodeSlug: null,
    nodeName: null,
    branchSlug: null,
    tier: fallbackTier(unit),
    costTechnology: 0,
    isBranchFinal: false,
    isAssignedToTroopTree: false
  };
}

function unitSlug(unit) {
  return unit.slug ?? unit.id;
}

function factionSlugForUnit(unit) {
  return unit.factionSlug ?? unit.factionId;
}

function fallbackTier(unit) {
  const keywords = unit.unitKeywords ?? [];
  if (unit.category === "Linea de batalla" && keywords.includes("Infanteria")) return 1;
  if (keywords.includes("Caracter") || keywords.includes("Vehiculo") || keywords.includes("Aeronave") || keywords.includes("Fortificacion")) return 3;
  if (keywords.includes("Bestia") || keywords.includes("Montado")) return 2;
  return 2;
}

function clampProfile(profile) {
  const total = profile.minerals + profile.honor + profile.gold;
  if (total <= 0.9) {
    return profile;
  }

  const factor = 0.9 / total;
  return {
    minerals: profile.minerals * factor,
    honor: profile.honor * factor,
    gold: profile.gold * factor
  };
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

function sortNodesByProgression(left, right) {
  if (left.tier !== right.tier) return left.tier - right.tier;
  if (left.positionY !== right.positionY) return left.positionY - right.positionY;
  if (left.positionX !== right.positionX) return left.positionX - right.positionX;
  return left.name.localeCompare(right.name);
}
