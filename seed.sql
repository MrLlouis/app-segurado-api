-- Teste de inserção de dados para o Supabase Auth e tabelas relacionadas

INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES 
('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@bsseguros.com.br', '$2a$10$w0/8/N0.k4zR5lqRjW2D3.8yK/Wf8Fq.eOaB/pE0.G3H4J5K6L7M8', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'maria.souza@email.com', '$2a$10$w0/8/N0.k4zR5lqRjW2D3.8yK/Wf8Fq.eOaB/pE0.G3H4J5K6L7M8', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'joao.silva@email.com', '$2a$10$w0/8/N0.k4zR5lqRjW2D3.8yK/Wf8Fq.eOaB/pE0.G3H4J5K6L7M8', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ana.oliveira@email.com', '$2a$10$w0/8/N0.k4zR5lqRjW2D3.8yK/Wf8Fq.eOaB/pE0.G3H4J5K6L7M8', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'carlos.pereira@email.com', '$2a$10$w0/8/N0.k4zR5lqRjW2D3.8yK/Wf8Fq.eOaB/pE0.G3H4J5K6L7M8', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
('66666666-6666-6666-6666-666666666666', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fernanda.costa@email.com', '$2a$10$w0/8/N0.k4zR5lqRjW2D3.8yK/Wf8Fq.eOaB/pE0.G3H4J5K6L7M8', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

-- Perfis de teste correspondentes aos usuários acima

INSERT INTO public.perfil (id, cpf, nome, telefone, data_nascimento, cliente_desde, papel, codigo_indicacao, aceita_marketing, termos_aceitos_em) VALUES
('11111111-1111-1111-1111-111111111111', '11122233344', 'Administrador BS', '81999990000', '1985-05-15', '2023-01-01', 'ADMIN', 'ADM001', true, now()),
('22222222-2222-2222-2222-222222222222', '52948220097', 'Maria Souza', '81988881111', '1992-06-20', '2023-06-01', 'SEGURADO', 'MARIA123', true, now()),
('33333333-3333-3333-3333-333333333333', '22334455566', 'João Silva', '81988882222', '1988-10-16', '2022-03-15', 'SEGURADO', 'JOAO456', true, now()), -- Aniversariante de hoje (16/Out)
('44444444-4444-4444-4444-444444444444', '33445566677', 'Ana Oliveira', '81988883333', '1995-12-10', '2024-01-10', 'SEGURADO', 'ANA789', false, now()),
('55555555-5555-5555-5555-555555555555', '44556677788', 'Carlos Pereira', '81988884444', '1980-04-05', '2021-11-20', 'SEGURADO', 'CARLOS101', true, now()),
('66666666-6666-6666-6666-666666666666', '55667788899', 'Fernanda Costa', '81988885555', '1998-08-25', '2026-10-01', 'SEGURADO', 'FERN202', true, now());

-- Inserção de apólices de teste para os perfis acima

INSERT INTO public.apolice (id, cpf_titular, perfil_id, numero, produto, status, inicio_vigencia, fim_vigencia, premio, pdf_caminho) VALUES
('6f1c1111-1111-1111-1111-111111111111', '52948220097', '22222222-2222-2222-2222-222222222222', 'AU-2026-000184', 'AUTO', 'ATIVA', '2026-10-01', '2027-10-01', 2400.00, 'exemplos/apolice_auto.pdf'),
('6f1c2222-2222-2222-2222-222222222222', '52948220097', '22222222-2222-2222-2222-222222222222', 'RE-2026-000052', 'RESIDENCIAL', 'ATIVA', '2026-05-01', '2027-05-01', 1200.00, 'exemplos/apolice_res.pdf'),
('6f1c3333-3333-3333-3333-333333333333', '22334455566', '33333333-3333-3333-3333-333333333333', 'VI-2026-000012', 'VIDA', 'ATIVA', '2025-10-15', '2026-10-15', 850.00, 'exemplos/apolice_vida.pdf'),
('6f1c4444-4444-4444-4444-444444444444', '33445566677', '44444444-4444-4444-4444-444444444444', 'EM-2026-000005', 'EMPRESARIAL', 'ATIVA', '2026-02-01', '2027-02-01', 5000.00, 'exemplos/apolice_emp.pdf'),
-- Apólice de CPF sem cadastro no sistema (para teste do vínculo no cadastro público)
('6f1c5555-5555-5555-5555-555555555555', '99887766554', NULL, 'AU-2026-000999', 'AUTO', 'ATIVA', '2026-01-01', '2027-01-01', 2100.00, 'exemplos/apolice_auto.pdf');

-- Contatos de assistência para os produtos de seguro

INSERT INTO public.contato_assistencia (tipo, produto, rotulo, telefone, whatsapp) VALUES
('ASSISTENCIA_24H', 'AUTO', 'Assistência 24h - Auto', '08007001000', '5581900000000'),
('ASSISTENCIA_24H', 'RESIDENCIAL', 'Assistência 24h - Residencial', '08007002000', '5581900000001'),
('ASSISTENCIA_24H', 'VIDA', 'Assistência 24h - Vida', '08007003000', '5581900000002'),
('ASSISTENCIA_24H', 'EMPRESARIAL', 'Assistência 24h - Empresarial', '08007004000', '5581900000003'),
('SINISTRO', NULL, 'Central de Atendimento de Sinistros', '08008009000', '5581911112222');

-- Histórico de sinistros para os perfis e apólices acima

INSERT INTO public.sinistro (id, perfil_id, apolice_id, protocolo, tipo, data_ocorrencia, local, descricao, status, criado_em) VALUES
('a7d21111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '6f1c1111-1111-1111-1111-111111111111', 'SIN-2026-000123', 'COLISAO', '2026-10-03 14:20:00-03', 'Av. Boa Viagem, Recife-PE', 'Colisão traseira no semáforo.', 'EM_ANALISE', '2026-10-03 14:25:00-03');

INSERT INTO public.sinistro_evento (sinistro_id, status, comentario, autor_id, criado_em) VALUES
('a7d21111-1111-1111-1111-111111111111', 'ABERTO', 'Sinistro aberto pelo aplicativo.', '22222222-2222-2222-2222-222222222222', '2026-10-03 14:25:00-03'),
('a7d21111-1111-1111-1111-111111111111', 'EM_ANALISE', 'Documentação recebida e encaminhada para perícia.', '11111111-1111-1111-1111-111111111111', '2026-10-04 09:00:00-03');

-- Cotação de seguro residencial

INSERT INTO public.cotacao (id, perfil_id, produto, motivo, dados, status, resposta, valor_estimado, criado_em, respondida_em) VALUES
('c31e1111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'RESIDENCIAL', 'NOVO', '{"tipo_imovel": "casa", "valor_edificacao": 350000}', 'RESPONDIDA', 'Plano básico a partir de R$ 39,90/mês.', 478.80, '2026-10-03 10:00:00-03', '2026-10-04 16:30:00-03');

-- Indicações de novos clientes

INSERT INTO public.indicacao (indicador_id, nome, telefone, email, status, criado_em) VALUES
('22222222-2222-2222-2222-222222222222', 'Lucas Mendes', '81999998888', 'lucas.mendes@email.com', 'NOVA', '2026-10-05 11:00:00-03');

-- Notificações de teste para os perfis acima

INSERT INTO public.notificacao (id, perfil_id, tipo, titulo, mensagem, destino_tipo, destino_id, lida_em, criado_em) VALUES
('9e441111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'SISTEMA', 'Seu sinistro mudou de status', 'SIN-2026-000123 está em análise.', 'SINISTRO', 'a7d21111-1111-1111-1111-111111111111', NULL, '2026-10-04 09:00:00-03'),
('9e442222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'ANIVERSARIO', 'Parabéns pelo seu aniversário!', 'A BS Seguros te deseja um feliz aniversário!', NULL, NULL, NULL, '2026-10-16 08:00:00-03');