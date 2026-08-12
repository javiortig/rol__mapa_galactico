import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { fixSpanishText } from "@/lib/spanish-text";

export async function retireCampaignUnit(unitId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error(fixSpanishText("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY."));
  }

  const { data, error } = await supabase.rpc("retire_campaign_unit", {
    campaign_unit_id: unitId
  });

  if (error) {
    throw new Error(fixSpanishText(error.message));
  }

  return data as string;
}
