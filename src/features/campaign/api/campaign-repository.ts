import type {
  BattleReport,
  BuildingTemplate,
  CampaignUnit,
  CampaignSnapshot,
  Conflict,
  Faction,
  FactionTechnology,
  FactionResources,
  Mission,
  MovementOrder,
  RecruitmentQueueItem,
  ResourceBundle,
  ResourceKey,
  StarClass,
  StarSystem,
  SystemBuilding,
  SystemEdge,
  SystemResourceCapability,
  SystemSpecialObject,
  TechnologyEffect,
  TechnologyNode,
  TechnologyPrerequisite,
  TradeOffer,
  UnitRecoveryQueueItem,
  UnitCategory,
  UnitMovementSelection,
  UnitTemplate
} from "@/domain/campaign";
import {
  clearSupabaseAuthStorage,
  getSupabaseBrowserClient,
  isStaleSupabaseRefreshTokenError
} from "@/lib/supabase/client";
import { mockCampaignSnapshot } from "@/mocks/campaign-data";

type DbRow = Record<string, unknown>;

export class CampaignAuthRequiredError extends Error {
  constructor(message = "Necesitas iniciar sesion para acceder a la campana.") {
    super(message);
    this.name = "CampaignAuthRequiredError";
  }
}

export class CampaignDataUnavailableError extends Error {
  constructor(message = "No se pudo cargar la campana desde Supabase.") {
    super(message);
    this.name = "CampaignDataUnavailableError";
  }
}

const emptyResources: ResourceBundle = {
  supply: 0,
  minerals: 0,
  honor: 0,
  gold: 0,
  industrialMaterial: 0,
  uridium: 0,
  technology: 0
};

