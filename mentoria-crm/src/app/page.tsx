"use client"

export const dynamic = "force-dynamic"

import { useEffect, useState } from "react"
import Link from "next/link"
import {
  Users, TrendingUp, DollarSign, Target, Calendar, ArrowRight, CheckCircle
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { formatCurrency } from "@/lib/utils"
import type { Stage, Lead, Meeting } from "@/types"

interface Metrics {
  totalLeads: number
  totalProposalValue: number
  conversionRate: number
  wonCount: number
  leadsByStage: { stage: Stage; count: number; value: number }[]
  upcomingMeetings: (Meeting & { lead: { name: string } })[]
}

export default function DashboardPage() {
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      const [{ data: stages }, { data: leads }, { data: meetings }] = await Promise.all([
        supabase.from("stages").select("*").order("order"),
        supabase.from("leads").select("*, stage:stages(*)"),
        supabase
          .from("meetings")
          .select("*, lead:leads(name)")
          .gte("date", new Date().toISOString().split("T")[0])
          .order("date")
          .limit(10),
      ])

      if (!stages || !leads) { setLoading(false); return }

      const leadsByStage = stages.map((stage) => {
        const stageLeads = leads.filter((l) => l.stage_id === stage.id)
        return {
          stage: stage as Stage,
          count: stageLeads.length,
          value: stageLeads.reduce((s: number, l: Lead) => s + (l.proposal_value || 0), 0),
        }
      })

      const wonStage = stages.find((s: Stage) => s.type === "won")
      const wonCount = wonStage ? leads.filter((l: Lead) => l.stage_id === wonStage.id).length : 0
      const totalLeads = leads.length
      const totalProposalValue = leads.reduce((s: number, l: Lead) => s + (l.proposal_value || 0), 0)

      setMetrics({
        totalLeads,
        totalProposalValue,
        conversionRate: totalLeads > 0 ? Math.round((wonCount / totalLeads) * 100) : 0,
        wonCount,
        leadsByStage,
        upcomingMeetings: (meetings || []) as (Meeting & { lead: { name: string } })[],
      })
      setLoading(false)
    }
    load()
  }, [])

  if (loading) {
    return <div className="flex items-center justify-center h-64 text-slate-400">Carregando dashboard...</div>
  }

  if (!metrics) return null

  const maxCount = Math.max(...metrics.leadsByStage.map((s) => s.count), 1)

  return (
    <div className="max-w-6xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">Dashboard</h1>
        <p className="text-sm text-slate-500 mt-0.5">Visão geral do seu pipeline de mentoria</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-4 gap-4 mb-6">
        <KPICard
          label="Total de Leads"
          value={metrics.totalLeads.toString()}
          icon={<Users className="h-5 w-5" />}
          color="indigo"
        />
        <KPICard
          label="Valor em Proposta"
          value={formatCurrency(metrics.totalProposalValue)}
          icon={<DollarSign className="h-5 w-5" />}
          color="emerald"
        />
        <KPICard
          label="Taxa de Conversão"
          value={`${metrics.conversionRate}%`}
          icon={<TrendingUp className="h-5 w-5" />}
          color="violet"
        />
        <KPICard
          label="Leads Fechados"
          value={metrics.wonCount.toString()}
          icon={<CheckCircle className="h-5 w-5" />}
          color="green"
        />
      </div>

      <div className="grid grid-cols-3 gap-6">
        {/* Pipeline by stage */}
        <div className="col-span-2">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Target className="h-4 w-4 text-indigo-500" />
                Leads por Estágio
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex flex-col gap-3">
                {metrics.leadsByStage.map(({ stage, count, value }) => (
                  <div key={stage.id}>
                    <div className="flex items-center justify-between mb-1.5">
                      <div className="flex items-center gap-2">
                        <span className="h-2 w-2 rounded-full flex-shrink-0" style={{ backgroundColor: stage.color }} />
                        <span className="text-sm text-slate-700">{stage.name}</span>
                        <span className="text-xs text-slate-400">({count})</span>
                      </div>
                      {value > 0 && (
                        <span className="text-xs font-semibold text-emerald-600">{formatCurrency(value)}</span>
                      )}
                    </div>
                    <div className="h-2 bg-slate-100 rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all duration-500"
                        style={{
                          width: `${(count / maxCount) * 100}%`,
                          backgroundColor: stage.color,
                        }}
                      />
                    </div>
                  </div>
                ))}
              </div>
              <div className="mt-4 pt-4 border-t border-slate-100">
                <Link href="/kanban" className="flex items-center gap-1.5 text-sm text-indigo-600 hover:text-indigo-800 font-medium transition-colors">
                  Ver kanban completo <ArrowRight className="h-3.5 w-3.5" />
                </Link>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Upcoming meetings */}
        <div>
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Calendar className="h-4 w-4 text-indigo-500" />
                Próximas Reuniões
              </CardTitle>
            </CardHeader>
            <CardContent>
              {metrics.upcomingMeetings.length === 0 ? (
                <p className="text-sm text-slate-400 text-center py-6">Nenhuma reunião nos próximos dias</p>
              ) : (
                <div className="flex flex-col gap-3">
                  {metrics.upcomingMeetings.map((m) => (
                    <div key={m.id} className="flex gap-3">
                      <div className="flex flex-col items-center text-center w-10 flex-shrink-0">
                        <span className="text-xs font-bold text-indigo-600 uppercase leading-none">
                          {new Date(m.date + "T00:00:00").toLocaleDateString("pt-BR", { month: "short" })}
                        </span>
                        <span className="text-lg font-black text-slate-800 leading-none">
                          {new Date(m.date + "T00:00:00").getDate()}
                        </span>
                      </div>
                      <div className="flex-1 min-w-0 border-l border-slate-100 pl-3">
                        <p className="text-sm font-medium text-slate-800 truncate">{m.title}</p>
                        <p className="text-xs text-slate-500 truncate">{m.lead?.name}</p>
                        <p className="text-xs text-indigo-500 font-medium">{m.time.substring(0, 5)}</p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
              <div className="mt-4 pt-4 border-t border-slate-100">
                <Link href="/leads" className="flex items-center gap-1.5 text-sm text-indigo-600 hover:text-indigo-800 font-medium transition-colors">
                  Ver todos os leads <ArrowRight className="h-3.5 w-3.5" />
                </Link>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}

interface KPICardProps {
  label: string
  value: string
  icon: React.ReactNode
  color: "indigo" | "emerald" | "violet" | "green"
}

const colorMap = {
  indigo: { bg: "bg-indigo-50", text: "text-indigo-600", icon: "bg-indigo-100 text-indigo-600" },
  emerald: { bg: "bg-emerald-50", text: "text-emerald-700", icon: "bg-emerald-100 text-emerald-600" },
  violet: { bg: "bg-violet-50", text: "text-violet-700", icon: "bg-violet-100 text-violet-600" },
  green: { bg: "bg-green-50", text: "text-green-700", icon: "bg-green-100 text-green-600" },
}

function KPICard({ label, value, icon, color }: KPICardProps) {
  const c = colorMap[color]
  return (
    <div className={`rounded-xl p-4 ${c.bg} border border-white`}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs text-slate-500 font-medium mb-1">{label}</p>
          <p className={`text-2xl font-black ${c.text}`}>{value}</p>
        </div>
        <div className={`h-9 w-9 rounded-lg flex items-center justify-center ${c.icon}`}>
          {icon}
        </div>
      </div>
    </div>
  )
}
