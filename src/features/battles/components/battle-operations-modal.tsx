"use client";

import { useEffect, useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, Check, Clock3, Flag, Route, Shield, Swords, UserPlus, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import type {
  BattleReport,
  BattleOperation,
  BattleOperationMember,
  BattleSide,
  CampaignSnapshot,
  CampaignUnit,
  Conflict,
  UnitMovementSelection
} from "@/domain/campaign";
import {
  cancelBattleOperation,
  inviteBattleSupport,
  joinBattleOperation,
  launchCoalitionAttack,
  respondBattleSupportInvitation
} from "@/features/battles/api/battle-operation-api";
import { canUseMovementRpc, respondMovementPassageRequest } from "@/features/movement/api/movement-api";
import { findCheapestRoute, formatTravelDuration } from "@/features/movement/lib/pathfinding";

type ActionInput =
  | { kind: "invite"; operationId: string; factionId: string; side: BattleSide }
  | { kind: "respond"; operationId: string; decision: "accepted" | "rejected" }
  | { kind: "launch"; operationId: string }
  | { kind: "cancel"; operationId: string };

export function BattleOperationsModal({
  open,
  snapshot,
  onClose
}: {
  open: boolean;
  snapshot: CampaignSnapshot;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const currentFactionId = snapshot.currentUser.factionId;
  const [inviteFactionByOperation, setInviteFactionByOperation] = useState<Record<string, string>>({});
  const [supportOperationId, setSupportOperationId] = useState<string | null>(null);
  const [supportOriginId, setSupportOriginId] = useState<string | null>(null);
  const [selectedUnitIds, setSelectedUnitIds] = useState<string[]>([]);
  const [clockMs, setClockMs] = useState(0);
  const movementRpcReady = canUseMovementRpc();
  const operations = snapshot.battleOperations.filter((operation) =>
    ["assembling", "moving", "in_battle"].includes(operation.status)
  );
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
  const supportOperation = operations.find((operation) => operation.id === supportOperationId) ?? null;
  const supportMember =
    supportOperation && currentFactionId
      ? snapshot.battleOperationMembers.find(
          (member) => member.operationId === supportOperation.id && member.factionId === currentFactionId
        ) ?? null
      : null;
  const supportDestinationId =
    supportOperation && supportMember
      ? supportMember.side === "attacker"
        ? supportOperation.originSystemId
        : supportOperation.targetSystemId
      : null;
  const originOptions = useMemo(() => {
    if (!currentFactionId) {
      return [];
    }

    const ids = new Set(
      snapshot.units
        .filter((unit) => unit.factionId === currentFactionId && unit.status === "ready" && unit.currentSystemId)
        .map((unit) => unit.currentSystemId as string)
    );

    return snapshot.systems.filter((system) => ids.has(system.id));
  }, [currentFactionId, snapshot.systems, snapshot.units]);
  const availableUnits = snapshot.units.filter(
    (unit) =>
      unit.factionId === currentFactionId &&
      unit.currentSystemId === supportOriginId &&
      unit.status === "ready" &&
      unit.quantity > 0
  );
  const supportRoute = getSupportRoute(snapshot, supportOperation, supportOriginId, supportDestinationId);
  const supportSecondsRemaining = supportOperation?.attackArrivalAt && clockMs > 0
    ? Math.max(0, Math.floor((Date.parse(supportOperation.attackArrivalAt) - clockMs) / 1000))
    : null;
  const arrivesInTime =
    supportMember?.side === "defender"
      ? Boolean(supportRoute && supportSecondsRemaining !== null && supportRoute.durationSeconds <= supportSecondsRemaining)
      : Boolean(supportRoute);
  const selectedSelections = availableUnits.flatMap<UnitMovementSelection>((unit) =>
    selectedUnitIds.includes(unit.id) ? [{ unitId: unit.id, quantity: unit.quantity }] : []
  );
  const actionMutation = useMutation({
    mutationFn: (input: ActionInput) => {
      if (input.kind === "invite") {
        return inviteBattleSupport(input.operationId, input.factionId, input.side);
      }

      if (input.kind === "respond") {
        return respondBattleSupportInvitation(input.operationId, input.decision);
      }

      if (input.kind === "launch") {
        return launchCoalitionAttack(input.operationId);
      }

      return cancelBattleOperation(input.operationId);
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const supportMutation = useMutation({
    mutationFn: () => {
      if (!supportOperation || !supportRoute) {
        throw new Error("No existe una ruta valida hasta el punto de reunion.");
      }

      return joinBattleOperation(supportOperation.id, selectedSelections, supportRoute.pathSystemIds);
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      setSupportOperationId(null);
      setSupportOriginId(null);
      setSelectedUnitIds([]);
    }
  });
  const passageMutation = useMutation({
    mutationFn: ({ requestId, decision }: { requestId: string; decision: "accepted" | "rejected" }) =>
      respondMovementPassageRequest(requestId, decision),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  useEffect(() => {
    if (!open || !supportOperation?.attackArrivalAt) {
      return;
    }

    const intervalId = window.setInterval(() => setClockMs(Date.now()), 1000);

    return () => window.clearInterval(intervalId);
  }, [open, supportOperation?.attackArrivalAt]);

  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/80 p-0 backdrop-blur-sm md:p-4">
      <Panel className="flex h-[var(--app-height)] w-full max-w-6xl flex-col overflow-hidden rounded-none md:h-auto md:max-h-[calc(var(--app-height)-2rem)] md:rounded-lg">
        <header className="flex shrink-0 items-center justify-between gap-3 border-b border-cyan-200/15 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:p-4">
          <div className="min-w-0">
            <div className="text-xs uppercase text-cyan-200/70">Mando operativo</div>
            <h2 className="mt-1 text-lg font-semibold text-cyan-50">Operaciones y avisos</h2>
          </div>
          <Button aria-label="Cerrar operaciones" onClick={onClose} size="icon" variant="ghost">
            <X size={17} />
          </Button>
        </header>

        <div className="mobile-scroll min-h-0 flex-1 p-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
          <div className="mb-4 grid gap-2 md:grid-cols-3">
            <TimingItem label="Ataques disponibles" value={formatBattleAvailability(snapshot.battleLimits, "attacker")} />
            <TimingItem label="Defensas disponibles" value={formatBattleAvailability(snapshot.battleLimits, "defender")} />
            <TimingItem label="Total disponible" value={formatBattleAvailability(snapshot.battleLimits, "total")} />
          </div>

          {supportOperation && supportMember?.side === "attacker" ? (
            <SupportComposer
              arrivesInTime={arrivesInTime}
              availableUnits={availableUnits}
              destinationName={
                snapshot.systems.find((system) => system.id === supportDestinationId)?.name ?? "Punto de reunion"
              }
              error={supportMutation.error?.message ?? null}
              isPending={supportMutation.isPending}
              onBack={() => {
                setSupportOperationId(null);
                setSupportOriginId(null);
                setSelectedUnitIds([]);
              }}
              onConfirm={() => supportMutation.mutate()}
              onSelectOrigin={(systemId) => {
                setSupportOriginId(systemId);
                setSelectedUnitIds([]);
              }}
              onToggleUnit={(unitId) =>
                setSelectedUnitIds((current) =>
                  current.includes(unitId) ? current.filter((id) => id !== unitId) : [...current, unitId]
                )
              }
              operation={supportOperation}
              originOptions={originOptions}
              route={supportRoute}
              selectedUnitIds={selectedUnitIds}
              selectedOriginId={supportOriginId}
              side={supportMember.side}
              snapshot={snapshot}
              secondsRemaining={supportSecondsRemaining}
            />
          ) : (
            <div className="grid gap-3">
              <NotificationsPanel
                movementRpcReady={movementRpcReady}
                onRespondPassage={(requestId, decision) => passageMutation.mutate({ requestId, decision })}
                passageError={passageMutation.error?.message ?? null}
                passagePending={passageMutation.isPending}
                pendingBattles={pendingBattles}
                pendingPassageRequests={pendingPassageRequests}
                pendingReports={pendingReports}
                snapshot={snapshot}
              />

              <div className="mt-1 flex items-center gap-2">
                <Swords size={15} className="text-cyan-100" />
                <h3 className="text-sm font-semibold text-cyan-50">Operaciones conjuntas activas</h3>
              </div>
              {operations.map((operation) => (
                <OperationCard
                  actionPending={actionMutation.isPending}
                  currentFactionId={currentFactionId}
                  inviteFactionId={inviteFactionByOperation[operation.id] ?? ""}
                  key={operation.id}
                  onAction={(input) => actionMutation.mutate(input)}
                  onChangeInviteFaction={(factionId) =>
                    setInviteFactionByOperation((current) => ({ ...current, [operation.id]: factionId }))
                  }
                  onPrepareSupport={() => {
                    setSupportOperationId(operation.id);
                    setSupportOriginId(operation.originSystemId);
                    setSelectedUnitIds([]);
                  }}
                  operation={operation}
                  snapshot={snapshot}
                />
              ))}

              {operations.length === 0 ? (
                <div className="rounded-md border border-slate-400/20 bg-slate-900/35 p-5 text-sm text-slate-400">
                  No tienes operaciones conjuntas activas.
                </div>
              ) : null}

              {actionMutation.error ? <p className="text-sm text-rose-200">{actionMutation.error.message}</p> : null}
            </div>
          )}
        </div>
      </Panel>
    </div>
  );
}

function OperationCard({
  operation,
  snapshot,
  currentFactionId,
  inviteFactionId,
  actionPending,
  onChangeInviteFaction,
  onPrepareSupport,
  onAction
}: {
  operation: BattleOperation;
  snapshot: CampaignSnapshot;
  currentFactionId: string | null;
  inviteFactionId: string;
  actionPending: boolean;
  onChangeInviteFaction: (factionId: string) => void;
  onPrepareSupport: () => void;
  onAction: (input: ActionInput) => void;
}) {
  const members = snapshot.battleOperationMembers.filter((member) => member.operationId === operation.id);
  const commitments = snapshot.battleUnitCommitments.filter((item) => item.operationId === operation.id);
  const currentMember = members.find((member) => member.factionId === currentFactionId) ?? null;
  const origin = snapshot.systems.find((system) => system.id === operation.originSystemId);
  const target = snapshot.systems.find((system) => system.id === operation.targetSystemId);
  const eligibleFactions = snapshot.factions.filter(
    (faction) => !faction.isNarrative && !members.some((member) => member.factionId === faction.id)
  );
  const canInviteAttackerStaging =
    currentMember?.role === "commander" &&
    currentMember.invitationStatus === "accepted" &&
    currentMember.side === "attacker" &&
    operation.status === "assembling";
  const canInviteDefensiveSupport =
    currentMember?.role === "commander" &&
    currentMember.invitationStatus === "accepted" &&
    currentMember.side === "defender" &&
    operation.status === "moving";
  const canInvite = canInviteAttackerStaging || canInviteDefensiveSupport;
  const hasOwnCommitment = commitments.some(
    (commitment) =>
      commitment.factionId === currentFactionId &&
      !["cancelled", "returned", "destroyed"].includes(commitment.status)
  );
  const canAcceptAttackerSupport =
    currentMember?.role === "supporter" &&
    currentMember.invitationStatus === "invited" &&
    currentMember.side === "attacker" &&
    operation.status === "assembling";
  const canMarkAttackerReady =
    currentMember?.role === "supporter" &&
    currentMember.invitationStatus === "accepted" &&
    currentMember.side === "attacker" &&
    operation.status === "assembling";
  const canAcceptDefensiveSupport =
    currentMember?.role === "supporter" &&
    currentMember.invitationStatus === "invited" &&
    currentMember.side === "defender" &&
    operation.status === "moving";
  const hasAcceptedDefensiveSupport =
    currentMember?.role === "supporter" &&
    currentMember.invitationStatus === "accepted" &&
    currentMember.side === "defender" &&
    operation.status === "moving";
  const readyUnitsAtOrigin = snapshot.units.filter(
    (unit) =>
      unit.factionId === currentFactionId &&
      unit.currentSystemId === operation.originSystemId &&
      unit.status === "ready" &&
      unit.quantity > 0
  );
  const pendingAttackerInvites = members.filter(
    (member) => member.side === "attacker" && member.role === "supporter" && member.invitationStatus === "invited"
  ).length;
  const waitingUnits = commitments.filter(
    (commitment) => commitment.side === "attacker" && commitment.status === "en_route"
  ).length;
  const acceptedAttackerSupportersWithoutCommitment = members.filter(
    (member) =>
      member.side === "attacker" &&
      member.role === "supporter" &&
      member.invitationStatus === "accepted" &&
      !commitments.some(
        (commitment) =>
          commitment.factionId === member.factionId &&
          commitment.side === "attacker" &&
          commitment.role === "supporter" &&
          !["cancelled", "returned", "destroyed"].includes(commitment.status)
      )
  ).length;
  const canLaunchCoalition =
    operation.status === "assembling" &&
    operation.leaderFactionId === currentFactionId &&
    waitingUnits === 0 &&
    pendingAttackerInvites === 0 &&
    acceptedAttackerSupportersWithoutCommitment === 0;

  return (
    <article className="rounded-md border border-cyan-200/15 bg-slate-950/40 p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="min-w-0 break-words font-semibold text-cyan-50">
              {origin?.name ?? "Origen"} {" -> "} {target?.name ?? "Objetivo"}
            </h3>
            <Badge tone={operation.status === "in_battle" ? "rose" : operation.status === "assembling" ? "amber" : "cyan"}>
              {operationStatusLabel(operation.status)}
            </Badge>
            <Badge tone="slate">{operation.mode === "coalition" ? "Coalicion" : "Individual"}</Badge>
          </div>
          <p className="mt-1 text-xs text-slate-400">
            {operation.attackArrivalAt
              ? `Cierre del plantel: ${new Date(operation.attackArrivalAt).toLocaleString()}`
              : "La salida se decide cuando las tropas aliadas esten reunidas."}
          </p>
        </div>
        <div className="shrink-0 text-left text-xs text-slate-400 sm:text-right">
          <div>{commitments.length} unidades comprometidas</div>
          <div>{commitments.reduce((total, item) => total + item.pointsAtCommitment, 0)} pts actuales</div>
        </div>
      </div>

      <div className="mt-4 grid gap-2 md:grid-cols-2">
        {(["attacker", "defender"] as const).map((side) => (
          <div className="rounded-md border border-cyan-200/10 bg-slate-950/35 p-3" key={side}>
            <div className="mb-2 flex items-center gap-2 text-xs font-semibold text-slate-200">
              {side === "attacker" ? <Swords size={14} /> : <Shield size={14} />}
              {side === "attacker" ? "Bando atacante" : "Bando defensor"}
            </div>
            <div className="flex flex-wrap gap-1.5">
              {members
                .filter((member) => member.side === side)
                .map((member) => (
                  <Badge key={member.id} tone={member.invitationStatus === "accepted" ? "cyan" : "amber"}>
                    {snapshot.factions.find((faction) => faction.id === member.factionId)?.name ?? "Faccion"} -{" "}
                    {invitationLabel(member)}
                  </Badge>
                ))}
            </div>
          </div>
        ))}
      </div>

      <div className="mt-3 grid gap-2 text-xs sm:grid-cols-2 xl:grid-cols-3">
        {commitments.map((commitment) => {
          const unit = snapshot.units.find((item) => item.id === commitment.unitId);
          const faction = snapshot.factions.find((item) => item.id === commitment.factionId);

          return (
            <div className="rounded-md border border-slate-400/15 bg-slate-900/35 p-2.5" key={commitment.id}>
              <div className="break-words font-medium text-slate-100">{unit?.name ?? "Unidad comprometida"}</div>
              <div className="mt-1 text-slate-400">
                {faction?.name ?? "Faccion"} - {commitment.pointsAtCommitment} pts - {commitmentStatusLabel(commitment.status)}
              </div>
            </div>
          );
        })}
      </div>

      {canAcceptAttackerSupport ? (
        <div className="mt-4 grid gap-2 sm:grid-cols-2">
          <Button
            disabled={actionPending}
            onClick={() => onAction({ kind: "respond", operationId: operation.id, decision: "accepted" })}
            size="sm"
          >
            <Check size={15} />
            Aceptar coalicion
          </Button>
          <Button
            disabled={actionPending}
            onClick={() => onAction({ kind: "respond", operationId: operation.id, decision: "rejected" })}
            size="sm"
            variant="danger"
          >
            <X size={15} />
            Rechazar
          </Button>
        </div>
      ) : canMarkAttackerReady && !hasOwnCommitment ? (
        <div className="mt-4 rounded-md border border-cyan-200/15 bg-cyan-300/10 p-3 text-xs text-cyan-50">
          <div>
            Coalicion aceptada. Mueve tus tropas al sistema de salida y marca listo cuando quieras comprometerlas.
          </div>
          <Button
            className="mt-3 w-full"
            disabled={actionPending || readyUnitsAtOrigin.length === 0}
            onClick={onPrepareSupport}
            size="sm"
          >
            <Check size={15} />
            {readyUnitsAtOrigin.length > 0 ? "Marcar tropas listas" : "Sin tropas en el punto de salida"}
          </Button>
        </div>
      ) : canAcceptDefensiveSupport ? (
        <div className="mt-4 grid gap-2 sm:grid-cols-2">
          <Button
            disabled={actionPending}
            onClick={() => onAction({ kind: "respond", operationId: operation.id, decision: "accepted" })}
            size="sm"
          >
            <Check size={15} />
            Aceptar apoyo
          </Button>
          <Button
            disabled={actionPending}
            onClick={() => onAction({ kind: "respond", operationId: operation.id, decision: "rejected" })}
            size="sm"
            variant="danger"
          >
            <X size={15} />
            Rechazar
          </Button>
        </div>
      ) : hasAcceptedDefensiveSupport ? (
        <div className="mt-4 rounded-md border border-cyan-200/15 bg-cyan-300/10 p-3 text-xs text-cyan-50">
          Apoyo aceptado. Mueve tus tropas al sistema objetivo antes de la llegada del ataque; las unidades presentes
          cuando cierre el plantel se sumaran a la defensa.
        </div>
      ) : currentMember?.role === "supporter" && currentMember.invitationStatus === "invited" ? (
        <div className="mt-4 rounded-md border border-amber-300/20 bg-amber-300/10 p-3 text-xs text-amber-100">
          La ventana de esta invitacion ya esta cerrada. Los atacantes no pueden anadir tropas una vez el ataque ha
          salido; solo el defensor puede traer refuerzos antes de que cierre el plantel.
        </div>
      ) : null}

      {canInvite ? (
        <div className="mt-4 flex flex-col gap-2 border-t border-cyan-200/10 pt-4 sm:flex-row">
          <select
            className="min-w-0 flex-1 rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
            onChange={(event) => onChangeInviteFaction(event.target.value)}
            value={inviteFactionId}
          >
            <option value="">Seleccionar faccion de apoyo</option>
            {eligibleFactions.map((faction) => (
              <option key={faction.id} value={faction.id}>
                {faction.name}
              </option>
            ))}
          </select>
          <Button
            disabled={!inviteFactionId || actionPending}
            onClick={() =>
              onAction({
                kind: "invite",
                operationId: operation.id,
                factionId: inviteFactionId,
                side: currentMember.side
              })
            }
            size="sm"
          >
            <UserPlus size={15} />
            {canInviteAttackerStaging ? "Invitar a coalicion" : "Invitar defensa"}
          </Button>
        </div>
      ) : null}

      {operation.status === "assembling" && operation.leaderFactionId === currentFactionId ? (
        <div className="mt-4 grid gap-2 sm:grid-cols-2">
          <Button
            disabled={!canLaunchCoalition || actionPending}
            onClick={() => onAction({ kind: "launch", operationId: operation.id })}
            size="sm"
            variant="danger"
          >
            <Flag size={15} />
            {waitingUnits > 0
              ? `${waitingUnits} en camino`
              : pendingAttackerInvites > 0
                ? `${pendingAttackerInvites} invitaciones pendientes`
                : acceptedAttackerSupportersWithoutCommitment > 0
                  ? `${acceptedAttackerSupportersWithoutCommitment} aliados sin listo`
                  : "Lanzar coalicion"}
          </Button>
          <Button
            disabled={actionPending}
            onClick={() => onAction({ kind: "cancel", operationId: operation.id })}
            size="sm"
            variant="ghost"
          >
            Cancelar reunion
          </Button>
        </div>
      ) : null}
    </article>
  );
}

function SupportComposer({
  snapshot,
  operation,
  side,
  destinationName,
  originOptions,
  selectedOriginId,
  availableUnits,
  selectedUnitIds,
  route,
  arrivesInTime,
  secondsRemaining,
  isPending,
  error,
  onSelectOrigin,
  onToggleUnit,
  onConfirm,
  onBack
}: {
  snapshot: CampaignSnapshot;
  operation: BattleOperation;
  side: BattleSide;
  destinationName: string;
  originOptions: CampaignSnapshot["systems"];
  selectedOriginId: string | null;
  availableUnits: CampaignSnapshot["units"];
  selectedUnitIds: string[];
  route: ReturnType<typeof findCheapestRoute>;
  arrivesInTime: boolean;
  secondsRemaining: number | null;
  isPending: boolean;
  error: string | null;
  onSelectOrigin: (systemId: string | null) => void;
  onToggleUnit: (unitId: string) => void;
  onConfirm: () => void;
  onBack: () => void;
}) {
  const routeNames =
    route?.pathSystemIds.map((id) => snapshot.systems.find((system) => system.id === id)?.name ?? id).join(" -> ") ??
    "Sin ruta";
  const selectedUnitCount = selectedUnitIds.length;
  const currentResources = snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
  const totalUridiumCost = route ? route.uridiumCost * selectedUnitCount : 0;
  const hasEnoughUridium = Boolean(route && currentResources && currentResources.uridium >= totalUridiumCost);

  return (
    <div>
      <div className="mb-4 flex items-center justify-between gap-3">
        <div>
          <div className="text-xs uppercase text-cyan-200/70">
            {side === "attacker" ? "Tropas listas para la coalicion" : "Refuerzo defensivo"}
          </div>
          <h3 className="mt-1 text-lg font-semibold text-cyan-50">{destinationName}</h3>
        </div>
        <Button onClick={onBack} size="sm" variant="ghost">
          Volver
        </Button>
      </div>

      <div className="grid gap-4 lg:grid-cols-[280px_1fr]">
        <aside>
          {side === "attacker" ? (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/40 p-3 text-sm text-cyan-50">
              Punto de salida confirmado
              <div className="mt-1 text-xs text-slate-400">{destinationName}</div>
            </div>
          ) : (
            <label className="text-sm text-slate-300">
              Planeta de origen
              <select
                className="mt-2 w-full rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
                onChange={(event) => onSelectOrigin(event.target.value || null)}
                value={selectedOriginId ?? ""}
              >
                <option value="">Selecciona origen</option>
                {originOptions.map((system) => (
                  <option key={system.id} value={system.id}>
                    {system.name}
                  </option>
                ))}
              </select>
            </label>
          )}

          <div className="mt-4 rounded-md border border-cyan-200/15 bg-slate-950/40 p-3 text-xs text-slate-300">
            <div className="break-words font-medium text-cyan-50">{routeNames}</div>
            <div className="mt-2 flex items-center gap-2">
              <Clock3 size={14} />
              {route ? formatTravelDuration(route.durationSeconds) : "Ruta no disponible"}
            </div>
            <div className={hasEnoughUridium ? "mt-1 text-slate-300" : "mt-1 text-rose-200"}>
              Coste: {formatResourceValue(totalUridiumCost)} / {formatResourceValue(currentResources?.uridium ?? 0)} Uridium
            </div>
            {route && selectedUnitCount > 1 ? (
              <div className="mt-1 text-slate-500">
                Ruta {route.uridiumCost} x {selectedUnitCount} unidades
              </div>
            ) : null}
            {operation.attackArrivalAt && side === "defender" ? (
              <div className="mt-1 text-slate-400">
                Plantel cierra en: {formatTravelDuration(secondsRemaining ?? 0)}
              </div>
            ) : null}
            {operation.attackArrivalAt && side === "defender" ? (
              <div className={arrivesInTime ? "mt-2 text-cyan-100" : "mt-2 text-rose-200"}>
                {arrivesInTime ? "Llegan antes del cierre." : "Llegarian despues del ataque."}
              </div>
            ) : side === "attacker" ? (
              <div className="mt-2 text-amber-100">
                Estas unidades se comprometeran para el ataque. Cuando todos los aliados aceptados esten listos, el
                comandante podra lanzar la coalicion.
              </div>
            ) : null}
          </div>
        </aside>

        <div>
          <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
            {availableUnits.map((unit) => {
              const selected = selectedUnitIds.includes(unit.id);

              return (
                <button
                  className={`rounded-md border p-3 text-left ${
                    selected
                      ? "border-cyan-200/55 bg-cyan-300/10"
                      : "border-cyan-200/15 bg-slate-950/35"
                  }`}
                  key={unit.id}
                  onClick={() => onToggleUnit(unit.id)}
                  type="button"
                >
                  <div className="break-words font-medium text-slate-100">{unit.name}</div>
                  <div className="mt-1 text-xs text-slate-400">
                    {unit.quantity} miniaturas - {unit.points} pts de ficha
                  </div>
                </button>
              );
            })}
          </div>

          {selectedOriginId && availableUnits.length === 0 ? (
            <p className="text-sm text-slate-400">No hay unidades listas en este planeta.</p>
          ) : null}

          {error ? <p className="mt-3 text-sm text-rose-200">{error}</p> : null}

          <Button
            className="mt-4 w-full"
            disabled={!route || !arrivesInTime || selectedUnitIds.length === 0 || !hasEnoughUridium || isPending}
            onClick={onConfirm}
          >
            <Route size={16} />
            {isPending
              ? "Comprometiendo tropas..."
            : side === "attacker"
                ? "Marcar listo"
                : "Enviar refuerzo defensivo"}
          </Button>
        </div>
      </div>
    </div>
  );
}

function TimingItem({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-cyan-200/15 bg-slate-950/40 p-3">
      <div className="text-xs text-slate-400">{label}</div>
      <div className="mt-1 text-sm font-semibold text-cyan-50">{value}</div>
    </div>
  );
}

function NotificationsPanel({
  snapshot,
  pendingPassageRequests,
  pendingBattles,
  pendingReports,
  movementRpcReady,
  passagePending,
  passageError,
  onRespondPassage
}: {
  snapshot: CampaignSnapshot;
  pendingPassageRequests: CampaignSnapshot["passageRequests"];
  pendingBattles: CampaignSnapshot["conflicts"];
  pendingReports: CampaignSnapshot["battleReports"];
  movementRpcReady: boolean;
  passagePending: boolean;
  passageError: string | null;
  onRespondPassage: (requestId: string, decision: "accepted" | "rejected") => void;
}) {
  const total = pendingPassageRequests.length + pendingBattles.length + pendingReports.length;

  return (
    <section className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-4">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <AlertTriangle size={15} className="text-amber-100" />
          <h3 className="text-sm font-semibold text-cyan-50">Notificaciones pendientes</h3>
        </div>
        <Badge tone={total > 0 ? "amber" : "slate"}>{total} avisos</Badge>
      </div>

      <div className="grid gap-3">
        {pendingPassageRequests.map((request) => {
          const movement = snapshot.movements.find((item) => item.id === request.movementOrderId);
          const requester = snapshot.factions.find((item) => item.id === movement?.factionId);
          const origin = snapshot.systems.find((item) => item.id === movement?.fromSystemId);
          const destination = snapshot.systems.find((item) => item.id === movement?.toSystemId);
          const routeText = movement?.pathSystemIds
            .map((systemId) => snapshot.systems.find((system) => system.id === systemId)?.name ?? systemId)
            .join(" -> ");
          const traversedText = request.traversedSystemIds
            .map((systemId) => snapshot.systems.find((system) => system.id === systemId)?.name ?? systemId)
            .join(", ");
          const visibleUnits = movement?.unitSelections
            .map((selection) => {
              const unit = snapshot.units.find((item) => item.id === selection.unitId);
              return unit ? `${unit.name} x${selection.quantity}` : `Unidad oculta x${selection.quantity}`;
            })
            .join(", ");

          return (
            <article className="rounded-md border border-amber-300/25 bg-amber-300/10 p-3" key={request.id}>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-medium text-amber-50">{requester?.name ?? "Faccion solicitante"}</span>
                <Badge tone="amber">Permiso de paso/estancia</Badge>
              </div>
              <p className="mt-1 text-xs text-amber-50/80">
                {origin?.name ?? "Origen"} {" -> "} {destination?.name ?? "Destino"}
              </p>
              <p className="mt-2 break-words text-xs text-slate-300">Ruta: {routeText ?? "No disponible"}</p>
              <p className="mt-1 text-xs text-slate-300">Tu territorio implicado: {traversedText || "No disponible"}</p>
              <p className="mt-1 text-xs text-slate-400">
                Unidades: {visibleUnits || "Informacion no revelada"}
              </p>
              <div className="mt-3 grid grid-cols-2 gap-2">
                <Button
                  disabled={!movementRpcReady || passagePending}
                  onClick={() => onRespondPassage(request.id, "accepted")}
                  size="sm"
                >
                  Aceptar
                </Button>
                <Button
                  disabled={!movementRpcReady || passagePending}
                  onClick={() => onRespondPassage(request.id, "rejected")}
                  size="sm"
                  variant="danger"
                >
                  Rechazar
                </Button>
              </div>
            </article>
          );
        })}

        {pendingBattles.map((conflict) => {
          const system = snapshot.systems.find((item) => item.id === conflict.systemId);
          const currentFactionId = snapshot.currentUser.factionId;
          const isAttacker = conflict.attackerFactionId === currentFactionId;
          const rivalFactionId = isAttacker ? conflict.defenderFactionId : conflict.attackerFactionId;
          const rival = snapshot.factions.find((item) => item.id === rivalFactionId);

          return (
            <article className="rounded-md border border-rose-300/25 bg-rose-400/10 p-3" key={conflict.id}>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-medium text-rose-50">{system?.name ?? "Sistema en conflicto"}</span>
                <Badge tone="rose">{isAttacker ? "Atacante" : "Defensor"}</Badge>
              </div>
              <p className="mt-1 text-xs text-rose-100/80">Rival: {rival?.name ?? "Fuerza desconocida"}</p>
              <p className="mt-1 text-xs text-slate-400">
                Estado: pendiente de batalla fisica o reporte. Bloqueo: {formatConflictTimer(conflict.blockedUntil)}
              </p>
            </article>
          );
        })}

        {pendingReports.map((report) => {
          const conflict = snapshot.conflicts.find((item) => item.id === report.conflictId);
          const system = conflict ? snapshot.systems.find((item) => item.id === conflict.systemId) : null;
          const winner = report.winnerFactionId
            ? snapshot.factions.find((item) => item.id === report.winnerFactionId)?.name
            : null;

          return (
            <article className="rounded-md border border-cyan-200/15 bg-cyan-300/8 p-3" key={report.id}>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-medium text-cyan-50">{system?.name ?? "Reporte de batalla"}</span>
                <Badge tone={getBattleReportStatusTone(report)}>{getBattleReportStatusLabel(report)}</Badge>
              </div>
              <p className="mt-1 text-xs text-slate-300">
                Resultado declarado: {winner ?? "sin ganador indicado"}. Esperando validacion de los participantes.
              </p>
              {report.narrativeNotes ? (
                <p className="mt-1 line-clamp-2 text-xs text-slate-500">{report.narrativeNotes}</p>
              ) : null}
            </article>
          );
        })}

        {total === 0 ? (
          <div className="rounded-md border border-slate-400/20 bg-slate-900/35 p-4 text-sm text-slate-400">
            No hay avisos pendientes por resolver.
          </div>
        ) : null}
        {passageError ? <p className="text-sm text-rose-200">{passageError}</p> : null}
      </div>
    </section>
  );
}

function formatBattleAvailability(
  limits: CampaignSnapshot["battleLimits"],
  kind: "attacker" | "defender" | "total"
) {
  if (!limits) {
    return "Sin datos";
  }

  if (kind === "attacker") {
    return `${Math.max(0, limits.maxStartedAttacks - limits.startedAttacks)} / ${limits.maxStartedAttacks}`;
  }

  if (kind === "defender") {
    return `${Math.max(0, limits.maxReceivedAttacks - limits.receivedAttacks)} / ${limits.maxReceivedAttacks}`;
  }

  return `${Math.max(0, limits.maxTotalParticipations - limits.totalParticipations)} / ${limits.maxTotalParticipations}`;
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

function getBattleReportStatusLabel(report: BattleReport) {
  const labels: Record<BattleReport["status"], string> = {
    draft: "Borrador",
    awaiting_validation: "Pendiente de validar",
    players_confirmed: "Validado por jugadores",
    submitted: "Enviado",
    auto_confirmed: "Confirmado",
    admin_confirmed: "Resuelto",
    disputed: "En disputa",
    rejected: "Rechazado"
  };

  return labels[report.status];
}

function getBattleReportStatusTone(report: BattleReport): "cyan" | "rose" | "amber" | "slate" | "violet" {
  if (report.status === "players_confirmed" || report.status === "admin_confirmed" || report.status === "auto_confirmed") {
    return "cyan";
  }

  if (report.status === "disputed" || report.status === "rejected") {
    return "rose";
  }

  return "amber";
}

function formatResourceValue(value: number) {
  if (Number.isInteger(value)) {
    return value.toLocaleString("es-ES");
  }

  return value.toLocaleString("es-ES", { maximumFractionDigits: 2 });
}

function formatConflictTimer(blockedUntil?: string | null) {
  if (!blockedUntil) {
    return "sin cierre";
  }

  const timestamp = Date.parse(blockedUntil);

  if (Number.isNaN(timestamp)) {
    return "sin cierre";
  }

  return timestamp <= Date.now() ? "Expirado" : new Date(blockedUntil).toLocaleString();
}

function invitationLabel(member: BattleOperationMember) {
  if (member.role === "commander") {
    return "mando";
  }

  const labels: Record<BattleOperationMember["invitationStatus"], string> = {
    invited: "invitada",
    accepted: "confirmada",
    rejected: "rechazada",
    closed: "cerrada"
  };

  return labels[member.invitationStatus];
}

function operationStatusLabel(status: BattleOperation["status"]) {
  const labels: Record<BattleOperation["status"], string> = {
    assembling: "Reuniendo",
    moving: "Ataque en camino",
    in_battle: "Plantel cerrado",
    resolved: "Resuelta",
    cancelled: "Cancelada"
  };

  return labels[status];
}

function commitmentStatusLabel(status: CampaignSnapshot["battleUnitCommitments"][number]["status"]) {
  const labels: Record<CampaignSnapshot["battleUnitCommitments"][number]["status"], string> = {
    staged: "reunida",
    en_route: "en camino",
    in_battle: "en batalla",
    returning: "regresando",
    returned: "devuelta",
    destroyed: "destruida",
    cancelled: "cancelada",
    return_pending: "retirada pendiente"
  };

  return labels[status];
}

function getSupportRoute(
  snapshot: CampaignSnapshot,
  operation: BattleOperation | null,
  originSystemId: string | null,
  destinationSystemId: string | null
) {
  if (!operation || !originSystemId || !destinationSystemId) {
    return null;
  }

  const acceptedFactionIds = new Set(
    snapshot.battleOperationMembers
      .filter(
        (member) =>
          member.operationId === operation.id &&
          member.invitationStatus === "accepted"
      )
      .map((member) => member.factionId)
  );
  const allowedSystemIds = new Set(
    snapshot.systems
      .filter(
        (system) =>
          !system.controllerFactionId ||
          acceptedFactionIds.has(system.controllerFactionId) ||
          system.id === originSystemId ||
          system.id === destinationSystemId
      )
      .map((system) => system.id)
  );
  const allowedEdges = snapshot.edges.filter(
    (edge) => allowedSystemIds.has(edge.fromSystemId) && allowedSystemIds.has(edge.toSystemId)
  );

  return findCheapestRoute({
    systems: snapshot.systems,
    edges: allowedEdges,
    originSystemId,
    targetSystemId: destinationSystemId,
    edgeDurationSeconds: snapshot.movementEdgeDurationSeconds
  });
}
