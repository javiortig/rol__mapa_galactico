import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { fixSpanishText } from "@/lib/spanish-text";

export async function startTechnologyResearch(technologyNodeId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error(fixSpanishText("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY."));
  }

  const { data, error } = await supabase.rpc("start_technology_research", {
    technology_node_id: technologyNodeId
  });

  if (error) {
    throw new Error(fixSpanishText(error.message));
  }

  return data as string;
}

export function canUseTechnologyRpc() {
  return Boolean(getSupabaseBrowserClient());
}
