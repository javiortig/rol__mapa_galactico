import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import type { UnitMovementSelection } from "@/domain/campaign";
import { fixSpanishText } from "@/lib/spanish-text";

export async function createMovementOrder(unitSelections: UnitMovementSelection[], pathSystemIds: string[]) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error(fixSpanishText("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY."));
  }

  const { data, error } = await supabase.rpc("create_movement_order", {
    unit_selections: unitSelections.map((selection) => ({
      unit_id: selection.unitId,
      quantity: selection.quantity
    })),
    path_system_ids: pathSystemIds
  });

  if (error) {
    throw new Error(fixSpanishText(error.message));
  }

  return data as string;
}

export async function createAttackOrder(
  unitSelections: UnitMovementSelection[],
  originSystemId: string,
  targetSystemId: string
) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error(fixSpanishText("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY."));
  }

  const { data, error } = await supabase.rpc("create_attack_order", {
    unit_selections: unitSelections.map((selection) => ({
      unit_id: selection.unitId,
      quantity: selection.quantity
    })),
    origin_system_id: originSystemId,
    target_system_id: targetSystemId
  });

  if (error) {
    throw new Error(fixSpanishText(error.message));
  }

  return data as string;
}

export async function respondMovementPassageRequest(
  passageRequestId: string,
  decision: "accepted" | "rejected",
  responseReason?: string | null
) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error(fixSpanishText("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY."));
  }

  const { data, error } = await supabase.rpc("respond_movement_passage_request", {
    passage_request_id: passageRequestId,
    decision,
    response_reason: responseReason ?? null
  });

  if (error) {
    throw new Error(fixSpanishText(error.message));
  }

  return data as string;
}

export async function cancelMovementOrder(orderId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error(fixSpanishText("Supabase no está configurado. Añade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY."));
  }

  const { data, error } = await supabase.rpc("cancel_movement_order", {
    order_id: orderId
  });

  if (error) {
    throw new Error(fixSpanishText(error.message));
  }

  return data as string;
}

export function canUseMovementRpc() {
  return Boolean(getSupabaseBrowserClient());
}
