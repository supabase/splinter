"use client"

import { useState } from "react"
import { useDroppable } from "@dnd-kit/core"
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable"
import { Plus } from "lucide-react"
import { KanbanCard } from "./kanban-card"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { LeadForm } from "@/components/leads/lead-form"
import { formatCurrency } from "@/lib/utils"
import type { Stage, Lead } from "@/types"

interface KanbanColumnProps {
  stage: Stage
  leads: Lead[]
  onRefresh: () => void
}

export function KanbanColumn({ stage, leads, onRefresh }: KanbanColumnProps) {
  const [showCreate, setShowCreate] = useState(false)
  const { setNodeRef, isOver } = useDroppable({ id: stage.id })

  const totalValue = leads.reduce((sum, l) => sum + (l.proposal_value || 0), 0)

  return (
    <>
      <div className="flex flex-col w-72 flex-shrink-0">
        {/* Column header */}
        <div
          className="flex items-center justify-between px-3 py-2.5 rounded-xl mb-3"
          style={{ backgroundColor: `${stage.color}15`, borderLeft: `3px solid ${stage.color}` }}
        >
          <div className="flex items-center gap-2">
            <div className="h-2 w-2 rounded-full" style={{ backgroundColor: stage.color }} />
            <span className="text-sm font-semibold" style={{ color: stage.color }}>
              {stage.name}
            </span>
            <span
              className="text-xs font-semibold px-1.5 py-0.5 rounded-full"
              style={{ backgroundColor: `${stage.color}25`, color: stage.color }}
            >
              {leads.length}
            </span>
          </div>
          <div className="flex items-center gap-1.5">
            {totalValue > 0 && (
              <span className="text-xs text-slate-500 font-medium">{formatCurrency(totalValue)}</span>
            )}
            <button
              onClick={() => setShowCreate(true)}
              className="h-6 w-6 rounded-md flex items-center justify-center text-slate-400 hover:text-slate-700 hover:bg-white transition"
            >
              <Plus className="h-3.5 w-3.5" />
            </button>
          </div>
        </div>

        {/* Drop zone */}
        <div
          ref={setNodeRef}
          className={`flex flex-col gap-2.5 flex-1 rounded-xl p-1.5 transition-colors min-h-24 ${
            isOver ? "bg-indigo-50 ring-2 ring-indigo-200" : "bg-slate-100/60"
          }`}
        >
          <SortableContext items={leads.map((l) => l.id)} strategy={verticalListSortingStrategy}>
            {leads.map((lead) => (
              <KanbanCard key={lead.id} lead={lead} />
            ))}
          </SortableContext>

          {leads.length === 0 && (
            <div className="flex items-center justify-center h-20 text-xs text-slate-400">
              Arraste leads aqui
            </div>
          )}
        </div>
      </div>

      <Dialog open={showCreate} onOpenChange={setShowCreate}>
        <DialogContent onClose={() => setShowCreate(false)}>
          <DialogHeader>
            <DialogTitle>Novo Lead em "{stage.name}"</DialogTitle>
          </DialogHeader>
          <LeadForm
            initialStageId={stage.id}
            onSuccess={() => { setShowCreate(false); onRefresh() }}
            onCancel={() => setShowCreate(false)}
          />
        </DialogContent>
      </Dialog>
    </>
  )
}
