"use client";

import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Activity, Building2, Clock3, HeartPulse, Minus, Plus, Shield, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceAmount, ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import {
  canUseRecruitmentRpc,
  cancelRecruitmentQueue,
  cancelUnitRecoveryQueue,
  recruitUnitAtBuilding,
  resupplyUnitAtBuilding
} from "@/features/recruitment/api/recruitment-api";
import {
  getBaseRecruitmentCost,
  getRecruitmentCost,
  getRecruitmentDuration,
  getRequiredTechnologyName,
  getVisibleRecruitmentCostResources,
  isUnitTemplateUnlocked
} from "@/features/technology/lib/technology-state";
import { formatCountdown } from "@/lib/time";
import type {
  BuildingTemplate,
  CampaignSnapshot,
  FactionResources,
  RecruitmentQueueItem,
  ResourceKey,
  SystemBuilding,
  UnitRecoveryQueueItem,
  UnitTemplate
} from "@/domain/campaign";

type BuildingTab = "recruit" | "heal" | "queue";

export function BuildingActionModal({
  snapshot,
  building,
  template,
  open,
  onClose
}: {
  snapshot: CampaignSnapshot;
  building: SystemBuilding | null;
  template: BuildingTemplate | null;
  open: boolean;
  onClose: () => void;
}) {
  const [tab, setTab] = useState<BuildingTab>("recruit");

  if (!open || !building || !template) {
    return null;
  }

  if (template.buildingKind === "commerce") {
    return null;
  }

  return (
    <div className="pointer-events-auto fixed inset-0 z-50 grid place-items-center bg-black/60 p-0 backdrop-blur-sm md:px-4 md:py-6">
      <Panel className="flex h-[var(--app-height)] w-full max-w-6xl flex-col overflow-hidden rounded-none md:h-auto md:max-h-[90vh] md:rounded-lg">
        <div className="shrink-0 border-b border-cyan-200/15 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:p-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="text-xs uppercase tracking-[0.24em] text-cyan-200/70">Edificio planetario</div>
              <h2 className="mt-1 text-2xl font-semibold text-cyan-50">{template.name}</h2>
              <p className="mt-1 text-sm text-slate-400">{template.description}</p>
            </div>
            <Button aria-label="Cerrar edificio" onClick={onClose} size="icon" variant="ghost">
              <X size={18} />
            </Button>
          </div>
        </div>

        {building.status !== "active" ? (
          <ConstructingBuildingView building={building} />
        ) : template.buildingKind === "recruitment" ? (
          <RecruitmentBuildingView
            building={building}
            onClose={onClose}
            snapshot={snapshot}
            tab={tab}
            template={template}
            onTabChange={setTab}
          />
        ) : template.buildingKind === "production" ? (
          <ProductionBuildingView template={template} />
        ) : (
          <PlaceholderBuildingView template={template} />
        )}
      </Panel>
    </div>
  );
}

function ConstructingBuildingView({ building }: { building: SystemBuilding }) {
  return (
    <div className="grid flex-1 place-items-center p-6 text-center">
      <div>
        <div className="mx-auto mb-4 grid size-14 place-items-center rounded-md border border-amber-300/30 bg-amber-300/10 text-amber-100">
          <Building2 size={26} />
        </div>
        <h3 className="text-xl font-semibold text-cyan-50">Construccion en marcha</h3>
        <p className="mt-2 text-sm text-slate-300">
          Disponible en {building.finishesAt ? formatCountdown(building.finishesAt) : "breve"}.
        </p>
      </div>
    </div>
  );
}

function RecruitmentBuildingView({
  snapshot,
  building,
  template,
  tab,
  onTabChange,
  onClose
}: {
  snapshot: CampaignSnapshot;
  building: SystemBuilding;
  template: BuildingTemplate;
  tab: BuildingTab;
  onTabChange: (tab: BuildingTab) => void;
  onClose: () => void;
}) {
  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="shrink-0 border-b border-cyan-200/15 px-4 py-3 md:px-5">
        <div className="grid grid-cols-3 gap-2 md:w-fit">
          <Button onClick={() => onTabChange("recruit")} size="sm" variant={tab === "recruit" ? "primary" : "ghost"}>
            <Shield size={15} />
            Reclutar
          </Button>
          <Button onClick={() => onTabChange("heal")} size="sm" variant={tab === "heal" ? "primary" : "ghost"}>
            <HeartPulse size={15} />
            Reabastecer
          </Button>
          <Button onClick={() => onTabChange("queue")} size="sm" variant={tab === "queue" ? "primary" : "ghost"}>
            <Clock3 size={15} />
            Cola
          </Button>
        </div>
      </div>

      {tab === "recruit" ? (
        <RecruitTab building={building} onClose={onClose} snapshot={snapshot} template={template} />
      ) : tab === "heal" ? (
        <HealTab building={building} onClose={onClose} snapshot={snapshot} template={template} />
      ) : (
        <QueueTab building={building} snapshot={snapshot} />
      )}
    </div>
  );
}

