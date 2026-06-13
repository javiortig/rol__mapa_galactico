import { getSupabaseBrowserClient } from "@/lib/supabase/client";

export async function retireCampaignUnit(unitId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("retire_campaign_unit", {
    campaign_unit_id: unitId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}
