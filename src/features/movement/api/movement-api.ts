import { getSupabaseBrowserClient } from "@/lib/supabase/client";

export async function createMovementOrder(unitIds: string[], pathSystemIds: string[]) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("create_movement_order", {
    unit_ids: unitIds,
    path_system_ids: pathSystemIds
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseMovementRpc() {
  return Boolean(getSupabaseBrowserClient());
}