export async function getCampaignSnapshot(): Promise<CampaignSnapshot> {
  const supabase = getSupabaseBrowserClient();
  const allowMockFallback = canUseMockFallback();

  if (!supabase) {
    return getFallbackSnapshotOrThrow(allowMockFallback, "Supabase no esta configurado.");
  }

  try {
    const {
      data: { user }
    } = await supabase.auth.getUser();

    if (!user) {
      return getFallbackSnapshotOrThrow(allowMockFallback, "Necesitas iniciar sesion para acceder a la campana.", "auth");
    }

    await Promise.allSettled([
      supabase.rpc("resolve_resource_ticks"),
      supabase.rpc("resolve_building_construction"),
      supabase.rpc("resolve_movement_orders"),
      supabase.rpc("resolve_recruitment_queue"),
      supabase.rpc("resolve_unit_recovery_queue"),
      supabase.rpc("resolve_technology_research")
    ]);

    const [
      profileResult,
      playerFactionsResult,
      settingsResult,
      factionsResult,
      systemsResult,
      edgesResult,
      productionResult,
      specialObjectsResult,
      resourcesResult,
      unitsResult,
      movementsResult,
      movementUnitsResult,
      unitTemplatesResult,
      recruitmentQueueResult,
      technologyNodesResult,
      technologyPrerequisitesResult,
      factionTechnologiesResult,
      technologyEffectsResult,
      buildingTemplatesResult,
      systemBuildingsResult,
      systemResourceCapabilitiesResult,
      unitRecoveryQueueResult,
      tradeOffersResult,
      conflictsResult,
      battleReportsResult,
      missionsResult
    ] = await Promise.all([
      supabase.from("profiles").select("id, display_name, role").eq("id", user.id).maybeSingle(),
      supabase.from("player_factions").select("faction_id").eq("user_id", user.id).order("created_at"),
      supabase.from("campaign_settings").select("*").eq("id", "default").maybeSingle(),
      supabase.from("factions").select("*").order("name"),
      supabase.from("systems").select("*").order("name"),
      supabase.from("system_edges").select("*").order("slug"),
      supabase.from("system_production").select("*"),
      supabase.from("system_special_objects").select("id, system_id, name, type, is_public").eq("is_public", true),
      supabase.from("faction_resources").select("*"),
      supabase.from("campaign_units").select("*").order("name"),
      supabase.from("movement_orders").select("*").order("arrival_at"),
      supabase.from("movement_order_units").select("*"),
      supabase.from("unit_templates").select("*").order("name"),
      supabase.from("recruitment_queue").select("*, unit_templates(name)").order("finishes_at"),
      supabase.from("technology_nodes").select("*").order("position_y").order("position_x"),
      supabase.from("technology_prerequisites").select("*"),
      supabase.from("faction_technologies").select("*"),
      supabase.from("technology_effects").select("*"),
      supabase.from("building_templates").select("*").order("name"),
      supabase.from("system_buildings").select("*").order("created_at"),
      supabase.from("system_resource_capabilities").select("*"),
      supabase.from("unit_recovery_queue").select("*, campaign_units(name)").order("finishes_at"),
      supabase.from("trade_offers").select("*").order("created_at", { ascending: false }),
      supabase.from("conflicts").select("*").order("created_at"),
      supabase.from("battle_reports").select("*").order("created_at"),
      supabase.from("missions").select("*").order("title")
    ]);

    if (profileResult.error) {
      throw profileResult.error;
    }

    const profile = profileResult.data as DbRow | null;

    if (!profile) {
      return getFallbackSnapshotOrThrow(allowMockFallback, "Tu usuario no tiene perfil de campana configurado.");
    }

    const playerFactions = getRows(playerFactionsResult, "player_factions");
    const factionRows = getRows(factionsResult, "factions");
    const currentFactionId =
      (playerFactions[0]?.faction_id as string | undefined) ?? (factionRows[0]?.id as string | undefined);

    if (!currentFactionId) {
      return getFallbackSnapshotOrThrow(allowMockFallback, "Tu usuario no tiene faccion asignada.");
    }

    const productionBySystem = new Map(
      getRows(productionResult, "system_production").map((row) => [
        row.system_id as string,
        mapResourceProduction(row)
      ])
    );
    const specialObjectsBySystem = groupBy(
      getRows(specialObjectsResult, "system_special_objects").map(mapSpecialObject),
      (item) => item.systemId
    );
    const unitIdsByMovement = groupBy(
      getRows(movementUnitsResult, "movement_order_units").map(mapMovementUnit),
      (item) => item.movementOrderId
    );

    return {
      currentUser: {
        id: profile.id as string,
        displayName: profile.display_name as string,
        role: profile.role as CampaignSnapshot["currentUser"]["role"],
        factionId: currentFactionId
      },
      resourceTickIntervalHours: settingsResult.data?.resource_tick_interval_hours ?? 24,
      nextResourceTickAt: settingsResult.data?.next_resource_tick_at ?? new Date().toISOString(),
      factions: factionRows.map(mapFaction),
      systems: getRows(systemsResult, "systems").map((row) =>
        mapSystem(row, productionBySystem.get(row.id as string), specialObjectsBySystem.get(row.id as string))
      ),
      edges: getRows(edgesResult, "system_edges").map(mapEdge),
      resources: getRows(resourcesResult, "faction_resources").map(mapFactionResources),
      units: getRows(unitsResult, "campaign_units").map(mapCampaignUnit),
      movements: getRows(movementsResult, "movement_orders").map((row) =>
        mapMovement(row, unitIdsByMovement.get(row.id as string))
      ),
      unitTemplates: getRows(unitTemplatesResult, "unit_templates").map(mapUnitTemplate),
      recruitmentQueue: getRows(recruitmentQueueResult, "recruitment_queue").map(mapRecruitmentQueueItem),
      technologyNodes: getRows(technologyNodesResult, "technology_nodes").map(mapTechnologyNode),
      technologyPrerequisites: getRows(technologyPrerequisitesResult, "technology_prerequisites").map(mapTechnologyPrerequisite),
      factionTechnologies: getRows(factionTechnologiesResult, "faction_technologies").map(mapFactionTechnology),
      technologyEffects: getRows(technologyEffectsResult, "technology_effects").map(mapTechnologyEffect),
      buildingTemplates: getRows(buildingTemplatesResult, "building_templates").map(mapBuildingTemplate),
      systemBuildings: getRows(systemBuildingsResult, "system_buildings").map(mapSystemBuilding),
      systemResourceCapabilities: getRows(systemResourceCapabilitiesResult, "system_resource_capabilities").map(mapSystemResourceCapability),
      unitRecoveryQueue: getRows(unitRecoveryQueueResult, "unit_recovery_queue").map(mapUnitRecoveryQueueItem),
      tradeOffers: getRows(tradeOffersResult, "trade_offers").map(mapTradeOffer),
      conflicts: getRows(conflictsResult, "conflicts").map(mapConflict),
      battleReports: getRows(battleReportsResult, "battle_reports").map(mapBattleReport),
      missions: getRows(missionsResult, "missions").map(mapMission)
    };
  } catch (error) {
    if (isStaleSupabaseRefreshTokenError(error)) {
      clearSupabaseAuthStorage();
      console.warn("Sesion local de Supabase caducada tras reset; se limpio el token local.");
      return getFallbackSnapshotOrThrow(allowMockFallback, "La sesion ha caducado. Vuelve a iniciar sesion.", "auth");
    }

    if (error instanceof CampaignAuthRequiredError || error instanceof CampaignDataUnavailableError) {
      throw error;
    }

    console.warn(
      allowMockFallback ? "No se pudo cargar Supabase; usando datos mock." : "No se pudo cargar Supabase.",
      error
    );
    return getFallbackSnapshotOrThrow(allowMockFallback);
  }
}

