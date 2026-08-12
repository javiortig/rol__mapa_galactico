"use client";

import dynamic from "next/dynamic";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AlertTriangle, Bell, Building2, Check, Clock3, Cpu, Crosshair, Factory, Gem, HandCoins, Hammer, Landmark, Megaphone, Minus, MousePointer2, Plus, RadioTower, Route, Shield, Swords, Undo2, X } from "lucide-react";
import { getCampaignSnapshot, isCampaignAuthRequiredError } from "@/features/campaign/api/campaign-repository";
import { useCampaignUiStore } from "@/features/campaign/store/campaign-ui-store";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import { canUseMovementRpc, createAttackOrder, createMovementOrder } from "@/features/movement/api/movement-api";
import { adminConfirmBattleReport, canUseBattleReportRpc, submitBattleReport, validateBattleReport } from "@/features/battle-reports/api/battle-report-api";
import { createCoalitionAttackDraft } from "@/features/battles/api/battle-operation-api";
import { BattleOperationsModal } from "@/features/battles/components/battle-operations-modal";
import {
  calculateRoutePlan,
  canAppendManualStep,
  findCheapestRoute,
  formatTravelDuration,
  getEdgeBetween,
  isSystemBlockedForMovement
} from "@/features/movement/lib/pathfinding";
import { TechnologyTreeModal } from "@/features/technology/components/technology-tree-modal";
import { TradeModal } from "@/features/trade/components/trade-modal";
import { ConstructionModal } from "@/features/buildings/components/construction-modal";
import { BuildingActionModal } from "@/features/buildings/components/building-action-modal";
import { retireCampaignUnit } from "@/features/units/api/unit-api";
import { formatUnitKeywords, getCharacterLevel, getCharacterRank, isCharacterUnit } from "@/features/units/lib/character-ranks";
import { formatCountdown } from "@/lib/time";
import { useMediaQuery, useViewportHeightCssVar } from "@/lib/use-media-query";
import type {
  BattleReport,
  BattleResolutionMode,
  BuildingTemplate,
  CampaignSnapshot,
  CampaignUnit,
  Conflict,
  Faction,
  NarrativeMissionEnemyUnit,
  StarSystem,
  SystemBuilding,
  UnitMovementSelection
} from "@/domain/campaign";

const GalaxyMap = dynamic(
  () => import("@/features/galaxy-map/components/galaxy-map").then((mod) => mod.GalaxyMap),
  {
    ssr: false,
    loading: () => <div className="grid h-full place-items-center text-sm text-cyan-100">Inicializando mapa...</div>
  }
);

const mainResources = ["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium"] as const;
const planetProductionResources = ["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium"] as const;
const defaultPostBattleBlockDays = 14;

