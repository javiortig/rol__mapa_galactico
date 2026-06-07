import { getSupabaseBrowserClient } from "@/lib/supabase/client";

export async function startBuildingConstruction(systemId: string, buildingTemplateId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("start_building_construction", {
    system_id: systemId,
    building_template_id: buildingTemplateId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseBuildingRpc() {
  return Boolean(getSupabaseBrowserClient());
}
