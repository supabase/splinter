-- =============================================
-- CRM Mentoria - Seed
-- =============================================

-- Estágios padrão
INSERT INTO stages (name, color, "order", type) VALUES
  ('Primeiro Contato',      '#3b82f6', 1, 'normal'),
  ('Sessão de Diagnóstico', '#eab308', 2, 'normal'),
  ('Criação de Proposta',   '#f97316', 3, 'normal'),
  ('Proposta Enviada',      '#a855f7', 4, 'normal'),
  ('Fechado',               '#22c55e', 5, 'won'),
  ('Não Fechado',           '#6b7280', 6, 'lost');

-- Produtos padrão
INSERT INTO products (name, price, description) VALUES
  ('Sessão Única',  600.00, 'Sessão individual de mentoria'),
  ('Travessia',    2000.00, 'Pacote com 4 sessões de mentoria');

-- Origens padrão
INSERT INTO sources (name) VALUES
  ('Instagram'),
  ('Indicação'),
  ('YouTube'),
  ('LinkedIn'),
  ('Evento ao Vivo'),
  ('Site');
