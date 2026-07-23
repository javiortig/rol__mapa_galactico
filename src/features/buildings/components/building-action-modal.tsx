"use client";

import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Activity, Building2, Clock3, Gem, HeartPulse, Minus, Plus, Shield, Sparkles, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceAmount, ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import {
  canUseRecruitmentRpc,
  cancelRecruitmentQueue,
  cancelUnitRecoveryQueue,
  recruitUnitVariantAtBuilding,
  resupplyUnitAtBuilding
} from "@/features/recruitment/api/recruitment-api";
import { canUseRelicRpc, equipRelicToCharacter, unequipRelicFromCharacter } from "@/features/relics/api/relic-api";
import {
  getBaseRecruitmentVariantCost,
  computeRecruitmentCostsForPoints,
  getRecruitmentDuration,
  getRecruitmentVariantCost,
  getRequiredTechnologyName,
  getVisibleRecruitmentVariantCostResources,
  isUnitTemplateUnlocked
} from "@/features/technology/lib/technology-state";
import { getFactionArmyPoints } from "@/features/units/lib/army-points";
import { getCharacterLevel, getCharacterRank, getCharacterRelicSlots, isCharacterUnit } from "@/features/units/lib/character-ranks";
import { formatCountdown } from "@/lib/time";
import type {
  BuildingTemplate,
  CampaignUnit,
  CampaignRelic,
  CampaignSnapshot,
  FactionResources,
  RecruitmentQueueItem,
  RecruitmentWargearSelection,
  ResourceKey,
  SystemBuilding,
  UnitTemplateModelOption,
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
        ) : template.buildingKind === "relic" ? (
          <RelicSanctuaryView building={building} snapshot={snapshot} />
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
  const [selectedModelCounts, setSelectedModelCounts] = useState<Record<string, number>>({});
  const [selectedWargearQuantities, setSelectedWargearQuantities] = useState<Record<string, Record<string, number>>>({});
  const resources = getCurrentResources(snapshot);
  const rpcReady = canUseRecruitmentRpc();
  const templates = useMemo(
    () =>
      snapshot.unitTemplates.filter(
        (unitTemplate) =>
          unitTemplate.factionId === snapshot.currentUser.factionId &&
          unitTemplate.isAvailable &&
          canUseTemplateAtBuilding(unitTemplate, template.slug, template.allowedUnitCategories)
      ),
    [snapshot.currentUser.factionId, snapshot.unitTemplates, template.allowedUnitCategories, template.slug]
  );
  const selectedTemplate = templates.find((item) => item.id === selectedTemplateId) ?? templates[0] ?? null;
  const selectedCopyIndex = selectedTemplate ? getRecruitmentCopyIndex(snapshot, selectedTemplate) : 1;
  const selectedModelChoices = selectedTemplate ? getModelChoices(selectedTemplate, selectedCopyIndex) : [];
  const selectedModelCount = selectedTemplate
    ? selectedModelCounts[selectedTemplate.id] ?? selectedModelChoices[0]?.models ?? selectedTemplate.defaultQuantity
    : 0;
  const selectedWargearForTemplate = selectedTemplate ? selectedWargearQuantities[selectedTemplate.id] ?? {} : {};
  const selectedModelOption = selectedTemplate
    ? getModelOptionForCopy(selectedTemplate, selectedModelCount, selectedCopyIndex)
    : null;
  const selectedWargearPoints = selectedTemplate
    ? getWargearPoints(selectedTemplate, selectedWargearForTemplate, selectedModelCount)
    : 0;
  const selectedPoints = selectedTemplate
    ? getVariantPoints(selectedTemplate, selectedModelCount, selectedCopyIndex, selectedWargearForTemplate)
    : 0;
  const selectedUnlocked = selectedTemplate ? isUnitTemplateUnlocked(snapshot, selectedTemplate) : false;
  const selectedResources = selectedTemplate
    ? getVisibleRecruitmentVariantCostResources(snapshot, selectedTemplate, selectedPoints)
    : [];
  const hasResources = selectedTemplate && resources ? canAffordRecruitmentVariant(snapshot, resources, selectedTemplate, selectedPoints) : false;
  const activeQueue = getActiveBuildingQueue(snapshot, building.id);
  const currentArmyPoints = getFactionArmyPoints(snapshot, snapshot.currentUser.factionId);
  const exceedsArmyLimit = currentArmyPoints + selectedPoints > snapshot.maxArmyPoints;
  const mutation = useMutation({
    mutationFn: () => {
      if (!selectedTemplate) {
        throw new Error("Selecciona una unidad.");
      }

      return recruitUnitVariantAtBuilding({
        systemBuildingId: building.id,
        unitTemplateId: selectedTemplate.id,
        modelCount: selectedModelCount,
        wargearSelections: getWargearSelectionsForRpc(selectedTemplate, selectedWargearForTemplate, selectedModelCount)
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
      onClose();
    }
  });
  const updateWargearQuantity = (slug: string, value: number) => {
    if (!selectedTemplate) {
      return;
    }

    const nextValue = Math.max(0, Math.min(selectedModelCount, Math.trunc(value)));

    setSelectedWargearQuantities((current) => ({
      ...current,
      [selectedTemplate.id]: {
        ...(current[selectedTemplate.id] ?? {}),
        [slug]: nextValue
      }
    }));
  };

  return (
    <div className="mobile-scroll flex-1 lg:grid lg:grid-cols-[1fr_320px] lg:overflow-hidden">
      <div className="p-4 md:p-5 lg:min-h-0 lg:overflow-y-auto">
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {templates.length > 0 ? (
            templates.map((unitTemplate) => {
              const selected = unitTemplate.id === selectedTemplate?.id;
              const unlocked = isUnitTemplateUnlocked(snapshot, unitTemplate);
              const previewCopyIndex = getRecruitmentCopyIndex(snapshot, unitTemplate);
              const previewChoice = getModelChoices(unitTemplate, previewCopyIndex)[0];
              const previewPoints = previewChoice?.points ?? unitTemplate.points;
              const affordable = resources ? canAffordRecruitmentVariant(snapshot, resources, unitTemplate, previewPoints) : false;
              const costResources = getVisibleRecruitmentVariantCostResources(snapshot, unitTemplate, previewPoints);
              const hasVariants = (unitTemplate.modelOptions?.length ?? 0) > 1 || (unitTemplate.wargearOptions?.length ?? 0) > 0;

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
                        Desde {previewPoints} pts · {previewChoice?.models ?? unitTemplate.defaultQuantity} miniaturas
                      </div>
                    </div>
                    <Badge tone={!unlocked ? "violet" : affordable ? "cyan" : "rose"}>
                      {!unlocked ? "Tecnologia" : hasVariants ? "Opciones" : unitTemplate.category}
                    </Badge>
                  </div>

                  <div className="grid grid-cols-2 gap-2 text-xs">
                    {costResources.map((resource) => (
                      <CostPill
                        key={resource}
                        resource={resource}
                        baseValue={getBaseRecruitmentVariantCost(unitTemplate, previewPoints, resource)}
                        value={getRecruitmentVariantCost(snapshot, unitTemplate, previewPoints, resource)}
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
                {selectedTemplate.category} · {selectedPoints} pts · {selectedModelCount} miniaturas
              </p>
              <p className="mt-1 text-xs text-slate-500">
                Tiempo: {formatDuration(getRecruitmentDuration(snapshot, selectedTemplate, 1))}
              </p>
              <p className="mt-2 text-xs text-slate-400">
                Ejercito: {currentArmyPoints + selectedPoints}/{snapshot.maxArmyPoints} pts
              </p>
              {selectedModelOption?.copyFrom && selectedModelOption.copyFrom > 1 ? (
                <p className="mt-1 text-xs text-amber-100">
                  MFM aplica precio de {formatCopyRange(selectedModelOption)} para esta copia.
                </p>
              ) : null}
            </div>

            {selectedModelChoices.length > 1 ? (
              <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3">
                <div className="mb-2 text-xs uppercase tracking-[0.18em] text-slate-400">Tamano de unidad</div>
                <div className="grid grid-cols-2 gap-2">
                  {selectedModelChoices.map((choice) => (
                    <button
                      className={`rounded-md border px-3 py-2 text-left text-sm transition ${
                        selectedModelCount === choice.models
                          ? "border-cyan-200/55 bg-cyan-300/12 text-cyan-50"
                          : "border-cyan-200/15 bg-slate-950/35 text-slate-300 hover:border-cyan-200/35"
                      }`}
                      disabled={mutation.isPending}
                      key={choice.slug}
                      onClick={() =>
                        setSelectedModelCounts((current) => ({
                          ...current,
                          [selectedTemplate.id]: choice.models
                        }))
                      }
                      type="button"
                    >
                      <span className="block font-medium">{choice.models} miniaturas</span>
                      <span className="text-xs text-slate-400">{choice.points} pts</span>
                    </button>
                  ))}
                </div>
              </div>
            ) : null}

            {(selectedTemplate.wargearOptions?.length ?? 0) > 0 ? (
              <div className="rounded-md border border-cyan-200/15 bg-slate-950/45 p-3">
                <div className="mb-2 text-xs uppercase tracking-[0.18em] text-slate-400">Extras de equipo</div>
                <div className="space-y-2">
                  {selectedTemplate.wargearOptions?.map((option) => {
                    const value = Math.min(selectedWargearForTemplate[option.slug] ?? 0, selectedModelCount);

                    return (
                      <div
                        className="flex items-center justify-between gap-3 rounded-md border border-cyan-200/10 bg-slate-950/35 p-2"
                        key={option.slug}
                      >
                        <div className="min-w-0">
                          <div className="truncate text-sm font-medium text-slate-100">{option.name}</div>
                          <div className="text-xs text-slate-400">+{option.points} pts por opcion</div>
                        </div>
                        <MiniStepper
                          disabled={mutation.isPending}
                          max={selectedModelCount}
                          onChange={(nextValue) => updateWargearQuantity(option.slug, nextValue)}
                          value={value}
                        />
                      </div>
                    );
                  })}
                </div>
                {selectedWargearPoints > 0 ? (
                  <p className="mt-2 text-xs text-amber-100">Extras seleccionados: +{selectedWargearPoints} pts.</p>
                ) : null}
              </div>
            ) : null}

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

            {exceedsArmyLimit ? (
              <div className="rounded-md border border-rose-300/25 bg-rose-400/10 p-3 text-sm text-rose-100">
                Supera el limite de {snapshot.maxArmyPoints} puntos de ejercito.
              </div>
            ) : null}

            <CostSummary
              getValue={(resource) => getRecruitmentVariantCost(snapshot, selectedTemplate, selectedPoints, resource)}
              resources={resources}
              visibleResources={selectedResources}
            />

            {mutation.error ? <p className="text-sm text-rose-200">{mutation.error.message}</p> : null}

            <Button
              className="sticky bottom-0 w-full"
              disabled={!rpcReady || !selectedUnlocked || !hasResources || Boolean(activeQueue) || exceedsArmyLimit || mutation.isPending}
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
    (unit) => {
      const unitTemplate = snapshot.unitTemplates.find((candidate) => candidate.id === unit.unitTemplateId);

      return (
        unit.factionId === snapshot.currentUser.factionId &&
        unit.currentSystemId === building.systemId &&
        unit.status === "ready" &&
        (unit.quantity < unit.startingQuantity || unit.woundsTaken > 0) &&
        (unitTemplate
          ? canUseTemplateAtBuilding(unitTemplate, template.slug, template.allowedUnitCategories)
          : template.allowedUnitCategories.includes(unit.category))
      );
    }
  );
  const selectedUnit = woundedUnits.find((unit) => unit.id === selectedUnitId) ?? woundedUnits[0] ?? null;
  const selectedTemplate = selectedUnit
    ? snapshot.unitTemplates.find((unitTemplate) => unitTemplate.id === selectedUnit.unitTemplateId) ?? null
    : null;
  const recoveryCosts = selectedTemplate && selectedUnit ? getResupplyCosts(selectedTemplate, selectedUnit) : {};
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
            detail: getRecruitmentQueueDetail(snapshot, item),
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

function RelicSanctuaryView({ snapshot, building }: { snapshot: CampaignSnapshot; building: SystemBuilding }) {
  const queryClient = useQueryClient();
  const [selectedRelicId, setSelectedRelicId] = useState<string | null>(null);
  const [selectedCharacterId, setSelectedCharacterId] = useState<string | null>(null);
  const rpcReady = canUseRelicRpc();
  const isAdmin = snapshot.currentUser.role === "admin";
  const storedRelics = snapshot.relics.filter(
    (relic) =>
      (isAdmin || relic.factionId === snapshot.currentUser.factionId) &&
      relic.systemId === building.systemId &&
      !relic.equippedUnitId
  );
  const characters = snapshot.units.filter(
    (unit) =>
      (isAdmin || unit.factionId === snapshot.currentUser.factionId) &&
      unit.currentSystemId === building.systemId &&
      isCharacterUnit(unit) &&
      unit.status === "ready" &&
      unit.quantity > 0
  );
  const selectedRelic = storedRelics.find((relic) => relic.id === selectedRelicId) ?? storedRelics[0] ?? null;
  const selectedCharacter = characters.find((unit) => unit.id === selectedCharacterId) ?? characters[0] ?? null;
  const equippedRelics = snapshot.relics.filter((relic) =>
    characters.some((character) => character.id === relic.equippedUnitId)
  );
  const selectedCharacterRelics = selectedCharacter
    ? snapshot.relics.filter((relic) => relic.equippedUnitId === selectedCharacter.id)
    : [];
  const selectedCharacterSlots = selectedCharacter ? getCharacterRelicSlots(selectedCharacter) : 0;
  const canEquip =
    Boolean(selectedRelic && selectedCharacter) &&
    selectedCharacterSlots > selectedCharacterRelics.length;
  const equipMutation = useMutation({
    mutationFn: () => {
      if (!selectedRelic || !selectedCharacter) {
        throw new Error("Selecciona una reliquia y un Caracter.");
      }

      return equipRelicToCharacter(selectedRelic.id, selectedCharacter.id, building.id);
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const unequipMutation = useMutation({
    mutationFn: (relicId: string) => unequipRelicFromCharacter(relicId, building.id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  return (
    <div className="mobile-scroll flex-1 lg:grid lg:grid-cols-[1fr_340px] lg:overflow-hidden">
      <div className="p-4 md:p-5 lg:min-h-0 lg:overflow-y-auto">
        <div className="mb-4 flex items-center gap-3">
          <div className="grid size-11 place-items-center rounded-md border border-violet-300/30 bg-violet-400/10 text-violet-100">
            <Gem size={22} />
          </div>
          <div>
            <h3 className="text-xl font-semibold text-cyan-50">Reliquias almacenadas</h3>
            <p className="mt-1 text-sm text-slate-400">Las reliquias narrativas se equipan a unidades con keyword Caracter presentes en este sistema.</p>
          </div>
        </div>

        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {storedRelics.length > 0 ? (
            storedRelics.map((relic) => (
              <RelicCard
                key={relic.id}
                relic={relic}
                selected={relic.id === selectedRelic?.id}
                onSelect={() => setSelectedRelicId(relic.id)}
              />
            ))
          ) : (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-4 text-sm text-slate-400">
              No hay reliquias guardadas en este Santuario.
            </div>
          )}
        </div>

        {equippedRelics.length > 0 ? (
          <section className="mt-5">
            <h3 className="mb-3 text-sm font-semibold text-cyan-50">Reliquias equipadas en Caracteres presentes</h3>
            <div className="grid gap-2 md:grid-cols-2">
              {equippedRelics.map((relic) => {
                const character = characters.find((unit) => unit.id === relic.equippedUnitId) ?? null;

                return (
                  <div className="rounded-md border border-violet-300/20 bg-violet-400/10 p-3" key={relic.id}>
                    <div className="font-semibold text-violet-50">{relic.name}</div>
                    <div className="mt-1 text-xs text-slate-300">{character?.name ?? "Caracter desconocido"}</div>
                    <Button
                      className="mt-3 w-full"
                      disabled={!rpcReady || unequipMutation.isPending}
                      onClick={() => unequipMutation.mutate(relic.id)}
                      size="sm"
                      variant="ghost"
                    >
                      Desequipar al Santuario
                    </Button>
                  </div>
                );
              })}
            </div>
          </section>
        ) : null}
      </div>

      <aside className="border-t border-cyan-200/15 bg-slate-950/35 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-4 md:p-5 lg:border-l lg:border-t-0">
        <div className="space-y-4">
          <div>
            <h3 className="text-lg font-semibold text-cyan-50">Equipar reliquia</h3>
            <p className="mt-1 text-sm text-slate-400">Nivel 3 desbloquea 1 reliquia; nivel 6 desbloquea 2.</p>
          </div>

          <label className="block text-xs text-slate-400">
            Reliquia
            <select
              className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-2 text-sm text-cyan-50"
              onChange={(event) => setSelectedRelicId(event.target.value)}
              value={selectedRelic?.id ?? ""}
            >
              {storedRelics.length > 0 ? (
                storedRelics.map((relic) => (
                  <option key={relic.id} value={relic.id}>
                    {relic.name}
                  </option>
                ))
              ) : (
                <option value="">Sin reliquias</option>
              )}
            </select>
          </label>

          <label className="block text-xs text-slate-400">
            Caracter presente
            <select
              className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-2 text-sm text-cyan-50"
              onChange={(event) => setSelectedCharacterId(event.target.value)}
              value={selectedCharacter?.id ?? ""}
            >
              {characters.length > 0 ? (
                characters.map((character) => (
                  <option key={character.id} value={character.id}>
                    {character.name} - nivel {getCharacterLevel(character)}
                  </option>
                ))
              ) : (
                <option value="">Sin Caracteres</option>
              )}
            </select>
          </label>

          {selectedCharacter ? (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/40 p-3 text-sm">
              <div className="font-semibold text-cyan-50">{selectedCharacter.name}</div>
              <div className="mt-1 text-xs text-amber-100">
                Nivel {getCharacterLevel(selectedCharacter)} - {getCharacterRank(selectedCharacter)}
              </div>
              <div className="mt-1 text-xs text-slate-400">
                Slots: {selectedCharacterRelics.length}/{selectedCharacterSlots}
              </div>
            </div>
          ) : null}

          {selectedRelic ? (
            <div className="rounded-md border border-violet-300/20 bg-violet-400/10 p-3 text-sm text-violet-50">
              <div className="font-semibold">{selectedRelic.name}</div>
              <p className="mt-1 text-xs leading-5 text-violet-100/85">{selectedRelic.effectText ?? selectedRelic.description}</p>
            </div>
          ) : null}

          {!rpcReady ? (
            <div className="rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
              Supabase no esta configurado.
            </div>
          ) : null}

          {selectedCharacter && selectedCharacterSlots <= selectedCharacterRelics.length ? (
            <div className="rounded-md border border-rose-300/25 bg-rose-400/10 p-3 text-sm text-rose-100">
              Este Caracter no tiene slots de reliquia libres.
            </div>
          ) : null}

          {equipMutation.error ? <p className="text-sm text-rose-200">{equipMutation.error.message}</p> : null}
          {unequipMutation.error ? <p className="text-sm text-rose-200">{unequipMutation.error.message}</p> : null}

          <Button
            className="sticky bottom-0 w-full"
            disabled={!rpcReady || !canEquip || equipMutation.isPending}
            onClick={() => equipMutation.mutate()}
          >
            <Sparkles size={16} />
            {equipMutation.isPending ? "Equipando..." : "Equipar reliquia"}
          </Button>
        </div>
      </aside>
    </div>
  );
}

function RelicCard({
  relic,
  selected,
  onSelect
}: {
  relic: CampaignRelic;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      className={`rounded-lg border p-4 text-left transition ${
        selected
          ? "border-violet-200/60 bg-violet-400/15 shadow-[0_0_24px_rgba(168,85,247,0.14)]"
          : "border-cyan-200/15 bg-slate-950/35 hover:border-violet-200/35"
      }`}
      onClick={onSelect}
      type="button"
    >
      <div className="mb-3 flex items-start justify-between gap-3">
        <div>
          <div className="font-semibold text-cyan-50">{relic.name}</div>
          <div className="mt-1 text-xs uppercase tracking-[0.14em] text-violet-200/80">{relic.rarity}</div>
        </div>
        <Gem className="text-violet-100" size={19} />
      </div>
      <p className="text-xs leading-5 text-slate-300">{relic.description}</p>
      {relic.effectText ? <p className="mt-2 text-xs leading-5 text-violet-100">{relic.effectText}</p> : null}
    </button>
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

function MiniStepper({
  value,
  max,
  disabled,
  onChange
}: {
  value: number;
  max: number;
  disabled: boolean;
  onChange: (value: number) => void;
}) {
  return (
    <div className="flex shrink-0 items-center gap-1 rounded border border-cyan-200/15 bg-slate-950/45 p-1">
      <Button disabled={disabled || value <= 0} onClick={() => onChange(value - 1)} size="icon" variant="ghost">
        <Minus size={14} />
      </Button>
      <div className="min-w-7 text-center text-sm font-semibold text-cyan-50">{value}</div>
      <Button disabled={disabled || value >= max} onClick={() => onChange(value + 1)} size="icon" variant="ghost">
        <Plus size={14} />
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

function canAffordRecruitmentVariant(
  snapshot: CampaignSnapshot,
  resources: FactionResources,
  template: UnitTemplate,
  points: number
) {
  return getVisibleRecruitmentVariantCostResources(snapshot, template, points).every((resource) =>
    resources[resource] >= getRecruitmentVariantCost(snapshot, template, points, resource)
  );
}

function getRecruitmentCopyIndex(snapshot: CampaignSnapshot, template: UnitTemplate) {
  const livingCopies = snapshot.units.filter(
    (unit) =>
      unit.factionId === template.factionId &&
      unit.unitTemplateId === template.id &&
      unit.status !== "destroyed" &&
      unit.quantity > 0
  ).length;
  const queuedCopies = snapshot.recruitmentQueue
    .filter((item) => item.factionId === template.factionId && item.unitTemplateId === template.id && item.status === "queued")
    .reduce((total, item) => total + Math.max(1, item.quantity), 0);

  return livingCopies + queuedCopies + 1;
}

function getModelChoices(template: UnitTemplate, copyIndex: number) {
  const modelOptions = template.modelOptions ?? [];

  if (modelOptions.length === 0) {
    return [
      {
        slug: `${template.id}-default`,
        models: template.defaultQuantity,
        points: template.points,
        option: null
      }
    ];
  }

  const modelCounts = Array.from(new Set(modelOptions.map((option) => option.models))).sort((left, right) => left - right);

  return modelCounts
    .map((models) => {
      const option =
        getModelOptionForCopy(template, models, copyIndex) ??
        [...modelOptions]
          .filter((candidate) => candidate.minModels <= models && candidate.maxModels >= models)
          .sort((left, right) => left.copyFrom - right.copyFrom || left.points - right.points)[0] ??
        null;

      return {
        slug: `${template.id}-${models}-${option?.copyFrom ?? 1}-${option?.copyTo ?? "plus"}`,
        models,
        points: option?.points ?? template.points,
        option
      };
    })
    .sort((left, right) => left.models - right.models);
}

function getModelOptionForCopy(template: UnitTemplate, modelCount: number, copyIndex: number): UnitTemplateModelOption | null {
  return (
    [...(template.modelOptions ?? [])]
      .filter(
        (option) =>
          option.minModels <= modelCount &&
          option.maxModels >= modelCount &&
          option.copyFrom <= copyIndex &&
          (option.copyTo === null || option.copyTo === undefined || copyIndex <= option.copyTo)
      )
      .sort((left, right) => right.copyFrom - left.copyFrom || left.maxModels - right.maxModels || right.minModels - left.minModels)[0] ??
    null
  );
}

function getVariantPoints(
  template: UnitTemplate,
  modelCount: number,
  copyIndex: number,
  wargearQuantities: Record<string, number>
) {
  const modelOption = getModelOptionForCopy(template, modelCount, copyIndex);
  const basePoints = modelOption?.points ?? template.points;

  return basePoints + getWargearPoints(template, wargearQuantities, modelCount);
}

function getWargearPoints(template: UnitTemplate, wargearQuantities: Record<string, number>, modelCount: number) {
  return (template.wargearOptions ?? []).reduce((total, option) => {
    const quantity = getBoundedWargearQuantity(wargearQuantities, option.slug, modelCount);
    return total + option.points * quantity;
  }, 0);
}

function getWargearSelectionsForRpc(
  template: UnitTemplate,
  wargearQuantities: Record<string, number>,
  modelCount: number
): Array<Pick<RecruitmentWargearSelection, "slug" | "quantity">> {
  return (template.wargearOptions ?? [])
    .map((option) => ({
      slug: option.slug,
      quantity: getBoundedWargearQuantity(wargearQuantities, option.slug, modelCount)
    }))
    .filter((selection) => selection.quantity > 0);
}

function getBoundedWargearQuantity(wargearQuantities: Record<string, number>, slug: string, modelCount: number) {
  return Math.max(0, Math.min(Math.max(1, modelCount), Math.trunc(wargearQuantities[slug] ?? 0)));
}

function formatCopyRange(option: UnitTemplateModelOption) {
  if (option.copyTo === null || option.copyTo === undefined) {
    return `${option.copyFrom}+ copia`;
  }

  if (option.copyFrom === option.copyTo) {
    return `${option.copyFrom}. copia`;
  }

  return `${option.copyFrom}-${option.copyTo} copia`;
}

function canUseTemplateAtBuilding(unitTemplate: UnitTemplate, buildingSlug: string, allowedUnitCategories: string[]) {
  if (unitTemplate.recruitmentBuildingType) {
    return unitTemplate.recruitmentBuildingType === buildingSlug;
  }

  return allowedUnitCategories.includes(unitTemplate.category);
}

function getResupplyCosts(template: UnitTemplate, unit: CampaignUnit): Partial<Record<ResourceKey, number>> {
  const halfCost = (value: number) => (value > 0 ? Math.ceil(value / 2) : 0);
  const costs = computeRecruitmentCostsForPoints(template, unit.points);

  return {
    supply: halfCost(costs.supply),
    minerals: halfCost(costs.minerals),
    honor: halfCost(costs.honor),
    gold: halfCost(costs.gold),
    industrialMaterial: 0,
    uridium: 0,
    technology: 0
  };
}

function getActiveBuildingQueue(snapshot: CampaignSnapshot, buildingId: string) {
  return (
    snapshot.recruitmentQueue.find((item) => item.systemBuildingId === buildingId && item.status === "queued") ??
    snapshot.unitRecoveryQueue.find((item) => item.systemBuildingId === buildingId && item.status === "queued") ??
    null
  );
}

function getRecruitmentQueueDetail(snapshot: CampaignSnapshot, item: RecruitmentQueueItem) {
  const template = snapshot.unitTemplates.find((candidate) => candidate.id === item.unitTemplateId);
  const modelCount = item.selectedModelCount ?? template?.defaultQuantity ?? item.quantity;
  const points = item.selectedPoints ?? template?.points ?? 0;
  const wargear = item.selectedWargearOptions ?? [];
  const wargearText =
    wargear.length > 0
      ? ` · ${wargear.map((option) => `${option.quantity}x ${option.name ?? option.slug}`).join(", ")}`
      : "";

  return `${modelCount} miniaturas · ${points} pts${wargearText}`;
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
  if (seconds < 60) {
    return `${Math.max(1, seconds)}s`;
  }

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