export function isCampaignAuthRequiredError(error: unknown): boolean {
  return error instanceof CampaignAuthRequiredError;
}

function canUseMockFallback() {
  if (process.env.NEXT_PUBLIC_ALLOW_MOCK_FALLBACK === "true") {
    return true;
  }

  if (process.env.NEXT_PUBLIC_ALLOW_MOCK_FALLBACK === "false") {
    return false;
  }

  return process.env.NODE_ENV !== "production";
}

function getFallbackSnapshotOrThrow(
  allowMockFallback: boolean,
  message = "No se pudo cargar la campana desde Supabase.",
  kind: "auth" | "data" = "data"
) {
  if (allowMockFallback) {
    return mockCampaignSnapshot;
  }

  if (kind === "auth") {
    throw new CampaignAuthRequiredError(message);
  }

  throw new CampaignDataUnavailableError(message);
}

function getRows(result: { data: unknown; error: unknown }, label: string): DbRow[] {
  if (result.error) {
    throw new Error(`Error cargando ${label}`);
  }

  return Array.isArray(result.data) ? (result.data as DbRow[]) : [];
}

function groupBy<T>(items: T[], getKey: (item: T) => string | null | undefined) {
  return items.reduce((groups, item) => {
    const groupKey = getKey(item);

    if (!groupKey) {
      return groups;
    }

    const existing = groups.get(groupKey) ?? [];
    existing.push(item);
    groups.set(groupKey, existing);

    return groups;
  }, new Map<string, T[]>());
}

function mapFaction(row: Record<string, unknown>): Faction {
  return {
    id: row.id as string,
    name: row.name as string,
    color: row.color as string,
    emblemUrl: (row.emblem_url as string | null) ?? null,
    capitalSystemId: (row.capital_system_id as string | null) ?? null
  };
}

