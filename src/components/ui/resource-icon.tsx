import Image from "next/image";
import goldIcon from "../../../icons/resources/gold.png";
import honorIcon from "../../../icons/resources/honor.png";
import industrialMaterialIcon from "../../../icons/resources/industrial_material.png";
import uridiumIcon from "../../../icons/resources/iridium.png";
import supplyIcon from "../../../icons/resources/life_essense.png";
import mineralIcon from "../../../icons/resources/mineral.png";
import technologyIcon from "../../../icons/resources/tech_component.png";
import { cn } from "@/lib/utils";
import type { ResourceKey } from "@/domain/campaign";

export const resourceLabels: Record<ResourceKey, string> = {
  supply: "Suministro vital",
  minerals: "Mineral",
  honor: "Honor",
  gold: "Oro",
  industrialMaterial: "Material industrial",
  uridium: "Uridium",
  technology: "Componentes tecnologicos"
};

const resourceIcons = {
  supply: supplyIcon,
  minerals: mineralIcon,
  honor: honorIcon,
  gold: goldIcon,
  industrialMaterial: industrialMaterialIcon,
  uridium: uridiumIcon,
  technology: technologyIcon
};

export function ResourceIcon({
  resource,
  className
}: {
  resource: ResourceKey;
  className?: string;
}) {
  return (
    <Image
      alt={resourceLabels[resource]}
      className={cn("size-5 object-contain drop-shadow-[0_0_8px_rgba(103,232,249,0.24)]", className)}
      height={32}
      src={resourceIcons[resource]}
      width={32}
    />
  );
}

export function ResourceAmount({
  resource,
  value,
  className,
  prefix
}: {
  resource: ResourceKey;
  value: number;
  className?: string;
  prefix?: string;
}) {
  return (
    <span className={cn("inline-flex items-center gap-1.5 tabular-nums text-slate-100", className)}>
      <ResourceIcon className="size-4" resource={resource} />
      {prefix}
      {value}
    </span>
  );
}
