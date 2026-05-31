"use client";

import { useMemo, useState } from "react";
import type { ReactNode } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Check, Clock3, Cpu, Factory, FlaskConical, Lock, RadioTower, Shield, Sparkles, Swords, X } from "lucide-react";
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
import { formatCountdown } from "@/lib/time";
import type { CampaignSnapshot, TechnologyNode } from "@/domain/campaign";

const branchStyles: Record<string, { color: string; soft: string; icon: ReactNode }> = {
  "Mando y doctrina": { color: "#38bdf8", soft: "rgba(56,189,248,0.14)", icon: <RadioTower size={18} /> },
  "Infanteria y elite": { color: "#facc15", soft: "rgba(250,204,21,0.14)", icon: <Swords size={18} /> },
  "Blindados y maquinas": { color: "#fb923c", soft: "rgba(251,146,60,0.14)", icon: <Shield size={18} /> },
  Infraestructura: { color: "#34d399", soft: "rgba(52,211,153,0.14)", icon: <Factory size={18} /> },
  Arqueotecnologia: { color: "#c084fc", soft: "rgba(192,132,252,0.14)", icon: <FlaskConical size={18} /> }
};

const treeWidth = 1680;
const treeHeight = 900;

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
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const currentResources = snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
  const activeResearch = getActiveTechnologyResearch(snapshot);
  const selectedNode =
    snapshot.technologyNodes.find((node) => node.id === selectedNodeId) ??
    snapshot.technologyNodes.find((node) => getTechnologyStatus(snapshot, node) === "available") ??
    snapshot.technologyNodes[0] ??
    null;
  const rpcReady = canUseTechnologyRpc();
  const mutation = useMutation({
    mutationFn: (technologyNodeId: string) => startTechnologyResearch(technologyNodeId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const nodeById = useMemo(
    () => new Map(snapshot.technologyNodes.map((node) => [node.id, node])),
    [snapshot.technologyNodes]
  );

  if (!open) {
    return null;
  }

  return (
    <div className="pointer-events-auto fixed inset-0 z-50 grid place-items-center bg-black/76 p-2 backdrop-blur-md md:p-3">
      <Panel className="flex h-[96vh] w-[98vw] max-w-none flex-col overflow-hidden border-cyan-200/20 shadow-[0_0_70px_rgba(8,145,178,0.18)]">
        <div className="flex items-center justify-between gap-4 border-b border-cyan-200/15 bg-slate-950/60 px-5 py-4">
          <div>
            <div className="text-xs uppercase tracking-[0.24em] text-cyan-200/70">Arbol tecnologico</div>
            <h2 className="mt-1 text-2xl font-semibold text-cyan-50">Doctrinas de campana</h2>
          </div>
          <div className="flex items-center gap-3">
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 px-3 py-2">
              <ResourceAmount resource="technology" value={currentResources?.technology ?? 0} />
            </div>
            <Button aria-label="Cerrar tecnologia" onClick={onClose} size="icon" variant="ghost">
              <X size={18} />
            </Button>
          </div>
        </div>

        <div className="grid min-h-0 flex-1 overflow-hidden xl:grid-cols-[minmax(0,1fr)_420px]">
          <div className="relative min-h-0 overflow-auto bg-[radial-gradient(circle_at_18%_18%,rgba(14,165,233,0.18),transparent_28%),radial-gradient(circle_at_74%_68%,rgba(192,132,252,0.14),transparent_34%),linear-gradient(180deg,rgba(2,6,23,0.98),rgba(8,13,31,0.98))] p-3">
            <div
              className="relative overflow-hidden rounded border border-cyan-200/10 bg-slate-950/38 shadow-[inset_0_0_120px_rgba(8,145,178,0.10)]"
              style={{ height: treeHeight, width: treeWidth }}
            >
              <BranchLanes branches={[...new Set(snapshot.technologyNodes.map((node) => node.branch))]} />
              <TechnologyConnections snapshot={snapshot} nodeById={nodeById} />

              {snapshot.technologyNodes.map((node) => (
                <TechnologyNodeButton
                  key={node.id}
                  node={node}
                  onSelect={() => setSelectedNodeId(node.id)}
                  selected={selectedNode?.id === node.id}
                  status={getTechnologyStatus(snapshot, node)}
                />
              ))}
            </div>
          </div>

          <TechnologyDetailsPanel
            activeResearch={activeResearch}
            currentTechnology={currentResources?.technology ?? 0}
            error={mutation.error?.message}
            node={selectedNode}
            onResearch={(node) => mutation.mutate(node.id)}
            pending={mutation.isPending}
            rpcReady={rpcReady}
            snapshot={snapshot}
          />
        </div>
      </Panel>
    </div>
  );
}

function BranchLanes({ branches }: { branches: string[] }) {
  return (
    <div className="pointer-events-none absolute inset-0 z-0">
      {branches.map((branch) => {
        const style = branchStyles[branch] ?? branchStyles["Mando y doctrina"];
        const top = getBranchTop(branch);

        return (
          <div
            className="absolute left-0 right-0 h-32 border-y border-white/5"
            key={branch}
            style={{ top, background: `linear-gradient(90deg, ${style.soft}, transparent 48%)` }}
          >
            <div className="ml-6 mt-3 inline-flex items-center gap-2 rounded border border-white/5 bg-slate-950/35 px-3 py-2 text-xs uppercase tracking-[0.2em] text-slate-300">
              <span style={{ color: style.color }}>{style.icon}</span>
              {branch}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function TechnologyConnections({
  snapshot,
  nodeById
}: {
  snapshot: CampaignSnapshot;
  nodeById: Map<string, TechnologyNode>;
}) {
  return (
    <svg
      className="pointer-events-none absolute inset-0 z-[1]"
      height={treeHeight}
      viewBox={`0 0 ${treeWidth} ${treeHeight}`}
      width={treeWidth}
    >
      {snapshot.technologyPrerequisites.map((prerequisite) => {
        const from = nodeById.get(prerequisite.requiredNodeId);
        const to = nodeById.get(prerequisite.technologyNodeId);

        if (!from || !to) {
          return null;
        }

        const status = getTechnologyStatus(snapshot, to);
        const color = status === "locked" ? "rgba(148,163,184,0.22)" : "rgba(103,232,249,0.58)";
        const fromPoint = getNodePoint(from);
        const toPoint = getNodePoint(to);
        const midX = fromPoint.x + (toPoint.x - fromPoint.x) * 0.52;

        return (
          <path
            d={`M ${fromPoint.x} ${fromPoint.y} C ${midX} ${fromPoint.y}, ${midX} ${toPoint.y}, ${toPoint.x} ${toPoint.y}`}
            key={`${prerequisite.requiredNodeId}-${prerequisite.technologyNodeId}`}
            fill="none"
            stroke={color}
            strokeLinecap="round"
            strokeWidth={status === "researching" ? 5 : 3}
          />
        );
      })}
    </svg>
  );
}

function TechnologyNodeButton({
  node,
  selected,
  status,
  onSelect
}: {
  node: TechnologyNode;
  selected: boolean;
  status: DerivedTechnologyStatus;
  onSelect: () => void;
}) {
  const style = branchStyles[node.branch] ?? branchStyles["Mando y doctrina"];
  const point = getNodePoint(node);
  const statusClass = {
    locked: "border-slate-500/20 bg-slate-950/80 text-slate-500",
    available: "border-cyan-200/45 bg-cyan-300/12 text-cyan-50 shadow-[0_0_22px_rgba(34,211,238,0.12)]",
    researching: "border-amber-200/55 bg-amber-300/14 text-amber-50 shadow-[0_0_24px_rgba(251,191,36,0.16)]",
    unlocked: "border-emerald-200/50 bg-emerald-300/12 text-emerald-50 shadow-[0_0_22px_rgba(52,211,153,0.14)]"
  }[status];

  return (
    <button
      className={`absolute z-10 w-44 -translate-x-1/2 -translate-y-1/2 rounded-md border p-3 text-left transition hover:scale-[1.03] ${statusClass} ${
        selected ? "ring-2 ring-cyan-200/60" : ""
      }`}
      onClick={onSelect}
      style={{ left: point.x, top: point.y }}
      type="button"
    >
      <div className="mb-2 flex items-center justify-between gap-2">
        <span className="grid size-8 place-items-center rounded border border-white/10" style={{ color: style.color }}>
          {getNodeIcon(node.iconKey)}
        </span>
        {status === "locked" ? <Lock size={15} /> : status === "unlocked" ? <Check size={15} /> : <Cpu size={15} />}
      </div>
      <div className="text-sm font-semibold leading-tight">{node.name}</div>
      <div className="mt-1 text-[11px] text-slate-400">Tier {node.tier}</div>
    </button>
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
  onResearch
}: {
  snapshot: CampaignSnapshot;
  node: TechnologyNode | null;
  activeResearch: ReturnType<typeof getActiveTechnologyResearch>;
  currentTechnology: number;
  rpcReady: boolean;
  pending: boolean;
  error?: string;
  onResearch: (node: TechnologyNode) => void;
}) {
  if (!node) {
    return (
      <aside className="border-t border-cyan-200/15 bg-slate-950/55 p-5 lg:border-l lg:border-t-0">
        <p className="text-sm text-slate-400">No hay tecnologias definidas.</p>
      </aside>
    );
  }

  const status = getTechnologyStatus(snapshot, node);
  const progress = getFactionTechnology(snapshot, node.id);
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
    <aside className="min-h-0 overflow-y-auto border-t border-cyan-200/15 bg-slate-950/55 p-5 lg:border-l lg:border-t-0">
      <div className="mb-4 flex items-start justify-between gap-3">
        <div>
          <Badge tone={getStatusTone(status)}>{getStatusLabel(status)}</Badge>
          <h3 className="mt-3 text-2xl font-semibold text-cyan-50">{node.name}</h3>
          <p className="mt-2 text-sm leading-6 text-slate-300">{node.description}</p>
        </div>
        <span className="grid size-12 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
          {getNodeIcon(node.iconKey)}
        </span>
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
              <div className="flex items-center justify-between rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm" key={prerequisite.id}>
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

      <Button className="w-full" disabled={!canResearch} onClick={() => onResearch(node)}>
        <Sparkles size={16} />
        {pending ? "Iniciando..." : "Investigar"}
      </Button>
    </aside>
  );
}

function getBranchTop(branch: string) {
  const positions: Record<string, number> = {
    "Mando y doctrina": 52,
    "Infanteria y elite": 225,
    "Blindados y maquinas": 369,
    Infraestructura: 513,
    Arqueotecnologia: 675
  };

  return positions[branch] ?? 52;
}

function getNodePoint(node: TechnologyNode) {
  return {
    x: Math.round((node.positionX / 100) * treeWidth),
    y: Math.round((node.positionY / 100) * treeHeight)
  };
}

function getNodeIcon(iconKey?: string | null) {
  if (iconKey === "factory" || iconKey === "forge" || iconKey === "infrastructure") {
    return <Factory size={18} />;
  }

  if (iconKey === "elite" || iconKey === "vehicle" || iconKey === "arsenal") {
    return <Swords size={18} />;
  }

  if (iconKey === "auspex" || iconKey === "data" || iconKey === "matrix" || iconKey === "cipher") {
    return <FlaskConical size={18} />;
  }

  return <Cpu size={18} />;
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
