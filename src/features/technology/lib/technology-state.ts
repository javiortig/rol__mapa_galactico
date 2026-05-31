import type { CampaignSnapshot, ResourceKey, TechnologyNode, UnitCategory, UnitTemplate } from "@/domain/campaign";

export type DerivedTechnologyStatus = "locked" | "available" | "researching" | "unlocked";

const resources: ResourceKey[] = ["supply", "minerals", "ancestralStone", "uridium", "technology"];

export function getFactionTechnology(snapshot: CampaignSnapshot, technologyNodeId: string) {
  return snapshot.factionTechnologies.find(
    (item) => item.factionId === snapshot.currentUser.factionId && item.technologyNodeId === technologyNodeId
  );
}

export function getTechnologyStatus(snapshot: CampaignSnapshot, node: TechnologyNode): DerivedTechnologyStatus {
  const progress = getFactionTechnology(snapshot, node.id);

  if (progress?.status) {
    return progress.status;
  }

  return areTechnologyPrerequisitesUnlocked(snapshot, node.id) ? "available" : "locked";
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

export function getRequiredTechnologyName(snapshot: CampaignSnapshot, technologyNodeId?: string | null) {
  if (!technologyNodeId) {
    return null;
  }

  return snapshot.technologyNodes.find((node) => node.id === technologyNodeId)?.name ?? "Tecnologia requerida";
}

export function getActiveTechnologyResearch(snapshot: CampaignSnapshot) {
  return snapshot.factionTechnologies.find(
    (item) => item.factionId === snapshot.currentUser.factionId && item.status === "researching"
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

export function getBaseRecruitmentCost(template: UnitTemplate, resource: ResourceKey) {
  const costs: Record<ResourceKey, number> = {
    supply: template.supplyCost,
    minerals: template.mineralsCost,
    ancestralStone: template.ancestralStoneCost,
    uridium: template.uridiumCost,
    technology: template.technologyCost
  };

  return costs[resource];
}

export function getVisibleRecruitmentCostResources(snapshot: CampaignSnapshot, template: UnitTemplate) {
  return resources.filter(
    (resource) => getBaseRecruitmentCost(template, resource) > 0 || getRecruitmentCost(snapshot, template, resource) > 0
  );
}

function areTechnologyPrerequisitesUnlocked(snapshot: CampaignSnapshot, technologyNodeId: string) {
  const prerequisites = snapshot.technologyPrerequisites.filter((item) => item.technologyNodeId === technologyNodeId);

  return prerequisites.every((prerequisite) => isTechnologyUnlocked(snapshot, prerequisite.requiredNodeId));
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
