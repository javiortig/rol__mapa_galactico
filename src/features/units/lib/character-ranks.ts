import type { CampaignUnit, UnitKeyword } from "@/domain/campaign";

export const unitKeywordLabels: Record<UnitKeyword, string> = {
  Vehiculo: "Vehiculo",
  Caracter: "Caracter",
  Infanteria: "Infanteria",
  Bestia: "Bestia",
  Montado: "Montado"
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

export function isCharacterUnit(unit: Pick<CampaignUnit, "unitKeywords" | "unitType">) {
  return unit.unitKeywords.includes("Caracter") || unit.unitType === "character";
}

export function formatUnitKeywords(unit: Pick<CampaignUnit, "unitKeywords" | "unitType">) {
  const fallbackKeywords: UnitKeyword[] = unit.unitType === "character" ? ["Infanteria", "Caracter"] : ["Infanteria"];
  const keywords: UnitKeyword[] = unit.unitKeywords.length > 0 ? unit.unitKeywords : fallbackKeywords;

  return keywords.map((keyword) => unitKeywordLabels[keyword]).join(" / ");
}

export function getCharacterRank(unit: CampaignUnit) {
  if (!isCharacterUnit(unit)) {
    return null;
  }

  return characterRanks[getCharacterLevel(unit) - 1] ?? characterRanks[0];
}

export function getCharacterRelicSlots(unit: CampaignUnit) {
  if (!isCharacterUnit(unit)) {
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
