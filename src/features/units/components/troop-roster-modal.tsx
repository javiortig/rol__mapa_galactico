"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Clock3,
  Factory,
  MapPin,
  RotateCcw,
  Route,
  Shield,
  Swords,
  Timer,
  UsersRound,
  Wrench,
  X
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import type {
  CampaignSnapshot,
  CampaignUnit,
  MovementOrder,
  RecruitmentQueueItem,
  UnitRecoveryQueueItem
} from "@/domain/campaign";
import { cancelMovementOrder, canUseMovementRpc } from "@/features/movement/api/movement-api";
import { formatUnitKeywords } from "@/features/units/lib/character-ranks";
import { getJoinedCoalitionAttackOrderIds, getRecruitmentSystemName } from "@/features/units/lib/unit-operational-status";
import { formatCountdown, formatDurationSeconds } from "@/lib/time";

type TroopRosterModalProps = {
  open: boolean;
  snapshot: CampaignSnapshot;
  onClose: () => void;
};

type RosterView = "movement" | "combat" | "queues" | "deployed";

type SystemUnitGroup = {
  systemId: string;
  systemName: string;
  units: CampaignUnit[];
};

const activeMovementStatuses = new Set<MovementOrder["status"]>(["pending_approval", "moving"]);
const combatMovementPurposes = new Set<MovementOrder["movementPurpose"]>([
  "attack",
  "coalition_staging",
  "defense_support"
]);

