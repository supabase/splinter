"use client"

import { useState, useEffect } from "react"
import { supabase } from "@/lib/supabase"
import type { Stage } from "@/types"

export function useStages() {
  const [stages, setStages] = useState<Stage[]>([])
  const [loading, setLoading] = useState(true)

  const fetchStages = async () => {
    const { data } = await supabase
      .from("stages")
      .select("*")
      .order("order", { ascending: true })
    setStages(data || [])
    setLoading(false)
  }

  useEffect(() => {
    fetchStages()
  }, [])

  return { stages, loading, refetch: fetchStages }
}
