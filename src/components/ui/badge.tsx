import { cn } from "@/lib/utils";

type BadgeTone = "cyan" | "rose" | "amber" | "slate" | "violet";

const tones: Record<BadgeTone, string> = {
  cyan: "border-cyan-300/30 bg-cyan-300/10 text-cyan-100",
  rose: "border-rose-300/30 bg-rose-300/10 text-rose-100",
  amber: "border-amber-300/30 bg-amber-300/10 text-amber-100",
  slate: "border-slate-300/20 bg-slate-300/8 text-slate-200",
  violet: "border-violet-300/30 bg-violet-300/10 text-violet-100"
};

export function Badge({
  children,
  tone = "slate",
  className
}: {
  children: React.ReactNode;
  tone?: BadgeTone;
  className?: string;
}) {
  return (
    <span className={cn("inline-flex items-center rounded px-2 py-1 text-xs", tones[tone], className)}>
      {children}
    </span>
  );
}
