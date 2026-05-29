"use client";

import dynamic from "next/dynamic";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { AlertTriangle, Clock3, Crosshair, RadioTower, Shield, Swords } from "lucide-react";
import { getCampaignSnapshot } from "@/features/campaign/api/campaign-repository";
import { useCampaignUiStore } from "@/features/campaign/store/campaign-ui-store";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import { RecruitmentModal } from "@/features/recruitment/components/recruitment-modal";
import { formatCountdown } from "@/lib/time";
import type { CampaignSnapshot, StarSystem } from "@/domain/campaign";

const GalaxyMap = dynamic(
  () => import("@/features/galaxy-map/components/galaxy-map").then((mod) => mod.GalaxyMap),
  {
    ssr: false,
    loading: () => <div className="grid h-full place-items-center text-sm text-cyan-100">Inicializando mapa...</div>
  }
);

const mainResources = ["supply", "minerals", "ancestralStone", "uridium"] as const;

export function CampaignShell() {
  const selectedSystemId = useCampaignUiStore((state) => state.selectedSystemId);
  const hoveredSystemId = useCampaignUiStore((state) => state.hoveredSystemId);
  const tooltipPosition = useCampaignUiStore((state) => state.tooltipPosition);
  const [recruitmentOpen, setRecruitmentOpen] = useState(false);
  const { data } = useQuery({
    queryKey: ["campaign-snapshot"],
    queryFn: getCampaignSnapshot
  });

  if (!data) {
    return <main className="grid min-h-screen place-items-center text-cyan-100">Cargando campaña...</main>;
  }

  const selectedSystem = data.systems.find(
    (system) => system.id === selectedSystemId
  );

  return (
    <main className="relative h-screen overflow-hidden">
      <GalaxyMap
        edges={data.edges}
        factions={data.factions}
        movements={data.movements}
        systems={data.systems}
      />

      <div className="pointer-events-none absolute inset-0 flex flex-col">
        <div className="pointer-events-auto p-4">
          <ResourceBar snapshot={data} />
        </div>

        <div className="flex min-h-0 flex-1 items-stretch justify-between gap-4 px-4 pb-4">
          <CommandDock snapshot={data} />
          <SystemPanel
            onOpenRecruitment={() => setRecruitmentOpen(true)}
            snapshot={data}
            system={selectedSystem ?? data.systems[0]}
          />
        </div>
      </div>

      <GalaxyTooltip
        snapshot={data}
        system={data.systems.find((system) => system.id === hoveredSystemId) ?? null}
        tooltipPosition={tooltipPosition}
      />

      <RecruitmentModal onClose={() => setRecruitmentOpen(false)} open={recruitmentOpen} snapshot={data} />
    </main>
  );
}

