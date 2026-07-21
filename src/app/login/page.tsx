"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { clearSupabaseAuthStorage, getSupabaseBrowserClient, markCampaignSessionStarted } from "@/lib/supabase/client";

const campaignAccounts = [
  {
    label: "Administrador",
    email: "admin@rol40k.local",
    password: "admin-local-123"
  },
  {
    label: "Adeptus Custodes",
    email: "adeptus-custodes@rol40k.local",
    password: "rol40k-local-123"
  },
  {
    label: "Aeldari",
    email: "aeldari@rol40k.local",
    password: "rol40k-local-123"
  },
  {
    label: "Agentes del Imperium",
    email: "agentes-imperium@rol40k.local",
    password: "rol40k-local-123"
  },
  {
    label: "Cultos Genestealer",
    email: "cultos-genestealer@rol40k.local",
    password: "rol40k-local-123"
  },
  {
    label: "Legiones Daemonicas",
    email: "legiones-daemonicas@rol40k.local",
    password: "rol40k-local-123"
  },
  {
    label: "Necrones",
    email: "necrones@rol40k.local",
    password: "rol40k-local-123"
  },
  {
    label: "Space Marines",
    email: "space-marines@rol40k.local",
    password: "rol40k-local-123"
  }
];

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("adeptus-custodes@rol40k.local");
  const [password, setPassword] = useState("rol40k-local-123");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    const supabase = getSupabaseBrowserClient();

    if (!supabase) {
      setError("Supabase no esta configurado para esta campana.");
      return;
    }

    setIsSubmitting(true);
    clearSupabaseAuthStorage();
    const { data, error: signInError } = await supabase.auth.signInWithPassword({ email, password });
    setIsSubmitting(false);

    if (signInError) {
      setError(signInError.message);
      return;
    }

    markCampaignSessionStarted();

    let destination = "/";

    if (data.user?.id) {
      const { data: profileData } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", data.user.id)
        .maybeSingle();

      if (profileData?.role === "admin") {
        destination = "/admin";
      }
    }

    router.push(destination);
    router.refresh();
  }

  return (
    <main className="flex min-h-dvh items-center justify-center px-4">
      <section className="hud-panel w-full max-w-md rounded-lg p-6">
        <div className="mb-6 flex items-center gap-3">
          <div className="grid size-10 place-items-center rounded-md border border-cyan-300/30 bg-cyan-300/10 text-cyan-200">
            <ShieldCheck size={20} />
          </div>
          <div>
            <h1 className="text-xl font-semibold">Acceso de campana</h1>
            <p className="text-sm text-slate-300">Acceso privado con Supabase Auth.</p>
          </div>
        </div>

        <form className="space-y-3" onSubmit={handleSubmit}>
          <select
            className="w-full rounded-md border border-cyan-200/20 bg-slate-950/70 px-3 py-2 text-sm outline-none transition focus:border-cyan-200/50"
            onChange={(event) => {
              const nextEmail = event.target.value;
              const nextAccount = campaignAccounts.find((account) => account.email === nextEmail);

              setEmail(nextEmail);
              setPassword(nextAccount?.password ?? "rol40k-local-123");
            }}
            value={email}
          >
            {campaignAccounts.map((account) => (
              <option key={account.email} value={account.email}>
                {account.label} - {account.email}
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