function mapSystem(
  row: Record<string, unknown>,
  production: ResourceBundle = emptyResources,
  specialObjects: SystemSpecialObject[] = []
): StarSystem {
  return {
    id: row.id as string,
    name: row.name as string,
    x: Number(row.x),
    y: Number(row.y),
    size: Number(row.size ?? 1),
    starClass: row.star_class as StarClass | undefined,
    systemKind: (row.system_kind as StarSystem["systemKind"] | undefined) ?? "standard",
    isConquerable: row.is_conquerable === null || row.is_conquerable === undefined ? true : Boolean(row.is_conquerable),
    allowsSharedOccupation:
      row.allows_shared_occupation === null || row.allows_shared_occupation === undefined
        ? false
        : Boolean(row.allows_shared_occupation),
    type: row.type as string,
    status: row.status as StarSystem["status"],
    controllerFactionId: (row.controller_faction_id as string | null) ?? null,
    blockedUntil: (row.blocked_until as string | null) ?? null,
    publicDescription: (row.public_description as string | null) ?? "",
    secretAdminNotes: (row.secret_admin_notes as string | null) ?? null,
    missionId: (row.mission_id as string | null) ?? null,
    isCapital: Boolean(row.is_capital),
    buildingSlots: Number(row.building_slots ?? (row.is_capital ? 6 : 3)),
    production,
    specialObjects
  };
}

function mapEdge(row: Record<string, unknown>): SystemEdge {
  return {
    id: row.id as string,
    fromSystemId: row.from_system_id as string,
    toSystemId: row.to_system_id as string,
    uridiumCost: Number(row.uridium_cost ?? 1),
    isBlocked: Boolean(row.is_blocked)
  };
}

function mapResourceProduction(row: Record<string, unknown>): ResourceBundle {
  return {
    supply: Number(row.supply_per_tick ?? 0),
    minerals: Number(row.minerals_per_tick ?? 0),
    honor: Number(row.honor_per_tick ?? row.ancestral_stone_per_tick ?? 0),
    gold: Number(row.gold_per_tick ?? 0),
    industrialMaterial: Number(row.industrial_material_per_tick ?? 0),
    uridium: Number(row.uridium_per_tick ?? 0),
    technology: Number(row.technology_per_tick ?? 0)
  };
}

function mapFactionResources(row: Record<string, unknown>): FactionResources {
  return {
    factionId: row.faction_id as string,
    supply: Number(row.supply ?? 0),
    minerals: Number(row.minerals ?? 0),
    honor: Number(row.honor ?? row.ancestral_stone ?? 0),
    gold: Number(row.gold ?? 0),
    industrialMaterial: Number(row.industrial_material ?? 0),
    uridium: Number(row.uridium ?? 0),
    technology: Number(row.technology ?? 0),
    updatedAt: row.updated_at as string
  };
}

function mapCampaignUnit(row: Record<string, unknown>): CampaignUnit {
  return {
    id: row.id as string,
    factionId: row.faction_id as string,
    name: row.name as string,
    currentSystemId: (row.current_system_id as string | null) ?? null,
    status: row.status as CampaignUnit["status"],
    category: row.category as CampaignUnit["category"],
    points: Number(row.points ?? 0),
    quantity: Number(row.quantity ?? 1),
    startingQuantity: Number(row.starting_quantity ?? row.quantity ?? 1),
    woundsTaken: Number(row.wounds_taken ?? 0),
    experience: Number(row.experience ?? 0),
    isVisiblePublicly: Boolean(row.is_visible_publicly),
    parentUnitId: (row.parent_unit_id as string | null) ?? null,
    destroyedAt: (row.destroyed_at as string | null) ?? null,
    unitTemplateId: (row.unit_template_id as string | null) ?? null,
    rank: (row.rank as string | null) ?? null,
    enhancementText: (row.enhancement_text as string | null) ?? null,
    notes: (row.notes as string | null) ?? null
  };
}

function mapMovementUnit(row: Record<string, unknown>) {
  return {
    movementOrderId: row.movement_order_id as string,
    unitId: row.unit_id as string,
    quantity: Number(row.quantity_at_departure ?? 1)
  };
}

