"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"

export default function NewMentoradoPage() {
  const router = useRouter()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [form, setForm] = useState({
    name: "",
    email: "",
    product_name: "",
    start_date: "",
    end_date: "",
    status: "active" as "active" | "completed" | "paused",
    notes: "",
  })

  function set(field: string, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)
    setError(null)

    const { data, error: insertError } = await supabase
      .from("mentorados")
      .insert({
        name: form.name,
        email: form.email,
        product_name: form.product_name,
        start_date: form.start_date || null,
        end_date: form.end_date || null,
        status: form.status,
        notes: form.notes || null,
      })
      .select()
      .single()

    if (insertError) {
      setError("Erro ao criar mentorado. Verifique os dados e tente novamente.")
      setSaving(false)
      return
    }

    router.push(`/mentorados/${data.id}`)
  }

  return (
    <div className="max-w-2xl mx-auto">
      <div className="flex items-center gap-3 mb-6">
        <Link href="/mentorados" className="text-slate-400 hover:text-slate-600 transition-colors">
          <ArrowLeft className="h-5 w-5" />
        </Link>
        <h1 className="text-2xl font-bold text-slate-900">Novo Mentorado</h1>
      </div>

      <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-slate-200 p-6 flex flex-col gap-5">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Nome *</label>
            <input
              required
              value={form.name}
              onChange={(e) => set("name", e.target.value)}
              placeholder="Nome completo"
              className="h-10 rounded-lg border border-slate-200 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Email *</label>
            <input
              required
              type="email"
              value={form.email}
              onChange={(e) => set("email", e.target.value)}
              placeholder="email@exemplo.com"
              className="h-10 rounded-lg border border-slate-200 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Produto</label>
            <input
              value={form.product_name}
              onChange={(e) => set("product_name", e.target.value)}
              placeholder="ex: Ciclo Travessia"
              className="h-10 rounded-lg border border-slate-200 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Status</label>
            <select
              value={form.status}
              onChange={(e) => set("status", e.target.value)}
              className="h-10 rounded-lg border border-slate-200 px-3 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="active">Ativo</option>
              <option value="paused">Pausado</option>
              <option value="completed">Concluído</option>
            </select>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Data de início</label>
            <input
              type="date"
              value={form.start_date}
              onChange={(e) => set("start_date", e.target.value)}
              className="h-10 rounded-lg border border-slate-200 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Data de término</label>
            <input
              type="date"
              value={form.end_date}
              onChange={(e) => set("end_date", e.target.value)}
              className="h-10 rounded-lg border border-slate-200 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="flex flex-col gap-1.5">
          <label className="text-sm font-medium text-slate-700">Notas internas</label>
          <textarea
            rows={3}
            value={form.notes}
            onChange={(e) => set("notes", e.target.value)}
            placeholder="Observações sobre este mentorado (visível apenas para o mentor)"
            className="rounded-lg border border-slate-200 px-3 py-2 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
          />
        </div>

        <div className="bg-indigo-50 border border-indigo-100 rounded-lg p-3 text-xs text-indigo-700">
          <strong>Próximo passo:</strong> Após criar o mentorado, vá ao detalhe para atribuir tarefas, registrar sessões e adicionar materiais. Para dar acesso ao portal, envie o email de convite pelo Supabase Auth.
        </div>

        {error && (
          <p className="text-red-500 text-sm bg-red-50 px-3 py-2 rounded-lg">{error}</p>
        )}

        <div className="flex gap-3">
          <button
            type="submit"
            disabled={saving}
            className="bg-indigo-600 hover:bg-indigo-700 disabled:opacity-60 text-white font-semibold px-6 py-2.5 rounded-lg text-sm transition-colors"
          >
            {saving ? "Criando…" : "Criar Mentorado"}
          </button>
          <Link
            href="/mentorados"
            className="bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 font-semibold px-6 py-2.5 rounded-lg text-sm transition-colors"
          >
            Cancelar
          </Link>
        </div>
      </form>
    </div>
  )
}
