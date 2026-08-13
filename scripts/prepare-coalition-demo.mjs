import fs from "node:fs";
import { createClient } from "@supabase/supabase-js";
import WebSocket from "ws";

globalThis.WebSocket = WebSocket;

const env = Object.fromEntries(
  fs
    .readFileSync(".env.local", "utf8")
    .split(/\r?\n/)
    .filter(Boolean)
    .filter((line) => !line.startsWith("#"))
    .map((line) => {
      const separator = line.indexOf("=");
      return [line.slice(0, separator), line.slice(separator + 1)];
    })
);
const service = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
});
const custodes = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.NEXT_PUBLIC_SUPABASE_ANON_KEY, {
  auth: { persistSession: false }
});

function fail(label, error) {
  if (error) {
    throw new Error(`${label}: ${error.message}`);
  }
}

async function forceArrival(orderIds) {
  if (orderIds.length === 0) {
    return;
  }

  const result = await service
    .from("movement_orders")
    .update({ arrival_at: new Date(Date.now() - 1000).toISOString() })
    .in("id", orderIds);
  fail("forzar llegada local", result.error);
  const resolver = await service.rpc("resolve_movement_orders");
  fail("resolver llegadas", resolver.error);
}

async function main() {
  const login = await custodes.auth.signInWithPassword({
    email: "adeptus-custodes@rol40k.local",
    password: "Penedorado"
  });
  fail("login Adeptus Custodes", login.error);

  const seedMovements = await service
    .from("movement_orders")
    .select("id")
    .eq("movement_type", "move")
    .eq("status", "moving");
  fail("leer movimientos seed", seedMovements.error);
  await forceArrival(seedMovements.data.map((order) => order.id));

  const factions = await service.from("factions").select("id,slug");
  const systems = await service.from("systems").select("id,slug");
  fail("leer facciones", factions.error);
  fail("leer sistemas", systems.error);
  const factionId = Object.fromEntries(factions.data.map((row) => [row.slug, row.id]));
  const systemId = Object.fromEntries(systems.data.map((row) => [row.slug, row.id]));
  const caladiusResult = await service
    .from("campaign_units")
    .select("id,quantity,current_system_id,status")
    .eq("name", "Caladius Grav-tank")
    .eq("faction_id", factionId["adeptus-custodes"])
    .single();
  fail("leer Caladius Grav-tank", caladiusResult.error);
  const caladius = caladiusResult.data;

  if (caladius.current_system_id !== systemId["arx-solum"] || caladius.status !== "ready") {
    const move = await custodes.rpc("create_movement_order", {
      unit_selections: [{ unit_id: caladius.id, quantity: caladius.quantity }],
      path_system_ids: [systemId["helios-drift"], systemId["arx-solum"]]
    });
    fail("mover Caladius a Arx Solum", move.error);
    await forceArrival([move.data]);
  }

  const draft = await custodes.rpc("create_coalition_attack_draft", {
    unit_selections: [{ unit_id: caladius.id, quantity: caladius.quantity }],
    origin_system_id: systemId["arx-solum"],
    target_system_id: systemId.orison,
    invited_faction_ids: [factionId.aeldari]
  });
  fail("crear demostracion de coalicion", draft.error);

  console.log(`Demostracion preparada: ${draft.data}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
