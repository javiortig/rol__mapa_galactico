import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const configPath = path.join(rootDir, "data", "technology", "faction-troop-trees.json");
const generatedTemplatesPath = path.join(rootDir, "src", "mocks", "generated", "40k-unit-templates.ts");
const config = JSON.parse(readFileSync(configPath, "utf8"));
const generatedTemplatesSource = readFileSync(generatedTemplatesPath, "utf8");
const strict = process.argv.includes("--strict");
const errors = [];

const targetFactionSlugs = new Set(config.targetFactionSlugs ?? []);
const trees = Array.isArray(config.trees) ? config.trees : [];
const treeByFaction = new Map();
const unitTemplates = readGeneratedUnitTemplates(generatedTemplatesSource);

for (const factionSlug of targetFactionSlugs) {
  const expectedTreeKey = `${config.treeKeyPrefix}-${factionSlug}-v1`;
  const tree = trees.find((candidate) => candidate.factionSlug === factionSlug);

  if (!tree) {
    errors.push(`Falta arbol declarativo para ${factionSlug}.`);
    continue;
  }

  treeByFaction.set(factionSlug, tree);

  if (tree.treeKey !== expectedTreeKey) {
    errors.push(`${factionSlug}: treeKey debe ser ${expectedTreeKey}, recibido ${tree.treeKey}.`);
  }

  if (!["draft", "ready"].includes(tree.status)) {
    errors.push(`${factionSlug}: status debe ser draft o ready.`);
  }
}

for (const tree of trees) {
  if (!targetFactionSlugs.has(tree.factionSlug)) {
    errors.push(`${tree.factionSlug}: faccion no esta en targetFactionSlugs.`);
  }

  validateUniqueSlugs(`${tree.factionSlug}: ramas`, tree.branches ?? [], "slug");
  validateUniqueSlugs(`${tree.factionSlug}: nodos`, tree.nodes ?? [], "slug");

  if (strict || tree.status === "ready") {
    validateReadyTree(tree);
  }
}

