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

const url = env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const service = createClient(url, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
});

const checks = [];

function normalize(value) {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function recordCheck(name, detail = "ok") {
  checks.push({ name, detail });
  console.log(`OK - ${name}: ${detail}`);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function must(label, promise) {
  const result = await promise;

  if (result.error) {
    throw new Error(`${label}: ${result.error.message}`);
  }

  return result.data;
}

async function rpc(client, name, args = {}, label = name) {
  return must(label, client.rpc(name, args));
}

async function expectError(label, promise, fragment) {
  const result = await promise;

  if (!result.error) {
    throw new Error(`${label}: esperaba error y no fallo`);
  }

  if (fragment && !normalize(result.error.message).includes(normalize(fragment))) {
    throw new Error(`${label}: error inesperado: ${result.error.message}`);
  }

  recordCheck(label, result.error.message);
}

async function login(slug) {
  const client = createClient(url, anonKey, { auth: { persistSession: false } });
  const email = slug === "admin" ? "admin@rol40k.local" : `${slug}@rol40k.local`;
  const password = slug === "admin" ? "admin-local-123" : "rol40k-local-123";
  const { data, error } = await client.auth.signInWithPassword({ email, password });

  if (error) {
    throw new Error(`login ${slug}: ${error.message}`);
  }

  return { client, userId: data.user.id };
}

async function table(name, columns = "*") {
  return must(name, service.from(name).select(columns));
}

async function buildMaps() {
  const factions = await table("factions", "id,slug,name,is_narrative");
  const systems = await table(
    "systems",
    "id,slug,name,status,controller_faction_id,is_capital,blocked_until,building_slots"
  );
  const tech = await table("technology_nodes", "id,slug,name,implementation_status,tree_key");
  const buildings = await table("building_templates", "id,slug,name,building_kind");

  return {
    factions,
    systems,
    tech,
    buildings,
    factionBySlug: Object.fromEntries(factions.map((row) => [row.slug, row])),
    systemBySlug: Object.fromEntries(systems.map((row) => [row.slug, row])),
    techBySlug: Object.fromEntries(tech.map((row) => [row.slug, row])),
    buildingBySlug: Object.fromEntries(buildings.map((row) => [row.slug, row]))
  };
}

async function forceArrival(ids) {
  const list = (Array.isArray(ids) ? ids : [ids]).filter(Boolean);

  if (list.length === 0) {
    return 0;
  }

  await must(
    "forzar llegada",
    service
      .from("movement_orders")
      .update({ arrival_at: new Date(Date.now() - 1000).toISOString() })
      .in("id", list)
  );

  return rpc(service, "resolve_movement_orders", {}, "resolver movimientos forzados");
}

async function getUnitByName(factionId, namePart) {
  const rows = await must(
    `unidad ${namePart}`,
    service
      .from("campaign_units")
      .select("*")
      .eq("faction_id", factionId)
      .ilike("name", `%${namePart}%`)
      .gt("quantity", 0)
      .limit(10)
  );

  if (!rows.length) {
    throw new Error(`No encontre unidad ${namePart}`);
  }

  return rows[0];
}

async function upsertTechUnlocked(factionIds, nodeIds) {
  const now = new Date().toISOString();
  const rows = [];

  for (const factionId of factionIds) {
    for (const technologyNodeId of nodeIds) {
      if (factionId && technologyNodeId) {
        rows.push({
          faction_id: factionId,
          technology_node_id: technologyNodeId,
          status: "unlocked",
          started_at: now,
          finishes_at: now,
          unlocked_at: now
        });
      }
    }
  }

  if (rows.length) {
    await must(
      "desbloquear tecnologias fixture",
      service.from("faction_technologies").upsert(rows, {
        onConflict: "faction_id,technology_node_id"
      })
    );
  }
}

async function setResources(factionIds, amount) {
  await must(
    "set resources fixture",
    service
      .from("faction_resources")
      .update({
        supply: amount,
        minerals: amount,
        honor: amount,
        gold: amount,
        industrial_material: amount,
        uridium: amount,
        technology: amount
      })
      .in("faction_id", factionIds)
  );
}

async function ensureActiveBuilding(maps, systemSlug, buildingSlug, label = "edificio fixture") {
  const existing = (
    await must(
      `buscar ${label}`,
      service
        .from("system_buildings")
        .select("*")
        .eq("system_id", maps.systemBySlug[systemSlug].id)
        .eq("building_template_id", maps.buildingBySlug[buildingSlug].id)
        .limit(1)
    )
  )[0];

  if (existing) {
    return existing;
  }

  const now = new Date().toISOString();

  return must(
    `crear ${label}`,
    service
      .from("system_buildings")
      .insert({
        system_id: maps.systemBySlug[systemSlug].id,
        building_template_id: maps.buildingBySlug[buildingSlug].id,
        status: "active",
        started_at: now,
        finishes_at: now,
        constructed_at: now
      })
      .select("*")
      .single()
  );
}

async function resetCombatFixture(maps) {
  await must(
    "limpiar conflictos fixture",
    service
      .from("conflicts")
      .update({ status: "cancelled", blocked_until: null, resolved_at: new Date().toISOString() })
      .eq("status", "pending")
  );

  const resetSystems = [
    ["novem", "controlled", "necrones"],
    ["nexus-aster", "neutral", null],
    ["goregate", "neutral", null],
    ["maelstrom-gas", "neutral", null],
    ["voidmist-basin", "neutral", null],
    ["helios-drift", "controlled", "adeptus-custodes"],
    ["lyra-terminus", "controlled", "space-marines"],
    ["red-sabbath", "controlled", "cultos-genestealer"],
    ["drusus", "controlled", "legiones-daemonicas"]
  ];

  for (const [slug, status, factionSlug] of resetSystems) {
    await must(
      `reset sistema ${slug}`,
      service
        .from("systems")
        .update({
          status,
          controller_faction_id: factionSlug ? maps.factionBySlug[factionSlug].id : null,
          blocked_until: null,
          system_kind: slug.endsWith("-gas") || slug === "voidmist-basin" ? "gaseous" : "standard",
          is_conquerable: !(slug.endsWith("-gas") || slug === "voidmist-basin"),
          allows_shared_occupation: slug.endsWith("-gas") || slug === "voidmist-basin"
        })
        .eq("id", maps.systemBySlug[slug].id)
    );
  }

  await must(
    "ruta fixture coalicion",
    service.from("system_edges").upsert({
      id: "00000000-0000-0000-0000-000000000054",
      slug: "route-test-helios-novem",
      from_system_id: maps.systemBySlug["helios-drift"].id,
      to_system_id: maps.systemBySlug.novem.id,
      uridium_cost: 1,
      is_blocked: false
    })
  );

  const warUnits = await must(
    "unidades guerra seed",
    service.from("campaign_units").select("id,faction_id").eq("status", "in_war")
  );
  const capitalByFaction = Object.fromEntries(
    maps.systems
      .filter((system) => system.is_capital)
      .map((system) => [system.controller_faction_id, system.id])
  );

  for (const unit of warUnits) {
    await must(
      "sacar unidad seed de guerra",
      service
        .from("campaign_units")
        .update({ current_system_id: capitalByFaction[unit.faction_id], status: "ready" })
        .eq("id", unit.id)
    );
  }

  const necronWarrior = await getUnitByName(maps.factionBySlug.necrones.id, "Necron Warriors");
  await must(
    "poner defensor necron en Novem",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug.novem.id, status: "ready" })
      .eq("id", necronWarrior.id)
  );

  await must(
    "preparar Caladius inicial",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["helios-drift"].id, status: "ready" })
      .eq("faction_id", maps.factionBySlug["adeptus-custodes"].id)
      .ilike("name", "%Caladius%")
  );
  await must(
    "preparar Rhino",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["lyra-terminus"].id, status: "ready" })
      .eq("faction_id", maps.factionBySlug["space-marines"].id)
      .eq("name", "Rhino")
  );
  await must(
    "preparar Primus",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["red-sabbath"].id, status: "ready" })
      .eq("faction_id", maps.factionBySlug["cultos-genestealer"].id)
      .eq("name", "Primus")
  );
  await must(
    "preparar demonios",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug.drusus.id, status: "ready" })
      .eq("faction_id", maps.factionBySlug["legiones-daemonicas"].id)
      .eq("name", "Pink Horrors")
  );

  recordCheck("fixture combate", "Novem Necrones, Helios Custodes, rutas limpias");
}