function ResourceBar({ snapshot }: { snapshot: CampaignSnapshot }) {
  const currentResources = snapshot.resources.find(
    (resources) => resources.factionId === snapshot.currentUser.factionId
  );

  return (
    <Panel className="mx-auto flex w-fit max-w-full flex-wrap items-center justify-center gap-2 px-4 py-3">
      <div className="flex flex-wrap items-center gap-2">
        {mainResources.map((key) => (
          <div
            className="rounded-md border border-cyan-200/15 bg-slate-950/45 px-3 py-2"
            key={key}
          >
            <div className="mb-1 flex items-center gap-2 text-[11px] text-slate-400">
              <ResourceIcon className="size-4" resource={key} />
              {resourceLabels[key]}
            </div>
            <div className="text-sm font-semibold text-cyan-50">{currentResources?.[key] ?? 0}</div>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function CommandDock({ snapshot }: { snapshot: CampaignSnapshot }) {
  const ownArmies = snapshot.armies.filter((army) => army.factionId === snapshot.currentUser.factionId);
  const activeMovements = snapshot.movements.filter((movement) => movement.status === "moving");
  const pendingConflicts = snapshot.conflicts.filter((conflict) => conflict.status === "pending");

  return (
    <div className="pointer-events-auto hidden w-80 flex-col gap-3 self-end lg:flex">
      <Panel className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-cyan-50">Mando operativo</h2>
          <Badge tone="cyan">{snapshot.currentUser.role}</Badge>
        </div>

        <div className="grid grid-cols-2 gap-2">
          <Button size="sm" variant="ghost">
            <RadioTower size={15} />
            Recursos
          </Button>
          <Button size="sm" variant="ghost">
            <Shield size={15} />
            Tropas
          </Button>
          <Button size="sm" variant="ghost">
            <Clock3 size={15} />
            Reclutar
          </Button>
          <Button size="sm" variant="ghost">
            <Swords size={15} />
            Reportes
          </Button>
        </div>
      </Panel>

      <Panel className="p-4">
        <h2 className="mb-3 text-sm font-semibold text-cyan-50">Cronos activos</h2>
        <div className="space-y-3 text-sm">
          {activeMovements.map((movement) => (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={movement.id}>
              <div className="flex items-center justify-between gap-3">
                <span className="text-slate-200">Movimiento</span>
                <Badge tone="cyan">{formatCountdown(movement.arrivalAt)}</Badge>
              </div>
            </div>
          ))}
          {snapshot.recruitmentQueue.map((item) => (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={item.id}>
              <div className="flex items-center justify-between gap-3">
                <span className="text-slate-200">{item.unitName}</span>
                <Badge tone="violet">{formatCountdown(item.finishesAt)}</Badge>
              </div>
            </div>
          ))}
          {pendingConflicts.map((conflict) => (
            <div className="rounded-md border border-rose-300/20 bg-rose-400/8 p-3" key={conflict.id}>
              <div className="flex items-center justify-between gap-3">
                <span className="text-rose-50">Batalla pendiente</span>
                <Badge tone="rose">{formatCountdown(conflict.blockedUntil)}</Badge>
              </div>
            </div>
          ))}
        </div>
      </Panel>

      <Panel className="p-4">
        <h2 className="mb-3 text-sm font-semibold text-cyan-50">Ejércitos propios</h2>
        <div className="space-y-2">
          {ownArmies.map((army) => (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={army.id}>
              <div className="font-medium text-slate-100">{army.name}</div>
              <div className="mt-1 text-xs text-slate-400">
                {army.pointsTotal} pts · {army.status}
              </div>
            </div>
          ))}
        </div>
      </Panel>
    </div>
  );
}

function GalaxyTooltip({
  snapshot,
  system,
  tooltipPosition
}: {
  snapshot: CampaignSnapshot;
  system: StarSystem | null;
  tooltipPosition: { x: number; y: number } | null;
}) {
  if (!system || !tooltipPosition) {
    return null;
  }

  const faction = snapshot.factions.find((item) => item.id === system.controllerFactionId);
  const totalProduction =
    system.production.supply +
    system.production.minerals +
    system.production.ancestralStone +
    system.production.uridium;
  const stateText =
    system.status === "war" ? "En guerra" : system.status === "controlled" ? "Controlado" : "Neutral";

  return (
    <div
      className="pointer-events-none absolute z-30 w-64 rounded-lg border border-cyan-200/25 bg-slate-950/88 p-3 text-sm shadow-[0_0_28px_rgba(8,145,178,0.18)] backdrop-blur-md"
      style={{ left: tooltipPosition.x, top: tooltipPosition.y }}
    >
      <div className="mb-2 flex items-start justify-between gap-3">
        <div>
          <div className="font-semibold text-cyan-50">{system.name}</div>
          <div className="mt-0.5 text-xs text-slate-400">{system.type}</div>
        </div>
        <Badge tone={system.status === "war" ? "rose" : system.status === "controlled" ? "cyan" : "slate"}>
          {stateText}
        </Badge>
      </div>

      <div className="space-y-1.5 text-xs text-slate-300">
        <div className="flex items-center justify-between gap-3">
          <span>Control</span>
          <span className="inline-flex items-center gap-1.5 text-slate-100">
            {faction ? (
              <>
                <span className="size-2 rounded-full" style={{ backgroundColor: faction.color }} />
                {faction.name}
              </>
            ) : (
              "Nadie"
            )}
          </span>
        </div>
        <div className="flex items-center justify-between gap-3">
          <span>Producción diaria</span>
          <span className="text-cyan-100">+{totalProduction}/día</span>
        </div>
        {system.blockedUntil ? (
          <div className="flex items-center justify-between gap-3 text-amber-100">
            <span>Bloqueo</span>
            <span>{formatCountdown(system.blockedUntil)}</span>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function SystemPanel({
  snapshot,
  system,
  onOpenRecruitment
}: {
  snapshot: CampaignSnapshot;
  system: StarSystem;
  onOpenRecruitment: () => void;
}) {
  const faction = snapshot.factions.find((item) => item.id === system.controllerFactionId);
  const relatedArmies = snapshot.armies.filter((army) => army.currentSystemId === system.id);
  const conflict = snapshot.conflicts.find(
    (item) => item.systemId === system.id && item.status === "pending"
  );
  const tone = system.status === "war" ? "rose" : system.status === "controlled" ? "cyan" : "slate";
  const ownFaction = snapshot.factions.find((item) => item.id === snapshot.currentUser.factionId);
  const canRecruit =
    Boolean(ownFaction?.capitalSystemId === system.id) &&
    system.isCapital &&
    system.controllerFactionId === snapshot.currentUser.factionId &&
    (snapshot.currentUser.role === "admin" || snapshot.currentUser.role === "player");

  return (
    <Panel className="pointer-events-auto w-full max-w-md self-stretch overflow-hidden">
      <div className="flex h-full flex-col">
        <div className="border-b border-cyan-200/15 p-5">
          <div className="mb-3 flex items-start justify-between gap-3">
            <div>
              <div className="mb-2 flex items-center gap-2">
                <Badge tone={tone}>{system.status}</Badge>
                {system.isCapital ? <Badge tone="amber">capital</Badge> : null}
              </div>
              <h1 className="text-2xl font-semibold text-cyan-50">{system.name}</h1>
              <p className="mt-1 text-sm text-slate-300">{system.type}</p>
            </div>
            {system.status === "war" ? (
              <div className="grid size-11 place-items-center rounded-md border border-rose-300/30 bg-rose-400/12 text-rose-100">
                <AlertTriangle size={20} />
              </div>
            ) : (
              <div className="grid size-11 place-items-center rounded-md border border-cyan-300/30 bg-cyan-400/10 text-cyan-100">
                <Crosshair size={20} />
              </div>
            )}
          </div>
          <p className="text-sm leading-6 text-slate-300">{system.publicDescription}</p>
        </div>

        <div className="min-h-0 flex-1 space-y-5 overflow-y-auto p-5">
          <section>
            <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Control</h2>
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-200">
              {faction ? (
                <span className="inline-flex items-center gap-2">
                  <span className="size-2 rounded-full" style={{ backgroundColor: faction.color }} />
                  {faction.name}
                </span>
              ) : (
                "Neutral"
              )}
            </div>
          </section>

          {system.blockedUntil ? (
            <section>
              <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-amber-200/70">Bloqueo</h2>
              <div className="rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-50">
                Bloqueado durante {formatCountdown(system.blockedUntil)}
              </div>
            </section>
          ) : null}

          <section>
            <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Producción diaria</h2>
            <div className="grid grid-cols-2 gap-2">
              {mainResources.map((key) => (
                <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={key}>
                  <div className="mb-1 flex items-center gap-2 text-[11px] text-slate-400">
                    <ResourceIcon className="size-4" resource={key} />
                    {resourceLabels[key]}
                  </div>
                  <div className="font-semibold tabular-nums text-cyan-50">+{system.production[key]}</div>
                </div>
              ))}
            </div>
          </section>

          <section>
            <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Tropas visibles</h2>
            <div className="space-y-2">
              {relatedArmies.length > 0 ? (
                relatedArmies.map((army) => (
                  <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={army.id}>
                    <div className="text-sm font-medium text-slate-100">{army.name}</div>
                    <div className="mt-1 text-xs text-slate-400">
                      {army.pointsTotal} pts · {army.status}
                    </div>
                  </div>
                ))
              ) : (
                <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
                  Sin tropas propias visibles.
                </div>
              )}
            </div>
          </section>

          {conflict ? (
            <section>
              <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-rose-200/70">Reporte pendiente</h2>
              <div className="rounded-md border border-rose-300/25 bg-rose-400/10 p-3 text-sm text-rose-50">
                Este sistema espera resultado de batalla física.
              </div>
            </section>
          ) : null}
        </div>

        <div className={`grid gap-2 border-t border-cyan-200/15 p-5 ${canRecruit ? "grid-cols-3" : "grid-cols-2"}`}>
          <Button>Ver misión</Button>
          {canRecruit ? (
            <Button onClick={onOpenRecruitment}>
              <Clock3 size={16} />
              Reclutar
            </Button>
          ) : null}
          <Button variant={system.status === "war" ? "danger" : "ghost"}>
            {system.status === "war" ? "Reportar" : "Mover tropas"}
          </Button>
        </div>
      </div>
    </Panel>
  );
}
