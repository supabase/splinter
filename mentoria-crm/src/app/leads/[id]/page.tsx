"use client"

export const dynamic = "force-dynamic"

import { useState, useEffect, useCallback } from "react"
import { useParams, useRouter } from "next/navigation"
import {
  ArrowLeft, Phone, Mail, Calendar, Edit3, Trash2, Plus,
  ExternalLink, Send, DollarSign
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { LeadForm } from "@/components/leads/lead-form"
import { MeetingForm } from "@/components/leads/meeting-form"
import { Timeline } from "@/components/leads/timeline"
import { formatCurrency, formatDate } from "@/lib/utils"
import type { Lead, Meeting, Interaction } from "@/types"

export default function LeadDetailPage() {
  const params = useParams()
  const router = useRouter()
  const id = params.id as string

  const [lead, setLead] = useState<Lead | null>(null)
  const [meetings, setMeetings] = useState<Meeting[]>([])
  const [interactions, setInteractions] = useState<Interaction[]>([])
  const [loading, setLoading] = useState(true)
  const [showEdit, setShowEdit] = useState(false)
  const [showMeeting, setShowMeeting] = useState(false)
  const [sendingNotif, setSendingNotif] = useState<string | null>(null)

  const fetchLead = useCallback(async () => {
    const { data } = await supabase
      .from("leads")
      .select("*, stage:stages(*), source:sources(*), product:products(*)")
      .eq("id", id)
      .single()
    setLead(data)
  }, [id])

  const fetchMeetings = useCallback(async () => {
    const { data } = await supabase
      .from("meetings")
      .select("*")
      .eq("lead_id", id)
      .order("date", { ascending: true })
    setMeetings(data || [])
  }, [id])

  const fetchInteractions = useCallback(async () => {
    const { data } = await supabase
      .from("interactions")
      .select("*")
      .eq("lead_id", id)
      .order("created_at", { ascending: false })
    setInteractions(data || [])
  }, [id])

  const fetchAll = useCallback(async () => {
    setLoading(true)
    await Promise.all([fetchLead(), fetchMeetings(), fetchInteractions()])
    setLoading(false)
  }, [fetchLead, fetchMeetings, fetchInteractions])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  const deleteLead = async () => {
    if (!confirm(`Tem certeza que deseja excluir o lead "${lead?.name}"?`)) return
    await supabase.from("leads").delete().eq("id", id)
    router.push("/leads")
  }

  const sendWhatsAppNotif = async (meeting: Meeting) => {
    if (!lead) return
    setSendingNotif(meeting.id)
    await fetch("/api/notify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        leadName: lead.name,
        meetingTitle: meeting.title,
        date: meeting.date,
        time: meeting.time,
        link: meeting.link,
      }),
    })
    await supabase.from("meetings").update({ notified: true }).eq("id", meeting.id)
    await fetchMeetings()
    setSendingNotif(null)
  }

  const deleteMeeting = async (meetingId: string) => {
    await supabase.from("meetings").delete().eq("id", meetingId)
    await fetchMeetings()
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400">
        Carregando...
      </div>
    )
  }

  if (!lead) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3 text-slate-400">
        <p>Lead não encontrado</p>
        <Button variant="outline" onClick={() => router.push("/leads")}>Voltar</Button>
      </div>
    )
  }

  const upcomingMeetings = meetings.filter((m) => new Date(m.date) >= new Date())
  const pastMeetings = meetings.filter((m) => new Date(m.date) < new Date())

  return (
    <div className="max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="icon" onClick={() => router.back()}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-full bg-indigo-100 flex items-center justify-center">
              <span className="text-base font-bold text-indigo-700">
                {lead.name.charAt(0).toUpperCase()}
              </span>
            </div>
            <div>
              <h1 className="text-xl font-bold text-slate-900">{lead.name}</h1>
              {lead.stage && <Badge color={lead.stage.color}>{lead.stage.name}</Badge>}
            </div>
          </div>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={() => setShowEdit(true)}>
            <Edit3 className="h-4 w-4 mr-1.5" /> Editar
          </Button>
          <Button variant="destructive" size="icon" onClick={deleteLead}>
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-6">
        {/* Left: Info + Meetings */}
        <div className="col-span-2 flex flex-col gap-5">
          {/* Contact info */}
          <Card>
            <CardHeader>
              <CardTitle>Informações do Lead</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 gap-4">
                <div className="flex items-center gap-2">
                  <Phone className="h-4 w-4 text-slate-400" />
                  <div>
                    <p className="text-xs text-slate-400">Telefone</p>
                    <p className="text-sm font-medium text-slate-800">{lead.phone}</p>
                  </div>
                </div>
                {lead.email && (
                  <div className="flex items-center gap-2">
                    <Mail className="h-4 w-4 text-slate-400" />
                    <div>
                      <p className="text-xs text-slate-400">E-mail</p>
                      <p className="text-sm font-medium text-slate-800">{lead.email}</p>
                    </div>
                  </div>
                )}
                {lead.source && (
                  <div>
                    <p className="text-xs text-slate-400">Origem</p>
                    <p className="text-sm font-medium text-slate-800">{lead.source.name}</p>
                  </div>
                )}
                <div>
                  <p className="text-xs text-slate-400">Criado em</p>
                  <p className="text-sm font-medium text-slate-800">{formatDate(lead.created_at)}</p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Proposal */}
          {(lead.proposal_value || lead.product || lead.payment_method) && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <DollarSign className="h-4 w-4 text-emerald-500" /> Proposta
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-3 gap-4">
                  {lead.proposal_value && (
                    <div>
                      <p className="text-xs text-slate-400">Valor</p>
                      <p className="text-lg font-bold text-emerald-600">{formatCurrency(lead.proposal_value)}</p>
                    </div>
                  )}
                  {lead.product && (
                    <div>
                      <p className="text-xs text-slate-400">Produto</p>
                      <p className="text-sm font-medium text-slate-800">{lead.product.name}</p>
                    </div>
                  )}
                  {lead.payment_method && (
                    <div>
                      <p className="text-xs text-slate-400">Pagamento</p>
                      <p className="text-sm font-medium text-slate-800">{lead.payment_method}</p>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          )}

          {/* Meetings */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="flex items-center gap-2">
                  <Calendar className="h-4 w-4 text-indigo-500" /> Reuniões
                </CardTitle>
                <Button size="sm" variant="outline" onClick={() => setShowMeeting(true)}>
                  <Plus className="h-3.5 w-3.5 mr-1" /> Agendar
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {meetings.length === 0 ? (
                <p className="text-sm text-slate-400">Nenhuma reunião agendada.</p>
              ) : (
                <div className="flex flex-col gap-3">
                  {upcomingMeetings.length > 0 && (
                    <div>
                      <p className="text-xs font-semibold text-slate-400 uppercase tracking-wide mb-2">Próximas</p>
                      {upcomingMeetings.map((m) => (
                        <MeetingRow
                          key={m.id}
                          meeting={m}
                          onDelete={() => deleteMeeting(m.id)}
                          onNotify={() => sendWhatsAppNotif(m)}
                          sending={sendingNotif === m.id}
                        />
                      ))}
                    </div>
                  )}
                  {pastMeetings.length > 0 && (
                    <div>
                      <p className="text-xs font-semibold text-slate-400 uppercase tracking-wide mb-2">Passadas</p>
                      {pastMeetings.map((m) => (
                        <MeetingRow
                          key={m.id}
                          meeting={m}
                          past
                          onDelete={() => deleteMeeting(m.id)}
                        />
                      ))}
                    </div>
                  )}
                </div>
              )}
            </CardContent>
          </Card>

          {lead.notes && (
            <Card>
              <CardHeader><CardTitle>Observações</CardTitle></CardHeader>
              <CardContent>
                <p className="text-sm text-slate-700 whitespace-pre-wrap">{lead.notes}</p>
              </CardContent>
            </Card>
          )}
        </div>

        {/* Right: Timeline */}
        <div>
          <Card>
            <CardHeader><CardTitle>Histórico de Interações</CardTitle></CardHeader>
            <CardContent>
              <Timeline
                leadId={id}
                interactions={interactions}
                onRefresh={fetchInteractions}
              />
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Edit Dialog */}
      <Dialog open={showEdit} onOpenChange={setShowEdit}>
        <DialogContent onClose={() => setShowEdit(false)}>
          <DialogHeader>
            <DialogTitle>Editar Lead</DialogTitle>
          </DialogHeader>
          <LeadForm
            lead={lead}
            onSuccess={() => { setShowEdit(false); fetchAll() }}
            onCancel={() => setShowEdit(false)}
          />
        </DialogContent>
      </Dialog>

      {/* Meeting Dialog */}
      <Dialog open={showMeeting} onOpenChange={setShowMeeting}>
        <DialogContent onClose={() => setShowMeeting(false)}>
          <DialogHeader>
            <DialogTitle>Agendar Reunião</DialogTitle>
          </DialogHeader>
          <MeetingForm
            leadId={id}
            onSuccess={() => { setShowMeeting(false); fetchMeetings() }}
            onCancel={() => setShowMeeting(false)}
          />
        </DialogContent>
      </Dialog>
    </div>
  )
}

