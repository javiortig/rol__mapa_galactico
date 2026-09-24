"use client";

import { useEffect, useMemo, useState } from "react";
import { Clock3, Factory, MapPin, Route, Shield, Swords, Timer, UsersRound, Wrench, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import type { CampaignSnapshot, CampaignUnit, RecruitmentQueueItem } from "@/domain/campaign";
import { formatUnitKeywords } from "@/features/units/lib/character-ranks";
import {
  buildActiveMovementByUnitId,
  getRecruitmentSystemName,
  getUnitOperationalState,
  type UnitOperationalState
} from "@/features/units/lib/unit-operational-status";
import { formatCountdown } from "@/lib/time";

type TroopRosterModalProps = {
  open: boolean;
  snapshot: CampaignSnapshot;
  onClose: () => void;
};

type UnitRosterEntry = {
  unit: CampaignUnit;
  operationalState: UnitOperationalState;
};

const sectionOrder = [0, 1, 2, 3] as const;

export function TroopRosterModal({ open, snapshot, onClose }: TroopRosterModalProps) {
  const [nowMs, setNowMs] = useState(() => Date.now());
  const currentFactionId = snapshot.currentUser.factionId;
  const activeMovementByUnitId = useMemo(
    () => buildActiveMovementByUnitId(snapshot.movements),
    [snapshot.movements]
  );
  const entries = useMemo(() => {
    if (!currentFactionId) {
      return [];
    }

    return snapshot.units
      .filter(
        (unit) =>
          unit.factionId === currentFactionId &&
          unit.status !== "destroyed" &&
          unit.quantity > 0
      )
      .map((unit) => ({
        unit,
        operationalState: getUnitOperationalState(snapshot, unit, activeMovementByUnitId.get(unit.id))
      }))
      .sort(compareRosterEntries);
  }, [activeMovementByUnitId, currentFactionId, snapshot]);
  const recruitmentQueue = useMemo(
    () =>
      snapshot.recruitmentQueue
        .filter((item) => item.factionId === currentFactionId && item.status === "queued")
        .sort((left, right) => Date.parse(left.finishesAt) - Date.parse(right.finishesAt)),
    [currentFactionId, snapshot.recruitmentQueue]
  );
  const groupedEntries = useMemo(
    () =>
      sectionOrder.map((priority) => ({
        priority,
        entries: entries.filter((entry) => entry.operationalState.priority === priority)
      })),
    [entries]
  );
  const totalPoints = entries.reduce((total, entry) => total + entry.unit.points, 0);
  const totalModels = entries.reduce((total, entry) => total + entry.unit.quantity, 0);
  const activeCount = entries.filter((entry) => entry.operationalState.priority < 3).length + recruitmentQueue.length;

  useEffect(() => {
    if (!open) {
      return;
    }

    const intervalId = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(intervalId);
  }, [open]);

  useEffect(() => {
    if (!open) {
      return;
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose, open]);

  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/80 p-0 backdrop-blur-sm md:p-4">
      <Panel className="flex h-[var(--app-height)] w-full max-w-6xl flex-col overflow-hidden rounded-none md:h-auto md:max-h-[calc(var(--app-height)-2rem)] md:rounded-lg">
        <header className="flex shrink-0 items-center justify-between gap-3 border-b border-cyan-200/15 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:p-5">
          <div className="min-w-0">
            <div className="text-xs uppercase tracking-[0.2em] text-cyan-200/70">Registro de fuerzas</div>
            <h2 className="mt-1 text-xl font-semibold text-cyan-50">Tropas</h2>
          </div>
          <Button aria-label="Cerrar tropas" onClick={onClose} size="icon" title="Cerrar" variant="ghost">
            <X size={18} />
          </Button>
        </header>

        <div className="mobile-scroll min-h-0 flex-1 p-3 pb-[max(1rem,env(safe-area-inset-bottom))] md:p-5">
          <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
            <RosterMetric icon={Shield} label="Unidades" value={entries.length} />
            <RosterMetric icon={UsersRound} label="Miniaturas" value={totalModels} />
            <RosterMetric icon={Swords} label="Fuerza" suffix="pts" value={totalPoints} />
            <RosterMetric icon={Clock3} label="En curso" value={activeCount} />
          </div>

          <div className="mt-5 space-y-5">
            {groupedEntries.map((group) =>
              group.entries.length > 0 ? (
                <TroopSection entries={group.entries} key={group.priority} nowMs={nowMs} priority={group.priority} />
              ) : null
            )}

            {recruitmentQueue.length > 0 ? (
              <section>
                <SectionHeading count={recruitmentQueue.length} icon={Factory} title="En reclutamiento" />
                <div className="mt-2 space-y-2">
                  {recruitmentQueue.map((item) => (
                    <RecruitmentRow item={item} key={item.id} nowMs={nowMs} snapshot={snapshot} />
                  ))}
                </div>
              </section>
            ) : null}

            {entries.length === 0 && recruitmentQueue.length === 0 ? (
              <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-6 text-center text-sm text-slate-400">
                No hay tropas ni reclutamientos activos.
              </div>
            ) : null}
          </div>
        </div>
      </Panel>
    </div>
  );
}

function TroopSection({
  entries,
  priority,
  nowMs
}: {
  entries: UnitRosterEntry[];
  priority: (typeof sectionOrder)[number];
  nowMs: number;
}) {
  const definition = getSectionDefinition(priority);

  return (
    <section>
      <SectionHeading count={entries.length} icon={definition.icon} title={definition.title} />
      <div className="mt-2 space-y-2">
        {entries.map((entry) => (
          <TroopRow entry={entry} key={entry.unit.id} nowMs={nowMs} />
        ))}
      </div>
    </section>
  );
}

function TroopRow({ entry, nowMs }: { entry: UnitRosterEntry; nowMs: number }) {
  const { unit, operationalState } = entry;

  return (
    <article className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 [content-visibility:auto] md:p-4">
      <div className="grid gap-3 md:grid-cols-[minmax(0,1.25fr)_minmax(12rem,1fr)_auto] md:items-center">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="truncate text-sm font-semibold text-slate-100">{unit.name}</h3>
            <Badge tone={operationalState.tone}>{operationalState.label}</Badge>
          </div>
          <p className="mt-1 text-xs text-slate-400">
            {unit.quantity}/{unit.startingQuantity} miniaturas · {unit.woundsTaken} heridas · {unit.points} pts
          </p>
          <p className="mt-1 text-[11px] text-slate-500">{formatUnitKeywords(unit)}</p>
        </div>

        <div className="flex min-w-0 items-start gap-2 text-xs text-slate-300">
          <MapPin className="mt-0.5 shrink-0 text-cyan-300/70" size={14} />
          <span className="min-w-0 break-words">{operationalState.detail}</span>
        </div>

        <div className="flex min-w-32 items-center gap-2 text-xs md:justify-end">
          {operationalState.targetAt ? (
            <>
              <Timer className="shrink-0 text-amber-200" size={14} />
              <span className="font-medium tabular-nums text-amber-100">
                {formatCountdown(operationalState.targetAt, nowMs)}
              </span>
            </>
          ) : operationalState.priority === 1 ? (
            <span className="text-rose-200">Hasta resolver la batalla</span>
          ) : operationalState.label === "Esperando autorización" ? (
            <span className="text-amber-200">Pendiente de respuesta</span>
          ) : operationalState.priority === 3 ? (
            <span className="text-cyan-200">Lista para órdenes</span>
          ) : (
            <span className="text-slate-400">Pendiente</span>
          )}
        </div>
      </div>
    </article>
  );
}

function RecruitmentRow({
  item,
  snapshot,
  nowMs
}: {
  item: RecruitmentQueueItem;
  snapshot: CampaignSnapshot;
  nowMs: number;
}) {
  const systemName = getRecruitmentSystemName(snapshot, item.originSystemId, item.systemBuildingId);
  const template = snapshot.unitTemplates.find((unitTemplate) => unitTemplate.id === item.unitTemplateId);
  const modelsPerUnit = item.selectedModelCount ?? template?.defaultQuantity ?? 1;
  const totalModels = modelsPerUnit * item.quantity;
  const totalPoints = (item.selectedPoints ?? template?.points ?? 0) * item.quantity;

  return (
    <article className="rounded-md border border-violet-300/18 bg-violet-400/7 p-3 [content-visibility:auto] md:p-4">
      <div className="grid gap-3 md:grid-cols-[minmax(0,1.25fr)_minmax(12rem,1fr)_auto] md:items-center">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="truncate text-sm font-semibold text-slate-100">{item.unitName}</h3>
            <Badge tone="violet">Reclutando</Badge>
          </div>
          <p className="mt-1 text-xs text-slate-400">
            {item.quantity} {item.quantity === 1 ? "unidad" : "unidades"} · {totalModels}{" "}
            {totalModels === 1 ? "miniatura" : "miniaturas"}
            {totalPoints > 0 ? ` · ${totalPoints} pts` : ""}
          </p>
        </div>
        <div className="flex min-w-0 items-center gap-2 text-xs text-slate-300">
          <Factory className="shrink-0 text-violet-200/80" size={14} />
          <span className="truncate">{systemName}</span>
        </div>
        <div className="flex min-w-32 items-center gap-2 text-xs md:justify-end">
          <Timer className="shrink-0 text-amber-200" size={14} />
          <span className="font-medium tabular-nums text-amber-100">{formatCountdown(item.finishesAt, nowMs)}</span>
        </div>
      </div>
    </article>
  );
}

function SectionHeading({
  title,
  count,
  icon: Icon
}: {
  title: string;
  count: number;
  icon: typeof Route;
}) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-cyan-200/10 pb-2">
      <h3 className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.16em] text-cyan-100/80">
        <Icon size={15} /> {title}
      </h3>
      <Badge tone="slate">{count}</Badge>
    </div>
  );
}

