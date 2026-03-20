"use client"

import { useState } from "react"
import {
  DndContext,
  DragEndEvent,
  DragOverEvent,
  DragOverlay,
  DragStartEvent,
  PointerSensor,
  useSensor,
  useSensors,
  closestCorners,
} from "@dnd-kit/core"
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable"
import { KanbanColumn } from "./kanban-column"
import { KanbanCardOverlay } from "./kanban-card"
import { supabase } from "@/lib/supabase"
import type { Stage, Lead } from "@/types"

interface KanbanBoardProps {
  stages: Stage[]
  leads: Lead[]
  onRefresh: () => void
}

export function KanbanBoard({ stages, leads, onRefresh }: KanbanBoardProps) {
  const [activeId, setActiveId] = useState<string | null>(null)
  const [leadsByStage, setLeadsByStage] = useState<Record<string, Lead[]>>(() =>
    buildLeadsByStage(stages, leads)
  )

  // Rebuild when props change
  const currentLeadsByStage = buildLeadsByStage(stages, leads)

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
  )

  const activeLead = activeId ? leads.find((l) => l.id === activeId) : null

  const handleDragStart = (event: DragStartEvent) => {
    setActiveId(event.active.id as string)
  }

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event
    setActiveId(null)

    if (!over) return

    const leadId = active.id as string
    const overId = over.id as string

    // Find which stage the lead was dropped into
    const targetStageId = stages.find((s) => s.id === overId)?.id
      || leads.find((l) => l.id === overId)?.stage_id

    if (!targetStageId) return

    const lead = leads.find((l) => l.id === leadId)
    if (!lead || lead.stage_id === targetStageId) return

    // Atualiza estágio + interação atomicamente via RPC
    const stageName = stages.find((s) => s.id === targetStageId)?.name || ""
    const { error } = await supabase.rpc("move_lead_stage", {
      p_lead_id: leadId,
      p_stage_id: targetStageId,
      p_stage_name: stageName,
    })

    if (!error) {
      onRefresh()
    }
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <div className="flex gap-4 overflow-x-auto pb-4" style={{ minHeight: "calc(100vh - 180px)" }}>
        {stages.map((stage) => (
          <KanbanColumn
            key={stage.id}
            stage={stage}
            leads={currentLeadsByStage[stage.id] || []}
            onRefresh={onRefresh}
          />
        ))}
      </div>

      <DragOverlay>
        {activeLead && <KanbanCardOverlay lead={activeLead} />}
      </DragOverlay>
    </DndContext>
  )
}

function buildLeadsByStage(stages: Stage[], leads: Lead[]): Record<string, Lead[]> {
  const map: Record<string, Lead[]> = {}
  stages.forEach((s) => { map[s.id] = [] })
  leads.forEach((l) => {
    if (map[l.stage_id]) map[l.stage_id].push(l)
  })
  return map
}
