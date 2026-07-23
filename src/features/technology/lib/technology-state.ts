import type { BuildingTemplate, CampaignSnapshot, ResourceKey, TechnologyNode, UnitCategory, UnitTemplate } from "@/domain/campaign";

export type DerivedTechnologyStatus = "locked" | "planned" | "available" | "researching" | "unlocked";

const resources: ResourceKey[] = ["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium", "technology"];

export function getFactionTechnology(snapshot: CampaignSnapshot, technologyNodeId: string, factionId = snapshot.currentUser.factionId) {
  return snapshot.factionTechnologies.find(
    (item) => item.factionId === factionId && item.technologyNodeId === technologyNodeId
  );
}

export function getTechnologyStatus(
  snapshot: CampaignSnapshot,
  node: TechnologyNode,
  factionId = snapshot.currentUser.factionId
): DerivedTechnologyStatus {
  if (node.implementationStatus === "planned") {
    return "planned";
  }

  if (node.implementationStatus === "deprecated") {
    return "locked";
  }

  const progress = getFactionTechnology(snapshot, node.id, factionId);

  if (progress?.status) {
    return progress.status;
  }

  return areTechnologyPrerequisitesUnlocked(snapshot, node.id, factionId) ? "available" : "locked";
}

export function isTechnologyUnlocked(snapshot: CampaignSnapshot, technologyNodeId?: string | null) {
  if (!technologyNodeId) {
    return true;
  }

  return getFactionTechnology(snapshot, technologyNodeId)?.status === "unlocked";
}

export function isUnitTemplateUnlocked(snapshot: CampaignSnapshot, template: UnitTemplate) {
  return isTechnologyUnlocked(snapshot, template.requiredTechnologyNodeId);
}

export function isBuildingTemplateUnlocked(snapshot: CampaignSnapshot, template: BuildingTemplate) {
  return isTechnologyUnlocked(snapshot, template.requiredTechnologyNodeId);
}

export function isTechnologyNodeVisible(node: TechnologyNode) {
  return node.implementationStatus !== "deprecated";
}

export function getRequiredTechnologyName(snapshot: CampaignSnapshot, technologyNodeId?: string | null) {
  if (!technologyNodeId) {
    return null;
  }

  return snapshot.technologyNodes.find((node) => node.id === technologyNodeId)?.name ?? "Tecnologia requerida";
}

export function getActiveTechnologyResearch(snapshot: CampaignSnapshot, factionId = snapshot.currentUser.factionId) {
  return snapshot.factionTechnologies.find(
    (item) => item.factionId === factionId && item.status === "researching"
  );
}

export function getRecruitmentCost(snapshot: CampaignSnapshot, template: UnitTemplate, resource: ResourceKey) {
  let cost = getBaseRecruitmentCost(template, resource);

  for (const effect of getUnlockedEffects(snapshot, "recruitment_cost_discount")) {
    if (!matchesCategory(effect.payload.category, template.category)) {
      continue;
    }

    if (!matchesResource(effect.payload.resource, resource)) {
      continue;
    }

    cost = applyDiscount(cost, toPercent(effect.payload.percent));
  }

  return cost;
}

export function getRecruitmentVariantCost(snapshot: CampaignSnapshot, template: UnitTemplate, points: number, resource: ResourceKey) {
  let cost = getBaseRecruitmentVariantCost(template, points, resource);

  for (const effect of getUnlockedEffects(snapshot, "recruitment_cost_discount")) {
    if (!matchesCategory(effect.payload.category, template.category)) {
      continue;
    }

    if (!matchesResource(effect.payload.resource, resource)) {
      continue;
    }

    cost = applyDiscount(cost, toPercent(effect.payload.percent));
  }

  return cost;
}

