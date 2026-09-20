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

export function applyUnitCostBalance(units, troopTreeConfig, balanceConfig, preservedCostsBySlug = new Map()) {
  const assignmentByUnit = buildTechnologyAssignmentMap(troopTreeConfig);
  const preservedFactionSlugs = new Set(balanceConfig.preserveFactionCostSlugs ?? []);
  const rebalancedFactionSlugs = new Set(balanceConfig.rebalanceFactionSlugs ?? []);
  const goldUnitSlugs = new Set();

  const summaries = [];

  for (const unit of units) {
    const assignment = assignmentByUnit.get(unitSlug(unit)) ?? fallbackAssignment(unit);
    const factionSlug = factionSlugForUnit(unit);
    const shouldPreserve = preservedFactionSlugs.has(factionSlug) || !rebalancedFactionSlugs.has(factionSlug);
    const preservedCosts = shouldPreserve ? preservedCostsBySlug.get(unitSlug(unit)) : null;
    const rule = getUnitCostRule(unit, balanceConfig);
    const costs = preservedCosts
      ? pickUnitCosts(preservedCosts)
      : computeBalancedUnitCosts(unit, assignment, balanceConfig);

    if (shouldPreserve && !preservedCosts) {
      throw new Error(`No hay costes preservados para ${unitSlug(unit)}.`);
    }

    unit.supplyCost = costs.supplyCost;
    unit.mineralsCost = costs.mineralsCost;
    unit.honorCost = costs.honorCost;
    unit.goldCost = costs.goldCost;
    unit.industrialMaterialCost = 0;
    unit.uridiumCost = 0;
    unit.technologyCost = 0;

    if (unit.goldCost > 0) {
      goldUnitSlugs.add(unitSlug(unit));
    }

    summaries.push({
      slug: unitSlug(unit),
      factionSlug,
      name: unit.name,
      points: unit.points,
      assignment,
      primaryType: primaryUnitType(unit),
      costs,
      hasGold: unit.goldCost > 0,
      goldShare: rule.goldShare,
      isInitialBasicInfantry: rule.supplyOnly,
      isBasicSupplyOnlyInfantry: rule.supplyOnly,
      isPreserved: Boolean(preservedCosts)
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
  balanceConfig = {}
) {
  void assignment;
  const rule = getUnitCostRule(unit, balanceConfig);

  if (rule.supplyOnly) {
    return emptyUnitCosts(unit.points);
  }

  return costsFromPointShares(unit.points, pointSharesForUnit(unit, rule, balanceConfig));
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

  if (factionSlugForUnit(template) === "space-marines") {
    return legacyScaleCostsFromTemplate(template, points, basePoints);
  }

  const baseCosts = pickUnitCosts(template);
  const baseValue = warhammerPointValue(baseCosts);
  const shares = Object.fromEntries(
    COST_RESOURCE_KEYS.map((key) => [key, baseValue > 0 ? (baseCosts[key] * resourcePointValue(key)) / baseValue : 0])
  );
  const normalized = costsFromPointShares(points, shares);

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

function legacyScaleCostsFromTemplate(template, points, basePoints) {
  const minerals = Math.floor(((points * Number(template.mineralsCost ?? 0) * 2) / basePoints) / 2);
  const honor = Math.floor(((points * Number(template.honorCost ?? 0) * 5) / basePoints) / 5);
  const rawGold = Math.floor(((points * Number(template.goldCost ?? 0) * 5) / basePoints) / 5);
  const gold = Number(template.goldCost ?? 0) > 0 && points >= 5 ? Math.max(1, rawGold) : rawGold;
  const normalized = {
    supplyCost: 0,
    mineralsCost: Math.max(0, minerals),
    honorCost: Math.max(0, honor),
    goldCost: Math.max(0, gold)
  };

  while (warhammerPointValue(normalized) > points && normalized.goldCost > 0) normalized.goldCost -= 1;
  while (warhammerPointValue(normalized) > points && normalized.honorCost > 0) normalized.honorCost -= 1;
  while (warhammerPointValue(normalized) > points && normalized.mineralsCost > 0) normalized.mineralsCost -= 1;
  normalized.supplyCost = points - normalized.mineralsCost * 2 - normalized.honorCost * 5 - normalized.goldCost * 5;

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
  void balanceConfig;

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
          targetGoldUnits: typedUnits.filter((unit) => unit.goldCost > 0).length
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
  void units;
  void assignmentByUnit;
  return new Set(balanceConfig.supplyOnlyUnitSlugs ?? []);
}

export function primaryUnitType(unit) {
  const keywords = unit.unitKeywords ?? [];
  if (keywords.includes("Caracter")) return "Caracter";
  if (keywords.includes("Vehiculo") || keywords.includes("Aeronave") || keywords.includes("Fortificacion")) return "Vehiculo";
  if (keywords.includes("Monstruo")) return "Monstruo";
  if (keywords.includes("Bestia")) return "Bestia";
  if (keywords.includes("Montado")) return "Montado";
  if (keywords.includes("Infanteria")) return "Infanteria";
  return "Otro";
}

export function getUnitCostRule(unit, balanceConfig = {}) {
  const slug = unitSlug(unit);
  const factionSlug = factionSlugForUnit(unit);
  const supplyOnly = new Set(balanceConfig.supplyOnlyUnitSlugs ?? []).has(slug);
  const configuredGoldShare = Number(balanceConfig.goldShareByUnitSlug?.[slug] ?? 0);
  const isNamedCharacter = Boolean(unit.isNamedCharacter) || new Set(balanceConfig.namedAlliedCharacterSlugs ?? []).has(slug);
  const alliedGoldShare = configuredGoldShare <= 0 && alliedUnitQualifiesForGold(unit, isNamedCharacter) ? 0.2 : 0;
  const goldShare = supplyOnly ? 0 : configuredGoldShare || alliedGoldShare;
  const characterHonorShare = Number(
    balanceConfig.characterHonorShareByUnitSlug?.[slug] ??
      balanceConfig.characterHonorShareByFaction?.[factionSlug] ??
      balanceConfig.characterHonorShareByFaction?.default ??
      0.5
  );

  return {
    supplyOnly,
    goldShare,
    characterHonorShare,
    isAllied: unit.category === "Aliada" || Boolean(unit.isAlliedUnit),
    isNamedCharacter
  };
}

export function costsFromPointShares(points, shares) {
  const safePoints = Math.max(0, Math.trunc(Number(points ?? 0)));
  const normalizedShares = COST_RESOURCE_KEYS.reduce((result, key) => {
    const share = Math.max(0, Number(shares?.[key] ?? 0));
    if (share > 0) result[key] = share;
    return result;
  }, {});
  const activeKeys = COST_RESOURCE_KEYS.filter((key) => normalizedShares[key] > 0);

  if (activeKeys.length === 0 || safePoints === 0) {
    return { supplyCost: safePoints, mineralsCost: 0, honorCost: 0, goldCost: 0 };
  }

  const shareTotal = activeKeys.reduce((sum, key) => sum + normalizedShares[key], 0);
  const cheapestKey = [...activeKeys].sort((left, right) => resourcePointValue(left) - resourcePointValue(right))[0];
  const result = { supplyCost: 0, mineralsCost: 0, honorCost: 0, goldCost: 0 };

  for (const key of activeKeys) {
    if (key === cheapestKey) continue;
    const targetPoints = (safePoints * normalizedShares[key]) / shareTotal;
    result[key] = Math.max(1, Math.floor(targetPoints / resourcePointValue(key)));
  }

  const allocatedPoints = warhammerPointValue(result);
  const cheapestValue = resourcePointValue(cheapestKey);
  result[cheapestKey] = Math.max(1, Math.ceil(Math.max(0, safePoints - allocatedPoints) / cheapestValue));
  return result;
}

function pointSharesForUnit(unit, rule, balanceConfig) {
  const type = primaryUnitType(unit);
  const points = Number(unit.points ?? 0);
  const factionSlug = factionSlugForUnit(unit);
  let baseProfile;

  if (type === "Caracter") {
    const honor = rule.characterHonorShare;
    const supplyToMinerals = points < 75 ? [0.7, 0.3] : [0.5, 0.5];
    const nonHonorAndGold = Math.max(0, 1 - honor - rule.goldShare);
    const characterGoldRatio = points < 75 ? [0.8, 0.2] : [0.6, 0.4];
    const ratio = rule.goldShare > 0 ? characterGoldRatio : supplyToMinerals;
    baseProfile = {
      supplyCost: nonHonorAndGold * ratio[0],
      mineralsCost: nonHonorAndGold * ratio[1],
      honorCost: honor,
      goldCost: rule.goldShare
    };
  } else {
    const nonGoldProfile = nonCharacterPointShares(type, points, factionSlug);
    const availableShare = Math.max(0, 1 - rule.goldShare);
    baseProfile = {
      supplyCost: nonGoldProfile.supply * availableShare,
      mineralsCost: nonGoldProfile.minerals * availableShare,
      honorCost: 0,
      goldCost: rule.goldShare
    };
  }

  void balanceConfig;
  return baseProfile;
}

function nonCharacterPointShares(type, points, factionSlug) {
  if (type === "Vehiculo") return { supply: 0, minerals: 1 };
  if (type === "Monstruo") return { supply: 0.2, minerals: 0.8 };

  if (factionSlug === "necrones" && ["Infanteria", "Bestia", "Montado"].includes(type)) {
    if (type === "Bestia" && points >= 200) return { supply: 0, minerals: 1 };
    if (points < 65) return { supply: 0.7, minerals: 0.3 };
    if (points <= 115) return { supply: 0.5, minerals: 0.5 };
    if (points <= 190) return { supply: 0.4, minerals: 0.6 };
    return { supply: 0.1, minerals: 0.9 };
  }

  if (type === "Bestia" && points >= 200) return { supply: 0.5, minerals: 0.5 };
  if (["Infanteria", "Bestia", "Montado", "Otro"].includes(type)) {
    if (points < 65) return { supply: 0.9, minerals: 0.1 };
    if (points <= 115) return { supply: 0.8, minerals: 0.2 };
    if (points <= 190) return { supply: 0.7, minerals: 0.3 };
    return { supply: 0.6, minerals: 0.4 };
  }

  return { supply: 1, minerals: 0 };
}

function alliedUnitQualifiesForGold(unit, isNamedCharacter) {
  const isAllied = unit.category === "Aliada" || Boolean(unit.isAlliedUnit);
  if (!isAllied) return false;

  const type = primaryUnitType(unit);
  const points = Number(unit.points ?? 0);
  if (type === "Caracter") return points > 90 || isNamedCharacter;
  if (type === "Infanteria" || type === "Montado") return points >= 120;
  if (type === "Vehiculo" || type === "Monstruo") return points >= 170;
  return false;
}

function pickUnitCosts(value) {
  return {
    supplyCost: Number(value.supplyCost ?? 0),
    mineralsCost: Number(value.mineralsCost ?? 0),
    honorCost: Number(value.honorCost ?? 0),
    goldCost: Number(value.goldCost ?? 0)
  };
}

function resourcePointValue(key) {
  if (key === "supplyCost") return 1;
  if (key === "mineralsCost") return 2;
  return 5;
}

function emptyUnitCosts(points) {
  return {
    supplyCost: Math.max(0, Math.trunc(Number(points ?? 0))),
    mineralsCost: 0,
    honorCost: 0,
    goldCost: 0
  };
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