async function main() {
  const admin = await login("admin");
  const custodes = await login("adeptus-custodes");
  const marines = await login("space-marines");
  const necrones = await login("necrones");
  const cultos = await login("cultos-genestealer");
  const daemonicas = await login("legiones-daemonicas");
  const maps = await buildMaps();

  const expectedPlayable = [
    "adeptus-custodes",
    "cultos-genestealer",
    "legiones-daemonicas",
    "necrones",
    "space-marines"
  ];
  const expectedNarrative = ["orcos", "tiranidos"];

  for (const slug of expectedPlayable) {
    assert(maps.factionBySlug[slug] && !maps.factionBySlug[slug].is_narrative, `Faccion jugable ausente: ${slug}`);
  }
  for (const slug of expectedNarrative) {
    assert(maps.factionBySlug[slug] && maps.factionBySlug[slug].is_narrative, `Faccion narrativa ausente: ${slug}`);
  }
  for (const removed of ["aeldari", "agentes-imperium", "astra-militarum", "orcos-waagh", "guardia-muerte"]) {
    assert(!maps.factionBySlug[removed], `Faccion obsoleta sigue presente: ${removed}`);
  }
  recordCheck("roster final de facciones", "5 jugables + orcos/tiranidos narrativas");

  const initialBuildings = await must(
    "edificios iniciales",
    service.from("system_buildings").select("id")
  );
  assert(initialBuildings.length === 0, `La campana debe arrancar sin edificios; encontrados ${initialBuildings.length}`);
  recordCheck("arranque sin edificios", "system_buildings vacio");

  const settings = await must(
    "campaign_settings",
    service.from("campaign_settings").select("*").eq("id", "default").single()
  );
  assert(settings.movement_edge_duration_seconds === 3, `Movimiento esperado 3s/arista, recibido ${settings.movement_edge_duration_seconds}`);
  assert(settings.attack_duration_seconds === 300, `Ataque esperado 300s, recibido ${settings.attack_duration_seconds}`);
  recordCheck("timers de test", "movimiento 3s/arista y ataque 5min");

  const battleLimits = await rpc(custodes.client, "get_battle_limit_summary", {}, "limites batalla ventana");
  const battleWindowMs = Date.parse(battleLimits.month_end) - Date.parse(battleLimits.month_start);
  assert(
    Math.abs(battleWindowMs - 33 * 24 * 60 * 60 * 1000) < 1000,
    `La ventana de operaciones debe ser 33 dias, recibida ${battleWindowMs / 86400000} dias`
  );
  recordCheck("ventana operaciones", "cupos de batalla se recargan cada 33 dias");

  await rpc(
    admin.client,
    "admin_set_campaign_limits",
    {
      max_supply: 10000,
      max_minerals: 10000,
      max_honor: 10000,
      max_gold: 10000,
      max_industrial_material: 10000,
      max_uridium: 10000,
      max_technology: 10000,
      max_army_points: 10000
    },
    "admin_set_campaign_limits"
  );
  recordCheck("admin limites", "caps subidos para fixture de stress");

  const playerFactionIds = expectedPlayable.map((slug) => maps.factionBySlug[slug].id);
  await setResources(playerFactionIds, 5000);

  const initialMoving = await must(
    "movimientos iniciales",
    service.from("movement_orders").select("id").eq("status", "moving")
  );
  await forceArrival(initialMoving.map((row) => row.id));
  recordCheck("movimientos seed resueltos", `${initialMoving.length} llegadas forzadas`);

  const custodianGuardForMove = await getUnitByName(maps.factionBySlug["adeptus-custodes"].id, "Custodian Guard");
  const shieldCaptainForMove = await getUnitByName(maps.factionBySlug["adeptus-custodes"].id, "Shield-Captain");
  await must(
    "preparar dos unidades para coste por unidad",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["kharon-prime"].id, status: "ready" })
      .in("id", [custodianGuardForMove.id, shieldCaptainForMove.id])
  );
  await must(
    "preparar helios neutral coste por unidad",
    service
      .from("systems")
      .update({ status: "neutral", controller_faction_id: null, blocked_until: null })
      .eq("id", maps.systemBySlug["helios-drift"].id)
  );
  const kharonHeliosEdge = await must(
    "arista Kharon-Helios",
    service
      .from("system_edges")
      .select("uridium_cost")
      .or(
        `and(from_system_id.eq.${maps.systemBySlug["kharon-prime"].id},to_system_id.eq.${maps.systemBySlug["helios-drift"].id}),and(from_system_id.eq.${maps.systemBySlug["helios-drift"].id},to_system_id.eq.${maps.systemBySlug["kharon-prime"].id})`
      )
      .single()
  );
  const resourcesBeforeUnitCost = await must(
    "recursos antes coste por unidad",
    service.from("faction_resources").select("uridium").eq("faction_id", maps.factionBySlug["adeptus-custodes"].id).single()
  );
  const unitCostMoveId = await rpc(
    custodes.client,
    "create_movement_order",
    {
      unit_selections: [
        { unit_id: custodianGuardForMove.id, quantity: custodianGuardForMove.quantity },
        { unit_id: shieldCaptainForMove.id, quantity: shieldCaptainForMove.quantity }
      ],
      path_system_ids: [maps.systemBySlug["kharon-prime"].id, maps.systemBySlug["helios-drift"].id]
    },
    "movimiento coste por unidad"
  );
  const unitCostOrder = await must(
    "orden coste por unidad",
    service.from("movement_orders").select("uridium_cost").eq("id", unitCostMoveId).single()
  );
  const expectedUnitCost = kharonHeliosEdge.uridium_cost * 2;
  assert(
    unitCostOrder.uridium_cost === expectedUnitCost,
    `Coste esperado ${expectedUnitCost}, recibido ${unitCostOrder.uridium_cost}`
  );
  const resourcesAfterUnitCost = await must(
    "recursos despues coste por unidad",
    service.from("faction_resources").select("uridium").eq("faction_id", maps.factionBySlug["adeptus-custodes"].id).single()
  );
  assert(
    Number(resourcesBeforeUnitCost.uridium) - Number(resourcesAfterUnitCost.uridium) === expectedUnitCost,
    "El descuento de Uridium no coincide con unidades movidas"
  );
  await forceArrival(unitCostMoveId);
  recordCheck("movimiento coste por unidad", `ruta ${kharonHeliosEdge.uridium_cost} x 2 unidades`);

  await must(
    "preparar gaseoso para ataque",
    service
      .from("systems")
      .update({ status: "neutral", controller_faction_id: null, blocked_until: null, system_kind: "gaseous", is_conquerable: false, allows_shared_occupation: true })
      .eq("id", maps.systemBySlug["maelstrom-gas"].id)
  );
  await must(
    "preparar objetivo orko gaseoso",
    service
      .from("systems")
      .update({ status: "controlled", controller_faction_id: maps.factionBySlug.orcos.id, blocked_until: null })
      .eq("id", maps.systemBySlug["nexus-aster"].id)
  );
  await must(
    "preparar unidad ataque gaseoso",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["maelstrom-gas"].id, status: "ready" })
      .eq("id", custodianGuardForMove.id)
  );
  const gasAttackOrderId = await rpc(
    custodes.client,
    "create_attack_order",
    {
      unit_selections: [{ unit_id: custodianGuardForMove.id, quantity: custodianGuardForMove.quantity }],
      origin_system_id: maps.systemBySlug["maelstrom-gas"].id,
      target_system_id: maps.systemBySlug["nexus-aster"].id
    },
    "ataque desde gaseoso"
  );
  const gasAttackOrder = await must(
    "orden ataque gaseoso",
    service.from("movement_orders").select("battle_operation_id,status").eq("id", gasAttackOrderId).single()
  );
  assert(gasAttackOrder.status === "moving", "El ataque desde gaseoso no quedo en camino");
  await must(
    "limpiar ataque gaseoso fixture",
    service.from("battle_operations").update({ status: "cancelled", updated_at: new Date().toISOString() }).eq("id", gasAttackOrder.battle_operation_id)
  );
  await must(
    "limpiar orden ataque gaseoso fixture",
    service.from("movement_orders").update({ status: "cancelled", cancelled_at: new Date().toISOString() }).eq("id", gasAttackOrderId)
  );
  await must(
    "devolver unidad ataque gaseoso fixture",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["kharon-prime"].id, status: "ready" })
      .eq("id", custodianGuardForMove.id)
  );
  recordCheck("ataque desde gaseoso", "origen compartido permite lanzar contra adyacente enemigo");

  await must(
    "preparar origen enemigo autorizado",
    service
      .from("systems")
      .update({ status: "controlled", controller_faction_id: maps.factionBySlug.necrones.id, blocked_until: null })
      .in("id", [maps.systemBySlug["kharon-prime"].id, maps.systemBySlug["helios-drift"].id])
  );
  await must(
    "preparar unidad en origen enemigo",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["kharon-prime"].id, status: "ready" })
      .eq("id", custodianGuardForMove.id)
  );
  const foreignOriginAttackOrderId = await rpc(
    custodes.client,
    "create_attack_order",
    {
      unit_selections: [{ unit_id: custodianGuardForMove.id, quantity: custodianGuardForMove.quantity }],
      origin_system_id: maps.systemBySlug["kharon-prime"].id,
      target_system_id: maps.systemBySlug["helios-drift"].id
    },
    "ataque desde origen enemigo autorizado"
  );
  const foreignOriginAttackOrder = await must(
    "orden ataque origen enemigo",
    service.from("movement_orders").select("battle_operation_id,status").eq("id", foreignOriginAttackOrderId).single()
  );
  assert(foreignOriginAttackOrder.status === "moving", "El ataque desde origen enemigo autorizado no quedo en camino");
  await must(
    "limpiar operacion origen enemigo fixture",
    service
      .from("battle_operations")
      .update({ status: "cancelled", updated_at: new Date().toISOString() })
      .eq("id", foreignOriginAttackOrder.battle_operation_id)
  );
  await must(
    "limpiar orden origen enemigo fixture",
    service
      .from("movement_orders")
      .update({ status: "cancelled", cancelled_at: new Date().toISOString() })
      .eq("id", foreignOriginAttackOrderId)
  );
  await must(
    "restaurar sistemas origen enemigo fixture",
    service
      .from("systems")
      .update({ status: "controlled", controller_faction_id: maps.factionBySlug["adeptus-custodes"].id, blocked_until: null })
      .eq("id", maps.systemBySlug["kharon-prime"].id)
  );
  await must(
    "restaurar Helios origen enemigo fixture",
    service
      .from("systems")
      .update({ status: "neutral", controller_faction_id: null, blocked_until: null })
      .eq("id", maps.systemBySlug["helios-drift"].id)
  );
  await must(
    "devolver unidad origen enemigo fixture",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["kharon-prime"].id, status: "ready" })
      .eq("id", custodianGuardForMove.id)
  );
  recordCheck("ataque desde origen enemigo", "presencia propia autorizada sirve como origen");

  await expectError(
    "tecnologia planned bloqueada",
    custodes.client.rpc("start_technology_research", {
      technology_node_id: maps.techBySlug["oficina-inteligencia"].id
    }),
    "bloqueada"
  );

  await rpc(
    custodes.client,
    "start_technology_research",
    { technology_node_id: maps.techBySlug["maquinaria-belica"].id },
    "start tecnologia activa"
  );
  await must(
    "vencer investigacion",
    service
      .from("faction_technologies")
      .update({ finishes_at: new Date(Date.now() - 1000).toISOString() })
      .eq("faction_id", maps.factionBySlug["adeptus-custodes"].id)
      .eq("technology_node_id", maps.techBySlug["maquinaria-belica"].id)
  );
  await rpc(service, "resolve_technology_research", {}, "resolve tecnologia");
  const machinery = await must(
    "maquinaria desbloqueada",
    service
      .from("faction_technologies")
      .select("status")
      .eq("faction_id", maps.factionBySlug["adeptus-custodes"].id)
      .eq("technology_node_id", maps.techBySlug["maquinaria-belica"].id)
      .single()
  );
  assert(machinery.status === "unlocked", "La tecnologia activa no quedo desbloqueada");
  recordCheck("tecnologia activa", "investiga y resuelve en 3s");

  await upsertTechUnlocked(
    playerFactionIds,
    [
      "fundacion-planetaria",
      "maquinaria-belica",
      "pactos-mercantiles",
      "contactos-economicos",
      "mercado-galactico",
      "tratos-preferentes",
      "aranceles-privilegiados"
    ].map((slug) => maps.techBySlug[slug]?.id)
  );

  await resetCombatFixture(maps);

  await must(
    "custodes recursos a 0 para produccion",
    service
      .from("faction_resources")
      .update({
        supply: 0,
        minerals: 0,
        honor: 0,
        gold: 0,
        industrial_material: 0,
        uridium: 0,
        technology: 5000
      })
      .eq("faction_id", maps.factionBySlug["adeptus-custodes"].id)
  );
  const foundryFixture = await must(
    "crear planta Kharon fixture",
    service
      .from("system_buildings")
      .insert({
        system_id: maps.systemBySlug["kharon-prime"].id,
        building_template_id: maps.buildingBySlug["planta-fundicion"].id,
        status: "active",
        started_at: new Date().toISOString(),
        finishes_at: new Date().toISOString(),
        constructed_at: new Date().toISOString()
      })
      .select("*")
      .single()
  );
  await must(
    "tick vencido",
    service
      .from("campaign_settings")
      .update({
        next_resource_tick_at: new Date(Date.now() - 1000).toISOString(),
        last_resource_tick_at: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
      })
      .eq("id", "default")
  );
  await rpc(service, "resolve_resource_ticks", {}, "resolve recurso");
  const produced = await must(
    "recursos producidos Custodes",
    service.from("faction_resources").select("*").eq("faction_id", maps.factionBySlug["adeptus-custodes"].id).single()
  );
  assert(Number(produced.industrial_material) === 5, `Planta de Kharon debia producir 5 material, produjo ${produced.industrial_material}`);
  recordCheck("produccion por capacidad planetaria", "Kharon Prime material industrial = 5/dia");

  const foundry = (
    await must(
      "buscar planta de Kharon",
      service
        .from("system_buildings")
        .select("*")
        .eq("id", foundryFixture.id)
        .limit(1)
    )
  )[0];
  assert(foundry, "Kharon Prime debia tener Planta de Fundicion activa");
  const resourcesBeforeDestroy = await must(
    "recursos antes destruir edificio",
    service.from("faction_resources").select("*").eq("faction_id", maps.factionBySlug["adeptus-custodes"].id).single()
  );
  const destroyedBuildingId = await rpc(
    custodes.client,
    "destroy_system_building",
    { system_building_id: foundry.id },
    "destruir edificio propio"
  );
  assert(destroyedBuildingId === foundry.id, "La RPC de destruccion no devolvio el edificio destruido");
  const resourcesAfterDestroy = await must(
    "recursos tras destruir edificio",
    service.from("faction_resources").select("*").eq("faction_id", maps.factionBySlug["adeptus-custodes"].id).single()
  );
  assert(
    resourcesAfterDestroy.industrial_material === resourcesBeforeDestroy.industrial_material &&
      resourcesAfterDestroy.supply === resourcesBeforeDestroy.supply &&
      resourcesAfterDestroy.minerals === resourcesBeforeDestroy.minerals,
    "Destruir edificio no debe devolver recursos"
  );
  const destroyedRows = await must(
    "edificio destruido desaparece",
    service.from("system_buildings").select("id").eq("id", foundry.id)
  );
  assert(destroyedRows.length === 0, "El edificio destruido no desaparecio del sistema");
  const productionAfterDestroy = await must(
    "produccion tras destruir edificio",
    service
      .from("system_production")
      .select("industrial_material_per_tick")
      .eq("system_id", maps.systemBySlug["kharon-prime"].id)
      .single()
  );
  assert(
    productionAfterDestroy.industrial_material_per_tick === 0,
    "La produccion derivada de Material Industrial debia caer a 0 tras destruir la Planta"
  );
  await must(
    "reconstruir planta fixture",
    service
      .from("system_buildings")
      .insert({
        system_id: maps.systemBySlug["kharon-prime"].id,
        building_template_id: maps.buildingBySlug["planta-fundicion"].id,
        status: "active",
        started_at: new Date().toISOString(),
        finishes_at: new Date().toISOString(),
        constructed_at: new Date().toISOString()
      })
      .select("*")
      .single()
  );
  await rpc(service, "refresh_system_production_from_buildings", {}, "refrescar produccion tras reconstruir planta");
  recordCheck("destruccion de edificios", "sin reembolso, libera slot y refresca produccion derivada");
  await setResources(playerFactionIds, 5000);
  await ensureActiveBuilding(maps, "kharon-prime", "camara-comercio", "camara comercio Custodes fixture");
  await ensureActiveBuilding(maps, "sa-cea-gate", "camara-comercio", "camara comercio Marines fixture");

  await rpc(
    custodes.client,
    "merchant_trade",
    { resource_key: "minerals", direction: "buy", trade_quantity: 3 },
    "mercader compra minerales"
  );
  const sellOfferId = await rpc(
    custodes.client,
    "create_trade_offer",
    {
      offer_type: "sell",
      resource_key: "industrialMaterial",
      resource_amount: 5,
      gold_amount: 10
    },
    "crear oferta venta industrialMaterial"
  );
  await rpc(marines.client, "accept_trade_offer", { offer_id: sellOfferId }, "aceptar oferta estelar");
  const acceptedOffer = await must(
    "oferta aceptada",
    service.from("trade_offers").select("status,is_reserved,resource_key").eq("id", sellOfferId).single()
  );
  assert(
    acceptedOffer.status === "accepted" && acceptedOffer.resource_key === "industrial_material",
    "Comercio estelar no normalizo/acepto la oferta"
  );
  recordCheck("comercio", "mercader + oferta estelar con reserva y resourceKey camelCase");

  const taller = await ensureActiveBuilding(maps, "kharon-prime", "taller-guerra", "taller Custodes fixture");
  const caladiusTemplate = await must(
    "template Caladius",
    service
      .from("unit_templates")
      .select("*")
      .eq("faction_id", maps.factionBySlug["adeptus-custodes"].id)
      .eq("name", "Caladius Grav-tank")
      .single()
  );
  await upsertTechUnlocked([maps.factionBySlug["adeptus-custodes"].id], [caladiusTemplate.required_technology_node_id]);
  const queueId = await rpc(
    custodes.client,
    "recruit_unit_variant_at_building",
    {
      system_building_id: taller.id,
      unit_template_id: caladiusTemplate.id,
      model_count: 1,
      wargear_selections: [{ slug: "twin-arachnus-heavy-blaze-cannon", quantity: 1 }]
    },
    "reclutar Caladius variante"
  );
  const queue = await must("cola Caladius", service.from("recruitment_queue").select("*").eq("id", queueId).single());
  assert(
    queue.selected_points === 225 && queue.selected_wargear_points === 15,
    `Caladius variante esperaba 225/+15, recibido ${queue.selected_points}/+${queue.selected_wargear_points}`
  );
  await expectError(
    "una cola por edificio",
    custodes.client.rpc("recruit_unit_variant_at_building", {
      system_building_id: taller.id,
      unit_template_id: caladiusTemplate.id,
      model_count: 1,
      wargear_selections: []
    }),
    "cola activa"
  );
  await must(
    "vencer cola Caladius",
    service.from("recruitment_queue").update({ finishes_at: new Date(Date.now() - 1000).toISOString() }).eq("id", queueId)
  );
  await rpc(service, "resolve_recruitment_queue", {}, "resolve reclutamiento");
  const recruited = await must(
    "unidad Caladius reclutada",
    service.from("campaign_units").select("*").like("slug", `recruited-${queueId}-%`).single()
  );
  assert(
    recruited.points === 225 && recruited.selected_wargear_points === 15 && recruited.status === "ready",
    "Caladius variante no se creo con los puntos/equipo esperados"
  );
  recordCheck("reclutamiento variantes", "Caladius 225 pts con Twin Arachnus, sin ambiguous column");

  const sanctuary = await ensureActiveBuilding(
    maps,
    "kharon-prime",
    "santuario-reliquias",
    "santuario Custodes fixture"
  );
  const relic = (
    await must(
      "reliquia Custodes",
      service
        .from("relics")
        .select("*")
        .eq("faction_id", maps.factionBySlug["adeptus-custodes"].id)
        .eq("system_id", maps.systemBySlug["kharon-prime"].id)
        .is("equipped_unit_id", null)
        .limit(1)
    )
  )[0];
  const shieldCaptain = await getUnitByName(maps.factionBySlug["adeptus-custodes"].id, "Shield-Captain");
  await must(
    "preparar Shield-Captain",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["kharon-prime"].id, status: "ready", experience: 3 })
      .eq("id", shieldCaptain.id)
  );
  await rpc(
    custodes.client,
    "equip_relic_to_character",
    { relic_id: relic.id, character_unit_id: shieldCaptain.id, system_building_id: sanctuary.id },
    "equipar reliquia"
  );
  await rpc(
    custodes.client,
    "unequip_relic_from_character",
    { relic_id: relic.id, system_building_id: sanctuary.id },
    "desequipar reliquia"
  );
  const relicBack = await must(
    "reliquia vuelta santuario",
    service.from("relics").select("system_id,equipped_unit_id").eq("id", relic.id).single()
  );
  assert(
    relicBack.system_id === maps.systemBySlug["kharon-prime"].id && relicBack.equipped_unit_id === null,
    "Reliquia no volvio al santuario"
  );
  recordCheck("reliquias", "equipar/desequipar character nivel 3");

  await rpc(custodes.client, "retire_campaign_unit", { campaign_unit_id: recruited.id }, "retirar unidad reclutada");
  const retired = await must(
    "unidad retirada",
    service.from("campaign_units").select("status,quantity,wounds_taken").eq("id", recruited.id).single()
  );
  assert(retired.status === "destroyed" && retired.quantity === 0 && retired.wounds_taken === 0, "Retirada no destruyo soft-delete correctamente");
  recordCheck("retirada voluntaria", "sin reembolso y soft-delete");

  const intercessor = await getUnitByName(maps.factionBySlug["space-marines"].id, "Intercessor Squad");
  await must(
    "preparar Intercessor paso",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["sa-cea-gate"].id, status: "ready" })
      .eq("id", intercessor.id)
  );
  const passageOrderId = await rpc(
    marines.client,
    "create_movement_order",
    {
      unit_selections: [{ unit_id: intercessor.id, quantity: intercessor.quantity }],
      path_system_ids: ["sa-cea-gate", "lyra-terminus", "maelstrom-gas", "nexus-aster", "voidmist-basin", "helios-drift"].map(
        (slug) => maps.systemBySlug[slug].id
      )
    },
    "movimiento con permiso ajeno"
  );
  const passageOrder = await must(
    "orden pendiente paso",
    service.from("movement_orders").select("status").eq("id", passageOrderId).single()
  );
  assert(passageOrder.status === "pending_approval", `Movimiento ajeno debia quedar pending_approval, quedo ${passageOrder.status}`);
  const passageRequest = await must(
    "solicitud paso",
    service.from("movement_passage_requests").select("*").eq("movement_order_id", passageOrderId).single()
  );
  assert(passageRequest.responder_faction_id === maps.factionBySlug["adeptus-custodes"].id, "Solicitud de paso no fue al controlador del destino");
  const visibleToResponder = await must(
    "RLS tropas solicitud paso",
    custodes.client.from("campaign_units").select("id,name").eq("id", intercessor.id)
  );
  assert(visibleToResponder.length === 1, "El receptor de la peticion no ve las tropas solicitadas");
  await rpc(
    custodes.client,
    "respond_movement_passage_request",
    { passage_request_id: passageRequest.id, decision: "rejected", response_reason: "Prueba local" },
    "rechazar paso"
  );
  const rejectedOrder = await must(
    "orden rechazada",
    service.from("movement_orders").select("status").eq("id", passageOrderId).single()
  );
  assert(rejectedOrder.status === "cancelled", "Rechazar paso no cancelo movimiento");
  recordCheck("permisos de paso", "pendiente, tropas visibles para receptor y rechazo cancela");

  await expectError(
    "capital inmune a operaciones",
    service.from("battle_operations").insert({
      mode: "solo",
      status: "moving",
      leader_faction_id: maps.factionBySlug.necrones.id,
      defender_faction_id: maps.factionBySlug["adeptus-custodes"].id,
      origin_system_id: maps.systemBySlug.novem.id,
      target_system_id: maps.systemBySlug["kharon-prime"].id,
      created_by_user_id: admin.userId
    }),
    "capitales"
  );
  await expectError(
    "capital inmune a narrativa",
    admin.client.rpc("admin_create_narrative_attack", {
      target_system_id: maps.systemBySlug["kharon-prime"].id,
      narrative_faction_id: maps.factionBySlug.orcos.id,
      attack_description: "La horda prueba el bloqueo de capital",
      arrival_at: new Date(Date.now() + 60000).toISOString()
    }),
    "capitales"
  );
  const narrativeAttackId = await rpc(
    admin.client,
    "admin_create_narrative_attack",
    {
      target_system_id: maps.systemBySlug["red-sabbath"].id,
      narrative_faction_id: maps.factionBySlug.tiranidos.id,
      attack_description: "Una bioflota de prueba cruza los sensores exteriores.",
      arrival_at: new Date(Date.now() + 60000).toISOString()
    },
    "crear ataque narrativo futuro"
  );
  const narrativeAttack = await must(
    "ataque narrativo incoming",
    service.from("narrative_attacks").select("status").eq("id", narrativeAttackId).single()
  );
  assert(narrativeAttack.status === "incoming", "Ataque narrativo no quedo incoming");
  const missionId = await rpc(
    admin.client,
    "admin_create_narrative_mission",
    {
      anchor_system_id: maps.systemBySlug["nexus-aster"].id,
      narrative_faction_id: maps.factionBySlug.orcos.id,
      mission_name: "Puesto orbital de prueba",
      mission_description: "Una senal de guerra improvisada reclama botin entre asteroides.",
      enemy_units_visible: true,
      enemy_units: [{ name: "Horda de Boyz", quantity: "20" }],
      duration_days: 1,
      expires_after_battle: false
    },
    "crear mision temporal"
  );
  const mission = await must(
    "mision temporal creada",
    service.from("systems").select("is_temporary_mission,mission_enemy_units_visible").eq("id", missionId).single()
  );
  assert(mission.is_temporary_mission && mission.mission_enemy_units_visible, "Mision temporal no quedo visible como mision");
  await rpc(admin.client, "admin_remove_temporary_mission", { target_system_id: missionId }, "eliminar mision temporal");
  await rpc(
    admin.client,
    "admin_create_campaign_event",
    { event_title: "Prueba de evento", event_content: "La galaxia registra una senal de validacion." },
    "crear evento admin"
  );
  recordCheck("admin narrativo/eventos", "ataques con llegada, mision temporal eliminable y evento");

  const caladius = await getUnitByName(maps.factionBySlug["adeptus-custodes"].id, "Caladius Grav-tank");
  const rhino = await getUnitByName(maps.factionBySlug["space-marines"].id, "Rhino");
  await must(
    "asegurar origen custodes",
    service
      .from("systems")
      .update({ status: "controlled", controller_faction_id: maps.factionBySlug["adeptus-custodes"].id, blocked_until: null })
      .eq("id", maps.systemBySlug["helios-drift"].id)
  );
  await must(
    "preparar Caladius coalicion",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["helios-drift"].id, status: "ready" })
      .eq("id", caladius.id)
  );
  await must(
    "preparar Rhino coalicion",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug["lyra-terminus"].id, status: "ready" })
      .eq("id", rhino.id)
  );
  const operationId = await rpc(
    custodes.client,
    "create_coalition_attack_draft",
    {
      unit_selections: [{ unit_id: caladius.id, quantity: caladius.quantity }],
      origin_system_id: maps.systemBySlug["helios-drift"].id,
      target_system_id: maps.systemBySlug.novem.id,
      invited_faction_ids: [maps.factionBySlug["space-marines"].id]
    },
    "crear coalicion atacante"
  );
  await expectError(
    "coalicion no lanza con invitaciones pendientes",
    custodes.client.rpc("launch_coalition_attack", { operation_id: operationId }),
    "invitaciones"
  );
  await expectError(
    "aliado atacante no marca listo sin aceptar",
    marines.client.rpc("join_battle_operation", {
      operation_id: operationId,
      unit_selections: [{ unit_id: rhino.id, quantity: rhino.quantity }],
      path_system_ids: [maps.systemBySlug["helios-drift"].id]
    }),
    "aceptar"
  );
  await rpc(marines.client, "respond_battle_support_invitation", { operation_id: operationId, decision: "accepted" }, "aceptar coalicion atacante");
  await expectError(
    "coalicion no lanza con aliado sin listo",
    custodes.client.rpc("launch_coalition_attack", { operation_id: operationId }),
    "sin tropas"
  );
  await expectError(
    "join atacante ya no mueve por ruta larga",
    marines.client.rpc("join_battle_operation", {
      operation_id: operationId,
      unit_selections: [{ unit_id: rhino.id, quantity: rhino.quantity }],
      path_system_ids: ["lyra-terminus", "maelstrom-gas", "nexus-aster", "voidmist-basin", "helios-drift"].map(
        (slug) => maps.systemBySlug[slug].id
      )
    }),
    "sistema de salida"
  );
  const stagingMoveId = await rpc(
    marines.client,
    "create_movement_order",
    {
      unit_selections: [{ unit_id: rhino.id, quantity: rhino.quantity }],
      path_system_ids: ["lyra-terminus", "maelstrom-gas", "nexus-aster", "voidmist-basin", "helios-drift"].map(
        (slug) => maps.systemBySlug[slug].id
      )
    },
    "mover aliado atacante al origen"
  );
  const stagingMove = await must(
    "staging auto aceptado",
    service.from("movement_orders").select("status,movement_type").eq("id", stagingMoveId).single()
  );
  assert(stagingMove.status === "moving", `El movimiento de aliado al origen debia autoaceptarse, quedo ${stagingMove.status}`);
  await forceArrival(stagingMoveId);
  const rhinoAtOrigin = await must(
    "Rhino en origen",
    service.from("campaign_units").select("current_system_id,status").eq("id", rhino.id).single()
  );
  assert(
    rhinoAtOrigin.current_system_id === maps.systemBySlug["helios-drift"].id && rhinoAtOrigin.status === "ready",
    "Rhino no llego listo al origen"
  );
  await rpc(
    marines.client,
    "join_battle_operation",
    {
      operation_id: operationId,
      unit_selections: [{ unit_id: rhino.id, quantity: rhino.quantity }],
      path_system_ids: [maps.systemBySlug["helios-drift"].id]
    },
    "marcar atacante listo"
  );
  const attackOrderId = await rpc(custodes.client, "launch_coalition_attack", { operation_id: operationId }, "lanzar coalicion");
  const attackOrder = await must(
    "orden ataque",
    service.from("movement_orders").select("status,duration_seconds,arrival_at").eq("id", attackOrderId).single()
  );
  assert(attackOrder.status === "moving" && attackOrder.duration_seconds === 300, `Ataque debia durar 300s, recibido ${attackOrder.duration_seconds}`);
  recordCheck("coalicion atacante", "aceptar -> mover al origen -> marcar listo -> lanzar 5min");

  await expectError(
    "bloqueo ataque duplicado mismo objetivo",
    service.from("battle_operations").insert({
      mode: "solo",
      status: "moving",
      leader_faction_id: maps.factionBySlug["adeptus-custodes"].id,
      defender_faction_id: maps.factionBySlug.necrones.id,
      origin_system_id: maps.systemBySlug["helios-drift"].id,
      target_system_id: maps.systemBySlug.novem.id,
      created_by_user_id: admin.userId
    }),
    "ataque activo"
  );
  await expectError(
    "bloqueo contraataque reciproco",
    service.from("battle_operations").insert({
      mode: "solo",
      status: "moving",
      leader_faction_id: maps.factionBySlug.necrones.id,
      defender_faction_id: maps.factionBySlug["adeptus-custodes"].id,
      origin_system_id: maps.systemBySlug.novem.id,
      target_system_id: maps.systemBySlug["helios-drift"].id,
      created_by_user_id: admin.userId
    }),
    "contraatacar"
  );

  await rpc(
    necrones.client,
    "invite_battle_support",
    {
      operation_id: operationId,
      target_faction_id: maps.factionBySlug["cultos-genestealer"].id,
      support_side: "defender"
    },
    "invitar defensa cultos"
  );
  await rpc(
    necrones.client,
    "invite_battle_support",
    {
      operation_id: operationId,
      target_faction_id: maps.factionBySlug["legiones-daemonicas"].id,
      support_side: "defender"
    },
    "invitar defensa daemonicas"
  );
  await rpc(cultos.client, "respond_battle_support_invitation", { operation_id: operationId, decision: "accepted" }, "cultos aceptan defensa");
  await rpc(daemonicas.client, "respond_battle_support_invitation", { operation_id: operationId, decision: "accepted" }, "daemonicas aceptan defensa");
  const primus = await getUnitByName(maps.factionBySlug["cultos-genestealer"].id, "Primus");
  const horrors = await getUnitByName(maps.factionBySlug["legiones-daemonicas"].id, "Pink Horrors");
  await expectError(
    "defensor no usa join directo",
    cultos.client.rpc("join_battle_operation", {
      operation_id: operationId,
      unit_selections: [{ unit_id: primus.id, quantity: primus.quantity }],
      path_system_ids: [maps.systemBySlug.novem.id]
    }),
    "apoyo defensivo"
  );
  const cultMoveId = await rpc(
    cultos.client,
    "create_movement_order",
    {
      unit_selections: [{ unit_id: primus.id, quantity: primus.quantity }],
      path_system_ids: ["red-sabbath", "maelstrom-gas", "nexus-aster", "voidmist-basin", "novem"].map(
        (slug) => maps.systemBySlug[slug].id
      )
    },
    "cultos mueven defensa"
  );
  const daemonMoveId = await rpc(
    daemonicas.client,
    "create_movement_order",
    {
      unit_selections: [{ unit_id: horrors.id, quantity: horrors.quantity }],
      path_system_ids: ["drusus", "maelstrom-gas", "nexus-aster", "voidmist-basin", "novem"].map(
        (slug) => maps.systemBySlug[slug].id
      )
    },
    "daemonicas mueven defensa tardia"
  );
  await forceArrival(cultMoveId);
  await must(
    "hacer daemonicas tarde",
    service.from("movement_orders").update({ arrival_at: new Date(Date.now() + 300000).toISOString() }).eq("id", daemonMoveId)
  );
  await forceArrival(attackOrderId);
  const conflict = await must(
    "conflicto generado",
    service.from("conflicts").select("*").eq("battle_operation_id", operationId).single()
  );
  assert(conflict.status === "pending", "La llegada del ataque no creo conflicto pendiente");
  const cultCommitment = await must(
    "compromiso defensor cultos",
    service.from("battle_unit_commitments").select("status,side,role").eq("operation_id", operationId).eq("unit_id", primus.id).single()
  );
  assert(cultCommitment.status === "in_battle" && cultCommitment.side === "defender", "Apoyo defensor llegado a tiempo no entro en batalla");
  await forceArrival(daemonMoveId);
  const lateDaemon = await must(
    "daemonicas redirigidas",
    service.from("campaign_units").select("current_system_id,status").eq("id", horrors.id).single()
  );
  const daemonHome = await must(
    "sistema vivo apoyo tardio",
    service.from("systems").select("controller_faction_id,status").eq("id", lateDaemon.current_system_id).single()
  );
  assert(
    lateDaemon.status === "ready" && daemonHome.controller_faction_id === maps.factionBySlug["legiones-daemonicas"].id,
    "Apoyo tardio no fue redirigido a aliado seguro"
  );
  recordCheck("defensa dinamica", "join rechazado, llegada temprana entra, llegada tardia se redirige");

  await rpc(
    admin.client,
    "admin_set_system_block",
    { target_system_id: maps.systemBySlug.novem.id, blocked_until: null },
    "admin desbloquea conflicto"
  );
  const clearedConflict = await must(
    "conflicto cancelado admin",
    service.from("conflicts").select("status,blocked_until").eq("id", conflict.id).single()
  );
  assert(clearedConflict.status === "cancelled" && clearedConflict.blocked_until === null, "Admin unlock no cancelo conflicto");
  const unitsStillInWar = await must(
    "unidades aun en guerra Azur",
    service.from("campaign_units").select("id").eq("current_system_id", maps.systemBySlug.novem.id).eq("status", "in_war")
  );
  assert(unitsStillInWar.length === 0, "Quedan unidades in_war en el sistema desbloqueado");
  recordCheck("admin desbloqueo conflicto", "conflicto desaparece y tropas evacuan a aliado seguro");

  await resetCombatFixture(maps);
  const autoReportBlockUntil = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
  const autoReportCustodian = await getUnitByName(maps.factionBySlug["adeptus-custodes"].id, "Custodian Guard");
  const autoReportWarriors = await getUnitByName(maps.factionBySlug.necrones.id, "Necron Warriors");
  await must(
    "preparar sistema reporte auto",
    service
      .from("systems")
      .update({
        status: "war",
        controller_faction_id: maps.factionBySlug.necrones.id,
        blocked_until: autoReportBlockUntil
      })
      .eq("id", maps.systemBySlug.novem.id)
  );
  await must(
    "preparar unidades reporte auto",
    service
      .from("campaign_units")
      .update({ current_system_id: maps.systemBySlug.novem.id, status: "in_war", wounds_taken: 0 })
      .in("id", [autoReportCustodian.id, autoReportWarriors.id])
  );
  const autoConflict = await must(
    "crear conflicto reporte auto",
    service
      .from("conflicts")
      .insert({
        system_id: maps.systemBySlug.novem.id,
        attacker_faction_id: maps.factionBySlug["adeptus-custodes"].id,
        defender_faction_id: maps.factionBySlug.necrones.id,
        status: "pending",
        blocked_until: autoReportBlockUntil,
        notes: "Fixture de informe automatico"
      })
      .select("*")
      .single()
  );
  const autoSurvivors = {
    [autoReportCustodian.id]: autoReportCustodian.quantity,
    [autoReportWarriors.id]: Math.max(1, autoReportWarriors.quantity - 1)
  };
  const autoWounds = {
    [autoReportCustodian.id]: 0,
    [autoReportWarriors.id]: 0
  };
  await rpc(
    custodes.client,
    "submit_battle_report",
    {
      conflict_id: autoConflict.id,
      report_payload: {
        battle_mode: "tabletop",
        winner_faction_id: maps.factionBySlug["adeptus-custodes"].id,
        final_controller_faction_id: maps.factionBySlug["adeptus-custodes"].id,
        survivors: autoSurvivors,
        wounds_remaining: autoWounds,
        post_battle_blocked_until: autoReportBlockUntil,
        narrative_notes: "Los Custodes aseguran el corredor tras una retirada necrona ordenada."
      }
    },
    "crear informe auto"
  );
  await rpc(custodes.client, "validate_battle_report", { target_conflict_id: autoConflict.id }, "validar informe Custodes");
  const reportAwaitingNecrons = await must(
    "informe espera segunda validacion",
    service.from("battle_reports").select("status").eq("conflict_id", autoConflict.id).single()
  );
  assert(reportAwaitingNecrons.status === "awaiting_validation", "El informe debia esperar a la faccion defensora");
  await rpc(necrones.client, "validate_battle_report", { target_conflict_id: autoConflict.id }, "validar informe Necrones");
  const autoReport = await must(
    "informe autoconfirmado",
    service.from("battle_reports").select("status,resolved_at").eq("conflict_id", autoConflict.id).single()
  );
  assert(autoReport.status === "auto_confirmed" && autoReport.resolved_at, "El informe no se autoconfirmo tras ambas validaciones");
  const autoResolvedConflict = await must(
    "conflicto autoconfirmado",
    service.from("conflicts").select("status,winner_faction_id").eq("id", autoConflict.id).single()
  );
  assert(
    autoResolvedConflict.status === "resolved" && autoResolvedConflict.winner_faction_id === maps.factionBySlug["adeptus-custodes"].id,
    "La autoconfirmacion no resolvio el conflicto"
  );
  const retreatedWarriors = await must(
    "perdedor retirado seguro",
    service.from("campaign_units").select("current_system_id,status,quantity,wounds_taken").eq("id", autoReportWarriors.id).single()
  );
  const retreatSystem = await must(
    "sistema retirada seguro",
    service.from("systems").select("controller_faction_id,status,blocked_until").eq("id", retreatedWarriors.current_system_id).single()
  );
  assert(
    retreatedWarriors.status === "ready" &&
      retreatedWarriors.quantity === autoSurvivors[autoReportWarriors.id] &&
      retreatedWarriors.wounds_taken === 0 &&
      retreatedWarriors.current_system_id !== maps.systemBySlug.novem.id &&
      retreatSystem.controller_faction_id === maps.factionBySlug.necrones.id &&
      retreatSystem.status === "controlled" &&
      (!retreatSystem.blocked_until || Date.parse(retreatSystem.blocked_until) <= Date.now()),
    "El perdedor superviviente no se retiro al aliado seguro mas cercano"
  );
  recordCheck("reportes auto", "doble validacion aplica resultado y retira perdedor a aliado seguro");

  console.log(`\nRESULTADO: ${checks.length} checks OK`);
}

main().catch((error) => {
  console.error("\nFALLO EN TEST:", error.message);
  process.exitCode = 1;
});
