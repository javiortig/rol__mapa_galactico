"use client";

import dynamic from "next/dynamic";
import { useEffect, useMemo } from "react";
import { Building2, Eye, Route, ShieldAlert, Swords, Users, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { CampaignSnapshot } from "@/domain/campaign";
import { useCampaignUiStore } from "@/features/campaign/store/campaign-ui-store";

const GalaxyMap = dynamic(
  () => import("@/features/galaxy-map/components/galaxy-map").then((module) => module.GalaxyMap),
  {
    ssr: false,
    loading: () => <div className="grid h-full place-items-center text-sm text-cyan-100">Inicializando mapa...</div>
  }
);

type AdminGalaxyMapModalProps = {
  snapshot: CampaignSnapshot;
  onClose: () => void;
};

export function AdminGalaxyMapModal({ snapshot, onClose }: AdminGalaxyMapModalProps) {
  const selectedSystemId = useCampaignUiStore((state) => state.selectedSystemId);
  const setSelectedSystem = useCampaignUiStore((state) => state.setSelectedSystem);
  const selectedSystem = snapshot.systems.find((system) => system.id === selectedSystemId) ?? null;
  const activeMovements = useMemo(
    () => snapshot.movements.filter((movement) => ["moving", "pending_approval"].includes(movement.status)),
    [snapshot.movements]
  );
  const unitsInSystem = useMemo(
    () =>
      selectedSystem
        ? snapshot.units
            .filter((unit) => unit.currentSystemId === selectedSystem.id && unit.status !== "destroyed")
            .sort((left, right) => left.name.localeCompare(right.name))
        : [],
    [selectedSystem, snapshot.units]
  );
  const buildingsInSystem = useMemo(
    () =>
      selectedSystem
        ? snapshot.systemBuildings.filter(
            (building) => building.systemId === selectedSystem.id && building.status !== "disabled"
          )
        : [],
    [selectedSystem, snapshot.systemBuildings]
  );
  const movementsThroughSystem = useMemo(
    () =>
      selectedSystem
        ? activeMovements.filter((movement) => movement.pathSystemIds.includes(selectedSystem.id))
        : [],
    [activeMovements, selectedSystem]
  );

  useEffect(() => {
    setSelectedSystem(null);

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      setSelectedSystem(null);
    };
  }, [onClose, setSelectedSystem]);

  if (snapshot.currentUser.role !== "admin") {
    return null;
  }

  const controller = selectedSystem
    ? snapshot.factions.find((faction) => faction.id === selectedSystem.controllerFactionId) ?? null
    : null;

  return (
    <div
      aria-label="Mapa estratégico de administración"
      aria-modal="true"
      className="fixed inset-0 z-[120] flex h-[100dvh] flex-col bg-[#02040a]"
      role="dialog"
    >
      <header className="relative z-20 flex min-h-16 items-center justify-between gap-3 border-b border-cyan-200/15 bg-slate-950/95 px-3 py-2 shadow-[0_12px_36px_rgba(0,0,0,0.35)] md:px-5">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <Eye className="shrink-0 text-cyan-200" size={18} />
            <h2 className="truncate text-base font-semibold text-cyan-50 md:text-lg">Mapa estratégico total</h2>
            <Badge tone="rose">admin</Badge>
          </div>
          <p className="mt-1 truncate text-xs text-slate-400">
            {snapshot.systems.length} sistemas · {activeMovements.length} movimientos activos · {snapshot.conflicts.filter((conflict) => conflict.status === "pending").length} conflictos
          </p>
        </div>
        <Button aria-label="Cerrar mapa" onClick={onClose} size="icon" title="Cerrar mapa" variant="ghost">
          <X size={19} />
        </Button>
      </header>

      <div className="relative min-h-0 flex-1 overflow-hidden">
        <GalaxyMap
          edges={snapshot.edges}
          factions={snapshot.factions}
          movements={snapshot.movements}
          systems={snapshot.systems}
        />

        <div className="pointer-events-none absolute left-3 top-3 z-10 hidden max-w-[calc(100%-1.5rem)] flex-wrap gap-1.5 md:flex">
          {snapshot.factions.map((faction) => (
            <span
              className="inline-flex items-center gap-1.5 rounded border border-white/10 bg-slate-950/80 px-2 py-1 text-[11px] text-slate-200 backdrop-blur-sm"
              key={faction.id}
            >
              <span className="size-2 rounded-full" style={{ backgroundColor: faction.color }} />
              {faction.name}
            </span>
          ))}
        </div>

        {selectedSystem ? (
          <aside className="mobile-scroll absolute inset-x-2 bottom-2 z-20 max-h-[48%] overflow-y-auto rounded-md border border-cyan-200/20 bg-slate-950/95 p-3 shadow-[0_18px_60px_rgba(0,0,0,0.65)] backdrop-blur-md md:inset-y-3 md:left-auto md:right-3 md:max-h-none md:w-[22rem] md:p-4">
            <div className="sticky top-0 z-10 -mx-1 -mt-1 flex items-start justify-between gap-3 bg-slate-950/95 px-1 pb-3 pt-1">
              <div className="min-w-0">
                <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-cyan-300/70">Sistema seleccionado</p>
                <h3 className="truncate text-lg font-semibold text-cyan-50">{selectedSystem.name}</h3>
                <p className="text-xs text-slate-400">
                  {controller?.name ?? "Neutral"} · {formatSystemStatus(selectedSystem.status)}
                </p>
              </div>
              <Button
                aria-label="Cerrar información del sistema"
                onClick={() => setSelectedSystem(null)}
                size="icon"
                title="Cerrar información"
                variant="ghost"
              >
                <X size={17} />
              </Button>
            </div>

            <div className="grid grid-cols-3 gap-2 border-y border-cyan-200/10 py-3">
              <AdminMapMetric icon={Users} label="Tropas" value={unitsInSystem.length} />
              <AdminMapMetric icon={Building2} label="Edificios" value={buildingsInSystem.length} />
              <AdminMapMetric icon={Route} label="Tránsitos" value={movementsThroughSystem.length} />
            </div>

            <section className="mt-4">
              <h4 className="mb-2 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.14em] text-cyan-100/80">
                <Users size={14} /> Tropas presentes
              </h4>
              <div className="divide-y divide-white/5">
                {unitsInSystem.length > 0 ? (
                  unitsInSystem.map((unit) => {
                    const faction = snapshot.factions.find((entry) => entry.id === unit.factionId);
                    return (
                      <div className="flex items-center justify-between gap-3 py-2 text-xs" key={unit.id}>
                        <div className="min-w-0">
                          <p className="truncate font-medium text-slate-100">{unit.name}</p>
                          <p className="truncate text-slate-500">{faction?.name ?? "Facción desconocida"}</p>
                        </div>
                        <span className="shrink-0 text-cyan-200">{unit.points} pts</span>
                      </div>
                    );
                  })
                ) : (
                  <p className="py-2 text-xs text-slate-500">Sin tropas presentes.</p>
                )}
              </div>
            </section>

            <section className="mt-4">
              <h4 className="mb-2 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.14em] text-cyan-100/80">
                <Building2 size={14} /> Instalaciones
              </h4>
              <div className="divide-y divide-white/5">
                {buildingsInSystem.length > 0 ? (
                  buildingsInSystem.map((building) => {
                    const template = snapshot.buildingTemplates.find((entry) => entry.id === building.buildingTemplateId);
                    return (
                      <div className="flex items-center justify-between gap-3 py-2 text-xs" key={building.id}>
                        <span className="truncate text-slate-100">{template?.name ?? "Instalación desconocida"}</span>
                        <Badge tone={building.status === "active" ? "cyan" : "amber"}>{formatBuildingStatus(building.status)}</Badge>
                      </div>
                    );
                  })
                ) : (
                  <p className="py-2 text-xs text-slate-500">Sin edificios construidos.</p>
                )}
              </div>
            </section>

            {movementsThroughSystem.length > 0 ? (
              <section className="mt-4">
                <h4 className="mb-2 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.14em] text-cyan-100/80">
                  <Swords size={14} /> Movimientos relacionados
                </h4>
                <div className="divide-y divide-white/5">
                  {movementsThroughSystem.map((movement) => {
                    const faction = snapshot.factions.find((entry) => entry.id === movement.factionId);
                    const origin = snapshot.systems.find((entry) => entry.id === movement.fromSystemId);
                    const destination = snapshot.systems.find((entry) => entry.id === movement.toSystemId);
                    return (
                      <div className="py-2 text-xs" key={movement.id}>
                        <div className="flex items-center justify-between gap-2">
                          <span className="font-medium text-slate-100">{faction?.name ?? "Facción desconocida"}</span>
                          <Badge tone={movement.movementType === "attack" ? "rose" : "slate"}>
                            {movement.movementType === "attack" ? "Ataque" : "Movimiento"}
                          </Badge>
                        </div>
                        <p className="mt-1 text-slate-500">{origin?.name ?? "?"} → {destination?.name ?? "?"}</p>
                      </div>
                    );
                  })}
                </div>
              </section>
            ) : null}

            {selectedSystem.status === "war" ? (
              <div className="mt-4 flex items-center gap-2 border-t border-rose-300/15 pt-3 text-xs text-rose-200">
                <ShieldAlert size={15} /> Conflicto activo en el sistema
              </div>
            ) : null}
          </aside>
        ) : null}
      </div>
    </div>
  );
}

function AdminMapMetric({
  icon: Icon,
  label,
  value
}: {
  icon: typeof Users;
  label: string;
  value: number;
}) {
  return (
    <div className="min-w-0 text-center">
      <Icon className="mx-auto text-cyan-300/70" size={14} />
      <p className="mt-1 text-sm font-semibold text-cyan-50">{value}</p>
      <p className="truncate text-[10px] uppercase tracking-[0.1em] text-slate-500">{label}</p>
    </div>
  );
}

function formatSystemStatus(status: string) {
  if (status === "war") return "En guerra";
  if (status === "controlled") return "Controlado";
  return "Neutral";
}

function formatBuildingStatus(status: string) {
  if (status === "active") return "Activo";
  if (status === "constructing") return "En construcción";
  return "Deshabilitado";
}
