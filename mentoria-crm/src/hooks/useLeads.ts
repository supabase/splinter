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
        .select(`
          *,
          stage:stages(*),
          source:sources(*),
          product:products(*),
          next_meeting:meetings(*)
        `)
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

      // Get next meeting for each lead (the closest future meeting)
      const leadsWithNextMeeting = (data || []).map((lead) => {
        const futureMeetings = (lead.next_meeting || [])
          .filter((m: { date: string }) => new Date(m.date) >= new Date())
          .sort((a: { date: string }, b: { date: string }) => new Date(a.date).getTime() - new Date(b.date).getTime())
        return { ...lead, next_meeting: futureMeetings[0] || null }
      })

      setLeads(leadsWithNextMeeting)
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
