"use client"

import { useState, useEffect, useRef } from "react"
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
  const [debugMsg, setDebugMsg] = useState<string | null>(null)
  const [leadsByStage, setLeadsByStage] = useState<Record<string, Lead[]>>(() =>
    buildLeadsByStage(stages, leads)
  )
  // Ref sempre atualizado — evita stale closure em handleDragEnd
  const leadsByStageRef = useRef<Record<string, Lead[]>>(leadsByStage)

  useEffect(() => {
    const newState = buildLeadsByStage(stages, leads)
    setLeadsByStage(newState)
    leadsByStageRef.current = newState
  }, [leads, stages])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
  )

  const activeLead = activeId ? leads.find((l) => l.id === activeId) : null

  const handleDragStart = (event: DragStartEvent) => {
    setActiveId(event.active.id as string)
  }

  const handleDragOver = (event: DragOverEvent) => {
    const { active, over } = event
    if (!over) return

    const activeLeadId = active.id as string
    const overId = over.id as string

    // Usa o ref para leitura — nunca stale
    const sourceStageId = Object.keys(leadsByStageRef.current).find((stageId) =>
      leadsByStageRef.current[stageId].some((l) => l.id === activeLeadId)
    )

    const targetStageId =
      stages.find((s) => s.id === overId)?.id ||
      leads.find((l) => l.id === overId)?.stage_id

    if (!sourceStageId || !targetStageId || sourceStageId === targetStageId) return

    setLeadsByStage((prev) => {
      const movedLead = prev[sourceStageId]?.find((l) => l.id === activeLeadId)
      if (!movedLead) return prev
      const newState = {
        ...prev,
        [sourceStageId]: prev[sourceStageId].filter((l) => l.id !== activeLeadId),
        [targetStageId]: [...(prev[targetStageId] || []), movedLead],
      }
      // Atualiza o ref de forma síncrona dentro do setState
      leadsByStageRef.current = newState
      return newState
    })
  }

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active } = event
    setActiveId(null)

    const leadId = active.id as string

    // Lê do ref — sempre reflete o estado mais recente após os drags
    const targetStageId = Object.keys(leadsByStageRef.current).find((stageId) =>
      leadsByStageRef.current[stageId].some((l) => l.id === leadId)
    )

    if (!targetStageId) {
      setDebugMsg("ERRO: targetStageId não encontrado no ref")
      return
    }

    const lead = leads.find((l) => l.id === leadId)

    if (!lead || lead.stage_id === targetStageId) {
      setDebugMsg(`ABORTADO: lead.stage_id=${lead?.stage_id} === targetStageId=${targetStageId} (sem mudança detectada)`)
      return
    }

    const stageName = stages.find((s) => s.id === targetStageId)?.name || ""
    setDebugMsg(`Atualizando: lead "${lead.name}" → "${stageName}"...`)

    const { error: updateError } = await supabase
      .from("leads")
      .update({ stage_id: targetStageId })
      .eq("id", leadId)

    if (updateError) {
      setDebugMsg(`ERRO SUPABASE: [${updateError.code}] ${updateError.message}`)
      const revertState = buildLeadsByStage(stages, leads)
      setLeadsByStage(revertState)
      leadsByStageRef.current = revertState
      return
    }

    setDebugMsg(`OK: "${lead.name}" movido para "${stageName}"`)

    await supabase.from("interactions").insert({
      lead_id: leadId,
      type: "stage_change",
      content: `Movido para "${stageName}"`,
    })

    onRefresh()
  }

  return (
    <>
    {debugMsg && (
      <div className={`mb-4 px-4 py-3 rounded-lg text-sm font-mono font-medium border ${
        debugMsg.startsWith("OK") ? "bg-green-50 border-green-300 text-green-800" :
        debugMsg.startsWith("ERRO") ? "bg-red-50 border-red-300 text-red-800" :
        debugMsg.startsWith("ABORTADO") ? "bg-yellow-50 border-yellow-300 text-yellow-800" :
        "bg-blue-50 border-blue-300 text-blue-800"
      }`}>
        {debugMsg}
      </div>
    )}
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
    </>
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
