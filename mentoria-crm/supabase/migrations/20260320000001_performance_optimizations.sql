-- =============================================
-- Performance: índice composto + RPCs atômicas
-- =============================================

-- Índice composto para busca de próxima reunião (Fix #1)
CREATE INDEX IF NOT EXISTS idx_meetings_lead_date ON meetings(lead_id, date);

-- =============================================
-- RPC: criar lead + interação em transação única (Fix #2)
-- =============================================
CREATE OR REPLACE FUNCTION create_lead_with_interaction(
  p_name TEXT,
  p_phone TEXT,
  p_email TEXT,
  p_stage_id UUID,
  p_source_id UUID,
  p_product_id UUID,
  p_proposal_value NUMERIC,
  p_payment_method TEXT,
  p_notes TEXT,
  p_stage_name TEXT
) RETURNS UUID AS $$
DECLARE
  v_lead_id UUID;
BEGIN
  INSERT INTO leads (name, phone, email, stage_id, source_id, product_id, proposal_value, payment_method, notes)
  VALUES (p_name, p_phone, p_email, p_stage_id, p_source_id, p_product_id, p_proposal_value, p_payment_method, p_notes)
  RETURNING id INTO v_lead_id;

  INSERT INTO interactions (lead_id, type, content)
  VALUES (v_lead_id, 'stage_change', 'Lead criado em "' || p_stage_name || '"');

  RETURN v_lead_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- RPC: atualizar lead + interação de estágio em transação única (Fix #2)
-- =============================================
CREATE OR REPLACE FUNCTION update_lead_with_interaction(
  p_lead_id UUID,
  p_name TEXT,
  p_phone TEXT,
  p_email TEXT,
  p_stage_id UUID,
  p_source_id UUID,
  p_product_id UUID,
  p_proposal_value NUMERIC,
  p_payment_method TEXT,
  p_notes TEXT,
  p_old_stage_id UUID,
  p_new_stage_name TEXT
) RETURNS VOID AS $$
BEGIN
  UPDATE leads
  SET name = p_name,
      phone = p_phone,
      email = p_email,
      stage_id = p_stage_id,
      source_id = p_source_id,
      product_id = p_product_id,
      proposal_value = p_proposal_value,
      payment_method = p_payment_method,
      notes = p_notes
  WHERE id = p_lead_id;

  IF p_old_stage_id IS DISTINCT FROM p_stage_id THEN
    INSERT INTO interactions (lead_id, type, content)
    VALUES (p_lead_id, 'stage_change', 'Movido para "' || p_new_stage_name || '"');
  END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- RPC: criar reunião + interação em transação única (Fix #2)
-- =============================================
CREATE OR REPLACE FUNCTION create_meeting_with_interaction(
  p_lead_id UUID,
  p_title TEXT,
  p_date DATE,
  p_time TIME,
  p_link TEXT,
  p_formatted_date TEXT
) RETURNS VOID AS $$
BEGIN
  INSERT INTO meetings (lead_id, title, date, time, link)
  VALUES (p_lead_id, p_title, p_date, p_time, p_link);

  INSERT INTO interactions (lead_id, type, content)
  VALUES (p_lead_id, 'meeting', 'Reunião agendada: ' || p_title || ' — ' || p_formatted_date);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- RPC: mover lead de estágio (kanban drag) em transação única (Fix #2)
-- =============================================
CREATE OR REPLACE FUNCTION move_lead_stage(
  p_lead_id UUID,
  p_stage_id UUID,
  p_stage_name TEXT
) RETURNS VOID AS $$
BEGIN
  UPDATE leads SET stage_id = p_stage_id WHERE id = p_lead_id;

  INSERT INTO interactions (lead_id, type, content)
  VALUES (p_lead_id, 'stage_change', 'Movido para "' || p_stage_name || '"');
END;
$$ LANGUAGE plpgsql;
