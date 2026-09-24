import type { CampaignSnapshot, CampaignUnit, MovementOrder } from "@/domain/campaign";

export type UnitOperationalTone = "cyan" | "rose" | "amber" | "slate" | "violet";

export type UnitOperationalState = {
  label: string;
  detail: string;
  targetAt?: string | null;
  tone: UnitOperationalTone;
  priority: number;
};

const activeMovementStatuses = new Set<MovementOrder["status"]>(["pending_approval", "moving"]);

export function buildActiveMovementByUnitId(movements: MovementOrder[]) {
  const result = new Map<string, MovementOrder>();
  const activeMovements = movements
    .filter((movement) => activeMovementStatuses.has(movement.status))
    .sort((left, right) => Date.parse(right.startedAt) - Date.parse(left.startedAt));

  for (const movement of activeMovements) {
    for (const unitId of movement.unitIds) {
      if (!result.has(unitId)) {
        result.set(unitId, movement);
      }
    }
  }

  return result;
}

export function getUnitOperationalState(
  snapshot: CampaignSnapshot,
  unit: CampaignUnit,
  movement = findActiveMovement(snapshot.movements, unit.id)
): UnitOperationalState {
  const systemById = new Map(snapshot.systems.map((system) => [system.id, system]));
  const currentSystemName = unit.currentSystemId
    ? systemById.get(unit.currentSystemId)?.name ?? "Sistema desconocido"
    : "Sin posición registrada";

  if (unit.status === "in_war") {
    return {
      label: "En batalla",
      detail: currentSystemName,
      tone: "rose",
      priority: 1
    };
  }

  const recovery = snapshot.unitRecoveryQueue.find(
    (item) => item.campaignUnitId === unit.id && item.status === "queued"
  );

  if (recovery || unit.status === "recovering") {
    const building = recovery
      ? snapshot.systemBuildings.find((item) => item.id === recovery.systemBuildingId)
      : null;
    const recoverySystemName = building
      ? systemById.get(building.systemId)?.name ?? currentSystemName
      : currentSystemName;

    return {
      label: "Reabasteciendo",
      detail: recoverySystemName,
      targetAt: recovery?.finishesAt ?? null,
      tone: "violet",
      priority: 2
    };
  }

  if (movement) {
    const originName = systemById.get(movement.fromSystemId)?.name ?? "Origen desconocido";
    const destinationName = systemById.get(movement.toSystemId)?.name ?? "Destino desconocido";

    return {
      label: getMovementLabel(movement),
      detail: `${originName} → ${destinationName}`,
      targetAt: movement.status === "moving" ? movement.arrivalAt : null,
      tone: movement.movementType === "attack" ? "rose" : movement.status === "pending_approval" ? "amber" : "cyan",
      priority: 0
    };
  }

  if (unit.status === "retreat_pending") {
    return {
      label: "Retirada pendiente",
      detail: currentSystemName,
      tone: "violet",
      priority: 0
    };
  }

  if (unit.status === "moving") {
    return {
      label: "En tránsito",
      detail: "Ruta en curso",
      tone: "amber",
      priority: 0
    };
  }

  return {
    label: "Disponible",
    detail: currentSystemName,
    tone: "cyan",
    priority: 3
  };
}

export function getRecruitmentSystemName(snapshot: CampaignSnapshot, originSystemId?: string | null, buildingId?: string | null) {
  const buildingSystemId = buildingId
    ? snapshot.systemBuildings.find((building) => building.id === buildingId)?.systemId
    : null;
  const systemId = originSystemId ?? buildingSystemId;

  return systemId
    ? snapshot.systems.find((system) => system.id === systemId)?.name ?? "Sistema desconocido"
    : "Ubicación pendiente";
}

function findActiveMovement(movements: MovementOrder[], unitId: string) {
  return movements
    .filter((movement) => activeMovementStatuses.has(movement.status) && movement.unitIds.includes(unitId))
    .sort((left, right) => Date.parse(right.startedAt) - Date.parse(left.startedAt))[0] ?? null;
}

function getMovementLabel(movement: MovementOrder) {
  if (movement.status === "pending_approval") {
    return "Esperando autorización";
  }

  if (movement.movementPurpose === "battle_return") {
    return "En retirada";
  }

  if (movement.movementPurpose === "route_fallback") {
    return "Replegándose por la ruta";
  }

  if (movement.movementPurpose === "coalition_staging") {
    return "Reuniéndose para atacar";
  }

  if (movement.movementPurpose === "defense_support") {
    return "Refuerzo defensivo";
  }

  if (movement.movementType === "attack") {
    return "Ataque en marcha";
  }

  return "En movimiento";
}
