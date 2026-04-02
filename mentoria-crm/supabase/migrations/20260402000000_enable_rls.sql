-- =============================================
-- Habilita Row-Level Security em todas as tabelas
-- Acesso total para usuários autenticados
-- Bloqueia acesso anônimo
-- =============================================

ALTER TABLE stages      ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads       ENABLE ROW LEVEL SECURITY;
ALTER TABLE products    ENABLE ROW LEVEL SECURITY;
ALTER TABLE sources     ENABLE ROW LEVEL SECURITY;
ALTER TABLE meetings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;

-- Stages
CREATE POLICY "authenticated_full_access" ON stages
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Leads
CREATE POLICY "authenticated_full_access" ON leads
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Products
CREATE POLICY "authenticated_full_access" ON products
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Sources
CREATE POLICY "authenticated_full_access" ON sources
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Meetings
CREATE POLICY "authenticated_full_access" ON meetings
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Interactions
CREATE POLICY "authenticated_full_access" ON interactions
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
