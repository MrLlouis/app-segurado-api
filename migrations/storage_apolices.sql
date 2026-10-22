-- Criação de bucket para armazenar apólices em PDF

INSERT INTO storage.buckets (id, name, public)
VALUES ('apolices', 'apolices', false)
ON CONFLICT (id) DO NOTHING;