export function TroopRosterModal({ open, snapshot, onClose }: TroopRosterModalProps) {
  const queryClient = useQueryClient();
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [activeView, setActiveView] = useState<RosterView>("movement");
  const [confirmCancellationId, setConfirmCancellationId] = useState<string | null>(null);
  const handleClose = useCallback(() => {
    setActiveView("movement");
    setConfirmCancellationId(null);
    onClose();
  }, [onClose]);
  const currentFactionId = snapshot.currentUser.factionId;
  const units = useMemo(
    () =>
      snapshot.units
        .filter(
          (unit) =>
            unit.factionId === currentFactionId &&
            unit.status !== "destroyed" &&
            unit.quantity > 0
        )
        .sort(compareUnits),
    [currentFactionId, snapshot.units]
  );
  const unitById = useMemo(() => new Map(units.map((unit) => [unit.id, unit])), [units]);
  const visibleUnitById = useMemo(
    () => new Map(snapshot.units.map((unit) => [unit.id, unit])),
    [snapshot.units]
  );
  const joinedCoalitionAttackOrderIds = useMemo(
    () => getJoinedCoalitionAttackOrderIds(snapshot, currentFactionId),
    [currentFactionId, snapshot]
  );
  const activeMovements = useMemo(
    () =>
      snapshot.movements
        .filter(
          (movement) =>
            (movement.factionId === currentFactionId || (
              movement.movementType === "attack" && joinedCoalitionAttackOrderIds.has(movement.id)
            )) &&
            activeMovementStatuses.has(movement.status)
        )
        .sort(compareMovements),
    [currentFactionId, joinedCoalitionAttackOrderIds, snapshot.movements]
  );
  const combatMovements = useMemo(
    () => activeMovements.filter(isCombatMovement),
    [activeMovements]
  );
  const standardMovements = useMemo(
    () => activeMovements.filter((movement) => !isCombatMovement(movement)),
    [activeMovements]
  );
  const movingUnitIds = useMemo(
    () => new Set(activeMovements.flatMap((movement) => movement.unitIds)),
    [activeMovements]
  );
  const orphanMovementUnits = useMemo(
    () => units.filter((unit) => unit.status === "moving" && !movingUnitIds.has(unit.id)),
    [movingUnitIds, units]
  );
  const combatUnits = useMemo(
    () =>
      units.filter(
        (unit) =>
          !movingUnitIds.has(unit.id) &&
          (unit.status === "in_war" || unit.status === "retreat_pending")
      ),
    [movingUnitIds, units]
  );
  const combatGroups = useMemo(
    () => groupUnitsBySystem(snapshot, combatUnits),
    [combatUnits, snapshot]
  );
  const recruitmentQueue = useMemo(
    () =>
      snapshot.recruitmentQueue
        .filter((item) => item.factionId === currentFactionId && item.status === "queued")
        .sort((left, right) => Date.parse(left.finishesAt) - Date.parse(right.finishesAt)),
    [currentFactionId, snapshot.recruitmentQueue]
  );
  const recoveryQueue = useMemo(
    () =>
      snapshot.unitRecoveryQueue
        .filter((item) => item.factionId === currentFactionId && item.status === "queued")
        .sort((left, right) => Date.parse(left.finishesAt) - Date.parse(right.finishesAt)),
    [currentFactionId, snapshot.unitRecoveryQueue]
  );
  const recoveryUnitIds = useMemo(
    () => new Set(recoveryQueue.map((item) => item.campaignUnitId)),
    [recoveryQueue]
  );
  const deployedUnits = useMemo(
    () =>
      units.filter(
        (unit) =>
          unit.status === "ready" &&
          !movingUnitIds.has(unit.id) &&
          !recoveryUnitIds.has(unit.id)
      ),
    [movingUnitIds, recoveryUnitIds, units]
  );
  const deployedGroups = useMemo(
    () => groupUnitsBySystem(snapshot, deployedUnits),
    [deployedUnits, snapshot]
  );
  const totalPoints = units.reduce((total, unit) => total + unit.points, 0);
  const totalModels = units.reduce((total, unit) => total + unit.quantity, 0);
  const activeOperationCount =
    activeMovements.length + combatGroups.length + recruitmentQueue.length + recoveryQueue.length;
  const movementUnitCount = countMovementUnits(standardMovements) + orphanMovementUnits.length;
  const combatUnitCount = countMovementUnits(combatMovements) + combatUnits.length;
  const queueCount = recruitmentQueue.length + recoveryQueue.length;
  const cancelMutation = useMutation({
    mutationFn: cancelMovementOrder,
    onSuccess: () => {
      setConfirmCancellationId(null);
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

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
        handleClose();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [handleClose, open]);

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
          <Button aria-label="Cerrar tropas" onClick={handleClose} size="icon" title="Cerrar" variant="ghost">
            <X size={18} />
          </Button>
        </header>

        <div className="mobile-scroll min-h-0 flex-1 p-3 pb-[max(1rem,env(safe-area-inset-bottom))] md:p-5">
          <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
            <RosterMetric icon={Shield} label="Unidades" value={units.length} />
            <RosterMetric icon={UsersRound} label="Miniaturas" value={totalModels} />
            <RosterMetric icon={Swords} label="Fuerza" suffix="pts" value={totalPoints} />
            <RosterMetric icon={Clock3} label="Operaciones" value={activeOperationCount} />
          </div>

          <RosterNavigation
            activeView={activeView}
            counts={{
              movement: movementUnitCount,
              combat: combatUnitCount,
              queues: queueCount,
              deployed: deployedUnits.length
            }}
            onChange={setActiveView}
          />

          <div className="mt-4">
            {activeView === "movement" ? (
              <MovementView
                confirmCancellationId={confirmCancellationId}
                movements={standardMovements}
                mutationError={cancelMutation.error?.message ?? null}
                mutationPendingId={cancelMutation.isPending ? cancelMutation.variables : null}
                nowMs={nowMs}
                onCancel={(movementId) => cancelMutation.mutate(movementId)}
                onConfirmChange={setConfirmCancellationId}
                orphanUnits={orphanMovementUnits}
                rpcReady={canUseMovementRpc()}
                snapshot={snapshot}
                unitById={unitById}
              />
            ) : null}

            {activeView === "combat" ? (
              <CombatView
                combatGroups={combatGroups}
                movements={combatMovements}
                nowMs={nowMs}
                snapshot={snapshot}
                unitById={visibleUnitById}
              />
            ) : null}

            {activeView === "queues" ? (
              <QueueView
                nowMs={nowMs}
                recruitmentQueue={recruitmentQueue}
                recoveryQueue={recoveryQueue}
                snapshot={snapshot}
                unitById={unitById}
              />
            ) : null}

            {activeView === "deployed" ? <DeployedView groups={deployedGroups} /> : null}
          </div>
        </div>
      </Panel>
    </div>
  );
}

function RosterNavigation({
  activeView,
  counts,
  onChange
}: {
  activeView: RosterView;
  counts: Record<RosterView, number>;
  onChange: (view: RosterView) => void;
}) {
  const items: Array<{ id: RosterView; label: string; mobileLabel?: string; icon: typeof Route; activeClass: string }> = [
    { id: "movement", label: "Movimiento", icon: Route, activeClass: "border-cyan-300/45 bg-cyan-300/10 text-cyan-50" },
    { id: "combat", label: "En combate", icon: Swords, activeClass: "border-rose-300/45 bg-rose-300/10 text-rose-50" },
    { id: "queues", label: "Reclutamiento / reabastecimiento", mobileLabel: "Preparación", icon: Factory, activeClass: "border-violet-300/45 bg-violet-300/10 text-violet-50" },
    { id: "deployed", label: "Desplegadas", icon: Shield, activeClass: "border-emerald-300/40 bg-emerald-300/10 text-emerald-50" }
  ];

  return (
    <nav aria-label="Estado de las tropas" className="sticky top-0 z-10 mt-4 grid grid-cols-2 gap-2 bg-slate-950/90 py-2 backdrop-blur-md md:grid-cols-4">
      {items.map((item) => {
        const Icon = item.icon;
        const selected = activeView === item.id;
        return (
          <button
            aria-pressed={selected}
            className={`flex min-h-11 items-center justify-between gap-2 rounded-md border px-3 py-2 text-left text-xs font-semibold transition-colors ${
              selected
                ? item.activeClass
                : "border-slate-700/70 bg-slate-950/55 text-slate-400 hover:border-slate-500 hover:text-slate-200"
            }`}
            key={item.id}
            onClick={() => onChange(item.id)}
            type="button"
          >
            <span className="flex min-w-0 items-center gap-2">
              <Icon className="shrink-0" size={15} />
              <span className="truncate md:hidden">{item.mobileLabel ?? item.label}</span>
              <span className="hidden truncate md:inline">{item.label}</span>
            </span>
            <span className="shrink-0 tabular-nums opacity-80">{counts[item.id]}</span>
          </button>
        );
      })}
    </nav>
  );
}

function MovementView({
  movements,
  orphanUnits,
  snapshot,
  unitById,
  nowMs,
  confirmCancellationId,
  mutationPendingId,
  mutationError,
  rpcReady,
  onConfirmChange,
  onCancel
}: {
  movements: MovementOrder[];
  orphanUnits: CampaignUnit[];
  snapshot: CampaignSnapshot;
  unitById: Map<string, CampaignUnit>;
  nowMs: number;
  confirmCancellationId: string | null;
  mutationPendingId: string | null;
  mutationError: string | null;
  rpcReady: boolean;
  onConfirmChange: (movementId: string | null) => void;
  onCancel: (movementId: string) => void;
}) {
  if (movements.length === 0 && orphanUnits.length === 0) {
    return <EmptyRosterState icon={Route} text="No hay fuerzas desplazándose entre sistemas." />;
  }

  return (
    <section>
      <SectionHeading count={movements.length} icon={Route} title="Movimientos activos" />
      <div className="mt-3 space-y-3">
        {movements.map((movement) => (
          <MovementOrderCard
            confirmCancellation={confirmCancellationId === movement.id}
            key={movement.id}
            movement={movement}
            mutationPending={mutationPendingId === movement.id}
            nowMs={nowMs}
            onCancel={() => onCancel(movement.id)}
            onConfirmChange={(confirming) => onConfirmChange(confirming ? movement.id : null)}
            rpcReady={rpcReady}
            snapshot={snapshot}
            unitById={unitById}
          />
        ))}
        {orphanUnits.length > 0 ? (
          <article className="rounded-md border border-amber-300/20 bg-amber-300/5 p-3 md:p-4">
            <div className="flex items-center gap-2">
              <Timer className="text-amber-200" size={16} />
              <h3 className="text-sm font-semibold text-amber-50">Ruta en curso</h3>
            </div>
            <div className="mt-3 divide-y divide-slate-800/80 border-t border-slate-800/80">
              {orphanUnits.map((unit) => <UnitLine key={unit.id} unit={unit} />)}
            </div>
          </article>
        ) : null}
      </div>
      {mutationError ? <p className="mt-3 text-sm text-rose-200">{mutationError}</p> : null}
    </section>
  );
}

function CombatView({
  movements,
  combatGroups,
  snapshot,
  unitById,
  nowMs
}: {
  movements: MovementOrder[];
  combatGroups: SystemUnitGroup[];
  snapshot: CampaignSnapshot;
  unitById: Map<string, CampaignUnit>;
  nowMs: number;
}) {
  if (movements.length === 0 && combatGroups.length === 0) {
    return <EmptyRosterState icon={Swords} text="No hay fuerzas comprometidas en operaciones de combate." />;
  }

  return (
    <div className="space-y-5">
      {movements.length > 0 ? (
        <section>
          <SectionHeading count={movements.length} icon={Route} title="En camino al combate" tone="rose" />
          <div className="mt-3 space-y-3">
            {movements.map((movement) => (
              <MovementOrderCard
                key={movement.id}
                movement={movement}
                nowMs={nowMs}
                snapshot={snapshot}
                tone="combat"
                unitById={unitById}
              />
            ))}
          </div>
        </section>
      ) : null}

      {combatGroups.length > 0 ? (
        <section>
          <SectionHeading count={combatGroups.length} icon={Swords} title="Frentes activos" tone="rose" />
          <div className="mt-3 space-y-3">
            {combatGroups.map((group) => (
              <SystemUnitPanel badge="Frente activo" group={group} key={group.systemId} tone="rose" />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}

function MovementOrderCard({
  movement,
  snapshot,
  unitById,
  nowMs,
  tone = "movement",
  confirmCancellation = false,
  mutationPending = false,
  rpcReady = false,
  onConfirmChange,
  onCancel
}: {
  movement: MovementOrder;
  snapshot: CampaignSnapshot;
  unitById: Map<string, CampaignUnit>;
  nowMs: number;
  tone?: "movement" | "combat";
  confirmCancellation?: boolean;
  mutationPending?: boolean;
  rpcReady?: boolean;
  onConfirmChange?: (confirming: boolean) => void;
  onCancel?: () => void;
}) {
  const systemById = new Map(snapshot.systems.map((system) => [system.id, system]));
  const originName = systemById.get(movement.fromSystemId)?.name ?? "Origen desconocido";
  const destinationName = systemById.get(movement.toSystemId)?.name ?? "Destino desconocido";
  const movementUnits = movement.unitIds
    .map((unitId) => unitById.get(unitId))
    .filter((unit): unit is CampaignUnit => Boolean(unit));
  const isCoalitionAttack = movement.movementType === "attack" && snapshot.battleOperations.some(
    (operation) => operation.mode === "coalition" && operation.attackMovementOrderId === movement.id
  );
  const points = movementUnits.reduce((total, unit) => total + unit.points, 0);
  const models = movementUnits.reduce((total, unit) => total + unit.quantity, 0);
  const canCancel =
    movement.movementType === "move" &&
    movement.movementPurpose === "normal" &&
    activeMovementStatuses.has(movement.status);
  const estimate = canCancel ? getTurnbackEstimate(snapshot, movement, nowMs) : null;
  const combatTone = tone === "combat";

  return (
    <article className={`overflow-hidden rounded-md border ${combatTone ? "border-rose-300/20 bg-rose-400/5" : "border-cyan-200/15 bg-slate-950/35"}`}>
      <div className="p-3 md:p-4">
        <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={combatTone ? "rose" : movement.status === "pending_approval" ? "amber" : "cyan"}>
                {getMovementStateLabel(movement)}
              </Badge>
              <span className="text-xs text-slate-400">
                {movement.segmentCount} {movement.segmentCount === 1 ? "salto" : "saltos"}
              </span>
            </div>
            <div className="mt-3 grid gap-2 sm:grid-cols-[1fr_auto_1fr] sm:items-center">
              <SystemRouteEndpoint label="Origen" name={originName} />
              <Route className={combatTone ? "hidden text-rose-300/70 sm:block" : "hidden text-cyan-300/70 sm:block"} size={18} />
              <SystemRouteEndpoint align="right" label="Destino" name={destinationName} />
            </div>
          </div>

          <div className="shrink-0 rounded-md border border-slate-700/70 bg-slate-950/50 px-3 py-2 text-left md:min-w-40 md:text-right">
            <div className="text-[10px] uppercase tracking-[0.14em] text-slate-500">
              {movement.status === "pending_approval" ? "Estado" : "Llegada"}
            </div>
            <div className={`mt-1 flex items-center gap-2 text-sm font-semibold tabular-nums md:justify-end ${combatTone ? "text-rose-100" : "text-cyan-100"}`}>
              <Timer size={14} />
              {movement.status === "pending_approval"
                ? "Pendiente de autorización"
                : movement.arrivalAt
                  ? formatCountdown(movement.arrivalAt, nowMs)
                  : "Calculando"}
            </div>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap items-center justify-between gap-2 border-b border-slate-800/80 pb-2">
          <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-400">
            {isCoalitionAttack ? "Fuerzas de la coalición" : "Fuerzas asignadas"}
          </span>
          <span className="text-xs tabular-nums text-slate-400">
            {movementUnits.length} {movementUnits.length === 1 ? "unidad" : "unidades"} · {models} miniaturas · {points} pts
          </span>
        </div>
        <div className="divide-y divide-slate-800/80">
          {movementUnits.length > 0
            ? movementUnits.map((unit) => (
                <UnitLine
                  factionName={isCoalitionAttack ? snapshot.factions.find((faction) => faction.id === unit.factionId)?.name : undefined}
                  key={unit.id}
                  unit={unit}
                />
              ))
            : <p className="py-3 text-sm text-slate-500">No hay información disponible de las unidades asignadas.</p>}
        </div>

        {canCancel && estimate ? (
          <div className="mt-3 border-t border-cyan-200/10 pt-3">
            {confirmCancellation ? (
              <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                <div className="text-xs leading-5 text-slate-300">
                  Regresarán a <strong className="text-slate-100">{estimate.returnSystemName}</strong> en{" "}
                  <strong className="text-slate-100">{formatDurationSeconds(estimate.returnSeconds)}</strong>.
                  <span className={estimate.refundUridium > 0 ? "ml-1 text-emerald-200" : "ml-1 text-slate-500"}>
                    {estimate.refundUridium > 0
                      ? `Se devolverán ${estimate.refundUridium} de Uridium.`
                      : "No habrá reembolso de Uridium."}
                  </span>
                </div>
                <div className="flex shrink-0 gap-2">
                  <Button disabled={mutationPending} onClick={() => onConfirmChange?.(false)} size="sm" variant="ghost">
                    Mantener ruta
                  </Button>
                  <Button disabled={!rpcReady || mutationPending} onClick={onCancel} size="sm" variant="danger">
                    <RotateCcw size={14} />
                    {mutationPending ? "Ordenando..." : "Confirmar regreso"}
                  </Button>
                </div>
              </div>
            ) : (
              <div className="flex justify-end">
                <Button onClick={() => onConfirmChange?.(true)} size="sm" variant="ghost">
                  <RotateCcw size={14} /> Dar media vuelta
                </Button>
              </div>
            )}
          </div>
        ) : null}
      </div>
    </article>
  );
}

function QueueView({
  recruitmentQueue,
  recoveryQueue,
  snapshot,
  unitById,
  nowMs
}: {
  recruitmentQueue: RecruitmentQueueItem[];
  recoveryQueue: UnitRecoveryQueueItem[];
  snapshot: CampaignSnapshot;
  unitById: Map<string, CampaignUnit>;
  nowMs: number;
}) {
  if (recruitmentQueue.length === 0 && recoveryQueue.length === 0) {
    return <EmptyRosterState icon={Factory} text="No hay reclutamientos ni reabastecimientos en curso." />;
  }

  return (
    <div className="space-y-5">
      {recruitmentQueue.length > 0 ? (
        <section>
          <SectionHeading count={recruitmentQueue.length} icon={Factory} title="En reclutamiento" tone="violet" />
          <div className="mt-3 space-y-2">
            {recruitmentQueue.map((item) => (
              <RecruitmentRow item={item} key={item.id} nowMs={nowMs} snapshot={snapshot} />
            ))}
          </div>
        </section>
      ) : null}

      {recoveryQueue.length > 0 ? (
        <section>
          <SectionHeading count={recoveryQueue.length} icon={Wrench} title="En reabastecimiento" tone="violet" />
          <div className="mt-3 space-y-2">
            {recoveryQueue.map((item) => (
              <RecoveryRow item={item} key={item.id} nowMs={nowMs} snapshot={snapshot} unit={unitById.get(item.campaignUnitId)} />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}

function DeployedView({ groups }: { groups: SystemUnitGroup[] }) {
  if (groups.length === 0) {
    return <EmptyRosterState icon={Shield} text="No hay unidades desplegadas y disponibles." />;
  }

  return (
    <section>
      <SectionHeading count={groups.length} icon={Shield} title="Fuerzas desplegadas" tone="emerald" />
      <div className="mt-3 space-y-3">
        {groups.map((group) => (
          <SystemUnitPanel badge="Listas para órdenes" group={group} key={group.systemId} tone="cyan" />
        ))}
      </div>
    </section>
  );
}

function SystemUnitPanel({ group, badge, tone }: { group: SystemUnitGroup; badge: string; tone: "cyan" | "rose" }) {
  const points = group.units.reduce((total, unit) => total + unit.points, 0);
  const models = group.units.reduce((total, unit) => total + unit.quantity, 0);

  return (
    <article className={`overflow-hidden rounded-md border ${tone === "rose" ? "border-rose-300/20 bg-rose-400/5" : "border-cyan-200/15 bg-slate-950/35"}`}>
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-800/80 px-3 py-3 md:px-4">
        <div className="flex min-w-0 items-center gap-2">
          <MapPin className={tone === "rose" ? "shrink-0 text-rose-300" : "shrink-0 text-cyan-300"} size={16} />
          <h3 className="truncate text-sm font-semibold text-slate-100">{group.systemName}</h3>
          <Badge tone={tone}>{badge}</Badge>
        </div>
        <span className="text-xs tabular-nums text-slate-400">
          {group.units.length} {group.units.length === 1 ? "unidad" : "unidades"} · {models} miniaturas · {points} pts
        </span>
      </div>
      <div className="divide-y divide-slate-800/80 px-3 md:px-4">
        {group.units.map((unit) => <UnitLine key={unit.id} unit={unit} />)}
      </div>
    </article>
  );
}

function UnitLine({ unit, factionName }: { unit: CampaignUnit; factionName?: string }) {
  return (
    <div className="flex flex-col gap-1 py-2.5 sm:flex-row sm:items-center sm:justify-between sm:gap-3">
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5">
          <span className="truncate text-sm font-medium text-slate-100">{unit.name}</span>
          {factionName ? <span className="text-[11px] text-cyan-200/70">{factionName}</span> : null}
        </div>
        <div className="mt-0.5 text-[11px] text-slate-500">{formatUnitKeywords(unit)}</div>
      </div>
      <div className="shrink-0 text-xs tabular-nums text-slate-400">
        {unit.quantity}/{unit.startingQuantity} miniaturas · {unit.woundsTaken} heridas · {unit.points} pts
      </div>
    </div>
  );
}

function RecruitmentRow({ item, snapshot, nowMs }: { item: RecruitmentQueueItem; snapshot: CampaignSnapshot; nowMs: number }) {
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
        <Countdown targetAt={item.finishesAt} nowMs={nowMs} tone="violet" />
      </div>
    </article>
  );
}

function RecoveryRow({
  item,
  unit,
  snapshot,
  nowMs
}: {
  item: UnitRecoveryQueueItem;
  unit?: CampaignUnit;
  snapshot: CampaignSnapshot;
  nowMs: number;
}) {
  const building = snapshot.systemBuildings.find((candidate) => candidate.id === item.systemBuildingId);
  const systemName = building
    ? snapshot.systems.find((system) => system.id === building.systemId)?.name ?? "Sistema desconocido"
    : "Sistema desconocido";

  return (
    <article className="rounded-md border border-violet-300/18 bg-violet-400/7 p-3 [content-visibility:auto] md:p-4">
      <div className="grid gap-3 md:grid-cols-[minmax(0,1.25fr)_minmax(12rem,1fr)_auto] md:items-center">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="truncate text-sm font-semibold text-slate-100">{unit?.name ?? item.unitName}</h3>
            <Badge tone="violet">Reabasteciendo</Badge>
          </div>
          <p className="mt-1 text-xs text-slate-400">
            {unit ? `${unit.quantity}/${unit.startingQuantity} miniaturas · ${unit.woundsTaken} heridas` : "Recuperación completa"}
          </p>
        </div>
        <div className="flex min-w-0 items-center gap-2 text-xs text-slate-300">
          <Wrench className="shrink-0 text-violet-200/80" size={14} />
          <span className="truncate">{systemName}</span>
        </div>
        <Countdown targetAt={item.finishesAt} nowMs={nowMs} tone="violet" />
      </div>
    </article>
  );
}

function Countdown({ targetAt, nowMs, tone }: { targetAt: string; nowMs: number; tone: "cyan" | "violet" }) {
  return (
    <div className={`flex min-w-32 items-center gap-2 text-xs font-medium tabular-nums md:justify-end ${tone === "violet" ? "text-violet-100" : "text-cyan-100"}`}>
      <Timer className="shrink-0" size={14} />
      {formatCountdown(targetAt, nowMs)}
    </div>
  );
}

function SystemRouteEndpoint({ label, name, align = "left" }: { label: string; name: string; align?: "left" | "right" }) {
  return (
    <div className={align === "right" ? "sm:text-right" : undefined}>
      <div className="text-[10px] uppercase tracking-[0.14em] text-slate-500">{label}</div>
      <div className="mt-0.5 truncate text-sm font-semibold text-slate-100">{name}</div>
    </div>
  );
}

function EmptyRosterState({ icon: Icon, text }: { icon: typeof Route; text: string }) {
  return (
    <div className="grid min-h-48 place-items-center rounded-md border border-dashed border-slate-700/80 bg-slate-950/25 p-6 text-center">
      <div>
        <Icon className="mx-auto text-slate-600" size={28} />
        <p className="mt-3 text-sm text-slate-400">{text}</p>
      </div>
    </div>
  );
}

function SectionHeading({
  title,
  count,
  icon: Icon,
  tone = "cyan"
}: {
  title: string;
  count: number;
  icon: typeof Route;
  tone?: "cyan" | "rose" | "violet" | "emerald";
}) {
  const colors = {
    cyan: "text-cyan-100/80",
    rose: "text-rose-100/85",
    violet: "text-violet-100/85",
    emerald: "text-emerald-100/85"
  };

  return (
    <div className="flex items-center justify-between gap-3 border-b border-cyan-200/10 pb-2">
      <h3 className={`flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.16em] ${colors[tone]}`}>
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

function getTurnbackEstimate(snapshot: CampaignSnapshot, movement: MovementOrder, nowMs: number) {
  const systemById = new Map(snapshot.systems.map((system) => [system.id, system]));

  if (movement.status === "pending_approval" || !movement.departureAt || !movement.arrivalAt) {
    return {
      returnSystemName: systemById.get(movement.fromSystemId)?.name ?? "origen",
      returnSeconds: 0,
      refundUridium: movement.uridiumCost
    };
  }

  const path = movement.pathSystemIds.length > 1
    ? movement.pathSystemIds
    : [movement.fromSystemId, movement.toSystemId];
  const edgeCount = Math.max(path.length - 1, 1);
  const departureMs = Date.parse(movement.departureAt);
  const arrivalMs = Date.parse(movement.arrivalAt);
  const totalMs = Math.max(arrivalMs - departureMs, 1);
  const edgeMs = totalMs / edgeCount;
  const elapsedMs = Math.min(Math.max(nowMs - departureMs, 0), totalMs);
  const edgeIndex = Math.min(Math.floor(elapsedMs / edgeMs), edgeCount - 1);
  const elapsedInEdgeMs = Math.max(elapsedMs - edgeIndex * edgeMs, 0);
  const returnSystemId = path[edgeIndex] ?? movement.fromSystemId;

  return {
    returnSystemName: systemById.get(returnSystemId)?.name ?? "último sistema atravesado",
    returnSeconds: Math.ceil(elapsedInEdgeMs / 1000),
    refundUridium: nowMs <= departureMs + 60 * 60 * 1000 ? movement.uridiumCost : 0
  };
}

function groupUnitsBySystem(snapshot: CampaignSnapshot, units: CampaignUnit[]) {
  const systemById = new Map(snapshot.systems.map((system) => [system.id, system]));
  const groups = new Map<string, CampaignUnit[]>();

  for (const unit of units) {
    const systemId = unit.currentSystemId ?? "unknown";
    const current = groups.get(systemId) ?? [];
    current.push(unit);
    groups.set(systemId, current);
  }

  return Array.from(groups, ([systemId, groupedUnits]) => ({
    systemId,
    systemName: systemById.get(systemId)?.name ?? "Sin localización registrada",
    units: groupedUnits.sort(compareUnits)
  })).sort((left, right) => left.systemName.localeCompare(right.systemName, "es"));
}

function isCombatMovement(movement: MovementOrder) {
  return movement.movementType === "attack" || combatMovementPurposes.has(movement.movementPurpose);
}

function getMovementStateLabel(movement: MovementOrder) {
  if (movement.status === "pending_approval") {
    return "Esperando autorización";
  }

  if (movement.movementPurpose === "battle_return") {
    return "Retirada";
  }

  if (movement.movementPurpose === "route_fallback") {
    return "Repliegue de ruta";
  }

  if (movement.movementPurpose === "cancel_return") {
    return "Regresando";
  }

  if (movement.movementPurpose === "coalition_staging") {
    return "Reunión de coalición";
  }

  if (movement.movementPurpose === "defense_support") {
    return "Refuerzo defensivo";
  }

  if (movement.movementType === "attack" || movement.movementPurpose === "attack") {
    return "Ataque en marcha";
  }

  return "En movimiento";
}

function countMovementUnits(movements: MovementOrder[]) {
  return new Set(movements.flatMap((movement) => movement.unitIds)).size;
}

function compareMovements(left: MovementOrder, right: MovementOrder) {
  const leftTime = Date.parse(left.arrivalAt ?? left.startedAt);
  const rightTime = Date.parse(right.arrivalAt ?? right.startedAt);
  return leftTime - rightTime;
}

function compareUnits(left: CampaignUnit, right: CampaignUnit) {
  return left.name.localeCompare(right.name, "es") || left.id.localeCompare(right.id);
}
