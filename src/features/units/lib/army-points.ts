import type { CampaignSnapshot } from "@/domain/campaign";

export function getFactionArmyPoints(snapshot: CampaignSnapshot, factionId: string | null | undefined) {
  if (!factionId) {
    return 0;
  }

  return getLivingUnitPoints(snapshot, factionId) + getQueuedRecruitmentPoints(snapshot, factionId);
}

export function getLivingUnitPoints(snapshot: CampaignSnapshot, factionId: string) {
  return snapshot.units
    .filter((unit) => unit.factionId === factionId && unit.status !== "destroyed" && unit.quantity > 0)
    .reduce((total, unit) => total + unit.points, 0);
}

export function getQueuedRecruitmentPoints(snapshot: CampaignSnapshot, factionId: string) {
  return snapshot.recruitmentQueue
    .filter((item) => item.factionId === factionId && item.status === "queued")
    .reduce((total, item) => {
      const template = snapshot.unitTemplates.find((unitTemplate) => unitTemplate.id === item.unitTemplateId);
      return total + (item.selectedPoints ?? template?.points ?? 0) * item.quantity;
    }, 0);
}
