-- =============================================
-- Habilita Row-Level Security em todas as tabelas
-- Acesso total para usuários autenticados
-- Bloqueia acesso anônimo
-- =============================================

-- IMPORTANTE: Execute isso APÓS ter criado seu usuário em
-- Authentication → Users no Supabase Dashboard.
-- Os dados existentes permanecem intactos — o RLS apenas
-- controla quem pode acessá-los.

ALTER TABLE stages       ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads        ENABLE ROW LEVEL SECURITY;
ALTER TABLE products     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sources      ENABLE ROW LEVEL SECURITY;
ALTER TABLE meetings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;

-- Acesso completo para usuários autenticados
CREATE POLICY "authenticated_full_access" ON stages
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access" ON leads
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access" ON products
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access" ON sources
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access" ON meetings
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access" ON interactions
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Garante que funções RPC sejam executáveis por usuários autenticados
GRANT EXECUTE ON FUNCTION create_lead_with_interaction TO authenticated;
GRANT EXECUTE ON FUNCTION update_lead_with_interaction TO authenticated;
GRANT EXECUTE ON FUNCTION create_meeting_with_interaction TO authenticated;
GRANT EXECUTE ON FUNCTION move_lead_stage TO authenticated;
