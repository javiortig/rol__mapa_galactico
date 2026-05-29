import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";

function readSupabaseStatus() {
  return execSync("npx supabase status -o env", {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"]
  });
}

function parseEnv(output) {
  return Object.fromEntries(
    output
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && line.includes("="))
      .map((line) => {
        const index = line.indexOf("=");
        return [line.slice(0, index), stripQuotes(line.slice(index + 1))];
      })
  );
}

function stripQuotes(value) {
  return value.replace(/^"|"$/g, "");
}

const statusEnv = parseEnv(readSupabaseStatus());
const url = statusEnv.API_URL ?? statusEnv.SUPABASE_URL ?? "http://127.0.0.1:54321";
const anonKey = statusEnv.ANON_KEY ?? statusEnv.SUPABASE_ANON_KEY;
const serviceRoleKey = statusEnv.SERVICE_ROLE_KEY ?? statusEnv.SUPABASE_SERVICE_ROLE_KEY;

if (!anonKey || !serviceRoleKey) {
  throw new Error("No se pudieron leer ANON_KEY y SERVICE_ROLE_KEY desde `supabase status -o env`.");
}

writeFileSync(
  ".env.local",
  [
    `NEXT_PUBLIC_SUPABASE_URL=${url}`,
    `NEXT_PUBLIC_SUPABASE_ANON_KEY=${anonKey}`,
    `SUPABASE_SERVICE_ROLE_KEY=${serviceRoleKey}`,
    ""
  ].join("\n")
);

console.log(`.env.local actualizado para Supabase local en ${url}`);
