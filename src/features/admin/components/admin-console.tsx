"use client";

import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Ban, Building2, CheckCircle2, Factory, Save, ShieldAlert, ShieldPlus, SlidersHorizontal, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import {
  adminConstructBuilding,
  adminCreateUnit,
  adminSetCampaignLimits,
  adminSetFactionResources,
  adminSetSystemBlock,
  adminSetSystemResourceCapabilities,
  adminUpdateCampaignUnit,
  adminUpdateSystemBuilding,
  canUseAdminRpc
} from "@/features/admin/api/admin-api";
import { getFactionArmyPoints } from "@/features/units/lib/army-points";
import type { CampaignSnapshot, CampaignUnit, ResourceBundle, SystemBuilding } from "@/domain/campaign";

const factionResourceKeys = ["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium", "technology"] as const;
const systemCapabilityKeys = ["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium"] as const;
const unitStatusOptions: CampaignUnit["status"][] = ["ready", "moving", "in_war", "recovering", "retreat_pending", "destroyed"];
const buildingStatusOptions: SystemBuilding["status"][] = ["constructing", "active", "disabled"];

type EditableFactionResources = Pick<
  ResourceBundle,
  "supply" | "minerals" | "honor" | "gold" | "industrialMaterial" | "uridium" | "technology"
>;
type EditableSystemCapabilities = Pick<
  ResourceBundle,
  "supply" | "minerals" | "honor" | "gold" | "industrialMaterial" | "uridium"
>;
type UnitEditDraft = {
  systemId: string;
  quantity: number;
  woundsTaken: number;
  status: CampaignUnit["status"];
  isVisiblePublicly: boolean;
};
type BuildingEditDraft = {
  systemId: string;
  buildingTemplateId: string;
  status: SystemBuilding["status"];
  finishesAt: string;
};

