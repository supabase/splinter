"use client"

import { useState, useEffect, useCallback } from "react"
import { supabase } from "@/lib/supabase"
import type { Lead } from "@/types"

export function useLeads(filters?: { stageId?: string; sourceId?: string; search?: string }) {
  const [leads, setLeads] = useState<Lead[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchLeads = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      let query = supabase
        .from("leads")
        .select(`*, stage:stages(*), source:sources(*), product:products(*)`)
        .order("created_at", { ascending: false })

      if (filters?.stageId) query = query.eq("stage_id", filters.stageId)
      if (filters?.sourceId) query = query.eq("source_id", filters.sourceId)
      if (filters?.search) {
        query = query.or(
          `name.ilike.%${filters.search}%,phone.ilike.%${filters.search}%,email.ilike.%${filters.search}%`
        )
      }

      const { data, error } = await query
      if (error) throw error

      const leads = data || []

      if (leads.length === 0) {
        setLeads([])
        return
      }

      // Busca somente reuniões futuras em uma única query indexada
      const today = new Date().toISOString().split("T")[0]
      const { data: meetings, error: meetingsError } = await supabase
        .from("meetings")
        .select("*")
        .in("lead_id", leads.map((l) => l.id))
        .gte("date", today)
        .order("date", { ascending: true })
        .order("time", { ascending: true })

      if (meetingsError) throw meetingsError

      // Monta mapa lead_id → próxima reunião (já ordenado por date+time)
      const nextMeetingMap = new Map<string, Meeting>()
      for (const m of (meetings || [])) {
        if (!nextMeetingMap.has(m.lead_id)) nextMeetingMap.set(m.lead_id, m)
      }

      setLeads(leads.map((lead) => ({ ...lead, next_meeting: nextMeetingMap.get(lead.id) ?? null })))
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao carregar leads")
    } finally {
      setLoading(false)
    }
  }, [filters?.stageId, filters?.sourceId, filters?.search])

  useEffect(() => {
    fetchLeads()
  }, [fetchLeads])

  return { leads, loading, error, refetch: fetchLeads }
}
