import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import type { UnitMovementSelection } from "@/domain/campaign";

export async function createMovementOrder(unitSelections: UnitMovementSelection[], pathSystemIds: string[]) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("create_movement_order", {
    unit_selections: unitSelections.map((selection) => ({
      unit_id: selection.unitId,
      quantity: selection.quantity
    })),
    path_system_ids: pathSystemIds
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function mergeCampaignUnits(unitIds: string[]) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("merge_campaign_units", {
    unit_ids: unitIds
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseMovementRpc() {
  return Boolean(getSupabaseBrowserClient());
}
