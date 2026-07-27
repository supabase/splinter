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
  ('Mentoria Individual 3 meses',  3000.00, 'Acompanhamento individual por 3 meses'),
  ('Mentoria Individual 6 meses',  5000.00, 'Acompanhamento individual por 6 meses'),
  ('Mentoria Individual 12 meses', 9000.00, 'Acompanhamento individual por 12 meses'),
  ('Sessão Avulsa',                 500.00, 'Sessão de mentoria avulsa');

-- Origens padrão
INSERT INTO sources (name) VALUES
  ('Instagram'),
  ('Indicação'),
  ('YouTube'),
  ('LinkedIn'),
  ('Evento ao Vivo'),
  ('Site');
