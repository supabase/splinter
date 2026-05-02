"use client"

import { useState } from "react"
import { supabase } from "@/lib/supabase"
import { MessageSquare, ArrowRight, Calendar, FileText, RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import type { Interaction } from "@/types"

interface TimelineProps {
  leadId: string
  interactions: Interaction[]
  onRefresh: () => void
}

const icons: Record<string, React.ElementType> = {
  note: MessageSquare,
  stage_change: ArrowRight,
  meeting: Calendar,
  proposal: FileText,
}

const colors: Record<string, string> = {
  note: "bg-blue-100 text-blue-600",
  stage_change: "bg-purple-100 text-purple-600",
  meeting: "bg-indigo-100 text-indigo-600",
  proposal: "bg-emerald-100 text-emerald-600",
}

export function Timeline({ leadId, interactions, onRefresh }: TimelineProps) {
  const [note, setNote] = useState("")
  const [saving, setSaving] = useState(false)

  const addNote = async () => {
    if (!note.trim()) return
    setSaving(true)
    await supabase.from("interactions").insert({
      lead_id: leadId,
      type: "note",
      content: note.trim(),
    })
    setNote("")
    setSaving(false)
    onRefresh()
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Add note */}
      <div className="flex flex-col gap-2">
        <Textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Adicionar uma nota ou observação..."
          rows={3}
        />
        <div className="flex justify-end">
          <Button size="sm" onClick={addNote} disabled={saving || !note.trim()}>
            {saving ? "Salvando..." : "Adicionar nota"}
          </Button>
        </div>
      </div>

      {/* Timeline */}
      <div className="flex flex-col gap-3">
        {interactions.length === 0 ? (
          <p className="text-sm text-slate-400 text-center py-6">Nenhuma interação ainda.</p>
        ) : (
          interactions.map((item) => {
            const Icon = icons[item.type] || MessageSquare
            return (
              <div key={item.id} className="flex gap-3">
                <div className={`h-7 w-7 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5 ${colors[item.type]}`}>
                  <Icon className="h-3.5 w-3.5" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-slate-700 leading-relaxed">{item.content}</p>
                  <p className="text-xs text-slate-400 mt-0.5">
                    {new Date(item.created_at).toLocaleString("pt-BR", {
                      day: "2-digit",
                      month: "2-digit",
                      year: "numeric",
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </p>
                </div>
              </div>
            )
          })
        )}
      </div>

      <button
        onClick={onRefresh}
        className="flex items-center gap-1.5 text-xs text-slate-400 hover:text-slate-600 transition mx-auto"
      >
        <RefreshCw className="h-3 w-3" /> Atualizar
      </button>
    </div>
  )
}
