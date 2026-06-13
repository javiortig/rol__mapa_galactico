"use client";

import {
  BadgePercent,
  Banknote,
  Boxes,
  BrainCog,
  Check,
  Clock3,
  Cog,
  Crown,
  Eye,
  Factory,
  Gem,
  Handshake,
  Hammer,
  Landmark,
  Lock,
  Medal,
  Network,
  Package,
  Pickaxe,
  Radar,
  RadioTower,
  Shield,
  Sparkles,
  Store,
  Swords,
  Truck,
  Users,
  X,
  type LucideIcon
} from "lucide-react";
import { createElement, memo, useCallback, useEffect, useMemo, useRef, useState, type RefObject } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceAmount } from "@/components/ui/resource-icon";
import { canUseTechnologyRpc, startTechnologyResearch } from "@/features/technology/api/technology-api";
import {
  getActiveTechnologyResearch,
  getFactionTechnology,
  getTechnologyStatus,
  isTechnologyNodeVisible,
  type DerivedTechnologyStatus
} from "@/features/technology/lib/technology-state";
import { cn } from "@/lib/utils";
import { formatCountdown } from "@/lib/time";
import { useMediaQuery } from "@/lib/use-media-query";
import type { CampaignSnapshot, TechnologyNode, TechnologyPrerequisite } from "@/domain/campaign";

type BranchConfig = {
  angle: number;
  color: string;
  label: string;
  mutedColor: string;
  startRadius: number;
  tierGap: number;
};

type TechnologyPoint = {
  branch: string;
  id: string;
  x: number;
  y: number;
};

type BranchRay = {
  branch: string;
  color: string;
  endX: number;
  endY: number;
  label: string;
  labelX: number;
  labelY: number;
};

const boardWidth = 1540;
const boardHeight = 980;
const corePoint = { x: boardWidth / 2, y: boardHeight / 2 };
const coreSize = 150;

const branchOrder = [
  "Progreso",
  "Mando militar",
  "Infanteria y elite",
  "Blindados y maquinas",
  "Arqueotecnologia",
  "Inteligencia"
];

const branchConfigs: Record<string, BranchConfig> = {
  Progreso: {
    angle: 0,
    color: "#67e8f9",
    label: "Progreso",
    mutedColor: "rgba(103,232,249,0.15)",
    startRadius: 184,
    tierGap: 86
  },
  "Mando militar": {
    angle: -56,
    color: "#facc15",
    label: "Mando",
    mutedColor: "rgba(250,204,21,0.14)",
    startRadius: 190,
    tierGap: 88
  },
  "Infanteria y elite": {
    angle: -122,
    color: "#fb7185",
    label: "Infanteria",
    mutedColor: "rgba(251,113,133,0.13)",
    startRadius: 196,
    tierGap: 92
  },
  "Blindados y maquinas": {
    angle: 56,
    color: "#fb923c",
    label: "Maquinas",
    mutedColor: "rgba(251,146,60,0.14)",
    startRadius: 190,
    tierGap: 88
  },
  Arqueotecnologia: {
    angle: 122,
    color: "#c084fc",
    label: "Arqueotec.",
    mutedColor: "rgba(192,132,252,0.14)",
    startRadius: 196,
    tierGap: 90
  },
  Inteligencia: {
    angle: 180,
    color: "#94a3b8",
    label: "Intel.",
    mutedColor: "rgba(148,163,184,0.12)",
    startRadius: 190,
    tierGap: 86
  }
};

