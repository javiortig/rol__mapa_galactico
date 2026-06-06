"use client";

import Image from "next/image";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Check, Clock3, Crosshair, Lock, Minus, Plus, Sparkles, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceAmount } from "@/components/ui/resource-icon";
import { canUseTechnologyRpc, startTechnologyResearch } from "@/features/technology/api/technology-api";
import {
  getActiveTechnologyResearch,
  getFactionTechnology,
  getTechnologyStatus,
  type DerivedTechnologyStatus
} from "@/features/technology/lib/technology-state";
import { cn } from "@/lib/utils";
import { formatCountdown } from "@/lib/time";
import { useMediaQuery } from "@/lib/use-media-query";
import type { CampaignSnapshot, TechnologyNode } from "@/domain/campaign";

type BranchStyle = {
  color: string;
  glow: string;
  labelX: number;
  labelY: number;
};

const branchStyles: Record<string, BranchStyle> = {
  "Mando y doctrina": { color: "#38bdf8", glow: "rgba(56,189,248,0.24)", labelX: 18, labelY: 21 },
  "Infanteria y elite": { color: "#facc15", glow: "rgba(250,204,21,0.22)", labelX: 10, labelY: 84 },
  "Blindados y maquinas": { color: "#fb923c", glow: "rgba(251,146,60,0.24)", labelX: 72, labelY: 84 },
  Infraestructura: { color: "#34d399", glow: "rgba(52,211,153,0.22)", labelX: 77, labelY: 22 },
  Arqueotecnologia: { color: "#c084fc", glow: "rgba(192,132,252,0.24)", labelX: 47, labelY: 92 }
};

