import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import type { ResourceBundle } from "@/domain/campaign";

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

export function canUseAdminRpc() {
  return Boolean(getSupabaseBrowserClient());
}
