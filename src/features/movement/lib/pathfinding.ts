import type { StarSystem, SystemEdge } from "@/domain/campaign";

export const MOVEMENT_EDGE_DURATION_SECONDS = 120;

export type RoutePlan = {
  pathSystemIds: string[];
  uridiumCost: number;
  segmentCount: number;
  durationSeconds: number;
};

type FindRouteInput = {
  systems: StarSystem[];
  edges: SystemEdge[];
  originSystemId: string;
  targetSystemId: string;
  edgeDurationSeconds?: number;
};

export function findCheapestRoute({
  systems,
  edges,
  originSystemId,
  targetSystemId,
  edgeDurationSeconds = MOVEMENT_EDGE_DURATION_SECONDS
}: FindRouteInput): RoutePlan | null {
  if (originSystemId === targetSystemId) {
    return {
      pathSystemIds: [originSystemId],
      uridiumCost: 0,
      segmentCount: 0,
      durationSeconds: 0
    };
  }

  const systemById = new Map(systems.map((system) => [system.id, system]));
  const target = systemById.get(targetSystemId);

  if (!target || isSystemBlockedForMovement(target)) {
    return null;
  }

  const adjacency = buildAdjacency(systems, edges);
  const distances = new Map<string, number>([[originSystemId, 0]]);
  const previous = new Map<string, string>();
  const pending = new Set<string>(systems.map((system) => system.id));

  while (pending.size > 0) {
    let currentId: string | null = null;
    let currentDistance = Number.POSITIVE_INFINITY;

    for (const candidate of pending) {
      const distance = distances.get(candidate) ?? Number.POSITIVE_INFINITY;

      if (distance < currentDistance) {
        currentDistance = distance;
        currentId = candidate;
      }
    }

    if (!currentId || currentDistance === Number.POSITIVE_INFINITY) {
      break;
    }

    pending.delete(currentId);

    if (currentId === targetSystemId) {
      break;
    }

    for (const next of adjacency.get(currentId) ?? []) {
      const nextSystem = systemById.get(next.systemId);

      if (!nextSystem || (next.systemId !== originSystemId && isSystemBlockedForMovement(nextSystem))) {
        continue;
      }

      const nextDistance = currentDistance + next.cost;

      if (nextDistance < (distances.get(next.systemId) ?? Number.POSITIVE_INFINITY)) {
        distances.set(next.systemId, nextDistance);
        previous.set(next.systemId, currentId);
      }
    }
  }

  if (!distances.has(targetSystemId)) {
    return null;
  }

  const pathSystemIds: string[] = [];
  let cursor: string | undefined = targetSystemId;

  while (cursor) {
    pathSystemIds.unshift(cursor);

    if (cursor === originSystemId) {
      break;
    }

    cursor = previous.get(cursor);
  }

  if (pathSystemIds[0] !== originSystemId) {
    return null;
  }

  return calculateRoutePlan(pathSystemIds, edges, edgeDurationSeconds);
}

export function calculateRoutePlan(
  pathSystemIds: string[],
  edges: SystemEdge[],
  edgeDurationSeconds = MOVEMENT_EDGE_DURATION_SECONDS
): RoutePlan | null {
  if (pathSystemIds.length === 0) {
    return null;
  }

  let uridiumCost = 0;

  for (let index = 0; index < pathSystemIds.length - 1; index += 1) {
    const edge = getEdgeBetween(edges, pathSystemIds[index], pathSystemIds[index + 1]);

    if (!edge || edge.isBlocked) {
      return null;
    }

    uridiumCost += edge.uridiumCost;
  }

  const segmentCount = Math.max(pathSystemIds.length - 1, 0);

  return {
    pathSystemIds,
    uridiumCost,
    segmentCount,
    durationSeconds: segmentCount * edgeDurationSeconds
  };
}

export function canAppendManualStep(
  systems: StarSystem[],
  edges: SystemEdge[],
  pathSystemIds: string[],
  targetSystemId: string
) {
  const system = systems.find((item) => item.id === targetSystemId);
  const lastSystemId = pathSystemIds[pathSystemIds.length - 1];

  if (!system || !lastSystemId || isSystemBlockedForMovement(system)) {
    return false;
  }

  return Boolean(getEdgeBetween(edges, lastSystemId, targetSystemId));
}

export function isSystemBlockedForMovement(system: StarSystem) {
  if (system.status === "war") {
    return true;
  }

  if (!system.blockedUntil) {
    return false;
  }

  return new Date(system.blockedUntil).getTime() > Date.now();
}

export function getEdgeBetween(edges: SystemEdge[], fromSystemId: string, toSystemId: string) {
  return edges.find(
    (edge) =>
      (edge.fromSystemId === fromSystemId && edge.toSystemId === toSystemId) ||
      (edge.fromSystemId === toSystemId && edge.toSystemId === fromSystemId)
  );
}

export function formatTravelDuration(seconds: number) {
  const minutes = Math.ceil(seconds / 60);

  if (minutes < 60) {
    return `${minutes}m`;
  }

  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;

  return rest > 0 ? `${hours}h ${rest}m` : `${hours}h`;
}

function buildAdjacency(systems: StarSystem[], edges: SystemEdge[]) {
  const adjacency = new Map<string, Array<{ systemId: string; cost: number }>>();

  for (const system of systems) {
    adjacency.set(system.id, []);
  }

  for (const edge of edges) {
    if (edge.isBlocked) {
      continue;
    }

    adjacency.get(edge.fromSystemId)?.push({ systemId: edge.toSystemId, cost: edge.uridiumCost });
    adjacency.get(edge.toSystemId)?.push({ systemId: edge.fromSystemId, cost: edge.uridiumCost });
  }

  return adjacency;
}
