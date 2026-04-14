export type MentoradoStatus = 'active' | 'completed' | 'paused'
export type MaterialType = 'pdf' | 'video' | 'template' | 'link'
export type TarefaStatus = 'pending' | 'in_progress' | 'done'

export interface Mentorado {
  id: string
  user_id: string | null
  lead_id: string | null
  name: string
  email: string
  product_name: string
  start_date: string | null
  end_date: string | null
  status: MentoradoStatus
  notes: string | null
  created_at: string
}

export interface Material {
  id: string
  title: string
  description: string | null
  type: MaterialType
  url: string
  thumbnail_url: string | null
  is_global: boolean
  created_at: string
}

export interface MentoradoMaterial {
  id: string
  mentorado_id: string
  material_id: string
  unlocked_at: string
  seen_at: string | null
  material?: Material
}

export interface Tarefa {
  id: string
  mentorado_id: string
  title: string
  description: string | null
  due_date: string | null
  status: TarefaStatus
  created_by_mentor: boolean
  completed_at: string | null
  created_at: string
}

export interface Sessao {
  id: string
  mentorado_id: string
  date: string
  duration_min: number
  summary: string | null
  decisions: string | null
  next_steps: string | null
  created_at: string
}

export interface Competencia {
  id: string
  name: string
  description: string | null
  order: number
}

export interface AvaliacaoCompetencia {
  id: string
  mentorado_id: string
  competencia_id: string
  score: number
  notes: string | null
  assessed_at: string
  competencia?: Competencia
}
