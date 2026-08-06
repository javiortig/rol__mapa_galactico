import type { BattleResolutionMode } from "@/domain/campaign";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";

export type BattleReportPayload = {
  battleMode: BattleResolutionMode;
  winnerFactionId: string | null;
  finalControllerFactionId: string | null;
  survivors: Record<string, number>;
  woundsRemaining: Record<string, number>;
  expectedRevision?: number | null;
  postBattleBlockedUntil?: string | null;
  narrativeNotes?: string | null;
};

export async function submitBattleReport(conflictId: string, payload: BattleReportPayload) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("submit_battle_report", {
    conflict_id: conflictId,
    report_payload: {
      battle_mode: payload.battleMode,
      winner_faction_id: payload.winnerFactionId,
      final_controller_faction_id: payload.finalControllerFactionId,
      survivors: payload.survivors,
      wounds_remaining: payload.woundsRemaining,
      expected_revision: payload.expectedRevision ?? null,
      post_battle_blocked_until: payload.postBattleBlockedUntil ?? null,
      narrative_notes: payload.narrativeNotes ?? null
    }
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function validateBattleReport(conflictId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("validate_battle_report", {
    target_conflict_id: conflictId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function adminConfirmBattleReport(conflictId: string, payload: BattleReportPayload) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { error } = await supabase.rpc("admin_confirm_battle_report", {
    target_conflict_id: conflictId,
    report_payload: {
      battle_mode: payload.battleMode,
      winner_faction_id: payload.winnerFactionId,
      final_controller_faction_id: payload.finalControllerFactionId,
      survivors: payload.survivors,
      wounds_remaining: payload.woundsRemaining,
      expected_revision: payload.expectedRevision ?? null,
      post_battle_blocked_until: payload.postBattleBlockedUntil ?? null,
      narrative_notes: payload.narrativeNotes ?? null
    }
  });

  if (error) {
    throw new Error(error.message);
  }
}

export function canUseBattleReportRpc() {
  return Boolean(getSupabaseBrowserClient());
}
