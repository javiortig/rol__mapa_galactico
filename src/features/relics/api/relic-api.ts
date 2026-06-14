import { getSupabaseBrowserClient } from "@/lib/supabase/client";

function getRelicClient() {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  return supabase;
}

export async function equipRelicToCharacter(relicId: string, characterUnitId: string, systemBuildingId: string) {
  const supabase = getRelicClient();

  const { data, error } = await supabase.rpc("equip_relic_to_character", {
    relic_id: relicId,
    character_unit_id: characterUnitId,
    system_building_id: systemBuildingId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function unequipRelicFromCharacter(relicId: string, systemBuildingId: string) {
  const supabase = getRelicClient();

  const { data, error } = await supabase.rpc("unequip_relic_from_character", {
    relic_id: relicId,
    system_building_id: systemBuildingId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseRelicRpc() {
  return Boolean(getSupabaseBrowserClient());
}
