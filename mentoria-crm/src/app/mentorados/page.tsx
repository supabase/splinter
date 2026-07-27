"use client"

export const dynamic = "force-dynamic"

import { useState, useEffect } from "react"
import { Plus, Search, User } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface Mentorado {
  id: string
  name: string
  email: string
  product_name: string
  status: "active" | "completed" | "paused"
  start_date: string | null
  end_date: string | null
}

const statusColors: Record<string, string> = {
  active: "bg-emerald-100 text-emerald-700",
  completed: "bg-slate-100 text-slate-600",
  paused: "bg-yellow-100 text-yellow-700",
}

const statusLabels: Record<string, string> = {
  active: "Ativo",
  completed: "Concluído",
  paused: "Pausado",
}

export default function MentoradosPage() {
  const [mentorados, setMentorados] = useState<Mentorado[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState("")
  const [statusFilter, setStatusFilter] = useState("")

  useEffect(() => {
    async function load() {
      setLoading(true)
      let query = supabase
        .from("mentorados")
        .select("id, name, email, product_name, status, start_date, end_date")
        .order("created_at", { ascending: false })

      if (statusFilter) query = query.eq("status", statusFilter)
      if (search) query = query.ilike("name", `%${search}%`)

      const { data } = await query
      setMentorados(data ?? [])
      setLoading(false)
    }
    load()
  }, [search, statusFilter])

  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Mentorados</h1>
          <p className="text-sm text-slate-500 mt-0.5">
            {mentorados.length} mentorado{mentorados.length !== 1 ? "s" : ""}
          </p>
        </div>
        <Link
          href="/mentorados/new"
          className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors"
        >
          <Plus className="h-4 w-4" />
          Novo Mentorado
        </Link>
      </div>

      {/* Filters */}
      <div className="flex gap-3 mb-6 flex-wrap">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por nome…"
            className="h-10 w-full rounded-lg border border-slate-200 bg-white pl-9 pr-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="h-10 rounded-lg border border-slate-200 bg-white px-3 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
        >
          <option value="">Todos os status</option>
          <option value="active">Ativo</option>
          <option value="paused">Pausado</option>
          <option value="completed">Concluído</option>
        </select>
      </div>

      {loading ? (
        <div className="text-center py-20 text-slate-400">Carregando…</div>
      ) : mentorados.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-400 gap-3">
          <User className="h-10 w-10 opacity-30" />
          <p className="text-sm">Nenhum mentorado encontrado</p>
          <Link
            href="/mentorados/new"
            className="text-sm font-medium text-indigo-600 hover:underline"
          >
            Criar primeiro mentorado
          </Link>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50">
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Nome</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Produto</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Status</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Início</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Fim</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {mentorados.map((m) => (
                <tr key={m.id} className="hover:bg-slate-50 transition-colors group">
                  <td className="px-5 py-4">
                    <Link href={`/mentorados/${m.id}`} className="flex items-center gap-3">
                      <div className="h-8 w-8 rounded-full bg-indigo-100 flex items-center justify-center shrink-0">
                        <span className="text-xs font-bold text-indigo-700">
                          {m.name.charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <div>
                        <p className="text-sm font-medium text-slate-900 group-hover:text-indigo-700 transition-colors">
                          {m.name}
                        </p>
                        <p className="text-xs text-slate-400">{m.email}</p>
                      </div>
                    </Link>
                  </td>
                  <td className="px-5 py-4 text-sm text-slate-600">{m.product_name || "—"}</td>
                  <td className="px-5 py-4">
                    <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${statusColors[m.status]}`}>
                      {statusLabels[m.status]}
                    </span>
                  </td>
                  <td className="px-5 py-4 text-xs text-slate-500">
                    {m.start_date
                      ? new Date(m.start_date).toLocaleDateString("pt-BR")
                      : "—"}
                  </td>
                  <td className="px-5 py-4 text-xs text-slate-500">
                    {m.end_date
                      ? new Date(m.end_date).toLocaleDateString("pt-BR")
                      : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
