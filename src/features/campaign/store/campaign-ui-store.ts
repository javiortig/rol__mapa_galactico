import { create } from "zustand";

interface CampaignUiState {
  selectedSystemId: string | null;
  hoveredSystemId: string | null;
  tooltipPosition: { x: number; y: number } | null;
  movementOriginSystemId: string | null;
  setSelectedSystem: (systemId: string | null) => void;
  setHoveredSystem: (systemId: string | null) => void;
  setTooltipPosition: (position: { x: number; y: number } | null) => void;
  startMovementMode: (originSystemId: string) => void;
  cancelMovementMode: () => void;
}

export const useCampaignUiStore = create<CampaignUiState>((set) => ({
  selectedSystemId: null,
  hoveredSystemId: null,
  tooltipPosition: null,
  movementOriginSystemId: null,
  setSelectedSystem: (selectedSystemId) => set({ selectedSystemId }),
  setHoveredSystem: (hoveredSystemId) => set({ hoveredSystemId }),
  setTooltipPosition: (tooltipPosition) => set({ tooltipPosition }),
  startMovementMode: (movementOriginSystemId) => set({ movementOriginSystemId }),
  cancelMovementMode: () => set({ movementOriginSystemId: null })
}));
