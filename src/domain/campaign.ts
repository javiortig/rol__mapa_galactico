export type Role = "admin" | "player" | "spectator";

export type CampaignTimingMode = "test" | "campaign";

export type SystemStatus = "neutral" | "controlled" | "war";

export type UnitStatus = "ready" | "moving" | "in_war" | "destroyed" | "retreat_pending" | "recovering";

export type RecruitmentStatus = "queued" | "completed" | "cancelled";

export type MovementStatus = "pending_approval" | "moving" | "arrived" | "in_battle" | "resolved" | "cancelled";

export type MovementType = "move" | "attack";

export type MovementPurpose = "normal" | "attack" | "coalition_staging" | "defense_support" | "battle_return";

export type PassageRequestStatus = "pending" | "accepted" | "rejected";

export type BattleOperationMode = "solo" | "coalition";

export type BattleOperationStatus = "assembling" | "moving" | "in_battle" | "resolved" | "cancelled";

export type BattleSide = "attacker" | "defender";

export type NarrativeAttackStatus = "incoming" | "arrived" | "cancelled";

export type TemporaryMissionStatus = "active" | "expired" | "completed" | "removed";

export type BattleInvitationStatus = "invited" | "accepted" | "rejected" | "closed";

export type BattleCommitmentStatus =
  | "staged"
  | "en_route"
  | "in_battle"
  | "returning"
  | "returned"
  | "destroyed"
  | "cancelled"
  | "return_pending";

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
  | "L\u00ednea de batalla"
  | "Linea de batalla"
  | "Transporte"
  | "Otras hojas de datos"
  | "Hoja de datos"
  | "Aliada"
  | "Monstruo"
  | "Superpesado"
  | "Otro";

export type UnitType = "beast" | "vehicle" | "character" | "infantry" | "mounted";

export type UnitKeyword = "Vehiculo" | "Caracter" | "Infanteria" | "Bestia" | "Montado" | "Aeronave" | "Fortificacion";

export type ResourceKey = "supply" | "minerals" | "honor" | "gold" | "industrialMaterial" | "uridium" | "technology";

export type TradeableResourceKey = "supply" | "minerals" | "industrialMaterial" | "uridium";

export type TradeOfferType = "buy" | "sell";

export type TradeOfferStatus = "open" | "accepted" | "cancelled";

export type ResourceBundle = Record<ResourceKey, number>;

export type BuildingStatus = "constructing" | "active" | "disabled";

export type BuildingKind = "recruitment" | "commerce" | "intelligence" | "production" | "relic";

export type RecoveryStatus = "queued" | "completed" | "cancelled";

export type RelicRarity = "common" | "rare" | "epic" | "legendary";

export type BattleResolutionMode = "tabletop" | "autoresolve";

export type BattleReportStatus =
  | "draft"
  | "awaiting_validation"
  | "players_confirmed"
  | "submitted"
  | "auto_confirmed"
  | "admin_confirmed"
  | "disputed"
  | "rejected";

export interface Faction {
  id: string;
  slug?: string | null;
  name: string;
  color: string;
  emblemUrl?: string | null;
  capitalSystemId?: string | null;
  isNarrative?: boolean;
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
  isTemporaryMission?: boolean;
  missionThreatFactionId?: string | null;
  missionEnemyUnitsVisible?: boolean;
  missionEnemyUnits?: NarrativeMissionEnemyUnit[];
  missionExpiresAt?: string | null;
  missionExpiresAfterBattle?: boolean;
  temporaryMissionStatus?: TemporaryMissionStatus;
  temporaryMissionClosedAt?: string | null;
  production: ResourceBundle;
  specialObjects?: SystemSpecialObject[];
}

export interface NarrativeMissionEnemyUnit {
  id: string;
  name: string;
  details?: string | null;
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
  unitKeywords: UnitKeyword[];
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
  selectedModelOptionId?: string | null;
  selectedWargearPoints?: number;
  selectedWargearOptions?: RecruitmentWargearSelection[];
  pointCostBreakdown?: Record<string, unknown>;
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
  defenderFactionId?: string | null;
  fromSystemId: string;
  toSystemId: string;
  movementType: MovementType;
  movementPurpose: MovementPurpose;
  battleOperationId?: string | null;
  pathSystemIds: string[];
  uridiumCost: number;
  segmentCount: number;
  durationSeconds: number;
  startedAt: string;
  departureAt?: string | null;
  arrivalAt?: string | null;
  status: MovementStatus;
  cancelledAt?: string | null;
  cancellationReason?: string | null;
  resolvedAt?: string | null;
}

export interface MovementPassageRequest {
  id: string;
  movementOrderId: string;
  responderFactionId: string;
  traversedSystemIds: string[];
  status: PassageRequestStatus;
  responseReason?: string | null;
  respondedByUserId?: string | null;
  respondedAt?: string | null;
  createdAt: string;
}

export interface BattleLimitSummary {
  factionId: string | null;
  monthStart: string;
  monthEnd: string;
  startedAttacks: number;
  receivedAttacks: number;
  totalParticipations: number;
  activeBattles: number;
  maxStartedAttacks: number;
  maxReceivedAttacks: number;
  maxTotalParticipations: number;
  maxActiveBattles: number;
}

