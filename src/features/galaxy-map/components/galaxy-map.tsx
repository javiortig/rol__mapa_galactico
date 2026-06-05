"use client";

import { useEffect, useMemo, useRef } from "react";
import * as PIXI from "pixi.js";
import type { Faction, MovementOrder, StarClass, StarSystem, SystemEdge } from "@/domain/campaign";
import { useCampaignUiStore } from "@/features/campaign/store/campaign-ui-store";

interface GalaxyMapProps {
  systems: StarSystem[];
  edges: SystemEdge[];
  factions: Faction[];
  movements: MovementOrder[];
  movementPlanning?: MovementPlanning;
}

type MovementPlanning = {
  active: boolean;
  originSystemId: string;
  pathSystemIds: string[];
  onSystemHover: (systemId: string | null) => void;
  onSystemClick: (systemId: string) => void;
};

type ViewState = {
  scale: number;
  x: number;
  y: number;
};

type MapData = GalaxyMapProps & {
  factionColorById: Map<string, string>;
};

type MapLayers = {
  background: PIXI.Container;
  routes: PIXI.Container;
  routeEffects: PIXI.Container;
  systems: PIXI.Container;
  effects: PIXI.Container;
  movement: PIXI.Container;
  labels: PIXI.Container;
};

type BackgroundStar = {
  node: PIXI.Graphics;
  baseAlpha: number;
  phase: number;
  speed: number;
};

type LabelRecord = {
  label: PIXI.Text;
  system: StarSystem;
};

type PixiMapState = {
  app: PIXI.Application;
  world: PIXI.Container;
  layers: MapLayers;
  view: ViewState;
  targetView: ViewState | null;
  labels: LabelRecord[];
  backgroundStars: BackgroundStar[];
  cleanup: () => void;
};

const starClasses: StarClass[] = ["blue", "white", "yellow", "orange", "red", "violet", "green"];

const starPalette: Record<StarClass, { core: number; corona: number; halo: number; name: string }> = {
  blue: { core: 0xe4f7ff, corona: 0x60a5fa, halo: 0x0ea5e9, name: "Azul" },
  white: { core: 0xffffff, corona: 0xdbeafe, halo: 0x93c5fd, name: "Blanca" },
  yellow: { core: 0xfff7cc, corona: 0xfacc15, halo: 0xf59e0b, name: "Amarilla" },
  orange: { core: 0xffedd5, corona: 0xfb923c, halo: 0xea580c, name: "Naranja" },
  red: { core: 0xffe4e6, corona: 0xfb7185, halo: 0xbe123c, name: "Roja" },
  violet: { core: 0xf5e8ff, corona: 0xc084fc, halo: 0x7c3aed, name: "Violeta" },
  green: { core: 0xdcfce7, corona: 0x34d399, halo: 0x059669, name: "Verde" }
};