export function CampaignShell() {
  const router = useRouter();
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
  const [eventsOpen, setEventsOpen] = useState(false);
  const [technologyOpen, setTechnologyOpen] = useState(false);
  const [battleOperationsOpen, setBattleOperationsOpen] = useState(false);
  const [constructionSystemId, setConstructionSystemId] = useState<string | null>(null);
  const [selectedBuildingId, setSelectedBuildingId] = useState<string | null>(null);
  const [battleReportSystemId, setBattleReportSystemId] = useState<string | null>(null);
  const [mobileTapShieldActive, setMobileTapShieldActive] = useState(false);
  const mobileTapShieldTimerRef = useRef<number | null>(null);
  const [movementOriginSystemId, setMovementOriginSystemId] = useState<string | null>(null);
  const [movementUnitQuantities, setMovementUnitQuantities] = useState<Record<string, number>>({});
  const [movementRouteMode, setMovementRouteMode] = useState<"optimal" | "manual">("optimal");
  const [movementMobileStage, setMovementMobileStage] = useState<"select" | "route">("select");
  const [movementPathSystemIds, setMovementPathSystemIds] = useState<string[]>([]);
  const [movementHoverPathSystemIds, setMovementHoverPathSystemIds] = useState<string[]>([]);
  const [attackOriginSystemId, setAttackOriginSystemId] = useState<string | null>(null);
  const [attackUnitQuantities, setAttackUnitQuantities] = useState<Record<string, number>>({});
  const [attackTargetSystemId, setAttackTargetSystemId] = useState<string | null>(null);
  const { data, error } = useQuery({
    queryKey: ["campaign-snapshot"],
    queryFn: getCampaignSnapshot
  });

  useEffect(() => {
    if (isCampaignAuthRequiredError(error)) {
      router.replace("/login");
    }
  }, [error, router]);

  useEffect(() => {
    if (data?.currentUser.role === "admin") {
      router.replace("/admin");
    }
  }, [data?.currentUser.role, router]);

  const armMobileTapShield = useCallback(() => {
    if (!isMobile) {
      return;
    }

    setMobileTapShieldActive(true);

    if (mobileTapShieldTimerRef.current !== null) {
      window.clearTimeout(mobileTapShieldTimerRef.current);
    }

    mobileTapShieldTimerRef.current = window.setTimeout(() => {
      setMobileTapShieldActive(false);
      mobileTapShieldTimerRef.current = null;
    }, 280);
  }, [isMobile]);

  useEffect(() => {
    return () => {
      if (mobileTapShieldTimerRef.current !== null) {
        window.clearTimeout(mobileTapShieldTimerRef.current);
      }
    };
  }, []);

  if (isCampaignAuthRequiredError(error)) {
    return <PrivateCampaignNotice title="Acceso privado" message="Redirigiendo al acceso de campaña..." />;
  }

  if (error) {
    return <PrivateCampaignNotice title="Campaña no disponible" message={error.message} />;
  }

  if (!data) {
    return <main className="grid min-h-screen place-items-center text-cyan-100">Cargando campaña...</main>;
  }

  if (data.currentUser.role === "admin") {
    return <main className="grid min-h-screen place-items-center text-cyan-100">Redirigiendo a consola de administración...</main>;
  }

  const selectedSystem = data.systems.find(
    (system) => system.id === selectedSystemId
  );
  const panelSystem = selectedSystem ?? (!isMobile ? data.systems[0] : null);
  const showSystemPanel = Boolean(panelSystem) && !(isMobile && movementOriginSystemId && movementMobileStage === "route");
  const showCommandDock = !(
    isMobile &&
    (showSystemPanel ||
      movementOriginSystemId ||
      attackOriginSystemId ||
      tradeOpen ||
      eventsOpen ||
      technologyOpen ||
      battleOperationsOpen ||
      battleReportSystemId ||
      constructionSystemId ||
      selectedBuildingId)
  );
  const battleReportSystem = data.systems.find((system) => system.id === battleReportSystemId) ?? null;
  const battleReportConflict =
    battleReportSystem
      ? data.conflicts.find((conflict) => conflict.systemId === battleReportSystem.id && conflict.status === "pending") ?? null
      : null;
  const movementOriginSystem = data.systems.find((system) => system.id === movementOriginSystemId) ?? null;
  const attackOriginSystem = data.systems.find((system) => system.id === attackOriginSystemId) ?? null;
  const movementDisplayPath =
    movementHoverPathSystemIds.length > 1 ? movementHoverPathSystemIds : movementPathSystemIds;
  const movementRoutePlan =
    movementDisplayPath.length > 1
      ? calculateRoutePlan(movementDisplayPath, data.edges, data.movementEdgeDurationSeconds)
      : null;
  const constructionSystem = data.systems.find((system) => system.id === constructionSystemId) ?? null;
  const selectedBuilding = data.systemBuildings.find((building) => building.id === selectedBuildingId) ?? null;
  const selectedBuildingTemplate = selectedBuilding
    ? data.buildingTemplates.find((template) => template.id === selectedBuilding.buildingTemplateId) ?? null
    : null;
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

  const openAttack = (system: StarSystem) => {
    setAttackOriginSystemId(system.id);
    setAttackUnitQuantities({});
    setAttackTargetSystemId(null);
  };

  const closeAttack = () => {
    setAttackOriginSystemId(null);
    setAttackUnitQuantities({});
    setAttackTargetSystemId(null);
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
        targetSystemId: systemId,
        currentFactionId: data.currentUser.factionId,
        edgeDurationSeconds: data.movementEdgeDurationSeconds
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
        targetSystemId: systemId,
        currentFactionId: data.currentUser.factionId,
        edgeDurationSeconds: data.movementEdgeDurationSeconds
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
        onSystemPointerTap={armMobileTapShield}
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

      {mobileTapShieldActive ? <div aria-hidden="true" className="pointer-events-auto absolute inset-0 z-[35] touch-none" /> : null}

      <div className="pointer-events-none absolute inset-0 flex flex-col">
        <div className="pointer-events-auto px-3 pb-2 pt-[max(0.75rem,env(safe-area-inset-top))] md:p-4">
          <ResourceBar snapshot={data} />
        </div>

        <div className="flex min-h-0 flex-1 items-stretch justify-end gap-4 px-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] md:px-4 md:pb-4 lg:justify-between">
          {showCommandDock ? (
            <CommandDock
              onOpenBattles={() => setBattleOperationsOpen(true)}
              onOpenEvents={() => setEventsOpen(true)}
              onOpenTechnology={() => setTechnologyOpen(true)}
              snapshot={data}
            />
          ) : null}
          {showSystemPanel && panelSystem ? (
            <SystemPanel
              onClose={() => setSelectedSystem(null)}
              onOpenBattleReport={(system) => setBattleReportSystemId(system.id)}
              onOpenBuilding={(building) => {
                setSelectedBuildingId(building.id);
              }}
              onOpenConstruction={(system) => setConstructionSystemId(system.id)}
              onOpenAttack={openAttack}
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
        onOpenTrade={() => {
          setSelectedBuildingId(null);
          openTradeFromBuilding();
        }}
        open={Boolean(selectedBuilding && selectedBuildingTemplate)}
        snapshot={data}
        template={selectedBuildingTemplate}
      />
      <TradeModal lockedReason={tradeLockedReason} onClose={() => setTradeOpen(false)} open={tradeOpen} snapshot={data} />
      <EventsModal onClose={() => setEventsOpen(false)} open={eventsOpen} snapshot={data} />
      <TechnologyTreeModal onClose={() => setTechnologyOpen(false)} open={technologyOpen} snapshot={data} />
      <BattleOperationsModal
        onClose={() => setBattleOperationsOpen(false)}
        open={battleOperationsOpen}
        snapshot={data}
      />
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
      {attackOriginSystem ? (
        <AttackPlanner
          onClose={closeAttack}
          onSetTargetSystem={setAttackTargetSystemId}
          onSetUnitQuantity={(unitId, quantity) =>
            setAttackUnitQuantities((current) => {
              if (quantity <= 0) {
                const next = { ...current };
                delete next[unitId];
                return next;
              }

              return { ...current, [unitId]: quantity };
            })
          }
          originSystem={attackOriginSystem}
          selectedQuantities={attackUnitQuantities}
          snapshot={data}
          targetSystemId={attackTargetSystemId}
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
            title={`${resourceLabels[key]}: ${currentResources?.[key] ?? 0}`}
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

  if (!Number.isInteger(value)) {
    return value.toLocaleString("es-ES", { maximumFractionDigits: 2 });
  }

  return value.toLocaleString("es-ES");
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

function hasUnresolvedBattleBlock(snapshot: CampaignSnapshot, systemId: string) {
  return (
    snapshot.conflicts.some((conflict) => conflict.systemId === systemId && conflict.status === "pending") ||
    snapshot.narrativeAttacks.some((attack) => attack.systemId === systemId && attack.status === "incoming") ||
    snapshot.battleOperations.some(
      (operation) =>
        operation.targetSystemId === systemId &&
        ["assembling", "moving", "in_battle"].includes(operation.status)
    ) ||
    snapshot.movements.some(
      (movement) =>
        movement.toSystemId === systemId &&
        movement.movementType === "attack" &&
        ["pending_approval", "moving"].includes(movement.status)
    )
  );
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
    ) : template.buildingKind === "relic" ? (
      <Gem className={className} />
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
  onOpenBattles,
  onOpenEvents,
  onOpenTechnology
}: {
  snapshot: CampaignSnapshot;
  onOpenBattles: () => void;
  onOpenEvents: () => void;
  onOpenTechnology: () => void;
}) {
  const currentFactionId = snapshot.currentUser.factionId;
  const pendingPassageRequests = currentFactionId
    ? snapshot.passageRequests.filter(
        (request) => request.responderFactionId === currentFactionId && request.status === "pending"
      )
    : [];
  const pendingBattles = currentFactionId
    ? snapshot.conflicts.filter(
        (conflict) =>
          conflict.status === "pending" &&
          (conflict.attackerFactionId === currentFactionId || conflict.defenderFactionId === currentFactionId)
      )
    : [];
  const pendingReports = snapshot.battleReports.filter((report) =>
    isBattleReportActionableForCurrentUser(snapshot, report, currentFactionId)
  );
  const pendingCount = pendingBattles.length + pendingPassageRequests.length + pendingReports.length;

  return (
    <>
    <div className="pointer-events-auto fixed inset-x-3 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] z-30 lg:hidden">
      <Panel className="p-2">
        <div className="grid grid-cols-4 gap-1.5">
          <Button className="h-12 flex-col gap-1 px-1 text-[11px]" onClick={onOpenEvents} size="sm" variant="ghost">
            <Megaphone size={16} />
            Eventos
          </Button>
          <Button className="h-12 flex-col gap-1 px-1 text-[11px]" size="sm" variant="ghost">
            <Shield size={16} />
            Tropas
          </Button>
          <Button className="h-12 flex-col gap-1 px-1 text-[11px]" onClick={onOpenTechnology} size="sm" variant="ghost">
            <Cpu size={16} />
            Tecno.
          </Button>
          <Button className="h-12 flex-col gap-1 px-1 text-[11px]" onClick={onOpenBattles} size="sm" variant="ghost">
            <Bell size={16} />
            {pendingCount > 0 ? `${pendingCount} avisos` : "Operaciones"}
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
          <Button onClick={onOpenEvents} size="sm" variant="ghost">
            <Megaphone size={15} />
            Eventos
          </Button>
          <Button size="sm" variant="ghost">
            <Shield size={15} />
            Tropas
          </Button>
          <Button onClick={onOpenTechnology} size="sm" variant="ghost">
            <Cpu size={15} />
            Tecnología
          </Button>
          <Button onClick={onOpenBattles} size="sm" variant="ghost">
            <Bell size={15} />
            {pendingCount > 0 ? `${pendingCount} avisos` : "Operaciones"}
          </Button>
        </div>
      </Panel>
    </div>
    </>
  );
}

function EventsModal({
  open,
  snapshot,
  onClose
}: {
  open: boolean;
  snapshot: CampaignSnapshot;
  onClose: () => void;
}) {
  if (!open) {
    return null;
  }

  const events = [...snapshot.campaignEvents].sort(
    (left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt)
  );

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/80 p-0 backdrop-blur-sm md:p-4">
      <Panel className="flex h-[var(--app-height)] w-full max-w-4xl flex-col overflow-hidden rounded-none md:h-auto md:max-h-[calc(var(--app-height)-2rem)] md:rounded-lg">
        <header className="flex shrink-0 items-center justify-between gap-3 border-b border-cyan-200/15 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:p-4">
          <div>
            <div className="text-xs uppercase tracking-[0.22em] text-cyan-200/70">Crónica galáctica</div>
            <h2 className="mt-1 text-lg font-semibold text-cyan-50">Eventos</h2>
          </div>
          <Button aria-label="Cerrar eventos" onClick={onClose} size="icon" variant="ghost">
            <X size={17} />
          </Button>
        </header>

        <div className="mobile-scroll min-h-0 flex-1 space-y-3 p-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
          {events.map((event) => {
            const system = event.systemId ? snapshot.systems.find((item) => item.id === event.systemId) : null;

            return (
              <article
                className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-4 shadow-[0_0_24px_rgba(8,145,178,0.08)]"
                key={event.id}
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h3 className="break-words font-semibold text-cyan-50">{event.title}</h3>
                      <Badge tone={event.eventType === "battle_result" ? "rose" : event.eventType === "manual" ? "cyan" : "amber"}>
                        {eventLabel(event.eventType)}
                      </Badge>
                    </div>
                    <p className="mt-1 text-xs text-slate-500">
                      {new Date(event.createdAt).toLocaleString()}
                      {system ? ` - ${system.name}` : ""}
                    </p>
                  </div>
                </div>
                <p className="mt-3 whitespace-pre-wrap text-sm leading-6 text-slate-200">{event.content}</p>
              </article>
            );
          })}

          {events.length === 0 ? (
            <div className="rounded-md border border-slate-400/20 bg-slate-900/35 p-5 text-sm text-slate-400">
              Aun no hay eventos registrados en la galaxia.
            </div>
          ) : null}
        </div>
      </Panel>
    </div>
  );
}

function eventLabel(type: CampaignSnapshot["campaignEvents"][number]["eventType"]) {
  const labels: Record<CampaignSnapshot["campaignEvents"][number]["eventType"], string> = {
    manual: "Comunicado",
    battle_result: "Batalla",
    system_unblocked: "Sistema",
    movement: "Movimiento",
    narrative: "Narrativa"
  };

  return labels[type] ?? "Evento";
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
  const naturalProduction = getNaturalSystemProduction(snapshot, system.id);
  const totalProduction = planetProductionResources.reduce((total, key) => total + naturalProduction[key], 0);
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
          <div className="mt-1 flex flex-wrap gap-1">
            {system.isTemporaryMission ? <Badge tone="amber">misión</Badge> : null}
            {system.systemKind === "gaseous" ? <Badge tone="cyan">gaseoso</Badge> : null}
            {!system.isConquerable ? <Badge tone="slate">no conquistable</Badge> : null}
          </div>
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
          <span>Capacidad base</span>
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

function getNaturalSystemProduction(snapshot: CampaignSnapshot, systemId: string) {
  return planetProductionResources.reduce(
    (production, key) => {
      production[key] =
        snapshot.systemResourceCapabilities.find(
          (capability) => capability.systemId === systemId && capability.resourceKey === key
        )?.productionAmount ?? 0;

      return production;
    },
    {
      supply: 0,
      minerals: 0,
      honor: 0,
      gold: 0,
      industrialMaterial: 0,
      uridium: 0
    } as Record<(typeof planetProductionResources)[number], number>
  );
}

function SystemPanel({
  snapshot,
  system,
  onClose,
  onOpenBattleReport,
  onOpenBuilding,
  onOpenConstruction,
  onOpenAttack,
  onOpenMovement,
}: {
  snapshot: CampaignSnapshot;
  system: StarSystem;
  onClose: () => void;
  onOpenBattleReport: (system: StarSystem) => void;
  onOpenBuilding: (building: SystemBuilding, template: BuildingTemplate) => void;
  onOpenConstruction: (system: StarSystem) => void;
  onOpenAttack: (system: StarSystem) => void;
  onOpenMovement: (system: StarSystem) => void;
}) {
  const queryClient = useQueryClient();
  const faction = snapshot.factions.find((item) => item.id === system.controllerFactionId);
  const relatedUnits = snapshot.units.filter(
    (unit) => unit.currentSystemId === system.id && unit.status !== "destroyed" && unit.quantity > 0
  );
  const hasOwnPresence = relatedUnits.some((unit) => unit.factionId === snapshot.currentUser.factionId);
  const ownReadyUnits = relatedUnits.filter(
    (unit) => unit.factionId === snapshot.currentUser.factionId && unit.status === "ready" && unit.quantity > 0
  );
  const conflict = snapshot.conflicts.find(
    (item) => item.systemId === system.id && item.status === "pending"
  );
  const incomingNarrativeAttack = snapshot.narrativeAttacks.find(
    (item) => item.systemId === system.id && item.status === "incoming"
  );
  const mission = system.isTemporaryMission
    ? snapshot.missions.find((item) => item.systemId === system.id) ?? null
    : null;
  const missionThreatFaction = system.missionThreatFactionId
    ? snapshot.factions.find((item) => item.id === system.missionThreatFactionId) ?? null
    : null;
  const conflictAttackerFaction = conflict
    ? snapshot.factions.find((item) => item.id === conflict.attackerFactionId) ?? null
    : null;
  const conflictDefenderFaction = conflict?.defenderFactionId
    ? snapshot.factions.find((item) => item.id === conflict.defenderFactionId) ?? null
    : null;
  const isNarrativeConflict = Boolean(conflictAttackerFaction?.isNarrative);
  const tone = system.status === "war" ? "rose" : system.status === "controlled" ? "cyan" : "slate";
  const isSharedSystem = !system.isConquerable || system.allowsSharedOccupation;
  const canUseBuildings = snapshot.currentUser.role === "admin" || system.controllerFactionId === snapshot.currentUser.factionId;
  const canInspectBuildings = canUseBuildings || hasOwnPresence;
  const systemBuildings = snapshot.systemBuildings.filter(
    (building) => building.systemId === system.id && building.status !== "disabled"
  );
  const buildingSlots = system.buildingSlots ?? (system.isCapital ? 6 : 3);
  const buildingSlotsUsed = systemBuildings.length;
  const hasActiveBattleBlock = system.status === "war" || hasUnresolvedBattleBlock(snapshot, system.id);
  const canBuild =
    system.controllerFactionId === snapshot.currentUser.factionId &&
    system.status === "controlled" &&
    system.systemKind !== "gaseous" &&
    !system.isTemporaryMission &&
    !hasActiveBattleBlock &&
    buildingSlotsUsed < buildingSlots &&
    (snapshot.currentUser.role === "admin" || snapshot.currentUser.role === "player");
  const canMove =
    ownReadyUnits.length > 0 &&
    system.status !== "war" &&
    !hasActiveBattleBlock &&
    (snapshot.currentUser.role === "admin" || snapshot.currentUser.role === "player");
  const hasAdjacentEnemySystem = snapshot.systems.some(
    (target) =>
      target.status === "controlled" &&
      target.controllerFactionId &&
      target.controllerFactionId !== snapshot.currentUser.factionId &&
      !target.isCapital &&
      !isSystemBlockedForMovement(target) &&
      Boolean(getEdgeBetween(snapshot.edges, system.id, target.id)) &&
      !getAttackOperationBlockReason(
        snapshot.battleOperations,
        system.id,
        target.id,
        snapshot.currentUser.factionId
      )
  );
  const canAttack = canMove && hasAdjacentEnemySystem;
  const conflictParticipantFactionIds = conflict
    ? getBattleReportRequiredFactionIds(conflict, relatedUnits, snapshot.battleUnitCommitments)
    : [];
  const canReport =
    Boolean(conflict) &&
    !isSharedSystem &&
    (snapshot.currentUser.role === "admin" ||
      Boolean(snapshot.currentUser.factionId && conflictParticipantFactionIds.includes(snapshot.currentUser.factionId)));
  const mergeGroups: CampaignUnit[][] = [];
  const mergePending = false;
  const mergeError: string | undefined = undefined;
  const onMergeUnits = (_unitIds: string[]) => {
    void _unitIds;
  };
  const visibleUnits = relatedUnits;
  const alliedUnits = visibleUnits.filter((unit) => unit.factionId === snapshot.currentUser.factionId);
  const enemyUnitsByFaction = snapshot.factions
    .map((enemyFaction) => ({
      faction: enemyFaction,
      units: visibleUnits.filter(
        (unit) => unit.factionId === enemyFaction.id && unit.factionId !== snapshot.currentUser.factionId
      )
    }))
    .filter((group) => group.units.length > 0);
  const canRevealMissionEnemies =
    Boolean(system.isTemporaryMission) &&
    (Boolean(system.missionEnemyUnitsVisible) || snapshot.currentUser.role === "admin");
  const missionEnemyUnits = canRevealMissionEnemies ? system.missionEnemyUnits ?? [] : [];
  const retireUnitMutation = useMutation({
    mutationFn: retireCampaignUnit,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const handleRetireUnit = (unit: CampaignUnit) => {
    if (!window.confirm(`Retirar ${unit.name}? Esta acción no devuelve recursos.`)) {
      return;
    }

    retireUnitMutation.mutate(unit.id);
  };
  const blockExpired = isBlockExpired(system.blockedUntil);
  const naturalProduction = getNaturalSystemProduction(snapshot, system.id);

  return (
    <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] top-[calc(4.85rem+env(safe-area-inset-top))] z-30 flex w-auto max-w-none overflow-hidden lg:static lg:z-auto lg:w-full lg:max-w-md lg:self-stretch">
      <div className="flex min-h-0 flex-1 flex-col">
        <div className="shrink-0 border-b border-cyan-200/15 p-4 md:p-5">
          <div className="mb-3 flex items-start justify-between gap-3">
            <div>
              <div className="mb-2 flex items-center gap-2">
                <Badge tone={tone}>{system.status}</Badge>
                {system.isCapital ? <Badge tone="amber">capital</Badge> : null}
                {system.isTemporaryMission ? <Badge tone="amber">misión temporal</Badge> : null}
                {system.systemKind === "gaseous" ? <Badge tone="cyan">gaseoso</Badge> : null}
                {!system.isConquerable ? <Badge tone="slate">no conquistable</Badge> : null}
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
          {system.isTemporaryMission ? (
            <section>
              <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-amber-200/70">Objetivo narrativo</h2>
              <div className="rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-50">
                <div className="mb-2 flex flex-wrap items-center gap-2">
                  <Badge tone="amber">Sistema temporal</Badge>
                  {missionThreatFaction ? <Badge tone="rose">{missionThreatFaction.name}</Badge> : null}
                </div>
                <h3 className="font-semibold text-cyan-50">{mission?.title ?? system.name}</h3>
                <p className="mt-2 leading-6 text-slate-200">
                  {mission?.narrativeDescription ?? system.publicDescription}
                </p>
                {mission ? (
                  <div className="mt-3 grid gap-2 text-xs text-slate-300">
                    <div>
                      <span className="font-semibold text-amber-100">Objetivo:</span> {mission.objectives}
                    </div>
                    <div>
                      <span className="font-semibold text-amber-100">Regla:</span> {mission.specialRules}
                    </div>
                    <div>
                      <span className="font-semibold text-amber-100">Victoria:</span> {mission.victoryConditions}
                    </div>
                    <div>
                      <span className="font-semibold text-amber-100">Duracion:</span>{" "}
                      {system.missionExpiresAt ? `expira en ${formatCountdown(system.missionExpiresAt)}` : "sin caducidad visible"}
                      {system.missionExpiresAfterBattle ? " o al resolver batalla." : "."}
                    </div>
                  </div>
                ) : null}
              </div>
            </section>
          ) : null}

          <section>
            <div className="mb-2 flex items-center justify-between gap-3">
              <h2 className="text-xs uppercase tracking-[0.18em] text-cyan-200/70">Edificios</h2>
              <Badge tone="cyan">{buildingSlotsUsed}/{buildingSlots} slots</Badge>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {systemBuildings.map((building) => {
                const template = snapshot.buildingTemplates.find((item) => item.id === building.buildingTemplateId);

                if (!canInspectBuildings || !building.detailsVisible || !template) {
                  return <HiddenBuildingSlot building={building} key={building.id} />;
                }

                const content = (
                  <>
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
                        : canUseBuildings
                          ? template.category
                          : "Detectado por presencia militar"}
                    </div>
                  </>
                );

                return canUseBuildings ? (
                  <button
                    className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-left transition hover:border-cyan-200/40"
                    key={building.id}
                    onClick={() => onOpenBuilding(building, template)}
                    type="button"
                  >
                    {content}
                  </button>
                ) : (
                  <div
                    className="rounded-md border border-cyan-200/15 bg-slate-950/30 p-3 text-left"
                    key={building.id}
                  >
                    {content}
                  </div>
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
              <p className="mt-2 text-xs text-slate-500">Solo puedes construir en sistemas propios, controlados y sin batalla activa.</p>
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
            {isSharedSystem ? (
              <p className="mt-2 text-xs text-slate-400">
                Sistema compartido: no admite conquista y las facciones pueden coexistir al llegar.
              </p>
            ) : null}
            {system.systemKind === "gaseous" ? (
              <p className="mt-2 text-xs text-slate-400">
                Sistema gaseoso: no admite construcciones y su capacidad de recursos es nula.
              </p>
            ) : null}
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
            <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Capacidad natural diaria</h2>
            <div className="grid grid-cols-2 gap-2">
              {planetProductionResources.map((key) => (
                <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={key}>
                  <div className="mb-1 flex items-center gap-2 text-[11px] text-slate-400">
                    <ResourceIcon className="size-4" resource={key} />
                    {resourceLabels[key]}
                  </div>
                  <div className="font-semibold tabular-nums text-cyan-50">+{naturalProduction[key]}</div>
                </div>
              ))}
            </div>
          </section>

          <section>
            <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Tropas visibles</h2>
            <div className="space-y-3">
              {visibleUnits.length > 0 || missionEnemyUnits.length > 0 || system.isTemporaryMission ? (
                <>
                  {visibleUnits.length > 0 ? (
                    <UnitGroup
                      canRetire
                      faction={snapshot.factions.find((item) => item.id === snapshot.currentUser.factionId) ?? null}
                      onRetireUnit={handleRetireUnit}
                      relics={snapshot.relics}
                      retirePendingUnitId={retireUnitMutation.isPending ? retireUnitMutation.variables : null}
                      title="Aliadas"
                      units={alliedUnits}
                    />
                  ) : null}
                  {enemyUnitsByFaction.length > 0 || missionEnemyUnits.length > 0 || system.isTemporaryMission ? (
                    <div className="space-y-2">
                      <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-rose-200/75">Enemigas</div>
                      {enemyUnitsByFaction.map((group) => (
                        <UnitGroup
                          canRetire={false}
                          faction={group.faction}
                          key={group.faction.id}
                          relics={snapshot.relics}
                          title={group.faction.name}
                          units={group.units}
                        />
                      ))}
                      {missionEnemyUnits.length > 0 ? (
                        <MissionEnemyUnitGroup
                          faction={missionThreatFaction ?? faction ?? null}
                          title={missionThreatFaction?.name ?? "Amenaza narrativa"}
                          units={missionEnemyUnits}
                        />
                      ) : system.isTemporaryMission ? (
                        <div className="rounded-md border border-rose-300/15 bg-rose-400/8 p-3 text-sm text-rose-100/80">
                          Presencia enemiga detectada. Composicion no revelada.
                        </div>
                      ) : null}
                    </div>
                  ) : null}
                </>
              ) : (
                <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
                  {system.controllerFactionId === snapshot.currentUser.factionId
                    ? "Sin tropas propias visibles."
                    : "Sin tropas reveladas por la niebla de guerra."}
                </div>
              )}
              {retireUnitMutation.error ? <p className="text-xs text-rose-200">{retireUnitMutation.error.message}</p> : null}
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
                          {group.length} grupos compatibles - {group.reduce((total, unit) => total + unit.quantity, 0)} miniaturas
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

          {incomingNarrativeAttack ? (
            <section>
              <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-amber-200/70">Amenaza entrante</h2>
              <div className="rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-50">
                <div className="mb-2 flex flex-wrap items-center gap-2">
                  <Badge tone="amber">Llega en {formatCountdown(incomingNarrativeAttack.arrivalAt)}</Badge>
                  {snapshot.factions.find((item) => item.id === incomingNarrativeAttack.narrativeFactionId) ? (
                    <Badge tone="rose">
                      {snapshot.factions.find((item) => item.id === incomingNarrativeAttack.narrativeFactionId)?.name}
                    </Badge>
                  ) : null}
                </div>
                <p>{incomingNarrativeAttack.description}</p>
              </div>
            </section>
          ) : null}

          {conflict ? (
            <section>
              <h2 className="mb-2 text-xs uppercase tracking-[0.18em] text-rose-200/70">
                {isNarrativeConflict ? "Amenaza narrativa" : "Reporte pendiente"}
              </h2>
              <div className="rounded-md border border-rose-300/25 bg-rose-400/10 p-3 text-sm text-rose-50">
                <div className="mb-2 flex flex-wrap items-center gap-2">
                  {conflictAttackerFaction ? <Badge tone="rose">{conflictAttackerFaction.name}</Badge> : null}
                  {conflictDefenderFaction ? <Badge tone="slate">vs {conflictDefenderFaction.name}</Badge> : null}
                  {isNarrativeConflict ? <Badge tone="amber">evento admin</Badge> : null}
                </div>
                <p>
                  {isNarrativeConflict
                    ? conflict.notes || "Una amenaza narrativa controlada por el admin acecha el sistema."
                    : "Este sistema espera resultado de batalla fisica."}
                </p>
              </div>
            </section>
          ) : null}
        </div>

        <div className="grid shrink-0 grid-cols-2 gap-2 border-t border-cyan-200/15 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3 sm:grid-cols-4 md:p-5">
          <Button className="min-w-0 px-2 text-xs sm:text-sm">Ver misión</Button>
          {system.systemKind === "gaseous" ? (
            <Button className="min-w-0 px-2 text-xs sm:text-sm" disabled variant="ghost">
              No edificable
            </Button>
          ) : (
            <Button
              className="min-w-0 px-2 text-xs sm:text-sm"
              disabled={!canBuild}
              onClick={() => onOpenConstruction(system)}
            >
              <Hammer size={16} />
              Construir
            </Button>
          )}
          <Button
            className="min-w-0 px-2 text-xs sm:text-sm"
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
          <Button
            className="min-w-0 px-2 text-xs sm:text-sm"
            disabled={!canAttack}
            onClick={() => {
              if (canAttack) {
                onOpenAttack(system);
              }
            }}
            variant="danger"
          >
            <Swords size={16} />
            Atacar
          </Button>
        </div>
      </div>
    </Panel>
  );
}

function UnitGroup({
  title,
  faction,
  units,
  relics,
  canRetire,
  retirePendingUnitId,
  onRetireUnit
}: {
  title: string;
  faction: Faction | null;
  units: CampaignUnit[];
  relics: CampaignSnapshot["relics"];
  canRetire: boolean;
  retirePendingUnitId?: string | null;
  onRetireUnit?: (unit: CampaignUnit) => void;
}) {
  return (
    <div className="rounded-md border border-cyan-200/12 bg-slate-950/22 p-2.5">
      <div className="mb-2 flex items-center justify-between gap-2">
        <div className="inline-flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-cyan-200/75">
          {faction ? <span className="size-2 rounded-full" style={{ backgroundColor: faction.color }} /> : null}
          {title}
        </div>
        <Badge tone={units.length > 0 ? "cyan" : "slate"}>{units.length}</Badge>
      </div>
      <div className="space-y-2">
        {units.length > 0 ? (
          units.map((unit) => {
            const canRetireUnit = canRetire && unit.status === "ready";
            const equippedRelics = relics.filter((relic) => relic.equippedUnitId === unit.id);
            const characterRank = getCharacterRank(unit);

            return (
              <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={unit.id}>
                <div className="flex items-center justify-between gap-3">
                  <div className="min-w-0">
                    <div className="truncate text-sm font-medium text-slate-100">{unit.name}</div>
                    <div className="mt-1 text-xs text-slate-400">
                      {formatUnitStrength(unit)} - {formatUnitKeywords(unit)}
                    </div>
                    {characterRank ? (
                      <div className="mt-1 text-xs text-amber-100">
                        Nivel {getCharacterLevel(unit)} - {characterRank}
                      </div>
                    ) : null}
                    {equippedRelics.length > 0 ? (
                      <div className="mt-2 flex flex-wrap gap-1.5">
                        {equippedRelics.map((relic) => (
                          <span
                            className="rounded border border-violet-300/25 bg-violet-400/10 px-2 py-0.5 text-[11px] text-violet-100"
                            key={relic.id}
                          >
                            {relic.name}
                          </span>
                        ))}
                      </div>
                    ) : null}
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <Badge tone={getUnitStatusTone(unit.status)}>{getUnitStatusLabel(unit.status)}</Badge>
                    {canRetire ? (
                      <Button
                        disabled={!canRetireUnit || retirePendingUnitId === unit.id}
                        onClick={() => onRetireUnit?.(unit)}
                        size="sm"
                        variant="ghost"
                      >
                        Retirar
                      </Button>
                    ) : null}
                  </div>
                </div>
              </div>
            );
          })
        ) : (
          <div className="rounded-md border border-cyan-200/10 bg-slate-950/20 p-3 text-sm text-slate-500">
            Sin unidades visibles.
          </div>
        )}
      </div>
    </div>
  );
}

function MissionEnemyUnitGroup({
  title,
  faction,
  units
}: {
  title: string;
  faction: Faction | null;
  units: NarrativeMissionEnemyUnit[];
}) {
  return (
    <div className="rounded-md border border-rose-300/14 bg-rose-400/8 p-2.5">
      <div className="mb-2 flex items-center justify-between gap-2">
        <div className="inline-flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-rose-200/80">
          {faction ? <span className="size-2 rounded-full" style={{ backgroundColor: faction.color }} /> : null}
          {title}
        </div>
        <Badge tone="rose">{units.length}</Badge>
      </div>
      <div className="space-y-2">
        {units.map((unit) => (
          <div className="rounded-md border border-rose-300/15 bg-slate-950/35 p-3" key={unit.id}>
            <div className="text-sm font-medium text-slate-100">{unit.name}</div>
            {unit.details ? <div className="mt-1 text-xs leading-5 text-slate-400">{unit.details}</div> : null}
          </div>
        ))}
      </div>
    </div>
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
    return selectedQuantities[unit.id] ? [{ unitId: unit.id, quantity: unit.quantity }] : [];
  });
  const selectedUnitCount = selectedSelections.length;
  const selectedMiniatures = selectedSelections.reduce((total, selection) => total + selection.quantity, 0);
  const totalUridiumCost = routePlan ? routePlan.uridiumCost * selectedUnitCount : 0;
  const hasEnoughUridium = resources && routePlan ? resources.uridium >= totalUridiumCost : false;
  const routeText =
    activePathSystemIds.length > 1
      ? activePathSystemIds.map((id) => systemById.get(id)?.name ?? id).join(" -> ")
      : "Sin destino fijado";
  const destinationSystem = activePathSystemIds.length > 1 ? systemById.get(activePathSystemIds[activePathSystemIds.length - 1]) : null;
  const destinationIsBlocked = Boolean(
    destinationSystem && isSystemBlockedForMovement(destinationSystem, snapshot.currentUser.factionId)
  );
  const approvalSystems = activePathSystemIds
    .slice(1)
    .map((id) => systemById.get(id))
    .filter(
      (system): system is StarSystem =>
        Boolean(system?.controllerFactionId) &&
        system?.controllerFactionId !== snapshot.currentUser.factionId &&
        system?.status === "controlled"
    );
  const approvalFactionNames = Array.from(
    new Set(
      approvalSystems.map(
        (system) => snapshot.factions.find((faction) => faction.id === system.controllerFactionId)?.name ?? "Facción rival"
      )
    )
  );
  const canConfirm =
    rpcReady &&
    selectedSelections.length > 0 &&
    Boolean(routePlan && routePlan.segmentCount > 0) &&
    Boolean(hasEnoughUridium) &&
    !destinationIsBlocked;

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
      <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] top-[calc(4.5rem+env(safe-area-inset-top))] z-40 flex flex-col overflow-hidden lg:hidden">
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
                isSelected={Boolean(selectedQuantities[unit.id])}
                onToggleSelected={(nextSelected) => onSetUnitQuantity(unit.id, nextSelected ? unit.quantity : 0)}
                unit={unit}
              />
            ))}
          </div>
        </div>

        <div className="shrink-0 border-t border-cyan-200/15 bg-slate-950/60 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3">
          <div className="mb-3 rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-xs text-slate-300">
            {selectedSelections.length > 0
              ? `${selectedSelections.length} unidades seleccionadas listas para mover.`
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
      <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] z-40 flex max-h-[calc(var(--app-height)-5rem)] flex-col overflow-hidden lg:hidden">
        <div className="shrink-0 border-b border-cyan-200/15 p-3">
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
              <div className="font-semibold text-cyan-50">{selectedSelections.length}</div>
            </div>
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-2">
              <div className="flex items-center gap-1 text-slate-400">
                <ResourceIcon className="size-3.5" resource="uridium" />
                Uridium
              </div>
              <div className={hasEnoughUridium ? "font-semibold text-cyan-50" : "font-semibold text-rose-100"}>
                {formatCompactNumber(totalUridiumCost)}/{formatCompactNumber(resources?.uridium ?? 0)}
              </div>
            </div>
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-2">
              <div className="text-slate-400">Tiempo</div>
              <div className="font-semibold text-cyan-50">{formatTravelDuration(routePlan?.durationSeconds ?? 0)}</div>
            </div>
          </div>
        </div>

        <div className="grid shrink-0 grid-cols-2 gap-2 px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3 sm:grid-cols-4">
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

        <div className="mobile-scroll max-h-32 shrink-0">
          {!rpcReady ? (
            <div className="border-t border-amber-300/20 bg-amber-300/10 px-3 py-2 text-xs text-amber-100">
              Supabase no está configurado.
            </div>
          ) : null}
          {mutation.error ? (
            <div className="border-t border-rose-300/20 bg-rose-400/10 px-3 py-2 text-xs text-rose-100">
              {mutation.error.message}
            </div>
          ) : null}
          {destinationIsBlocked ? (
            <div className="border-t border-amber-300/20 bg-amber-300/10 px-3 py-2 text-xs text-amber-100">
              El destino está bloqueado por una batalla. Puedes atravesarlo, pero no terminar el movimiento allí.
            </div>
          ) : approvalSystems.length > 0 ? (
            <div className="border-t border-amber-300/20 bg-amber-300/10 px-3 py-2 text-xs text-amber-100">
              Requiere permiso de paso o estancia de {approvalFactionNames.join(", ")}.
            </div>
          ) : null}
        </div>
      </Panel>
    );
  }

  return (
    <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] z-40 mx-auto grid max-h-[calc(var(--app-height)-2rem)] max-w-6xl grid-cols-1 overflow-hidden md:inset-x-4 md:bottom-[calc(1rem+env(safe-area-inset-bottom))] md:max-h-[72vh] md:grid-cols-[minmax(0,1fr)_340px] lg:max-h-[64vh]">
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

        <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
          {availableUnits.map((unit) => (
            <UnitSelectionCard
              key={unit.id}
              isSelected={Boolean(selectedQuantities[unit.id])}
              onToggleSelected={(nextSelected) => onSetUnitQuantity(unit.id, nextSelected ? unit.quantity : 0)}
              unit={unit}
            />
          ))}
        </div>
      </div>

      <aside className="mobile-scroll border-t border-cyan-200/15 bg-slate-950/35 p-4 md:min-h-0 md:border-l md:border-t-0">
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
              {formatCompactNumber(totalUridiumCost)} / {formatCompactNumber(resources?.uridium ?? 0)}
            </div>
            {routePlan && selectedUnitCount > 1 ? (
              <div className="mt-1 text-[11px] text-slate-500">
                Ruta {routePlan.uridiumCost} x {selectedUnitCount}
              </div>
            ) : null}
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
            ? `${selectedSelections.length} unidades seleccionadas - ${selectedMiniatures} miniaturas en total`
            : "Sin unidades seleccionadas"}
        </div>

        {!rpcReady ? (
          <div className="mb-3 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
            Supabase no está configurado.
          </div>
        ) : null}

        {mutation.error ? <p className="mb-3 text-sm text-rose-200">{mutation.error.message}</p> : null}
        {destinationIsBlocked ? (
          <p className="mb-3 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
            El destino está bloqueado por una batalla. Puedes atravesarlo, pero no terminar el movimiento allí.
          </p>
        ) : approvalSystems.length > 0 ? (
          <p className="mb-3 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
            Esta ruta atraviesa o termina en territorio de otro jugador. Quedara pendiente hasta que acepten: {approvalFactionNames.join(", ")}.
          </p>
        ) : null}

        <Button className="sticky bottom-0 w-full" disabled={!canConfirm || mutation.isPending} onClick={() => mutation.mutate()}>
          <Check size={16} />
          {mutation.isPending ? "Enviando..." : "Confirmar movimiento"}
        </Button>
      </aside>
    </Panel>
  );
}

