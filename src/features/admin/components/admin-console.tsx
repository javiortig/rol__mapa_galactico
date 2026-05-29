import { Activity, Clock3, Database, FileText, ShieldAlert, Swords } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/ui/panel";
import { mockCampaignSnapshot } from "@/mocks/campaign-data";
import { formatCountdown } from "@/lib/time";

const adminBlocks = [
  {
    title: "Producción temporal",
    icon: Clock3,
    text: "Tick configurable de 24h con resolución por cron o lazy processing.",
    action: "Configurar"
  },
  {
    title: "Reportes de batalla",
    icon: Swords,
    text: "Coincidencia automática entre participantes o confirmación manual del admin.",
    action: "Revisar"
  },
  {
    title: "Mapa y rutas",
    icon: Database,
    text: "Sistemas, rutas, producción por tick, bloqueos y control territorial.",
    action: "Editar"
  },
  {
    title: "Misiones",
    icon: FileText,
    text: "Briefings narrativos con imagen de mapa, objetivos y reglas especiales.",
    action: "Gestionar"
  }
];

export function AdminConsole() {
  const pendingConflicts = mockCampaignSnapshot.conflicts.filter((conflict) => conflict.status === "pending");
  const pendingReports = mockCampaignSnapshot.battleReports.filter((report) => report.status === "submitted");

  return (
    <main className="min-h-screen px-5 py-5">
      <div className="mx-auto flex max-w-7xl flex-col gap-5">
        <Panel className="p-5">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <div className="text-xs uppercase tracking-[0.24em] text-cyan-200/70">Panel de administración</div>
              <h1 className="mt-2 text-2xl font-semibold text-cyan-50">Control de campaña en tiempo real</h1>
            </div>
            <Button>
              <Activity size={16} />
              Resolver cronos vencidos
            </Button>
          </div>
        </Panel>

        <div className="grid gap-4 md:grid-cols-3">
          <MetricCard label="Conflictos pendientes" value={pendingConflicts.length} tone="rose" />
          <MetricCard label="Reportes por revisar" value={pendingReports.length} tone="amber" />
          <MetricCard
            label="Próximo tick"
            value={formatCountdown(mockCampaignSnapshot.nextResourceTickAt)}
            tone="cyan"
          />
        </div>

        <div className="grid gap-4 lg:grid-cols-4">
          {adminBlocks.map((block) => {
            const Icon = block.icon;

            return (
              <Panel className="p-4" key={block.title}>
                <div className="mb-4 flex items-center justify-between gap-3">
                  <div className="grid size-10 place-items-center rounded-md border border-cyan-300/25 bg-cyan-300/10 text-cyan-100">
                    <Icon size={18} />
                  </div>
                  <Button size="sm" variant="ghost">
                    {block.action}
                  </Button>
                </div>
                <h2 className="text-sm font-semibold text-cyan-50">{block.title}</h2>
                <p className="mt-2 text-sm leading-6 text-slate-300">{block.text}</p>
              </Panel>
            );
          })}
        </div>

        <Panel className="p-5">
          <div className="mb-4 flex items-center gap-3">
            <ShieldAlert className="text-rose-200" size={20} />
            <h2 className="text-lg font-semibold text-cyan-50">Cola de reportes</h2>
          </div>
          <div className="overflow-hidden rounded-md border border-cyan-200/15">
            <table className="w-full border-collapse text-left text-sm">
              <thead className="bg-slate-950/55 text-xs uppercase tracking-[0.16em] text-cyan-200/70">
                <tr>
                  <th className="px-4 py-3">Conflicto</th>
                  <th className="px-4 py-3">Reporta</th>
                  <th className="px-4 py-3">Ganador</th>
                  <th className="px-4 py-3">Estado</th>
                </tr>
              </thead>
              <tbody>
                {mockCampaignSnapshot.battleReports.map((report) => {
                  const conflict = mockCampaignSnapshot.conflicts.find((item) => item.id === report.conflictId);
                  const system = mockCampaignSnapshot.systems.find((item) => item.id === conflict?.systemId);
                  const faction = mockCampaignSnapshot.factions.find((item) => item.id === report.winnerFactionId);

                  return (
                    <tr className="border-t border-cyan-200/10" key={report.id}>
                      <td className="px-4 py-3 text-slate-100">{system?.name ?? report.conflictId}</td>
                      <td className="px-4 py-3 text-slate-300">{report.reporterFactionId ?? "admin"}</td>
                      <td className="px-4 py-3 text-slate-300">{faction?.name ?? "Sin declarar"}</td>
                      <td className="px-4 py-3">
                        <Badge tone={report.status === "submitted" ? "amber" : "cyan"}>{report.status}</Badge>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Panel>
      </div>
    </main>
  );
}

function MetricCard({
  label,
  value,
  tone
}: {
  label: string;
  value: string | number;
  tone: "cyan" | "rose" | "amber";
}) {
  return (
    <Panel className="p-4">
      <div className="text-xs uppercase tracking-[0.18em] text-slate-400">{label}</div>
      <div className="mt-3 flex items-center justify-between">
        <div className="text-3xl font-semibold text-cyan-50">{value}</div>
        <Badge tone={tone}>live</Badge>
      </div>
    </Panel>
  );
}
