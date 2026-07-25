import type { BattleSide, UnitMovementSelection } from "@/domain/campaign";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";

function getClient() {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado.");
  }

  return supabase;
}

function mapSelections(unitSelections: UnitMovementSelection[]) {
  return unitSelections.map((selection) => ({
    unit_id: selection.unitId,
    quantity: selection.quantity
  }));
}

export async function createCoalitionAttackDraft(
  unitSelections: UnitMovementSelection[],
  originSystemId: string,
  targetSystemId: string,
  invitedFactionIds: string[]
) {
  const { data, error } = await getClient().rpc("create_coalition_attack_draft", {
    unit_selections: mapSelections(unitSelections),
    origin_system_id: originSystemId,
    target_system_id: targetSystemId,
    invited_faction_ids: invitedFactionIds
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function inviteBattleSupport(operationId: string, factionId: string, side: BattleSide) {
  const { data, error } = await getClient().rpc("invite_battle_support", {
    operation_id: operationId,
    target_faction_id: factionId,
    support_side: side
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function respondBattleSupportInvitation(operationId: string, decision: "accepted" | "rejected") {
  const { data, error } = await getClient().rpc("respond_battle_support_invitation", {
    operation_id: operationId,
    decision
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function joinBattleOperation(
  operationId: string,
  unitSelections: UnitMovementSelection[],
  pathSystemIds: string[]
) {
  const { data, error } = await getClient().rpc("join_battle_operation", {
    operation_id: operationId,
    unit_selections: mapSelections(unitSelections),
    path_system_ids: pathSystemIds
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function launchCoalitionAttack(operationId: string) {
  const { data, error } = await getClient().rpc("launch_coalition_attack", {
    operation_id: operationId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function cancelBattleOperation(operationId: string) {
  const { data, error } = await getClient().rpc("cancel_battle_operation", {
    operation_id: operationId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}