function RosterMetric({
  icon: Icon,
  label,
  value,
  suffix
}: {
  icon: typeof Shield;
  label: string;
  value: number;
  suffix?: string;
}) {
  return (
    <div className="rounded-md border border-cyan-200/15 bg-slate-950/40 p-3">
      <div className="flex items-center gap-2 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-400">
        <Icon className="text-cyan-300/70" size={14} /> {label}
      </div>
      <div className="mt-2 text-lg font-semibold tabular-nums text-cyan-50">
        {value.toLocaleString("es-ES")} {suffix ? <span className="text-xs text-slate-400">{suffix}</span> : null}
      </div>
    </div>
  );
}

function compareRosterEntries(left: UnitRosterEntry, right: UnitRosterEntry) {
  return (
    left.operationalState.priority - right.operationalState.priority ||
    left.operationalState.detail.localeCompare(right.operationalState.detail, "es") ||
    left.unit.name.localeCompare(right.unit.name, "es")
  );
}

function getSectionDefinition(priority: (typeof sectionOrder)[number]) {
  if (priority === 0) {
    return { title: "En tránsito", icon: Route };
  }

  if (priority === 1) {
    return { title: "En batalla", icon: Swords };
  }

  if (priority === 2) {
    return { title: "En reabastecimiento", icon: Wrench };
  }

  return { title: "Desplegadas", icon: Shield };
}
