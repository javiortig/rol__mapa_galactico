import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { fixSpanishText } from "@/lib/spanish-text";

export async function startBuildingConstruction(systemId: string, buildingTemplateId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error(fixSpanishText("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY."));
  }

  const { data, error } = await supabase.rpc("start_building_construction", {
    system_id: systemId,
    building_template_id: buildingTemplateId
  });

  if (error) {
    throw new Error(fixSpanishText(error.message));
  }

  return data as string;
}

export async function destroySystemBuilding(systemBuildingId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error(fixSpanishText("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY."));
  }

  const { data, error } = await supabase.rpc("destroy_system_building", {
    system_building_id: systemBuildingId
  });

  if (error) {
    throw new Error(fixSpanishText(error.message));
  }

  return data as string;
}

export function canUseBuildingRpc() {
  return Boolean(getSupabaseBrowserClient());
}
