-- Extensões necessárias para UUID e outras funcionalidades

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Sequência para os protocolos de sinistro
CREATE SEQUENCE IF NOT EXISTS sinistro_protocolo_seq START WITH 1 INCREMENT BY 1;

-- Tabelas do sistema de seguros
-- Tabela de perfis de usuários (clientes e administradores)

CREATE TABLE public.perfil (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    cpf VARCHAR(11) NOT NULL UNIQUE,
    nome VARCHAR(120) NOT NULL,
    telefone VARCHAR(20),
    data_nascimento DATE NOT NULL,
    cliente_desde DATE NOT NULL DEFAULT CURRENT_DATE,
    papel VARCHAR(20) NOT NULL DEFAULT 'SEGURADO',
    codigo_indicacao VARCHAR(12) NOT NULL UNIQUE,
    aceita_marketing BOOLEAN NOT NULL DEFAULT true,
    termos_aceitos_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_perfil_cpf_digits CHECK (cpf ~ '^[0-9]{11}$'),
    CONSTRAINT check_perfil_papel CHECK (papel IN ('SEGURADO', 'ADMIN'))
);

ALTER TABLE public.perfil ENABLE ROW LEVEL SECURITY;

-- Tabela para armazenar informações sobre apólices de seguro

CREATE TABLE public.apolice (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cpf_titular VARCHAR(11) NOT NULL,
    perfil_id UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
    numero VARCHAR(30) NOT NULL UNIQUE,
    produto VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ATIVA',
    inicio_vigencia DATE NOT NULL,
    fim_vigencia DATE NOT NULL,
    premio NUMERIC(12,2),
    pdf_caminho VARCHAR(255),
    CONSTRAINT check_apolice_cpf_digits CHECK (cpf_titular ~ '^[0-9]{11}$'),
    CONSTRAINT check_apolice_produto CHECK (produto IN ('AUTO', 'RESIDENCIAL', 'VIDA', 'EMPRESARIAL')),
    CONSTRAINT check_apolice_status CHECK (status IN ('ATIVA', 'VENCIDA', 'CANCELADA')),
    CONSTRAINT check_apolice_vigencia CHECK (fim_vigencia > inicio_vigencia)
);

ALTER TABLE public.apolice ENABLE ROW LEVEL SECURITY;

-- Tabela para armazenar informações sobre contatos de assistência

CREATE TABLE public.contato_assistencia (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo VARCHAR(20) NOT NULL,
    produto VARCHAR(30),
    rotulo VARCHAR(80) NOT NULL,
    telefone VARCHAR(20),
    whatsapp VARCHAR(20),
    ativo BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT check_contato_tipo CHECK (tipo IN ('ASSISTENCIA_24H', 'SINISTRO')),
    CONSTRAINT check_contato_produto CHECK (produto IS NULL OR produto IN ('AUTO', 'RESIDENCIAL', 'VIDA', 'EMPRESARIAL'))
);

ALTER TABLE public.contato_assistencia ENABLE ROW LEVEL SECURITY;

-- Tabela de sinistros, vinculando perfis e apólices, com histórico de eventos

CREATE TABLE public.sinistro (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    apolice_id UUID NOT NULL REFERENCES public.apolice(id) ON DELETE CASCADE,
    protocolo VARCHAR(20) UNIQUE,
    tipo VARCHAR(30) NOT NULL,
    data_ocorrencia TIMESTAMPTZ NOT NULL,
    local VARCHAR(200),
    descricao TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'ABERTO',
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_sinistro_tipo CHECK (tipo IN ('COLISAO', 'ROUBO', 'INCENDIO', 'DANO_ELETRICO', 'OUTROS')),
    CONSTRAINT check_sinistro_status CHECK (status IN ('ABERTO', 'EM_ANALISE', 'CONCLUIDO')),
    CONSTRAINT check_sinistro_data_ocorrencia CHECK (data_ocorrencia <= now())
);

-- Impede que um sinistro seja apagado acidentalmente se a apólice for removida
ALTER TABLE public.sinistro 
  DROP CONSTRAINT sinistro_apolice_id_fkey,
  ADD CONSTRAINT sinistro_apolice_id_fkey 
    FOREIGN KEY (apolice_id) 
    REFERENCES public.apolice(id) 
    ON DELETE RESTRICT;
    
