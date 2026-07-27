-- =============================================
-- Member Portal — Portal do Mentorado
-- =============================================

-- Mentorados (clientes ativos que têm acesso ao portal)
CREATE TABLE mentorados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  product_name TEXT NOT NULL DEFAULT '',
  start_date DATE,
  end_date DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mentorados_user_id ON mentorados(user_id);
CREATE INDEX idx_mentorados_lead_id ON mentorados(lead_id);
CREATE INDEX idx_mentorados_status ON mentorados(status);

-- Materiais (conteúdo compartilhado pelo mentor)
CREATE TABLE materiais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL DEFAULT 'link' CHECK (type IN ('pdf', 'video', 'template', 'link')),
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  is_global BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pivot: materiais atribuídos por mentorado
CREATE TABLE mentorado_materiais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentorado_id UUID NOT NULL REFERENCES mentorados(id) ON DELETE CASCADE,
  material_id UUID NOT NULL REFERENCES materiais(id) ON DELETE CASCADE,
  unlocked_at TIMESTAMPTZ DEFAULT NOW(),
  seen_at TIMESTAMPTZ,
  UNIQUE(mentorado_id, material_id)
);

CREATE INDEX idx_mentorado_materiais_mentorado ON mentorado_materiais(mentorado_id);
CREATE INDEX idx_mentorado_materiais_material ON mentorado_materiais(material_id);

-- Tarefas atribuídas ao mentorado
CREATE TABLE tarefas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentorado_id UUID NOT NULL REFERENCES mentorados(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'done')),
  created_by_mentor BOOLEAN NOT NULL DEFAULT TRUE,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tarefas_mentorado ON tarefas(mentorado_id);
CREATE INDEX idx_tarefas_status ON tarefas(status);
CREATE INDEX idx_tarefas_due_date ON tarefas(due_date);

-- Sessões de mentoria
CREATE TABLE sessoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentorado_id UUID NOT NULL REFERENCES mentorados(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  duration_min INT NOT NULL DEFAULT 60,
  summary TEXT,
  decisions TEXT,
  next_steps TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sessoes_mentorado ON sessoes(mentorado_id);
CREATE INDEX idx_sessoes_date ON sessoes(date DESC);

-- Competências (pré-definidas)
CREATE TABLE competencias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  "order" INT NOT NULL DEFAULT 0
);

-- Auto-avaliações de competência
CREATE TABLE avaliacoes_competencia (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentorado_id UUID NOT NULL REFERENCES mentorados(id) ON DELETE CASCADE,
  competencia_id UUID NOT NULL REFERENCES competencias(id) ON DELETE CASCADE,
  score INT NOT NULL CHECK (score BETWEEN 1 AND 10),
  notes TEXT,
  assessed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_avaliacoes_mentorado ON avaliacoes_competencia(mentorado_id);
CREATE INDEX idx_avaliacoes_competencia ON avaliacoes_competencia(competencia_id);
CREATE INDEX idx_avaliacoes_assessed_at ON avaliacoes_competencia(assessed_at DESC);

-- =============================================
-- RLS Policies
-- =============================================

ALTER TABLE mentorados ENABLE ROW LEVEL SECURITY;
ALTER TABLE materiais ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentorado_materiais ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarefas ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE competencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE avaliacoes_competencia ENABLE ROW LEVEL SECURITY;

-- mentorados: cada mentorado vê/edita apenas o próprio registro
CREATE POLICY mentorado_self_select ON mentorados
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY mentorado_self_update ON mentorados
  FOR UPDATE USING (user_id = auth.uid());

-- Helper: retorna o mentorado_id do usuário autenticado
CREATE OR REPLACE FUNCTION get_mentorado_id()
RETURNS UUID LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT id FROM mentorados WHERE user_id = auth.uid() LIMIT 1;
$$;

-- tarefas: mentorado vê suas próprias tarefas
CREATE POLICY tarefas_select ON tarefas
  FOR SELECT USING (mentorado_id = get_mentorado_id());

CREATE POLICY tarefas_update ON tarefas
  FOR UPDATE USING (mentorado_id = get_mentorado_id());

-- sessoes: mentorado vê suas próprias sessões
CREATE POLICY sessoes_select ON sessoes
  FOR SELECT USING (mentorado_id = get_mentorado_id());

-- competencias: leitura pública autenticada
CREATE POLICY competencias_select ON competencias
  FOR SELECT USING (auth.role() = 'authenticated');

-- materiais: leitura de materiais globais ou atribuídos ao mentorado
CREATE POLICY materiais_select ON materiais
  FOR SELECT USING (
    is_global = TRUE
    OR id IN (
      SELECT material_id FROM mentorado_materiais
      WHERE mentorado_id = get_mentorado_id()
    )
  );

-- mentorado_materiais: mentorado vê seus próprios
CREATE POLICY mentorado_materiais_select ON mentorado_materiais
  FOR SELECT USING (mentorado_id = get_mentorado_id());

CREATE POLICY mentorado_materiais_update ON mentorado_materiais
  FOR UPDATE USING (mentorado_id = get_mentorado_id());

-- avaliacoes: mentorado gerencia as próprias
CREATE POLICY avaliacoes_select ON avaliacoes_competencia
  FOR SELECT USING (mentorado_id = get_mentorado_id());

CREATE POLICY avaliacoes_insert ON avaliacoes_competencia
  FOR INSERT WITH CHECK (mentorado_id = get_mentorado_id());

CREATE POLICY avaliacoes_update ON avaliacoes_competencia
  FOR UPDATE USING (mentorado_id = get_mentorado_id());

-- =============================================
-- Seed: Competências
-- =============================================

INSERT INTO competencias (name, description, "order") VALUES
  ('Clareza de decisão',          'Capacidade de decidir com critérios explícitos, sem procrastinar', 1),
  ('Autoconhecimento profissional','Saber o que quer, o que evita e o que te energiza', 2),
  ('Comunicação estratégica',     'Capacidade de se posicionar e contar sua história', 3),
  ('Gestão de carreira',          'Ter um plano e agir conforme ele', 4),
  ('Autonomia',                   'Decidir e agir sem depender de validação constante', 5),
  ('Execução',                    'Transformar decisões em ações concretas', 6),
  ('Posicionamento no mercado',   'Ser reconhecido pelo que faz e pelo que vale', 7),
  ('Liderança',                   'Influenciar, alinhar e desenvolver pessoas', 8);
