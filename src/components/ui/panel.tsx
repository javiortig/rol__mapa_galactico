import { cn } from "@/lib/utils";

export function Panel({
  children,
  className
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return <section className={cn("hud-panel rounded-lg", className)}>{children}</section>;
}
