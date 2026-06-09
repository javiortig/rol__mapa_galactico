"use client";

import dynamic from "next/dynamic";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, Building2, Check, Clock3, Cpu, Crosshair, Factory, HandCoins, Hammer, Landmark, Minus, MousePointer2, Plus, RadioTower, Route, Shield, Swords, Undo2, X } from "lucide-react";
import { getCampaignSnapshot, isCampaignAuthRequiredError } from "@/features/campaign/api/campaign-repository";
import { useCampaignUiStore } from "@/features/campaign/store/campaign-ui-store";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import { canUseMovementRpc, createMovementOrder, mergeCampaignUnits } from "@/features/movement/api/movement-api";
import { canUseBattleReportRpc, submitBattleReport } from "@/features/battle-reports/api/battle-report-api";
import {
  calculateRoutePlan,
  canAppendManualStep,
  findCheapestRoute,
  formatTravelDuration,
  isSystemBlockedForMovement
} from "@/features/movement/lib/pathfinding";
import { TechnologyTreeModal } from "@/features/technology/components/technology-tree-modal";
import { TradeModal } from "@/features/trade/components/trade-modal";
import { ConstructionModal } from "@/features/buildings/components/construction-modal";
import { BuildingActionModal } from "@/features/buildings/components/building-action-modal";
import { getActiveTechnologyResearch } from "@/features/technology/lib/technology-state";
import { formatCountdown } from "@/lib/time";
import { useMediaQuery, useViewportHeightCssVar } from "@/lib/use-media-query";
import type { BuildingTemplate, CampaignSnapshot, CampaignUnit, Conflict, StarSystem, SystemBuilding, UnitMovementSelection } from "@/domain/campaign";

const GalaxyMap = dynamic(
  () => import("@/features/galaxy-map/components/galaxy-map").then((mod) => mod.GalaxyMap),
  {
    ssr: false,
    loading: () => <div className="grid h-full place-items-center text-sm text-cyan-100">Inicializando mapa...</div>
  }
);

const mainResources = ["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium"] as const;
const planetProductionResources = ["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium"] as const;