export function GalaxyMap({ systems, edges, factions, movements, movementPlanning }: GalaxyMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const pixiStateRef = useRef<PixiMapState | null>(null);
  const dataRef = useRef<MapData | null>(null);
  const movementPlanningRef = useRef<MovementPlanning | undefined>(movementPlanning);
  const selectedSystemId = useCampaignUiStore((state) => state.selectedSystemId);
  const hoveredSystemId = useCampaignUiStore((state) => state.hoveredSystemId);
  const movementOriginSystemId = useCampaignUiStore((state) => state.movementOriginSystemId);
  const setSelectedSystem = useCampaignUiStore((state) => state.setSelectedSystem);
  const setHoveredSystem = useCampaignUiStore((state) => state.setHoveredSystem);
  const setTooltipPosition = useCampaignUiStore((state) => state.setTooltipPosition);
  const selectedSystemIdRef = useRef(selectedSystemId);
  const hoveredSystemIdRef = useRef(hoveredSystemId);
  const movementOriginSystemIdRef = useRef(movementOriginSystemId);
  const factionColorById = useMemo(
    () => new Map(factions.map((faction) => [faction.id, faction.color])),
    [factions]
  );

  useEffect(() => {
    selectedSystemIdRef.current = selectedSystemId;

    const state = pixiStateRef.current;
    const data = dataRef.current;
    const selected = data?.systems.find((system) => system.id === selectedSystemId);

    if (state && selected) {
      state.targetView = getFocusView(state.app, selected, state.view);
    }
  }, [selectedSystemId]);

  useEffect(() => {
    hoveredSystemIdRef.current = hoveredSystemId;
  }, [hoveredSystemId]);

  useEffect(() => {
    movementOriginSystemIdRef.current = movementOriginSystemId;
  }, [movementOriginSystemId]);

  useEffect(() => {
    movementPlanningRef.current = movementPlanning;
  }, [movementPlanning]);

  useEffect(() => {
    dataRef.current = { systems, edges, factions, movements, factionColorById };

    if (pixiStateRef.current) {
      renderStaticMap(pixiStateRef.current, dataRef.current, {
        setHoveredSystem,
        setSelectedSystem,
        setTooltipPosition,
        getMovementPlanning: () => movementPlanningRef.current
      });
    }
  }, [edges, factionColorById, factions, movements, setHoveredSystem, setSelectedSystem, setTooltipPosition, systems]);

  useEffect(() => {
    if (!containerRef.current) {
      return;
    }

    let cancelled = false;
    let initialized = false;
    let tickerAttached = false;
    const container = containerRef.current;
    const app = new PIXI.Application();

    async function boot() {
      await app.init({
        antialias: true,
        autoDensity: true,
        backgroundAlpha: 0,
        resizeTo: container,
        resolution: Math.min(window.devicePixelRatio || 1, 2)
      });
      initialized = true;

      if (cancelled) {
        app.destroy(true, { children: true });
        return;
      }

      container.appendChild(app.canvas);

      const world = new PIXI.Container();
      const layers = createLayers();
      world.addChild(
        layers.background,
        layers.routes,
        layers.routeEffects,
        layers.effects,
        layers.systems,
        layers.movement,
        layers.labels
      );
      app.stage.addChild(world);
      app.stage.eventMode = "static";
      app.stage.hitArea = app.screen;

      const bounds = getBounds(systems);
      const initialScale = 0.72;
      const view = {
        scale: initialScale,
        x: app.renderer.width / 2 - ((bounds.minX + bounds.maxX) / 2) * initialScale,
        y: app.renderer.height / 2 - ((bounds.minY + bounds.maxY) / 2) * initialScale
      };

      const state: PixiMapState = {
        app,
        world,
        layers,
        view,
        targetView: null,
        labels: [],
        backgroundStars: [],
        cleanup: () => undefined
      };

      applyView(world, view);
      pixiStateRef.current = state;

      const cleanupInput = bindMapInput({
        app,
        container,
        state
      });
      state.cleanup = cleanupInput;

      renderStaticMap(state, dataRef.current ?? { systems, edges, factions, movements, factionColorById }, {
        setHoveredSystem,
        setSelectedSystem,
        setTooltipPosition,
        getMovementPlanning: () => movementPlanningRef.current
      });

      let time = 0;
      app.ticker.add((ticker) => {
        time += ticker.deltaTime;
        animateBackground(state.backgroundStars, time);
        animateCamera(state);
        renderDynamicLayers({
          state,
          data: dataRef.current ?? { systems, edges, factions, movements, factionColorById },
          time,
          selectedSystemId: selectedSystemIdRef.current,
          hoveredSystemId: hoveredSystemIdRef.current,
          movementOriginSystemId: movementOriginSystemIdRef.current,
          movementPlanning: movementPlanningRef.current
        });
      });
      tickerAttached = true;
    }

    void boot();

    return () => {
      cancelled = true;
      setHoveredSystem(null);
      setTooltipPosition(null);

      if (pixiStateRef.current?.app === app) {
        pixiStateRef.current.cleanup();
        pixiStateRef.current = null;
      }

      if (tickerAttached) {
        app.ticker.stop();
      }

      if (initialized) {
        app.destroy(true, { children: true });
      }
    };
  }, [edges, factionColorById, factions, movements, setHoveredSystem, setSelectedSystem, setTooltipPosition, systems]);

  return <div className="absolute inset-0 touch-none" ref={containerRef} />;
}

function createLayers(): MapLayers {
  return {
    background: new PIXI.Container(),
    routes: new PIXI.Container(),
    routeEffects: new PIXI.Container(),
    systems: new PIXI.Container(),
    effects: new PIXI.Container(),
    movement: new PIXI.Container(),
    labels: new PIXI.Container()
  };
}

