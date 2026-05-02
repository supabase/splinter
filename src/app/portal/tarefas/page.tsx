import { createClient } from "@/lib/supabase-server";
import { revalidatePath } from "next/cache";
import type { Tarefa } from "@/types/portal";

function formatDate(dateStr: string | null) {
  if (!dateStr) return null;
  return new Date(dateStr + "T00:00:00").toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "short",
  });
}

function isPastDue(dateStr: string | null) {
  if (!dateStr) return false;
  return new Date(dateStr + "T00:00:00") < new Date(new Date().toDateString());
}

const statusConfig = {
  pending: {
    label: "Pendente",
    badge: "bg-[#F7F8FC] text-[#64748b] border border-[#e2e8f0]",
    dot: "bg-[#94a3b8]",
  },
  in_progress: {
    label: "Em andamento",
    badge: "bg-blue-50 text-[#1E88E5] border border-blue-100",
    dot: "bg-[#1E88E5]",
  },
  done: {
    label: "Concluída",
    badge: "bg-green-50 text-green-700 border border-green-100",
    dot: "bg-green-500",
  },
};

export default async function TarefasPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("tarefas")
    .select("*")
    .order("status", { ascending: true })
    .order("due_date", { ascending: true, nullsFirst: false })
    .order("created_at", { ascending: false });

  const tarefas = (data ?? []) as Tarefa[];

  const pending = tarefas.filter((t) => t.status === "pending");
  const in_progress = tarefas.filter((t) => t.status === "in_progress");
  const done = tarefas.filter((t) => t.status === "done");

  async function markDone(formData: FormData) {
    "use server";
    const id = formData.get("id") as string;
    if (!id) return;
    const client = await createClient();
    await client
      .from("tarefas")
      .update({ status: "done", completed_at: new Date().toISOString() })
      .eq("id", id);
    revalidatePath("/portal/tarefas");
  }

  async function markInProgress(formData: FormData) {
    "use server";
    const id = formData.get("id") as string;
    if (!id) return;
    const client = await createClient();
    await client
      .from("tarefas")
      .update({ status: "in_progress", completed_at: null })
      .eq("id", id);
    revalidatePath("/portal/tarefas");
  }

  function TarefaCard({ tarefa }: { tarefa: Tarefa }) {
    const cfg = statusConfig[tarefa.status];
    const overdue = tarefa.status !== "done" && isPastDue(tarefa.due_date);
    return (
      <div className={`bg-white rounded-2xl border shadow-sm p-5 ${tarefa.status === "done" ? "opacity-60 border-[#e2e8f0]" : "border-[#e2e8f0]"}`}>
        <div className="flex items-start justify-between gap-3 mb-2">
          <div className="flex items-center gap-2">
            <div className={`w-2 h-2 rounded-full shrink-0 mt-0.5 ${cfg.dot}`} />
            <p className={`font-semibold text-sm text-[#0f172a] ${tarefa.status === "done" ? "line-through text-[#94a3b8]" : ""}`}>
              {tarefa.title}
            </p>
          </div>
          <span className={`shrink-0 text-[10px] font-bold px-2.5 py-0.5 rounded-full ${cfg.badge}`}>
            {cfg.label}
          </span>
        </div>
        {tarefa.description && (
          <p className="text-[#64748b] text-xs leading-relaxed ml-4 mb-2">{tarefa.description}</p>
        )}
        {tarefa.due_date && (
          <p className={`text-xs ml-4 mb-3 font-medium ${overdue ? "text-red-500" : "text-[#94a3b8]"}`}>
            {overdue ? "⚠ Prazo: " : "Prazo: "}
            {formatDate(tarefa.due_date)}
          </p>
        )}
        {tarefa.status !== "done" && (
          <div className="flex gap-2 ml-4">
            {tarefa.status === "pending" && (
              <form action={markInProgress}>
                <input type="hidden" name="id" value={tarefa.id} />
                <button
                  type="submit"
                  className="text-xs font-semibold text-[#1E88E5] border border-[#1E88E5]/30 hover:bg-blue-50 px-3 py-1.5 rounded-full transition"
                >
                  Iniciar
                </button>
              </form>
            )}
            <form action={markDone}>
              <input type="hidden" name="id" value={tarefa.id} />
              <button
                type="submit"
                className="text-xs font-semibold text-green-700 border border-green-200 hover:bg-green-50 px-3 py-1.5 rounded-full transition"
              >
                Marcar como feito
              </button>
            </form>
          </div>
        )}
        {tarefa.completed_at && (
          <p className="text-[#94a3b8] text-xs ml-4 mt-1">
            Concluída em {new Date(tarefa.completed_at).toLocaleDateString("pt-BR")}
          </p>
        )}
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto">
      <div className="mb-8">
        <p className="text-[#1E88E5] text-xs font-semibold tracking-widest uppercase mb-1">Acompanhamento</p>
        <h1 className="text-2xl sm:text-3xl font-extrabold text-[#0f172a]">Tarefas</h1>
        <p className="text-[#64748b] text-sm mt-1">
          {tarefas.length === 0
            ? "Nenhuma tarefa atribuída ainda."
            : `${pending.length + in_progress.length} pendente${pending.length + in_progress.length !== 1 ? "s" : ""} · ${done.length} concluída${done.length !== 1 ? "s" : ""}`}
        </p>
      </div>

      {tarefas.length === 0 ? (
        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-10 text-center">
          <p className="text-[#64748b] text-sm">O mentor irá atribuir tarefas após as sessões.</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {[...in_progress, ...pending, ...done].map((tarefa) => (
            <TarefaCard key={tarefa.id} tarefa={tarefa} />
          ))}
        </div>
      )}
    </div>
  );
}
