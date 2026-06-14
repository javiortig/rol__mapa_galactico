import type { CampaignUnit, UnitType } from "@/domain/campaign";

export const unitTypeLabels: Record<UnitType, string> = {
  beast: "Beast",
  vehicle: "Vehicle",
  character: "Character",
  infantry: "Infantry",
  mounted: "Mounted"
};

const characterRanks = [
  "Oficial",
  "Oficial Veterano",
  "Campeon",
  "Capitan",
  "Comandante",
  "Senor de Guerra",
  "Alto Senor",
  "Heroe de Cruzada",
  "Leyenda de Guerra",
  "Leyenda del Sector"
];

export function getCharacterLevel(unit: CampaignUnit) {
  return Math.min(10, Math.max(1, unit.experience || 1));
}

export function getCharacterRank(unit: CampaignUnit) {
  if (unit.unitType !== "character") {
    return null;
  }

  return characterRanks[getCharacterLevel(unit) - 1] ?? characterRanks[0];
}

export function getCharacterRelicSlots(unit: CampaignUnit) {
  if (unit.unitType !== "character") {
    return 0;
  }

  const level = getCharacterLevel(unit);

  if (level >= 6) {
    return 2;
  }

  if (level >= 3) {
    return 1;
  }

  return 0;
}