function bindMapInput({
  app,
  container,
  state
}: {
  app: PIXI.Application;
  container: HTMLDivElement;
  state: PixiMapState;
}) {
  let dragging = false;
  let lastPoint = { x: 0, y: 0 };
  const activePointers = new Map<number, { x: number; y: number }>();
  let pinchStart:
    | {
        distance: number;
        view: ViewState;
        worldPoint: { x: number; y: number };
      }
    | null = null;

  const onPointerDown = (event: PIXI.FederatedPointerEvent) => {
    const point = { x: event.global.x, y: event.global.y };
    activePointers.set(event.pointerId, point);
    state.targetView = null;

    if (activePointers.size >= 2) {
      dragging = false;
      pinchStart = getPinchStart(activePointers, state.view);
      return;
    }

    dragging = true;
    lastPoint = point;
  };

  const onPointerUp = (event: PIXI.FederatedPointerEvent) => {
    activePointers.delete(event.pointerId);
    pinchStart = null;

    if (activePointers.size === 1) {
      dragging = true;
      lastPoint = [...activePointers.values()][0];
      return;
    }

    dragging = false;
  };

  const onPointerMove = (event: PIXI.FederatedPointerEvent) => {
    const nextPoint = { x: event.global.x, y: event.global.y };

    if (activePointers.has(event.pointerId)) {
      activePointers.set(event.pointerId, nextPoint);
    }

    if (activePointers.size >= 2 && pinchStart) {
      const pinch = getPinchMetrics(activePointers);

      if (pinch) {
        const nextScale = clamp(
          pinchStart.view.scale * (pinch.distance / Math.max(pinchStart.distance, 1)),
          0.42,
          2
        );
        state.view.scale = nextScale;
        state.view.x = pinch.midpoint.x - pinchStart.worldPoint.x * nextScale;
        state.view.y = pinch.midpoint.y - pinchStart.worldPoint.y * nextScale;
        applyView(state.world, state.view);
      }

      return;
    }

    if (!dragging) {
      return;
    }

    state.view.x += nextPoint.x - lastPoint.x;
    state.view.y += nextPoint.y - lastPoint.y;
    lastPoint = nextPoint;
    applyView(state.world, state.view);
  };

  const wheelHandler = (event: WheelEvent) => {
    event.preventDefault();
    state.targetView = null;
    const oldScale = state.view.scale;
    const direction = event.deltaY > 0 ? 0.92 : 1.08;
    const nextScale = clamp(oldScale * direction, 0.42, 2);
    const rect = container.getBoundingClientRect();
    const pointer = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top
    };
    const worldPoint = {
      x: (pointer.x - state.view.x) / oldScale,
      y: (pointer.y - state.view.y) / oldScale
    };

    state.view.scale = nextScale;
    state.view.x = pointer.x - worldPoint.x * nextScale;
    state.view.y = pointer.y - worldPoint.y * nextScale;
    applyView(state.world, state.view);
  };

  app.stage.on("pointerdown", onPointerDown);
  app.stage.on("pointerup", onPointerUp);
  app.stage.on("pointerupoutside", onPointerUp);
  app.stage.on("pointercancel", onPointerUp);
  app.stage.on("pointermove", onPointerMove);
  container.addEventListener("wheel", wheelHandler, { passive: false });

  return () => {
    app.stage.off("pointerdown", onPointerDown);
    app.stage.off("pointerup", onPointerUp);
    app.stage.off("pointerupoutside", onPointerUp);
    app.stage.off("pointercancel", onPointerUp);
    app.stage.off("pointermove", onPointerMove);
    container.removeEventListener("wheel", wheelHandler);
  };
}

function getPinchStart(activePointers: Map<number, { x: number; y: number }>, view: ViewState) {
  const pinch = getPinchMetrics(activePointers);

  if (!pinch) {
    return null;
  }

  return {
    distance: pinch.distance,
    view: { ...view },
    worldPoint: {
      x: (pinch.midpoint.x - view.x) / view.scale,
      y: (pinch.midpoint.y - view.y) / view.scale
    }
  };
}

function getPinchMetrics(activePointers: Map<number, { x: number; y: number }>) {
  const points = [...activePointers.values()];

  if (points.length < 2) {
    return null;
  }

  const [first, second] = points;

  return {
    distance: Math.hypot(second.x - first.x, second.y - first.y),
    midpoint: {
      x: (first.x + second.x) / 2,
      y: (first.y + second.y) / 2
    }
  };
}

function renderStaticMap(
  state: PixiMapState,
  data: MapData,
  handlers: {
    setHoveredSystem: (systemId: string | null) => void;
    setSelectedSystem: (systemId: string | null) => void;
    setTooltipPosition: (position: { x: number; y: number } | null) => void;
    getMovementPlanning: () => MovementPlanning | undefined;
  }
) {
  clearLayer(state.layers.background);
  clearLayer(state.layers.routes);
  clearLayer(state.layers.systems);
  clearLayer(state.layers.labels);
  state.labels = [];
  state.backgroundStars = [];

  const bounds = getBounds(data.systems);
  drawBackground(state.layers.background, bounds, state.backgroundStars);
  drawRoutes(state.layers.routes, data.systems, data.edges, data.factionColorById);
  drawSystems({
    layer: state.layers.systems,
    labelsLayer: state.layers.labels,
    labels: state.labels,
    systems: data.systems,
    factionColorById: data.factionColorById,
    setSelectedSystem: handlers.setSelectedSystem,
    setHoveredSystem: handlers.setHoveredSystem,
    setTooltipPosition: handlers.setTooltipPosition,
    getMovementPlanning: handlers.getMovementPlanning
  });
}

function renderDynamicLayers({
  state,
  data,
  time,
  selectedSystemId,
  hoveredSystemId,
  movementOriginSystemId,
  movementPlanning
}: {
  state: PixiMapState;
  data: MapData;
  time: number;
  selectedSystemId: string | null;
  hoveredSystemId: string | null;
  movementOriginSystemId: string | null;
  movementPlanning?: MovementPlanning;
}) {
  clearLayer(state.layers.effects);
  clearLayer(state.layers.routeEffects);
  clearLayer(state.layers.movement);

  drawRouteEffects({
    layer: state.layers.routeEffects,
    systems: data.systems,
    edges: data.edges,
    selectedSystemId,
    hoveredSystemId,
    movementOriginSystemId,
    plannedPathSystemIds: movementPlanning?.pathSystemIds ?? [],
    time
  });
  drawSystemEffects({
    layer: state.layers.effects,
    systems: data.systems,
    factionColorById: data.factionColorById,
    selectedSystemId,
    hoveredSystemId,
    movementOriginSystemId,
    time
  });
  drawMovements(state.layers.movement, data.systems, data.movements, data.factionColorById, time);
  updateLabels(state.labels, state.view.scale, selectedSystemId, hoveredSystemId);
}