export function TechnologyTreeModal({
  snapshot,
  open,
  onClose
}: {
  snapshot: CampaignSnapshot;
  open: boolean;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const boardViewportRef = useRef<HTMLDivElement | null>(null);
  const isTechnologyDesktop = useMediaQuery("(min-width: 1024px)");
  const isMobile = !isTechnologyDesktop;
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const currentFaction = snapshot.factions.find((faction) => faction.id === snapshot.currentUser.factionId) ?? null;
  const currentResources = snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
  const activeResearch = getActiveTechnologyResearch(snapshot);
  const visibleTechnologyNodes = useMemo(
    () => snapshot.technologyNodes.filter(isTechnologyNodeVisible),
    [snapshot.technologyNodes]
  );
  const layout = useMemo(
    () => buildRadialConstellationLayout(visibleTechnologyNodes, snapshot.technologyPrerequisites),
    [snapshot.technologyPrerequisites, visibleTechnologyNodes]
  );
  const nodeById = useMemo(
    () => new Map(visibleTechnologyNodes.map((node) => [node.id, node])),
    [visibleTechnologyNodes]
  );
  const statusByNodeId = useMemo(
    () => new Map(visibleTechnologyNodes.map((node) => [node.id, getTechnologyStatus(snapshot, node)])),
    [snapshot, visibleTechnologyNodes]
  );
  const selectedNode = selectedNodeId ? nodeById.get(selectedNodeId) ?? null : null;
  const rpcReady = canUseTechnologyRpc();
  const mutation = useMutation({
    mutationFn: (technologyNodeId: string) => startTechnologyResearch(technologyNodeId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const handleSelectNode = useCallback((nodeId: string) => setSelectedNodeId(nodeId), []);

  useEffect(() => {
    if (!open) {
      return;
    }

    window.requestAnimationFrame(() => {
      const viewport = boardViewportRef.current;

      if (!viewport) {
        return;
      }

      viewport.scrollLeft = Math.max(0, corePoint.x - viewport.clientWidth / 2);
      viewport.scrollTop = Math.max(0, corePoint.y - viewport.clientHeight / 2);
    });
  }, [open]);

  const handleClose = () => {
    setSelectedNodeId(null);
    onClose();
  };

  if (!open) {
    return null;
  }

  return (
    <div className="pointer-events-auto fixed inset-0 z-50 grid place-items-center bg-black/76 p-0 backdrop-blur-sm md:p-3">
      <Panel className="flex h-[var(--app-height)] w-full max-w-none flex-col overflow-hidden rounded-none border-cyan-200/16 shadow-[0_0_48px_rgba(8,145,178,0.14)] md:h-[96vh] md:w-[98vw] md:rounded-lg">
        <header className="flex items-center justify-between gap-4 border-b border-cyan-200/12 bg-slate-950/78 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:px-5 md:py-4">
          <div>
            <div className="text-xs uppercase tracking-[0.24em] text-cyan-200/70">Arbol tecnologico</div>
            <h2 className="mt-1 text-xl font-semibold text-cyan-50 md:text-2xl">
              {currentFaction?.name ?? "Campana"}
            </h2>
          </div>
          <div className="flex items-center gap-3">
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 px-3 py-2">
              <ResourceAmount resource="technology" value={currentResources?.technology ?? 0} />
            </div>
            <Button aria-label="Cerrar tecnologia" onClick={handleClose} size="icon" variant="ghost">
              <X size={18} />
            </Button>
          </div>
        </header>

        <div className="grid min-h-0 flex-1 grid-rows-[minmax(0,1fr)_auto] overflow-hidden xl:grid-cols-[minmax(0,1fr)_420px] xl:grid-rows-none">
          <RadialTechnologyBoard
            factionColor={currentFaction?.color ?? "#67e8f9"}
            layout={layout}
            nodes={visibleTechnologyNodes}
            onSelectNode={handleSelectNode}
            selectedNodeId={selectedNodeId}
            statusByNodeId={statusByNodeId}
            viewportRef={boardViewportRef}
          />

          {!isMobile || selectedNode ? (
            <TechnologyDetailsPanel
              activeResearch={activeResearch}
              currentTechnology={currentResources?.technology ?? 0}
              error={mutation.error?.message}
              node={selectedNode}
              onCloseNode={isMobile ? () => setSelectedNodeId(null) : undefined}
              onResearch={(node) => mutation.mutate(node.id)}
              pending={mutation.isPending}
              rpcReady={rpcReady}
              snapshot={snapshot}
            />
          ) : null}
        </div>
      </Panel>
    </div>
  );
}

const RadialTechnologyBoard = memo(function RadialTechnologyBoard({
  nodes,
  layout,
  statusByNodeId,
  selectedNodeId,
  factionColor,
  viewportRef,
  onSelectNode
}: {
  nodes: TechnologyNode[];
  layout: ReturnType<typeof buildRadialConstellationLayout>;
  statusByNodeId: Map<string, DerivedTechnologyStatus>;
  selectedNodeId: string | null;
  factionColor: string;
  viewportRef: RefObject<HTMLDivElement | null>;
  onSelectNode: (nodeId: string) => void;
}) {
  return (
    <div
      className="min-h-0 overflow-auto overscroll-contain bg-[radial-gradient(circle_at_50%_50%,rgba(34,211,238,0.11),transparent_19rem),radial-gradient(circle_at_20%_72%,rgba(192,132,252,0.06),transparent_16rem),linear-gradient(180deg,rgba(2,6,23,0.99),rgba(8,13,31,0.99))] [-webkit-overflow-scrolling:touch] [touch-action:pan-x_pan-y]"
      ref={viewportRef}
    >
      <div className="relative h-[860px] w-[1240px]">
        <ConstellationBackdrop />
        <BranchRays rays={layout.rays} />
        <TechnologyConnections layout={layout} statusByNodeId={statusByNodeId} />
        {layout.rays.map((ray) => (
          <BranchChip key={ray.branch} ray={ray} />
        ))}
        <FactionCoreOrb factionColor={factionColor} />
        {nodes.map((node) => (
          <TechnologyOrb
            key={node.id}
            node={node}
            onSelectNode={onSelectNode}
            point={layout.points.get(node.id) ?? corePoint}
            selected={selectedNodeId === node.id}
            status={statusByNodeId.get(node.id) ?? "locked"}
          />
        ))}
      </div>
    </div>
  );
});

const TechnologyConnections = memo(function TechnologyConnections({
  layout,
  statusByNodeId
}: {
  layout: ReturnType<typeof buildRadialConstellationLayout>;
  statusByNodeId: Map<string, DerivedTechnologyStatus>;
}) {
  return (
    <svg
      className="pointer-events-none absolute inset-0 z-[2]"
      height={boardHeight}
      viewBox={`0 0 ${boardWidth} ${boardHeight}`}
      width={boardWidth}
    >
      {layout.connections.map((connection) => {
        const status = statusByNodeId.get(connection.to.id) ?? "locked";
        const inactive = status === "locked" || status === "planned";
        const style = getBranchConfig(connection.to.branch);

        return (
          <path
            d={getConnectionPath(connection.from, connection.to)}
            fill="none"
            key={`${connection.from.id}-${connection.to.id}`}
            opacity={inactive ? 0.34 : 0.78}
            stroke={inactive ? "rgba(100,116,139,0.42)" : style.color}
            strokeDasharray={inactive ? "7 10" : undefined}
            strokeLinecap="round"
            strokeWidth={status === "researching" ? 2.8 : 2}
          />
        );
      })}
    </svg>
  );
});

const TechnologyOrb = memo(function TechnologyOrb({
  node,
  point,
  status,
  selected,
  onSelectNode
}: {
  node: TechnologyNode;
  point: TechnologyPoint | { x: number; y: number };
  status: DerivedTechnologyStatus;
  selected: boolean;
  onSelectNode: (nodeId: string) => void;
}) {
  const style = getBranchConfig(node.branch);
  const locked = status === "locked";
  const planned = status === "planned";
  const researching = status === "researching";
  const unlocked = status === "unlocked";
  const available = status === "available";

  return (
    <button
      aria-label={node.name}
      aria-pressed={selected}
      className={cn(
        "absolute z-10 grid size-[52px] -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full border bg-slate-950/90 transition-[border-color,background-color,opacity] duration-75 focus:outline-none focus:ring-2 focus:ring-cyan-100/55",
        selected && "bg-slate-900",
        available && "border-cyan-200/72",
        unlocked && "border-emerald-200/65",
        researching && "border-amber-200/75",
        (locked || planned) && "border-slate-500/42 opacity-72"
      )}
      onClick={(event) => {
        if (event.detail === 0) {
          onSelectNode(node.id);
        }
      }}
      onPointerDown={(event) => {
        if (event.pointerType === "mouse" && event.button !== 0) {
          return;
        }

        onSelectNode(node.id);
      }}
      style={{
        boxShadow: selected ? `0 0 0 2px ${style.color}` : "inset 0 0 12px rgba(15,23,42,0.86)",
        left: point.x,
        top: point.y
      }}
      type="button"
    >
      <span
        className="absolute inset-[6px] rounded-full border"
        style={{ borderColor: locked || planned ? "rgba(100,116,139,0.38)" : style.color }}
      />
      <TechnologyGlyph
        className={cn("relative z-10", locked || planned ? "text-slate-400" : "text-cyan-50")}
        node={node}
        size={22}
        strokeWidth={1.8}
      />
      <span className="absolute -right-1 -top-1 z-20 grid size-5 place-items-center rounded-full border border-slate-950 bg-slate-950/96">
        {locked || planned ? (
          <Lock className="text-slate-400" size={10} />
        ) : unlocked ? (
          <Check className="text-emerald-200" size={12} />
        ) : researching ? (
          <Sparkles className="text-amber-200" size={10} />
        ) : (
          <Sparkles className="text-cyan-100" size={10} />
        )}
      </span>
    </button>
  );
});

function FactionCoreOrb({ factionColor }: { factionColor: string }) {
  return (
    <section
      className="pointer-events-none absolute z-20"
      style={{
        height: coreSize,
        left: corePoint.x - coreSize / 2,
        top: corePoint.y - coreSize / 2,
        width: coreSize
      }}
    >
      <div
        className="absolute inset-0 grid place-items-center rounded-full border bg-slate-950/94"
        style={{
          borderColor: `${factionColor}cc`,
          boxShadow: `0 0 0 1px ${hexToRgba(factionColor, 0.2)}, 0 0 24px ${hexToRgba(factionColor, 0.18)}, inset 0 0 30px rgba(15,23,42,0.94)`
        }}
      >
        <div className="absolute inset-3 rounded-full border border-cyan-100/12" />
        <div className="absolute inset-7 rotate-45 rounded-md border border-cyan-100/18 bg-slate-900/70" />
        <div
          className="absolute inset-[2.35rem] rounded-full"
          style={{
            background: `radial-gradient(circle, ${hexToRgba(factionColor, 0.42)}, rgba(15,23,42,0.35) 62%, transparent 72%)`
          }}
        />
        <Network className="relative z-10 text-cyan-50" size={38} strokeWidth={1.45} />
        <span className="absolute left-1/2 top-3 h-4 w-px -translate-x-1/2 bg-cyan-100/28" />
        <span className="absolute bottom-3 left-1/2 h-4 w-px -translate-x-1/2 bg-cyan-100/28" />
        <span className="absolute left-3 top-1/2 h-px w-4 -translate-y-1/2 bg-cyan-100/28" />
        <span className="absolute right-3 top-1/2 h-px w-4 -translate-y-1/2 bg-cyan-100/28" />
      </div>
    </section>
  );
}

function BranchRays({ rays }: { rays: BranchRay[] }) {
  return (
    <svg className="pointer-events-none absolute inset-0 z-[1]" height={boardHeight} viewBox={`0 0 ${boardWidth} ${boardHeight}`} width={boardWidth}>
      {rays.map((ray) => (
        <path
          d={`M ${corePoint.x} ${corePoint.y} L ${ray.endX} ${ray.endY}`}
          fill="none"
          key={ray.branch}
          stroke={ray.color}
          strokeLinecap="round"
          strokeOpacity="0.18"
          strokeWidth="2"
        />
      ))}
    </svg>
  );
}

function BranchChip({ ray }: { ray: BranchRay }) {
  return (
    <div
      className="pointer-events-none absolute z-20 rounded-full border bg-slate-950/72 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.16em]"
      style={{
        borderColor: `${ray.color}38`,
        color: ray.color,
        left: ray.labelX,
        top: ray.labelY
      }}
    >
      {ray.label}
    </div>
  );
}

function ConstellationBackdrop() {
  return (
    <div className="pointer-events-none absolute inset-0 z-0">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_50%,rgba(103,232,249,0.09),transparent_17rem),radial-gradient(circle_at_30%_68%,rgba(192,132,252,0.06),transparent_18rem)]" />
      <div className="absolute inset-0 opacity-25 [background-image:radial-gradient(circle,rgba(148,163,184,0.62)_1px,transparent_1px)] [background-size:56px_56px]" />
    </div>
  );
}

function TechnologyDetailsPanel({
  snapshot,
  node,
  activeResearch,
  currentTechnology,
  rpcReady,
  pending,
  error,
  onCloseNode,
  onResearch
}: {
  snapshot: CampaignSnapshot;
  node: TechnologyNode | null;
  activeResearch: ReturnType<typeof getActiveTechnologyResearch>;
  currentTechnology: number;
  rpcReady: boolean;
  pending: boolean;
  error?: string;
  onCloseNode?: () => void;
  onResearch: (node: TechnologyNode) => void;
}) {
  if (!node) {
    return (
      <aside className="mobile-scroll border-t border-cyan-200/15 bg-slate-950/55 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-4 md:p-5 xl:border-l xl:border-t-0">
        <div className="rounded-md border border-cyan-200/15 bg-slate-950/42 p-4">
          <div className="text-sm font-semibold text-cyan-50">Selecciona una tecnologia</div>
          <p className="mt-2 text-sm leading-6 text-slate-400">
            La constelacion parte del nucleo de tu faccion. Toca un circulo para consultar requisitos, coste y efecto.
          </p>
        </div>
      </aside>
    );
  }

  const status = getTechnologyStatus(snapshot, node);
  const progress = getFactionTechnology(snapshot, node.id);
  const style = getBranchConfig(node.branch);
  const prerequisiteGroups = getPrerequisiteGroups(snapshot, node.id);
  const canResearch =
    status === "available" &&
    !activeResearch &&
    currentTechnology >= node.costTechnology &&
    rpcReady &&
    !pending;

  return (
    <aside className="mobile-scroll max-h-[calc(var(--app-height)-8rem)] border-t border-cyan-200/15 bg-slate-950/88 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-4 md:max-h-[42vh] md:p-5 xl:max-h-none xl:border-l xl:border-t-0">
      <div className="mb-5 rounded-md border border-cyan-200/12 bg-slate-950/38 p-4">
        <div className="flex items-start gap-4">
          <div
            className="grid size-20 shrink-0 place-items-center rounded-full border bg-slate-950/72"
            style={{ borderColor: `${style.color}88` }}
          >
            <TechnologyGlyph className="text-cyan-50" node={node} size={34} strokeWidth={1.65} />
          </div>
          <div className="min-w-0">
            <Badge tone={getStatusTone(status)}>{getStatusLabel(status)}</Badge>
            <h3 className="mt-3 text-2xl font-semibold leading-tight text-cyan-50">{node.name}</h3>
            <div className="mt-2 text-xs uppercase tracking-[0.18em]" style={{ color: style.color }}>
              {node.branch}
            </div>
          </div>
          {onCloseNode ? (
            <Button aria-label="Cerrar detalle" className="ml-auto shrink-0" onClick={onCloseNode} size="icon" variant="ghost">
              <X size={17} />
            </Button>
          ) : null}
        </div>
        <p className="mt-4 text-sm leading-6 text-slate-300">{node.description}</p>
      </div>

      <div className="mb-4 grid grid-cols-2 gap-2">
        <div className="rounded-md border border-cyan-200/12 bg-slate-950/36 p-3">
          <div className="mb-1 text-xs text-slate-400">Coste</div>
          <ResourceAmount
            className={currentTechnology >= node.costTechnology ? "text-cyan-50" : "text-rose-100"}
            resource="technology"
            value={node.costTechnology}
          />
        </div>
        <div className="rounded-md border border-cyan-200/12 bg-slate-950/36 p-3">
          <div className="mb-1 flex items-center gap-2 text-xs text-slate-400">
            <Clock3 size={14} />
            Tiempo
          </div>
          <div className="text-sm font-semibold text-cyan-50">{formatDuration(node.researchTimeSeconds)}</div>
        </div>
      </div>

      {progress?.status === "researching" && progress.finishesAt ? (
        <div className="mb-4 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
          Investigacion activa: {formatCountdown(progress.finishesAt)}
        </div>
      ) : null}

      {activeResearch && activeResearch.technologyNodeId !== node.id ? (
        <div className="mb-4 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
          Ya hay otra investigacion activa.
        </div>
      ) : null}

      {status === "planned" ? (
        <div className="mb-4 rounded-md border border-slate-400/25 bg-slate-400/10 p-3 text-sm text-slate-200">
          Esta rama se muestra para orientar el desarrollo, pero espionaje aun no esta implementado.
        </div>
      ) : null}

      <section className="mb-4">
        <h4 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Efecto</h4>
        <div className="rounded-md border border-cyan-200/12 bg-slate-950/32 p-3 text-sm text-slate-200">
          {node.effectSummary ?? "Sin efecto activo en esta fase."}
        </div>
      </section>

      <section className="mb-4">
        <h4 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Requisitos</h4>
        <div className="space-y-2">
          {prerequisiteGroups.length > 0 ? (
            prerequisiteGroups.map((group) => (
              <div className="rounded-md border border-cyan-200/12 bg-slate-950/32 p-3" key={group.group}>
                {group.nodes.length > 1 ? (
                  <div className="mb-2 text-[11px] uppercase tracking-[0.16em] text-cyan-200/60">
                    Cualquiera de estas tecnologias
                  </div>
                ) : null}
                <div className="space-y-2">
                  {group.nodes.map((prerequisite) => (
                    <div className="flex items-center justify-between gap-3 text-sm" key={prerequisite.id}>
                      <span className="text-slate-200">{prerequisite.name}</span>
                      <Badge tone={getTechnologyStatus(snapshot, prerequisite) === "unlocked" ? "cyan" : "slate"}>
                        {getStatusLabel(getTechnologyStatus(snapshot, prerequisite))}
                      </Badge>
                    </div>
                  ))}
                </div>
              </div>
            ))
          ) : (
            <div className="rounded-md border border-cyan-200/12 bg-slate-950/32 p-3 text-sm text-slate-400">
              Sin requisitos.
            </div>
          )}
        </div>
      </section>

      {!rpcReady ? (
        <div className="mb-3 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
          Supabase no esta configurado.
        </div>
      ) : null}

      {error ? <p className="mb-3 text-sm text-rose-200">{error}</p> : null}

      <Button className="sticky bottom-0 w-full" disabled={!canResearch} onClick={() => onResearch(node)}>
        <Sparkles size={16} />
        {status === "planned" ? "Proximamente" : pending ? "Iniciando..." : "Investigar"}
      </Button>
    </aside>
  );
}

function buildRadialConstellationLayout(nodes: TechnologyNode[], prerequisites: TechnologyPrerequisite[]) {
  const points = new Map<string, TechnologyPoint>();
  const nodesByBranch = new Map<string, TechnologyNode[]>();

  for (const node of nodes) {
    const branchNodes = nodesByBranch.get(node.branch) ?? [];
    branchNodes.push(node);
    nodesByBranch.set(node.branch, branchNodes);
  }

  const sortedBranches = [...nodesByBranch.keys()].sort((left, right) => {
    const leftIndex = branchOrder.indexOf(left);
    const rightIndex = branchOrder.indexOf(right);

    return (leftIndex === -1 ? 999 : leftIndex) - (rightIndex === -1 ? 999 : rightIndex);
  });

  const rays = sortedBranches.map((branch) => {
    const config = getBranchConfig(branch);
    const angle = toRadians(config.angle);
    const direction = { x: Math.cos(angle), y: Math.sin(angle) };
    const perpendicular = { x: -direction.y, y: direction.x };
    const branchNodes = [...(nodesByBranch.get(branch) ?? [])].sort(sortTechnologyNodes);
    const nodesByTier = new Map<number, TechnologyNode[]>();

    for (const node of branchNodes) {
      const tierNodes = nodesByTier.get(node.tier) ?? [];
      tierNodes.push(node);
      nodesByTier.set(node.tier, tierNodes);
    }

    let maxRadius = config.startRadius;

    for (const [tier, tierNodes] of nodesByTier.entries()) {
      tierNodes.sort(sortTechnologyNodes);
      const radius = config.startRadius + Math.max(0, tier) * config.tierGap;
      maxRadius = Math.max(maxRadius, radius);
      const spread = tierNodes.length <= 1 ? 0 : Math.max(74, Math.min(96, 260 / Math.max(3, tierNodes.length)));

      tierNodes.forEach((node, index) => {
        const offset = (index - (tierNodes.length - 1) / 2) * spread;

        points.set(node.id, {
          branch,
          id: node.id,
          x: Math.round(corePoint.x + direction.x * radius + perpendicular.x * offset),
          y: Math.round(corePoint.y + direction.y * radius + perpendicular.y * offset)
        });
      });
    }

    const labelRadius = 126;
    const endRadius = maxRadius + 58;

    return {
      branch,
      color: config.color,
      endX: Math.round(corePoint.x + direction.x * endRadius),
      endY: Math.round(corePoint.y + direction.y * endRadius),
      label: config.label,
      labelX: Math.round(corePoint.x + direction.x * labelRadius - 34),
      labelY: Math.round(corePoint.y + direction.y * labelRadius - 12)
    };
  });

  const nodeById = new Map(nodes.map((node) => [node.id, node]));
  const connections = prerequisites
    .map((prerequisite) => {
      const fromNode = nodeById.get(prerequisite.requiredNodeId);
      const toNode = nodeById.get(prerequisite.technologyNodeId);

      if (!fromNode || !toNode || fromNode.branch !== toNode.branch) {
        return null;
      }

      const from = points.get(fromNode.id);
      const to = points.get(toNode.id);

      return from && to ? { from, to } : null;
    })
    .filter(Boolean) as Array<{ from: TechnologyPoint; to: TechnologyPoint }>;

  return { connections, points, rays };
}

function sortTechnologyNodes(left: TechnologyNode, right: TechnologyNode) {
  if (left.tier !== right.tier) {
    return left.tier - right.tier;
  }

  if (left.positionY !== right.positionY) {
    return left.positionY - right.positionY;
  }

  if (left.positionX !== right.positionX) {
    return left.positionX - right.positionX;
  }

  return left.name.localeCompare(right.name);
}

function getConnectionPath(from: TechnologyPoint, to: TechnologyPoint) {
  const midX = (from.x + to.x) / 2;
  const midY = (from.y + to.y) / 2;
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const bend = Math.min(34, Math.max(12, Math.hypot(dx, dy) * 0.08));
  const normal = { x: -dy / Math.max(1, Math.hypot(dx, dy)), y: dx / Math.max(1, Math.hypot(dx, dy)) };

  return `M ${from.x} ${from.y} Q ${midX + normal.x * bend} ${midY + normal.y * bend} ${to.x} ${to.y}`;
}

function getBranchConfig(branch: string) {
  return branchConfigs[branch] ?? {
    angle: 0,
    color: "#67e8f9",
    label: branch.slice(0, 10),
    mutedColor: "rgba(103,232,249,0.14)",
    startRadius: 140,
    tierGap: 74
  };
}

function TechnologyGlyph({
  node,
  className,
  size,
  strokeWidth
}: {
  node: TechnologyNode;
  className?: string;
  size: number;
  strokeWidth: number;
}) {
  return createElement(getTechnologyIcon(node), {
    "aria-hidden": true,
    className,
    size,
    strokeWidth
  });
}

function getTechnologyIcon(node: TechnologyNode): LucideIcon {
  const bySlug: Record<string, LucideIcon> = {
    "fundacion-planetaria": Landmark,
    "maquinaria-belica": Cog,
    "criadero-guerra": Swords,
    "asamblea-planetaria": Crown,
    "procesado-metalurgico": Factory,
    "cristalizacion-combustible-cuantico": Gem,
    "extraccion-subterranea": Pickaxe,
    "monumentos-gloria": Landmark,
    "fiebre-oro": Banknote,
    "pactos-mercantiles": Handshake,
    "contactos-economicos": Store,
    "tratos-preferentes": BadgePercent,
    "mercado-galactico": Network,
    "aranceles-privilegiados": BadgePercent,
    "oficina-inteligencia": Eye,
    "celulas-informacion": Network,
    "doctrina-clandestina": Eye,
    "doble-agente": Users,
    "tecnologia-sar": Radar,
    "entrenamiento-linea": Users,
    "logistica-frente": Truck,
    "cadenas-mando": RadioTower,
    "veteranos-guerra": Medal,
    "especializacion-elite": Shield,
    "motores-guerra": Cog,
    "blindaje-reforzado": Shield,
    "matrices-eficiencia": BrainCog
  };
  const byIconKey: Record<string, LucideIcon> = {
    beast: Swords,
    cells: Network,
    command: Crown,
    commerce: Handshake,
    factory: Factory,
    foundation: Landmark,
    gold: Banknote,
    honor: Landmark,
    infantry: Users,
    intelligence: Eye,
    market: Store,
    matrix: BrainCog,
    merchant: Store,
    mine: Pickaxe,
    radar: Radar,
    supply: Package,
    tariff: BadgePercent,
    trade_discount: BadgePercent,
    uridium: Gem,
    vehicle: Cog,
    war_machine: Hammer
  };

  return bySlug[node.slug] ?? (node.iconKey ? byIconKey[node.iconKey] : null) ?? Boxes;
}

function getStatusLabel(status: DerivedTechnologyStatus) {
  const labels: Record<DerivedTechnologyStatus, string> = {
    locked: "Bloqueada",
    planned: "Proximamente",
    available: "Disponible",
    researching: "Investigando",
    unlocked: "Desbloqueada"
  };

  return labels[status];
}

function getStatusTone(status: DerivedTechnologyStatus): "cyan" | "rose" | "amber" | "slate" | "violet" {
  if (status === "unlocked") {
    return "cyan";
  }

  if (status === "researching") {
    return "amber";
  }

  if (status === "available") {
    return "violet";
  }

  return "slate";
}

function formatDuration(seconds: number) {
  if (seconds <= 0) {
    return "Instantaneo";
  }

  if (seconds < 60) {
    return `${seconds}s`;
  }

  const minutes = Math.ceil(seconds / 60);
  return `${minutes}m`;
}

function getPrerequisiteGroups(snapshot: CampaignSnapshot, technologyNodeId: string) {
  const groups = new Map<number, TechnologyNode[]>();

  for (const prerequisite of snapshot.technologyPrerequisites.filter((item) => item.technologyNodeId === technologyNodeId)) {
    const node = snapshot.technologyNodes.find((candidate) => candidate.id === prerequisite.requiredNodeId);

    if (!node || !isTechnologyNodeVisible(node)) {
      continue;
    }

    const group = groups.get(prerequisite.prerequisiteGroup) ?? [];
    group.push(node);
    groups.set(prerequisite.prerequisiteGroup, group);
  }

  return [...groups.entries()]
    .sort(([left], [right]) => left - right)
    .map(([group, nodes]) => ({ group, nodes }));
}

function hexToRgba(hex: string, alpha: number) {
  const normalized = hex.replace("#", "");

  if (normalized.length !== 6) {
    return `rgba(103,232,249,${alpha})`;
  }

  const value = Number.parseInt(normalized, 16);
  const red = (value >> 16) & 255;
  const green = (value >> 8) & 255;
  const blue = value & 255;

  return `rgba(${red},${green},${blue},${alpha})`;
}

function toRadians(degrees: number) {
  return (degrees * Math.PI) / 180;
}