export interface BattleOperation {
  id: string;
  mode: BattleOperationMode;
  status: BattleOperationStatus;
  leaderFactionId: string;
  defenderFactionId: string;
  originSystemId: string;
  targetSystemId: string;
  attackMovementOrderId?: string | null;
  conflictId?: string | null;
  attackArrivalAt?: string | null;
  rosterLockedAt?: string | null;
  launchedAt?: string | null;
  resolvedAt?: string | null;
  cancelledAt?: string | null;
  cancellationReason?: string | null;
  createdAt: string;
}

export interface BattleOperationMember {
  id: string;
  operationId: string;
  factionId: string;
  side: BattleSide;
  role: "commander" | "supporter";
  invitationStatus: BattleInvitationStatus;
  invitedByFactionId?: string | null;
  invitedAt: string;
  respondedAt?: string | null;
}

export interface BattleUnitCommitment {
  id: string;
  operationId: string;
  unitId: string;
  factionId: string;
  side: BattleSide;
  role: "leader" | "supporter";
  homeSystemId: string;
  stagingSystemId: string;
  outboundMovementOrderId?: string | null;
  returnMovementOrderId?: string | null;
  outboundPathSystemIds: string[];
  returnPathSystemIds: string[];
  quantityAtCommitment: number;
  pointsAtCommitment: number;
  status: BattleCommitmentStatus;
  joinedAt: string;
  returnedAt?: string | null;
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
  selectedModelCount?: number | null;
  selectedPoints?: number | null;
  selectedModelOptionId?: string | null;
  selectedWargearPoints?: number;
  selectedWargearOptions?: RecruitmentWargearSelection[];
  pointCostBreakdown?: Record<string, unknown>;
}

export interface UnitTemplateModelOption {
  id: string;
  unitTemplateId: string;
  slug: string;
  label: string;
  models: number;
  minModels: number;
  maxModels: number;
  points: number;
  copyFrom: number;
  copyTo?: number | null;
  source: string;
  pointsChangeDirection?: "up" | "down" | null;
  pointsChangeAmount?: number | null;
}

export interface UnitTemplateWargearOption {
  id: string;
  unitTemplateId: string;
  slug: string;
  name: string;
  points: number;
  pricing: string;
  source: string;
  pointsChangeDirection?: "up" | "down" | null;
  pointsChangeAmount?: number | null;
}

export interface RecruitmentWargearSelection {
  slug: string;
  name?: string;
  points?: number;
  quantity: number;
  totalPoints?: number;
}

export interface UnitTemplate {
  id: string;
  factionId: string;
  name: string;
  category: UnitCategory;
  unitType: UnitType;
  unitKeywords: UnitKeyword[];
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
  sourceSection?: string | null;
  sourceFactionName?: string | null;
  isAlliedUnit?: boolean;
  modelOptions?: UnitTemplateModelOption[];
  wargearOptions?: UnitTemplateWargearOption[];
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
  battleOperationId?: string | null;
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
  status: BattleReportStatus;
  battleMode: BattleResolutionMode;
  revision: number;
  participantValidations: Record<string, BattleReportValidation>;
  casualties?: Record<string, number> | null;
  survivors?: Record<string, number> | null;
  woundsRemaining?: Record<string, number> | null;
  narrativeNotes?: string | null;
  updatedAt?: string | null;
}

export interface BattleReportValidation {
  factionId: string;
  userId?: string | null;
  revision: number;
  confirmedAt?: string | null;
}

export interface NarrativeAttack {
  id: string;
  systemId: string;
  narrativeFactionId: string;
  description: string;
  arrivalAt: string;
  status: NarrativeAttackStatus;
  conflictId?: string | null;
  createdAt: string;
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

export interface CampaignEvent {
  id: string;
  slug: string;
  title: string;
  content: string;
  eventType: "manual" | "battle_result" | "system_unblocked" | "movement" | "narrative";
  systemId?: string | null;
  conflictId?: string | null;
  createdByUserId?: string | null;
  isPublic: boolean;
  createdAt: string;
}

export interface CampaignSnapshot {
  currentUser: {
    id: string;
    displayName: string;
    role: Role;
    factionId: string | null;
  };
  timingMode: CampaignTimingMode;
  resourceTickIntervalHours: number;
  movementEdgeDurationSeconds: number;
  attackDurationSeconds: number;
  battlePointsLimit: number;
  nextResourceTickAt: string;
  resourceCaps: ResourceBundle;
  maxArmyPoints: number;
  factions: Faction[];
  systems: StarSystem[];
  edges: SystemEdge[];
  resources: FactionResources[];
  units: CampaignUnit[];
  movements: MovementOrder[];
  passageRequests: MovementPassageRequest[];
  battleLimits: BattleLimitSummary | null;
  battleOperations: BattleOperation[];
  battleOperationMembers: BattleOperationMember[];
  battleUnitCommitments: BattleUnitCommitment[];
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
  narrativeAttacks: NarrativeAttack[];
  missions: Mission[];
  campaignEvents: CampaignEvent[];
}