function drawBackground(layer: PIXI.Container, bounds: Bounds, stars: BackgroundStar[]) {
  const field = new PIXI.Graphics();
  field.rect(bounds.minX - 900, bounds.minY - 650, bounds.width + 1800, bounds.height + 1300);
  field.fill({ color: 0x02040a, alpha: 0.92 });
  layer.addChild(field);

  drawNebula(layer, bounds, bounds.minX + bounds.width * 0.28, bounds.minY + bounds.height * 0.2, 0x0ea5e9, 250);
  drawNebula(layer, bounds, bounds.minX + bounds.width * 0.72, bounds.minY + bounds.height * 0.68, 0xa855f7, 300);
  drawNebula(layer, bounds, bounds.minX + bounds.width * 0.42, bounds.minY + bounds.height * 0.78, 0x22c55e, 210);

  let seed = 71;
  const colorOptions = [0xdff9ff, 0xbfd7ff, 0xfff1ba, 0xffc7a3, 0xd8c7ff, 0xc9ffe1];

  for (let index = 0; index < 560; index += 1) {
    const rx = seededRandom();
    const ry = seededRandom();
    const intensity = 0.24 + seededRandom() * 0.72;
    const radius = intensity > 0.78 ? 1.45 + seededRandom() * 0.85 : 0.65 + seededRandom() * 0.65;
    const x = bounds.minX - 780 + rx * (bounds.width + 1560);
    const y = bounds.minY - 540 + ry * (bounds.height + 1080);
    const color = colorOptions[Math.floor(seededRandom() * colorOptions.length)] ?? 0xdff9ff;
    const star = new PIXI.Graphics();
    star.circle(0, 0, radius);
    star.fill({ color, alpha: 1 });
    star.position.set(x, y);
    star.alpha = intensity;
    stars.push({
      node: star,
      baseAlpha: intensity,
      phase: seededRandom() * Math.PI * 2,
      speed: 0.015 + seededRandom() * 0.035
    });
    layer.addChild(star);
  }

  function seededRandom() {
    seed = (seed * 9301 + 49297) % 233280;
    return seed / 233280;
  }
}

function drawNebula(layer: PIXI.Container, bounds: Bounds, x: number, y: number, color: number, radius: number) {
  const nebula = new PIXI.Graphics();
  nebula.ellipse(x, y, radius * 1.35, radius * 0.72);
  nebula.fill({ color, alpha: 0.045 });
  nebula.ellipse(x + radius * 0.22, y - radius * 0.12, radius * 0.78, radius * 0.42);
  nebula.fill({ color, alpha: 0.065 });
  nebula.ellipse(x - radius * 0.28, y + radius * 0.16, radius * 0.58, radius * 0.34);
  nebula.fill({ color: 0xffffff, alpha: 0.015 });
  nebula.rotation = ((x + y + bounds.width) % 90) * (Math.PI / 180);
  layer.addChild(nebula);
}

function drawRoutes(
  layer: PIXI.Container,
  systems: StarSystem[],
  edges: SystemEdge[],
  factionColorById: Map<string, string>
) {
  const systemById = new Map(systems.map((system) => [system.id, system]));

  for (const edge of edges) {
    const from = systemById.get(edge.fromSystemId);
    const to = systemById.get(edge.toSystemId);

    if (!from || !to) {
      continue;
    }

    const route = new PIXI.Graphics();
    const routeColor = getRouteColor(edge, from, to, factionColorById);
    route.moveTo(from.x, from.y);
    route.lineTo(to.x, to.y);
    route.stroke({ color: routeColor, alpha: 0.12, width: 5 });

    if (edge.isBlocked) {
      drawDashedLine(route, from.x, from.y, to.x, to.y, 14, 8);
      route.stroke({ color: 0xfb7185, alpha: 0.4, width: 1.8 });
    } else {
      route.moveTo(from.x, from.y);
      route.lineTo(to.x, to.y);
      route.stroke({ color: routeColor, alpha: 0.36, width: 1.4 });
    }

    layer.addChild(route);
  }
}