function mapMovement(row: Record<string, unknown>, movementUnits: UnitMovementSelection[] = []): MovementOrder {
  return {
    id: row.id as string,
    unitIds: movementUnits.map((item) => item.unitId),
    unitSelections: movementUnits,
    factionId: row.faction_id as string,
    fromSystemId: row.from_system_id as string,
    toSystemId: row.to_system_id as string,
    pathSystemIds: Array.isArray(row.path_system_ids)
      ? (row.path_system_ids as string[])
      : [row.from_system_id as string, row.to_system_id as string],
    uridiumCost: Number(row.uridium_cost ?? 0),
    segmentCount: Number(row.segment_count ?? 1),
    durationSeconds: Number(row.duration_seconds ?? 0),
    startedAt: row.started_at as string,
    arrivalAt: row.arrival_at as string,
    status: row.status as MovementOrder["status"],
    cancelledAt: (row.cancelled_at as string | null) ?? null
  };
}

function mapUnitTemplate(row: Record<string, unknown>): UnitTemplate {
  return {
    id: row.id as string,
    factionId: row.faction_id as string,
    name: row.name as string,
    category: row.category as UnitCategory,
    points: Number(row.points ?? 0),
    defaultQuantity: Number(row.default_quantity ?? 1),
    woundsPerModel: Number(row.wounds_per_model ?? 1),
    supplyCost: Number(row.supply_cost ?? 0),
    mineralsCost: Number(row.minerals_cost ?? 0),
    honorCost: Number(row.honor_cost ?? row.ancestral_stone_cost ?? 0),
    goldCost: Number(row.gold_cost ?? 0),
    industrialMaterialCost: Number(row.industrial_material_cost ?? 0),
    uridiumCost: Number(row.uridium_cost ?? 0),
    technologyCost: Number(row.technology_cost ?? 0),
    recruitmentTimeSeconds: Number(row.recruitment_time_seconds ?? 0),
    recruitmentBuildingType: (row.recruitment_building_type as string | null) ?? null,
    notes: (row.notes as string | null) ?? null,
    isAvailable: Boolean(row.is_available),
    requiredTechnologyNodeId: (row.required_technology_node_id as string | null) ?? null
  };
}

function mapTradeOffer(row: Record<string, unknown>): TradeOffer {
  return {
    id: row.id as string,
    creatorFactionId: row.creator_faction_id as string,
    offerType: row.offer_type as TradeOffer["offerType"],
    resourceKey: mapTradeableResource(row.resource_key),
    resourceAmount: Number(row.resource_amount ?? 0),
    goldAmount: Number(row.gold_amount ?? 0),
    feeGold: Number(row.fee_gold ?? 0),
    status: row.status as TradeOffer["status"],
    acceptedByFactionId: (row.accepted_by_faction_id as string | null) ?? null,
    createdAt: row.created_at as string,
    acceptedAt: (row.accepted_at as string | null) ?? null,
    cancelledAt: (row.cancelled_at as string | null) ?? null,
    isReserved: Boolean(row.is_reserved)
  };
}

function mapTradeableResource(value: unknown): TradeOffer["resourceKey"] {
  if (value === "industrial_material") {
    return "industrialMaterial";
  }

  if (value === "supply" || value === "minerals" || value === "industrialMaterial" || value === "uridium") {
    return value;
  }

  return "supply";
}

function mapTechnologyNode(row: Record<string, unknown>): TechnologyNode {
  return {
    id: row.id as string,
    slug: row.slug as string,
    treeKey: row.tree_key as string,
    name: row.name as string,
    description: row.description as string,
    branch: row.branch as string,
    tier: Number(row.tier ?? 0),
    positionX: Number(row.position_x ?? 0),
    positionY: Number(row.position_y ?? 0),
    costTechnology: Number(row.cost_technology ?? 0),
    researchTimeSeconds: Number(row.research_time_seconds ?? 0),
    iconKey: (row.icon_key as string | null) ?? null,
    effectSummary: (row.effect_summary as string | null) ?? null,
    isStarter: Boolean(row.is_starter)
  };
}

function mapTechnologyPrerequisite(row: Record<string, unknown>): TechnologyPrerequisite {
  return {
    technologyNodeId: row.technology_node_id as string,
    requiredNodeId: row.required_node_id as string
  };
}

