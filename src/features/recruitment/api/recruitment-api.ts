import { getSupabaseBrowserClient } from "@/lib/supabase/client";

export async function recruitUnit(unitTemplateId: string, quantity: number) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("recruit_unit", {
    unit_template_id: unitTemplateId,
    quantity
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseRecruitmentRpc() {
  return Boolean(getSupabaseBrowserClient());
}