function drawSystems({
  layer,
  labelsLayer,
  labels,
  systems,
  factionColorById,
  setSelectedSystem,
  setHoveredSystem,
  setTooltipPosition,
  getMovementPlanning
}: {
  layer: PIXI.Container;
  labelsLayer: PIXI.Container;
  labels: LabelRecord[];
  systems: StarSystem[];
  factionColorById: Map<string, string>;
  setSelectedSystem: (systemId: string | null) => void;
  setHoveredSystem: (systemId: string | null) => void;
  setTooltipPosition: (position: { x: number; y: number } | null) => void;
  getMovementPlanning: () => MovementPlanning | undefined;
}) {
  for (const system of systems) {
    const starColors = getStarColors(system);
    const factionColor = getFactionColor(system, factionColorById);
    const controlColor = system.status === "war" ? 0xfb7185 : factionColor ?? 0x94a3b8;
    const radius = 8.4 * system.size;
    const node = new PIXI.Container();
    node.position.set(system.x, system.y);
    node.eventMode = "static";
    node.cursor = "pointer";
    node.hitArea = new PIXI.Circle(0, 0, radius * 3.4);

    drawSoftCircle(node, 0, 0, radius * 5.4, starColors.halo, 0.038, 4);
    drawSoftCircle(node, 0, 0, radius * 3.2, starColors.corona, 0.12, 3);

    const orbit = new PIXI.Graphics();
    orbit.circle(0, 0, radius * 1.82);
    orbit.stroke({
      color: system.status === "neutral" ? 0xcbd5e1 : controlColor,
      alpha: system.status === "neutral" ? 0.46 : 0.84,
      width: system.status === "neutral" ? 1.25 : 2.1
    });
    node.addChild(orbit);

    if (system.controllerFactionId && system.status !== "neutral") {
      const factionGlow = new PIXI.Graphics();
      factionGlow.circle(0, 0, radius * 2.55);
      factionGlow.stroke({ color: controlColor, alpha: 0.26, width: 5.4 });
      factionGlow.circle(0, 0, radius * 2.92);
      factionGlow.stroke({ color: controlColor, alpha: 0.16, width: 1.2 });
      node.addChild(factionGlow);
    }

    if (system.status === "war") {
      const alert = new PIXI.Graphics();
      alert.moveTo(0, -radius * 3.7);
      alert.lineTo(radius * 0.8, -radius * 2.35);
      alert.lineTo(-radius * 0.8, -radius * 2.35);
      alert.closePath();
      alert.fill({ color: 0xfb7185, alpha: 0.2 });
      alert.stroke({ color: 0xfb7185, alpha: 0.8, width: 1.2 });
      alert.moveTo(0, -radius * 3.24);
      alert.lineTo(0, -radius * 2.72);
      alert.stroke({ color: 0xffffff, alpha: 0.75, width: 1.1 });
      node.addChild(alert);
    }

    if (system.blockedUntil) {
      const shield = new PIXI.Graphics();
      shield.moveTo(radius * 2.2, -radius * 2.75);
      shield.lineTo(radius * 3.1, -radius * 2.36);
      shield.lineTo(radius * 2.86, -radius * 1.32);
      shield.lineTo(radius * 2.2, -radius * 0.94);
      shield.lineTo(radius * 1.54, -radius * 1.32);
      shield.lineTo(radius * 1.3, -radius * 2.36);
      shield.closePath();
      shield.fill({ color: 0xfbbf24, alpha: 0.18 });
      shield.stroke({ color: 0xfbbf24, alpha: 0.9, width: 1.35 });
      node.addChild(shield);
    }

    if (system.specialObjects?.some((object) => object.isPublic)) {
      const relic = new PIXI.Graphics();
      relic.moveTo(-radius * 0.7, radius * 2.76);
      relic.lineTo(0, radius * 2.08);
      relic.lineTo(radius * 0.7, radius * 2.76);
      relic.lineTo(0, radius * 3.44);
      relic.closePath();
      relic.fill({ color: 0xc084fc, alpha: 0.4 });
      relic.stroke({ color: 0xfef3c7, alpha: 0.8, width: 1.1 });
      node.addChild(relic);
    }

    const core = new PIXI.Graphics();
    core.circle(0, 0, radius * 1.12);
    core.fill({ color: starColors.corona, alpha: 0.75 });
    core.circle(0, 0, radius * 0.72);
    core.fill({ color: starColors.core, alpha: 1 });
    core.circle(-radius * 0.22, -radius * 0.24, radius * 0.24);
    core.fill({ color: 0xffffff, alpha: 0.82 });
    node.addChild(core);

    const scanline = new PIXI.Graphics();
    scanline.moveTo(-radius * 2.1, 0);
    scanline.lineTo(-radius * 1.2, 0);
    scanline.moveTo(radius * 1.2, 0);
    scanline.lineTo(radius * 2.1, 0);
    scanline.moveTo(0, -radius * 2.1);
    scanline.lineTo(0, -radius * 1.2);
    scanline.moveTo(0, radius * 1.2);
    scanline.lineTo(0, radius * 2.1);
    scanline.stroke({ color: controlColor, alpha: system.status === "neutral" ? 0.22 : 0.44, width: 1 });
    node.addChild(scanline);

    node.on("pointertap", () => {
      const planning = getMovementPlanning();

      if (planning?.active) {
        planning.onSystemClick(system.id);
        return;
      }

      setSelectedSystem(system.id);
    });
    node.on("pointerover", (event) => {
      getMovementPlanning()?.onSystemHover(system.id);
      setHoveredSystem(system.id);
      setTooltipPosition({ x: event.global.x + 18, y: event.global.y + 18 });
    });
    node.on("pointermove", (event) => {
      setTooltipPosition({ x: event.global.x + 18, y: event.global.y + 18 });
    });
    node.on("pointerout", () => {
      getMovementPlanning()?.onSystemHover(null);
      setHoveredSystem(null);
      setTooltipPosition(null);
    });

    layer.addChild(node);

    const label = new PIXI.Text({
      text: system.name,
      style: {
        fill: 0xdbeafe,
        fontFamily: "Arial",
        fontSize: 12,
        fontWeight: "400",
        letterSpacing: 0,
        dropShadow: {
          alpha: 0.55,
          blur: 3,
          color: 0x000000,
          distance: 1
        }
      }
    });
    label.anchor.set(0.5, 0);
    label.position.set(system.x, system.y + radius * 3.08);
    labelsLayer.addChild(label);
    labels.push({ label, system });
  }
}