function mapFactionTechnology(row: Record<string, unknown>): FactionTechnology {
  return {
    factionId: row.faction_id as string,
    technologyNodeId: row.technology_node_id as string,
    status: row.status as FactionTechnology["status"],
    startedAt: (row.started_at as string | null) ?? null,
    finishesAt: (row.finishes_at as string | null) ?? null,
    unlockedAt: (row.unlocked_at as string | null) ?? null
  };
}

function mapTechnologyEffect(row: Record<string, unknown>): TechnologyEffect {
  return {
    id: row.id as string,
    technologyNodeId: row.technology_node_id as string,
    effectType: row.effect_type as string,
    payload: mapObject(row.payload)
  };
}

function mapBuildingTemplate(row: Record<string, unknown>): BuildingTemplate {
  return {
    id: row.id as string,
    slug: (row.slug as string | null) ?? (row.id as string),
    name: row.name as string,
    category: row.category as string,
    description: row.description as string,
    buildingKind: row.building_kind as BuildingTemplate["buildingKind"],
    supplyCost: Number(row.supply_cost ?? 0),
    mineralsCost: Number(row.minerals_cost ?? 0),
    honorCost: Number(row.honor_cost ?? 0),
    goldCost: Number(row.gold_cost ?? 0),
    industrialMaterialCost: Number(row.industrial_material_cost ?? 0),
    uridiumCost: Number(row.uridium_cost ?? 0),
    technologyCost: Number(row.technology_cost ?? 0),
    constructionTimeSeconds: Number(row.construction_time_seconds ?? 0),
    producedResourceKey: mapNullableResourceKey(row.produced_resource_key),
    producedAmount: Number(row.produced_amount ?? 0),
    allowedUnitCategories: Array.isArray(row.allowed_unit_categories)
      ? (row.allowed_unit_categories as BuildingTemplate["allowedUnitCategories"])
      : [],
    iconKey: (row.icon_key as string | null) ?? null,
    requiredTechnologyNodeId: (row.required_technology_node_id as string | null) ?? null,
    isAvailable: Boolean(row.is_available)
  };
}

function mapSystemBuilding(row: Record<string, unknown>): SystemBuilding {
  return {
    id: row.id as string,
    systemId: row.system_id as string,
    buildingTemplateId: row.building_template_id as string,
    status: row.status as SystemBuilding["status"],
    startedAt: (row.started_at as string | null) ?? null,
    finishesAt: (row.finishes_at as string | null) ?? null,
    constructedAt: (row.constructed_at as string | null) ?? null
  };
}

function mapSystemResourceCapability(row: Record<string, unknown>): SystemResourceCapability {
  return {
    systemId: row.system_id as string,
    resourceKey: mapResourceKey(row.resource_key),
    productionAmount: Number(row.production_amount ?? 0)
  };
}

function mapRecruitmentQueueItem(row: Record<string, unknown>): RecruitmentQueueItem {
  const template = row.unit_templates as { name?: string } | null;

  return {
    id: row.id as string,
    factionId: row.faction_id as string,
    unitTemplateId: row.unit_template_id as string,
    unitName: template?.name ?? "Unidad",
    quantity: Number(row.quantity ?? 1),
    systemBuildingId: (row.system_building_id as string | null) ?? null,
    originSystemId: (row.origin_system_id as string | null) ?? null,
    supplyCost: Number(row.supply_cost ?? 0),
    mineralsCost: Number(row.minerals_cost ?? 0),
    honorCost: Number(row.honor_cost ?? row.ancestral_stone_cost ?? 0),
    goldCost: Number(row.gold_cost ?? 0),
    industrialMaterialCost: Number(row.industrial_material_cost ?? 0),
    uridiumCost: Number(row.uridium_cost ?? 0),
    technologyCost: Number(row.technology_cost ?? 0),
    startedAt: row.started_at as string,
    finishesAt: row.finishes_at as string,
    status: row.status as RecruitmentQueueItem["status"]
  };
}

