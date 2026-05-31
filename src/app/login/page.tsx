"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { clearSupabaseAuthStorage, getSupabaseBrowserClient } from "@/lib/supabase/client";

const localUsers = [
  "admin@rol40k.local",
  "orcos@rol40k.local",
  "necrones@rol40k.local",
  "guardia-imperial@rol40k.local",
  "culto-genestelar@rol40k.local",
  "sombra-emperador@rol40k.local",
  "guardia-muerte@rol40k.local"
];

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("guardia-imperial@rol40k.local");
  const [password, setPassword] = useState("rol40k-local-123");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    const supabase = getSupabaseBrowserClient();

    if (!supabase) {
      setError("Supabase no esta configurado. Ejecuta npm run db:sync-env con Supabase local arrancado.");
      return;
    }

    setIsSubmitting(true);
    clearSupabaseAuthStorage();
    const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
    setIsSubmitting(false);

    if (signInError) {
      setError(signInError.message);
      return;
    }

    router.push("/");
    router.refresh();
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <section className="hud-panel w-full max-w-md rounded-lg p-6">
        <div className="mb-6 flex items-center gap-3">
          <div className="grid size-10 place-items-center rounded-md border border-cyan-300/30 bg-cyan-300/10 text-cyan-200">
            <ShieldCheck size={20} />
          </div>
          <div>
            <h1 className="text-xl font-semibold">Acceso de campana</h1>
            <p className="text-sm text-slate-300">Login local con Supabase Auth.</p>
          </div>
        </div>

        <form className="space-y-3" onSubmit={handleSubmit}>
          <select
            className="w-full rounded-md border border-cyan-200/20 bg-slate-950/70 px-3 py-2 text-sm outline-none transition focus:border-cyan-200/50"
            onChange={(event) => {
              const nextEmail = event.target.value;
              setEmail(nextEmail);
              setPassword(nextEmail === "admin@rol40k.local" ? "admin-local-123" : "rol40k-local-123");
            }}
            value={email}
          >
            {localUsers.map((userEmail) => (
              <option key={userEmail} value={userEmail}>
                {userEmail}
              </option>
            ))}
          </select>
          <input
            className="w-full rounded-md border border-cyan-200/20 bg-slate-950/70 px-3 py-2 text-sm outline-none transition focus:border-cyan-200/50"
            onChange={(event) => setPassword(event.target.value)}
            placeholder="Contrasena"
            type="password"
            value={password}
          />
          <Button className="w-full" disabled={isSubmitting} type="submit">
            {isSubmitting ? "Entrando..." : "Entrar"}
          </Button>
          {error ? <p className="text-sm text-rose-200">{error}</p> : null}
        </form>
      </section>
    </main>
  );
}