function AttackPlanner({
  snapshot,
  originSystem,
  targetSystemId,
  selectedQuantities,
  onSetTargetSystem,
  onSetUnitQuantity,
  onClose
}: {
  snapshot: CampaignSnapshot;
  originSystem: StarSystem;
  targetSystemId: string | null;
  selectedQuantities: Record<string, number>;
  onSetTargetSystem: (systemId: string | null) => void;
  onSetUnitQuantity: (unitId: string, quantity: number) => void;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [attackMode, setAttackMode] = useState<"solo" | "coalition">("solo");
  const [invitedFactionIds, setInvitedFactionIds] = useState<string[]>([]);
  const rpcReady = canUseMovementRpc();
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
  const targetSystems = useMemo(
    () =>
      snapshot.systems.filter(
        (system) =>
          system.status === "controlled" &&
          system.controllerFactionId &&
          system.controllerFactionId !== snapshot.currentUser.factionId &&
          !system.isCapital &&
          !isSystemBlockedForMovement(system) &&
          Boolean(getEdgeBetween(snapshot.edges, originSystem.id, system.id)) &&
          !getAttackOperationBlockReason(
            snapshot.battleOperations,
            originSystem.id,
            system.id,
            snapshot.currentUser.factionId
          )
      ),
    [originSystem.id, snapshot.currentUser.factionId, snapshot.battleOperations, snapshot.edges, snapshot.systems]
  );
  const selectedSelections = availableUnits.flatMap<UnitMovementSelection>((unit) =>
    selectedQuantities[unit.id] ? [{ unitId: unit.id, quantity: unit.quantity }] : []
  );
  const selectedMiniatures = selectedSelections.reduce((total, selection) => total + selection.quantity, 0);
  const targetSystem = targetSystems.find((system) => system.id === targetSystemId) ?? null;
  const targetFaction = snapshot.factions.find((faction) => faction.id === targetSystem?.controllerFactionId) ?? null;
  const supportFactions = snapshot.factions.filter(
    (faction) =>
      !faction.isNarrative &&
      faction.id !== snapshot.currentUser.factionId &&
      faction.id !== targetSystem?.controllerFactionId
  );
  const limits = snapshot.battleLimits;
  const ownLimitReason =
    limits && limits.startedAttacks >= limits.maxStartedAttacks
      ? "Has alcanzado el límite de ataques iniciados en esta ventana."
      : limits && limits.totalParticipations >= limits.maxTotalParticipations
        ? "Has alcanzado el máximo de participaciones de la ventana."
        : limits && limits.activeBattles >= limits.maxActiveBattles
          ? "Has alcanzado el máximo de batallas activas."
          : null;
  const canConfirm =
    rpcReady &&
    selectedSelections.length > 0 &&
    Boolean(targetSystem) &&
    !ownLimitReason;
  const mutation = useMutation({
    mutationFn: () => {
      if (!targetSystem) {
        throw new Error("Selecciona un sistema enemigo adyacente.");
      }

      if (attackMode === "coalition") {
        return createCoalitionAttackDraft(
          selectedSelections,
          originSystem.id,
          targetSystem.id,
          invitedFactionIds.filter((factionId) => factionId !== targetSystem.controllerFactionId)
        );
      }

      return createAttackOrder(selectedSelections, originSystem.id, targetSystem.id);
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });

  return (
    <Panel className="pointer-events-auto fixed inset-x-2 bottom-[calc(0.75rem+env(safe-area-inset-bottom))] top-[calc(4.5rem+env(safe-area-inset-top))] z-40 mx-auto flex max-w-6xl flex-col overflow-hidden md:inset-x-4 md:bottom-[calc(1rem+env(safe-area-inset-bottom))] md:top-auto md:grid md:max-h-[72vh] md:grid-cols-[minmax(0,1fr)_340px] lg:max-h-[64vh]">
      <div className="mobile-scroll min-h-0 flex-1 p-4 md:overflow-y-auto">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-xs uppercase tracking-[0.22em] text-rose-200/70">Ataque de unidades</div>
            <h2 className="mt-1 text-lg font-semibold text-cyan-50">{originSystem.name}</h2>
          </div>
          <Button aria-label="Cerrar ataque" onClick={onClose} size="icon" variant="ghost">
            <X size={17} />
          </Button>
        </div>

        <div className="mb-4 grid gap-2">
          <div className="grid grid-cols-2 gap-2">
            <Button
              onClick={() => setAttackMode("solo")}
              size="sm"
              variant={attackMode === "solo" ? "danger" : "ghost"}
            >
              <Swords size={15} />
              Individual
            </Button>
            <Button
              onClick={() => setAttackMode("coalition")}
              size="sm"
              variant={attackMode === "coalition" ? "danger" : "ghost"}
            >
              <Shield size={15} />
              Coalicion
            </Button>
          </div>
          <div className="text-xs uppercase tracking-[0.18em] text-cyan-200/70">Objetivo adyacente</div>
          <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
            {targetSystems.map((system) => {
              const faction = snapshot.factions.find((item) => item.id === system.controllerFactionId);

              return (
                <button
                  className={`rounded-md border p-3 text-left transition ${
                    targetSystemId === system.id
                      ? "border-rose-200/60 bg-rose-400/15"
                      : "border-cyan-200/15 bg-slate-950/35 hover:border-rose-200/40"
                  }`}
                  key={system.id}
                  onClick={() => onSetTargetSystem(system.id)}
                  type="button"
                >
                  <div className="flex items-start justify-between gap-2">
                    <span className="min-w-0 break-words font-medium text-slate-100">{system.name}</span>
                    <Badge className="shrink-0 whitespace-nowrap" tone={system.isTemporaryMission || targetSystemId === system.id ? "rose" : "slate"}>
                      {system.isTemporaryMission ? "Misión" : "Enemigo"}
                    </Badge>
                  </div>
                  <div className="mt-1 break-words text-xs text-slate-400">
                    {system.isTemporaryMission ? "Objetivo narrativo" : faction?.name ?? "Facción rival"}
                  </div>
                </button>
              );
            })}
            {targetSystems.length === 0 ? (
              <div className="rounded-md border border-slate-400/20 bg-slate-900/30 p-3 text-sm text-slate-400">
                No hay sistemas enemigos adyacentes atacables desde este origen.
              </div>
            ) : null}
          </div>
        </div>

        <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
          {availableUnits.map((unit) => (
            <UnitSelectionCard
              key={unit.id}
              isSelected={Boolean(selectedQuantities[unit.id])}
              onToggleSelected={(nextSelected) => onSetUnitQuantity(unit.id, nextSelected ? unit.quantity : 0)}
              unit={unit}
            />
          ))}
        </div>

        {attackMode === "coalition" ? (
          <div className="mt-4">
            <div className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">
              Invitar al punto de reunión
            </div>
            <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
              {supportFactions.map((faction) => {
                const selected = invitedFactionIds.includes(faction.id);

                return (
                  <button
                    className={`rounded-md border p-3 text-left transition ${
                      selected
                        ? "border-cyan-200/55 bg-cyan-300/10"
                        : "border-cyan-200/15 bg-slate-950/35"
                    }`}
                    key={faction.id}
                    onClick={() =>
                      setInvitedFactionIds((current) =>
                        current.includes(faction.id)
                          ? current.filter((id) => id !== faction.id)
                          : [...current, faction.id]
                      )
                    }
                    type="button"
                  >
                    <div className="break-words font-medium text-slate-100">{faction.name}</div>
                    <div className="mt-1 text-xs text-slate-400">
                      {selected ? "Recibirá invitación" : "Sin invitar"}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        ) : null}
      </div>

      <aside className="mobile-scroll max-h-[48%] shrink-0 border-t border-cyan-200/15 bg-slate-950/35 p-4 pb-[max(1rem,env(safe-area-inset-bottom))] md:max-h-none md:min-h-0 md:border-l md:border-t-0 md:pb-4">
        <div className="mb-4 text-sm font-semibold text-cyan-50">
          {attackMode === "coalition" ? "Preparar coalición" : "Confirmar ataque"}
        </div>
        <div className="mb-4 rounded-md border border-rose-300/20 bg-rose-400/10 p-3 text-sm text-rose-50">
          {targetSystem ? (
            <>
              {originSystem.name} {" -> "} {targetSystem.name}
              <div className="mt-1 text-xs text-rose-100/80">Defensor: {targetFaction?.name ?? "Facción rival"}</div>
            </>
          ) : (
            "Selecciona un objetivo enemigo adyacente."
          )}
        </div>

        <div className="mb-4 grid grid-cols-2 gap-2">
          <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3">
            <div className="mb-1 flex items-center gap-2 text-xs text-slate-400">
              <Clock3 size={15} />
              Duracion
            </div>
            <div className="font-semibold text-cyan-50">{formatTravelDuration(snapshot.attackDurationSeconds)}</div>
          </div>
          <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3">
            <div className="mb-1 text-xs text-slate-400">Llegada prevista</div>
            <div className="text-xs font-semibold text-cyan-50">
              {attackMode === "coalition"
                ? "Empieza al lanzar la coalición"
                : `${formatTravelDuration(snapshot.attackDurationSeconds)} tras confirmar`}
            </div>
          </div>
        </div>

        <div className="mb-4 rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-xs text-slate-300">
          {selectedSelections.length > 0
            ? `${selectedSelections.length} unidades seleccionadas - ${selectedMiniatures} miniaturas`
            : "Sin unidades seleccionadas"}
        </div>

        {snapshot.attackDurationSeconds < 86400 ? (
          <div className="mb-4 rounded-md border border-amber-300/20 bg-amber-300/10 p-3 text-xs text-amber-100">
            Tiempo de prueba local. Regla final: movimiento 3 días por salto y ataque 6 días.
          </div>
        ) : null}

        {limits ? (
          <div className="mb-4 rounded-md border border-cyan-200/15 bg-slate-950/45 p-3 text-xs text-slate-300">
            <div className="mb-2 font-semibold text-cyan-50">Ventana de campaña</div>
            <div>Ataques iniciados: {limits.startedAttacks}/{limits.maxStartedAttacks}</div>
            <div>Ataques recibidos: {limits.receivedAttacks}/{limits.maxReceivedAttacks}</div>
            <div>Participaciones: {limits.totalParticipations}/{limits.maxTotalParticipations}</div>
            <div>Batallas activas: {limits.activeBattles}/{limits.maxActiveBattles}</div>
          </div>
        ) : null}

        {!rpcReady ? (
          <div className="mb-3 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
            Supabase no está configurado.
          </div>
        ) : null}

        {ownLimitReason ? <p className="mb-3 text-sm text-rose-200">{ownLimitReason}</p> : null}
        {mutation.error ? <p className="mb-3 text-sm text-rose-200">{mutation.error.message}</p> : null}

        <Button className="sticky bottom-0 w-full" disabled={!canConfirm || mutation.isPending} onClick={() => mutation.mutate()} variant="danger">
          <Swords size={16} />
          {mutation.isPending
            ? attackMode === "coalition"
              ? "Preparando..."
              : "Lanzando..."
            : attackMode === "coalition"
              ? "Crear punto de reunión"
              : "Confirmar ataque"}
        </Button>
      </aside>
    </Panel>
  );
}

function getAttackOperationBlockReason(
  battleOperations: CampaignSnapshot["battleOperations"],
  originSystemId: string,
  targetSystemId: string,
  currentFactionId: string | null
) {
  if (!currentFactionId) {
    return "Sin facción activa.";
  }

  const activeOperations = battleOperations.filter((operation) =>
    ["assembling", "moving", "in_battle"].includes(operation.status)
  );

  if (
    activeOperations.some(
      (operation) => operation.leaderFactionId === currentFactionId && operation.targetSystemId === targetSystemId
    )
  ) {
    return "Ya tienes un ataque activo contra este sistema.";
  }

  if (activeOperations.some((operation) => operation.targetSystemId === targetSystemId)) {
    return "Este sistema ya tiene una operación activa.";
  }

  if (
    activeOperations.some(
      (operation) =>
        operation.status === "moving" &&
        operation.defenderFactionId === currentFactionId &&
        operation.originSystemId === targetSystemId &&
        operation.targetSystemId === originSystemId
    )
  ) {
    return "No puedes contraatacar al origen de un ataque entrante.";
  }

  return null;
}

function UnitSelectionCard({
  unit,
  isSelected,
  onToggleSelected
}: {
  unit: CampaignUnit;
  isSelected: boolean;
  onToggleSelected: (selected: boolean) => void;
}) {
  const selected = isSelected;

  return (
    <div
      className={`rounded-md border p-3 text-left transition ${
        selected
          ? "border-cyan-200/55 bg-cyan-300/12 shadow-[0_0_20px_rgba(34,211,238,0.12)]"
          : "border-cyan-200/15 bg-slate-950/35 hover:border-cyan-200/35"
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="break-words font-medium text-slate-100">{unit.name}</div>
          <div className="mt-1 text-xs text-slate-400">
            {formatUnitStrength(unit)} - {formatUnitKeywords(unit)}
          </div>
          {isCharacterUnit(unit) ? (
            <div className="mt-1 text-xs text-amber-100">
              Nivel {getCharacterLevel(unit)} - {getCharacterRank(unit)}
            </div>
          ) : null}
        </div>
        <Badge className="shrink-0 whitespace-nowrap" tone={selected ? "cyan" : "slate"}>
          {selected ? "Lista" : "Libre"}
        </Badge>
      </div>

      <div className="mt-3 rounded-md border border-cyan-200/10 bg-slate-950/40 px-3 py-2 text-xs text-slate-300">
        Esta unidad se mueve completa: {unit.quantity} miniaturas.
      </div>

      <Button className="mt-3 w-full" onClick={() => onToggleSelected(!selected)} size="sm" variant={selected ? "ghost" : "primary"}>
        {selected ? "Quitar unidad" : "Seleccionar unidad"}
      </Button>
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
  const report = useMemo(
    () => findLatestBattleReport(snapshot.battleReports, conflict.id),
    [conflict.id, snapshot.battleReports]
  );
  const warUnits = useMemo(
    () =>
      snapshot.units.filter(
        (unit) => unit.currentSystemId === system.id && unit.status === "in_war" && unit.quantity > 0
      ),
    [snapshot.units, system.id]
  );
  const requiredFactionIds = useMemo(
    () => getBattleReportRequiredFactionIds(conflict, warUnits, snapshot.battleUnitCommitments),
    [conflict, snapshot.battleUnitCommitments, warUnits]
  );
  const factionOptions = snapshot.factions.filter((faction) =>
    getConflictFactionIds(conflict).includes(faction.id)
  );
  const participantFactions = snapshot.factions.filter((faction) => requiredFactionIds.includes(faction.id));
  const currentFactionId = snapshot.currentUser.factionId;
  const isParticipant = Boolean(currentFactionId && requiredFactionIds.includes(currentFactionId));
  const isAdmin = snapshot.currentUser.role === "admin";
  const defaultWinner =
    factionOptions.find((faction) => faction.id === currentFactionId)?.id ??
    conflict.attackerFactionId;
  const isConquerableSystem = system.isConquerable;
  const [battleMode, setBattleMode] = useState<BattleResolutionMode>(report?.battleMode ?? "tabletop");
  const [winnerFactionId, setWinnerFactionId] = useState<string | null>(report?.winnerFactionId ?? defaultWinner);
  const [narrativeNotes, setNarrativeNotes] = useState(report?.narrativeNotes ?? "");
  const [survivors, setSurvivors] = useState<Record<string, number>>(() => buildReportSurvivors(warUnits, report));
  const [woundsRemaining, setWoundsRemaining] = useState<Record<string, number>>(() =>
    buildReportWounds(snapshot, warUnits, report, buildReportSurvivors(warUnits, report))
  );

  const rpcReady = canUseBattleReportRpc();
  const finalControllerFactionId = isConquerableSystem ? winnerFactionId : null;

  const buildPayload = () => ({
    battleMode,
    winnerFactionId,
    finalControllerFactionId,
    survivors,
    woundsRemaining,
    expectedRevisión: report?.revision ?? 0,
    postBattleBlockedUntil: buildDefaultPostBattleBlockedUntil(),
    narrativeNotes: narrativeNotes.trim() || null
  });

  const saveMutation = useMutation({
    mutationFn: () =>
      submitBattleReport(conflict.id, buildPayload()),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const validateMutation = useMutation({
    mutationFn: () => validateBattleReport(conflict.id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const adminMutation = useMutation({
    mutationFn: () => adminConfirmBattleReport(conflict.id, buildPayload()),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });
  const busy = saveMutation.isPending || validateMutation.isPending || adminMutation.isPending;
  const currentFactionValidated = Boolean(
    report && currentFactionId && hasFactionValidated(report, currentFactionId)
  );
  const validatedCount = report
    ? requiredFactionIds.filter((factionId) => hasFactionValidated(report, factionId)).length
    : 0;
  const allPlayersValidated = report
    ? requiredFactionIds.length > 0 && requiredFactionIds.every((factionId) => hasFactionValidated(report, factionId))
    : false;

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
              {participantFactions.map((faction) => (
                <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={faction.id}>
                  <div className="flex items-center justify-between gap-3">
                    <div className="inline-flex items-center gap-2 text-sm font-medium text-slate-100">
                      <span className="size-2 rounded-full" style={{ backgroundColor: faction.color }} />
                      {faction.name}
                    </div>
                    <Badge tone={report && hasFactionValidated(report, faction.id) ? "cyan" : "amber"}>
                      {report && hasFactionValidated(report, faction.id) ? "Validado" : "Pendiente"}
                    </Badge>
                  </div>
                </div>
              ))}
            </div>

            <div className="mb-4 rounded-md border border-cyan-200/15 bg-slate-950/35 p-3">
              <div className="flex flex-wrap items-center gap-2">
                <Badge tone={getBattleReportStatusTone(report)}>{getBattleReportStatusLabel(report)}</Badge>
                {report ? <Badge tone="slate">Revisión {report.revision}</Badge> : null}
                <Badge tone={battleMode === "autoresolve" ? "violet" : "cyan"}>
                  {battleMode === "autoresolve" ? "Autoresolver" : "Mesa"}
                </Badge>
                <Badge tone={allPlayersValidated ? "cyan" : "amber"}>
                  {validatedCount}/{requiredFactionIds.length} validaciones
                </Badge>
              </div>
            </div>

            <h3 className="mb-3 text-sm font-semibold text-cyan-50">Supervivientes por unidad</h3>
            <div className="space-y-2">
              {warUnits.map((unit) => {
                const value = clampInteger(survivors[unit.id] ?? unit.quantity, 0, unit.quantity);
                const woundsPerModel = getUnitWoundsPerModel(snapshot, unit);
                const maxWounds = value * woundsPerModel;
                const woundsValue = clampInteger(woundsRemaining[unit.id] ?? 0, 0, maxWounds);
                const faction = snapshot.factions.find((item) => item.id === unit.factionId);

                return (
                  <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={unit.id}>
                    <div className="mb-3 flex items-start justify-between gap-3">
                      <div>
                        <div className="font-medium text-slate-100">{unit.name}</div>
                        <div className="mt-1 text-xs text-slate-400">
                          {faction?.name ?? "Facción"} - {unit.quantity}/{unit.startingQuantity} miniaturas actuales
                        </div>
                      </div>
                      <Badge tone={value === 0 ? "rose" : value < unit.quantity ? "amber" : "cyan"}>
                        {value} sobreviven
                      </Badge>
                    </div>

                    <div className="flex items-center justify-between rounded-md border border-cyan-200/10 bg-slate-950/40 p-2">
                      <Button
                        disabled={value <= 0 || busy}
                        onClick={() => {
                          const nextValue = value - 1;
                          setSurvivors((current) => ({ ...current, [unit.id]: nextValue }));
                          setWoundsRemaining((current) => ({
                            ...current,
                            [unit.id]: Math.min(current[unit.id] ?? 0, nextValue * woundsPerModel)
                          }));
                        }}
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
                        disabled={value >= unit.quantity || busy}
                        onClick={() => setSurvivors((current) => ({ ...current, [unit.id]: value + 1 }))}
                        size="icon"
                        variant="ghost"
                      >
                        <Plus size={15} />
                      </Button>
                    </div>

                    <div className="mt-2 flex items-center justify-between rounded-md border border-cyan-200/10 bg-slate-950/40 p-2">
                      <Button
                        disabled={woundsValue <= 0 || busy}
                        onClick={() => setWoundsRemaining((current) => ({ ...current, [unit.id]: woundsValue - 1 }))}
                        size="icon"
                        variant="ghost"
                      >
                        <Minus size={15} />
                      </Button>
                      <div className="text-center">
                        <div className="text-[11px] text-slate-400">Heridas restantes</div>
                        <div className="text-base font-semibold text-cyan-50">{woundsValue}/{maxWounds}</div>
                      </div>
                      <Button
                        disabled={woundsValue >= maxWounds || busy}
                        onClick={() => setWoundsRemaining((current) => ({ ...current, [unit.id]: woundsValue + 1 }))}
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
                <span className="mb-2 block text-slate-300">Resolucion</span>
                <select
                  className="w-full rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
                  disabled={busy}
                  onChange={(event) => setBattleMode(event.target.value as BattleResolutionMode)}
                  value={battleMode}
                >
                  <option value="tabletop">Jugada en mesa</option>
                  <option value="autoresolve">Autoresolver</option>
                </select>
              </label>

              <label className="block text-sm">
                <span className="mb-2 block text-slate-300">Ganador</span>
                <select
                  className="w-full rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
                  disabled={busy}
                  onChange={(event) => setWinnerFactionId(event.target.value || null)}
                  value={winnerFactionId ?? ""}
                >
                  <option value="">Empate / sin ganador</option>
                  {factionOptions.map((faction) => (
                    <option key={faction.id} value={faction.id}>
                      {faction.name}
                    </option>
                  ))}
                </select>
              </label>

              <label className="block text-sm">
                <span className="mb-2 block text-slate-300">Notas narrativas</span>
                <textarea
                  className="min-h-24 w-full resize-none rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
                  disabled={busy}
                  onChange={(event) => setNarrativeNotes(event.target.value)}
                  value={narrativeNotes}
                />
              </label>

              <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-xs leading-5 text-slate-400">
                No se registran recursos ganados: las batallas solo actualizan resultado, control, bajas, heridas y retirada.
              </div>

              {!rpcReady ? (
                <div className="rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
                  Supabase no está configurado.
                </div>
              ) : null}

              {saveMutation.error ? <p className="text-sm text-rose-200">{saveMutation.error.message}</p> : null}
              {validateMutation.error ? <p className="text-sm text-rose-200">{validateMutation.error.message}</p> : null}
              {adminMutation.error ? <p className="text-sm text-rose-200">{adminMutation.error.message}</p> : null}

              <Button
                className="w-full"
                disabled={!rpcReady || warUnits.length === 0 || busy || (!isParticipant && !isAdmin)}
                onClick={() => saveMutation.mutate()}
                variant="danger"
              >
                {saveMutation.isPending ? "Guardando..." : report ? "Guardar edición" : "Crear informe"}
              </Button>

              {isParticipant ? (
                <Button
                  className="w-full"
                  disabled={!rpcReady || !report || currentFactionValidated || busy}
                  onClick={() => validateMutation.mutate()}
                  variant="primary"
                >
                  <Check size={16} />
                  {currentFactionValidated ? "Ya validado" : validateMutation.isPending ? "Validando..." : "Validar informe"}
                </Button>
              ) : null}

              {isAdmin ? (
                <Button
                  className="sticky bottom-0 w-full"
                  disabled={!rpcReady || warUnits.length === 0 || busy || !allPlayersValidated}
                  onClick={() => adminMutation.mutate()}
                  variant="primary"
                >
                  <Check size={16} />
                  {adminMutation.isPending ? "Aplicando..." : "Confirmar admin y aplicar"}
                </Button>
              ) : null}

              {isAdmin && !allPlayersValidated ? (
                <p className="text-xs text-amber-100">
                  El resultado se aplicará automáticamente cuando todos los participantes validen la revisión actual.
                </p>
              ) : null}
            </div>
          </aside>
        </div>
      </Panel>
    </div>
  );
}

function findLatestBattleReport(reports: BattleReport[], conflictId: string) {
  return reports
    .filter((report) => report.conflictId === conflictId && report.status !== "rejected")
    .sort((a, b) => getReportTime(b) - getReportTime(a))[0] ?? null;
}

function buildReportSurvivors(units: CampaignUnit[], report: BattleReport | null) {
  return Object.fromEntries(
    units.map((unit) => [
      unit.id,
      clampInteger(report?.survivors?.[unit.id] ?? unit.quantity, 0, unit.quantity)
    ])
  );
}

function buildReportWounds(
  snapshot: CampaignSnapshot,
  units: CampaignUnit[],
  report: BattleReport | null,
  survivors: Record<string, number>
) {
  return Object.fromEntries(
    units.map((unit) => {
      const survivorsValue = survivors[unit.id] ?? unit.quantity;
      const maxWounds = survivorsValue * getUnitWoundsPerModel(snapshot, unit);

      return [
        unit.id,
        clampInteger(report?.woundsRemaining?.[unit.id] ?? unit.woundsTaken, 0, maxWounds)
      ];
    })
  );
}

function getReportTime(report: BattleReport) {
  return report.updatedAt ? new Date(report.updatedAt).getTime() : 0;
}

function getConflictFactionIds(conflict: Conflict) {
  return [conflict.attackerFactionId, conflict.defenderFactionId].filter((id): id is string => Boolean(id));
}

function getBattleReportRequiredFactionIds(
  conflict: Conflict,
  warUnits: CampaignUnit[],
  commitments: CampaignSnapshot["battleUnitCommitments"]
) {
  const factionIds = new Set(getConflictFactionIds(conflict));

  for (const unit of warUnits) {
    factionIds.add(unit.factionId);
  }

  if (conflict.battleOperationId) {
    for (const commitment of commitments) {
      if (
        commitment.operationId === conflict.battleOperationId &&
        isActiveBattleCommitmentStatus(commitment.status)
      ) {
        factionIds.add(commitment.factionId);
      }
    }
  }

  return Array.from(factionIds);
}

function isActiveBattleCommitmentStatus(status: CampaignSnapshot["battleUnitCommitments"][number]["status"]) {
  return status !== "returned" && status !== "destroyed" && status !== "cancelled";
}

function hasFactionValidated(report: BattleReport, factionId: string) {
  return report.participantValidations[factionId]?.revision === report.revision;
}

function isBattleReportActionableForCurrentUser(
  snapshot: CampaignSnapshot,
  report: BattleReport,
  currentFactionId?: string | null
) {
  const conflict = snapshot.conflicts.find((item) => item.id === report.conflictId);

  if (!conflict) {
    return false;
  }

  if (snapshot.currentUser.role === "admin") {
    return ["players_confirmed", "submitted", "disputed"].includes(report.status);
  }

  if (!currentFactionId) {
    return false;
  }

  const warUnits = snapshot.units.filter(
    (unit) => unit.currentSystemId === conflict.systemId && unit.status !== "destroyed" && unit.quantity > 0
  );
  const participantFactionIds = getBattleReportRequiredFactionIds(
    conflict,
    warUnits,
    snapshot.battleUnitCommitments
  );

  if (!participantFactionIds.includes(currentFactionId)) {
    return false;
  }

  if (report.status === "awaiting_validation") {
    return !hasFactionValidated(report, currentFactionId);
  }

  return ["draft", "submitted", "disputed"].includes(report.status);
}

function getBattleReportStatusLabel(report: BattleReport | null) {
  if (!report) {
    return "Sin informe";
  }

  const labels: Record<BattleReport["status"], string> = {
    draft: "Borrador",
    awaiting_validation: "Pendiente de validar",
    players_confirmed: "Validado por jugadores",
    submitted: "Enviado",
    auto_confirmed: "Confirmado automáticamente",
    admin_confirmed: "Confirmado por admin",
    disputed: "En disputa",
    rejected: "Rechazado"
  };

  return labels[report.status];
}

function getBattleReportStatusTone(report: BattleReport | null) {
  if (!report) {
    return "slate";
  }

  if (report.status === "players_confirmed" || report.status === "admin_confirmed" || report.status === "auto_confirmed") {
    return "cyan";
  }

  if (report.status === "disputed" || report.status === "rejected") {
    return "rose";
  }

  return "amber";
}

function formatUnitStrength(unit: CampaignUnit) {
  return `${unit.quantity}/${unit.startingQuantity} miniaturas - ${unit.woundsTaken} heridas - ${getCurrentUnitPoints(unit)} pts`;
}

function getUnitWoundsPerModel(snapshot: CampaignSnapshot, unit: CampaignUnit) {
  return snapshot.unitTemplates.find((template) => template.id === unit.unitTemplateId)?.woundsPerModel ?? 1;
}

function buildDefaultPostBattleBlockedUntil() {
  return new Date(Date.now() + defaultPostBattleBlockDays * 24 * 60 * 60 * 1000).toISOString();
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
