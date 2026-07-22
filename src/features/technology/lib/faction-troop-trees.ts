import troopTreeConfig from "../../../../data/technology/faction-troop-trees.json";
import type { CampaignSnapshot, Faction, TechnologyNode } from "@/domain/campaign";

export type TroopTreeStatus = "draft" | "ready";

export type TroopTreeDefinition = {
  factionSlug: string;
  treeKey: string;
  status: TroopTreeStatus;
};

const commonTreeKey = troopTreeConfig.commonTreeKey;
const troopTrees = troopTreeConfig.trees as TroopTreeDefinition[];
const troopTreeByFactionSlug = new Map(troopTrees.map((tree) => [tree.factionSlug, tree]));
const troopTreeKeys = new Set(troopTrees.map((tree) => tree.treeKey));

export function getCommonTechnologyTreeKey() {
  return commonTreeKey;
}

export function getTroopTreeDefinitions() {
  return troopTrees;
}

export function getTroopTreeKeyForFactionSlug(factionSlug?: string | null) {
  return factionSlug ? troopTreeByFactionSlug.get(factionSlug)?.treeKey ?? null : null;
}

export function isTroopTechnologyTreeKey(treeKey: string) {
  return troopTreeKeys.has(treeKey) || /^troops-[a-z0-9-]+-v\d+$/.test(treeKey);
}

export function getVisibleTechnologyTreeKeys({
  factions,
  inspectedFactionId
}: {
  factions: Faction[];
  inspectedFactionId?: string | null;
}) {
  const visibleTreeKeys = new Set([commonTreeKey]);
  const inspectedFaction = factions.find((faction) => faction.id === inspectedFactionId);
  const factionSlug = inspectedFaction?.slug ?? inspectedFaction?.id ?? null;
  const troopTreeKey = getTroopTreeKeyForFactionSlug(factionSlug);

  if (troopTreeKey) {
    visibleTreeKeys.add(troopTreeKey);
  }

  return visibleTreeKeys;
}

export function getTechnologyInspectionFaction(snapshot: CampaignSnapshot, selectedFactionId?: string | null) {
  if (snapshot.currentUser.role !== "admin") {
    return snapshot.factions.find((faction) => faction.id === snapshot.currentUser.factionId) ?? null;
  }

  const selectedFaction = snapshot.factions.find((faction) => faction.id === selectedFactionId);

  if (selectedFaction) {
    return selectedFaction;
  }

  return (
    snapshot.factions.find((faction) => Boolean(getTroopTreeKeyForFactionSlug(faction.id))) ??
    snapshot.factions.find((faction) => Boolean(getTroopTreeKeyForFactionSlug(faction.slug))) ??
    snapshot.factions[0] ??
    null
  );
}

export function isTechnologyNodeVisibleForTreeKeys(node: TechnologyNode, visibleTreeKeys: Set<string>) {
  return visibleTreeKeys.has(node.treeKey);
}