if (errors.length > 0) {
  console.error("Validacion de arboles de tropas fallida:");
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(
  `Arboles de tropas validados: ${trees.length} configurados, ${trees.filter((tree) => tree.status === "ready").length} listos, ${trees.filter((tree) => tree.status === "draft").length} en borrador.`
);

function validateReadyTree(tree) {
  const branches = tree.branches ?? [];
  const nodes = tree.nodes ?? [];
  const branchSlugs = new Set(branches.map((branch) => branch.slug));
  const nodeSlugs = new Set(nodes.map((node) => node.slug));
  const unitsForFaction = unitTemplates.filter((template) => template.factionId === tree.factionSlug);
  const assignedUnitSlugs = new Map();
  const allowedTechnologyCosts = new Set(config.allowedTechnologyCosts ?? [1, 2, 3]);
  const totalTechnologyCost = nodes.reduce((sum, node) => sum + Number(node.costTechnology ?? 0), 0);

  if (branches.length !== config.expectedBranchesPerFaction) {
    errors.push(
      `${tree.factionSlug}: debe tener ${config.expectedBranchesPerFaction} ramas, recibido ${branches.length}.`
    );
  }

  if (nodes.length !== config.expectedActiveNodesPerFaction) {
    errors.push(
      `${tree.factionSlug}: debe tener ${config.expectedActiveNodesPerFaction} nodos activos, recibido ${nodes.length}.`
    );
  }

  if (
    typeof config.expectedTechnologyCostPerReadyTree === "number" &&
    totalTechnologyCost !== config.expectedTechnologyCostPerReadyTree
  ) {
    errors.push(
      `${tree.factionSlug}: coste tecnologico total debe ser ${config.expectedTechnologyCostPerReadyTree}, recibido ${totalTechnologyCost}.`
    );
  }

  for (const node of nodes) {
    if (!branchSlugs.has(node.branchSlug)) {
      errors.push(`${tree.factionSlug}/${node.slug}: branchSlug inexistente ${node.branchSlug}.`);
    }

    if (!Array.isArray(node.unitTemplateSlugs) || node.unitTemplateSlugs.length === 0) {
      errors.push(`${tree.factionSlug}/${node.slug}: cada nodo activo debe desbloquear al menos una unidad.`);
    }

    if (node.researchTimeSeconds !== config.researchTimeSeconds) {
      errors.push(`${tree.factionSlug}/${node.slug}: researchTimeSeconds debe ser ${config.researchTimeSeconds}.`);
    }

    if (!allowedTechnologyCosts.has(node.costTechnology)) {
      errors.push(
        `${tree.factionSlug}/${node.slug}: costTechnology debe estar en [${[...allowedTechnologyCosts].join(", ")}], recibido ${node.costTechnology}.`
      );
    }

    for (const prerequisiteSlug of node.prerequisiteSlugs ?? []) {
      if (!nodeSlugs.has(prerequisiteSlug) && !isAllowedCommonPrerequisite(prerequisiteSlug)) {
        errors.push(`${tree.factionSlug}/${node.slug}: requisito inexistente ${prerequisiteSlug}.`);
      }
    }

    for (const unitSlug of node.unitTemplateSlugs ?? []) {
      const previousNode = assignedUnitSlugs.get(unitSlug);

      if (previousNode) {
        errors.push(`${tree.factionSlug}: unidad ${unitSlug} asignada en ${previousNode} y ${node.slug}.`);
      }

      assignedUnitSlugs.set(unitSlug, node.slug);
    }
  }

  if (config.maxCostOnlyOnLargestBranchFinals) {
    validateMaxCostPlacement(tree, branches, nodes);
  }

  for (const unit of unitsForFaction) {
    if (!assignedUnitSlugs.has(unit.id)) {
      errors.push(`${tree.factionSlug}: unidad sin asignar ${unit.id}.`);
    }
  }

  for (const unitSlug of assignedUnitSlugs.keys()) {
    const unit = unitTemplates.find((template) => template.id === unitSlug);

    if (!unit) {
      errors.push(`${tree.factionSlug}: unidad asignada no existe ${unitSlug}.`);
      continue;
    }

    if (unit.factionId !== tree.factionSlug) {
      errors.push(`${tree.factionSlug}: unidad ${unitSlug} pertenece a ${unit.factionId}.`);
    }
  }
}

function validateMaxCostPlacement(tree, branches, nodes) {
  const maxCost = Math.max(...(config.allowedTechnologyCosts ?? [1, 2, 3]));
  const nodesByBranch = new Map();

  for (const node of nodes) {
    const branchNodes = nodesByBranch.get(node.branchSlug) ?? [];
    branchNodes.push(node);
    nodesByBranch.set(node.branchSlug, branchNodes);
  }

  const expectedMaxCostSlugs = new Set(
    branches
      .map((branch) => {
        const branchNodes = [...(nodesByBranch.get(branch.slug) ?? [])].sort(sortNodesByProgression);
        return {
          branchSlug: branch.slug,
          finalNode: branchNodes.at(-1),
          nodeCount: branchNodes.length
        };
      })
      .sort((left, right) => {
        if (left.nodeCount !== right.nodeCount) {
          return right.nodeCount - left.nodeCount;
        }

        const leftTier = left.finalNode?.tier ?? 0;
        const rightTier = right.finalNode?.tier ?? 0;

        if (leftTier !== rightTier) {
          return rightTier - leftTier;
        }

        return left.branchSlug.localeCompare(right.branchSlug);
      })
      .slice(0, 2)
      .map((item) => item.finalNode?.slug)
      .filter(Boolean)
  );

  const actualMaxCostSlugs = new Set(nodes.filter((node) => node.costTechnology === maxCost).map((node) => node.slug));

  for (const slug of actualMaxCostSlugs) {
    if (!expectedMaxCostSlugs.has(slug)) {
      errors.push(
        `${tree.factionSlug}: ${slug} cuesta ${maxCost}, pero solo pueden costar ${maxCost} los nodos finales de las dos ramas mas grandes (${[...expectedMaxCostSlugs].join(", ")}).`
      );
    }
  }

  for (const slug of expectedMaxCostSlugs) {
    if (!actualMaxCostSlugs.has(slug)) {
      errors.push(`${tree.factionSlug}: ${slug} debe costar ${maxCost} por ser final de una de las dos ramas mas grandes.`);
    }
  }
}

function sortNodesByProgression(left, right) {
  if (left.tier !== right.tier) {
    return left.tier - right.tier;
  }

  if (left.positionY !== right.positionY) {
    return left.positionY - right.positionY;
  }

  if (left.positionX !== right.positionX) {
    return left.positionX - right.positionX;
  }

  return left.name.localeCompare(right.name);
}

function validateUniqueSlugs(label, items, key) {
  const seen = new Set();

  for (const item of items) {
    const value = item[key];

    if (!value) {
      errors.push(`${label}: item sin ${key}.`);
      continue;
    }

    if (seen.has(value)) {
      errors.push(`${label}: ${key} duplicado ${value}.`);
    }

    seen.add(value);
  }
}

function isAllowedCommonPrerequisite(slug) {
  return [
    "fundacion-planetaria",
    "asamblea-planetaria",
    "maquinaria-belica",
    "criadero-guerra"
  ].includes(slug);
}

function readGeneratedUnitTemplates(source) {
  const marker = "export const generated40kUnitTemplates = ";
  const start = source.indexOf(marker);

  if (start === -1) {
    throw new Error("No se encontro generated40kUnitTemplates.");
  }

  const arrayStart = source.indexOf("[", start);
  const arrayEnd = source.indexOf("] satisfies CampaignSnapshot[\"unitTemplates\"];", arrayStart);

  if (arrayStart === -1 || arrayEnd === -1) {
    throw new Error("No se pudo extraer el array generated40kUnitTemplates.");
  }

  return JSON.parse(source.slice(arrayStart, arrayEnd + 1));
}
