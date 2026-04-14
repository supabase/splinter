"use client"

export const dynamic = "force-dynamic"

import { useState, useEffect } from "react"
import { useParams } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { ArrowLeft, Plus } from "lucide-react"
import Link from "next/link"

interface Mentorado {
  id: string; name: string; email: string; product_name: string
  status: string; start_date: string | null; end_date: string | null; notes: string | null
}
interface Sessao {
  id: string; date: string; duration_min: number
  summary: string | null; decisions: string | null; next_steps: string | null
}
interface Tarefa {
  id: string; title: string; description: string | null
  due_date: string | null; status: string; completed_at: string | null
}
interface Material {
  id: string; title: string; type: string; url: string; description: string | null
}
interface MentoradoMaterial {
  id: string; unlocked_at: string; seen_at: string | null; material: Material
}
interface AvaliacaoWithComp {
  id: string; score: number; notes: string | null; assessed_at: string
  competencia: { name: string } | null
}

const statusColors: Record<string, string> = {
  active: "bg-emerald-100 text-emerald-700",
  completed: "bg-slate-100 text-slate-600",
  paused: "bg-yellow-100 text-yellow-700",
}

const statusLabels: Record<string, string> = {
  active: "Ativo", completed: "Concluído", paused: "Pausado",
}

const tarefaColors: Record<string, string> = {
  pending: "bg-slate-100 text-slate-600",
  in_progress: "bg-blue-100 text-blue-700",
  done: "bg-emerald-100 text-emerald-700",
}

const tarefaLabels: Record<string, string> = {
  pending: "Pendente", in_progress: "Em andamento", done: "Concluída",
}