function RecruitTab({
  snapshot,
  building,
  template,
  onClose
}: {
  snapshot: CampaignSnapshot;
  building: SystemBuilding;
  template: BuildingTemplate;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [quantity, setQuantity] = useState(1);
  const resources = getCurrentResources(snapshot);
  const rpcReady = canUseRecruitmentRpc();
  const templates = useMemo(
    () =>
      snapshot.unitTemplates.filter(
        (unitTemplate) =>
          unitTemplate.factionId === snapshot.currentUser.factionId &&
          unitTemplate.isAvailable &&
          template.allowedUnitCategories.includes(unitTemplate.category)
      ),
    [snapshot.currentUser.factionId, snapshot.unitTemplates, template.allowedUnitCategories]
  );
  const selectedTemplate = templates.find((item) => item.id === selectedTemplateId) ?? templates[0] ?? null;
  const selectedUnlocked = selectedTemplate ? isUnitTemplateUnlocked(snapshot, selectedTemplate) : false;
  const selectedResources = selectedTemplate ? getVisibleRecruitmentCostResources(snapshot, selectedTemplate) : [];
  const hasResources = selectedTemplate && resources ? canAffordRecruitment(snapshot, resources, selectedTemplate, quantity) : false;
  const activeQueue = getActiveBuildingQueue(snapshot, building.id);
  const mutation = useMutation({
    mutationFn: () => {
      if (!selectedTemplate) {
        throw new Error("Selecciona una unidad.");
      }

      return recruitUnitAtBuilding(building.id, selectedTemplate.id, quantity);
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });

  return (
    <div className="mobile-scroll flex-1 lg:grid lg:grid-cols-[1fr_320px] lg:overflow-hidden">
      <div className="p-4 md:p-5 lg:min-h-0 lg:overflow-y-auto">
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {templates.length > 0 ? (
            templates.map((unitTemplate) => {
              const selected = unitTemplate.id === selectedTemplate?.id;
              const unlocked = isUnitTemplateUnlocked(snapshot, unitTemplate);
              const affordable = resources ? canAffordRecruitment(snapshot, resources, unitTemplate, quantity) : false;
              const costResources = getVisibleRecruitmentCostResources(snapshot, unitTemplate);

              return (
                <button
                  className={`rounded-lg border p-4 text-left transition ${
                    selected
                      ? "border-cyan-200/55 bg-cyan-300/12 shadow-[0_0_24px_rgba(34,211,238,0.14)]"
                      : unlocked
                        ? "border-cyan-200/15 bg-slate-950/35 hover:border-cyan-200/35"
                        : "border-slate-500/20 bg-slate-950/25 opacity-70 hover:border-violet-200/25"
                  }`}
                  key={unitTemplate.id}
                  onClick={() => setSelectedTemplateId(unitTemplate.id)}
                  type="button"
                >
                  <div className="mb-3 flex items-start justify-between gap-3">
                    <div>
                      <div className="font-semibold text-cyan-50">{unitTemplate.name}</div>
                      <div className="mt-1 text-xs text-slate-400">
                        {unitTemplate.points} pts · {unitTemplate.defaultQuantity} miniaturas
                      </div>
                    </div>
                    <Badge tone={!unlocked ? "violet" : affordable ? "cyan" : "rose"}>
                      {!unlocked ? "Tecnologia" : unitTemplate.category}
                    </Badge>
                  </div>

                  <div className="grid grid-cols-2 gap-2 text-xs">
                    {costResources.map((resource) => (
                      <CostPill
                        key={resource}
                        resource={resource}
                        baseValue={getBaseRecruitmentCost(unitTemplate, resource)}
                        value={getRecruitmentCost(snapshot, unitTemplate, resource)}
                      />
                    ))}
                  </div>
                </button>
              );
            })
          ) : (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-4 text-sm text-slate-400">
              Este edificio no tiene unidades disponibles para tu faccion.
            </div>
          )}
        </div>
      </div>

      <aside className="border-t border-cyan-200/15 bg-slate-950/35 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-4 md:p-5 lg:border-l lg:border-t-0">
        {selectedTemplate ? (
          <div className="space-y-4">
            <div>
              <h3 className="text-xl font-semibold text-cyan-50">{selectedTemplate.name}</h3>
              <p className="mt-1 text-sm text-slate-400">
                {selectedTemplate.category} · {selectedTemplate.points * quantity} pts ·{" "}
                {selectedTemplate.defaultQuantity * quantity} miniaturas
              </p>
              <p className="mt-1 text-xs text-slate-500">
                Tiempo: {formatDuration(getRecruitmentDuration(snapshot, selectedTemplate, quantity))}
              </p>
            </div>

            <QuantityPicker disabled={mutation.isPending} max={1} min={1} onChange={setQuantity} value={quantity} />

            {!selectedUnlocked ? (
              <div className="rounded-md border border-violet-300/25 bg-violet-400/10 p-3 text-sm text-violet-100">
                Requiere investigar {getRequiredTechnologyName(snapshot, selectedTemplate.requiredTechnologyNodeId)}.
              </div>
            ) : null}

            {activeQueue ? (
              <div className="rounded-md border border-amber-300/25 bg-amber-400/10 p-3 text-sm text-amber-100">
                Este edificio ya tiene una orden en cola. Cancela o espera a que termine para iniciar otra.
              </div>
            ) : null}

            <CostSummary
              getValue={(resource) => getRecruitmentCost(snapshot, selectedTemplate, resource) * quantity}
              resources={resources}
              visibleResources={selectedResources}
            />

            {mutation.error ? <p className="text-sm text-rose-200">{mutation.error.message}</p> : null}

            <Button
              className="sticky bottom-0 w-full"
              disabled={!rpcReady || !selectedUnlocked || !hasResources || Boolean(activeQueue) || mutation.isPending}
              onClick={() => mutation.mutate()}
            >
              {mutation.isPending ? "Enviando..." : "Reclutar"}
            </Button>
          </div>
        ) : (
          <p className="text-sm text-slate-400">No hay unidades disponibles.</p>
        )}
      </aside>
    </div>
  );
}

function HealTab({
  snapshot,
  building,
  template,
  onClose
}: {
  snapshot: CampaignSnapshot;
  building: SystemBuilding;
  template: BuildingTemplate;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [selectedUnitId, setSelectedUnitId] = useState<string | null>(null);
  const resources = getCurrentResources(snapshot);
  const rpcReady = canUseRecruitmentRpc();
  const activeQueue = getActiveBuildingQueue(snapshot, building.id);
  const woundedUnits = snapshot.units.filter(
    (unit) =>
      unit.factionId === snapshot.currentUser.factionId &&
      unit.currentSystemId === building.systemId &&
      unit.status === "ready" &&
      (unit.quantity < unit.startingQuantity || unit.woundsTaken > 0) &&
      template.allowedUnitCategories.includes(unit.category)
  );
  const selectedUnit = woundedUnits.find((unit) => unit.id === selectedUnitId) ?? woundedUnits[0] ?? null;
  const selectedTemplate = selectedUnit
    ? snapshot.unitTemplates.find((unitTemplate) => unitTemplate.id === selectedUnit.unitTemplateId) ?? null
    : null;
  const recoveryCosts = selectedTemplate ? getResupplyCosts(selectedTemplate) : {};
  const visibleResources = Object.entries(recoveryCosts)
    .filter(([, value]) => value > 0)
    .map(([resource]) => resource as ResourceKey);
  const hasResources =
    resources && visibleResources.every((resource) => resources[resource] >= (recoveryCosts[resource] ?? 0));
  const mutation = useMutation({
    mutationFn: () => {
      if (!selectedUnit) {
        throw new Error("Selecciona una unidad para reabastecer.");
      }

      return resupplyUnitAtBuilding(building.id, selectedUnit.id);
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });

  return (
    <div className="mobile-scroll flex-1 lg:grid lg:grid-cols-[1fr_320px] lg:overflow-hidden">
      <div className="p-4 md:p-5 lg:min-h-0 lg:overflow-y-auto">
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {woundedUnits.length > 0 ? (
            woundedUnits.map((unit) => {
              const selected = unit.id === selectedUnit?.id;

              return (
                <button
                  className={`rounded-lg border p-4 text-left transition ${
                    selected
                      ? "border-rose-200/55 bg-rose-300/12 shadow-[0_0_24px_rgba(251,113,133,0.14)]"
                      : "border-cyan-200/15 bg-slate-950/35 hover:border-rose-200/35"
                  }`}
                  key={unit.id}
                  onClick={() => setSelectedUnitId(unit.id)}
                  type="button"
                >
                  <div className="mb-3 flex items-start justify-between gap-3">
                    <div>
                      <div className="font-semibold text-cyan-50">{unit.name}</div>
                      <div className="mt-1 text-xs text-slate-400">{unit.category}</div>
                    </div>
                    <Badge tone="rose">{unit.quantity}/{unit.startingQuantity}</Badge>
                  </div>
                  <div className="text-xs text-slate-300">
                    Faltan {unit.startingQuantity - unit.quantity} miniaturas · {unit.woundsTaken} heridas.
                  </div>
                </button>
              );
            })
          ) : (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-4 text-sm text-slate-400">
              No hay unidades compatibles para reabastecer en este sistema.
            </div>
          )}
        </div>
      </div>

      <aside className="border-t border-cyan-200/15 bg-slate-950/35 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-4 md:p-5 lg:border-l lg:border-t-0">
        {selectedUnit ? (
          <div className="space-y-4">
            <div>
              <h3 className="text-xl font-semibold text-cyan-50">{selectedUnit.name}</h3>
              <p className="mt-1 text-sm text-slate-400">
                {selectedUnit.quantity}/{selectedUnit.startingQuantity} miniaturas · {selectedUnit.woundsTaken} heridas
              </p>
              <p className="mt-2 text-xs leading-5 text-slate-500">
                Recupera la unidad completa: miniaturas al maximo y heridas a 0.
              </p>
            </div>

            {activeQueue ? (
              <div className="rounded-md border border-amber-300/25 bg-amber-400/10 p-3 text-sm text-amber-100">
                Este edificio ya tiene una orden en cola. Cancela o espera a que termine para reabastecer.
              </div>
            ) : null}

            <CostSummary
              getValue={(resource) => recoveryCosts[resource] ?? 0}
              resources={resources}
              visibleResources={visibleResources}
            />

            {mutation.error ? <p className="text-sm text-rose-200">{mutation.error.message}</p> : null}

            <Button
              className="sticky bottom-0 w-full"
              disabled={!rpcReady || !hasResources || Boolean(activeQueue) || mutation.isPending}
              onClick={() => mutation.mutate()}
            >
              <HeartPulse size={16} />
              {mutation.isPending ? "Iniciando..." : "Reabastecer unidad"}
            </Button>
          </div>
        ) : (
          <p className="text-sm text-slate-400">No hay unidades para reabastecer.</p>
        )}
      </aside>
    </div>
  );
}

function QueueTab({ snapshot, building }: { snapshot: CampaignSnapshot; building: SystemBuilding }) {
  const queryClient = useQueryClient();
  const recruitmentQueue = snapshot.recruitmentQueue.filter((item) => item.systemBuildingId === building.id && item.status === "queued");
  const recoveryQueue = snapshot.unitRecoveryQueue.filter((item) => item.systemBuildingId === building.id && item.status === "queued");
  const cancelRecruitmentMutation = useMutation({
    mutationFn: cancelRecruitmentQueue,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const cancelRecoveryMutation = useMutation({
    mutationFn: cancelUnitRecoveryQueue,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  return (
    <div className="mobile-scroll flex-1 p-4 md:p-5">
      <div className="grid gap-3 md:grid-cols-2">
        <QueueSection
          emptyText="Sin reclutamientos activos."
          items={recruitmentQueue.map((item) => ({
            id: item.id,
            title: item.unitName,
            detail: `x${item.quantity}`,
            finishesAt: item.finishesAt,
            refund: getQueueRefund(item)
          }))}
          cancelPending={cancelRecruitmentMutation.isPending}
          onCancel={(id) => cancelRecruitmentMutation.mutate(id)}
          title="Reclutamiento"
        />
        <QueueSection
          emptyText="Sin reabastecimientos activos."
          items={recoveryQueue.map((item) => ({
            id: item.id,
            title: item.unitName,
            detail: "Reabastecimiento completo",
            finishesAt: item.finishesAt,
            refund: getQueueRefund(item)
          }))}
          cancelPending={cancelRecoveryMutation.isPending}
          onCancel={(id) => cancelRecoveryMutation.mutate(id)}
          title="Reabastecimiento"
        />
      </div>
      {cancelRecruitmentMutation.error ? <p className="mt-3 text-sm text-rose-200">{cancelRecruitmentMutation.error.message}</p> : null}
      {cancelRecoveryMutation.error ? <p className="mt-3 text-sm text-rose-200">{cancelRecoveryMutation.error.message}</p> : null}
    </div>
  );
}

function QueueSection({
  title,
  items,
  emptyText,
  cancelPending,
  onCancel
}: {
  title: string;
  items: Array<{ id: string; title: string; detail: string; finishesAt: string; refund: Partial<Record<ResourceKey, number>> }>;
  emptyText: string;
  cancelPending: boolean;
  onCancel: (id: string) => void;
}) {
  return (
    <section>
      <h3 className="mb-3 text-sm font-semibold text-cyan-50">{title}</h3>
      <div className="space-y-2">
        {items.length > 0 ? (
          items.map((item) => (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={item.id}>
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-sm font-medium text-slate-100">{item.title}</div>
                  <div className="mt-1 text-xs text-slate-400">{item.detail}</div>
                  <RefundLine refund={item.refund} />
                </div>
                <div className="flex flex-col items-end gap-2">
                  <Badge tone="violet">{formatCountdown(item.finishesAt)}</Badge>
                  <Button disabled={cancelPending} onClick={() => onCancel(item.id)} size="sm" variant="ghost">
                    Cancelar
                  </Button>
                </div>
              </div>
            </div>
          ))
        ) : (
          <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
            {emptyText}
          </div>
        )}
      </div>
    </section>
  );
}

function ProductionBuildingView({ template }: { template: BuildingTemplate }) {
  return (
    <div className="grid flex-1 place-items-center p-6 text-center">
      <div>
        <div className="mx-auto mb-4 grid size-14 place-items-center rounded-md border border-cyan-300/30 bg-cyan-400/10 text-cyan-100">
          <Activity size={26} />
        </div>
        <h3 className="text-xl font-semibold text-cyan-50">Produccion activa</h3>
        {template.producedResourceKey ? (
          <p className="mt-2 text-sm text-slate-300">
            Genera <ResourceAmount resource={template.producedResourceKey} value={template.producedAmount} /> al dia.
          </p>
        ) : (
          <p className="mt-2 text-sm text-slate-300">Este edificio no tiene produccion configurada.</p>
        )}
      </div>
    </div>
  );
}

function PlaceholderBuildingView({ template }: { template: BuildingTemplate }) {
  return (
    <div className="grid flex-1 place-items-center p-6 text-center">
      <div>
        <div className="mx-auto mb-4 grid size-14 place-items-center rounded-md border border-violet-300/30 bg-violet-400/10 text-violet-100">
          <Activity size={26} />
        </div>
        <h3 className="text-xl font-semibold text-cyan-50">{template.name}</h3>
        <p className="mt-2 max-w-md text-sm leading-6 text-slate-300">
          Este edificio queda preparado para una fase futura. Su sistema asociado aun no esta implementado.
        </p>
      </div>
    </div>
  );
}

function QuantityPicker({
  value,
  min,
  max,
  disabled,
  onChange
}: {
  value: number;
  min: number;
  max: number;
  disabled: boolean;
  onChange: (value: number) => void;
}) {
  return (
    <div className="flex items-center justify-between rounded-md border border-cyan-200/15 bg-slate-950/45 p-2">
      <Button disabled={disabled || value <= min} onClick={() => onChange(value - 1)} size="icon" variant="ghost">
        <Minus size={16} />
      </Button>
      <div className="text-center">
        <div className="text-xs text-slate-400">Cantidad</div>
        <div className="text-lg font-semibold text-cyan-50">{value}</div>
      </div>
      <Button disabled={disabled || value >= max} onClick={() => onChange(value + 1)} size="icon" variant="ghost">
        <Plus size={16} />
      </Button>
    </div>
  );
}

function CostSummary({
  visibleResources,
  resources,
  getValue
}: {
  visibleResources: ResourceKey[];
  resources?: FactionResources;
  getValue: (resource: ResourceKey) => number;
}) {
  return (
    <div className="space-y-2">
      {visibleResources.length > 0 ? (
        visibleResources.map((resource) => {
          const value = getValue(resource);
          const enough = (resources?.[resource] ?? 0) >= value;

          return (
            <div className="flex items-center justify-between text-sm" key={resource}>
              <span className="text-slate-400">{resourceLabels[resource]}</span>
              <ResourceAmount className={enough ? "text-slate-100" : "text-rose-100"} resource={resource} value={value} />
            </div>
          );
        })
      ) : (
        <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
          Sin coste.
        </div>
      )}
    </div>
  );
}

function CostPill({
  resource,
  baseValue,
  value
}: {
  resource: ResourceKey;
  baseValue: number;
  value: number;
}) {
  return (
    <span className="inline-flex items-center justify-between gap-2 rounded border border-cyan-200/10 bg-slate-950/45 px-2 py-1 text-slate-200">
      <ResourceIcon className="size-4" resource={resource} />
      <span className="inline-flex items-center gap-1.5">
        {baseValue !== value ? <span className="text-[11px] text-slate-500 line-through">{baseValue}</span> : null}
        {value}
      </span>
    </span>
  );
}

function RefundLine({ refund }: { refund: Partial<Record<ResourceKey, number>> }) {
  const resources = Object.entries(refund).filter(([, value]) => value > 0) as Array<[ResourceKey, number]>;

  if (resources.length === 0) {
    return null;
  }

  return (
    <div className="mt-2 flex flex-wrap gap-2 text-[11px] text-slate-400">
      <span>Reembolso:</span>
      {resources.map(([resource, value]) => (
        <ResourceAmount key={resource} resource={resource} value={value} />
      ))}
    </div>
  );
}

function getCurrentResources(snapshot: CampaignSnapshot) {
  return snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
}

function canAffordRecruitment(
  snapshot: CampaignSnapshot,
  resources: FactionResources,
  template: UnitTemplate,
  quantity: number
) {
  return getVisibleRecruitmentCostResources(snapshot, template).every((resource) =>
    resources[resource] >= getRecruitmentCost(snapshot, template, resource) * quantity
  );
}

function getResupplyCosts(template: UnitTemplate): Partial<Record<ResourceKey, number>> {
  const halfCost = (value: number) => (value > 0 ? Math.ceil(value / 2) : 0);

  return {
    supply: halfCost(template.supplyCost),
    minerals: halfCost(template.mineralsCost),
    honor: halfCost(template.honorCost),
    gold: halfCost(template.goldCost),
    industrialMaterial: halfCost(template.industrialMaterialCost),
    uridium: halfCost(template.uridiumCost),
    technology: halfCost(template.technologyCost)
  };
}

function getActiveBuildingQueue(snapshot: CampaignSnapshot, buildingId: string) {
  return (
    snapshot.recruitmentQueue.find((item) => item.systemBuildingId === buildingId && item.status === "queued") ??
    snapshot.unitRecoveryQueue.find((item) => item.systemBuildingId === buildingId && item.status === "queued") ??
    null
  );
}

function getQueueRefund(
  item: Pick<
    RecruitmentQueueItem | UnitRecoveryQueueItem,
    | "supplyCost"
    | "mineralsCost"
    | "honorCost"
    | "goldCost"
    | "industrialMaterialCost"
    | "uridiumCost"
    | "technologyCost"
  >
): Partial<Record<ResourceKey, number>> {
  const refund = (value: number) => (value > 0 ? Math.ceil(value / 2) : 0);

  return {
    supply: refund(item.supplyCost),
    minerals: refund(item.mineralsCost),
    honor: refund(item.honorCost),
    gold: refund(item.goldCost),
    industrialMaterial: refund(item.industrialMaterialCost),
    uridium: refund(item.uridiumCost),
    technology: refund(item.technologyCost)
  };
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

  return `${Math.max(1, minutes)}m`;
}
