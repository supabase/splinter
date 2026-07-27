"use client"

import { useState } from "react"
import { useParams, useRouter } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"

export default function NovaSessaoPage() {
  const { id } = useParams<{ id: string }>()
  const router = useRouter()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [form, setForm] = useState({
    date: new Date().toISOString().slice(0, 10),
    duration_min: "60",
    summary: "",
    decisions: "",
    next_steps: "",
  })

  function set(field: string, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)
    setError(null)

    const { error: insertError } = await supabase.from("sessoes").insert({
      mentorado_id: id,
      date: form.date,
      duration_min: parseInt(form.duration_min),
      summary: form.summary || null,
      decisions: form.decisions || null,
      next_steps: form.next_steps || null,
    })

    if (insertError) {
      setError("Erro ao registrar sessão.")
      setSaving(false)
      return
    }

    router.push(`/mentorados/${id}`)
  }

  return (
    <div className="max-w-2xl mx-auto">
      <div className="flex items-center gap-3 mb-6">
        <Link href={`/mentorados/${id}`} className="text-slate-400 hover:text-slate-600">
          <ArrowLeft className="h-5 w-5" />
        </Link>
        <h1 className="text-xl font-bold text-slate-900">Registrar Sessão</h1>
      </div>

      <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-slate-200 p-6 flex flex-col gap-5">
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Data *</label>
            <input
              required
              type="date"
              value={form.date}
              onChange={(e) => set("date", e.target.value)}
              className="h-10 rounded-lg border border-slate-200 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Duração (min)</label>
            <input
              type="number"
              min="15"
              max="180"
              value={form.duration_min}
              onChange={(e) => set("duration_min", e.target.value)}
              className="h-10 rounded-lg border border-slate-200 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        {[
          { field: "summary", label: "Resumo da sessão" },
          { field: "decisions", label: "Decisões tomadas" },
          { field: "next_steps", label: "Próximos passos" },
        ].map(({ field, label }) => (
          <div key={field} className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">{label}</label>
            <textarea
              rows={3}
              value={form[field as keyof typeof form]}
              onChange={(e) => set(field, e.target.value)}
              placeholder={label}
              className="rounded-lg border border-slate-200 px-3 py-2 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
            />
          </div>
        ))}

        {error && (
          <p className="text-red-500 text-sm bg-red-50 px-3 py-2 rounded-lg">{error}</p>
        )}

        <div className="flex gap-3">
          <button
            type="submit"
            disabled={saving}
            className="bg-indigo-600 hover:bg-indigo-700 disabled:opacity-60 text-white font-semibold px-6 py-2.5 rounded-lg text-sm transition-colors"
          >
            {saving ? "Salvando…" : "Salvar Sessão"}
          </button>
          <Link
            href={`/mentorados/${id}`}
            className="bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 font-semibold px-6 py-2.5 rounded-lg text-sm transition-colors"
          >
            Cancelar
          </Link>
        </div>
      </form>
    </div>
  )
}