export default function MentoradoDetailPage() {
  const { id } = useParams<{ id: string }>()
  const [mentorado, setMentorado] = useState<Mentorado | null>(null)
  const [sessoes, setSessoes] = useState<Sessao[]>([])
  const [tarefas, setTarefas] = useState<Tarefa[]>([])
  const [materiais, setMateriais] = useState<MentoradoMaterial[]>([])
  const [avaliacoes, setAvaliacoes] = useState<AvaliacaoWithComp[]>([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<"sessoes" | "tarefas" | "materiais" | "avaliacoes">("sessoes")

  useEffect(() => {
    if (!id) return
    async function load() {
      setLoading(true)
      const [m, s, t, mt, av] = await Promise.all([
        supabase.from("mentorados").select("*").eq("id", id).single(),
        supabase.from("sessoes").select("*").eq("mentorado_id", id).order("date", { ascending: false }),
        supabase.from("tarefas").select("*").eq("mentorado_id", id).order("created_at", { ascending: false }),
        supabase.from("mentorado_materiais").select("*, material:materiais(*)").eq("mentorado_id", id).order("unlocked_at", { ascending: false }),
        supabase.from("avaliacoes_competencia").select("*, competencia:competencias(name)").eq("mentorado_id", id).order("assessed_at", { ascending: false }).limit(20),
      ])
      setMentorado(m.data)
      setSessoes(s.data ?? [])
      setTarefas(t.data ?? [])
      setMateriais(mt.data ?? [])
      setAvaliacoes(av.data ?? [])
      setLoading(false)
    }
    load()
  }, [id])

  if (loading) return <div className="text-center py-20 text-slate-400">Carregando…</div>
  if (!mentorado) return <div className="text-center py-20 text-slate-400">Mentorado não encontrado.</div>

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <Link href="/mentorados" className="text-slate-400 hover:text-slate-600">
          <ArrowLeft className="h-5 w-5" />
        </Link>
        <div className="flex-1 flex items-center gap-4">
          <div className="h-10 w-10 rounded-full bg-indigo-100 flex items-center justify-center shrink-0">
            <span className="text-sm font-bold text-indigo-700">{mentorado.name.charAt(0)}</span>
          </div>
          <div>
            <h1 className="text-xl font-bold text-slate-900">{mentorado.name}</h1>
            <p className="text-sm text-slate-500">{mentorado.email} · {mentorado.product_name}</p>
          </div>
          <span className={`ml-auto text-xs font-semibold px-2.5 py-1 rounded-full ${statusColors[mentorado.status]}`}>
            {statusLabels[mentorado.status]}
          </span>
        </div>
      </div>

      {/* Quick actions */}
      <div className="flex flex-wrap gap-2 mb-6">
        <Link
          href={`/mentorados/${id}/nova-sessao`}
          className="flex items-center gap-1.5 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors"
        >
          <Plus className="h-4 w-4" /> Nova Sessão
        </Link>
        <Link
          href={`/mentorados/${id}/nova-tarefa`}
          className="flex items-center gap-1.5 bg-white border border-slate-200 hover:bg-slate-50 text-slate-700 text-sm font-semibold px-4 py-2 rounded-lg transition-colors"
        >
          <Plus className="h-4 w-4" /> Nova Tarefa
        </Link>
      </div>

      {/* Notes */}
      {mentorado.notes && (
        <div className="bg-amber-50 border border-amber-100 rounded-xl p-4 mb-6 text-sm text-amber-800">
          <strong>Notas internas: </strong>{mentorado.notes}
        </div>
      )}

      {/* Tabs */}
      <div className="flex border-b border-slate-200 mb-6 gap-1">
        {(["sessoes", "tarefas", "materiais", "avaliacoes"] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2.5 text-sm font-semibold capitalize transition-colors border-b-2 -mb-px ${
              activeTab === tab
                ? "border-indigo-600 text-indigo-700"
                : "border-transparent text-slate-500 hover:text-slate-700"
            }`}
          >
            {tab === "sessoes" ? "Sessões" : tab === "tarefas" ? "Tarefas" : tab === "materiais" ? "Materiais" : "Avaliações"}
            <span className="ml-1.5 text-xs text-slate-400">
              ({tab === "sessoes" ? sessoes.length : tab === "tarefas" ? tarefas.length : tab === "materiais" ? materiais.length : avaliacoes.length})
            </span>
          </button>
        ))}
      </div>

      {/* Sessões */}
      {activeTab === "sessoes" && (
        <div className="flex flex-col gap-4">
          {sessoes.length === 0 ? (
            <p className="text-slate-400 text-sm py-8 text-center">Nenhuma sessão registrada.</p>
          ) : sessoes.map((s) => (
            <div key={s.id} className="bg-white rounded-xl border border-slate-200 p-5">
              <div className="flex items-center justify-between mb-3">
                <p className="font-semibold text-slate-900">
                  {new Date(s.date).toLocaleDateString("pt-BR", { weekday: "long", day: "2-digit", month: "long" })}
                </p>
                <span className="text-xs text-slate-400">{s.duration_min} min</span>
              </div>
              {s.summary && (
                <div className="mb-2">
                  <p className="text-xs font-semibold text-indigo-600 uppercase tracking-widest mb-1">Resumo</p>
                  <p className="text-sm text-slate-700 leading-relaxed">{s.summary}</p>
                </div>
              )}
              {s.decisions && (
                <div className="mb-2">
                  <p className="text-xs font-semibold text-emerald-600 uppercase tracking-widest mb-1">Decisões</p>
                  <p className="text-sm text-slate-700 leading-relaxed">{s.decisions}</p>
                </div>
              )}
              {s.next_steps && (
                <div>
                  <p className="text-xs font-semibold text-orange-500 uppercase tracking-widest mb-1">Próximos passos</p>
                  <p className="text-sm text-slate-700 leading-relaxed">{s.next_steps}</p>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Tarefas */}
      {activeTab === "tarefas" && (
        <div className="flex flex-col gap-3">
          {tarefas.length === 0 ? (
            <p className="text-slate-400 text-sm py-8 text-center">Nenhuma tarefa atribuída.</p>
          ) : tarefas.map((t) => (
            <div key={t.id} className="bg-white rounded-xl border border-slate-200 p-4 flex items-start gap-3">
              <span className={`shrink-0 text-xs font-semibold px-2.5 py-1 rounded-full ${tarefaColors[t.status]}`}>
                {tarefaLabels[t.status]}
              </span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-slate-900">{t.title}</p>
                {t.description && <p className="text-xs text-slate-500 mt-0.5">{t.description}</p>}
                {t.due_date && (
                  <p className="text-xs text-slate-400 mt-1">
                    Prazo: {new Date(t.due_date + "T00:00:00").toLocaleDateString("pt-BR")}
                  </p>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Materiais */}
      {activeTab === "materiais" && (
        <div className="flex flex-col gap-3">
          {materiais.length === 0 ? (
            <p className="text-slate-400 text-sm py-8 text-center">Nenhum material atribuído.</p>
          ) : materiais.map((m) => (
            <div key={m.id} className="bg-white rounded-xl border border-slate-200 p-4 flex items-center gap-3">
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-slate-900">{m.material.title}</p>
                {m.material.description && <p className="text-xs text-slate-500 mt-0.5">{m.material.description}</p>}
                <p className="text-xs text-slate-400 mt-1 uppercase font-semibold tracking-wide">{m.material.type}</p>
              </div>
              <div className="text-xs text-slate-400 shrink-0 text-right">
                {m.seen_at ? (
                  <span className="text-emerald-600 font-medium">Visto</span>
                ) : (
                  <span>Não visto</span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Avaliações */}
      {activeTab === "avaliacoes" && (
        <div className="flex flex-col gap-3">
          {avaliacoes.length === 0 ? (
            <p className="text-slate-400 text-sm py-8 text-center">Nenhuma avaliação registrada.</p>
          ) : avaliacoes.map((a) => (
            <div key={a.id} className="bg-white rounded-xl border border-slate-200 p-4 flex items-center gap-4">
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-slate-900">{a.competencia?.name ?? "—"}</p>
                {a.notes && <p className="text-xs text-slate-500 mt-0.5">{a.notes}</p>}
                <p className="text-xs text-slate-400 mt-1">
                  {new Date(a.assessed_at).toLocaleDateString("pt-BR", { day: "2-digit", month: "short", year: "numeric" })}
                </p>
              </div>
              <div className="flex items-center gap-1.5 shrink-0">
                <div className="h-8 w-8 rounded-full flex items-center justify-center text-sm font-extrabold text-white"
                  style={{ backgroundColor: `hsl(${(a.score / 10) * 120}, 60%, 50%)` }}>
                  {a.score}
                </div>
                <span className="text-xs text-slate-400">/10</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