function drawRouteEffects({
  layer,
  systems,
  edges,
  selectedSystemId,
  hoveredSystemId,
  movementOriginSystemId,
  plannedPathSystemIds,
  time
}: {
  layer: PIXI.Container;
  systems: StarSystem[];
  edges: SystemEdge[];
  selectedSystemId: string | null;
  hoveredSystemId: string | null;
  movementOriginSystemId: string | null;
  plannedPathSystemIds: string[];
  time: number;
}) {
  const systemById = new Map(systems.map((system) => [system.id, system]));
  const activeSystemId = movementOriginSystemId ?? selectedSystemId ?? hoveredSystemId;
  const warSystemIds = new Set(systems.filter((system) => system.status === "war").map((system) => system.id));
  drawPathHighlight(layer, systemById, plannedPathSystemIds, 0xfef08a, 0.74);

  for (const edge of edges) {
    const from = systemById.get(edge.fromSystemId);
    const to = systemById.get(edge.toSystemId);

    if (!from || !to) {
      continue;
    }

    const isAdjacent = activeSystemId === from.id || activeSystemId === to.id;
    const isWarAdjacent = warSystemIds.has(from.id) || warSystemIds.has(to.id);

    if (!isAdjacent && !isWarAdjacent) {
      continue;
    }

    const color = isWarAdjacent ? 0xfb7185 : movementOriginSystemId ? 0xfef08a : 0x67e8f9;
    const alpha = isAdjacent ? 0.72 : 0.32 + Math.sin(time * 0.07) * 0.08;
    const line = new PIXI.Graphics();
    line.moveTo(from.x, from.y);
    line.lineTo(to.x, to.y);
    line.stroke({ color, alpha, width: isAdjacent ? 4 : 2.3 });
    layer.addChild(line);

  }
}

function drawSystemEffects({
  layer,
  systems,
  factionColorById,
  selectedSystemId,
  hoveredSystemId,
  movementOriginSystemId,
  time
}: {
  layer: PIXI.Container;
  systems: StarSystem[];
  factionColorById: Map<string, string>;
  selectedSystemId: string | null;
  hoveredSystemId: string | null;
  movementOriginSystemId: string | null;
  time: number;
}) {
  for (const system of systems) {
    const radius = 8.4 * system.size;

    if (system.status === "war") {
      const pulse = new PIXI.Graphics();
      const pulseRadius = radius * 3.25 + Math.sin(time * 0.09) * radius * 0.58;
      pulse.circle(system.x, system.y, pulseRadius);
      pulse.stroke({ color: 0xfb7185, alpha: 0.52, width: 2.1 });
      pulse.circle(system.x, system.y, pulseRadius * 1.24);
      pulse.stroke({ color: 0xfb7185, alpha: 0.18, width: 5 });
      layer.addChild(pulse);
    }

    if (system.id === movementOriginSystemId) {
      const origin = new PIXI.Graphics();
      origin.circle(system.x, system.y, radius * 3.8);
      origin.stroke({ color: 0xfef08a, alpha: 0.78, width: 2.6 });
      origin.circle(system.x, system.y, radius * 4.35);
      origin.stroke({ color: 0xfef08a, alpha: 0.28, width: 4 });
      layer.addChild(origin);
    }
  }

  const selected = systems.find((system) => system.id === selectedSystemId);

  if (selected) {
    const color = getFactionColor(selected, factionColorById) ?? getStarColors(selected).halo;
    const radius = 8.4 * selected.size;
    const pulseRadius = radius * 3.05 + Math.sin(time * 0.08) * radius * 0.34;
    const selectedRing = new PIXI.Graphics();
    selectedRing.circle(selected.x, selected.y, pulseRadius);
    selectedRing.stroke({ color, alpha: 0.92, width: 2.7 });
    selectedRing.circle(selected.x, selected.y, pulseRadius * 1.18);
    selectedRing.stroke({ color, alpha: 0.22, width: 5.4 });
    layer.addChild(selectedRing);
  }

  const hovered = systems.find((system) => system.id === hoveredSystemId);

  if (hovered && hovered.id !== selectedSystemId) {
    const colors = getStarColors(hovered);
    const radius = 8.4 * hovered.size;
    const hoverRing = new PIXI.Graphics();
    hoverRing.circle(hovered.x, hovered.y, radius * 2.9);
    hoverRing.stroke({ color: colors.core, alpha: 0.7, width: 1.6 });
    layer.addChild(hoverRing);
  }
}

