"use client"

import Link from "next/link"
import { useSortable } from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import { Phone, Calendar, DollarSign, GripVertical } from "lucide-react"
import { formatCurrency, formatDate } from "@/lib/utils"
import type { Lead } from "@/types"

interface KanbanCardProps {
  lead: Lead
}

export function KanbanCard({ lead }: KanbanCardProps) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: lead.id,
  })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.4 : 1,
  }

  return (
    <div ref={setNodeRef} style={style} {...attributes}>
      <div className="bg-white rounded-xl border border-slate-200 p-3 shadow-sm hover:shadow-md hover:border-indigo-200 transition-all group">
        <div className="flex items-start gap-2">
          {/* Drag handle */}
          <div
            {...listeners}
            className="mt-0.5 text-slate-300 hover:text-slate-500 cursor-grab active:cursor-grabbing flex-shrink-0"
          >
            <GripVertical className="h-4 w-4" />
          </div>

          {/* Content */}
          <Link href={`/leads/${lead.id}`} className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-2">
              <div className="h-6 w-6 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0">
                <span className="text-xs font-bold text-indigo-700">
                  {lead.name.charAt(0).toUpperCase()}
                </span>
              </div>
              <p className="text-sm font-semibold text-slate-900 truncate group-hover:text-indigo-700 transition-colors">
                {lead.name}
              </p>
            </div>

            <div className="flex flex-col gap-1">
              <div className="flex items-center gap-1.5 text-xs text-slate-500">
                <Phone className="h-3 w-3" />
                {lead.phone}
              </div>

              {lead.proposal_value && (
                <div className="flex items-center gap-1.5 text-xs font-semibold text-emerald-600">
                  <DollarSign className="h-3 w-3" />
                  {formatCurrency(lead.proposal_value)}
                </div>
              )}

              {lead.next_meeting && (
                <div className="flex items-center gap-1.5 text-xs text-indigo-500 font-medium mt-1 pt-1 border-t border-slate-100">
                  <Calendar className="h-3 w-3" />
                  {formatDate(lead.next_meeting.date)} {lead.next_meeting.time.substring(0, 5)}
                </div>
              )}
            </div>
          </Link>
        </div>
      </div>
    </div>
  )
}

export function KanbanCardOverlay({ lead }: KanbanCardProps) {
  return (
    <div className="bg-white rounded-xl border-2 border-indigo-400 p-3 shadow-2xl w-72 rotate-2 opacity-90">
      <div className="flex items-center gap-2 mb-1">
        <div className="h-6 w-6 rounded-full bg-indigo-100 flex items-center justify-center">
          <span className="text-xs font-bold text-indigo-700">
            {lead.name.charAt(0).toUpperCase()}
          </span>
        </div>
        <p className="text-sm font-semibold text-slate-900">{lead.name}</p>
      </div>
      <p className="text-xs text-slate-500">{lead.phone}</p>
    </div>
  )
}