function mapUnitRecoveryQueueItem(row: Record<string, unknown>): UnitRecoveryQueueItem {
  const unit = row.campaign_units as { name?: string } | null;

  return {
    id: row.id as string,
    factionId: row.faction_id as string,
    systemBuildingId: row.system_building_id as string,
    campaignUnitId: row.campaign_unit_id as string,
    unitName: unit?.name ?? "Unidad",
    healQuantity: Number(row.heal_quantity ?? 0),
    supplyCost: Number(row.supply_cost ?? 0),
    mineralsCost: Number(row.minerals_cost ?? 0),
    honorCost: Number(row.honor_cost ?? 0),
    goldCost: Number(row.gold_cost ?? 0),
    industrialMaterialCost: Number(row.industrial_material_cost ?? 0),
    uridiumCost: Number(row.uridium_cost ?? 0),
    technologyCost: Number(row.technology_cost ?? 0),
    startedAt: row.started_at as string,
    finishesAt: row.finishes_at as string,
    status: row.status as UnitRecoveryQueueItem["status"]
  };
}

function mapConflict(row: Record<string, unknown>): Conflict {
  return {
    id: row.id as string,
    systemId: row.system_id as string,
    attackerFactionId: row.attacker_faction_id as string,
    defenderFactionId: (row.defender_faction_id as string | null) ?? null,
    status: row.status as Conflict["status"],
    winnerFactionId: (row.winner_faction_id as string | null) ?? null,
    blockedUntil: (row.blocked_until as string | null) ?? null,
    notes: (row.notes as string | null) ?? null
  };
}

function mapNullableResourceKey(value: unknown): ResourceKey | null {
  if (value === null || value === undefined) {
    return null;
  }

  return mapResourceKey(value);
}

function mapResourceKey(value: unknown): ResourceKey {
  if (value === "industrial_material") {
    return "industrialMaterial";
  }

  if (value === "honor") {
    return "honor";
  }

  if (value === "ancestral_stone" || value === "ancestralStone") {
    return "honor";
  }

  if (
    value === "supply" ||
    value === "minerals" ||
    value === "gold" ||
    value === "industrialMaterial" ||
    value === "uridium" ||
    value === "technology"
  ) {
    return value;
  }

  return "supply";
}

function mapBattleReport(row: Record<string, unknown>): BattleReport {
  return {
    id: row.id as string,
    conflictId: row.conflict_id as string,
    reporterFactionId: (row.reporter_faction_id as string | null) ?? null,
    winnerFactionId: (row.winner_faction_id as string | null) ?? null,
    finalControllerFactionId: (row.final_controller_faction_id as string | null) ?? null,
    status: row.status as BattleReport["status"],
    casualties: mapNumberRecord(row.casualties),
    survivors: mapNumberRecord(row.survivors),
    woundsRemaining: mapNumberRecord(row.wounds_remaining),
    narrativeNotes: (row.narrative_notes as string | null) ?? null
  };
}

function mapNumberRecord(value: unknown): Record<string, number> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([key, amount]) => [key, Number(amount ?? 0)])
  );
}

function mapObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  return value as Record<string, unknown>;
}

function mapMission(row: Record<string, unknown>): Mission {
  return {
    id: row.id as string,
    systemId: row.system_id as string,
    title: row.title as string,
    narrativeDescription: row.narrative_description as string,
    objectives: row.objectives as string,
    specialRules: row.special_rules as string,
    victoryConditions: row.victory_conditions as string,
    mapImageUrl: (row.map_image_url as string | null) ?? null
  };
}

function mapSpecialObject(row: Record<string, unknown>): SystemSpecialObject & { systemId: string } {
  return {
    id: row.id as string,
    systemId: row.system_id as string,
    name: row.name as string,
    type: row.type as SystemSpecialObject["type"],
    isPublic: Boolean(row.is_public)
  };
}
