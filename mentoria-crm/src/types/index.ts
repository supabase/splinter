export type StageType = "normal" | "won" | "lost"

export interface Stage {
  id: string
  name: string
  color: string
  order: number
  type: StageType
  created_at: string
}

export interface Product {
  id: string
  name: string
  price: number | null
  description: string | null
  active: boolean
  created_at: string
}

export interface Source {
  id: string
  name: string
  created_at: string
}

export interface Lead {
  id: string
  name: string
  phone: string
  email: string | null
  stage_id: string
  source_id: string | null
  product_id: string | null
  proposal_value: number | null
  payment_method: string | null
  notes: string | null
  created_at: string
  updated_at: string
  stage?: Stage
  source?: Source
  product?: Product
  next_meeting?: Meeting | null
}

export interface Meeting {
  id: string
  lead_id: string
  title: string
  date: string
  time: string
  link: string | null
  notified: boolean
  created_at: string
  lead?: Lead
}

export type InteractionType = "note" | "stage_change" | "meeting" | "proposal"

export interface Interaction {
  id: string
  lead_id: string
  type: InteractionType
  content: string
  created_at: string
}

export interface DashboardMetrics {
  totalLeads: number
  leadsByStage: { stage: Stage; count: number; value: number }[]
  totalProposalValue: number
  conversionRate: number
  upcomingMeetings: (Meeting & { lead: Lead })[]
}
