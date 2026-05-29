import { create } from "zustand";

interface CampaignUiState {
  selectedSystemId: string | null;
  hoveredSystemId: string | null;
  tooltipPosition: { x: number; y: number } | null;
  movementOriginSystemId: string | null;
  activeArmyId: string | null;
  setSelectedSystem: (systemId: string | null) => void;
  setHoveredSystem: (systemId: string | null) => void;
  setTooltipPosition: (position: { x: number; y: number } | null) => void;
  startMovementMode: (armyId: string, originSystemId: string) => void;
  cancelMovementMode: () => void;
}

export const useCampaignUiStore = create<CampaignUiState>((set) => ({
  selectedSystemId: "kharon-prime",
  hoveredSystemId: null,
  tooltipPosition: null,
  movementOriginSystemId: null,
  activeArmyId: null,
  setSelectedSystem: (selectedSystemId) => set({ selectedSystemId }),
  setHoveredSystem: (hoveredSystemId) => set({ hoveredSystemId }),
  setTooltipPosition: (tooltipPosition) => set({ tooltipPosition }),
  startMovementMode: (activeArmyId, movementOriginSystemId) =>
    set({ activeArmyId, movementOriginSystemId }),
  cancelMovementMode: () => set({ activeArmyId: null, movementOriginSystemId: null })
}));
