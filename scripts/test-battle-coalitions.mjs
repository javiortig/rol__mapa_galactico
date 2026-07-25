import fs from "node:fs";
import { createClient } from "@supabase/supabase-js";

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

const url = env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const service = createClient(url, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
});

function fail(label, error) {
  if (error) {
    throw new Error(`${label}: ${error.message}`);
  }
}

async function login(slug) {
  const client = createClient(url, anonKey, { auth: { persistSession: false } });
  const { error } = await client.auth.signInWithPassword({
    email: `${slug}@rol40k.local`,
    password: "rol40k-local-123"
  });
  fail(`login ${slug}`, error);
  return client;
}

async function loginAdmin() {
  const client = createClient(url, anonKey, { auth: { persistSession: false } });
  const { error } = await client.auth.signInWithPassword({
    email: "admin@rol40k.local",
    password: "admin-local-123"
  });
  fail("login admin", error);
  return client;
}

async function rows(table, columns = "*") {
  const result = await service.from(table).select(columns);
  fail(table, result.error);
  return result.data;
}

async function forceArrival(orderIds) {
  const result = await service
    .from("movement_orders")
    .update({ arrival_at: new Date(Date.now() - 1000).toISOString() })
    .in("id", Array.isArray(orderIds) ? orderIds : [orderIds]);
  fail("forzar llegada local", result.error);
}

