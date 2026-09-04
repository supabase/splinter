"use client"

import Link from "next/link"
import { Phone, Mail, Calendar, DollarSign } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { formatCurrency, formatDate } from "@/lib/utils"
import type { Lead } from "@/types"

interface LeadCardProps {
  lead: Lead
  compact?: boolean
}

export function LeadCard({ lead, compact = false }: LeadCardProps) {
  return (
    <Link href={`/leads/${lead.id}`}>
      <div className="bg-white rounded-xl border border-slate-200 p-4 hover:shadow-md hover:border-indigo-200 transition-all cursor-pointer group">
        {/* Header */}
        <div className="flex items-start justify-between gap-2 mb-3">
          <div className="flex items-center gap-2.5">
            <div className="h-8 w-8 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0">
              <span className="text-xs font-bold text-indigo-700">
                {lead.name.charAt(0).toUpperCase()}
              </span>
            </div>
            <div>
              <p className="text-sm font-semibold text-slate-900 group-hover:text-indigo-700 transition-colors leading-none">
                {lead.name}
              </p>
              {lead.source && (
                <p className="text-xs text-slate-400 mt-0.5">{lead.source.name}</p>
              )}
            </div>
          </div>
          {lead.stage && (
            <Badge color={lead.stage.color} className="flex-shrink-0">
              {lead.stage.name}
            </Badge>
          )}
        </div>

        {/* Info */}
        {!compact && (
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center gap-1.5 text-xs text-slate-500">
              <Phone className="h-3 w-3" />
              {lead.phone}
            </div>
            {lead.email && (
              <div className="flex items-center gap-1.5 text-xs text-slate-500">
                <Mail className="h-3 w-3" />
                {lead.email}
              </div>
            )}
            {lead.proposal_value && (
              <div className="flex items-center gap-1.5 text-xs font-medium text-emerald-600">
                <DollarSign className="h-3 w-3" />
                {formatCurrency(lead.proposal_value)}
              </div>
            )}
          </div>
        )}

        {/* Next meeting */}
        {lead.next_meeting && (
          <div className="mt-3 pt-3 border-t border-slate-100 flex items-center gap-1.5 text-xs text-indigo-600 font-medium">
            <Calendar className="h-3 w-3" />
            {lead.next_meeting.title} — {formatDate(lead.next_meeting.date)} às {lead.next_meeting.time.substring(0, 5)}
          </div>
        )}
      </div>
    </Link>
  )
}