function drawMovements(
  layer: PIXI.Container,
  systems: StarSystem[],
  movements: MovementOrder[],
  factionColorById: Map<string, string>,
  time: number
) {
  const systemById = new Map(systems.map((system) => [system.id, system]));
  const now = Date.now();

  for (const movement of movements.filter((item) => item.status === "moving")) {
    const pathSystemIds =
      movement.pathSystemIds.length > 1 ? movement.pathSystemIds : [movement.fromSystemId, movement.toSystemId];
    const pathSystems = pathSystemIds
      .map((systemId) => systemById.get(systemId))
      .filter((system): system is StarSystem => Boolean(system));

    if (pathSystems.length < 2) {
      continue;
    }

    const movementColor = toPixiColor(factionColorById.get(movement.factionId) ?? "#fef08a");
    const started = new Date(movement.startedAt).getTime();
    const arrival = new Date(movement.arrivalAt).getTime();
    const progress = clamp((now - started) / Math.max(arrival - started, 1), 0, 1);
    const point = pointOnPath(pathSystems, progress);
    const trailStart = pointOnPath(pathSystems, Math.max(progress - 0.08, 0));

    const routeGlow = new PIXI.Graphics();
    drawPathStroke(routeGlow, pathSystems, movementColor, 0.18, 4.8);
    drawPathStroke(routeGlow, pathSystems, movementColor, 0.42, 1.4);
    layer.addChild(routeGlow);

    for (let index = 0; index < 4; index += 1) {
      const particleProgress = (time * 0.014 + index / 4) % 1;
      const particle = pointOnPath(pathSystems, particleProgress);
      const dot = new PIXI.Graphics();
      dot.circle(particle.x, particle.y, 2.3);
      dot.fill({ color: movementColor, alpha: 0.8 });
      layer.addChild(dot);
    }

    const trail = new PIXI.Graphics();
    trail.moveTo(trailStart.x, trailStart.y);
    trail.lineTo(point.x, point.y);
    trail.stroke({ color: movementColor, alpha: 0.36, width: 5 });
    trail.moveTo(trailStart.x, trailStart.y);
    trail.lineTo(point.x, point.y);
    trail.stroke({ color: movementColor, alpha: 0.86, width: 1.6 });
    layer.addChild(trail);

    const marker = new PIXI.Graphics();
    const pulse = 1 + Math.sin(time * 0.16) * 0.16;
    marker.circle(point.x, point.y, 4.8 * pulse);
    marker.fill({ color: movementColor, alpha: 0.96 });
    marker.circle(point.x, point.y, 12 * pulse);
    marker.stroke({ color: movementColor, alpha: 0.34, width: 1.7 });
    const angle = Math.atan2(point.y - trailStart.y, point.x - trailStart.x);
    marker.moveTo(point.x + Math.cos(angle) * 10, point.y + Math.sin(angle) * 10);
    marker.lineTo(point.x + Math.cos(angle + 2.45) * 7, point.y + Math.sin(angle + 2.45) * 7);
    marker.lineTo(point.x + Math.cos(angle - 2.45) * 7, point.y + Math.sin(angle - 2.45) * 7);
    marker.closePath();
    marker.fill({ color: 0xffffff, alpha: 0.72 });
    layer.addChild(marker);
  }
}

function updateLabels(labels: LabelRecord[], scale: number, selectedSystemId: string | null, hoveredSystemId: string | null) {
  for (const { label, system } of labels) {
    const isSelected = system.id === selectedSystemId;
    const isHovered = system.id === hoveredSystemId;
    const shouldShow = isSelected || isHovered || scale > 0.82;
    label.visible = shouldShow;
    label.alpha = isSelected || isHovered ? 1 : clamp((scale - 0.72) / 0.28, 0.34, 0.82);
    label.scale.set(clamp(1 / scale, 0.78, 1.18));
  }
}

function animateBackground(stars: BackgroundStar[], time: number) {
  for (const star of stars) {
    star.node.alpha = clamp(star.baseAlpha + Math.sin(time * star.speed + star.phase) * 0.18, 0.1, 1);
  }
}

function animateCamera(state: PixiMapState) {
  if (!state.targetView) {
    return;
  }

  state.view.x += (state.targetView.x - state.view.x) * 0.08;
  state.view.y += (state.targetView.y - state.view.y) * 0.08;
  state.view.scale += (state.targetView.scale - state.view.scale) * 0.08;
  applyView(state.world, state.view);

  if (
    Math.abs(state.view.x - state.targetView.x) < 0.5 &&
    Math.abs(state.view.y - state.targetView.y) < 0.5 &&
    Math.abs(state.view.scale - state.targetView.scale) < 0.002
  ) {
    state.view = { ...state.targetView };
    state.targetView = null;
    applyView(state.world, state.view);
  }
}

function getFocusView(app: PIXI.Application, system: StarSystem, currentView: ViewState): ViewState {
  const scale = clamp(Math.max(currentView.scale, 0.88), 0.72, 1.16);

  return {
    scale,
    x: app.renderer.width * 0.42 - system.x * scale,
    y: app.renderer.height * 0.52 - system.y * scale
  };
}