export function getRecruitmentDuration(snapshot: CampaignSnapshot, template: UnitTemplate, quantity: number) {
  let duration = template.recruitmentTimeSeconds * quantity;

  for (const effect of getUnlockedEffects(snapshot, "recruitment_time_discount")) {
    if (!matchesCategory(effect.payload.category, template.category)) {
      continue;
    }

    duration = Math.max(quantity, Math.ceil((duration * (100 - toPercent(effect.payload.percent))) / 100));
  }

  return duration;
}

export function hasUnlockedTechnologyEffect(snapshot: CampaignSnapshot, effectType: string) {
  return getUnlockedEffects(snapshot, effectType).length > 0;
}

export function getMerchantTradeRates(snapshot: CampaignSnapshot) {
  const effects = getUnlockedEffects(snapshot, "merchant_rate_modifier");
  const buyMultiplier = effects.reduce((current, effect) => {
    const value = Number(effect.payload.buyMultiplier ?? effect.payload.buy_multiplier ?? current);
    return Number.isFinite(value) && value > 0 ? Math.min(current, value) : current;
  }, 2);
  const sellMultiplier = effects.reduce((current, effect) => {
    const value = Number(effect.payload.sellMultiplier ?? effect.payload.sell_multiplier ?? current);
    return Number.isFinite(value) && value > 0 ? Math.max(current, value) : current;
  }, 0.5);

  return { buyMultiplier, sellMultiplier };
}

export function getStellarTradeFeePercent(snapshot: CampaignSnapshot) {
  return getUnlockedEffects(snapshot, "stellar_trade_fee_discount").reduce((current, effect) => {
    const value = Number(effect.payload.percent ?? current);
    return Number.isFinite(value) && value > 0 ? Math.min(current, value) : current;
  }, 30);
}

export function getStellarTradeFee(snapshot: CampaignSnapshot, goldAmount: number) {
  const amount = Math.max(0, Math.trunc(goldAmount));

  if (amount <= 0) {
    return 0;
  }

  return Math.max(1, Math.ceil((amount * getStellarTradeFeePercent(snapshot)) / 100));
}

export function getBaseRecruitmentCost(template: UnitTemplate, resource: ResourceKey) {
  const costs: Record<ResourceKey, number> = {
    supply: template.supplyCost,
    minerals: template.mineralsCost,
    honor: template.honorCost,
    gold: template.goldCost,
    industrialMaterial: template.industrialMaterialCost,
    uridium: template.uridiumCost,
    technology: template.technologyCost
  };

  return costs[resource];
}

export function getBaseRecruitmentVariantCost(template: UnitTemplate, points: number, resource: ResourceKey) {
  const costs = computeRecruitmentCostsForPoints(template, points);
  return costs[resource];
}

export function computeRecruitmentCostsForPoints(template: UnitTemplate, points: number) {
  const safePoints = Math.max(0, Math.trunc(points));
  const profile = getCostProfile(template);
  const minerals = Math.floor((safePoints * profile.minerals) / 2);
  const honor = Math.floor((safePoints * profile.honor) / 5);
  const gold = Math.floor((safePoints * profile.gold) / 5);
  const supply = safePoints - minerals * 2 - honor * 5 - gold * 5;

  return {
    supply,
    minerals,
    honor,
    gold,
    industrialMaterial: 0,
    uridium: 0,
    technology: 0
  } satisfies Record<ResourceKey, number>;
}

export function getBaseBuildingCost(template: BuildingTemplate, resource: ResourceKey) {
  const costs: Record<ResourceKey, number> = {
    supply: template.supplyCost,
    minerals: template.mineralsCost,
    honor: template.honorCost,
    gold: template.goldCost,
    industrialMaterial: template.industrialMaterialCost,
    uridium: template.uridiumCost,
    technology: template.technologyCost
  };

  return costs[resource];
}

export function getVisibleBuildingCostResources(template: BuildingTemplate) {
  return resources.filter((resource) => getBaseBuildingCost(template, resource) > 0);
}

