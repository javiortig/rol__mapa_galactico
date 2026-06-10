import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";
import WebSocket from "ws";

const users = [
  {
    email: "admin@rol40k.local",
    password: "admin-local-123",
    displayName: "Administrador de Campana",
    role: "admin",
    factionSlug: "guardia-imperial"
  },
  {
    email: "orcos@rol40k.local",
    password: "rol40k-local-123",
    displayName: "Kaudillo Orko",
    role: "player",
    factionSlug: "orcos"
  },
  {
    email: "necrones@rol40k.local",
    password: "rol40k-local-123",
    displayName: "Noble Necron",
    role: "player",
    factionSlug: "necrones"
  },
  {
    email: "guardia-imperial@rol40k.local",
    password: "rol40k-local-123",
    displayName: "Alto Mando Imperial",
    role: "player",
    factionSlug: "guardia-imperial"
  },
  {
    email: "culto-genestelar@rol40k.local",
    password: "rol40k-local-123",
    displayName: "Magus del Culto",
    role: "player",
    factionSlug: "culto-genestelar"
  },
  {
    email: "sombra-emperador@rol40k.local",
    password: "rol40k-local-123",
    displayName: "Capitan de la Sombra",
    role: "player",
    factionSlug: "sombra-emperador"
  },
  {
    email: "guardia-muerte@rol40k.local",
    password: "rol40k-local-123",
    displayName: "Campeon de la Plaga",
    role: "player",
    factionSlug: "guardia-muerte"
  }
];

function parseEnvText(text) {
  return Object.fromEntries(
    text
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith("#") && line.includes("="))
      .map((line) => {
        const index = line.indexOf("=");
        return [line.slice(0, index), stripQuotes(line.slice(index + 1))];
      })
  );
}

function stripQuotes(value) {
  return value.replace(/^"|"$/g, "");
}

function readLocalEnv() {
  if (!existsSync(".env.local")) {
    return {};
  }

  return parseEnvText(readFileSync(".env.local", "utf8"));
}

function readStatusEnv() {
  try {
    return parseEnvText(
      execSync("npx supabase status -o env", {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"]
      })
    );
  } catch {
    return {};
  }
}

const localEnv = readLocalEnv();
const statusEnv = readStatusEnv();
const supabaseUrl =
  process.env.SUPABASE_URL ??
  process.env.NEXT_PUBLIC_SUPABASE_URL ??
  localEnv.NEXT_PUBLIC_SUPABASE_URL ??
  statusEnv.API_URL ??
  statusEnv.SUPABASE_URL ??
  "http://127.0.0.1:54321";
const serviceRoleKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ??
  localEnv.SUPABASE_SERVICE_ROLE_KEY ??
  statusEnv.SERVICE_ROLE_KEY ??
  statusEnv.SUPABASE_SERVICE_ROLE_KEY;

if (!serviceRoleKey) {
  throw new Error("Falta SUPABASE_SERVICE_ROLE_KEY. Ejecuta primero `npm run db:sync-env` con Supabase local arrancado.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  },
  realtime: {
    transport: WebSocket
  }
});

async function upsertAuthUser(seedUser) {
  const { data: existingUsers, error: listError } = await supabase.auth.admin.listUsers({
    page: 1,
    perPage: 1000
  });

  if (listError) {
    throw listError;
  }

  const existing = existingUsers.users.find((user) => user.email === seedUser.email);

  if (existing) {
    const { data, error } = await supabase.auth.admin.updateUserById(existing.id, {
      email: seedUser.email,
      password: seedUser.password,
      email_confirm: true,
      user_metadata: { display_name: seedUser.displayName }
    });

    if (error) {
      throw error;
    }

    return data.user;
  }

  const { data, error } = await supabase.auth.admin.createUser({
    email: seedUser.email,
    password: seedUser.password,
    email_confirm: true,
    user_metadata: { display_name: seedUser.displayName }
  });

  if (error) {
    throw error;
  }

  return data.user;
}

async function getFactionId(slug) {
  const { data, error } = await supabase
    .from("factions")
    .select("id")
    .eq("slug", slug)
    .single();

  if (error) {
    throw error;
  }

  return data.id;
}

async function seedUsers() {
  const seeded = new Map();

  for (const seedUser of users) {
    const authUser = await upsertAuthUser(seedUser);
    const factionId = await getFactionId(seedUser.factionSlug);

    const { error: profileError } = await supabase.from("profiles").upsert({
      id: authUser.id,
      display_name: seedUser.displayName,
      role: seedUser.role
    });

    if (profileError) {
      throw profileError;
    }

    if (seedUser.role === "admin") {
      const { error: clearFactionError } = await supabase
        .from("player_factions")
        .delete()
        .eq("user_id", authUser.id);

      if (clearFactionError) {
        throw clearFactionError;
      }

      seeded.set(seedUser.email, { id: authUser.id, factionId: null });
      console.log(`Usuario de campana listo: ${seedUser.email} (sin faccion)`);
      continue;
    }

    const { error: factionError } = await supabase.from("player_factions").upsert(
      {
        user_id: authUser.id,
        faction_id: factionId
      },
      { onConflict: "user_id,faction_id" }
    );

    if (factionError) {
      throw factionError;
    }

    seeded.set(seedUser.email, { id: authUser.id, factionId });
    console.log(`Usuario de campana listo: ${seedUser.email}`);
  }

  await seedDemoBattleReport(seeded);
}

async function seedDemoBattleReport(seeded) {
  const admin = seeded.get("admin@rol40k.local");

  if (!admin) {
    return;
  }

  const { data: conflict, error: conflictError } = await supabase
    .from("conflicts")
    .select("id")
    .eq("slug", "conflict-1")
    .maybeSingle();

  if (conflictError) {
    throw conflictError;
  }

  if (!conflict) {
    return;
  }

  const { data: existing, error: existingError } = await supabase
    .from("battle_reports")
    .select("id")
    .eq("conflict_id", conflict.id)
    .eq("reporter_user_id", admin.id)
    .maybeSingle();

  if (existingError) {
    throw existingError;
  }

  if (existing) {
    return;
  }

  const { error } = await supabase.from("battle_reports").insert({
    conflict_id: conflict.id,
    reporter_user_id: admin.id,
    reporter_faction_id: admin.factionId,
    winner_faction_id: admin.factionId,
    final_controller_faction_id: admin.factionId,
    casualties: {},
    survivors: {},
    xp_awards: {},
    enhancements: {},
    narrative_notes: "Reporte provisional del atacante.",
    status: "submitted"
  });

  if (error) {
    throw error;
  }
}

await seedUsers();
console.log("Usuarios, perfiles y facciones de campana sembrados.");