function drawSoftCircle(
  container: PIXI.Container,
  x: number,
  y: number,
  radius: number,
  color: number,
  alpha: number,
  steps: number
) {
  for (let index = steps; index >= 1; index -= 1) {
    const graphic = new PIXI.Graphics();
    const stepRadius = radius * (index / steps);
    graphic.circle(x, y, stepRadius);
    graphic.fill({ color, alpha: alpha / index });
    container.addChild(graphic);
  }
}

function drawDashedLine(
  graphics: PIXI.Graphics,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  dashLength: number,
  gapLength: number
) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const distance = Math.hypot(dx, dy);
  const dashCount = Math.floor(distance / (dashLength + gapLength));

  for (let index = 0; index <= dashCount; index += 1) {
    const start = (index * (dashLength + gapLength)) / distance;
    const end = Math.min((index * (dashLength + gapLength) + dashLength) / distance, 1);
    graphics.moveTo(x1 + dx * start, y1 + dy * start);
    graphics.lineTo(x1 + dx * end, y1 + dy * end);
  }
}

function pointOnLine(from: StarSystem, to: StarSystem, progress: number) {
  return {
    x: from.x + (to.x - from.x) * progress,
    y: from.y + (to.y - from.y) * progress
  };
}

function pointOnPath(pathSystems: StarSystem[], progress: number) {
  if (pathSystems.length === 1) {
    return { x: pathSystems[0].x, y: pathSystems[0].y };
  }

  const scaledProgress = clamp(progress, 0, 1) * (pathSystems.length - 1);
  const segmentIndex = Math.min(Math.floor(scaledProgress), pathSystems.length - 2);
  const localProgress = scaledProgress - segmentIndex;

  return pointOnLine(pathSystems[segmentIndex], pathSystems[segmentIndex + 1], localProgress);
}

function drawPathStroke(
  graphics: PIXI.Graphics,
  pathSystems: StarSystem[],
  color: number,
  alpha: number,
  width: number
) {
  if (pathSystems.length < 2) {
    return;
  }

  graphics.moveTo(pathSystems[0].x, pathSystems[0].y);

  for (const system of pathSystems.slice(1)) {
    graphics.lineTo(system.x, system.y);
  }

  graphics.stroke({ color, alpha, width });
}

function drawPathHighlight(
  layer: PIXI.Container,
  systemById: Map<string, StarSystem>,
  pathSystemIds: string[],
  color: number,
  alpha: number
) {
  if (pathSystemIds.length < 2) {
    return;
  }

  const pathSystems = pathSystemIds
    .map((systemId) => systemById.get(systemId))
    .filter((system): system is StarSystem => Boolean(system));

  if (pathSystems.length < 2) {
    return;
  }

  const glow = new PIXI.Graphics();
  drawPathStroke(glow, pathSystems, color, alpha * 0.24, 8);
  drawPathStroke(glow, pathSystems, color, alpha, 2.4);
  layer.addChild(glow);
}

function applyView(world: PIXI.Container, view: ViewState) {
  world.position.set(view.x, view.y);
  world.scale.set(view.scale);
}

function clearLayer(layer: PIXI.Container) {
  for (const child of layer.removeChildren()) {
    child.destroy({ children: true });
  }
}

function getStarColors(system: StarSystem) {
  return starPalette[getSystemStarClass(system)];
}

function getSystemStarClass(system: StarSystem): StarClass {
  if (system.starClass) {
    return system.starClass;
  }

  return starClasses[hashString(system.id) % starClasses.length] ?? "white";
}

function getFactionColor(system: StarSystem, factionColorById: Map<string, string>) {
  if (!system.controllerFactionId) {
    return null;
  }

  return toPixiColor(factionColorById.get(system.controllerFactionId) ?? "#94a3b8");
}

function getRouteColor(
  edge: SystemEdge,
  from: StarSystem,
  to: StarSystem,
  factionColorById: Map<string, string>
) {
  if (edge.isBlocked) {
    return 0xfb7185;
  }

  const sharedFactionId =
    from.status === "controlled" &&
    to.status === "controlled" &&
    from.controllerFactionId &&
    from.controllerFactionId === to.controllerFactionId
      ? from.controllerFactionId
      : null;

  if (!sharedFactionId) {
    return 0x67e8f9;
  }

  return toPixiColor(factionColorById.get(sharedFactionId) ?? "#67e8f9");
}

function getBounds(systems: StarSystem[]) {
  const xs = systems.map((system) => system.x);
  const ys = systems.map((system) => system.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);

  return {
    minX,
    maxX,
    minY,
    maxY,
    width: maxX - minX,
    height: maxY - minY
  };
}

type Bounds = ReturnType<typeof getBounds>;

function hashString(value: string) {
  let hash = 0;

  for (let index = 0; index < value.length; index += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(index);
    hash |= 0;
  }

  return Math.abs(hash);
}

function toPixiColor(hex: string) {
  return Number.parseInt(hex.replace("#", ""), 16);
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}
