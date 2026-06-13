import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let browserClient: SupabaseClient | null = null;

const campaignSessionStartedAtKey = "rol40k-session-started-at";
const campaignSessionMaxAgeMs = 7 * 24 * 60 * 60 * 1000;

export function getSupabaseBrowserClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    return null;
  }

  if (!browserClient) {
    browserClient = createClient(url, anonKey);
  }

  return browserClient;
}

export function clearSupabaseAuthStorage() {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.removeItem(campaignSessionStartedAtKey);

  for (let index = window.localStorage.length - 1; index >= 0; index -= 1) {
    const key = window.localStorage.key(index);

    if (!key) {
      continue;
    }

    if ((key.startsWith("sb-") && key.endsWith("-auth-token")) || key.includes("supabase.auth.token")) {
      window.localStorage.removeItem(key);
    }
  }
}

export function markCampaignSessionStarted() {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.setItem(campaignSessionStartedAtKey, String(Date.now()));
}

export function isCampaignSessionExpired() {
  if (typeof window === "undefined") {
    return false;
  }

  const startedAt = Number(window.localStorage.getItem(campaignSessionStartedAtKey));

  if (!Number.isFinite(startedAt) || startedAt <= 0) {
    return true;
  }

  return Date.now() - startedAt > campaignSessionMaxAgeMs;
}

export function isStaleSupabaseRefreshTokenError(error: unknown) {
  if (!error || typeof error !== "object") {
    return false;
  }

  const message = "message" in error ? String(error.message) : "";

  return message.includes("Invalid Refresh Token") || message.includes("Refresh Token Not Found");
}
