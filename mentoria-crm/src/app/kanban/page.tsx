"use client"

export const dynamic = "force-dynamic"

import { KanbanBoard } from "@/components/kanban/kanban-board"
import { useLeads } from "@/hooks/useLeads"
import { useStages } from "@/hooks/useStages"
import { KanbanSquare } from "lucide-react"

export default function KanbanPage() {
  const { stages, loading: stagesLoading } = useStages()
  const { leads, loading: leadsLoading, refetch } = useLeads()

  if (stagesLoading || leadsLoading) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400">
        Carregando kanban...
      </div>
    )
  }

  return (
    <div>
      <div className="flex items-center gap-3 mb-6">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-indigo-100">
          <KanbanSquare className="h-5 w-5 text-indigo-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Kanban</h1>
          <p className="text-sm text-slate-500">{leads.length} leads no pipeline</p>
        </div>
      </div>

      <KanbanBoard stages={stages} leads={leads} onRefresh={refetch} />
    </div>
  )
}
