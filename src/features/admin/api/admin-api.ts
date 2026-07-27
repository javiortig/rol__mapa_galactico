import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import type { BuildingStatus, NarrativeMissionEnemyUnit, ResourceBundle, UnitStatus } from "@/domain/campaign";

type EditableFactionResources = Pick<
  ResourceBundle,
  "supply" | "minerals" | "honor" | "gold" | "industrialMaterial" | "uridium" | "technology"
>;

type EditableSystemCapabilities = Pick<
  ResourceBundle,
  "supply" | "minerals" | "honor" | "gold" | "industrialMaterial" | "uridium"
>;

function getAdminClient() {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  return supabase;
}

export async function adminCreateUnit(input: {
  factionId: string;
  systemId: string;
  unitTemplateId: string;
  quantity: number;
  customName?: string;
}) {
  const supabase = getAdminClient();

  const { data, error } = await supabase.rpc("admin_create_unit", {
    target_faction_id: input.factionId,
    target_system_id: input.systemId,
    target_unit_template_id: input.unitTemplateId,
    quantity: input.quantity,
    custom_name: input.customName ?? null
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function adminConstructBuilding(input: { systemId: string; buildingTemplateId: string }) {
  const supabase = getAdminClient();

  const { data, error } = await supabase.rpc("admin_construct_building", {
    target_system_id: input.systemId,
    target_building_template_id: input.buildingTemplateId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function adminSetFactionResources(input: {
  factionId: string;
  resources: EditableFactionResources;
}) {
  const supabase = getAdminClient();

  const { error } = await supabase.rpc("admin_set_faction_resources", {
    target_faction_id: input.factionId,
    supply: input.resources.supply,
    minerals: input.resources.minerals,
    honor: input.resources.honor,
    gold: input.resources.gold,
    industrial_material: input.resources.industrialMaterial,
    uridium: input.resources.uridium,
    technology: input.resources.technology
  });

  if (error) {
    throw new Error(error.message);
  }
}

export async function adminSetSystemResourceCapabilities(input: {
  systemId: string;
  capabilities: EditableSystemCapabilities;
}) {
  const supabase = getAdminClient();

  const { error } = await supabase.rpc("admin_set_system_resource_capabilities", {
    target_system_id: input.systemId,
    supply: input.capabilities.supply,
    minerals: input.capabilities.minerals,
    honor: input.capabilities.honor,
    gold: input.capabilities.gold,
    industrial_material: input.capabilities.industrialMaterial,
    uridium: input.capabilities.uridium
  });

  if (error) {
    throw new Error(error.message);
  }
}

export async function adminSetCampaignLimits(input: {
  resourceCaps: EditableFactionResources;
  maxArmyPoints: number;
}) {
  const supabase = getAdminClient();

  const { error } = await supabase.rpc("admin_set_campaign_limits", {
    max_supply: input.resourceCaps.supply,
    max_minerals: input.resourceCaps.minerals,
    max_honor: input.resourceCaps.honor,
    max_gold: input.resourceCaps.gold,
    max_industrial_material: input.resourceCaps.industrialMaterial,
    max_uridium: input.resourceCaps.uridium,
    max_technology: input.resourceCaps.technology,
    max_army_points: input.maxArmyPoints
  });

  if (error) {
    throw new Error(error.message);
  }
}

export async function adminSetSystemBlock(input: { systemId: string; blockedUntil: string | null }) {
  const supabase = getAdminClient();

  const { error } = await supabase.rpc("admin_set_system_block", {
    target_system_id: input.systemId,
    blocked_until: input.blockedUntil
  });

  if (error) {
    throw new Error(error.message);
  }
}

export async function adminCreateNarrativeAttack(input: {
  systemId: string;
  narrativeFactionId: string;
  description: string;
  arrivalAt: string;
}) {
  const supabase = getAdminClient();

  const { data, error } = await supabase.rpc("admin_create_narrative_attack", {
    target_system_id: input.systemId,
    narrative_faction_id: input.narrativeFactionId,
    attack_description: input.description,
    arrival_at: input.arrivalAt
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function adminCreateNarrativeMission(input: {
  anchorSystemId: string;
  narrativeFactionId: string;
  name: string;
  description: string;
  enemyUnitsVisible: boolean;
  enemyUnits: NarrativeMissionEnemyUnit[];
  durationDays: number;
  expiresAfterBattle: boolean;
}) {
  const supabase = getAdminClient();

  const { data, error } = await supabase.rpc("admin_create_narrative_mission", {
    anchor_system_id: input.anchorSystemId,
    narrative_faction_id: input.narrativeFactionId,
    mission_name: input.name,
    mission_description: input.description,
    enemy_units_visible: input.enemyUnitsVisible,
    enemy_units: input.enemyUnits,
    duration_days: input.durationDays,
    expires_after_battle: input.expiresAfterBattle
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function adminRemoveTemporaryMission(systemId: string) {
  const supabase = getAdminClient();

  const { data, error } = await supabase.rpc("admin_remove_temporary_mission", {
    target_system_id: systemId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function adminSetNarrativeControl(input: {
  systemId: string;
  narrativeFactionId: string;
  description?: string;
}) {
  const supabase = getAdminClient();

  const { data, error } = await supabase.rpc("admin_set_narrative_control", {
    target_system_id: input.systemId,
    narrative_faction_id: input.narrativeFactionId,
    control_description: input.description ?? null
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function adminUpdateCampaignUnit(input: {
  unitId: string;
  systemId: string | null;
  quantity: number;
  woundsTaken: number;
  status: UnitStatus;
  isVisiblePublicly: boolean;
}) {
  const supabase = getAdminClient();

  const { data, error } = await supabase.rpc("admin_update_campaign_unit", {
    target_unit_id: input.unitId,
    target_system_id: input.systemId,
    quantity: input.quantity,
    wounds_taken: input.woundsTaken,
    status: input.status,
    is_visible_publicly: input.isVisiblePublicly
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function adminUpdateSystemBuilding(input: {
  systemBuildingId: string;
  systemId: string;
  buildingTemplateId: string;
  status: BuildingStatus;
  finishesAt: string | null;
}) {
  const supabase = getAdminClient();

  const { data, error } = await supabase.rpc("admin_update_system_building", {
    target_system_building_id: input.systemBuildingId,
    target_system_id: input.systemId,
    target_building_template_id: input.buildingTemplateId,
    status: input.status,
    finishes_at: input.finishesAt
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseAdminRpc() {
  return Boolean(getSupabaseBrowserClient());
}
