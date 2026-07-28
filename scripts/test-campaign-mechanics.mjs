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

  const settings = await must(
    "campaign_settings",
    service.from("campaign_settings").select("*").eq("id", "default").single()
  );
  assert(settings.movement_edge_duration_seconds === 3, `Movimiento esperado 3s/arista, recibido ${settings.movement_edge_duration_seconds}`);
  assert(settings.attack_duration_seconds === 300, `Ataque esperado 300s, recibido ${settings.attack_duration_seconds}`);
  recordCheck("timers de test", "movimiento 3s/arista y ataque 5min");

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
  assert(produced.industrial_material === 20, `Planta de Kharon debia producir 20 material, produjo ${produced.industrial_material}`);
  recordCheck("produccion por capacidad planetaria", "Kharon Prime material industrial = 20/dia");
  await setResources(playerFactionIds, 5000);

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

  let taller = (
    await must(
      "buscar taller Custodes",
      service
        .from("system_buildings")
        .select("*")
        .eq("system_id", maps.systemBySlug["kharon-prime"].id)
        .eq("building_template_id", maps.buildingBySlug["taller-guerra"].id)
        .limit(1)
    )
  )[0];
  if (!taller) {
    taller = await must(
      "crear taller fixture",
      service
        .from("system_buildings")
        .insert({
          system_id: maps.systemBySlug["kharon-prime"].id,
          building_template_id: maps.buildingBySlug["taller-guerra"].id,
          status: "active",
          started_at: new Date().toISOString(),
          finishes_at: new Date().toISOString(),
          constructed_at: new Date().toISOString()
        })
        .select("*")
        .single()
    );
  }
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

  const sanctuary = await must(
    "santuario Custodes",
    service
      .from("system_buildings")
      .select("*")
      .eq("system_id", maps.systemBySlug["kharon-prime"].id)
      .eq("building_template_id", maps.buildingBySlug["santuario-reliquias"].id)
      .single()
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
      path_system_ids: ["red-sabbath", "voidmist-basin", "nexus-aster", "maelstrom-gas", "novem"].map(
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
      path_system_ids: ["drusus", "maelstrom-gas", "novem"].map(
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

  console.log(`\nRESULTADO: ${checks.length} checks OK`);
}

main().catch((error) => {
  console.error("\nFALLO EN TEST:", error.message);
  process.exitCode = 1;
});
