"use client";

import Image from "next/image";
import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { HandCoins, Minus, Plus, Store, X } from "lucide-react";
import merchantAvatar from "../../../../icons/resources/merchant1.png";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { ResourceAmount, ResourceIcon, resourceLabels } from "@/components/ui/resource-icon";
import {
  acceptTradeOffer,
  cancelTradeOffer,
  canUseTradeRpc,
  createTradeOffer,
  merchantTrade,
  type MerchantTradeDirection
} from "@/features/trade/api/trade-api";
import type { CampaignSnapshot, FactionResources, TradeOffer, TradeOfferType, TradeableResourceKey } from "@/domain/campaign";

const tradeableResources: TradeableResourceKey[] = ["supply", "minerals", "industrialMaterial", "uridium"];

const resourcePointValues: Record<TradeableResourceKey | "gold", number> = {
  supply: 1,
  minerals: 2,
  uridium: 2,
  industrialMaterial: 2,
  gold: 5
};

export function TradeModal({
  snapshot,
  open,
  lockedReason,
  onClose
}: {
  snapshot: CampaignSnapshot;
  open: boolean;
  lockedReason?: string | null;
  onClose: () => void;
}) {
  const [tab, setTab] = useState<"merchant" | "stellar">("merchant");

  if (!open) {
    return null;
  }

  return (
    <div className="pointer-events-auto fixed inset-0 z-40 grid place-items-center bg-black/58 p-0 backdrop-blur-sm md:px-4 md:py-6">
      <Panel className="flex h-[var(--app-height)] w-full max-w-6xl flex-col overflow-hidden rounded-none md:h-auto md:max-h-[88vh] md:rounded-lg">
        <div className="shrink-0 border-b border-amber-200/15 px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))] md:p-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="text-xs uppercase tracking-[0.24em] text-amber-200/70">Comercio</div>
              <h2 className="mt-1 text-2xl font-semibold text-cyan-50">Mercados del frente</h2>
            </div>
            <Button aria-label="Cerrar comercio" onClick={onClose} size="icon" variant="ghost">
              <X size={18} />
            </Button>
          </div>

          <div className="mt-4 grid grid-cols-2 gap-2 md:w-fit">
            <Button
              onClick={() => setTab("merchant")}
              size="sm"
              variant={tab === "merchant" ? "primary" : "ghost"}
            >
              <Store size={15} />
              Mercader
            </Button>
            <Button
              onClick={() => setTab("stellar")}
              size="sm"
              variant={tab === "stellar" ? "primary" : "ghost"}
            >
              <HandCoins size={15} />
              Comercio estelar
            </Button>
          </div>
        </div>

        <div className="mobile-scroll flex-1">
          {lockedReason ? (
            <div className="grid min-h-full place-items-center p-6 text-center">
              <div className="max-w-md">
                <div className="mx-auto mb-4 grid size-14 place-items-center rounded-md border border-amber-300/30 bg-amber-300/10 text-amber-100">
                  <Store size={25} />
                </div>
                <h3 className="text-xl font-semibold text-cyan-50">Comercio bloqueado</h3>
                <p className="mt-2 text-sm leading-6 text-slate-300">{lockedReason}</p>
              </div>
            </div>
          ) : tab === "merchant" ? (
            <MerchantPanel snapshot={snapshot} />
          ) : (
            <StellarTradePanel snapshot={snapshot} />
          )}
        </div>
      </Panel>
    </div>
  );
}