ALTER TABLE public.sinistro ENABLE ROW LEVEL SECURITY;

-- Function & Trigger para gerar protocolo SIN-AAAA-NNNNNN
CREATE OR REPLACE FUNCTION public.gerar_protocolo_sinistro()
RETURNS TRIGGER AS $$
DECLARE
    ano VARCHAR(4);
    seq BIGINT;
BEGIN
    IF NEW.protocolo IS NULL THEN
        ano := TO_CHAR(now(), 'YYYY');
        seq := nextval('sinistro_protocolo_seq');
        NEW.protocolo := 'SIN-' || ano || '-' || LPAD(seq::text, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_gerar_protocolo_sinistro
BEFORE INSERT ON public.sinistro
FOR EACH ROW
EXECUTE FUNCTION public.gerar_protocolo_sinistro();

-- Tipo de evento para histórico de sinistros, com status e comentários

CREATE TABLE public.sinistro_evento (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sinistro_id UUID NOT NULL REFERENCES public.sinistro(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL,
    comentario TEXT,
    autor_id UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_sinistro_evento_status CHECK (status IN ('ABERTO', 'EM_ANALISE', 'CONCLUIDO'))
);

ALTER TABLE public.sinistro_evento ENABLE ROW LEVEL SECURITY;

-- Cotações de seguro, vinculadas a perfis, com dados em JSON e status de análise

CREATE TABLE public.cotacao (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    produto VARCHAR(30) NOT NULL,
    motivo VARCHAR(20) NOT NULL, -- Coluna adicional para indicar se é uma cotação nova ou renovação
    dados JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'RECEBIDA',
    resposta TEXT,
    valor_estimado NUMERIC(12,2),
    respondida_em TIMESTAMPTZ,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_cotacao_produto CHECK (produto IN ('AUTO', 'RESIDENCIAL', 'VIDA', 'EMPRESARIAL')),
    CONSTRAINT check_cotacao_motivo CHECK (motivo IN ('NOVO', 'RENOVACAO')),
    CONSTRAINT check_cotacao_status CHECK (status IN ('RECEBIDA', 'EM_ANALISE', 'RESPONDIDA'))
);

ALTER TABLE public.cotacao ENABLE ROW LEVEL SECURITY;

-- Tabela para registro de indicações de novos clientes, vinculadas a perfis existentes

CREATE TABLE public.indicacao (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    indicador_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    nome VARCHAR(120) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    email VARCHAR(160),
    status VARCHAR(20) NOT NULL DEFAULT 'NOVA',
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_indicacao_status CHECK (status IN ('NOVA', 'CONTATADA', 'CONVERTIDA'))
);

ALTER TABLE public.indicacao ENABLE ROW LEVEL SECURITY;

-- Tabela de notificações, vinculadas a perfis, com tipos e destinos variados

CREATE TABLE public.notificacao (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    tipo VARCHAR(20) NOT NULL,
    titulo VARCHAR(120) NOT NULL,
    mensagem TEXT NOT NULL,
    destino_tipo VARCHAR(20),
    destino_id UUID,
    lida_em TIMESTAMPTZ,
    push_enviado_em TIMESTAMPTZ,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_notificacao_tipo CHECK (tipo IN ('MARKETING', 'ANIVERSARIO', 'SISTEMA')),
    CONSTRAINT check_notificacao_destino_tipo CHECK (destino_tipo IS NULL OR destino_tipo IN ('SINISTRO', 'COTACAO', 'APOLICE'))
);

ALTER TABLE public.notificacao ENABLE ROW LEVEL SECURITY;

-- Tabela de armazenamento de dispositivos móveis para envio de notificações push, vinculados a perfis

CREATE TABLE public.dispositivo (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    push_token VARCHAR(255) NOT NULL UNIQUE,
    plataforma VARCHAR(10) NOT NULL,
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_dispositivo_plataforma CHECK (plataforma IN ('ANDROID', 'IOS'))
);

ALTER TABLE public.dispositivo ENABLE ROW LEVEL SECURITY;