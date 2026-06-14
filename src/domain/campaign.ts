export type Role = "admin" | "player" | "spectator";

export type SystemStatus = "neutral" | "controlled" | "war";

export type UnitStatus = "ready" | "moving" | "in_war" | "destroyed" | "retreat_pending" | "recovering";

export type RecruitmentStatus = "queued" | "completed" | "cancelled";

export type MovementStatus = "moving" | "arrived" | "cancelled";

export type TechnologyStatus = "available" | "researching" | "unlocked";

export type TechnologyImplementationStatus = "active" | "planned" | "deprecated";

export type StarClass = "blue" | "white" | "yellow" | "orange" | "red" | "violet" | "green";

export type StarSystemKind = "standard" | "gaseous";

export type UnitCategory =
  | "Infantería"
  | "Élite"
  | "Vehículo"
  | "Infanteria"
  | "Elite"
  | "Vehiculo"
  | "Personaje"
  | "Monstruo"
  | "Superpesado"
  | "Otro";

export type UnitType = "beast" | "vehicle" | "character" | "infantry" | "mounted";

export type ResourceKey = "supply" | "minerals" | "honor" | "gold" | "industrialMaterial" | "uridium" | "technology";

export type TradeableResourceKey = "supply" | "minerals" | "industrialMaterial" | "uridium";

export type TradeOfferType = "buy" | "sell";

export type TradeOfferStatus = "open" | "accepted" | "cancelled";

export type ResourceBundle = Record<ResourceKey, number>;

export type BuildingStatus = "constructing" | "active" | "disabled";

export type BuildingKind = "recruitment" | "commerce" | "intelligence" | "production" | "relic";

export type RecoveryStatus = "queued" | "completed" | "cancelled";

export type RelicRarity = "common" | "rare" | "epic" | "legendary";

export interface Faction {
  id: string;
  name: string;
  color: string;
  emblemUrl?: string | null;
  capitalSystemId?: string | null;
}

export interface StarSystem {
  id: string;
  name: string;
  x: number;
  y: number;
  size: number;
  starClass?: StarClass;
  systemKind: StarSystemKind;
  isConquerable: boolean;
  allowsSharedOccupation: boolean;
  type: string;
  status: SystemStatus;
  controllerFactionId?: string | null;
  blockedUntil?: string | null;
  publicDescription: string;
  secretAdminNotes?: string | null;
  missionId?: string | null;
  isCapital: boolean;
  buildingSlots?: number;
  production: ResourceBundle;
  specialObjects?: SystemSpecialObject[];
}

export interface SystemSpecialObject {
  id: string;
  name: string;
  type: "relic" | "technology" | "resource" | "anomaly";
  isPublic: boolean;
}

export interface SystemEdge {
  id: string;
  fromSystemId: string;
  toSystemId: string;
  uridiumCost: number;
  isBlocked?: boolean;
}

export interface FactionResources extends ResourceBundle {
  factionId: string;
  updatedAt: string;
}

export interface CampaignUnit {
  id: string;
  factionId: string;
  unitTemplateId?: string | null;
  name: string;
  currentSystemId?: string | null;
  status: UnitStatus;
  category: UnitCategory;
  unitType: UnitType;
  points: number;
  quantity: number;
  startingQuantity: number;
  woundsTaken: number;
  experience: number;
  isVisiblePublicly: boolean;
  parentUnitId?: string | null;
  destroyedAt?: string | null;
  rank?: string | null;
  enhancementText?: string | null;
  notes?: string | null;
}

export interface UnitMovementSelection {
  unitId: string;
  quantity: number;
}

export interface MovementOrder {
  id: string;
  unitIds: string[];
  unitSelections: UnitMovementSelection[];
  factionId: string;
  fromSystemId: string;
  toSystemId: string;
  pathSystemIds: string[];
  uridiumCost: number;
  segmentCount: number;
  durationSeconds: number;
  startedAt: string;
  arrivalAt: string;
  status: MovementStatus;
  cancelledAt?: string | null;
}

export interface RecruitmentQueueItem {
  id: string;
  factionId: string;
  unitTemplateId: string;
  unitName: string;
  quantity: number;
  systemBuildingId?: string | null;
  originSystemId?: string | null;
  supplyCost: number;
  mineralsCost: number;
  honorCost: number;
  goldCost: number;
  industrialMaterialCost: number;
  uridiumCost: number;
  technologyCost: number;
  startedAt: string;
  finishesAt: string;
  status: RecruitmentStatus;
}

export interface UnitTemplate {
  id: string;
  factionId: string;
  name: string;
  category: UnitCategory;
  unitType: UnitType;
  points: number;
  defaultQuantity: number;
  woundsPerModel: number;
  supplyCost: number;
  mineralsCost: number;
  honorCost: number;
  goldCost: number;
  industrialMaterialCost: number;
  uridiumCost: number;
  technologyCost: number;
  recruitmentTimeSeconds: number;
  recruitmentBuildingType?: string | null;
  notes?: string | null;
  isAvailable: boolean;
  requiredTechnologyNodeId?: string | null;
}

