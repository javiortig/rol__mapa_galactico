import type { CampaignSnapshot } from "@/domain/campaign";

export function getSystemBattlePointsLimit(snapshot: CampaignSnapshot, systemId: string): number {
  return snapshot.systems.find((system) => system.id === systemId)?.battlePointsLimit ?? snapshot.battlePointsLimit;
}

export function getVisibleBattlePointsLimit(snapshot: CampaignSnapshot, systemId: string): number {
  return snapshot.conflicts.find((conflict) => conflict.systemId === systemId && conflict.status === "pending")
    ?.battlePointsLimit
    ?? snapshot.narrativeAttacks.find((attack) => attack.systemId === systemId && attack.status === "incoming")
      ?.battlePointsLimit
    ?? getSystemBattlePointsLimit(snapshot, systemId);
}