export function getVisibleRecruitmentCostResources(snapshot: CampaignSnapshot, template: UnitTemplate) {
  return resources.filter(
    (resource) => getBaseRecruitmentCost(template, resource) > 0 || getRecruitmentCost(snapshot, template, resource) > 0
  );
}

export function getVisibleRecruitmentVariantCostResources(snapshot: CampaignSnapshot, template: UnitTemplate, points: number) {
  return resources.filter(
    (resource) =>
      getBaseRecruitmentVariantCost(template, points, resource) > 0 ||
      getRecruitmentVariantCost(snapshot, template, points, resource) > 0
  );
}

function areTechnologyPrerequisitesUnlocked(
  snapshot: CampaignSnapshot,
  technologyNodeId: string,
  factionId = snapshot.currentUser.factionId
) {
  const prerequisites = snapshot.technologyPrerequisites.filter((item) => item.technologyNodeId === technologyNodeId);

  if (prerequisites.length === 0) {
    return true;
  }

  const groups = new Map<number, typeof prerequisites>();

  for (const prerequisite of prerequisites) {
    const group = groups.get(prerequisite.prerequisiteGroup) ?? [];
    group.push(prerequisite);
    groups.set(prerequisite.prerequisiteGroup, group);
  }

  return [...groups.values()].every((group) =>
    group.some((prerequisite) => getFactionTechnology(snapshot, prerequisite.requiredNodeId, factionId)?.status === "unlocked")
  );
}

function getUnlockedEffects(snapshot: CampaignSnapshot, effectType: string) {
  const unlockedNodeIds = new Set(
    snapshot.factionTechnologies
      .filter((item) => item.factionId === snapshot.currentUser.factionId && item.status === "unlocked")
      .map((item) => item.technologyNodeId)
  );

  return snapshot.technologyEffects.filter(
    (effect) => effect.effectType === effectType && unlockedNodeIds.has(effect.technologyNodeId)
  );
}

function matchesCategory(rawCategory: unknown, category: UnitCategory) {
  const target = typeof rawCategory === "string" ? rawCategory : "all";
  return target === "all" || target === category;
}

function matchesResource(rawResource: unknown, resource: ResourceKey) {
  const target = typeof rawResource === "string" ? rawResource : "all";
  return target === "all" || target === resource;
}

function toPercent(value: unknown) {
  const numeric = Number(value ?? 0);
  return Math.max(0, Math.min(90, Number.isFinite(numeric) ? numeric : 0));
}

function applyDiscount(cost: number, percent: number) {
  if (cost <= 0 || percent <= 0) {
    return cost;
  }

  return Math.max(1, Math.floor((cost * (100 - percent)) / 100));
}

function getCostProfile(template: UnitTemplate) {
  if (template.unitKeywords.includes("Caracter") && template.unitKeywords.includes("Vehiculo")) {
    return { minerals: 0.45, honor: 0.3, gold: 0.1 };
  }

  if (template.unitKeywords.includes("Caracter")) {
    return { minerals: 0.25, honor: 0.35, gold: 0.15 };
  }

  if (
    template.unitKeywords.includes("Vehiculo") ||
    template.unitKeywords.includes("Aeronave") ||
    template.unitKeywords.includes("Fortificacion")
  ) {
    return { minerals: 0.7, honor: 0.1, gold: template.category === "Aliada" ? 0.1 : 0.05 };
  }

  if (template.unitKeywords.includes("Bestia")) {
    return { minerals: 0.15, honor: 0.3, gold: template.category === "Aliada" ? 0.05 : 0 };
  }

  if (template.unitKeywords.includes("Montado")) {
    return { minerals: 0.45, honor: 0.1, gold: template.category === "Aliada" ? 0.05 : 0 };
  }

  if (template.category === "Aliada") {
    return { minerals: 0.25, honor: 0.15, gold: 0.1 };
  }

  return { minerals: 0.2, honor: 0.05, gold: 0 };
}
