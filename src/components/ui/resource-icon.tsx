import Image from "next/image";
import ancestralStoneIcon from "../../../icons/resources/acestral_stone.png";
import uridiumIcon from "../../../icons/resources/iridium.png";
import supplyIcon from "../../../icons/resources/life_essense.png";
import mineralIcon from "../../../icons/resources/mineral.png";
import { cn } from "@/lib/utils";
import type { ResourceKey } from "@/domain/campaign";

export const resourceLabels: Record<ResourceKey, string> = {
  supply: "Suministro vital",
  minerals: "Mineral",
  ancestralStone: "Piedra ancestral",
  uridium: "Uridium",
  technology: "Tecnología"
};

const resourceIcons = {
  supply: supplyIcon,
  minerals: mineralIcon,
  ancestralStone: ancestralStoneIcon,
  uridium: uridiumIcon
};

export function ResourceIcon({
  resource,
  className
}: {
  resource: Exclude<ResourceKey, "technology">;
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
  resource: Exclude<ResourceKey, "technology">;
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
