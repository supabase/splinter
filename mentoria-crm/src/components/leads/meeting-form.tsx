"use client"

import { useState } from "react"
import { supabase } from "@/lib/supabase"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

interface MeetingFormProps {
  leadId: string
  onSuccess: () => void
  onCancel: () => void
}

export function MeetingForm({ leadId, onSuccess, onCancel }: MeetingFormProps) {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const [form, setForm] = useState({
    title: "",
    date: "",
    time: "",
    link: "",
  })

  const set = (field: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm((prev) => ({ ...prev, [field]: e.target.value }))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.title || !form.date || !form.time) {
      setError("Título, data e horário são obrigatórios")
      return
    }
    setLoading(true)
    const { error: err } = await supabase.from("meetings").insert({
      lead_id: leadId,
      title: form.title.trim(),
      date: form.date,
      time: form.time,
      link: form.link.trim() || null,
    })
    if (err) {
      setError(err.message)
      setLoading(false)
      return
    }
    await supabase.from("interactions").insert({
      lead_id: leadId,
      type: "meeting",
      content: `Reunião agendada: ${form.title} — ${new Date(form.date).toLocaleDateString("pt-BR")} às ${form.time}`,
    })
    setLoading(false)
    onSuccess()
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <Input label="Título da reunião *" value={form.title} onChange={set("title")} placeholder="Ex: Sessão de diagnóstico" />
      <div className="grid grid-cols-2 gap-4">
        <Input label="Data *" type="date" value={form.date} onChange={set("date")} />
        <Input label="Horário *" type="time" value={form.time} onChange={set("time")} />
      </div>
      <Input label="Link (Zoom/Meet)" value={form.link} onChange={set("link")} placeholder="https://meet.google.com/..." />
      {error && <p className="text-sm text-red-500">{error}</p>}
      <div className="flex gap-3 justify-end">
        <Button type="button" variant="outline" onClick={onCancel}>Cancelar</Button>
        <Button type="submit" disabled={loading}>{loading ? "Salvando..." : "Agendar"}</Button>
      </div>
    </form>
  )
}
