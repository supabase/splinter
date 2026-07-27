import { createClient } from "@/lib/supabase-server";
import type { Mentorado, Tarefa, Sessao, MentoradoMaterial } from "@/types/portal";

function formatDate(dateStr: string | null) {
  if (!dateStr) return "—";
  return new Date(dateStr).toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

const statusColors: Record<string, string> = {
  pending: "bg-[#F7F8FC] text-[#64748b] border border-[#e2e8f0]",
  in_progress: "bg-blue-50 text-[#1E88E5] border border-blue-100",
  done: "bg-green-50 text-green-700 border border-green-100",
};

const statusLabels: Record<string, string> = {
  pending: "Pendente",
  in_progress: "Em andamento",
  done: "Concluída",
};

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;

  const [mentoradoRes, tarefasRes, sessoesRes, materiaisRes] = await Promise.all([
    supabase
      .from("mentorados")
      .select("*")
      .eq("user_id", user.id)
      .single(),
    supabase
      .from("tarefas")
      .select("*")
      .order("due_date", { ascending: true })
      .limit(3),
    supabase
      .from("sessoes")
      .select("*")
      .order("date", { ascending: false })
      .limit(1),
    supabase
      .from("mentorado_materiais")
      .select("*, material:materiais(*)")
      .order("unlocked_at", { ascending: false })
      .limit(1),
  ]);

  const mentorado = mentoradoRes.data as Mentorado | null;
  const tarefas = (tarefasRes.data ?? []) as Tarefa[];
  const sessoes = (sessoesRes.data ?? []) as Sessao[];
  const materiais = (materiaisRes.data ?? []) as MentoradoMaterial[];

  const pendingCount = tarefas.filter((t) => t.status !== "done").length;
  const lastSessao = sessoes[0] ?? null;
  const lastMaterial = materiais[0] ?? null;

  return (
    <div className="max-w-3xl mx-auto">
      {/* Greeting */}
      <div className="mb-8">
        <p className="text-[#1E88E5] text-xs font-semibold tracking-widest uppercase mb-1">
          Portal do Mentorado
        </p>
        <h1 className="text-2xl sm:text-3xl font-extrabold text-[#0f172a]">
          Olá{mentorado?.name ? `, ${mentorado.name.split(" ")[0]}` : ""}!
        </h1>
        {mentorado && (
          <p className="text-[#64748b] text-sm mt-1">
            {mentorado.product_name}
            {mentorado.start_date && (
              <> · Iniciou em {formatDate(mentorado.start_date)}</>
            )}
          </p>
        )}
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div className="bg-white rounded-2xl p-5 border border-[#e2e8f0] shadow-sm">
          <p className="text-[#64748b] text-xs font-semibold uppercase tracking-widest mb-2">Tarefas pendentes</p>
          <p className="text-3xl font-extrabold text-[#0f172a]">{pendingCount}</p>
          <p className="text-[#64748b] text-xs mt-1">de {tarefas.length} no total</p>
        </div>
        <div className="bg-white rounded-2xl p-5 border border-[#e2e8f0] shadow-sm">
          <p className="text-[#64748b] text-xs font-semibold uppercase tracking-widest mb-2">Última sessão</p>
          <p className="text-base font-bold text-[#0f172a]">{lastSessao ? formatDate(lastSessao.date) : "—"}</p>
          {lastSessao?.duration_min && (
            <p className="text-[#64748b] text-xs mt-1">{lastSessao.duration_min} min</p>
          )}
        </div>
        <div className="bg-white rounded-2xl p-5 border border-[#e2e8f0] shadow-sm">
          <p className="text-[#64748b] text-xs font-semibold uppercase tracking-widest mb-2">Status</p>
          <span className={`inline-block text-xs font-bold px-3 py-1 rounded-full capitalize ${
            mentorado?.status === "active"
              ? "bg-green-50 text-green-700 border border-green-100"
              : mentorado?.status === "paused"
              ? "bg-yellow-50 text-yellow-700 border border-yellow-100"
              : "bg-[#F7F8FC] text-[#64748b] border border-[#e2e8f0]"
          }`}>
            {mentorado?.status === "active" ? "Ativa" : mentorado?.status === "paused" ? "Pausada" : mentorado?.status ?? "—"}
          </span>
        </div>
      </div>

      {/* Upcoming tasks */}
      {tarefas.length > 0 && (
        <div className="bg-white rounded-2xl border border-[#e2e8f0] shadow-sm mb-6">
          <div className="px-5 py-4 border-b border-[#e2e8f0] flex items-center justify-between">
            <h2 className="font-bold text-[#0f172a]">Próximas tarefas</h2>
            <a href="/portal/tarefas" className="text-[#1E88E5] text-xs font-semibold hover:underline">
              Ver todas →
            </a>
          </div>
          <ul className="divide-y divide-[#f1f5f9]">
            {tarefas.map((t) => (
              <li key={t.id} className="px-5 py-3.5 flex items-start gap-3">
                <span className={`shrink-0 text-xs font-semibold px-2.5 py-1 rounded-full mt-0.5 ${statusColors[t.status]}`}>
                  {statusLabels[t.status]}
                </span>
                <div className="min-w-0">
                  <p className="text-[#0f172a] text-sm font-medium truncate">{t.title}</p>
                  {t.due_date && (
                    <p className="text-[#94a3b8] text-xs mt-0.5">Prazo: {formatDate(t.due_date)}</p>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Last session */}
      {lastSessao && (
        <div className="bg-white rounded-2xl border border-[#e2e8f0] shadow-sm mb-6">
          <div className="px-5 py-4 border-b border-[#e2e8f0]">
            <h2 className="font-bold text-[#0f172a]">Última sessão — {formatDate(lastSessao.date)}</h2>
          </div>
          <div className="px-5 py-4 flex flex-col gap-3">
            {lastSessao.summary && (
              <div>
                <p className="text-[#1E88E5] text-xs font-semibold uppercase tracking-widest mb-1">Resumo</p>
                <p className="text-[#0f172a] text-sm leading-relaxed">{lastSessao.summary}</p>
              </div>
            )}
            {lastSessao.decisions && (
              <div>
                <p className="text-[#1E88E5] text-xs font-semibold uppercase tracking-widest mb-1">Decisões</p>
                <p className="text-[#0f172a] text-sm leading-relaxed">{lastSessao.decisions}</p>
              </div>
            )}
            {lastSessao.next_steps && (
              <div>
                <p className="text-[#F97316] text-xs font-semibold uppercase tracking-widest mb-1">Próximos passos</p>
                <p className="text-[#0f172a] text-sm leading-relaxed">{lastSessao.next_steps}</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Last material */}
      {lastMaterial?.material && (
        <div className="bg-white rounded-2xl border border-[#e2e8f0] shadow-sm">
          <div className="px-5 py-4 border-b border-[#e2e8f0] flex items-center justify-between">
            <h2 className="font-bold text-[#0f172a]">Material recente</h2>
            <a href="/portal/materiais" className="text-[#1E88E5] text-xs font-semibold hover:underline">
              Ver biblioteca →
            </a>
          </div>
          <div className="px-5 py-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#F7F8FC] border border-[#e2e8f0] flex items-center justify-center shrink-0">
              <MaterialTypeIcon type={lastMaterial.material.type} />
            </div>
            <div>
              <p className="text-[#0f172a] font-medium text-sm">{lastMaterial.material.title}</p>
              {lastMaterial.material.description && (
                <p className="text-[#64748b] text-xs mt-0.5 line-clamp-1">{lastMaterial.material.description}</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function MaterialTypeIcon({ type }: { type: string }) {
  if (type === "pdf")
    return <svg className="w-5 h-5 text-red-500" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>;
  if (type === "video")
    return <svg className="w-5 h-5 text-[#1E88E5]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M15 10l4.553-2.069A1 1 0 0121 8.87v6.26a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>;
  if (type === "template")
    return <svg className="w-5 h-5 text-[#F97316]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" /></svg>;
  return <svg className="w-5 h-5 text-[#64748b]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" /></svg>;
}