const treeWidth = 1560;
const treeHeight = 980;

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
  const treeViewportRef = useRef<HTMLDivElement | null>(null);
  const isNarrowTechnology = useMediaQuery("(max-width: 430px)");
  const isTechnologyDesktop = useMediaQuery("(min-width: 1024px)");
  const isMobile = !isTechnologyDesktop;
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [hoveredNodeId, setHoveredNodeId] = useState<string | null>(null);
  const [treeZoom, setTreeZoom] = useState<number | null>(null);
  const currentResources = snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
  const activeResearch = getActiveTechnologyResearch(snapshot);
  const centerNode =
    snapshot.technologyNodes.find((node) => node.slug === "doctrina-campana") ??
    snapshot.technologyNodes.find((node) => node.isStarter) ??
    snapshot.technologyNodes.find((node) => getTechnologyStatus(snapshot, node) === "available") ??
    snapshot.technologyNodes[0] ??
    null;
  const selectedNode = selectedNodeId ? snapshot.technologyNodes.find((node) => node.id === selectedNodeId) ?? null : null;
  const focusNodeId = hoveredNodeId ?? selectedNode?.id ?? null;
  const defaultTreeZoom = isTechnologyDesktop ? 0.9 : isNarrowTechnology ? 0.62 : 0.74;
  const currentTreeZoom = treeZoom ?? defaultTreeZoom;
  const relatedNodeIds = useMemo(
    () => (focusNodeId ? getRelatedNodeIds(snapshot, focusNodeId) : new Set<string>()),
    [focusNodeId, snapshot]
  );
  const nodeById = useMemo(
    () => new Map(snapshot.technologyNodes.map((node) => [node.id, node])),
    [snapshot.technologyNodes]
  );
  const hoveredNode = hoveredNodeId ? nodeById.get(hoveredNodeId) ?? null : null;
  const rpcReady = canUseTechnologyRpc();
  const mutation = useMutation({
    mutationFn: (technologyNodeId: string) => startTechnologyResearch(technologyNodeId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const centerTechnologyTree = useCallback((behavior: ScrollBehavior = "auto") => {
    const viewport = treeViewportRef.current;

    if (!viewport || !centerNode) {
      return;
    }

    const point = getNodePoint(centerNode);
    viewport.scrollTo({
      behavior,
      left: Math.max(0, point.x * currentTreeZoom - viewport.clientWidth / 2),
      top: Math.max(0, point.y * currentTreeZoom - viewport.clientHeight / 2)
    });
  }, [centerNode, currentTreeZoom]);

  useEffect(() => {
    if (!open) {
      return;
    }

    const frame = window.requestAnimationFrame(() => centerTechnologyTree("auto"));
    return () => window.cancelAnimationFrame(frame);
  }, [centerTechnologyTree, open]);

  const handleClose = () => {
    setSelectedNodeId(null);
    setHoveredNodeId(null);
    setTreeZoom(null);
    onClose();
  };

  if (!open) {
    return null;
  }

  return (
    <div className="pointer-events-auto fixed inset-0 z-50 grid place-items-center bg-black/78 p-0 backdrop-blur-md md:p-3">
      <Panel className="flex h-[var(--app-height)] w-full max-w-none flex-col overflow-hidden rounded-none border-cyan-200/20 shadow-[0_0_70px_rgba(8,145,178,0.18)] md:h-[96vh] md:w-[98vw] md:rounded-lg">
        <header className="flex items-center justify-between gap-4 border-b border-cyan-200/15 bg-slate-950/65 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:px-5 md:py-4">
          <div>
            <div className="text-xs uppercase tracking-[0.24em] text-cyan-200/70">Arbol tecnologico</div>
            <h2 className="mt-1 text-xl font-semibold text-cyan-50 md:text-2xl">Constelacion doctrinal</h2>
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

        <div className="grid min-h-0 flex-1 grid-rows-[minmax(0,1fr)_auto] overflow-hidden md:grid-rows-[minmax(0,1fr)_auto] xl:grid-cols-[minmax(0,1fr)_420px] xl:grid-rows-none">
          <div className="relative min-h-0 overflow-hidden bg-[radial-gradient(circle_at_18%_22%,rgba(14,165,233,0.18),transparent_26%),radial-gradient(circle_at_78%_64%,rgba(192,132,252,0.14),transparent_34%),linear-gradient(180deg,rgba(2,6,23,0.98),rgba(8,13,31,0.98))]">
            <div className="tech-scroll h-full p-3" ref={treeViewportRef}>
              <div
                className="relative"
                style={{ height: treeHeight * currentTreeZoom, width: treeWidth * currentTreeZoom }}
              >
                <div
                  className="relative origin-top-left overflow-hidden rounded border border-cyan-200/10 bg-slate-950/40 shadow-[inset_0_0_130px_rgba(8,145,178,0.11)]"
                  style={{
                    height: treeHeight,
                    transform: `scale(${currentTreeZoom})`,
                    transformOrigin: "top left",
                    width: treeWidth
                  }}
                >
                  <ConstellationBackdrop />
                  <BranchConstellations branches={[...new Set(snapshot.technologyNodes.map((node) => node.branch))]} />
                  <TechnologyConnections
                    focusNodeId={focusNodeId}
                    nodeById={nodeById}
                    relatedNodeIds={relatedNodeIds}
                    snapshot={snapshot}
                  />

                  {snapshot.technologyNodes.map((node) => (
                    <TechnologyNodeOrb
                      focused={Boolean(focusNodeId && relatedNodeIds.has(node.id))}
                      key={node.id}
                      muted={Boolean(focusNodeId && !relatedNodeIds.has(node.id))}
                      node={node}
                      onHoverChange={(hovered) => setHoveredNodeId(hovered ? node.id : null)}
                      onSelect={() => setSelectedNodeId(node.id)}
                      selected={selectedNode?.id === node.id}
                      status={getTechnologyStatus(snapshot, node)}
                    />
                  ))}

                  {hoveredNode ? <TechnologyTooltip node={hoveredNode} snapshot={snapshot} /> : null}
                  <TechnologyLegend />
                </div>
              </div>
            </div>
            <TechnologyZoomControls
              onCenter={() => centerTechnologyTree("smooth")}
              onZoomIn={() => setTreeZoom(clampNumber(currentTreeZoom + 0.08, 0.5, 1.08))}
              onZoomOut={() => setTreeZoom(clampNumber(currentTreeZoom - 0.08, 0.5, 1.08))}
              zoom={currentTreeZoom}
            />
          </div>

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

function ConstellationBackdrop() {
  return (
    <div className="pointer-events-none absolute inset-0">
      <div className="absolute inset-0 opacity-45 [background-image:radial-gradient(circle,rgba(148,163,184,0.55)_1px,transparent_1px)] [background-size:34px_34px]" />
      <div className="absolute inset-0 opacity-30 [background-image:linear-gradient(rgba(103,232,249,0.09)_1px,transparent_1px),linear-gradient(90deg,rgba(103,232,249,0.08)_1px,transparent_1px)] [background-size:120px_120px]" />
    </div>
  );
}

function BranchConstellations({ branches }: { branches: string[] }) {
  return (
    <div className="pointer-events-none absolute inset-0 z-0">
      {branches.map((branch) => {
        const style = getBranchStyle(branch);

        return (
          <div
            className="absolute rounded-full border border-white/5 px-3 py-2 text-xs uppercase tracking-[0.2em] text-slate-300"
            key={branch}
            style={{
              background: `linear-gradient(90deg, ${style.glow}, rgba(15,23,42,0.18))`,
              boxShadow: `0 0 42px ${style.glow}`,
              color: style.color,
              left: `${style.labelX}%`,
              top: `${style.labelY}%`
            }}
          >
            {branch}
          </div>
        );
      })}
    </div>
  );
}

function TechnologyConnections({
  snapshot,
  nodeById,
  focusNodeId,
  relatedNodeIds
}: {
  snapshot: CampaignSnapshot;
  nodeById: Map<string, TechnologyNode>;
  focusNodeId: string | null;
  relatedNodeIds: Set<string>;
}) {
  return (
    <svg
      className="pointer-events-none absolute inset-0 z-[1]"
      height={treeHeight}
      viewBox={`0 0 ${treeWidth} ${treeHeight}`}
      width={treeWidth}
    >
      <defs>
        <filter id="tech-connection-glow">
          <feGaussianBlur result="blur" stdDeviation="4" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>
      {snapshot.technologyPrerequisites.map((prerequisite) => {
        const from = nodeById.get(prerequisite.requiredNodeId);
        const to = nodeById.get(prerequisite.technologyNodeId);

        if (!from || !to) {
          return null;
        }

        const status = getTechnologyStatus(snapshot, to);
        const toStyle = getBranchStyle(to.branch);
        const related = !focusNodeId || (relatedNodeIds.has(from.id) && relatedNodeIds.has(to.id));
        const color = status === "locked" ? "rgba(100,116,139,0.38)" : toStyle.color;
        const path = getConnectionPath(from, to);

        return (
          <g key={`${prerequisite.requiredNodeId}-${prerequisite.technologyNodeId}`} opacity={related ? 1 : 0.16}>
            <path d={path} fill="none" stroke={toStyle.color} strokeLinecap="round" strokeOpacity={0.16} strokeWidth={12} />
            <path
              d={path}
              fill="none"
              filter={status === "locked" ? undefined : "url(#tech-connection-glow)"}
              stroke={color}
              strokeDasharray={status === "locked" ? "14 14" : undefined}
              strokeLinecap="round"
              strokeOpacity={status === "locked" ? 0.45 : 0.82}
              strokeWidth={status === "researching" ? 5 : 3}
            />
          </g>
        );
      })}
    </svg>
  );
}

function TechnologyNodeOrb({
  node,
  status,
  selected,
  focused,
  muted,
  onSelect,
  onHoverChange
}: {
  node: TechnologyNode;
  status: DerivedTechnologyStatus;
  selected: boolean;
  focused: boolean;
  muted: boolean;
  onSelect: () => void;
  onHoverChange: (hovered: boolean) => void;
}) {
  const style = getBranchStyle(node.branch);
  const point = getNodePoint(node);
  const locked = status === "locked";
  const researching = status === "researching";
  const unlocked = status === "unlocked";
  const available = status === "available";

  return (
    <button
      aria-label={node.name}
      className={cn(
        "absolute z-10 grid size-24 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full transition duration-200 hover:scale-110 focus:outline-none",
        selected && "scale-110",
        focused && "scale-105",
        muted && "opacity-25 grayscale"
      )}
      onClick={onSelect}
      onMouseEnter={() => onHoverChange(true)}
      onMouseLeave={() => onHoverChange(false)}
      style={{
        left: point.x,
        top: point.y
      }}
      type="button"
    >
      <span
        className={cn(
          "absolute inset-0 rounded-full border bg-slate-950/70",
          researching && "animate-pulse",
          selected && "ring-2 ring-cyan-100/70",
          available && "border-cyan-100/70",
          unlocked && "border-emerald-100/70",
          locked && "border-slate-500/30"
        )}
        style={{
          boxShadow: locked
            ? "inset 0 0 24px rgba(15,23,42,0.8)"
            : `0 0 34px ${style.glow}, inset 0 0 26px rgba(15,23,42,0.86)`
        }}
      />
      <span
        className="absolute inset-2 rounded-full border border-white/10"
        style={{ borderColor: locked ? "rgba(100,116,139,0.3)" : style.color }}
      />
      <TechnologyIconImage
        className={cn("relative z-10 size-[78px] object-contain drop-shadow-[0_0_12px_rgba(103,232,249,0.32)]", locked && "opacity-45")}
        node={node}
        size={96}
      />
      <span className="absolute right-0 top-0 z-20 grid size-7 place-items-center rounded-full border border-slate-950 bg-slate-950/92">
        {locked ? (
          <Lock className="text-slate-400" size={15} />
        ) : unlocked ? (
          <Check className="text-emerald-200" size={16} />
        ) : researching ? (
          <Sparkles className="text-amber-200" size={15} />
        ) : (
          <Sparkles className="text-cyan-100" size={15} />
        )}
      </span>
      {(selected || node.isStarter) && (
        <span
          className="absolute left-1/2 top-[104%] z-20 max-w-36 -translate-x-1/2 whitespace-nowrap rounded border border-cyan-100/15 bg-slate-950/82 px-2 py-1 text-[11px] font-medium text-cyan-50 shadow-lg"
          style={{ color: locked ? "#94a3b8" : style.color }}
        >
          {node.name}
        </span>
      )}
    </button>
  );
}

function TechnologyTooltip({ node, snapshot }: { node: TechnologyNode; snapshot: CampaignSnapshot }) {
  const point = getNodePoint(node);
  const status = getTechnologyStatus(snapshot, node);
  const style = getBranchStyle(node.branch);

  return (
    <div
      className="pointer-events-none absolute z-30 w-64 rounded-md border bg-slate-950/94 p-3 text-sm shadow-2xl backdrop-blur"
      style={{
        borderColor: `${style.color}66`,
        boxShadow: `0 0 28px ${style.glow}`,
        left: Math.min(point.x + 58, treeWidth - 300),
        top: Math.max(16, point.y - 64)
      }}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="font-semibold text-cyan-50">{node.name}</span>
        <Badge tone={getStatusTone(status)}>{getStatusLabel(status)}</Badge>
      </div>
      <p className="mt-2 line-clamp-2 text-xs leading-5 text-slate-300">{node.effectSummary ?? node.description}</p>
    </div>
  );
}

function TechnologyLegend() {
  const items: Array<{ label: string; tone: string; className: string }> = [
    { label: "Disponible", tone: "cyan", className: "border-cyan-200 bg-cyan-300/20" },
    { label: "Investigando", tone: "amber", className: "border-amber-200 bg-amber-300/20" },
    { label: "Desbloqueada", tone: "emerald", className: "border-emerald-200 bg-emerald-300/20" },
    { label: "Bloqueada", tone: "slate", className: "border-slate-500 bg-slate-700/20" }
  ];

  return (
    <div className="absolute bottom-4 left-4 z-20 flex flex-wrap gap-2 rounded-md border border-cyan-200/10 bg-slate-950/72 p-2 text-xs text-slate-300 backdrop-blur">
      {items.map((item) => (
        <span className="inline-flex items-center gap-2 px-2 py-1" key={item.label}>
          <span className={cn("size-3 rounded-full border", item.className)} />
          {item.label}
        </span>
      ))}
    </div>
  );
}

function TechnologyZoomControls({
  zoom,
  onZoomIn,
  onZoomOut,
  onCenter
}: {
  zoom: number;
  onZoomIn: () => void;
  onZoomOut: () => void;
  onCenter: () => void;
}) {
  return (
    <div className="pointer-events-auto absolute right-3 top-3 z-30 flex items-center gap-1.5 rounded-md border border-cyan-200/15 bg-slate-950/78 p-1.5 shadow-[0_0_24px_rgba(8,145,178,0.16)] backdrop-blur">
      <Button aria-label="Alejar arbol" onClick={onZoomOut} size="icon" variant="ghost">
        <Minus size={15} />
      </Button>
      <div className="min-w-12 text-center text-xs font-semibold tabular-nums text-cyan-50">
        {Math.round(zoom * 100)}%
      </div>
      <Button aria-label="Acercar arbol" onClick={onZoomIn} size="icon" variant="ghost">
        <Plus size={15} />
      </Button>
      <Button aria-label="Centrar arbol" onClick={onCenter} size="icon" variant="ghost">
        <Crosshair size={15} />
      </Button>
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
            El arbol se abre centrado en la doctrina principal. Toca un nodo para consultar requisitos, coste y efecto.
          </p>
        </div>
      </aside>
    );
  }

  const status = getTechnologyStatus(snapshot, node);
  const progress = getFactionTechnology(snapshot, node.id);
  const style = getBranchStyle(node.branch);
  const prerequisites = snapshot.technologyPrerequisites
    .filter((item) => item.technologyNodeId === node.id)
    .map((item) => snapshot.technologyNodes.find((candidate) => candidate.id === item.requiredNodeId))
    .filter(Boolean) as TechnologyNode[];
  const canResearch =
    status === "available" &&
    !activeResearch &&
    currentTechnology >= node.costTechnology &&
    rpcReady &&
    !pending;

  return (
    <aside className="mobile-scroll max-h-[calc(var(--app-height)-8rem)] border-t border-cyan-200/15 bg-slate-950/86 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-4 md:max-h-[42vh] md:p-5 xl:max-h-none xl:border-l xl:border-t-0">
      <div className="mb-5 rounded-md border border-cyan-200/15 bg-slate-950/42 p-4">
        <div className="flex items-start gap-4">
          <div
            className="grid size-28 shrink-0 place-items-center rounded-full border bg-slate-950/70"
            style={{ borderColor: `${style.color}99`, boxShadow: `0 0 34px ${style.glow}` }}
          >
            <TechnologyIconImage className="size-24 object-contain" node={node} size={112} />
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
        <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3">
          <div className="mb-1 text-xs text-slate-400">Coste</div>
          <ResourceAmount
            className={currentTechnology >= node.costTechnology ? "text-cyan-50" : "text-rose-100"}
            resource="technology"
            value={node.costTechnology}
          />
        </div>
        <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3">
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

      <section className="mb-4">
        <h4 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Efecto</h4>
        <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-200">
          {node.effectSummary ?? "Sin efecto activo en esta fase."}
        </div>
      </section>

      <section className="mb-4">
        <h4 className="mb-2 text-xs uppercase tracking-[0.18em] text-cyan-200/70">Requisitos</h4>
        <div className="space-y-2">
          {prerequisites.length > 0 ? (
            prerequisites.map((prerequisite) => (
              <div
                className="flex items-center justify-between gap-3 rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm"
                key={prerequisite.id}
              >
                <span className="text-slate-200">{prerequisite.name}</span>
                <Badge tone={getTechnologyStatus(snapshot, prerequisite) === "unlocked" ? "cyan" : "slate"}>
                  {getStatusLabel(getTechnologyStatus(snapshot, prerequisite))}
                </Badge>
              </div>
            ))
          ) : (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
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
        {pending ? "Iniciando..." : "Investigar"}
      </Button>
    </aside>
  );
}

function getConnectionPath(from: TechnologyNode, to: TechnologyNode) {
  const fromPoint = getNodePoint(from);
  const toPoint = getNodePoint(to);
  const dx = toPoint.x - fromPoint.x;
  const dy = toPoint.y - fromPoint.y;
  const curve = Math.min(160, Math.max(70, Math.abs(dx) * 0.32 + Math.abs(dy) * 0.18));
  const c1 = { x: fromPoint.x + dx * 0.36, y: fromPoint.y + dy * 0.08 - curve * Math.sign(dx || 1) * 0.12 };
  const c2 = { x: fromPoint.x + dx * 0.68, y: fromPoint.y + dy * 0.92 + curve * Math.sign(dy || 1) * 0.08 };

  return `M ${fromPoint.x} ${fromPoint.y} C ${c1.x} ${c1.y}, ${c2.x} ${c2.y}, ${toPoint.x} ${toPoint.y}`;
}

function getNodePoint(node: TechnologyNode) {
  return {
    x: Math.round((node.positionX / 100) * treeWidth),
    y: Math.round((node.positionY / 100) * treeHeight)
  };
}

function getRelatedNodeIds(snapshot: CampaignSnapshot, nodeId: string) {
  const related = new Set<string>([nodeId]);

  for (const prerequisite of snapshot.technologyPrerequisites) {
    if (prerequisite.technologyNodeId === nodeId) {
      related.add(prerequisite.requiredNodeId);
    }

    if (prerequisite.requiredNodeId === nodeId) {
      related.add(prerequisite.technologyNodeId);
    }
  }

  return related;
}

function getBranchStyle(branch: string) {
  return branchStyles[branch] ?? branchStyles["Mando y doctrina"];
}

function getTechnologyIconSrc(node: TechnologyNode) {
  return `/tech-icons/common-v1/${node.slug}.png`;
}

function TechnologyIconImage({
  node,
  className,
  size
}: {
  node: TechnologyNode;
  className?: string;
  size: number;
}) {
  const [fallback, setFallback] = useState(false);

  return (
    <Image
      alt=""
      className={className}
      height={size}
      onError={() => setFallback(true)}
      src={fallback ? "/tech-icons/common-v1/fallback.png" : getTechnologyIconSrc(node)}
      width={size}
    />
  );
}

function getStatusLabel(status: DerivedTechnologyStatus) {
  const labels: Record<DerivedTechnologyStatus, string> = {
    locked: "Bloqueada",
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

  const minutes = Math.ceil(seconds / 60);
  return `${minutes}m`;
}

function clampNumber(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}
