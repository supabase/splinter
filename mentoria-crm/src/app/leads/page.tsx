"use client"

export const dynamic = "force-dynamic"

import { useState } from "react"
import { Plus, Search, Filter, Phone, Mail, Calendar } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select } from "@/components/ui/select"
import { Badge } from "@/components/ui/badge"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { LeadForm } from "@/components/leads/lead-form"
import { useLeads } from "@/hooks/useLeads"
import { useStages } from "@/hooks/useStages"
import { useSources } from "@/hooks/useSources"
import { formatCurrency, formatDate } from "@/lib/utils"
import Link from "next/link"

export default function LeadsPage() {
  const [search, setSearch] = useState("")
  const [stageFilter, setStageFilter] = useState("")
  const [sourceFilter, setSourceFilter] = useState("")
  const [showCreate, setShowCreate] = useState(false)

  const { leads, loading, refetch } = useLeads({
    search: search || undefined,
    stageId: stageFilter || undefined,
    sourceId: sourceFilter || undefined,
  })
  const { stages } = useStages()
  const { sources } = useSources()

  return (
    <div className="max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Leads</h1>
          <p className="text-sm text-slate-500 mt-0.5">
            {leads.length} lead{leads.length !== 1 ? "s" : ""} encontrado{leads.length !== 1 ? "s" : ""}
          </p>
        </div>
        <Button onClick={() => setShowCreate(true)}>
          <Plus className="h-4 w-4 mr-2" />
          Novo Lead
        </Button>
      </div>

      {/* Filters */}
      <div className="flex gap-3 mb-6 flex-wrap">
        <div className="relative flex-1 min-w-64">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por nome, telefone ou e-mail..."
            className="h-10 w-full rounded-lg border border-slate-200 bg-white pl-9 pr-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>
        <div className="w-48">
          <Select
            value={stageFilter}
            onChange={(e) => setStageFilter(e.target.value)}
            placeholder="Todos os estágios"
            options={stages.map((s) => ({ value: s.id, label: s.name }))}
          />
        </div>
        <div className="w-44">
          <Select
            value={sourceFilter}
            onChange={(e) => setSourceFilter(e.target.value)}
            placeholder="Todas as origens"
            options={sources.map((s) => ({ value: s.id, label: s.name }))}
          />
        </div>
        {(stageFilter || sourceFilter || search) && (
          <Button
            variant="ghost"
            onClick={() => { setSearch(""); setStageFilter(""); setSourceFilter("") }}
          >
            Limpar filtros
          </Button>
        )}
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex items-center justify-center py-20 text-slate-400">Carregando leads...</div>
      ) : leads.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-400 gap-3">
          <Filter className="h-10 w-10 opacity-30" />
          <p className="text-sm">Nenhum lead encontrado</p>
          <Button variant="outline" onClick={() => setShowCreate(true)}>
            <Plus className="h-4 w-4 mr-1.5" /> Criar primeiro lead
          </Button>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50">
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Lead</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Contato</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Estágio</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Proposta</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Próx. Reunião</th>
                <th className="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-5 py-3">Origem</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {leads.map((lead) => (
                <tr key={lead.id} className="hover:bg-slate-50 transition-colors group">
                  <td className="px-5 py-4">
                    <Link href={`/leads/${lead.id}`} className="flex items-center gap-3">
                      <div className="h-8 w-8 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0">
                        <span className="text-xs font-bold text-indigo-700">
                          {lead.name.charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <span className="text-sm font-medium text-slate-900 group-hover:text-indigo-700 transition-colors">
                        {lead.name}
                      </span>
                    </Link>
                  </td>
                  <td className="px-5 py-4">
                    <div className="flex flex-col gap-0.5">
                      <span className="flex items-center gap-1.5 text-xs text-slate-600">
                        <Phone className="h-3 w-3" /> {lead.phone}
                      </span>
                      {lead.email && (
                        <span className="flex items-center gap-1.5 text-xs text-slate-400">
                          <Mail className="h-3 w-3" /> {lead.email}
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-5 py-4">
                    {lead.stage && (
                      <Badge color={lead.stage.color}>{lead.stage.name}</Badge>
                    )}
                  </td>
                  <td className="px-5 py-4">
                    {lead.proposal_value ? (
                      <div>
                        <p className="text-sm font-semibold text-emerald-600">{formatCurrency(lead.proposal_value)}</p>
                        {lead.payment_method && (
                          <p className="text-xs text-slate-400">{lead.payment_method}</p>
                        )}
                      </div>
                    ) : (
                      <span className="text-xs text-slate-300">—</span>
                    )}
                  </td>
                  <td className="px-5 py-4">
                    {lead.next_meeting ? (
                      <div className="flex items-center gap-1.5 text-xs text-indigo-600">
                        <Calendar className="h-3 w-3" />
                        {formatDate(lead.next_meeting.date)} {lead.next_meeting.time.substring(0, 5)}
                      </div>
                    ) : (
                      <span className="text-xs text-slate-300">—</span>
                    )}
                  </td>
                  <td className="px-5 py-4">
                    <span className="text-xs text-slate-500">{lead.source?.name || "—"}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Create Dialog */}
      <Dialog open={showCreate} onOpenChange={setShowCreate}>
        <DialogContent onClose={() => setShowCreate(false)}>
          <DialogHeader>
            <DialogTitle>Novo Lead</DialogTitle>
          </DialogHeader>
          <LeadForm
            onSuccess={() => { setShowCreate(false); refetch() }}
            onCancel={() => setShowCreate(false)}
          />
        </DialogContent>
      </Dialog>
    </div>
  )
}
