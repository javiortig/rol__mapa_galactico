"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { AdminConsole } from "@/features/admin/components/admin-console";
import { getCampaignSnapshot, isCampaignAuthRequiredError } from "@/features/campaign/api/campaign-repository";

export default function AdminPage() {
  const router = useRouter();
  const { data, error } = useQuery({
    queryKey: ["campaign-snapshot"],
    queryFn: getCampaignSnapshot
  });
  const errorMessage = error instanceof Error ? error.message : "Error desconocido";

  useEffect(() => {
    if (isCampaignAuthRequiredError(error)) {
      router.replace("/login");
      return;
    }

    if (data && data.currentUser.role !== "admin") {
      router.replace("/");
    }
  }, [data, error, router]);

  if (error) {
    return (
      <main className="grid min-h-screen place-items-center px-4 text-cyan-100">
        No se pudo cargar la consola admin: {errorMessage}
      </main>
    );
  }

  if (!data || data.currentUser.role !== "admin") {
    return <main className="grid min-h-screen place-items-center text-cyan-100">Cargando consola admin...</main>;
  }

  return <AdminConsole snapshot={data} />;
}
