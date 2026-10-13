import fs from "node:fs/promises";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";
import WebSocket from "ws";

const backupDir = process.argv[2];
if (!backupDir) throw new Error("Uso: node scripts/audit-space-marines-mfm-cloud.mjs <backup-dir>");

const root = process.cwd();
const envText = await fs.readFile(path.join(root, ".env.cloud.local"), "utf8");
const env = Object.fromEntries(
  envText.split(/\r?\n/).filter((line) => line && !line.startsWith("#"))
    .map((line) => {
      const separator = line.indexOf("=");
      return [line.slice(0, separator), line.slice(separator + 1)];
    })
);
if (!env.NEXT_PUBLIC_SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Faltan credenciales cloud");
}

const supabase = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
  realtime: { transport: WebSocket }
});
const backupTable = async (name) => JSON.parse(await fs.readFile(
  path.join(root, backupDir, "public_tables", `${name}.json`), "utf8"
));
const faction = (await backupTable("factions")).find((item) => item.slug === "space-marines");
if (!faction) throw new Error("Sombra del Emperador no figura en el backup");

async function currentTable(name) {
  const { data, error } = await supabase.from(name).select("*").eq("faction_id", faction.id);
  if (error) throw error;
  return data;
}

const [beforeUnits, beforeQueues, beforeTemplates, afterUnits, afterQueues, afterTemplates] = await Promise.all([
  backupTable("campaign_units"), backupTable("recruitment_queue"), backupTable("unit_templates"),
  currentTable("campaign_units"), currentTable("recruitment_queue"), currentTable("unit_templates")
]);
const { data: otherTemplates, error: otherTemplatesError } = await supabase
  .from("unit_templates").select("id, points, supply_cost, minerals_cost, honor_cost, gold_cost")
  .neq("faction_id", faction.id);
if (otherTemplatesError) throw otherTemplatesError;
const beforeOtherTemplates = new Map(beforeTemplates.filter((item) => item.faction_id !== faction.id)
  .map((item) => [item.id, item]));
for (const template of otherTemplates) {
  const previous = beforeOtherTemplates.get(template.id);
  if (!previous) throw new Error(`Plantilla ajena creada: ${template.id}`);
  for (const field of ["points", "supply_cost", "minerals_cost", "honor_cost", "gold_cost"]) {
    if (template[field] !== previous[field]) {
      throw new Error(`Plantilla ajena modificada: ${template.id}.${field}`);
    }
  }
}
const oldUnits = beforeUnits.filter((unit) => unit.faction_id === faction.id);
const oldQueues = beforeQueues.filter((queue) => queue.faction_id === faction.id);
const oldTemplates = beforeTemplates.filter((template) => template.faction_id === faction.id);
const byId = (rows) => new Map(rows.map((row) => [row.id, row]));
const newUnitById = byId(afterUnits);
const newQueueById = byId(afterQueues);
const oldTemplateById = byId(oldTemplates);
const mfm = JSON.parse(await fs.readFile(path.join(root, "data/11th-unit-cost-options.json"), "utf8"));
const refreshedUnits = mfm.units.filter((unit) =>
  unit.factionSlug === "space-marines" && unit.source?.fetchedAt === mfm.source.spaceMarinesRefreshedAt
);
const templateBySlug = new Map(afterTemplates.map((template) => [template.slug, template]));
if (refreshedUnits.length !== 64) throw new Error("El MFM refrescado no contiene 64 fichas");
for (const unit of refreshedUnits) {
  const template = templateBySlug.get(`unit-space-marines-${unit.unitSlug}`);
  if (!template || template.points !== unit.modelOptions[0]?.points) {
    throw new Error(`Precio base MFM incorrecto: ${unit.name}`);
  }
}
const { data: modelOptions, error: modelError } = await supabase
  .from("unit_template_model_options").select("unit_template_id, models, points, copy_from")
  .in("unit_template_id", refreshedUnits.map((unit) => templateBySlug.get(`unit-space-marines-${unit.unitSlug}`).id));
if (modelError) throw modelError;
for (const unit of refreshedUnits) {
  const template = templateBySlug.get(`unit-space-marines-${unit.unitSlug}`);
  for (const expected of unit.modelOptions) {
    if (!modelOptions.some((option) => option.unit_template_id === template.id
      && option.models === expected.models && option.copy_from === expected.copyRange.from
      && option.points === expected.points)) {
      throw new Error(`Opcion MFM incorrecta: ${unit.name}, ${expected.models} miniaturas`);
    }
  }
}

const changes = new Map();
for (const oldUnit of oldUnits) {
  const unit = newUnitById.get(oldUnit.id);
  if (!unit) throw new Error(`Desaparecio la unidad ${oldUnit.id}`);
  for (const field of ["status", "current_system_id", "quantity", "starting_quantity", "faction_id"]) {
    if (oldUnit[field] !== unit[field]) throw new Error(`Cambio inesperado en ${oldUnit.id}.${field}`);
  }
  if (oldUnit.status === "destroyed") continue;
  const key = `${oldUnit.name} (${oldUnit.starting_quantity})|${oldUnit.points}|${unit.points}`;
  const group = changes.get(key) ?? {
    unit: oldUnit.name, models: oldUnit.starting_quantity,
    count: 0, before: oldUnit.points, after: unit.points, difference: 0
  };
  group.count++;
  group.difference += unit.points - oldUnit.points;
  changes.set(key, group);
}

for (const queue of oldQueues) {
  const current = newQueueById.get(queue.id);
  if (!current) throw new Error(`Desaparecio la cola ${queue.id}`);
  if (current.status !== queue.status || current.quantity !== queue.quantity) {
    throw new Error(`Cambio inesperado en la cola ${queue.id}`);
  }
}

const oldArmy = oldUnits.filter((unit) => unit.status !== "destroyed").reduce((sum, unit) => sum + unit.points, 0);
const newArmy = afterUnits.filter((unit) => unit.status !== "destroyed").reduce((sum, unit) => sum + unit.points, 0);
const oldQueued = oldQueues.filter((queue) => queue.status === "queued")
  .reduce((sum, queue) => sum + (queue.selected_points ?? oldTemplateById.get(queue.unit_template_id)?.points ?? 0) * queue.quantity, 0);
const newTemplateById = byId(afterTemplates);
const newQueued = afterQueues.filter((queue) => queue.status === "queued")
  .reduce((sum, queue) => sum + (queue.selected_points ?? newTemplateById.get(queue.unit_template_id)?.points ?? 0) * queue.quantity, 0);

console.log(JSON.stringify({
  faction: faction.name,
  officialMfmSheetsVerified: refreshedUnits.length,
  officialModelOptionsVerified: refreshedUnits.reduce((sum, unit) => sum + unit.modelOptions.length, 0),
  otherFactionTemplatesUnchanged: otherTemplates.length,
  templateCount: { before: oldTemplates.length, after: afterTemplates.length },
  unitCount: { before: oldUnits.length, after: afterUnits.length },
  queuedRecruitmentCount: oldQueues.filter((queue) => queue.status === "queued").length,
  changes: [...changes.values()].sort((a, b) => a.unit.localeCompare(b.unit) || a.models - b.models),
  army: { before: oldArmy, after: newArmy, difference: newArmy - oldArmy },
  queued: { before: oldQueued, after: newQueued, difference: newQueued - oldQueued },
  total: { before: oldArmy + oldQueued, after: newArmy + newQueued,
    difference: newArmy + newQueued - oldArmy - oldQueued }
}, null, 2));
