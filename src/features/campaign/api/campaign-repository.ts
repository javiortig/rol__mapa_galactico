import type {
  BattleReport,
  CampaignUnit,
  CampaignSnapshot,
  Conflict,
  Faction,
  FactionResources,
  Mission,
  MovementOrder,
  RecruitmentQueueItem,
  ResourceBundle,
  StarClass,
  StarSystem,
  SystemEdge,
  SystemSpecialObject,
  UnitCategory,
  UnitTemplate
} from "@/domain/campaign";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { mockCampaignSnapshot } from "@/mocks/campaign-data";

type DbRow = Record<string, unknown>;

const emptyResources: ResourceBundle = {
  supply: 0,
  minerals: 0,
  ancestralStone: 0,
  uridium: 0,
  technology: 0
};

export async function getCampaignSnapshot(): Promise<CampaignSnapshot> {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    return mockCampaignSnapshot;
  }

  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    return mockCampaignSnapshot;
  }

  try {
    await Promise.allSettled([
      supabase.rpc("resolve_resource_ticks"),
      supabase.rpc("resolve_movement_orders"),
      supabase.rpc("resolve_recruitment_queue")
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
      supabase.from("conflicts").select("*").order("created_at"),
      supabase.from("battle_reports").select("*").order("created_at"),
      supabase.from("missions").select("*").order("title")
    ]);

    if (profileResult.error) {
      throw profileResult.error;
    }

    const profile = profileResult.data as DbRow | null;

    if (!profile) {
      return mockCampaignSnapshot;
    }

    const playerFactions = getRows(playerFactionsResult, "player_factions");
    const factionRows = getRows(factionsResult, "factions");
    const currentFactionId =
      (playerFactions[0]?.faction_id as string | undefined) ?? (factionRows[0]?.id as string | undefined);

    if (!currentFactionId) {
      return mockCampaignSnapshot;
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
      conflicts: getRows(conflictsResult, "conflicts").map(mapConflict),
      battleReports: getRows(battleReportsResult, "battle_reports").map(mapBattleReport),
      missions: getRows(missionsResult, "missions").map(mapMission)
    };
  } catch (error) {
    console.warn("No se pudo cargar Supabase; usando datos mock.", error);
    return mockCampaignSnapshot;
  }
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
    type: row.type as string,
    status: row.status as StarSystem["status"],
    controllerFactionId: (row.controller_faction_id as string | null) ?? null,
    blockedUntil: (row.blocked_until as string | null) ?? null,
    publicDescription: (row.public_description as string | null) ?? "",
    secretAdminNotes: (row.secret_admin_notes as string | null) ?? null,
    missionId: (row.mission_id as string | null) ?? null,
    isCapital: Boolean(row.is_capital),
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
    ancestralStone: Number(row.ancestral_stone_per_tick ?? 0),
    uridium: Number(row.uridium_per_tick ?? 0),
    technology: Number(row.technology_per_tick ?? 0)
  };
}

function mapFactionResources(row: Record<string, unknown>): FactionResources {
  return {
    factionId: row.faction_id as string,
    supply: Number(row.supply ?? 0),
    minerals: Number(row.minerals ?? 0),
    ancestralStone: Number(row.ancestral_stone ?? 0),
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
    experience: Number(row.experience ?? 0),
    isVisiblePublicly: Boolean(row.is_visible_publicly),
    unitTemplateId: (row.unit_template_id as string | null) ?? null,
    rank: (row.rank as string | null) ?? null,
    enhancementText: (row.enhancement_text as string | null) ?? null,
    notes: (row.notes as string | null) ?? null
  };
}

function mapMovementUnit(row: Record<string, unknown>) {
  return {
    movementOrderId: row.movement_order_id as string,
    unitId: row.unit_id as string
  };
}

function mapMovement(row: Record<string, unknown>, movementUnits: Array<{ unitId: string }> = []): MovementOrder {
  return {
    id: row.id as string,
    unitIds: movementUnits.map((item) => item.unitId),
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
    status: row.status as MovementOrder["status"]
  };
}

function mapUnitTemplate(row: Record<string, unknown>): UnitTemplate {
  return {
    id: row.id as string,
    factionId: row.faction_id as string,
    name: row.name as string,
    category: row.category as UnitCategory,
    points: Number(row.points ?? 0),
    supplyCost: Number(row.supply_cost ?? 0),
    mineralsCost: Number(row.minerals_cost ?? 0),
    ancestralStoneCost: Number(row.ancestral_stone_cost ?? 0),
    uridiumCost: Number(row.uridium_cost ?? 0),
    technologyCost: Number(row.technology_cost ?? 0),
    recruitmentTimeSeconds: Number(row.recruitment_time_seconds ?? 0),
    notes: (row.notes as string | null) ?? null,
    isAvailable: Boolean(row.is_available)
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
    startedAt: row.started_at as string,
    finishesAt: row.finishes_at as string,
    status: row.status as RecruitmentQueueItem["status"]
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

function mapBattleReport(row: Record<string, unknown>): BattleReport {
  return {
    id: row.id as string,
    conflictId: row.conflict_id as string,
    reporterFactionId: (row.reporter_faction_id as string | null) ?? null,
    winnerFactionId: (row.winner_faction_id as string | null) ?? null,
    finalControllerFactionId: (row.final_controller_faction_id as string | null) ?? null,
    status: row.status as BattleReport["status"],
    narrativeNotes: (row.narrative_notes as string | null) ?? null
  };
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