function MerchantPanel({ snapshot }: { snapshot: CampaignSnapshot }) {
  const queryClient = useQueryClient();
  const resources = getCurrentResources(snapshot);
  const rpcReady = canUseTradeRpc();
  const [resourceKey, setResourceKey] = useState<TradeableResourceKey>("minerals");
  const [quantity, setQuantity] = useState(10);
  const merchantBuyCost = getMerchantBuyCost(resourceKey, quantity);
  const merchantSellPayout = getMerchantSellPayout(resourceKey, quantity);
  const ownedResource = resources?.[resourceKey] ?? 0;
  const ownedGold = resources?.gold ?? 0;
  const canBuy = rpcReady && ownedGold >= merchantBuyCost;
  const canSell = rpcReady && ownedResource >= quantity;
  const mutation = useMutation({
    mutationFn: ({ direction }: { direction: MerchantTradeDirection }) => merchantTrade(resourceKey, direction, quantity),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  return (
    <div className="grid gap-4 p-4 md:grid-cols-[300px_1fr] md:p-5">
      <aside className="rounded-lg border border-amber-200/15 bg-slate-950/38 p-4">
        <div className="relative mx-auto aspect-square max-w-48 overflow-hidden rounded-lg border border-amber-200/25 bg-amber-300/8 shadow-[0_0_28px_rgba(251,191,36,0.12)]">
          <Image alt="Mercader estelar" className="object-cover" fill priority sizes="192px" src={merchantAvatar} />
        </div>
        <h3 className="mt-4 text-lg font-semibold text-amber-50">Mercader de frontera</h3>
        <p className="mt-2 text-sm leading-6 text-slate-300">
          Vende recursos al doble de su valor y compra a mitad de precio, redondeando siempre hacia arriba.
        </p>
        <div className="mt-4 rounded-md border border-amber-200/15 bg-slate-950/45 p-3">
          <div className="mb-2 text-xs uppercase tracking-[0.18em] text-amber-200/70">Caja disponible</div>
          <ResourceAmount resource="gold" value={ownedGold} />
        </div>
      </aside>

      <section className="min-w-0">
        {!rpcReady ? (
          <div className="mb-4 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
            Supabase no esta configurado. Puedes revisar precios, pero no comerciar.
          </div>
        ) : null}

        <div className="mb-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
          {tradeableResources.map((resource) => (
            <button
              className={`rounded-md border p-3 text-left transition ${
                resource === resourceKey
                  ? "border-amber-200/55 bg-amber-300/12 shadow-[0_0_20px_rgba(251,191,36,0.12)]"
                  : "border-cyan-200/15 bg-slate-950/35 hover:border-amber-200/30"
              }`}
              key={resource}
              onClick={() => setResourceKey(resource)}
              type="button"
            >
              <div className="mb-2 flex items-center gap-2 text-xs text-slate-400">
                <ResourceIcon className="size-5" resource={resource} />
                {resourceLabels[resource]}
              </div>
              <div className="font-semibold tabular-nums text-cyan-50">{ownedResourceFor(resources, resource)}</div>
            </button>
          ))}
        </div>

        <div className="mb-4 rounded-md border border-cyan-200/15 bg-slate-950/35 p-3">
          <div className="mb-3 flex items-center justify-between gap-3">
            <div>
              <div className="text-sm font-semibold text-cyan-50">Cantidad</div>
              <div className="text-xs text-slate-400">Recurso seleccionado: {resourceLabels[resourceKey]}</div>
            </div>
            <Badge tone="amber">{resourcePointValues[resourceKey]} pts/u</Badge>
          </div>
          <div className="flex items-center justify-between rounded-md border border-cyan-200/10 bg-slate-950/40 p-2">
            <Button disabled={quantity <= 1 || mutation.isPending} onClick={() => setQuantity((value) => Math.max(1, value - 5))} size="icon" variant="ghost">
              <Minus size={15} />
            </Button>
            <input
              className="w-24 bg-transparent text-center text-lg font-semibold tabular-nums text-cyan-50 outline-none"
              min={1}
              onChange={(event) => setQuantity(clampInteger(Number(event.target.value), 1, 9999))}
              type="number"
              value={quantity}
            />
            <Button disabled={mutation.isPending} onClick={() => setQuantity((value) => Math.min(9999, value + 5))} size="icon" variant="ghost">
              <Plus size={15} />
            </Button>
          </div>
        </div>

        <div className="grid gap-3 md:grid-cols-2">
          <TradeActionCard
            action="Comprar al mercader"
            buttonText="Comprar"
            disabled={!canBuy || mutation.isPending}
            onClick={() => mutation.mutate({ direction: "buy" })}
            primaryResource={resourceKey}
            primaryValue={quantity}
            secondaryResource="gold"
            secondaryValue={merchantBuyCost}
            tone="buy"
            pending={mutation.isPending}
          />
          <TradeActionCard
            action="Vender al mercader"
            buttonText="Vender"
            disabled={!canSell || mutation.isPending}
            onClick={() => mutation.mutate({ direction: "sell" })}
            primaryResource={resourceKey}
            primaryValue={quantity}
            secondaryResource="gold"
            secondaryValue={merchantSellPayout}
            tone="sell"
            pending={mutation.isPending}
          />
        </div>

        {mutation.error ? <p className="mt-3 text-sm text-rose-200">{mutation.error.message}</p> : null}
      </section>
    </div>
  );
}

function StellarTradePanel({ snapshot }: { snapshot: CampaignSnapshot }) {
  const queryClient = useQueryClient();
  const resources = getCurrentResources(snapshot);
  const rpcReady = canUseTradeRpc();
  const [offerType, setOfferType] = useState<TradeOfferType>("buy");
  const [resourceKey, setResourceKey] = useState<TradeableResourceKey>("minerals");
  const [resourceAmount, setResourceAmount] = useState(10);
  const [goldAmount, setGoldAmount] = useState(6);
  const openOffers = useMemo(
    () => snapshot.tradeOffers.filter((offer) => offer.status === "open"),
    [snapshot.tradeOffers]
  );
  const feeGold = getTradeFee(goldAmount);
  const createMutation = useMutation({
    mutationFn: () => createTradeOffer(offerType, resourceKey, resourceAmount, goldAmount),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const acceptMutation = useMutation({
    mutationFn: acceptTradeOffer,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });
  const cancelMutation = useMutation({
    mutationFn: cancelTradeOffer,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["campaign-snapshot"] });
    }
  });

  return (
    <div className="grid gap-4 p-4 md:grid-cols-[360px_1fr] md:p-5">
      <aside className="rounded-lg border border-cyan-200/15 bg-slate-950/38 p-4">
        <h3 className="text-lg font-semibold text-cyan-50">Publicar oferta</h3>
        <p className="mt-2 text-sm leading-6 text-slate-300">
          Las ofertas son recurso contra oro. La comision es del 30% en oro para cada jugador al aceptar.
        </p>

        <ResourceStrip className="mt-4" resources={resources} />

        <div className="mt-4 grid grid-cols-2 gap-2">
          <Button onClick={() => setOfferType("buy")} size="sm" variant={offerType === "buy" ? "primary" : "ghost"}>
            Comprar
          </Button>
          <Button onClick={() => setOfferType("sell")} size="sm" variant={offerType === "sell" ? "primary" : "ghost"}>
            Vender
          </Button>
        </div>

        <label className="mt-4 block text-sm">
          <span className="mb-2 block text-slate-300">Recurso</span>
          <select
            className="w-full rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
            onChange={(event) => setResourceKey(event.target.value as TradeableResourceKey)}
            value={resourceKey}
          >
            {tradeableResources.map((resource) => (
              <option key={resource} value={resource}>
                {resourceLabels[resource]}
              </option>
            ))}
          </select>
        </label>

        <NumberField label="Cantidad de recurso" onChange={setResourceAmount} value={resourceAmount} />
        <NumberField label="Oro ofertado" onChange={setGoldAmount} value={goldAmount} />

        <div className="mt-4 rounded-md border border-amber-200/15 bg-amber-300/8 p-3 text-sm text-amber-50">
          Comision por jugador: <ResourceAmount resource="gold" value={feeGold} />
        </div>

        {!rpcReady ? (
          <div className="mt-3 rounded-md border border-amber-300/25 bg-amber-300/10 p-3 text-sm text-amber-100">
            Supabase no esta configurado.
          </div>
        ) : null}

        {createMutation.error ? <p className="mt-3 text-sm text-rose-200">{createMutation.error.message}</p> : null}

        <Button
          className="mt-4 w-full"
          disabled={!rpcReady || createMutation.isPending || resourceAmount < 1 || goldAmount < 1}
          onClick={() => createMutation.mutate()}
        >
          {createMutation.isPending ? "Creando..." : "Crear oferta"}
        </Button>
      </aside>

      <section className="min-w-0">
        <div className="mb-3 flex items-center justify-between gap-3">
          <h3 className="text-lg font-semibold text-cyan-50">Ofertas abiertas</h3>
          <Badge tone="cyan">{openOffers.length}</Badge>
        </div>

        <div className="grid gap-3 xl:grid-cols-2">
          {openOffers.length > 0 ? (
            openOffers.map((offer) => (
              <TradeOfferCard
                acceptPending={acceptMutation.isPending}
                cancelPending={cancelMutation.isPending}
                key={offer.id}
                offer={offer}
                onAccept={() => acceptMutation.mutate(offer.id)}
                onCancel={() => cancelMutation.mutate(offer.id)}
                snapshot={snapshot}
              />
            ))
          ) : (
            <div className="rounded-md border border-cyan-200/15 bg-slate-950/35 p-4 text-sm text-slate-400">
              No hay ofertas abiertas.
            </div>
          )}
        </div>

        {acceptMutation.error ? <p className="mt-3 text-sm text-rose-200">{acceptMutation.error.message}</p> : null}
        {cancelMutation.error ? <p className="mt-3 text-sm text-rose-200">{cancelMutation.error.message}</p> : null}
      </section>
    </div>
  );
}

function TradeOfferCard({
  snapshot,
  offer,
  acceptPending,
  cancelPending,
  onAccept,
  onCancel
}: {
  snapshot: CampaignSnapshot;
  offer: TradeOffer;
  acceptPending: boolean;
  cancelPending: boolean;
  onAccept: () => void;
  onCancel: () => void;
}) {
  const creator = snapshot.factions.find((faction) => faction.id === offer.creatorFactionId);
  const isOwn = offer.creatorFactionId === snapshot.currentUser.factionId;

  return (
    <div className="rounded-lg border border-cyan-200/15 bg-slate-950/35 p-4">
      <div className="mb-3 flex items-start justify-between gap-3">
        <div>
          <div className="inline-flex items-center gap-2 text-sm font-medium text-slate-100">
            <span className="size-2 rounded-full" style={{ backgroundColor: creator?.color ?? "#94a3b8" }} />
            {creator?.name ?? "Faccion"}
          </div>
          <div className="mt-1 text-xs text-slate-400">
            {offer.offerType === "buy" ? "Quiere comprar" : "Quiere vender"}
          </div>
        </div>
        <Badge tone={offer.offerType === "buy" ? "cyan" : "amber"}>
          {offer.offerType === "buy" ? "Compra" : "Venta"}
        </Badge>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <div className="rounded-md border border-cyan-200/10 bg-slate-950/45 p-3">
          <div className="mb-1 text-xs text-slate-400">Recurso</div>
          <ResourceAmount resource={offer.resourceKey} value={offer.resourceAmount} />
        </div>
        <div className="rounded-md border border-amber-200/10 bg-slate-950/45 p-3">
          <div className="mb-1 text-xs text-slate-400">Oro</div>
          <ResourceAmount resource="gold" value={offer.goldAmount} />
        </div>
      </div>

      <div className="mt-3 rounded-md border border-amber-200/15 bg-amber-300/8 p-3 text-xs text-amber-50">
        Comision de cada parte: <ResourceAmount className="text-amber-50" resource="gold" value={offer.feeGold} />
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2">
        {isOwn ? (
          <Button className="col-span-2" disabled={cancelPending} onClick={onCancel} size="sm" variant="ghost">
            {cancelPending ? "Cancelando..." : "Cancelar"}
          </Button>
        ) : (
          <Button className="col-span-2" disabled={acceptPending} onClick={onAccept} size="sm">
            {acceptPending ? "Aceptando..." : "Aceptar"}
          </Button>
        )}
      </div>
    </div>
  );
}

function TradeActionCard({
  action,
  buttonText,
  primaryResource,
  primaryValue,
  secondaryResource,
  secondaryValue,
  disabled,
  tone,
  pending,
  onClick
}: {
  action: string;
  buttonText: string;
  primaryResource: TradeableResourceKey;
  primaryValue: number;
  secondaryResource: "gold";
  secondaryValue: number;
  disabled: boolean;
  tone: "buy" | "sell";
  pending?: boolean;
  onClick: () => void;
}) {
  return (
    <div className="rounded-lg border border-cyan-200/15 bg-slate-950/35 p-4">
      <div className="mb-3 flex items-center justify-between gap-3">
        <h3 className="font-semibold text-cyan-50">{action}</h3>
        <Badge tone={tone === "buy" ? "cyan" : "amber"}>{tone === "buy" ? "Pagas" : "Recibes"}</Badge>
      </div>
      <div className="mb-4 grid grid-cols-2 gap-2">
        <div className="rounded-md border border-cyan-200/10 bg-slate-950/45 p-3">
          <div className="mb-1 text-xs text-slate-400">Recurso</div>
          <ResourceAmount resource={primaryResource} value={primaryValue} />
        </div>
        <div className="rounded-md border border-amber-200/10 bg-slate-950/45 p-3">
          <div className="mb-1 text-xs text-slate-400">Oro</div>
          <ResourceAmount resource={secondaryResource} value={secondaryValue} />
        </div>
      </div>
      <Button className="w-full" disabled={disabled} onClick={onClick}>
        {pending ? "Procesando..." : buttonText}
      </Button>
    </div>
  );
}

function ResourceStrip({ resources, className }: { resources?: FactionResources; className?: string }) {
  return (
    <div className={`mb-4 grid grid-cols-6 gap-1.5 ${className ?? ""}`}>
      {(["supply", "minerals", "honor", "gold", "industrialMaterial", "uridium"] as const).map((resource) => (
        <div className="min-w-0 rounded-md border border-cyan-200/15 bg-slate-950/45 px-1.5 py-2 text-center" key={resource}>
          <ResourceIcon className="mx-auto mb-1 size-4" resource={resource} />
          <div className="truncate text-[clamp(0.68rem,2.6vw,0.9rem)] font-semibold tabular-nums text-cyan-50">
            {formatCompactResource(resources?.[resource] ?? 0)}
          </div>
        </div>
      ))}
    </div>
  );
}

function NumberField({
  label,
  value,
  onChange
}: {
  label: string;
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <label className="mt-4 block text-sm">
      <span className="mb-2 block text-slate-300">{label}</span>
      <input
        className="w-full rounded-md border border-cyan-200/15 bg-slate-950/70 px-3 py-2 text-sm text-cyan-50 outline-none"
        min={1}
        onChange={(event) => onChange(clampInteger(Number(event.target.value), 1, 9999))}
        type="number"
        value={value}
      />
    </label>
  );
}

function getCurrentResources(snapshot: CampaignSnapshot) {
  return snapshot.resources.find((item) => item.factionId === snapshot.currentUser.factionId);
}

function ownedResourceFor(resources: FactionResources | undefined, resource: TradeableResourceKey) {
  return formatCompactResource(resources?.[resource] ?? 0);
}

function getMerchantBuyCost(resource: TradeableResourceKey, quantity: number) {
  return Math.ceil((resourcePointValues[resource] * quantity * 2) / resourcePointValues.gold);
}

function getMerchantSellPayout(resource: TradeableResourceKey, quantity: number) {
  return Math.ceil((resourcePointValues[resource] * quantity * 0.5) / resourcePointValues.gold);
}

function getTradeFee(goldAmount: number) {
  return Math.ceil(Math.max(0, goldAmount) * 0.3);
}

function clampInteger(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, Math.trunc(Number.isFinite(value) ? value : min)));
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
