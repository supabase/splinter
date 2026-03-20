"use client"

import { useState, useEffect } from "react"
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

  // Sincroniza estado local quando as props são atualizadas (após refresh)
  useEffect(() => {
    setLeadsByStage(buildLeadsByStage(stages, leads))
  }, [leads, stages])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
  )

  const activeLead = activeId ? leads.find((l) => l.id === activeId) : null

  const handleDragStart = (event: DragStartEvent) => {
    setActiveId(event.active.id as string)
  }

  // Move o card visualmente entre colunas durante o arraste
  const handleDragOver = (event: DragOverEvent) => {
    const { active, over } = event
    if (!over) return

    const activeLeadId = active.id as string
    const overId = over.id as string

    // Coluna de origem (via estado local, que pode já ter sido movido)
    const sourceStageId = Object.keys(leadsByStage).find((stageId) =>
      leadsByStage[stageId].some((l) => l.id === activeLeadId)
    )

    // Coluna de destino: pode ser o id da coluna ou o id de um card dentro dela
    const targetStageId =
      stages.find((s) => s.id === overId)?.id ||
      leads.find((l) => l.id === overId)?.stage_id

    if (!sourceStageId || !targetStageId || sourceStageId === targetStageId) return

    setLeadsByStage((prev) => {
      const movedLead = prev[sourceStageId]?.find((l) => l.id === activeLeadId)
      if (!movedLead) return prev
      return {
        ...prev,
        [sourceStageId]: prev[sourceStageId].filter((l) => l.id !== activeLeadId),
        [targetStageId]: [...(prev[targetStageId] || []), movedLead],
      }
    })
  }

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event
    setActiveId(null)

    if (!over) return

    const leadId = active.id as string
    const overId = over.id as string

    const targetStageId =
      stages.find((s) => s.id === overId)?.id ||
      leads.find((l) => l.id === overId)?.stage_id

    if (!targetStageId) return

    // Usa as props originais para checar se houve mudança real
    const lead = leads.find((l) => l.id === leadId)
    if (!lead || lead.stage_id === targetStageId) return

    const stageName = stages.find((s) => s.id === targetStageId)?.name || ""
    const { error } = await supabase.rpc("move_lead_stage", {
      p_lead_id: leadId,
      p_stage_id: targetStageId,
      p_stage_name: stageName,
    })

    if (!error) {
      onRefresh()
    } else {
      // Reverte o estado otimista em caso de erro
      setLeadsByStage(buildLeadsByStage(stages, leads))
    }
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragOver={handleDragOver}
      onDragEnd={handleDragEnd}
    >
      <div className="flex gap-4 overflow-x-auto pb-4" style={{ minHeight: "calc(100vh - 180px)" }}>
        {stages.map((stage) => (
          <KanbanColumn
            key={stage.id}
            stage={stage}
            leads={leadsByStage[stage.id] || []}
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