export function AdminConsole({ snapshot }: { snapshot: CampaignSnapshot }) {
  const queryClient = useQueryClient();
  const rpcReady = canUseAdminRpc();

  const [unitFactionId, setUnitFactionId] = useState(snapshot.factions[0]?.id ?? "");
  const [unitSystemId, setUnitSystemId] = useState(snapshot.systems[0]?.id ?? "");
  const [unitTemplateId, setUnitTemplateId] = useState("");
  const [unitQuantity, setUnitQuantity] = useState(1);
  const [unitCustomName, setUnitCustomName] = useState("");

  const [buildingSystemId, setBuildingSystemId] = useState(snapshot.systems.find((system) => system.systemKind !== "gaseous")?.id ?? "");
  const [buildingTemplateId, setBuildingTemplateId] = useState(snapshot.buildingTemplates[0]?.id ?? "");

  const [resourceFactionId, setResourceFactionId] = useState(snapshot.factions[0]?.id ?? "");
  const [resourceDraftByFactionId, setResourceDraftByFactionId] = useState<Record<string, EditableFactionResources>>({});

  const [capabilitySystemId, setCapabilitySystemId] = useState(snapshot.systems[0]?.id ?? "");
  const [capabilityDraftBySystemId, setCapabilityDraftBySystemId] = useState<Record<string, EditableSystemCapabilities>>({});
  const [limitDraft, setLimitDraft] = useState<EditableFactionResources>(snapshot.resourceCaps);
  const [maxArmyPointsDraft, setMaxArmyPointsDraft] = useState(snapshot.maxArmyPoints);
  const [blockSystemId, setBlockSystemId] = useState(snapshot.systems[0]?.id ?? "");
  const [blockDays, setBlockDays] = useState(14);
  const [editUnitSystemId, setEditUnitSystemId] = useState(snapshot.systems[0]?.id ?? "");
  const [unitDrafts, setUnitDrafts] = useState<Record<string, UnitEditDraft>>({});
  const [editBuildingSystemId, setEditBuildingSystemId] = useState(snapshot.systems[0]?.id ?? "");
  const [buildingDrafts, setBuildingDrafts] = useState<Record<string, BuildingEditDraft>>({});

  const templatesForFaction = useMemo(
    () => snapshot.unitTemplates.filter((template) => template.factionId === unitFactionId && template.isAvailable),
    [snapshot.unitTemplates, unitFactionId]
  );

  const effectiveUnitTemplateId =
    templatesForFaction.find((template) => template.id === unitTemplateId)?.id ?? templatesForFaction[0]?.id ?? "";

  const selectedFactionResources = snapshot.resources.find((resource) => resource.factionId === resourceFactionId);
  const resourceDraft = resourceDraftByFactionId[resourceFactionId] ?? toEditableFactionResources(selectedFactionResources);

  const selectedCapabilitySystem = snapshot.systems.find((system) => system.id === capabilitySystemId) ?? null;
  const capabilityDraft =
    capabilityDraftBySystemId[capabilitySystemId] ??
    toEditableSystemCapabilities(selectedCapabilitySystem ?? undefined, snapshot.systemResourceCapabilities);
  const selectedBlockSystem = snapshot.systems.find((system) => system.id === blockSystemId) ?? null;
  const unitsInEditSystem = useMemo(
    () =>
      snapshot.units
        .filter((unit) => unit.currentSystemId === editUnitSystemId && unit.status !== "destroyed")
        .sort((left, right) => left.name.localeCompare(right.name)),
    [editUnitSystemId, snapshot.units]
  );
  const buildingsInEditSystem = useMemo(
    () =>
      snapshot.systemBuildings
        .filter((building) => building.systemId === editBuildingSystemId)
        .sort((left, right) => {
          const leftTemplate = snapshot.buildingTemplates.find((template) => template.id === left.buildingTemplateId);
          const rightTemplate = snapshot.buildingTemplates.find((template) => template.id === right.buildingTemplateId);
          return (leftTemplate?.name ?? left.id).localeCompare(rightTemplate?.name ?? right.id);
        }),
    [editBuildingSystemId, snapshot.buildingTemplates, snapshot.systemBuildings]
  );

  const handleUnitFactionChange = (nextFactionId: string) => {
    setUnitFactionId(nextFactionId);
    const nextTemplates = snapshot.unitTemplates.filter(
      (template) => template.factionId === nextFactionId && template.isAvailable
    );
    setUnitTemplateId(nextTemplates[0]?.id ?? "");
    setUnitQuantity(nextTemplates[0]?.defaultQuantity ?? 1);
  };

  const handleUnitTemplateChange = (nextTemplateId: string) => {
    setUnitTemplateId(nextTemplateId);
    const template = templatesForFaction.find((item) => item.id === nextTemplateId);

    if (template) {
      setUnitQuantity(template.defaultQuantity);
    }
  };

  const createUnitMutation = useMutation({
    mutationFn: () =>
      adminCreateUnit({
        factionId: unitFactionId,
        systemId: unitSystemId,
        unitTemplateId: effectiveUnitTemplateId,
        quantity: Math.max(1, unitQuantity),
        customName: unitCustomName.trim() || undefined
      }),
    onSuccess: async () => {
      setUnitCustomName("");
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const constructBuildingMutation = useMutation({
    mutationFn: () =>
      adminConstructBuilding({
        systemId: buildingSystemId,
        buildingTemplateId
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const setResourcesMutation = useMutation({
    mutationFn: () =>
      adminSetFactionResources({
        factionId: resourceFactionId,
        resources: resourceDraft
      }),
    onSuccess: async () => {
      setResourceDraftByFactionId((current) => {
        const next = { ...current };
        delete next[resourceFactionId];
        return next;
      });
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const setCapabilitiesMutation = useMutation({
    mutationFn: () =>
      adminSetSystemResourceCapabilities({
        systemId: capabilitySystemId,
        capabilities: capabilityDraft
      }),
    onSuccess: async () => {
      setCapabilityDraftBySystemId((current) => {
        const next = { ...current };
        delete next[capabilitySystemId];
        return next;
      });
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const setLimitsMutation = useMutation({
    mutationFn: () =>
      adminSetCampaignLimits({
        resourceCaps: limitDraft,
        maxArmyPoints: maxArmyPointsDraft
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const setSystemBlockMutation = useMutation({
    mutationFn: (blockedUntil: string | null) =>
      adminSetSystemBlock({
        systemId: blockSystemId,
        blockedUntil
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const updateUnitMutation = useMutation({
    mutationFn: ({ unit, draft }: { unit: CampaignUnit; draft: UnitEditDraft }) =>
      adminUpdateCampaignUnit({
        unitId: unit.id,
        systemId: draft.systemId || null,
        quantity: Math.max(0, draft.quantity),
        woundsTaken: Math.max(0, draft.woundsTaken),
        status: draft.status,
        isVisiblePublicly: draft.isVisiblePublicly
      }),
    onSuccess: async (_data, variables) => {
      setUnitDrafts((current) => {
        const next = { ...current };
        delete next[variables.unit.id];
        return next;
      });
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const updateBuildingMutation = useMutation({
    mutationFn: ({ building, draft }: { building: SystemBuilding; draft: BuildingEditDraft }) =>
      adminUpdateSystemBuilding({
        systemBuildingId: building.id,
        systemId: draft.systemId,
        buildingTemplateId: draft.buildingTemplateId,
        status: draft.status,
        finishesAt: draft.status === "constructing" ? fromDatetimeLocalValue(draft.finishesAt) : null
      }),
    onSuccess: async (_data, variables) => {
      setBuildingDrafts((current) => {
        const next = { ...current };
        delete next[variables.building.id];
        return next;
      });
      await queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  const getUnitDraft = (unit: CampaignUnit): UnitEditDraft =>
    unitDrafts[unit.id] ?? {
      systemId: unit.currentSystemId ?? editUnitSystemId,
      quantity: unit.quantity,
      woundsTaken: unit.woundsTaken,
      status: unit.status,
      isVisiblePublicly: unit.isVisiblePublicly
    };

  const updateUnitDraft = (unit: CampaignUnit, patch: Partial<UnitEditDraft>) => {
    setUnitDrafts((current) => ({
      ...current,
      [unit.id]: {
        ...getUnitDraft(unit),
        ...patch
      }
    }));
  };

  const getBuildingDraft = (building: SystemBuilding): BuildingEditDraft => {
    const fallbackTemplateId = snapshot.buildingTemplates[0]?.id ?? "";

    return (
      buildingDrafts[building.id] ?? {
        systemId: building.systemId,
        buildingTemplateId: building.buildingTemplateId ?? fallbackTemplateId,
        status: building.status,
        finishesAt: toDatetimeLocalValue(building.finishesAt)
      }
    );
  };

  const updateBuildingDraft = (building: SystemBuilding, patch: Partial<BuildingEditDraft>) => {
    setBuildingDrafts((current) => ({
      ...current,
      [building.id]: {
        ...getBuildingDraft(building),
        ...patch
      }
    }));
  };

  const getFactionName = (factionId: string) =>
    snapshot.factions.find((faction) => faction.id === factionId)?.name ?? "Faccion desconocida";

  return (
    <main className="mobile-scroll h-[var(--app-height)] px-4 py-4 md:px-5 md:py-5">
      <div className="mx-auto flex w-full max-w-7xl flex-col gap-4">
        <Panel className="p-4 md:p-5">
          <div className="mb-2 flex items-center gap-2">
            <Badge tone="rose">admin global</Badge>
            <Badge tone="slate">sin faccion de jugador</Badge>
          </div>
          <h1 className="text-xl font-semibold text-cyan-50 md:text-2xl">Consola de control absoluto</h1>
          <p className="mt-2 text-sm text-slate-300">
            Este modo no usa comercio ni arbol tecnologico de jugador. Todas las acciones se aplican a facciones y sistemas objetivo.
          </p>
          {!rpcReady ? (
            <p className="mt-3 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
              Supabase no esta configurado. La consola no puede ejecutar cambios.
            </p>
          ) : null}
        </Panel>

        <div className="grid gap-4 xl:grid-cols-2">
          <Panel className="p-4 md:p-5">
            <div className="mb-3 flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
                <ShieldPlus size={16} />
              </span>
              <h2 className="text-base font-semibold text-cyan-50">Crear tropas en cualquier sistema</h2>
            </div>
            <div className="grid gap-3">
              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => handleUnitFactionChange(event.target.value)} value={unitFactionId}>
                {snapshot.factions.map((faction) => (
                  <option key={faction.id} value={faction.id}>
                    {faction.name}
                  </option>
                ))}
              </select>

              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => setUnitSystemId(event.target.value)} value={unitSystemId}>
                {snapshot.systems.map((system) => (
                  <option key={system.id} value={system.id}>
                    {system.name}
                  </option>
                ))}
              </select>

              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => handleUnitTemplateChange(event.target.value)} value={effectiveUnitTemplateId}>
                {templatesForFaction.length > 0 ? (
                  templatesForFaction.map((template) => (
                    <option key={template.id} value={template.id}>
                      {template.name}
                    </option>
                  ))
                ) : (
                  <option value="">Sin plantillas para esta faccion</option>
                )}
              </select>

              <div className="grid grid-cols-2 gap-2">
                <input
                  className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm"
                  min={1}
                  onChange={(event) => setUnitQuantity(Math.max(1, toInt(event.target.value, 1)))}
                  type="number"
                  value={unitQuantity}
                />
                <input
                  className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm"
                  onChange={(event) => setUnitCustomName(event.target.value)}
                  placeholder="Nombre personalizado (opcional)"
                  value={unitCustomName}
                />
              </div>

              <Button
                disabled={!rpcReady || !unitFactionId || !unitSystemId || !effectiveUnitTemplateId || createUnitMutation.isPending}
                onClick={() => createUnitMutation.mutate()}
              >
                <Users size={16} />
                {createUnitMutation.isPending ? "Creando..." : "Crear unidad"}
              </Button>
              {createUnitMutation.error ? <p className="text-sm text-rose-200">{createUnitMutation.error.message}</p> : null}
            </div>
          </Panel>

          <Panel className="p-4 md:p-5">
            <div className="mb-3 flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
                <Building2 size={16} />
              </span>
              <h2 className="text-base font-semibold text-cyan-50">Construir edificios</h2>
            </div>
            <div className="grid gap-3">
              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => setBuildingSystemId(event.target.value)} value={buildingSystemId}>
                {snapshot.systems.map((system) => (
                  <option key={system.id} value={system.id}>
                    {system.name}{system.systemKind === "gaseous" ? " (gaseoso)" : ""}
                  </option>
                ))}
              </select>

              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => setBuildingTemplateId(event.target.value)} value={buildingTemplateId}>
                {snapshot.buildingTemplates
                  .filter((template) => template.isAvailable)
                  .map((template) => (
                    <option key={template.id} value={template.id}>
                      {template.name}
                    </option>
                  ))}
              </select>

              <Button
                disabled={
                  !rpcReady ||
                  !buildingSystemId ||
                  !buildingTemplateId ||
                  constructBuildingMutation.isPending ||
                  snapshot.systems.find((system) => system.id === buildingSystemId)?.systemKind === "gaseous"
                }
                onClick={() => constructBuildingMutation.mutate()}
              >
                <Factory size={16} />
                {constructBuildingMutation.isPending ? "Aplicando..." : "Construir ahora"}
              </Button>

              {snapshot.systems.find((system) => system.id === buildingSystemId)?.systemKind === "gaseous" ? (
                <p className="text-xs text-slate-400">Los sistemas gaseosos son no edificables, incluso para admin.</p>
              ) : null}
              {constructBuildingMutation.error ? <p className="text-sm text-rose-200">{constructBuildingMutation.error.message}</p> : null}
            </div>
          </Panel>
        </div>

        <div className="grid gap-4 xl:grid-cols-2">
          <Panel className="p-4 md:p-5">
            <div className="mb-3 flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-md border border-amber-200/20 bg-amber-300/10 text-amber-100">
                <ShieldAlert size={16} />
              </span>
              <h2 className="text-base font-semibold text-cyan-50">Bloquear o desbloquear sistema</h2>
            </div>
            <div className="grid gap-3">
              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => setBlockSystemId(event.target.value)} value={blockSystemId}>
                {snapshot.systems.map((system) => (
                  <option key={system.id} value={system.id}>
                    {system.name}
                  </option>
                ))}
              </select>
              <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-300">
                <div className="text-xs uppercase tracking-[0.18em] text-slate-500">Estado actual</div>
                <div className="mt-1 font-semibold text-cyan-50">
                  {selectedBlockSystem?.blockedUntil ? `Bloqueado hasta ${formatDateTime(selectedBlockSystem.blockedUntil)}` : "Sin bloqueo manual"}
                </div>
              </div>
              <label className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-2">
                <div className="mb-1 text-[11px] text-slate-400">Duracion del bloqueo en dias</div>
                <input
                  className="w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                  min={1}
                  onChange={(event) => setBlockDays(Math.max(1, toInt(event.target.value, 14)))}
                  type="number"
                  value={blockDays}
                />
              </label>
              <div className="grid gap-2 sm:grid-cols-2">
                <Button
                  disabled={!rpcReady || !blockSystemId || setSystemBlockMutation.isPending}
                  onClick={() => setSystemBlockMutation.mutate(new Date(Date.now() + blockDays * 24 * 60 * 60 * 1000).toISOString())}
                >
                  <Ban size={16} />
                  Bloquear
                </Button>
                <Button
                  disabled={!rpcReady || !blockSystemId || setSystemBlockMutation.isPending}
                  onClick={() => setSystemBlockMutation.mutate(null)}
                  variant="ghost"
                >
                  <CheckCircle2 size={16} />
                  Desbloquear
                </Button>
              </div>
              {setSystemBlockMutation.error ? <p className="text-sm text-rose-200">{setSystemBlockMutation.error.message}</p> : null}
            </div>
          </Panel>

          <Panel className="p-4 md:p-5">
            <div className="mb-3 flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
                <Users size={16} />
              </span>
              <h2 className="text-base font-semibold text-cyan-50">Editar tropas existentes</h2>
            </div>
            <div className="grid gap-3">
              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => setEditUnitSystemId(event.target.value)} value={editUnitSystemId}>
                {snapshot.systems.map((system) => (
                  <option key={system.id} value={system.id}>
                    {system.name}
                  </option>
                ))}
              </select>
              <div className="grid max-h-[32rem] gap-3 overflow-y-auto pr-1">
                {unitsInEditSystem.length > 0 ? (
                  unitsInEditSystem.map((unit) => {
                    const draft = getUnitDraft(unit);

                    return (
                      <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={unit.id}>
                        <div className="mb-3 flex flex-wrap items-start justify-between gap-2">
                          <div>
                            <h3 className="text-sm font-semibold text-cyan-50">{unit.name}</h3>
                            <p className="text-xs text-slate-400">
                              {getFactionName(unit.factionId)} · {unit.category} · {unit.points} pts
                            </p>
                          </div>
                          <Badge tone={unit.status === "ready" ? "cyan" : unit.status === "destroyed" ? "rose" : "amber"}>
                            {unit.status}
                          </Badge>
                        </div>
                        <div className="grid gap-2 md:grid-cols-2">
                          <label className="text-xs text-slate-400">
                            Sistema
                            <select
                              className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                              onChange={(event) => updateUnitDraft(unit, { systemId: event.target.value })}
                              value={draft.systemId}
                            >
                              {snapshot.systems.map((system) => (
                                <option key={system.id} value={system.id}>
                                  {system.name}
                                </option>
                              ))}
                            </select>
                          </label>
                          <label className="text-xs text-slate-400">
                            Estado
                            <select
                              className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                              onChange={(event) => updateUnitDraft(unit, { status: event.target.value as CampaignUnit["status"] })}
                              value={draft.status}
                            >
                              {unitStatusOptions.map((status) => (
                                <option key={status} value={status}>
                                  {status}
                                </option>
                              ))}
                            </select>
                          </label>
                          <label className="text-xs text-slate-400">
                            Miniaturas ({unit.startingQuantity} max.)
                            <input
                              className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                              max={unit.startingQuantity}
                              min={0}
                              onChange={(event) => updateUnitDraft(unit, { quantity: Math.max(0, toInt(event.target.value, unit.quantity)) })}
                              type="number"
                              value={draft.quantity}
                            />
                          </label>
                          <label className="text-xs text-slate-400">
                            Heridas
                            <input
                              className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                              min={0}
                              onChange={(event) => updateUnitDraft(unit, { woundsTaken: Math.max(0, toInt(event.target.value, unit.woundsTaken)) })}
                              type="number"
                              value={draft.woundsTaken}
                            />
                          </label>
                        </div>
                        <label className="mt-3 flex items-center gap-2 text-xs text-slate-300">
                          <input
                            checked={draft.isVisiblePublicly}
                            onChange={(event) => updateUnitDraft(unit, { isVisiblePublicly: event.target.checked })}
                            type="checkbox"
                          />
                          Visible publicamente
                        </label>
                        <Button
                          className="mt-3 w-full"
                          disabled={!rpcReady || updateUnitMutation.isPending}
                          onClick={() => updateUnitMutation.mutate({ unit, draft })}
                        >
                          <Save size={16} />
                          Guardar tropa
                        </Button>
                      </div>
                    );
                  })
                ) : (
                  <p className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
                    No hay tropas no destruidas en este sistema.
                  </p>
                )}
              </div>
              {updateUnitMutation.error ? <p className="text-sm text-rose-200">{updateUnitMutation.error.message}</p> : null}
            </div>
          </Panel>
        </div>

        <Panel className="p-4 md:p-5">
          <div className="mb-3 flex items-center gap-2">
            <span className="grid size-8 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
              <Building2 size={16} />
            </span>
            <h2 className="text-base font-semibold text-cyan-50">Editar edificios existentes</h2>
          </div>
          <div className="grid gap-3">
            <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => setEditBuildingSystemId(event.target.value)} value={editBuildingSystemId}>
              {snapshot.systems.map((system) => (
                <option key={system.id} value={system.id}>
                  {system.name}{system.systemKind === "gaseous" ? " (gaseoso)" : ""}
                </option>
              ))}
            </select>
            <div className="grid gap-3 xl:grid-cols-2">
              {buildingsInEditSystem.length > 0 ? (
                buildingsInEditSystem.map((building) => {
                  const draft = getBuildingDraft(building);
                  const template = snapshot.buildingTemplates.find((item) => item.id === building.buildingTemplateId);

                  return (
                    <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3" key={building.id}>
                      <div className="mb-3 flex flex-wrap items-start justify-between gap-2">
                        <div>
                          <h3 className="text-sm font-semibold text-cyan-50">{template?.name ?? "Edificio sin detalles"}</h3>
                          <p className="text-xs text-slate-400">{building.status}</p>
                        </div>
                        <Badge tone={building.status === "active" ? "cyan" : building.status === "disabled" ? "rose" : "amber"}>
                          {building.status}
                        </Badge>
                      </div>
                      <div className="grid gap-2 md:grid-cols-2">
                        <label className="text-xs text-slate-400">
                          Sistema
                          <select
                            className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                            onChange={(event) => updateBuildingDraft(building, { systemId: event.target.value })}
                            value={draft.systemId}
                          >
                            {snapshot.systems
                              .filter((system) => system.systemKind !== "gaseous")
                              .map((system) => (
                                <option key={system.id} value={system.id}>
                                  {system.name}
                                </option>
                              ))}
                          </select>
                        </label>
                        <label className="text-xs text-slate-400">
                          Edificio
                          <select
                            className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                            onChange={(event) => updateBuildingDraft(building, { buildingTemplateId: event.target.value })}
                            value={draft.buildingTemplateId}
                          >
                            {snapshot.buildingTemplates.map((buildingTemplate) => (
                              <option key={buildingTemplate.id} value={buildingTemplate.id}>
                                {buildingTemplate.name}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="text-xs text-slate-400">
                          Estado
                          <select
                            className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                            onChange={(event) => updateBuildingDraft(building, { status: event.target.value as SystemBuilding["status"] })}
                            value={draft.status}
                          >
                            {buildingStatusOptions.map((status) => (
                              <option key={status} value={status}>
                                {status}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="text-xs text-slate-400">
                          Fin construccion
                          <input
                            className="mt-1 w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                            disabled={draft.status !== "constructing"}
                            onChange={(event) => updateBuildingDraft(building, { finishesAt: event.target.value })}
                            type="datetime-local"
                            value={draft.finishesAt}
                          />
                        </label>
                      </div>
                      <Button
                        className="mt-3 w-full"
                        disabled={!rpcReady || updateBuildingMutation.isPending || !draft.buildingTemplateId || !draft.systemId}
                        onClick={() => updateBuildingMutation.mutate({ building, draft })}
                      >
                        <Save size={16} />
                        Guardar edificio
                      </Button>
                    </div>
                  );
                })
              ) : (
                <p className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3 text-sm text-slate-400">
                  Este sistema no tiene edificios registrados.
                </p>
              )}
            </div>
            {updateBuildingMutation.error ? <p className="text-sm text-rose-200">{updateBuildingMutation.error.message}</p> : null}
          </div>
        </Panel>

        <Panel className="p-4 md:p-5">
          <div className="mb-3 flex items-center gap-2">
            <span className="grid size-8 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
              <SlidersHorizontal size={16} />
            </span>
            <h2 className="text-base font-semibold text-cyan-50">Limites de campana</h2>
          </div>

          <div className="grid gap-4 xl:grid-cols-[1fr_320px]">
            <div className="grid gap-3">
              <ResourceEditorGrid
                keys={factionResourceKeys}
                value={limitDraft}
                onChange={(resourceKey, nextValue) =>
                  setLimitDraft((current) => ({
                    ...current,
                    [resourceKey]: nextValue
                  }))
                }
              />
              <label className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-2">
                <div className="mb-1 text-[11px] text-slate-400">Maximo de puntos de ejercito</div>
                <input
                  className="w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
                  min={0}
                  onChange={(event) => setMaxArmyPointsDraft(Math.max(0, toInt(event.target.value, 0)))}
                  type="number"
                  value={maxArmyPointsDraft}
                />
              </label>
              <Button disabled={!rpcReady || setLimitsMutation.isPending} onClick={() => setLimitsMutation.mutate()}>
                Guardar limites
              </Button>
              {setLimitsMutation.error ? <p className="text-sm text-rose-200">{setLimitsMutation.error.message}</p> : null}
            </div>

            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-3">
              <h3 className="mb-3 text-sm font-semibold text-cyan-50">Puntos usados por faccion</h3>
              <div className="space-y-2">
                {snapshot.factions.map((faction) => (
                  <div className="flex items-center justify-between gap-3 text-sm" key={faction.id}>
                    <span className="inline-flex min-w-0 items-center gap-2 text-slate-300">
                      <span className="size-2 shrink-0 rounded-full" style={{ backgroundColor: faction.color }} />
                      <span className="truncate">{faction.name}</span>
                    </span>
                    <span className="font-semibold tabular-nums text-cyan-50">
                      {getFactionArmyPoints(snapshot, faction.id)}/{snapshot.maxArmyPoints}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </Panel>

        <div className="grid gap-4 xl:grid-cols-2">
          <Panel className="p-4 md:p-5">
            <div className="mb-3 flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
                <SlidersHorizontal size={16} />
              </span>
              <h2 className="text-base font-semibold text-cyan-50">Editar recursos por facción</h2>
            </div>

            <div className="grid gap-3">
              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => setResourceFactionId(event.target.value)} value={resourceFactionId}>
                {snapshot.factions.map((faction) => (
                  <option key={faction.id} value={faction.id}>
                    {faction.name}
                  </option>
                ))}
              </select>

              <ResourceEditorGrid
                keys={factionResourceKeys}
                value={resourceDraft}
                onChange={(resourceKey, nextValue) =>
                  setResourceDraftByFactionId((current) => ({
                    ...current,
                    [resourceFactionId]: {
                      ...(current[resourceFactionId] ?? toEditableFactionResources(selectedFactionResources)),
                      [resourceKey]: nextValue
                    }
                  }))
                }
              />

              <Button disabled={!rpcReady || !resourceFactionId || setResourcesMutation.isPending} onClick={() => setResourcesMutation.mutate()}>
                Guardar recursos de facción
              </Button>
              {setResourcesMutation.error ? <p className="text-sm text-rose-200">{setResourcesMutation.error.message}</p> : null}
            </div>
          </Panel>

          <Panel className="p-4 md:p-5">
            <div className="mb-3 flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-md border border-cyan-200/20 bg-cyan-300/10 text-cyan-100">
                <Factory size={16} />
              </span>
              <h2 className="text-base font-semibold text-cyan-50">Editar capacidad base por planeta</h2>
            </div>

            <div className="grid gap-3">
              <select className="rounded-md border border-cyan-200/15 bg-slate-950/40 px-3 py-2 text-sm" onChange={(event) => setCapabilitySystemId(event.target.value)} value={capabilitySystemId}>
                {snapshot.systems.map((system) => (
                  <option key={system.id} value={system.id}>
                    {system.name}
                  </option>
                ))}
              </select>

              <ResourceEditorGrid
                keys={systemCapabilityKeys}
                value={capabilityDraft}
                onChange={(resourceKey, nextValue) =>
                  setCapabilityDraftBySystemId((current) => ({
                    ...current,
                    [capabilitySystemId]: {
                      ...(current[capabilitySystemId] ??
                        toEditableSystemCapabilities(selectedCapabilitySystem ?? undefined, snapshot.systemResourceCapabilities)),
                      [resourceKey]: nextValue
                    }
                  }))
                }
              />

              {selectedCapabilitySystem?.systemKind === "gaseous" ? (
                <p className="text-xs text-slate-400">Sistema gaseoso: al guardar, la capacidad se fuerza a 0 en todos los recursos.</p>
              ) : null}

              <Button disabled={!rpcReady || !capabilitySystemId || setCapabilitiesMutation.isPending} onClick={() => setCapabilitiesMutation.mutate()}>
                Guardar capacidad del sistema
              </Button>
              {setCapabilitiesMutation.error ? <p className="text-sm text-rose-200">{setCapabilitiesMutation.error.message}</p> : null}
            </div>
          </Panel>
        </div>
      </div>
    </main>
  );
}

function ResourceEditorGrid<K extends keyof ResourceBundle>({
  keys,
  value,
  onChange
}: {
  keys: readonly K[];
  value: Record<K, number>;
  onChange: (resourceKey: K, nextValue: number) => void;
}) {
  return (
    <div className="grid grid-cols-2 gap-2">
      {keys.map((resourceKey) => (
        <label className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-2" key={resourceKey}>
          <div className="mb-1 flex items-center gap-1.5 text-[11px] text-slate-400">
            <ResourceIcon className="size-4" resource={resourceKey} />
            {resourceLabels[resourceKey]}
          </div>
          <input
            className="w-full rounded-md border border-cyan-200/15 bg-slate-950/50 px-2 py-1.5 text-sm text-cyan-50"
            min={0}
            onChange={(event) => onChange(resourceKey, Math.max(0, toInt(event.target.value, 0)))}
            type="number"
            value={value[resourceKey] ?? 0}
          />
        </label>
      ))}
    </div>
  );
}

function toEditableFactionResources(resource?: Partial<EditableFactionResources> | null): EditableFactionResources {
  return {
    supply: resource?.supply ?? 0,
    minerals: resource?.minerals ?? 0,
    honor: resource?.honor ?? 0,
    gold: resource?.gold ?? 0,
    industrialMaterial: resource?.industrialMaterial ?? 0,
    uridium: resource?.uridium ?? 0,
    technology: resource?.technology ?? 0
  };
}

function toEditableSystemCapabilities(
  system: CampaignSnapshot["systems"][number] | undefined,
  capabilities: CampaignSnapshot["systemResourceCapabilities"]
): EditableSystemCapabilities {
  if (!system || system.systemKind === "gaseous") {
    return {
      supply: 0,
      minerals: 0,
      honor: 0,
      gold: 0,
      industrialMaterial: 0,
      uridium: 0
    };
  }

  const systemCapabilities = capabilities.filter((capability) => capability.systemId === system.id);

  return {
    supply: systemCapabilities.find((capability) => capability.resourceKey === "supply")?.productionAmount ?? 0,
    minerals: systemCapabilities.find((capability) => capability.resourceKey === "minerals")?.productionAmount ?? 0,
    honor: systemCapabilities.find((capability) => capability.resourceKey === "honor")?.productionAmount ?? 0,
    gold: systemCapabilities.find((capability) => capability.resourceKey === "gold")?.productionAmount ?? 0,
    industrialMaterial:
      systemCapabilities.find((capability) => capability.resourceKey === "industrialMaterial")?.productionAmount ?? 0,
    uridium: systemCapabilities.find((capability) => capability.resourceKey === "uridium")?.productionAmount ?? 0
  };
}

function toInt(value: string, fallback: number) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function formatDateTime(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString("es-ES", {
    dateStyle: "short",
    timeStyle: "short"
  });
}

function toDatetimeLocalValue(value?: string | null) {
  if (!value) {
    return "";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "";
  }

  const offsetMs = date.getTimezoneOffset() * 60 * 1000;
  return new Date(date.getTime() - offsetMs).toISOString().slice(0, 16);
}

function fromDatetimeLocalValue(value: string) {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}