interface MeetingRowProps {
  meeting: Meeting
  past?: boolean
  onDelete: () => void
  onNotify?: () => void
  sending?: boolean
}

function MeetingRow({ meeting, past, onDelete, onNotify, sending }: MeetingRowProps) {
  return (
    <div className={`flex items-center gap-3 p-3 rounded-lg border ${past ? "border-slate-100 bg-slate-50 opacity-60" : "border-indigo-100 bg-indigo-50"}`}>
      <Calendar className={`h-4 w-4 flex-shrink-0 ${past ? "text-slate-400" : "text-indigo-500"}`} />
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-slate-800 truncate">{meeting.title}</p>
        <p className="text-xs text-slate-500">
          {formatDate(meeting.date)} às {meeting.time.substring(0, 5)}
        </p>
      </div>
      <div className="flex items-center gap-1">
        {meeting.link && (
          <a href={meeting.link} target="_blank" rel="noopener noreferrer">
            <Button size="icon" variant="ghost" className="h-7 w-7">
              <ExternalLink className="h-3.5 w-3.5" />
            </Button>
          </a>
        )}
        {!past && onNotify && (
          <Button
            size="icon"
            variant="ghost"
            className={`h-7 w-7 ${meeting.notified ? "text-green-500" : "text-slate-400"}`}
            onClick={onNotify}
            disabled={sending}
            title="Enviar lembrete WhatsApp"
          >
            <Send className="h-3.5 w-3.5" />
          </Button>
        )}
        <Button size="icon" variant="ghost" className="h-7 w-7 text-red-400 hover:text-red-600" onClick={onDelete}>
          <Trash2 className="h-3.5 w-3.5" />
        </Button>
      </div>
    </div>
  )
}
