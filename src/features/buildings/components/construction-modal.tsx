"use client";

import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Building2, Check, Clock3, Hammer, Lock, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceAmount, ResourceIcon } from "@/components/ui/resource-icon";
import { startBuildingConstruction, canUseBuildingRpc } from "@/features/buildings/api/building-api";
import {
  getBaseBuildingCost,
  getRequiredTechnologyName,
  getVisibleBuildingCostResources,
  isBuildingTemplateUnlocked
} from "@/features/technology/lib/technology-state";
import type { BuildingTemplate, CampaignSnapshot, FactionResources, ResourceKey, StarSystem } from "@/domain/campaign";

const visibleResources: ResourceKey[] = ["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium"];

export function ConstructionModal({
  snapshot,
  system,
  open,
  onClose
}: {
  snapshot: CampaignSnapshot;
  system: StarSystem | null;
  open: boolean;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const resources = snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
  const rpcReady = canUseBuildingRpc();
  const buildingSlots = system?.buildingSlots ?? (system?.isCapital ? 6 : 3);
  const systemBuildings = useMemo(
    () => snapshot.systemBuildings.filter((building) => building.systemId === system?.id && building.status !== "disabled"),
    [snapshot.systemBuildings, system?.id]
  );
  const availableBuildingTemplates = useMemo(
    () => snapshot.buildingTemplates.filter((template) => template.isAvailable),
    [snapshot.buildingTemplates]
  );
  const selectedTemplate =
    availableBuildingTemplates.find((template) => template.id === selectedTemplateId) ??
    availableBuildingTemplates[0] ??
    null;
  const selectedReason = system && selectedTemplate ? getBuildBlockReason(snapshot, system, selectedTemplate, resources) : "Sin sistema";
  const mutation = useMutation({
    mutationFn: () => {
      if (!system || !selectedTemplate) {
        throw new Error("Selecciona un edificio.");
      }

      return startBuildingConstruction(system.id, selectedTemplate.id);
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });

  if (!open || !system) {
    return null;
  }

  return (
    <div className="pointer-events-auto fixed inset-0 z-50 grid place-items-center bg-black/60 p-0 backdrop-blur-sm md:px-4 md:py-6">
      <Panel className="flex h-[var(--app-height)] w-full max-w-6xl flex-col overflow-hidden rounded-none md:h-auto md:max-h-[90vh] md:rounded-lg">
        <div className="shrink-0 border-b border-cyan-200/15 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:p-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="text-xs uppercase tracking-[0.24em] text-cyan-200/70">Construccion planetaria</div>
              <h2 className="mt-1 text-2xl font-semibold text-cyan-50">{system.name}</h2>
              <p className="mt-1 text-sm text-slate-400">
                Slots usados: {systemBuildings.length}/{buildingSlots}
              </p>
            </div>
            <Button aria-label="Cerrar construccion" onClick={onClose} size="icon" variant="ghost">
              <X size={18} />
            </Button>
          </div>
        </div>

        <div className="mobile-scroll flex-1 lg:grid lg:grid-cols-[1fr_340px] lg:overflow-hidden">
          <div className="p-4 md:p-5 lg:min-h-0 lg:overflow-y-auto">
            <ResourceSummary resources={resources} />

            {!rpcReady ? (
              <div className="mb-4 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
                Supabase no esta configurado. Puedes revisar edificios, pero no construir.
              </div>
            ) : null}

            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {availableBuildingTemplates.map((template) => {
                const selected = template.id === selectedTemplate?.id;
                const reason = getBuildBlockReason(snapshot, system, template, resources);
                const effectiveProduction = getEffectiveProductionAmount(snapshot, system.id, template);

                return (
                  <button
                    className={`rounded-lg border p-4 text-left transition ${
                      selected
                        ? "border-cyan-200/55 bg-cyan-300/12 shadow-[0_0_24px_rgba(34,211,238,0.14)]"
                        : reason
                          ? "border-slate-500/20 bg-slate-950/25 opacity-75 hover:border-violet-200/25"
                          : "border-cyan-200/15 bg-slate-950/35 hover:border-cyan-200/35"
                    }`}
                    key={template.id}
                    onClick={() => setSelectedTemplateId(template.id)}
                    type="button"
                  >
                    <div className="mb-3 flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="font-semibold text-cyan-50">{template.name}</div>
                        <div className="mt-1 text-xs text-slate-400">{template.category}</div>
                      </div>
                      <Badge tone={reason ? "slate" : getKindTone(template)}>{getKindLabel(template)}</Badge>
                    </div>

                    <p className="mb-3 line-clamp-2 text-xs leading-5 text-slate-300">{template.description}</p>

                    {template.producedResourceKey ? (
                      <div className="mb-3 rounded border border-cyan-200/10 bg-cyan-400/5 px-2 py-1.5 text-xs text-cyan-50">
                        Produccion en este sistema:{" "}
                        <ResourceAmount resource={template.producedResourceKey} value={effectiveProduction} />
                      </div>
                    ) : null}

                    <div className="mb-3 grid grid-cols-2 gap-2 text-xs">
                      {getVisibleBuildingCostResources(template).map((resource) => (
                        <span
                          className="inline-flex items-center justify-between gap-2 rounded border border-cyan-200/10 bg-slate-950/45 px-2 py-1 text-slate-200"
                          key={resource}
                        >
                          <ResourceIcon className="size-4" resource={resource} />
                          {getBaseBuildingCost(template, resource)}
                        </span>
                      ))}
                    </div>

                    <div className="flex items-center justify-between gap-3 text-xs text-slate-400">
                      <span className="inline-flex items-center gap-1.5">
                        <Clock3 size={13} />
                        {formatMinutes(template.constructionTimeSeconds)}
                      </span>
                      {reason ? (
                        <span className="inline-flex items-center gap-1 text-violet-100">
                          <Lock size={13} />
                          {reason}
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-cyan-100">
                          <Check size={13} />
                          Disponible
                        </span>
                      )}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <aside className="border-t border-cyan-200/15 bg-slate-950/35 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-4 md:p-5 lg:border-l lg:border-t-0">
            <div className="mb-4 grid size-12 place-items-center rounded-md border border-cyan-300/30 bg-cyan-400/10 text-cyan-100">
              <Hammer size={23} />
            </div>
            {selectedTemplate ? (
              <div className="space-y-4">
                <div>
                  <Badge tone={selectedReason ? "slate" : "cyan"}>{selectedReason ? "Bloqueado" : "Listo"}</Badge>
                  <h3 className="mt-3 text-xl font-semibold text-cyan-50">{selectedTemplate.name}</h3>
                  <p className="mt-2 text-sm leading-6 text-slate-300">{selectedTemplate.description}</p>
                </div>

                {selectedTemplate.producedResourceKey ? (
                  <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-200">
                    Produccion diaria:{" "}
                    <ResourceAmount
                      resource={selectedTemplate.producedResourceKey}
                      value={getEffectiveProductionAmount(snapshot, system.id, selectedTemplate)}
                    />
                  </div>
                ) : null}

                {selectedReason ? (
                  <div className="rounded-md border border-violet-300/25 bg-violet-400/10 p-3 text-sm text-violet-100">
                    {selectedReason}
                  </div>
                ) : null}

                {mutation.error ? <p className="text-sm text-rose-200">{mutation.error.message}</p> : null}

                <Button
                  className="sticky bottom-0 w-full"
                  disabled={!rpcReady || Boolean(selectedReason) || mutation.isPending}
                  onClick={() => mutation.mutate()}
                >
                  <Building2 size={16} />
                  {mutation.isPending ? "Iniciando..." : "Construir"}
                </Button>
              </div>
            ) : (
              <p className="text-sm text-slate-400">No hay edificios disponibles.</p>
            )}
          </aside>
        </div>
      </Panel>
    </div>
  );
}

function ResourceSummary({ resources }: { resources?: FactionResources }) {
  return (
    <div className="mb-4 grid grid-cols-6 gap-1.5 md:gap-2">
      {visibleResources.map((resource) => (
        <div className="min-w-0 rounded-md border border-cyan-200/15 bg-slate-950/45 px-1.5 py-2 text-center" key={resource}>
          <ResourceIcon className="mx-auto mb-1 size-4" resource={resource} />
          <div className="truncate text-[clamp(0.66rem,2.4vw,0.9rem)] font-semibold tabular-nums text-cyan-50">
            {formatCompactResource(resources?.[resource] ?? 0)}
          </div>
        </div>
      ))}
    </div>
  );
}

function getBuildBlockReason(
  snapshot: CampaignSnapshot,
  system: StarSystem,
  template: BuildingTemplate,
  resources?: FactionResources
) {
  if (system.systemKind === "gaseous") {
    return "Sistema gaseoso no edificable";
  }

  const currentBuildings = snapshot.systemBuildings.filter(
    (building) => building.systemId === system.id && building.status !== "disabled"
  );

  if (system.controllerFactionId !== snapshot.currentUser.factionId || system.status !== "controlled") {
    return "Sistema no controlado";
  }

  if (system.blockedUntil && new Date(system.blockedUntil).getTime() > Date.now()) {
    return "Sistema bloqueado";
  }

  const buildingSlots = system.buildingSlots ?? (system.isCapital ? 6 : 3);

  if (currentBuildings.length >= buildingSlots) {
    return "Sin slots";
  }

  if (currentBuildings.some((building) => building.buildingTemplateId === template.id)) {
    return "Ya construido";
  }

  if (!isBuildingTemplateUnlocked(snapshot, template)) {
    const requiredTechnology = template.requiredTechnologyNodeId
      ? snapshot.technologyNodes.find((node) => node.id === template.requiredTechnologyNodeId)
      : null;

    if (requiredTechnology?.implementationStatus === "planned") {
      return "Proximamente";
    }

    return `Requiere ${getRequiredTechnologyName(snapshot, template.requiredTechnologyNodeId)}`;
  }

  if (
    template.buildingKind === "production" &&
    template.producedResourceKey &&
    !system.isCapital &&
    !snapshot.systemResourceCapabilities.some(
      (capability) =>
        capability.systemId === system.id &&
        capability.resourceKey === template.producedResourceKey &&
        capability.productionAmount > 0
    )
  ) {
    return `Recurso no disponible`;
  }

  if (!resources || !getVisibleBuildingCostResources(template).every((resource) => resources[resource] >= getBaseBuildingCost(template, resource))) {
    return "Recursos insuficientes";
  }

  return null;
}

function getKindLabel(template: BuildingTemplate) {
  const labels: Record<BuildingTemplate["buildingKind"], string> = {
    recruitment: "Militar",
    commerce: "Comercio",
    intelligence: "Intel",
    production: "Produccion",
    relic: "Reliquias"
  };

  return labels[template.buildingKind];
}

function getKindTone(template: BuildingTemplate): "cyan" | "rose" | "amber" | "slate" | "violet" {
  if (template.buildingKind === "commerce") {
    return "amber";
  }

  if (template.buildingKind === "intelligence") {
    return "violet";
  }

  if (template.buildingKind === "relic") {
    return "violet";
  }

  if (template.buildingKind === "production") {
    return "cyan";
  }

  return "rose";
}

function getEffectiveProductionAmount(snapshot: CampaignSnapshot, systemId: string, template: BuildingTemplate) {
  if (!template.producedResourceKey) {
    return 0;
  }

  return (
    snapshot.systemResourceCapabilities.find(
      (capability) => capability.systemId === systemId && capability.resourceKey === template.producedResourceKey
    )?.productionAmount ?? 0
  );
}

function formatMinutes(seconds: number) {
  const minutes = Math.ceil(seconds / 60);
  return `${minutes} min`;
}

function formatCompactResource(value: number) {
  if (Math.abs(value) >= 1000000) {
    return `${(value / 1000000).toFixed(value >= 10000000 ? 0 : 1)}M`;
  }

  if (Math.abs(value) >= 1000) {
    return `${(value / 1000).toFixed(value >= 10000 ? 0 : 1)}k`;
  }

  return String(value);
}
