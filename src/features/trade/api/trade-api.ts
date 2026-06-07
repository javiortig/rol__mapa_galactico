import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import type { TradeOfferType, TradeableResourceKey } from "@/domain/campaign";

export type MerchantTradeDirection = "buy" | "sell";

export async function merchantTrade(
  resourceKey: TradeableResourceKey,
  direction: MerchantTradeDirection,
  quantity: number
) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("merchant_trade", {
    resource_key: resourceKey,
    direction,
    trade_quantity: quantity
  });

  if (error) {
    throw new Error(error.message);
  }

  return data;
}

export async function createTradeOffer(
  offerType: TradeOfferType,
  resourceKey: TradeableResourceKey,
  resourceAmount: number,
  goldAmount: number
) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("create_trade_offer", {
    offer_type: offerType,
    resource_key: resourceKey,
    resource_amount: resourceAmount,
    gold_amount: goldAmount
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function acceptTradeOffer(offerId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("accept_trade_offer", {
    offer_id: offerId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export async function cancelTradeOffer(offerId: string) {
  const supabase = getSupabaseBrowserClient();

  if (!supabase) {
    throw new Error("Supabase no esta configurado. Anade NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY.");
  }

  const { data, error } = await supabase.rpc("cancel_trade_offer", {
    offer_id: offerId
  });

  if (error) {
    throw new Error(error.message);
  }

  return data as string;
}

export function canUseTradeRpc() {
  return Boolean(getSupabaseBrowserClient());
}