export interface TradeOffer {
  id: string;
  creatorFactionId: string;
  offerType: TradeOfferType;
  resourceKey: TradeableResourceKey;
  resourceAmount: number;
  goldAmount: number;
  feeGold: number;
  status: TradeOfferStatus;
  acceptedByFactionId?: string | null;
  createdAt: string;
  acceptedAt?: string | null;
  cancelledAt?: string | null;
  isReserved: boolean;
}

export interface TechnologyNode {
  id: string;
  slug: string;
  treeKey: string;
  name: string;
  description: string;
  branch: string;
  tier: number;
  positionX: number;
  positionY: number;
  costTechnology: number;
  researchTimeSeconds: number;
  iconKey?: string | null;
  effectSummary?: string | null;
  isStarter: boolean;
  implementationStatus: TechnologyImplementationStatus;
}

export interface TechnologyPrerequisite {
  technologyNodeId: string;
  requiredNodeId: string;
  prerequisiteGroup: number;
}

export interface FactionTechnology {
  factionId: string;
  technologyNodeId: string;
  status: TechnologyStatus;
  startedAt?: string | null;
  finishesAt?: string | null;
  unlockedAt?: string | null;
}

export interface TechnologyEffect {
  id: string;
  technologyNodeId: string;
  effectType: string;
  payload: Record<string, unknown>;
}

export interface BuildingTemplate {
  id: string;
  slug: string;
  name: string;
  category: string;
  description: string;
  buildingKind: BuildingKind;
  supplyCost: number;
  mineralsCost: number;
  honorCost: number;
  goldCost: number;
  industrialMaterialCost: number;
  uridiumCost: number;
  technologyCost: number;
  constructionTimeSeconds: number;
  producedResourceKey?: ResourceKey | null;
  producedAmount: number;
  allowedUnitCategories: UnitCategory[];
  iconKey?: string | null;
  requiredTechnologyNodeId?: string | null;
  isAvailable: boolean;
}

export interface SystemBuilding {
  id: string;
  systemId: string;
  buildingTemplateId?: string | null;
  status: BuildingStatus;
  detailsVisible?: boolean;
  startedAt?: string | null;
  finishesAt?: string | null;
  constructedAt?: string | null;
}

export interface SystemResourceCapability {
  systemId: string;
  resourceKey: ResourceKey;
  productionAmount: number;
}

export interface UnitRecoveryQueueItem {
  id: string;
  factionId: string;
  systemBuildingId: string;
  campaignUnitId: string;
  unitName: string;
  healQuantity: number;
  supplyCost: number;
  mineralsCost: number;
  honorCost: number;
  goldCost: number;
  industrialMaterialCost: number;
  uridiumCost: number;
  technologyCost: number;
  startedAt: string;
  finishesAt: string;
  status: RecoveryStatus;
}

export interface CampaignRelic {
  id: string;
  slug?: string | null;
  factionId?: string | null;
  systemId?: string | null;
  equippedUnitId?: string | null;
  name: string;
  description: string;
  effectText?: string | null;
  iconKey?: string | null;
  rarity: RelicRarity;
  isPublic: boolean;
  equippedAt?: string | null;
  createdAt?: string | null;
}

export interface Conflict {
  id: string;
  systemId: string;
  attackerFactionId: string;
  defenderFactionId?: string | null;
  status: "pending" | "resolved" | "cancelled";
  winnerFactionId?: string | null;
  blockedUntil?: string | null;
  notes?: string | null;
}

export interface BattleReport {
  id: string;
  conflictId: string;
  reporterFactionId?: string | null;
  winnerFactionId?: string | null;
  finalControllerFactionId?: string | null;
  status: "submitted" | "auto_confirmed" | "admin_confirmed" | "disputed" | "rejected";
  casualties?: Record<string, number> | null;
  survivors?: Record<string, number> | null;
  woundsRemaining?: Record<string, number> | null;
  narrativeNotes?: string | null;
}

export interface Mission {
  id: string;
  systemId: string;
  title: string;
  narrativeDescription: string;
  objectives: string;
  specialRules: string;
  victoryConditions: string;
  mapImageUrl?: string | null;
}

export interface CampaignSnapshot {
  currentUser: {
    id: string;
    displayName: string;
    role: Role;
    factionId: string | null;
  };
  resourceTickIntervalHours: number;
  nextResourceTickAt: string;
  resourceCaps: ResourceBundle;
  maxArmyPoints: number;
  factions: Faction[];
  systems: StarSystem[];
  edges: SystemEdge[];
  resources: FactionResources[];
  units: CampaignUnit[];
  movements: MovementOrder[];
  unitTemplates: UnitTemplate[];
  recruitmentQueue: RecruitmentQueueItem[];
  technologyNodes: TechnologyNode[];
  technologyPrerequisites: TechnologyPrerequisite[];
  factionTechnologies: FactionTechnology[];
  technologyEffects: TechnologyEffect[];
  buildingTemplates: BuildingTemplate[];
  systemBuildings: SystemBuilding[];
  systemResourceCapabilities: SystemResourceCapability[];
  unitRecoveryQueue: UnitRecoveryQueueItem[];
  relics: CampaignRelic[];
  tradeOffers: TradeOffer[];
  conflicts: Conflict[];
  battleReports: BattleReport[];
  missions: Mission[];
}
