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

export async function recruitUnitAtBuilding(systemBuildingId: string, unitTemplateId: string, quantity: number) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("recruit_unit_at_building", {
    system_building_id: systemBuildingId,
    unit_template_id: unitTemplateId,
    quantity
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function resupplyUnitAtBuilding(systemBuildingId: string, campaignUnitId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("resupply_unit_at_building", {
    system_building_id: systemBuildingId,
    campaign_unit_id: campaignUnitId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function cancelRecruitmentQueue(queueId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("cancel_recruitment_queue", {
    queue_id: queueId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function cancelUnitRecoveryQueue(queueId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("cancel_unit_recovery_queue", {
    queue_id: queueId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseRecruitmentRpc() {
  return Boolean(getSupabaseBrowserClient());
}
