import { memo, type ReactNode } from "react";
import { BarChart3, Cpu, Factory, Swords } from "lucide-react";
import { Panel } from "@/components/ui/panel";
import { ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import type { CampaignSnapshot, ResourceBundle, ResourceKey } from "@/domain/campaign";
import { getLivingUnitPoints, getQueuedRecruitmentPoints } from "@/features/units/lib/army-points";

const economicResourceKeys = [
  "supply",
  "minerals",
  "honor",
  "gold",
  "industrialMaterial",
  "uridium"
] as const satisfies readonly ResourceKey[];

type FactionSummary = {
  faction: CampaignSnapshot["factions"][number];
  resources: ResourceBundle;
  dailyProduction: ResourceBundle;
  controlledSystems: number;
  availableTechnology: number;
  spentTechnology: number;
  technologyStrength: number;
  fieldedArmyPoints: number;
  queuedArmyPoints: number;
  totalArmyPoints: number;
};

export const AdminFactionSummary = memo(function AdminFactionSummary({ snapshot }: { snapshot: CampaignSnapshot }) {
  const summaries = buildFactionSummaries(snapshot);

  return (
    <Panel className="overflow-hidden p-0">
      <div className="flex items-center gap-3 border-b border-cyan-200/15 px-4 py-4 md:px-5">
        <span className="grid size-9 shrink-0 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
          <BarChart3 aria-hidden="true" size={18} />
        </span>
        <div>
          <h2 className="text-base font-semibold text-cyan-50">Resumen de facciones</h2>
          <p className="text-xs text-slate-400">Estado económico, tecnológico y militar de la campaña.</p>
        </div>
      </div>

      <div className="hidden grid-cols-[minmax(150px,0.8fr)_minmax(260px,1.5fr)_minmax(155px,0.8fr)_minmax(260px,1.5fr)_minmax(155px,0.8fr)] gap-4 border-b border-cyan-200/10 bg-slate-950/30 px-5 py-2.5 text-[10px] font-semibold uppercase text-slate-500 xl:grid">
        <span>Facción</span>
        <span>Recursos</span>
        <span>Fuerza tecnológica</span>
        <span>Producción diaria</span>
        <span>Ejército</span>
      </div>

      <div className="divide-y divide-cyan-200/10">
        {summaries.map((summary) => (
          <FactionSummaryRow key={summary.faction.id} maxArmyPoints={snapshot.maxArmyPoints} summary={summary} />
        ))}
      </div>
    </Panel>
  );
});

function FactionSummaryRow({ summary, maxArmyPoints }: { summary: FactionSummary; maxArmyPoints: number }) {
  const armyRatio = maxArmyPoints > 0 ? Math.min(100, (summary.totalArmyPoints / maxArmyPoints) * 100) : 0;

  return (
    <section
      className="grid gap-4 px-4 py-4 xl:grid-cols-[minmax(150px,0.8fr)_minmax(260px,1.5fr)_minmax(155px,0.8fr)_minmax(260px,1.5fr)_minmax(155px,0.8fr)] xl:items-center xl:px-5"
      style={{ boxShadow: `inset 3px 0 0 ${summary.faction.color}` }}
    >
      <div className="flex min-w-0 items-center gap-3">
        <span
          aria-hidden="true"
          className="size-3 shrink-0 rounded-full border border-white/20"
          style={{ backgroundColor: summary.faction.color, boxShadow: `0 0 12px ${summary.faction.color}66` }}
        />
        <div className="min-w-0">
          <h3 className="truncate text-sm font-semibold text-cyan-50">{summary.faction.name}</h3>
          <p className="mt-0.5 text-[11px] text-slate-500">
            {summary.controlledSystems} {summary.controlledSystems === 1 ? "sistema" : "sistemas"}
          </p>
        </div>
      </div>

      <SummaryBlock icon={null} label="Recursos">
        <ResourceMetrics mode="stock" resources={summary.resources} />
      </SummaryBlock>

      <SummaryBlock icon={<Cpu aria-hidden="true" size={14} />} label="Fuerza tecnológica">
        <p className="text-lg font-semibold tabular-nums text-cyan-50">{summary.technologyStrength} pts</p>
        <p className="text-[11px] text-slate-500">
          {summary.spentTechnology} gastados + {summary.availableTechnology} disponibles
        </p>
      </SummaryBlock>

      <SummaryBlock icon={<Factory aria-hidden="true" size={14} />} label="Producción diaria">
        <ResourceMetrics mode="production" resources={summary.dailyProduction} />
      </SummaryBlock>

      <SummaryBlock icon={<Swords aria-hidden="true" size={14} />} label="Ejército">
        <div className="flex items-baseline gap-1 text-cyan-50">
          <span className="text-lg font-semibold tabular-nums">{summary.totalArmyPoints}</span>
          <span className="text-xs text-slate-500">/ {maxArmyPoints} pts</span>
        </div>
        <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-slate-800">
          <div className="h-full rounded-full bg-cyan-400" style={{ width: `${armyRatio}%` }} />
        </div>
        <p className="mt-1.5 text-[11px] text-slate-500">
          {summary.fieldedArmyPoints} desplegados
          {summary.queuedArmyPoints > 0 ? ` + ${summary.queuedArmyPoints} en cola` : ""}
        </p>
      </SummaryBlock>
    </section>
  );
}

function SummaryBlock({
  children,
  icon,
  label
}: {
  children: ReactNode;
  icon: ReactNode | null;
  label: string;
}) {
  return (
    <div className="min-w-0">
      <div className="mb-2 flex items-center gap-1.5 text-[10px] font-semibold uppercase text-slate-500 xl:hidden">
        {icon}
        {label}
      </div>
      {children}
    </div>
  );
}

function ResourceMetrics({ resources, mode }: { resources: ResourceBundle; mode: "stock" | "production" }) {
  return (
    <div className="grid grid-cols-3 gap-x-3 gap-y-2 sm:grid-cols-6 xl:grid-cols-3 2xl:grid-cols-6">
      {economicResourceKeys.map((resourceKey) => {
        const value = resources[resourceKey];
        return (
          <span
            className="inline-flex min-w-0 items-center gap-1.5 tabular-nums text-slate-200"
            key={resourceKey}
            title={resourceLabels[resourceKey]}
          >
            <ResourceIcon className="size-4 shrink-0" resource={resourceKey} />
            <span className={value > 0 ? "font-medium" : "text-slate-600"}>
              {mode === "production" && value > 0 ? "+" : ""}
              {formatMetricValue(value, mode)}
            </span>
          </span>
        );
      })}
    </div>
  );
}

function buildFactionSummaries(snapshot: CampaignSnapshot): FactionSummary[] {
  const playableFactions = snapshot.factions.filter((faction) => !faction.isNarrative);
  const resourcesByFaction = new Map(snapshot.resources.map((resources) => [resources.factionId, resources]));
  const technologyCostById = new Map(snapshot.technologyNodes.map((node) => [node.id, node.costTechnology]));
  const dailyFactor = snapshot.resourceTickIntervalHours > 0 ? 24 / snapshot.resourceTickIntervalHours : 1;

  return playableFactions.map((faction) => {
    const resources = resourcesByFaction.get(faction.id) ?? emptyResourceBundle();
    const controlledSystems = snapshot.systems.filter(
      (system) => system.controllerFactionId === faction.id && system.status === "controlled"
    );
    const dailyProduction = controlledSystems.reduce((total, system) => {
      for (const resourceKey of economicResourceKeys) {
        total[resourceKey] += (system.production[resourceKey] ?? 0) * dailyFactor;
      }
      return total;
    }, emptyResourceBundle());
    const spentTechnology = snapshot.factionTechnologies
      .filter(
        (technology) =>
          technology.factionId === faction.id &&
          (technology.status === "unlocked" || technology.status === "researching")
      )
      .reduce((total, technology) => total + (technologyCostById.get(technology.technologyNodeId) ?? 0), 0);
    const availableTechnology = resources.technology;
    const fieldedArmyPoints = getLivingUnitPoints(snapshot, faction.id);
    const queuedArmyPoints = getQueuedRecruitmentPoints(snapshot, faction.id);

    return {
      faction,
      resources,
      dailyProduction,
      controlledSystems: controlledSystems.length,
      availableTechnology,
      spentTechnology,
      technologyStrength: spentTechnology + availableTechnology,
      fieldedArmyPoints,
      queuedArmyPoints,
      totalArmyPoints: fieldedArmyPoints + queuedArmyPoints
    };
  });
}

function emptyResourceBundle(): ResourceBundle {
  return {
    supply: 0,
    minerals: 0,
    honor: 0,
    gold: 0,
    industrialMaterial: 0,
    uridium: 0,
    technology: 0
  };
}

function formatMetricValue(value: number, mode: "stock" | "production") {
  if (mode === "stock") {
    return Math.floor(value).toLocaleString("es-ES");
  }

  return value.toLocaleString("es-ES", {
    maximumFractionDigits: 2
  });
}
