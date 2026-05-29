"use client";

import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Clock3, Minus, Plus, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceAmount, ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import { canUseRecruitmentRpc, recruitUnit } from "@/features/recruitment/api/recruitment-api";
import { formatCountdown } from "@/lib/time";
import type { CampaignSnapshot, FactionResources, ResourceKey, UnitTemplate } from "@/domain/campaign";

const costResources = ["supply", "minerals", "ancestralStone", "uridium"] as const;

export function RecruitmentModal({
  snapshot,
  open,
  onClose
}: {
  snapshot: CampaignSnapshot;
  open: boolean;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [quantity, setQuantity] = useState(1);
  const ownFaction = snapshot.factions.find((faction) => faction.id === snapshot.currentUser.factionId);
  const resources = snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
  const templates = useMemo(
    () =>
      snapshot.unitTemplates.filter(
        (template) => template.factionId === snapshot.currentUser.factionId && template.isAvailable
      ),
    [snapshot.currentUser.factionId, snapshot.unitTemplates]
  );
  const selectedTemplate = templates.find((template) => template.id === selectedTemplateId) ?? templates[0] ?? null;
  const queue = snapshot.recruitmentQueue.filter((item) => item.factionId === snapshot.currentUser.factionId);
  const rpcReady = canUseRecruitmentRpc();
  const hasResources = selectedTemplate && resources ? canAfford(resources, selectedTemplate, quantity) : false;

  const mutation = useMutation({
    mutationFn: () => {
      if (!selectedTemplate) {
        throw new Error("Selecciona una unidad.");
      }

      return recruitUnit(selectedTemplate.id, quantity);
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  if (!open) {
    return null;
  }

  return (
    <div className="pointer-events-auto fixed inset-0 z-40 grid place-items-center bg-black/58 px-4 py-6 backdrop-blur-sm">
      <Panel className="flex max-h-[88vh] w-full max-w-5xl flex-col overflow-hidden">
        <div className="flex items-center justify-between gap-4 border-b border-cyan-200/15 p-5">
          <div>
            <div className="text-xs uppercase tracking-[0.24em] text-cyan-200/70">Reclutamiento orbital</div>
            <h2 className="mt-1 text-2xl font-semibold text-cyan-50">{ownFaction?.name ?? "Facción"}</h2>
          </div>
          <Button aria-label="Cerrar reclutamiento" onClick={onClose} size="icon" variant="ghost">
            <X size={18} />
          </Button>
        </div>

        <div className="grid min-h-0 flex-1 gap-0 overflow-hidden lg:grid-cols-[1fr_320px]">
          <div className="min-h-0 overflow-y-auto p-5">
            <ResourceSummary resources={resources} />

            {!rpcReady ? (
              <div className="mb-4 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
                Supabase no está configurado. Puedes revisar el catálogo, pero no confirmar reclutamientos.
              </div>
            ) : null}

            <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
              {templates.map((template) => {
                const selected = template.id === selectedTemplate?.id;
                const affordable = resources ? canAfford(resources, template, quantity) : false;

                return (
                  <button
                    className={`rounded-lg border p-4 text-left transition ${
                      selected
                        ? "border-cyan-200/55 bg-cyan-300/12 shadow-[0_0_24px_rgba(34,211,238,0.14)]"
                        : "border-cyan-200/15 bg-slate-950/35 hover:border-cyan-200/35"
                    }`}
                    key={template.id}
                    onClick={() => setSelectedTemplateId(template.id)}
                    type="button"
                  >
                    <div className="mb-3 flex items-start justify-between gap-3">
                      <div>
                        <div className="font-semibold text-cyan-50">{template.name}</div>
                        <div className="mt-1 text-xs text-slate-400">{template.points} pts</div>
                      </div>
                      <Badge tone={affordable ? "cyan" : "rose"}>{template.category}</Badge>
                    </div>

                    <div className="mb-3 grid grid-cols-2 gap-2 text-xs">
                      {costResources.map((resource) => (
                        <CostPill
                          key={resource}
                          resource={resource}
                          value={getTemplateCost(template, resource)}
                        />
                      ))}
                    </div>

                    <div className="flex items-center justify-between gap-3 text-xs text-slate-400">
                      <span className="inline-flex items-center gap-1.5">
                        <Clock3 size={13} />
                        {formatDuration(template.recruitmentTimeSeconds)}
                      </span>
                      <span>{template.notes}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <aside className="flex min-h-0 flex-col border-t border-cyan-200/15 bg-slate-950/32 lg:border-l lg:border-t-0">
            <div className="border-b border-cyan-200/15 p-5">
              <h3 className="text-sm font-semibold text-cyan-50">Confirmación</h3>
              {selectedTemplate ? (
                <div className="mt-4 space-y-4">
                  <div>
                    <div className="text-lg font-semibold text-slate-100">{selectedTemplate.name}</div>
                    <div className="mt-1 text-sm text-slate-400">
                      {selectedTemplate.category} · {selectedTemplate.points * quantity} pts
                    </div>
                  </div>

                  <div className="flex items-center justify-between rounded-md border border-cyan-200/15 bg-slate-950/45 p-2">
                    <Button
                      disabled={quantity <= 1 || mutation.isPending}
                      onClick={() => setQuantity((value) => Math.max(1, value - 1))}
                      size="icon"
                      variant="ghost"
                    >
                      <Minus size={16} />
                    </Button>
                    <div className="text-center">
                      <div className="text-xs text-slate-400">Cantidad</div>
                      <div className="text-lg font-semibold text-cyan-50">{quantity}</div>
                    </div>
                    <Button
                      disabled={mutation.isPending}
                      onClick={() => setQuantity((value) => Math.min(9, value + 1))}
                      size="icon"
                      variant="ghost"
                    >
                      <Plus size={16} />
                    </Button>
                  </div>

                  <div className="space-y-2">
                    {costResources.map((resource) => (
                      <div className="flex items-center justify-between text-sm" key={resource}>
                        <span className="text-slate-400">{resourceLabels[resource]}</span>
                        <ResourceAmount
                          className={resources && hasEnough(resources, resource, getTemplateCost(selectedTemplate, resource) * quantity) ? "text-slate-100" : "text-rose-100"}
                          resource={resource}
                          value={getTemplateCost(selectedTemplate, resource) * quantity}
                        />
                      </div>
                    ))}
                  </div>

                  <Button
                    className="w-full"
                    disabled={!rpcReady || !hasResources || mutation.isPending}
                    onClick={() => mutation.mutate()}
                  >
                    {mutation.isPending ? "Enviando orden..." : "Reclutar"}
                  </Button>

                  {mutation.error ? <p className="text-sm text-rose-200">{mutation.error.message}</p> : null}
                  {!hasResources ? <p className="text-sm text-rose-200">Recursos insuficientes.</p> : null}
                </div>
              ) : (
                <p className="mt-3 text-sm text-slate-400">No hay unidades disponibles.</p>
              )}
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto p-5">
              <h3 className="mb-3 text-sm font-semibold text-cyan-50">Cola activa</h3>
              <div className="space-y-2">
                {queue.length > 0 ? (
                  queue.map((item) => (
                    <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={item.id}>
                      <div className="flex items-center justify-between gap-3">
                        <div>
                          <div className="text-sm font-medium text-slate-100">{item.unitName}</div>
                          <div className="mt-1 text-xs text-slate-400">x{item.quantity}</div>
                        </div>
                        <Badge tone="violet">{formatCountdown(item.finishesAt)}</Badge>
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
                    Sin reclutamientos activos.
                  </div>
                )}
              </div>
            </div>
          </aside>
        </div>
      </Panel>
    </div>
  );
}

function ResourceSummary({ resources }: { resources?: FactionResources }) {
  return (
    <div className="mb-4 grid grid-cols-2 gap-2 md:grid-cols-4">
      {costResources.map((resource) => (
        <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3" key={resource}>
          <div className="mb-2 flex items-center gap-2 text-[11px] text-slate-400">
            <ResourceIcon className="size-5" resource={resource} />
            {resourceLabels[resource]}
          </div>
          <div className="text-lg font-semibold text-cyan-50">{resources?.[resource] ?? 0}</div>
        </div>
      ))}
    </div>
  );
}

function CostPill({
  resource,
  value
}: {
  resource: Exclude<ResourceKey, "technology">;
  value: number;
}) {
  return (
    <span className="inline-flex items-center justify-between gap-2 rounded border border-cyan-200/10 bg-slate-950/45 px-2 py-1 text-slate-200">
      <ResourceIcon className="size-4" resource={resource} />
      {value}
    </span>
  );
}

function getTemplateCost(template: UnitTemplate, resource: Exclude<ResourceKey, "technology">) {
  const costs = {
    supply: template.supplyCost,
    minerals: template.mineralsCost,
    ancestralStone: template.ancestralStoneCost,
    uridium: template.uridiumCost
  };

  return costs[resource];
}

function canAfford(resources: FactionResources, template: UnitTemplate, quantity: number) {
  return costResources.every((resource) =>
    hasEnough(resources, resource, getTemplateCost(template, resource) * quantity)
  );
}

function hasEnough(resources: FactionResources, resource: Exclude<ResourceKey, "technology">, value: number) {
  return resources[resource] >= value;
}

function formatDuration(seconds: number) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  if (hours > 0 && minutes > 0) {
    return `${hours}h ${minutes}m`;
  }

  if (hours > 0) {
    return `${hours}h`;
  }

  return `${minutes}m`;
}
