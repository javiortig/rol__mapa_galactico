export type Role = "admin" | "player" | "spectator";

export type SystemStatus = "neutral" | "controlled" | "war";

export type ArmyStatus = "ready" | "moving" | "in_war";

export type RecruitmentStatus = "queued" | "completed" | "cancelled";

export type MovementStatus = "moving" | "arrived" | "cancelled";

export type StarClass = "blue" | "white" | "yellow" | "orange" | "red" | "violet" | "green";

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

export type ResourceKey = "supply" | "minerals" | "ancestralStone" | "uridium" | "technology";

export type ResourceBundle = Record<ResourceKey, number>;

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
  type: string;
  status: SystemStatus;
  controllerFactionId?: string | null;
  blockedUntil?: string | null;
  publicDescription: string;
  secretAdminNotes?: string | null;
  missionId?: string | null;
  isCapital: boolean;
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

export interface Army {
  id: string;
  factionId: string;
  name: string;
  currentSystemId?: string | null;
  status: ArmyStatus;
  pointsTotal: number;
  isVisiblePublicly: boolean;
  units: ArmyUnit[];
}

export interface ArmyUnit {
  id: string;
  armyId: string;
  name: string;
  points: number;
  quantity: number;
  experience: number;
  rank?: string | null;
  enhancementText?: string | null;
  notes?: string | null;
}

export interface MovementOrder {
  id: string;
  armyId: string;
  factionId: string;
  fromSystemId: string;
  toSystemId: string;
  uridiumCost: number;
  startedAt: string;
  arrivalAt: string;
  status: MovementStatus;
}

export interface RecruitmentQueueItem {
  id: string;
  factionId: string;
  unitTemplateId: string;
  unitName: string;
  quantity: number;
  startedAt: string;
  finishesAt: string;
  status: RecruitmentStatus;
}

export interface UnitTemplate {
  id: string;
  factionId: string;
  name: string;
  category: UnitCategory;
  points: number;
  supplyCost: number;
  mineralsCost: number;
  ancestralStoneCost: number;
  uridiumCost: number;
  technologyCost: number;
  recruitmentTimeSeconds: number;
  notes?: string | null;
  isAvailable: boolean;
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
    factionId: string;
  };
  resourceTickIntervalHours: number;
  nextResourceTickAt: string;
  factions: Faction[];
  systems: StarSystem[];
  edges: SystemEdge[];
  resources: FactionResources[];
  armies: Army[];
  movements: MovementOrder[];
  unitTemplates: UnitTemplate[];
  recruitmentQueue: RecruitmentQueueItem[];
  conflicts: Conflict[];
  battleReports: BattleReport[];
  missions: Mission[];
}
