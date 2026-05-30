"use client";

import dynamic from "next/dynamic";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { AlertTriangle, Check, Clock3, Crosshair, MousePointer2, RadioTower, Route, Shield, Swords, Undo2, X } from "lucide-react";
import { getCampaignSnapshot } from "@/features/campaign/api/campaign-repository";
import { useCampaignUiStore } from "@/features/campaign/store/campaign-ui-store";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import { canUseMovementRpc, createMovementOrder } from "@/features/movement/api/movement-api";
import {
  calculateRoutePlan,
  canAppendManualStep,
  findCheapestRoute,
  formatTravelDuration,
  isSystemBlockedForMovement
} from "@/features/movement/lib/pathfinding";
import { RecruitmentModal } from "@/features/recruitment/components/recruitment-modal";
import { formatCountdown } from "@/lib/time";
import type { CampaignSnapshot, CampaignUnit, StarSystem } from "@/domain/campaign";

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
  const startMovementMode = useCampaignUiStore((state) => state.startMovementMode);
  const cancelMovementMode = useCampaignUiStore((state) => state.cancelMovementMode);
  const [recruitmentOpen, setRecruitmentOpen] = useState(false);
  const [movementOriginSystemId, setMovementOriginSystemId] = useState<string | null>(null);
  const [movementUnitIds, setMovementUnitIds] = useState<string[]>([]);
  const [movementRouteMode, setMovementRouteMode] = useState<"optimal" | "manual">("optimal");
  const [movementPathSystemIds, setMovementPathSystemIds] = useState<string[]>([]);
  const [movementHoverPathSystemIds, setMovementHoverPathSystemIds] = useState<string[]>([]);
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
  const movementOriginSystem = data.systems.find((system) => system.id === movementOriginSystemId) ?? null;
  const movementDisplayPath =
    movementHoverPathSystemIds.length > 1 ? movementHoverPathSystemIds : movementPathSystemIds;
  const movementRoutePlan =
    movementDisplayPath.length > 1 ? calculateRoutePlan(movementDisplayPath, data.edges) : null;

  const openMovement = (system: StarSystem) => {
    const readyUnitIds = data.units
      .filter(
        (unit) =>
          unit.factionId === data.currentUser.factionId &&
          unit.currentSystemId === system.id &&
          unit.status === "ready"
      )
      .map((unit) => unit.id);

    setMovementOriginSystemId(system.id);
    setMovementUnitIds(readyUnitIds);
    setMovementRouteMode("optimal");
    setMovementPathSystemIds([system.id]);
    setMovementHoverPathSystemIds([]);
    startMovementMode(system.id);
  };

  const closeMovement = () => {
    setMovementOriginSystemId(null);
    setMovementUnitIds([]);
    setMovementPathSystemIds([]);
    setMovementHoverPathSystemIds([]);
    cancelMovementMode();
  };

  const handleMovementHover = (systemId: string | null) => {
    if (!movementOriginSystemId || !systemId) {
      setMovementHoverPathSystemIds([]);
      return;
    }

    if (movementRouteMode === "optimal") {
      const route = findCheapestRoute({
        systems: data.systems,
        edges: data.edges,
        originSystemId: movementOriginSystemId,
        targetSystemId: systemId
      });
      setMovementHoverPathSystemIds(route?.pathSystemIds ?? []);
      return;
    }

    const basePath = movementPathSystemIds.length > 0 ? movementPathSystemIds : [movementOriginSystemId];

    if (canAppendManualStep(data.systems, data.edges, basePath, systemId) && !basePath.includes(systemId)) {
      setMovementHoverPathSystemIds([...basePath, systemId]);
      return;
    }

    setMovementHoverPathSystemIds([]);
  };

  const handleMovementClick = (systemId: string) => {
    if (!movementOriginSystemId) {
      return;
    }

    if (movementRouteMode === "optimal") {
      const route = findCheapestRoute({
        systems: data.systems,
        edges: data.edges,
        originSystemId: movementOriginSystemId,
        targetSystemId: systemId
      });

      if (route && route.pathSystemIds.length > 1) {
        setMovementPathSystemIds(route.pathSystemIds);
        setMovementHoverPathSystemIds([]);
      }

      return;
    }

    const basePath = movementPathSystemIds.length > 0 ? movementPathSystemIds : [movementOriginSystemId];
    const existingIndex = basePath.indexOf(systemId);

    if (existingIndex >= 0) {
      setMovementPathSystemIds(basePath.slice(0, existingIndex + 1));
      setMovementHoverPathSystemIds([]);
      return;
    }

    if (canAppendManualStep(data.systems, data.edges, basePath, systemId)) {
      setMovementPathSystemIds([...basePath, systemId]);
      setMovementHoverPathSystemIds([]);
    }
  };

  return (
    <main className="relative h-screen overflow-hidden">
      <GalaxyMap
        edges={data.edges}
        factions={data.factions}
        movements={data.movements}
        movementPlanning={
          movementOriginSystemId
            ? {
                active: true,
                originSystemId: movementOriginSystemId,
                pathSystemIds: movementDisplayPath,
                onSystemHover: handleMovementHover,
                onSystemClick: handleMovementClick
              }
            : undefined
        }
        systems={data.systems}
      />

      <div className="pointer-events-none absolute inset-0 flex flex-col">
        <div className="pointer-events-auto p-4">
          <ResourceBar snapshot={data} />
        </div>

        <div className="flex min-h-0 flex-1 items-stretch justify-between gap-4 px-4 pb-4">
          <CommandDock snapshot={data} />
          <SystemPanel
            onOpenMovement={openMovement}
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
      {movementOriginSystem ? (
        <MovementPlanner
          activePathSystemIds={movementDisplayPath}
          onChangeRouteMode={(mode) => {
            setMovementRouteMode(mode);
            setMovementPathSystemIds(movementOriginSystemId ? [movementOriginSystemId] : []);
            setMovementHoverPathSystemIds([]);
          }}
          onClose={closeMovement}
          onResetPath={() => {
            setMovementPathSystemIds(movementOriginSystemId ? [movementOriginSystemId] : []);
            setMovementHoverPathSystemIds([]);
          }}
          onToggleUnit={(unitId) =>
            setMovementUnitIds((current) =>
              current.includes(unitId) ? current.filter((id) => id !== unitId) : [...current, unitId]
            )
          }
          onUndoPath={() => {
            setMovementPathSystemIds((current) => (current.length > 1 ? current.slice(0, -1) : current));
            setMovementHoverPathSystemIds([]);
          }}
          originSystem={movementOriginSystem}
          routeMode={movementRouteMode}
          routePlan={movementRoutePlan}
          selectedUnitIds={movementUnitIds}
          snapshot={data}
        />
      ) : null}
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
  const ownUnits = snapshot.units.filter((unit) => unit.factionId === snapshot.currentUser.factionId);
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
        <h2 className="mb-3 text-sm font-semibold text-cyan-50">Unidades propias</h2>
        <div className="space-y-2">
          {ownUnits.slice(0, 6).map((unit) => (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={unit.id}>
              <div className="font-medium text-slate-100">{unit.name}</div>
              <div className="mt-1 text-xs text-slate-400">
                x{unit.quantity} · {unit.points * unit.quantity} pts · {unit.status}
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
  onOpenMovement,
  onOpenRecruitment
}: {
  snapshot: CampaignSnapshot;
  system: StarSystem;
  onOpenMovement: (system: StarSystem) => void;
  onOpenRecruitment: () => void;
}) {
  const faction = snapshot.factions.find((item) => item.id === system.controllerFactionId);
  const relatedUnits = snapshot.units.filter((unit) => unit.currentSystemId === system.id);
  const ownReadyUnits = relatedUnits.filter(
    (unit) => unit.factionId === snapshot.currentUser.factionId && unit.status === "ready"
  );
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
  const canMove =
    ownReadyUnits.length > 0 &&
    system.status !== "war" &&
    !isSystemBlockedForMovement(system) &&
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
              {relatedUnits.length > 0 ? (
                relatedUnits.map((unit) => (
                  <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={unit.id}>
                    <div className="flex items-center justify-between gap-3">
                      <div className="text-sm font-medium text-slate-100">{unit.name}</div>
                      <Badge tone={unit.status === "ready" ? "cyan" : unit.status === "moving" ? "amber" : "rose"}>
                        {unit.status}
                      </Badge>
                    </div>
                    <div className="mt-1 text-xs text-slate-400">
                      x{unit.quantity} · {unit.points * unit.quantity} pts
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
          <Button
            disabled={!canMove && system.status !== "war"}
            onClick={() => {
              if (canMove) {
                onOpenMovement(system);
              }
            }}
            variant={system.status === "war" ? "danger" : "ghost"}
          >
            {system.status === "war" ? "Reportar" : "Mover tropas"}
          </Button>
        </div>
      </div>
    </Panel>
  );
}

function MovementPlanner({
  activePathSystemIds,
  snapshot,
  originSystem,
  selectedUnitIds,
  routeMode,
  routePlan,
  onToggleUnit,
  onChangeRouteMode,
  onUndoPath,
  onResetPath,
  onClose
}: {
  activePathSystemIds: string[];
  snapshot: CampaignSnapshot;
  originSystem: StarSystem;
  selectedUnitIds: string[];
  routeMode: "optimal" | "manual";
  routePlan: NonNullable<ReturnType<typeof calculateRoutePlan>> | null;
  onToggleUnit: (unitId: string) => void;
  onChangeRouteMode: (mode: "optimal" | "manual") => void;
  onUndoPath: () => void;
  onResetPath: () => void;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const resources = snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
  const availableUnits = useMemo(
    () =>
      snapshot.units.filter(
        (unit) =>
          unit.factionId === snapshot.currentUser.factionId &&
          unit.currentSystemId === originSystem.id &&
          unit.status === "ready"
      ),
    [originSystem.id, snapshot.currentUser.factionId, snapshot.units]
  );
  const systemById = useMemo(() => new Map(snapshot.systems.map((system) => [system.id, system])), [snapshot.systems]);
  const rpcReady = canUseMovementRpc();
  const selectedUnits = availableUnits.filter((unit) => selectedUnitIds.includes(unit.id));
  const hasEnoughUridium = resources && routePlan ? resources.uridium >= routePlan.uridiumCost : false;
  const canConfirm =
    rpcReady &&
    selectedUnitIds.length > 0 &&
    Boolean(routePlan && routePlan.segmentCount > 0) &&
    Boolean(hasEnoughUridium);

  const mutation = useMutation({
    mutationFn: () => {
      if (!routePlan) {
        throw new Error("Selecciona una ruta valida.");
      }

      return createMovementOrder(selectedUnitIds, routePlan.pathSystemIds);
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });

  return (
    <Panel className="pointer-events-auto fixed inset-x-4 bottom-4 z-40 mx-auto grid max-h-[42vh] max-w-6xl grid-cols-1 overflow-hidden md:grid-cols-[1fr_340px]">
      <div className="min-h-0 overflow-y-auto p-4">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-xs uppercase tracking-[0.22em] text-cyan-200/70">Movimiento de unidades</div>
            <h2 className="mt-1 text-lg font-semibold text-cyan-50">{originSystem.name}</h2>
          </div>
          <div className="flex items-center gap-2">
            <Button
              onClick={() => onChangeRouteMode("optimal")}
              size="sm"
              variant={routeMode === "optimal" ? "primary" : "ghost"}
            >
              <MousePointer2 size={15} />
              Optima
            </Button>
            <Button
              onClick={() => onChangeRouteMode("manual")}
              size="sm"
              variant={routeMode === "manual" ? "primary" : "ghost"}
            >
              <Route size={15} />
              Manual
            </Button>
            <Button aria-label="Cerrar movimiento" onClick={onClose} size="icon" variant="ghost">
              <X size={17} />
            </Button>
          </div>
        </div>

        <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
          {availableUnits.map((unit) => (
            <UnitSelectionCard
              key={unit.id}
              onToggle={() => onToggleUnit(unit.id)}
              selected={selectedUnitIds.includes(unit.id)}
              unit={unit}
            />
          ))}
        </div>
      </div>

      <aside className="border-t border-cyan-200/15 bg-slate-950/35 p-4 md:border-l md:border-t-0">
        <div className="mb-4 flex items-center justify-between gap-3">
          <div className="text-sm font-semibold text-cyan-50">Ruta trazada</div>
          <div className="flex items-center gap-2">
            <Button disabled={activePathSystemIds.length <= 1} onClick={onUndoPath} size="icon" variant="ghost">
              <Undo2 size={16} />
            </Button>
            <Button onClick={onResetPath} size="sm" variant="ghost">
              Reiniciar
            </Button>
          </div>
        </div>

        <div className="mb-4 rounded-md border border-cyan-200/15 bg-slate-950/45 p-3 text-sm text-slate-200">
          {activePathSystemIds.length > 1
            ? activePathSystemIds.map((id) => systemById.get(id)?.name ?? id).join(" -> ")
            : "Sin destino fijado"}
        </div>

        <div className="mb-4 grid grid-cols-2 gap-2">
          <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3">
            <div className="mb-1 flex items-center gap-2 text-xs text-slate-400">
              <ResourceIcon className="size-4" resource="uridium" />
              Uridium
            </div>
            <div className={hasEnoughUridium ? "font-semibold text-cyan-50" : "font-semibold text-rose-100"}>
              {routePlan?.uridiumCost ?? 0} / {resources?.uridium ?? 0}
            </div>
          </div>
          <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3">
            <div className="mb-1 flex items-center gap-2 text-xs text-slate-400">
              <Clock3 size={15} />
              Tiempo
            </div>
            <div className="font-semibold text-cyan-50">{formatTravelDuration(routePlan?.durationSeconds ?? 0)}</div>
          </div>
        </div>

        <div className="mb-4 rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-xs text-slate-300">
          {selectedUnits.length > 0
            ? `${selectedUnits.length} unidades seleccionadas`
            : "Sin unidades seleccionadas"}
        </div>

        {!rpcReady ? (
          <div className="mb-3 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
            Supabase no esta configurado.
          </div>
        ) : null}

        {mutation.error ? <p className="mb-3 text-sm text-rose-200">{mutation.error.message}</p> : null}

        <Button className="w-full" disabled={!canConfirm || mutation.isPending} onClick={() => mutation.mutate()}>
          <Check size={16} />
          {mutation.isPending ? "Enviando..." : "Confirmar movimiento"}
        </Button>
      </aside>
    </Panel>
  );
}

function UnitSelectionCard({
  unit,
  selected,
  onToggle
}: {
  unit: CampaignUnit;
  selected: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      className={`rounded-md border p-3 text-left transition ${
        selected
          ? "border-cyan-200/55 bg-cyan-300/12 shadow-[0_0_20px_rgba(34,211,238,0.12)]"
          : "border-cyan-200/15 bg-slate-950/35 hover:border-cyan-200/35"
      }`}
      onClick={onToggle}
      type="button"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="font-medium text-slate-100">{unit.name}</div>
          <div className="mt-1 text-xs text-slate-400">
            x{unit.quantity} · {unit.points * unit.quantity} pts · {unit.category}
          </div>
        </div>
        <Badge tone={selected ? "cyan" : "slate"}>{selected ? "Lista" : "Libre"}</Badge>
      </div>
    </button>
  );
}