export function CampaignShell() {
  const router = useRouter();
  const queryClient = useQueryClient();
  useViewportHeightCssVar();
  const selectedSystemId = useCampaignUiStore((state) => state.selectedSystemId);
  const hoveredSystemId = useCampaignUiStore((state) => state.hoveredSystemId);
  const tooltipPosition = useCampaignUiStore((state) => state.tooltipPosition);
  const setSelectedSystem = useCampaignUiStore((state) => state.setSelectedSystem);
  const startMovementMode = useCampaignUiStore((state) => state.startMovementMode);
  const cancelMovementMode = useCampaignUiStore((state) => state.cancelMovementMode);
  const isDesktop = useMediaQuery("(min-width: 1024px)");
  const isMobile = !isDesktop;
  const [tradeOpen, setTradeOpen] = useState(false);
  const [tradeLockedReason, setTradeLockedReason] = useState<string | null>(null);
  const [technologyOpen, setTechnologyOpen] = useState(false);
  const [constructionSystemId, setConstructionSystemId] = useState<string | null>(null);
  const [selectedBuildingId, setSelectedBuildingId] = useState<string | null>(null);
  const [battleReportSystemId, setBattleReportSystemId] = useState<string | null>(null);
  const [movementOriginSystemId, setMovementOriginSystemId] = useState<string | null>(null);
  const [movementUnitQuantities, setMovementUnitQuantities] = useState<Record<string, number>>({});
  const [movementRouteMode, setMovementRouteMode] = useState<"optimal" | "manual">("optimal");
  const [movementMobileStage, setMovementMobileStage] = useState<"select" | "route">("select");
  const [movementPathSystemIds, setMovementPathSystemIds] = useState<string[]>([]);
  const [movementHoverPathSystemIds, setMovementHoverPathSystemIds] = useState<string[]>([]);
  const { data, error } = useQuery({
    queryKey: ["campaign-snapshot"],
    queryFn: getCampaignSnapshot
  });
  const mergeMutation = useMutation({
    mutationFn: mergeCampaignUnits,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  useEffect(() => {
    if (isCampaignAuthRequiredError(error)) {
      router.replace("/login");
    }
  }, [error, router]);

  if (isCampaignAuthRequiredError(error)) {
    return <PrivateCampaignNotice title="Acceso privado" message="Redirigiendo al acceso de campana..." />;
  }

  if (error) {
    return <PrivateCampaignNotice title="Campana no disponible" message={error.message} />;
  }

  if (!data) {
    return <main className="grid min-h-screen place-items-center text-cyan-100">Cargando campaña...</main>;
  }

  const selectedSystem = data.systems.find(
    (system) => system.id === selectedSystemId
  );
  const panelSystem = selectedSystem ?? (!isMobile ? data.systems[0] : null);
  const showSystemPanel = Boolean(panelSystem) && !(isMobile && movementOriginSystemId && movementMobileStage === "route");
  const showCommandDock = !(
    isMobile &&
    (showSystemPanel || movementOriginSystemId || tradeOpen || technologyOpen || battleReportSystemId || constructionSystemId || selectedBuildingId)
  );
  const battleReportSystem = data.systems.find((system) => system.id === battleReportSystemId) ?? null;
  const battleReportConflict =
    battleReportSystem
      ? data.conflicts.find((conflict) => conflict.systemId === battleReportSystem.id && conflict.status === "pending") ?? null
      : null;
  const movementOriginSystem = data.systems.find((system) => system.id === movementOriginSystemId) ?? null;
  const movementDisplayPath =
    movementHoverPathSystemIds.length > 1 ? movementHoverPathSystemIds : movementPathSystemIds;
  const movementRoutePlan =
    movementDisplayPath.length > 1 ? calculateRoutePlan(movementDisplayPath, data.edges) : null;
  const constructionSystem = data.systems.find((system) => system.id === constructionSystemId) ?? null;
  const selectedBuilding = data.systemBuildings.find((building) => building.id === selectedBuildingId) ?? null;
  const selectedBuildingTemplate = selectedBuilding
    ? data.buildingTemplates.find((template) => template.id === selectedBuilding.buildingTemplateId) ?? null
    : null;
  const hasActiveCommerceBuilding = data.systemBuildings.some((building) => {
    const system = data.systems.find((item) => item.id === building.systemId);
    const template = data.buildingTemplates.find((item) => item.id === building.buildingTemplateId);
    return (
      building.status === "active" &&
      template?.slug === "camara-comercio" &&
      system?.controllerFactionId === data.currentUser.factionId &&
      system.status === "controlled"
    );
  });

  const openTradeFromDock = () => {
    setTradeLockedReason(hasActiveCommerceBuilding ? null : "Necesitas una Camara de Comercio activa para comerciar.");
    setTradeOpen(true);
  };

  const openTradeFromBuilding = () => {
    setTradeLockedReason(null);
    setTradeOpen(true);
  };

  const openMovement = (system: StarSystem) => {
    setMovementOriginSystemId(system.id);
    setMovementUnitQuantities({});
    setMovementRouteMode("optimal");
    setMovementMobileStage("select");
    setMovementPathSystemIds([system.id]);
    setMovementHoverPathSystemIds([]);
    if (!isMobile) {
      startMovementMode(system.id);
    }
  };

  const closeMovement = () => {
    setMovementOriginSystemId(null);
    setMovementUnitQuantities({});
    setMovementMobileStage("select");
    setMovementPathSystemIds([]);
    setMovementHoverPathSystemIds([]);
    cancelMovementMode();
  };

  const startMobileRoutePlanning = () => {
    if (!movementOriginSystemId) {
      return;
    }

    setMovementMobileStage("route");
    setMovementPathSystemIds([movementOriginSystemId]);
    setMovementHoverPathSystemIds([]);
    setSelectedSystem(null);
    startMovementMode(movementOriginSystemId);
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
    <main className="relative overflow-hidden" style={{ height: "var(--app-height)" }}>
      <GalaxyMap
        edges={data.edges}
        factions={data.factions}
        movements={data.movements}
        movementPlanning={
          movementOriginSystemId && (!isMobile || movementMobileStage === "route")
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
        <div className="pointer-events-auto px-3 pb-2 pt-[max(0.75rem,env(safe-area-inset-top))] md:p-4">
          <ResourceBar snapshot={data} />
        </div>

        <div className="flex min-h-0 flex-1 items-stretch justify-end gap-4 px-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] md:px-4 md:pb-4 lg:justify-between">
          {showCommandDock ? (
            <CommandDock
              onOpenTechnology={() => setTechnologyOpen(true)}
              onOpenTrade={openTradeFromDock}
              snapshot={data}
            />
          ) : null}
          {showSystemPanel && panelSystem ? (
            <SystemPanel
              mergeError={mergeMutation.error?.message}
              mergePending={mergeMutation.isPending}
              onClose={() => setSelectedSystem(null)}
              onMergeUnits={(unitIds) => mergeMutation.mutate(unitIds)}
              onOpenBattleReport={(system) => setBattleReportSystemId(system.id)}
              onOpenBuilding={(building, template) => {
                if (template.slug === "camara-comercio") {
                  openTradeFromBuilding();
                  return;
                }

                setSelectedBuildingId(building.id);
              }}
              onOpenConstruction={(system) => setConstructionSystemId(system.id)}
              onOpenMovement={openMovement}
              snapshot={data}
              system={panelSystem}
            />
          ) : null}
        </div>
      </div>

      <GalaxyTooltip
        snapshot={data}
        system={data.systems.find((system) => system.id === hoveredSystemId) ?? null}
        tooltipPosition={tooltipPosition}
      />

      <ConstructionModal
        onClose={() => setConstructionSystemId(null)}
        open={Boolean(constructionSystem)}
        snapshot={data}
        system={constructionSystem}
      />
      <BuildingActionModal
        building={selectedBuilding}
        onClose={() => setSelectedBuildingId(null)}
        open={Boolean(selectedBuilding && selectedBuildingTemplate)}
        snapshot={data}
        template={selectedBuildingTemplate}
      />
      <TradeModal lockedReason={tradeLockedReason} onClose={() => setTradeOpen(false)} open={tradeOpen} snapshot={data} />
      <TechnologyTreeModal onClose={() => setTechnologyOpen(false)} open={technologyOpen} snapshot={data} />
      {battleReportSystem && battleReportConflict ? (
        <BattleReportModal
          conflict={battleReportConflict}
          onClose={() => setBattleReportSystemId(null)}
          snapshot={data}
          system={battleReportSystem}
        />
      ) : null}
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
          onSetUnitQuantity={(unitId, quantity) =>
            setMovementUnitQuantities((current) => {
              if (quantity <= 0) {
                const next = { ...current };
                delete next[unitId];
                return next;
              }

              return { ...current, [unitId]: quantity };
            })
          }
          onUndoPath={() => {
            setMovementPathSystemIds((current) => (current.length > 1 ? current.slice(0, -1) : current));
            setMovementHoverPathSystemIds([]);
          }}
          originSystem={movementOriginSystem}
          isMobile={isMobile}
          mobileStage={movementMobileStage}
          onStartMobileRoutePlanning={startMobileRoutePlanning}
          routeMode={movementRouteMode}
          routePlan={movementRoutePlan}
          selectedQuantities={movementUnitQuantities}
          snapshot={data}
        />
      ) : null}
    </main>
  );
}

function PrivateCampaignNotice({ title, message }: { title: string; message: string }) {
  return (
    <main className="grid min-h-dvh place-items-center px-4 text-cyan-50">
      <Panel className="w-full max-w-md p-6 text-center">
        <div className="mx-auto mb-4 grid size-12 place-items-center rounded-md border border-cyan-300/30 bg-cyan-300/10 text-cyan-100">
          <Shield size={22} />
        </div>
        <h1 className="text-xl font-semibold">{title}</h1>
        <p className="mt-2 text-sm leading-6 text-slate-300">{message}</p>
      </Panel>
    </main>
  );
}

function ResourceBar({ snapshot }: { snapshot: CampaignSnapshot }) {
  const currentResources = snapshot.resources.find(
    (resources) => resources.factionId === snapshot.currentUser.factionId
  );

  return (
    <Panel className="mx-auto w-full max-w-[27rem] overflow-hidden px-1.5 py-1.5 sm:max-w-xl md:w-fit md:max-w-full md:px-4 md:py-3">
      <div className="grid grid-cols-6 gap-1 sm:gap-2">
        {mainResources.map((key) => (
          <div
            className="min-w-0 rounded-md border border-cyan-200/15 bg-slate-950/45 px-1.5 py-1.5 text-center md:min-w-24 md:px-3 md:py-2 md:text-left"
            key={key}
          >
            <div className="mb-0.5 flex items-center justify-center gap-1 text-[10px] text-slate-400 md:mb-1 md:justify-start md:gap-2 md:text-[11px]">
              <ResourceIcon className="size-4 shrink-0" resource={key} />
              <span className="hidden md:inline">{resourceLabels[key]}</span>
            </div>
            <div className="truncate text-[clamp(0.68rem,2.7vw,0.9rem)] font-semibold tabular-nums text-cyan-50 md:text-sm">
              {formatCompactNumber(currentResources?.[key] ?? 0)}
            </div>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function formatCompactNumber(value: number) {
  if (Math.abs(value) >= 1000000) {
    return `${(value / 1000000).toFixed(value >= 10000000 ? 0 : 1)}M`;
  }

  if (Math.abs(value) >= 1000) {
    return `${(value / 1000).toFixed(value >= 10000 ? 0 : 1)}k`;
  }

  return String(value);
}

function isBlockExpired(blockedUntil?: string | null) {
  return Boolean(blockedUntil && new Date(blockedUntil).getTime() <= Date.now());
}

function formatBlockCountdown(blockedUntil?: string | null) {
  if (!blockedUntil) {
    return "";
  }

  return isBlockExpired(blockedUntil) ? "Expirado" : formatCountdown(blockedUntil);
}

function BuildingKindIcon({ template }: { template: BuildingTemplate }) {
  const className = "size-4";
  const icon =
    template.buildingKind === "commerce" ? (
      <HandCoins className={className} />
    ) : template.buildingKind === "intelligence" ? (
      <RadioTower className={className} />
    ) : template.buildingKind === "production" ? (
      <Factory className={className} />
    ) : template.slug === "cuartel-mando" || template.iconKey === "command_quarters" ? (
      <Landmark className={className} />
    ) : (
      <Building2 className={className} />
    );

  return (
    <span className="grid size-9 place-items-center rounded-md border border-cyan-200/15 bg-slate-950/45 text-cyan-100">
      {icon}
    </span>
  );
}

function HiddenBuildingSlot({ building }: { building: SystemBuilding }) {
  return (
    <div className="rounded-md border border-slate-400/20 bg-slate-950/25 p-3 text-left">
      <div className="mb-2 flex items-start justify-between gap-2">
        <span className="grid size-9 place-items-center rounded-md border border-slate-400/20 bg-slate-900/45 text-slate-300">
          <Building2 className="size-4" />
        </span>
        <Badge tone={building.status === "constructing" ? "amber" : "slate"}>
          {building.status === "constructing" ? "Actividad" : "Ocupado"}
        </Badge>
      </div>
      <div className="text-sm font-semibold text-slate-200">Instalacion detectada</div>
      <div className="mt-1 text-xs text-slate-500">Detalles no revelados</div>
    </div>
  );
}

function CommandDock({
  snapshot,
  onOpenTrade,
  onOpenTechnology
}: {
  snapshot: CampaignSnapshot;
  onOpenTrade: () => void;
  onOpenTechnology: () => void;
}) {
  const ownUnits = snapshot.units.filter(
    (unit) => unit.factionId === snapshot.currentUser.factionId && unit.status !== "destroyed" && unit.quantity > 0
  );
  const activeMovements = snapshot.movements.filter((movement) => movement.status === "moving");
  const pendingConflicts = snapshot.conflicts.filter((conflict) => conflict.status === "pending");
  const activeBuildings = snapshot.systemBuildings.filter((building) => building.status === "constructing");
  const activeRecoveries = snapshot.unitRecoveryQueue.filter((item) => item.status === "queued");
  const activeTechnology = getActiveTechnologyResearch(snapshot);
  const activeTechnologyNode = activeTechnology
    ? snapshot.technologyNodes.find((node) => node.id === activeTechnology.technologyNodeId)
    : null;
  const activeChronosCount =
    activeMovements.length +
    snapshot.recruitmentQueue.length +
    activeBuildings.length +
    activeRecoveries.length +
    pendingConflicts.length +
    (activeTechnology ? 1 : 0);

  return (
    <>
    <div className="pointer-events-auto fixed inset-x-3 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] z-30 lg:hidden">
      <Panel className="p-2">
        <div className="grid grid-cols-4 gap-1.5">
          <Button className="h-12 flex-col gap-1 px-1 text-[11px]" onClick={onOpenTrade} size="sm" variant="ghost">
            <HandCoins size={16} />
            Comercio
          </Button>
          <Button className="h-12 flex-col gap-1 px-1 text-[11px]" size="sm" variant="ghost">
            <Shield size={16} />
            Tropas
          </Button>
          <Button className="h-12 flex-col gap-1 px-1 text-[11px]" onClick={onOpenTechnology} size="sm" variant="ghost">
            <Cpu size={16} />
            Tecno.
          </Button>
          <Button className="h-12 flex-col gap-1 px-1 text-[11px]" size="sm" variant="ghost">
            <Swords size={16} />
            {activeChronosCount > 0 ? `${activeChronosCount} avisos` : "Estado"}
          </Button>
        </div>
      </Panel>
    </div>

    <div className="pointer-events-auto hidden w-80 flex-col gap-3 self-end lg:flex">
      <Panel className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-cyan-50">Mando operativo</h2>
          <Badge tone="cyan">{snapshot.currentUser.role}</Badge>
        </div>

        <div className="grid grid-cols-2 gap-2">
          <Button onClick={onOpenTrade} size="sm" variant="ghost">
            <HandCoins size={15} />
            Comercio
          </Button>
          <Button size="sm" variant="ghost">
            <Shield size={15} />
            Tropas
          </Button>
          <Button onClick={onOpenTechnology} size="sm" variant="ghost">
            <Cpu size={15} />
            Tecnologia
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
          {activeBuildings.map((building) => {
            const template = snapshot.buildingTemplates.find((item) => item.id === building.buildingTemplateId);

            return (
              <div className="rounded-md border border-amber-300/20 bg-amber-400/8 p-3" key={building.id}>
                <div className="flex items-center justify-between gap-3">
                  <span className="text-amber-50">{template?.name ?? "Construccion"}</span>
                  <Badge tone="amber">{formatCountdown(building.finishesAt)}</Badge>
                </div>
              </div>
            );
          })}
          {activeRecoveries.map((item) => (
            <div className="rounded-md border border-rose-300/20 bg-rose-400/8 p-3" key={item.id}>
              <div className="flex items-center justify-between gap-3">
                <span className="text-rose-50">{item.unitName}</span>
                <Badge tone="rose">{formatCountdown(item.finishesAt)}</Badge>
              </div>
            </div>
          ))}
          {pendingConflicts.map((conflict) => (
            <div className="rounded-md border border-rose-300/20 bg-rose-400/8 p-3" key={conflict.id}>
              <div className="flex items-center justify-between gap-3">
                <span className="text-rose-50">Batalla pendiente</span>
                <Badge tone={isBlockExpired(conflict.blockedUntil) ? "slate" : "rose"}>
                  {formatBlockCountdown(conflict.blockedUntil)}
                </Badge>
              </div>
            </div>
          ))}
          {activeTechnology?.finishesAt ? (
            <div className="rounded-md border border-violet-300/20 bg-violet-400/8 p-3" key={activeTechnology.technologyNodeId}>
              <div className="flex items-center justify-between gap-3">
                <span className="text-violet-50">{activeTechnologyNode?.name ?? "Investigacion"}</span>
                <Badge tone="violet">{formatCountdown(activeTechnology.finishesAt)}</Badge>
              </div>
            </div>
          ) : null}
        </div>
      </Panel>

      <Panel className="p-4">
        <h2 className="mb-3 text-sm font-semibold text-cyan-50">Unidades propias</h2>
        <div className="space-y-2">
          {ownUnits.slice(0, 6).map((unit) => (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={unit.id}>
              <div className="font-medium text-slate-100">{unit.name}</div>
              <div className="mt-1 text-xs text-slate-400">{formatUnitStrength(unit)} · {getUnitStatusLabel(unit.status)}</div>
            </div>
          ))}
        </div>
      </Panel>
    </div>
    </>
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
    system.production.honor +
    system.production.gold +
    system.production.industrialMaterial +
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
            <span>{formatBlockCountdown(system.blockedUntil)}</span>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function SystemPanel({
  snapshot,
  system,
  mergeError,
  mergePending,
  onClose,
  onMergeUnits,
  onOpenBattleReport,
  onOpenBuilding,
  onOpenConstruction,
  onOpenMovement,
}: {
  snapshot: CampaignSnapshot;
  system: StarSystem;
  mergeError?: string;
  mergePending: boolean;
  onClose: () => void;
  onMergeUnits: (unitIds: string[]) => void;
  onOpenBattleReport: (system: StarSystem) => void;
  onOpenBuilding: (building: SystemBuilding, template: BuildingTemplate) => void;
  onOpenConstruction: (system: StarSystem) => void;
  onOpenMovement: (system: StarSystem) => void;
}) {
  const faction = snapshot.factions.find((item) => item.id === system.controllerFactionId);
  const relatedUnits = snapshot.units.filter(
    (unit) => unit.currentSystemId === system.id && unit.status !== "destroyed" && unit.quantity > 0
  );
  const ownReadyUnits = relatedUnits.filter(
    (unit) => unit.factionId === snapshot.currentUser.factionId && unit.status === "ready" && unit.quantity > 0
  );
  const conflict = snapshot.conflicts.find(
    (item) => item.systemId === system.id && item.status === "pending"
  );
  const tone = system.status === "war" ? "rose" : system.status === "controlled" ? "cyan" : "slate";
  const canInspectBuildings = snapshot.currentUser.role === "admin" || system.controllerFactionId === snapshot.currentUser.factionId;
  const systemBuildings = snapshot.systemBuildings.filter(
    (building) => building.systemId === system.id && building.status !== "disabled"
  );
  const buildingSlots = system.buildingSlots ?? (system.isCapital ? 6 : 3);
  const buildingSlotsUsed = systemBuildings.length;
  const canBuild =
    system.controllerFactionId === snapshot.currentUser.factionId &&
    system.status === "controlled" &&
    !isSystemBlockedForMovement(system) &&
    buildingSlotsUsed < buildingSlots &&
    (snapshot.currentUser.role === "admin" || snapshot.currentUser.role === "player");
  const canMove =
    ownReadyUnits.length > 0 &&
    system.status !== "war" &&
    !isSystemBlockedForMovement(system) &&
    (snapshot.currentUser.role === "admin" || snapshot.currentUser.role === "player");
  const canReport =
    Boolean(conflict) &&
    (snapshot.currentUser.role === "admin" ||
      conflict?.attackerFactionId === snapshot.currentUser.factionId ||
      conflict?.defenderFactionId === snapshot.currentUser.factionId);
  const mergeGroups = getMergeableUnitGroups(ownReadyUnits);
  const visibleUnits = relatedUnits.filter(
    (unit) =>
      snapshot.currentUser.role === "admin" ||
      unit.factionId === snapshot.currentUser.factionId ||
      unit.isVisiblePublicly
  );
  const blockExpired = isBlockExpired(system.blockedUntil);

  return (
    <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] top-[calc(4.85rem+env(safe-area-inset-top))] z-30 flex w-auto max-w-none overflow-hidden lg:static lg:z-auto lg:w-full lg:max-w-md lg:self-stretch">
      <div className="flex min-h-0 flex-1 flex-col">
        <div className="shrink-0 border-b border-cyan-200/15 p-4 md:p-5">
          <div className="mb-3 flex items-start justify-between gap-3">
            <div>
              <div className="mb-2 flex items-center gap-2">
                <Badge tone={tone}>{system.status}</Badge>
                {system.isCapital ? <Badge tone="amber">capital</Badge> : null}
              </div>
              <h1 className="text-xl font-semibold text-cyan-50 md:text-2xl">{system.name}</h1>
              <p className="mt-1 text-sm text-slate-300">{system.type}</p>
            </div>
            <div className="flex items-center gap-2">
              {system.status === "war" ? (
                <div className="grid size-11 place-items-center rounded-md border border-rose-300/30 bg-rose-400/12 text-rose-100">
                  <AlertTriangle size={20} />
                </div>
              ) : (
                <div className="grid size-11 place-items-center rounded-md border border-cyan-300/30 bg-cyan-400/10 text-cyan-100">
                  <Crosshair size={20} />
                </div>
              )}
              <Button aria-label="Cerrar sistema" className="lg:hidden" onClick={onClose} size="icon" variant="ghost">
                <X size={17} />
              </Button>
            </div>
          </div>
          <p className="hidden text-sm leading-6 text-slate-300 sm:block">{system.publicDescription}</p>
        </div>

        <div className="mobile-scroll flex-1 space-y-4 p-4 md:space-y-5 md:p-5">
          <section>
            <div className="mb-2 flex items-center justify-between gap-3">
              <h2 className="text-xs uppercase tracking-[0.18em] text-cyan-200/70">Edificios</h2>
              <Badge tone="cyan">{buildingSlotsUsed}/{buildingSlots} slots</Badge>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {systemBuildings.map((building) => {
                const template = snapshot.buildingTemplates.find((item) => item.id === building.buildingTemplateId);

                if (!template) {
                  return null;
                }

                if (!canInspectBuildings) {
                  return <HiddenBuildingSlot building={building} key={building.id} />;
                }

                return (
                  <button
                    className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-left transition hover:border-cyan-200/40"
                    key={building.id}
                    onClick={() => onOpenBuilding(building, template)}
                    type="button"
                  >
                    <div className="mb-2 flex items-start justify-between gap-2">
                      <BuildingKindIcon template={template} />
                      <Badge tone={building.status === "active" ? "cyan" : "amber"}>
                        {building.status === "active" ? "Activo" : "Construyendo"}
                      </Badge>
                    </div>
                    <div className="text-sm font-semibold text-cyan-50">{template.name}</div>
                    <div className="mt-1 text-xs text-slate-400">
                      {building.status === "constructing" && building.finishesAt
                        ? formatCountdown(building.finishesAt)
                        : template.category}
                    </div>
                  </button>
                );
              })}
              {Array.from({ length: Math.max(0, buildingSlots - buildingSlotsUsed) }).map((_, index) => (
                <button
                  className="rounded-md border border-dashed border-cyan-200/20 bg-slate-950/20 p-3 text-left text-sm text-slate-400 transition hover:border-cyan-200/40 hover:text-cyan-100 disabled:pointer-events-none disabled:opacity-50"
                  disabled={!canBuild}
                  key={`empty-${index}`}
                  onClick={() => onOpenConstruction(system)}
                  type="button"
                >
                  <div className="mb-2 grid size-9 place-items-center rounded-md border border-cyan-200/15 bg-slate-950/35">
                    <Hammer size={17} />
                  </div>
                  Slot libre
                </button>
              ))}
            </div>
            {!canBuild && buildingSlotsUsed < buildingSlots ? (
              <p className="mt-2 text-xs text-slate-500">Solo puedes construir en sistemas propios, controlados y sin bloqueo.</p>
            ) : null}
          </section>

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
              <div
                className={`rounded-md border p-3 text-sm ${
                  blockExpired
                    ? "border-slate-400/25 bg-slate-500/10 text-slate-200"
                    : "border-amber-300/25 bg-amber-300/10 text-amber-50"
                }`}
              >
                {blockExpired ? "Bloqueo expirado" : `Bloqueado durante ${formatCountdown(system.blockedUntil)}`}
              </div>
            </section>
          ) : null}

          <section>
            <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Producción diaria</h2>
            <div className="grid grid-cols-2 gap-2">
              {planetProductionResources.map((key) => (
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
              {visibleUnits.length > 0 ? (
                visibleUnits.map((unit) => (
                  <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={unit.id}>
                    <div className="flex items-center justify-between gap-3">
                      <div className="text-sm font-medium text-slate-100">{unit.name}</div>
                      <Badge tone={getUnitStatusTone(unit.status)}>{getUnitStatusLabel(unit.status)}</Badge>
                    </div>
                    <div className="mt-1 text-xs text-slate-400">{formatUnitStrength(unit)}</div>
                  </div>
                ))
              ) : (
                <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
                  {system.controllerFactionId === snapshot.currentUser.factionId
                    ? "Sin tropas propias visibles."
                    : "Sin tropas reveladas por la niebla de guerra."}
                </div>
              )}
            </div>
          </section>

          {mergeGroups.length > 0 ? (
            <section>
              <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Reorganizar unidades</h2>
              <div className="space-y-2">
                {mergeGroups.map((group) => (
                  <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={getUnitCompatibilityKey(group[0])}>
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm font-medium text-slate-100">{group[0].name}</div>
                        <div className="mt-1 text-xs text-slate-400">
                          {group.length} grupos compatibles · {group.reduce((total, unit) => total + unit.quantity, 0)} miniaturas
                        </div>
                      </div>
                      <Button
                        disabled={mergePending}
                        onClick={() => onMergeUnits(group.map((unit) => unit.id))}
                        size="sm"
                        variant="ghost"
                      >
                        Fusionar
                      </Button>
                    </div>
                  </div>
                ))}
                {mergeError ? <p className="text-xs text-rose-200">{mergeError}</p> : null}
              </div>
            </section>
          ) : null}

          {conflict ? (
            <section>
              <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-rose-200/70">Reporte pendiente</h2>
              <div className="rounded-md border border-rose-300/25 bg-rose-400/10 p-3 text-sm text-rose-50">
                Este sistema espera resultado de batalla física.
              </div>
            </section>
          ) : null}
        </div>

        <div className="grid shrink-0 grid-cols-3 gap-2 border-t border-cyan-200/15 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3 md:p-5">
          <Button className="min-w-0 text-xs sm:text-sm">Ver mision</Button>
          <Button className="min-w-0 text-xs sm:text-sm" disabled={!canBuild} onClick={() => onOpenConstruction(system)}>
            <Hammer size={16} />
            Construir
          </Button>
          <Button
            className="min-w-0 text-xs sm:text-sm"
            disabled={system.status === "war" ? !canReport : !canMove}
            onClick={() => {
              if (system.status === "war" && canReport) {
                onOpenBattleReport(system);
                return;
              }

              if (canMove) {
                onOpenMovement(system);
              }
            }}
            variant={system.status === "war" ? "danger" : "ghost"}
          >
            {system.status === "war" ? (
              "Reportar"
            ) : (
              <>
                <span className="sm:hidden">Mover</span>
                <span className="hidden sm:inline">Mover tropas</span>
              </>
            )}
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
  selectedQuantities,
  routeMode,
  routePlan,
  onSetUnitQuantity,
  onChangeRouteMode,
  onUndoPath,
  onResetPath,
  onStartMobileRoutePlanning,
  isMobile,
  mobileStage,
  onClose
}: {
  activePathSystemIds: string[];
  snapshot: CampaignSnapshot;
  originSystem: StarSystem;
  selectedQuantities: Record<string, number>;
  routeMode: "optimal" | "manual";
  routePlan: NonNullable<ReturnType<typeof calculateRoutePlan>> | null;
  onSetUnitQuantity: (unitId: string, quantity: number) => void;
  onChangeRouteMode: (mode: "optimal" | "manual") => void;
  onUndoPath: () => void;
  onResetPath: () => void;
  onStartMobileRoutePlanning: () => void;
  isMobile: boolean;
  mobileStage: "select" | "route";
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
          unit.status === "ready" &&
          unit.quantity > 0
      ),
    [originSystem.id, snapshot.currentUser.factionId, snapshot.units]
  );
  const systemById = useMemo(() => new Map(snapshot.systems.map((system) => [system.id, system])), [snapshot.systems]);
  const rpcReady = canUseMovementRpc();
  const selectedSelections = availableUnits.flatMap<UnitMovementSelection>((unit) => {
    const quantity = clampInteger(selectedQuantities[unit.id] ?? 0, 0, unit.quantity);
    return quantity > 0 ? [{ unitId: unit.id, quantity }] : [];
  });
  const selectedMiniatures = selectedSelections.reduce((total, selection) => total + selection.quantity, 0);
  const hasEnoughUridium = resources && routePlan ? resources.uridium >= routePlan.uridiumCost : false;
  const routeText =
    activePathSystemIds.length > 1
      ? activePathSystemIds.map((id) => systemById.get(id)?.name ?? id).join(" -> ")
      : "Sin destino fijado";
  const canConfirm =
    rpcReady &&
    selectedSelections.length > 0 &&
    Boolean(routePlan && routePlan.segmentCount > 0) &&
    Boolean(hasEnoughUridium);

  const mutation = useMutation({
    mutationFn: () => {
      if (!routePlan) {
        throw new Error("Selecciona una ruta valida.");
      }

      return createMovementOrder(selectedSelections, routePlan.pathSystemIds);
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });

  if (isMobile && mobileStage === "select") {
    return (
      <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] z-40 flex max-h-[calc(var(--app-height)-2rem)] flex-col overflow-hidden lg:hidden">
        <div className="shrink-0 border-b border-cyan-200/15 p-4">
          <div className="mb-3 flex items-start justify-between gap-3">
            <div>
              <div className="text-xs uppercase tracking-[0.22em] text-cyan-200/70">Movimiento de unidades</div>
              <h2 className="mt-1 text-lg font-semibold text-cyan-50">{originSystem.name}</h2>
            </div>
            <Button aria-label="Cerrar movimiento" onClick={onClose} size="icon" variant="ghost">
              <X size={17} />
            </Button>
          </div>

          <div className="grid grid-cols-2 gap-2">
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
          </div>
        </div>

        <div className="mobile-scroll flex-1 p-3">
          <div className="grid gap-2">
            {availableUnits.map((unit) => (
              <UnitSelectionCard
                key={unit.id}
                onSetQuantity={(quantity) => onSetUnitQuantity(unit.id, quantity)}
                selectedQuantity={clampInteger(selectedQuantities[unit.id] ?? 0, 0, unit.quantity)}
                unit={unit}
              />
            ))}
          </div>
        </div>

        <div className="shrink-0 border-t border-cyan-200/15 bg-slate-950/60 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3">
          <div className="mb-3 rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-xs text-slate-300">
            {selectedSelections.length > 0
              ? `${selectedSelections.length} unidades - ${selectedMiniatures} miniaturas seleccionadas`
              : "Selecciona una o varias unidades para trazar una ruta."}
          </div>
          <Button className="w-full" disabled={selectedSelections.length === 0} onClick={onStartMobileRoutePlanning}>
            <Route size={16} />
            Trazar ruta en el mapa
          </Button>
        </div>
      </Panel>
    );
  }

  if (isMobile && mobileStage === "route") {
    return (
      <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] z-40 overflow-hidden lg:hidden">
        <div className="border-b border-cyan-200/15 p-3">
          <div className="mb-2 flex items-center justify-between gap-3">
            <div className="min-w-0">
              <div className="text-[10px] uppercase tracking-[0.2em] text-cyan-200/70">Ruta de movimiento</div>
              <div className="mt-1 truncate text-sm font-semibold text-cyan-50">{routeText}</div>
            </div>
            <Button aria-label="Cancelar movimiento" onClick={onClose} size="icon" variant="ghost">
              <X size={17} />
            </Button>
          </div>

          <div className="grid grid-cols-3 gap-2 text-xs">
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-2">
              <div className="text-slate-400">Unidades</div>
              <div className="font-semibold text-cyan-50">{selectedMiniatures}</div>
            </div>
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-2">
              <div className="flex items-center gap-1 text-slate-400">
                <ResourceIcon className="size-3.5" resource="uridium" />
                Uridium
              </div>
              <div className={hasEnoughUridium ? "font-semibold text-cyan-50" : "font-semibold text-rose-100"}>
                {routePlan?.uridiumCost ?? 0}/{resources?.uridium ?? 0}
              </div>
            </div>
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-2">
              <div className="text-slate-400">Tiempo</div>
              <div className="font-semibold text-cyan-50">{formatTravelDuration(routePlan?.durationSeconds ?? 0)}</div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-4 gap-2 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3">
          <Button className="min-w-0 px-1 text-[11px]" disabled={activePathSystemIds.length <= 1} onClick={onUndoPath} size="sm" variant="ghost">
            <Undo2 size={15} />
            Deshacer
          </Button>
          <Button className="min-w-0 px-1 text-[11px]" onClick={onResetPath} size="sm" variant="ghost">
            Reiniciar
          </Button>
          <Button className="min-w-0 px-1 text-[11px]" onClick={onClose} size="sm" variant="ghost">
            Cancelar
          </Button>
          <Button className="min-w-0 px-1 text-[11px]" disabled={!canConfirm || mutation.isPending} onClick={() => mutation.mutate()} size="sm">
            <Check size={15} />
            {mutation.isPending ? "..." : "Mover"}
          </Button>
        </div>

        {!rpcReady ? (
          <div className="border-t border-amber-300/20 bg-amber-300/10 px-3 py-2 text-xs text-amber-100">
            Supabase no esta configurado.
          </div>
        ) : null}
        {mutation.error ? (
          <div className="border-t border-rose-300/20 bg-rose-400/10 px-3 py-2 text-xs text-rose-100">
            {mutation.error.message}
          </div>
        ) : null}
      </Panel>
    );
  }

  return (
    <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] z-40 mx-auto grid max-h-[calc(var(--app-height)-2rem)] max-w-6xl grid-cols-1 overflow-hidden md:inset-x-4 md:bottom-4 md:max-h-[58vh] md:grid-cols-[1fr_340px] lg:max-h-[42vh]">
      <div className="mobile-scroll p-4 md:min-h-0 md:overflow-y-auto">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-xs uppercase tracking-[0.22em] text-cyan-200/70">Movimiento de unidades</div>
            <h2 className="mt-1 text-lg font-semibold text-cyan-50">{originSystem.name}</h2>
          </div>
          <div className="flex flex-wrap items-center gap-2">
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
              onSetQuantity={(quantity) => onSetUnitQuantity(unit.id, quantity)}
              selectedQuantity={clampInteger(selectedQuantities[unit.id] ?? 0, 0, unit.quantity)}
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

        <div className="mb-4 rounded-md border border-cyan-200/15 bg-slate-950/45 p-3 text-sm text-slate-200 break-words">
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
          {selectedSelections.length > 0
            ? `${selectedSelections.length} unidades · ${selectedMiniatures} miniaturas seleccionadas`
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
  selectedQuantity,
  onSetQuantity
}: {
  unit: CampaignUnit;
  selectedQuantity: number;
  onSetQuantity: (quantity: number) => void;
}) {
  const selected = selectedQuantity > 0;

  return (
    <div
      className={`rounded-md border p-3 text-left transition ${
        selected
          ? "border-cyan-200/55 bg-cyan-300/12 shadow-[0_0_20px_rgba(34,211,238,0.12)]"
          : "border-cyan-200/15 bg-slate-950/35 hover:border-cyan-200/35"
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="font-medium text-slate-100">{unit.name}</div>
          <div className="mt-1 text-xs text-slate-400">
            {formatUnitStrength(unit)} · {unit.category}
          </div>
        </div>
        <Badge tone={selected ? "cyan" : "slate"}>{selected ? `${selectedQuantity}/${unit.quantity}` : "Libre"}</Badge>
      </div>

      <div className="mt-3 flex items-center justify-between rounded-md border border-cyan-200/10 bg-slate-950/40 p-2">
        <Button
          disabled={selectedQuantity <= 0}
          onClick={() => onSetQuantity(selectedQuantity - 1)}
          size="icon"
          variant="ghost"
        >
          <Minus size={15} />
        </Button>
        <div className="text-center">
          <div className="text-[11px] text-slate-400">Miniaturas a mover</div>
          <div className="text-base font-semibold text-cyan-50">{selectedQuantity}</div>
        </div>
        <Button
          disabled={selectedQuantity >= unit.quantity}
          onClick={() => onSetQuantity(selectedQuantity + 1)}
          size="icon"
          variant="ghost"
        >
          <Plus size={15} />
        </Button>
      </div>

      <div className="mt-2 grid grid-cols-2 gap-2">
        <Button disabled={selectedQuantity === 0} onClick={() => onSetQuantity(0)} size="sm" variant="ghost">
          Limpiar
        </Button>
        <Button disabled={selectedQuantity === unit.quantity} onClick={() => onSetQuantity(unit.quantity)} size="sm" variant="ghost">
          Todo
        </Button>
      </div>
    </div>
  );
}

function BattleReportModal({
  snapshot,
  system,
  conflict,
  onClose
}: {
  snapshot: CampaignSnapshot;
  system: StarSystem;
  conflict: Conflict;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const warUnits = useMemo(
    () =>
      snapshot.units.filter(
        (unit) => unit.currentSystemId === system.id && unit.status === "in_war" && unit.quantity > 0
      ),
    [snapshot.units, system.id]
  );
  const factionOptions = snapshot.factions.filter(
    (faction) => faction.id === conflict.attackerFactionId || faction.id === conflict.defenderFactionId
  );
  const defaultWinner =
    factionOptions.find((faction) => faction.id === snapshot.currentUser.factionId)?.id ??
    conflict.attackerFactionId;
  const [winnerFactionId, setWinnerFactionId] = useState<string | null>(defaultWinner);
  const [finalControllerFactionId, setFinalControllerFactionId] = useState<string | null>(defaultWinner);
  const [postBlockMinutes, setPostBlockMinutes] = useState(0);
  const [narrativeNotes, setNarrativeNotes] = useState("");
  const [survivors, setSurvivors] = useState<Record<string, number>>(() =>
    Object.fromEntries(warUnits.map((unit) => [unit.id, unit.quantity]))
  );
  const rpcReady = canUseBattleReportRpc();
  const mutation = useMutation({
    mutationFn: () =>
      submitBattleReport(conflict.id, {
        winnerFactionId,
        finalControllerFactionId,
        survivors,
        postBattleBlockedUntil:
          postBlockMinutes > 0 ? new Date(Date.now() + postBlockMinutes * 60_000).toISOString() : null,
        narrativeNotes: narrativeNotes.trim() || null
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });

  return (
    <div className="pointer-events-auto fixed inset-0 z-50 grid place-items-center bg-black/60 p-0 backdrop-blur-sm md:px-4 md:py-6">
      <Panel className="flex h-[var(--app-height)] w-full max-w-4xl flex-col overflow-hidden rounded-none md:h-auto md:max-h-[88vh] md:rounded-lg">
        <div className="shrink-0 flex items-center justify-between gap-4 border-b border-rose-200/15 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:p-5">
          <div>
            <div className="text-xs uppercase tracking-[0.24em] text-rose-200/70">Reporte de batalla</div>
            <h2 className="mt-1 text-2xl font-semibold text-cyan-50">{system.name}</h2>
          </div>
          <Button aria-label="Cerrar reporte" onClick={onClose} size="icon" variant="ghost">
            <X size={18} />
          </Button>
        </div>

        <div className="mobile-scroll flex-1 lg:grid lg:overflow-hidden lg:grid-cols-[1fr_300px]">
          <div className="p-4 md:p-5 lg:min-h-0 lg:overflow-y-auto">
            <div className="mb-4 grid gap-3 md:grid-cols-2">
              {factionOptions.map((faction) => (
                <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={faction.id}>
                  <div className="inline-flex items-center gap-2 text-sm font-medium text-slate-100">
                    <span className="size-2 rounded-full" style={{ backgroundColor: faction.color }} />
                    {faction.name}
                  </div>
                </div>
              ))}
            </div>

            <h3 className="mb-3 text-sm font-semibold text-cyan-50">Supervivientes por unidad</h3>
            <div className="space-y-2">
              {warUnits.map((unit) => {
                const value = clampInteger(survivors[unit.id] ?? unit.quantity, 0, unit.quantity);
                const faction = snapshot.factions.find((item) => item.id === unit.factionId);

                return (
                  <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={unit.id}>
                    <div className="mb-3 flex items-start justify-between gap-3">
                      <div>
                        <div className="font-medium text-slate-100">{unit.name}</div>
                        <div className="mt-1 text-xs text-slate-400">
                          {faction?.name ?? "Faccion"} · {unit.quantity}/{unit.startingQuantity} miniaturas actuales
                        </div>
                      </div>
                      <Badge tone={value === 0 ? "rose" : value < unit.quantity ? "amber" : "cyan"}>
                        {value} sobreviven
                      </Badge>
                    </div>

                    <div className="flex items-center justify-between rounded-md border border-cyan-200/10 bg-slate-950/40 p-2">
                      <Button
                        disabled={value <= 0 || mutation.isPending}
                        onClick={() => setSurvivors((current) => ({ ...current, [unit.id]: value - 1 }))}
                        size="icon"
                        variant="ghost"
                      >
                        <Minus size={15} />
                      </Button>
                      <div className="text-center">
                        <div className="text-[11px] text-slate-400">Bajas: {unit.quantity - value}</div>
                        <div className="text-base font-semibold text-cyan-50">{value}</div>
                      </div>
                      <Button
                        disabled={value >= unit.quantity || mutation.isPending}
                        onClick={() => setSurvivors((current) => ({ ...current, [unit.id]: value + 1 }))}
                        size="icon"
                        variant="ghost"
                      >
                        <Plus size={15} />
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <aside className="border-t border-cyan-200/15 bg-slate-950/35 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-4 md:p-5 lg:border-l lg:border-t-0">
            <div className="space-y-4">
              <label className="block text-sm">
                <span className="mb-2 block text-slate-300">Ganador</span>
                <select
                  className="w-full rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
                  onChange={(event) => setWinnerFactionId(event.target.value || null)}
                  value={winnerFactionId ?? ""}
                >
                  {factionOptions.map((faction) => (
                    <option key={faction.id} value={faction.id}>
                      {faction.name}
                    </option>
                  ))}
                </select>
              </label>

              <label className="block text-sm">
                <span className="mb-2 block text-slate-300">Control final</span>
                <select
                  className="w-full rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
                  onChange={(event) => setFinalControllerFactionId(event.target.value || null)}
                  value={finalControllerFactionId ?? ""}
                >
                  <option value="">Neutral</option>
                  {factionOptions.map((faction) => (
                    <option key={faction.id} value={faction.id}>
                      {faction.name}
                    </option>
                  ))}
                </select>
              </label>

              <label className="block text-sm">
                <span className="mb-2 block text-slate-300">Bloqueo posterior</span>
                <select
                  className="w-full rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
                  onChange={(event) => setPostBlockMinutes(Number(event.target.value))}
                  value={postBlockMinutes}
                >
                  <option value={0}>Sin bloqueo</option>
                  <option value={1440}>1 dia</option>
                  <option value={10080}>7 dias</option>
                  <option value={20160}>14 dias</option>
                </select>
              </label>

              <label className="block text-sm">
                <span className="mb-2 block text-slate-300">Notas narrativas</span>
                <textarea
                  className="min-h-24 w-full resize-none rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
                  onChange={(event) => setNarrativeNotes(event.target.value)}
                  value={narrativeNotes}
                />
              </label>

              {!rpcReady ? (
                <div className="rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
                  Supabase no esta configurado.
                </div>
              ) : null}

              {mutation.error ? <p className="text-sm text-rose-200">{mutation.error.message}</p> : null}

              <Button
                className="sticky bottom-0 w-full"
                disabled={!rpcReady || warUnits.length === 0 || mutation.isPending}
                onClick={() => mutation.mutate()}
                variant="danger"
              >
                <Check size={16} />
                {mutation.isPending ? "Enviando..." : "Enviar reporte"}
              </Button>
            </div>
          </aside>
        </div>
      </Panel>
    </div>
  );
}

function formatUnitStrength(unit: CampaignUnit) {
  return `${unit.quantity}/${unit.startingQuantity} miniaturas · ${getCurrentUnitPoints(unit)} pts`;
}

function getCurrentUnitPoints(unit: CampaignUnit) {
  if (unit.quantity <= 0) {
    return 0;
  }

  return Math.max(1, Math.ceil((unit.points * unit.quantity) / Math.max(unit.startingQuantity, 1)));
}

function getUnitStatusLabel(status: CampaignUnit["status"]) {
  const labels: Record<CampaignUnit["status"], string> = {
    ready: "Lista",
    moving: "En movimiento",
    in_war: "En guerra",
    destroyed: "Destruida",
    retreat_pending: "Retirada",
    recovering: "Curandose"
  };

  return labels[status];
}

function getUnitStatusTone(status: CampaignUnit["status"]): "cyan" | "rose" | "amber" | "slate" | "violet" {
  if (status === "ready") {
    return "cyan";
  }

  if (status === "moving") {
    return "amber";
  }

  if (status === "in_war") {
    return "rose";
  }

  if (status === "retreat_pending" || status === "recovering") {
    return "violet";
  }

  return "slate";
}

function getMergeableUnitGroups(units: CampaignUnit[]) {
  const groups = new Map<string, CampaignUnit[]>();

  for (const unit of units) {
    const key = getUnitCompatibilityKey(unit);
    groups.set(key, [...(groups.get(key) ?? []), unit]);
  }

  return [...groups.values()].filter((group) => group.length > 1);
}

function getUnitCompatibilityKey(unit: CampaignUnit) {
  return [
    unit.factionId,
    unit.currentSystemId,
    unit.unitTemplateId ?? unit.name,
    unit.category,
    unit.rank ?? "",
    unit.enhancementText ?? ""
  ].join("|");
}

function clampInteger(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, Math.trunc(Number.isFinite(value) ? value : min)));
}
