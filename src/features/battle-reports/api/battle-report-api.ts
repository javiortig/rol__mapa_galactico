import { getSupabaseBrowserClient } from "@/lib/supabase/client";

export type BattleReportPayload = {
  winnerFactionId: string | null;
  finalControllerFactionId: string | null;
  survivors: Record<string, number>;
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
      winner_faction_id: payload.winnerFactionId,
      final_controller_faction_id: payload.finalControllerFactionId,
      survivors: payload.survivors,
      post_battle_blocked_until: payload.postBattleBlockedUntil ?? null,
      narrative_notes: payload.narrativeNotes ?? null
    }
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseBattleReportRpc() {
  return Boolean(getSupabaseBrowserClient());
}