async function main() {
  const factions = await rows("factions", "id,slug");
  const systems = await rows("systems", "id,slug");
  const factionId = Object.fromEntries(factions.map((row) => [row.slug, row.id]));
  const systemId = Object.fromEntries(systems.map((row) => [row.slug, row.id]));

  const seedMovements = await service
    .from("movement_orders")
    .select("id")
    .eq("movement_type", "move")
    .eq("status", "moving");
  fail("leer movimientos seed", seedMovements.error);

  if (seedMovements.data.length > 0) {
    await forceArrival(seedMovements.data.map((order) => order.id));
    const resolver = await service.rpc("resolve_movement_orders");
    fail("resolver movimientos seed", resolver.error);
  }

  const repositionCaladius = await service
    .from("campaign_units")
    .update({ current_system_id: systemId["arx-solum"], status: "ready" })
    .eq("name", "Caladius Grav-tank")
    .eq("faction_id", factionId["adeptus-custodes"]);
  fail("preparar Caladius local", repositionCaladius.error);

  const units = await rows(
    "campaign_units",
    "id,name,faction_id,current_system_id,status,quantity,wounds_taken"
  );
  const unitBy = (faction, system, namePart) =>
    units.find(
      (unit) =>
        unit.faction_id === factionId[faction] &&
        unit.current_system_id === systemId[system] &&
        unit.status === "ready" &&
        unit.name.includes(namePart)
    );
  const caladius = unitBy("adeptus-custodes", "arx-solum", "Caladius");
  const farseer = unitBy("aeldari", "cinder-maw", "Farseer");
  const intercessors = unitBy("space-marines", "sa-cea-gate", "Intercessor");

  if (!caladius || !farseer || !intercessors) {
    throw new Error("No se encontraron las unidades de prueba esperadas.");
  }

  const custodes = await login("adeptus-custodes");
  const aeldari = await login("aeldari");
  const agentes = await login("agentes-imperium");
  const marines = await login("space-marines");

  let result = await custodes.rpc("create_coalition_attack_draft", {
    unit_selections: [{ unit_id: caladius.id, quantity: caladius.quantity }],
    origin_system_id: systemId["arx-solum"],
    target_system_id: systemId.orison,
    invited_faction_ids: [factionId.aeldari]
  });
  fail("crear borrador", result.error);
  const operationId = result.data;

  result = await aeldari.rpc("join_battle_operation", {
    operation_id: operationId,
    unit_selections: [{ unit_id: farseer.id, quantity: farseer.quantity }],
    path_system_ids: [
      "cinder-maw",
      "eclipse-forge",
      "rustmaw-run",
      "azur-trench",
      "arx-solum"
    ].map((slug) => systemId[slug])
  });
  fail("reunir aliado atacante", result.error);
  await forceArrival(result.data);
  result = await aeldari.rpc("resolve_movement_orders");
  fail("resolver reunion", result.error);

  result = await custodes.rpc("launch_coalition_attack", { operation_id: operationId });
  fail("lanzar coalicion", result.error);
  const attackOrderId = result.data;

  const prepareMarineEnclave = await service
    .from("systems")
    .update({
      status: "controlled",
      controller_faction_id: factionId["space-marines"],
      blocked_until: null
    })
    .eq("id", systemId["azur-trench"]);
  fail("preparar enclave Marine local", prepareMarineEnclave.error);
  const repositionRhino = await service
    .from("campaign_units")
    .update({ current_system_id: systemId["azur-trench"], status: "ready" })
    .eq("name", "Rhino")
    .eq("faction_id", factionId["space-marines"])
    .select("id,name,faction_id,current_system_id,status,quantity,wounds_taken")
    .single();
  fail("preparar Rhino local", repositionRhino.error);
  const rhino = repositionRhino.data;

  result = await agentes.rpc("invite_battle_support", {
    operation_id: operationId,
    target_faction_id: factionId["space-marines"],
    support_side: "defender"
  });
  fail("invitar apoyo defensor", result.error);

  result = await marines.rpc("join_battle_operation", {
    operation_id: operationId,
    unit_selections: [{ unit_id: rhino.id, quantity: rhino.quantity }],
    path_system_ids: ["azur-trench", "orison"].map((slug) => systemId[slug])
  });
  fail("enviar apoyo defensor", result.error);
  const defenseOrderId = result.data;

  const lateAttempt = await marines.rpc("join_battle_operation", {
    operation_id: operationId,
    unit_selections: [{ unit_id: intercessors.id, quantity: intercessors.quantity }],
    path_system_ids: [
      "sa-cea-gate",
      "lyra-terminus",
      "narthex",
      "vesper-halo",
      "argent-rift",
      "orison"
    ].map((slug) => systemId[slug])
  });

  if (!lateAttempt.error || !lateAttempt.error.message.includes("no llegan")) {
    throw new Error("El backend no rechazo el apoyo tardio.");
  }

  await forceArrival(defenseOrderId);
  result = await marines.rpc("resolve_movement_orders");
  fail("resolver apoyo defensor", result.error);
  await forceArrival(attackOrderId);
  result = await custodes.rpc("resolve_movement_orders");
  fail("resolver llegada ataque", result.error);

  const operationResult = await service
    .from("battle_operations")
    .select("*")
    .eq("id", operationId)
    .single();
  fail("leer operacion", operationResult.error);

  if (operationResult.data.status !== "in_battle" || !operationResult.data.roster_locked_at) {
    throw new Error("El plantel no quedo cerrado.");
  }

  const commitmentsResult = await service
    .from("battle_unit_commitments")
    .select("*")
    .eq("operation_id", operationId);
  fail("leer compromisos", commitmentsResult.error);

  if (
    !commitmentsResult.data.some(
      (commitment) => commitment.unit_id === farseer.id && commitment.status === "in_battle"
    ) ||
    !commitmentsResult.data.some(
      (commitment) => commitment.unit_id === rhino.id && commitment.status === "in_battle"
    )
  ) {
    throw new Error("Los apoyos no entraron en el plantel cerrado.");
  }

  const currentUnits = await rows(
    "campaign_units",
    "id,name,faction_id,current_system_id,status,quantity"
  );
  const inquisitor = currentUnits.find(
    (unit) =>
      unit.faction_id === factionId["agentes-imperium"] &&
      unit.current_system_id === systemId["argent-rift"] &&
      unit.status === "ready"
  );

  result = await agentes.rpc("create_movement_order", {
    unit_selections: [{ unit_id: inquisitor.id, quantity: inquisitor.quantity }],
    path_system_ids: ["argent-rift", "orison", "nexus-aster"].map((slug) => systemId[slug])
  });
  fail("transito por planeta en guerra", result.error);

  const conflictResult = await service
    .from("conflicts")
    .select("*")
    .eq("battle_operation_id", operationId)
    .single();
  fail("leer conflicto", conflictResult.error);
  const warUnitsResult = await service
    .from("campaign_units")
    .select("id,quantity,wounds_taken")
    .eq("current_system_id", systemId.orison)
    .eq("status", "in_war");
  fail("leer unidades en guerra", warUnitsResult.error);
  const survivors = Object.fromEntries(warUnitsResult.data.map((unit) => [unit.id, unit.quantity]));
  const wounds = Object.fromEntries(
    warUnitsResult.data.map((unit) => [unit.id, unit.wounds_taken])
  );
  const admin = await loginAdmin();

  result = await admin.rpc("admin_resolve_battle", {
    target_conflict_id: conflictResult.data.id,
    winner_faction_id: factionId["adeptus-custodes"],
    final_controller_faction_id: factionId["adeptus-custodes"],
    survivors,
    post_battle_blocked_until: null,
    narrative_notes: "Prueba automatizada local de coaliciones",
    wounds_remaining: wounds
  });
  fail("resolver batalla", result.error);

  const returnsResult = await service
    .from("movement_orders")
    .select("id,movement_purpose,path_system_ids,status")
    .eq("battle_operation_id", operationId)
    .eq("movement_purpose", "battle_return");
  fail("leer retornos", returnsResult.error);

  if (
    returnsResult.data.length !== 2 ||
    returnsResult.data.some((order) => order.status !== "moving")
  ) {
    throw new Error("No se crearon los dos retornos aliados.");
  }

  await forceArrival(returnsResult.data.map((order) => order.id));
  result = await custodes.rpc("resolve_movement_orders");
  fail("resolver retornos", result.error);
  const returnedUnits = await service
    .from("campaign_units")
    .select("id,current_system_id,status")
    .in("id", [farseer.id, rhino.id]);
  fail("leer retornados", returnedUnits.error);

  if (
    !returnedUnits.data.every((unit) => unit.status === "ready") ||
    returnedUnits.data.find((unit) => unit.id === farseer.id)?.current_system_id !==
      systemId["cinder-maw"] ||
    returnedUnits.data.find((unit) => unit.id === rhino.id)?.current_system_id !==
      systemId["azur-trench"]
  ) {
    throw new Error("Los apoyos no volvieron correctamente a sus planetas de origen.");
  }

  console.log(
    JSON.stringify(
      {
        coalitionDraft: "ok",
        attackerSupport: "ok",
        defenderSupport: "ok",
        lateSupportRejected: "ok",
        rosterLock: "ok",
        warTransit: "ok",
        alliedReturns: "ok",
        returnPaths: returnsResult.data.map((order) => order.path_system_ids)
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
