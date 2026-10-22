-- Etapa 1: tabelas da seção 5.3 da especificação, na ordem das dependências.
-- RLS ligado em todas, sem policy: só a service_role (usada pela API) enxerga os dados.

-- Sequência para os protocolos de sinistro
CREATE SEQUENCE IF NOT EXISTS public.sinistro_protocolo_seq START WITH 1 INCREMENT BY 1;

-- Valida o CPF pelos dois dígitos verificadores (rejeita também os 11 dígitos repetidos)
CREATE OR REPLACE FUNCTION public.cpf_valido(cpf TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
    soma INT;
    resto INT;
    i INT;
BEGIN
    IF cpf IS NULL OR cpf !~ '^[0-9]{11}$' OR cpf ~ '^(.)\1{10}$' THEN
        RETURN false;
    END IF;

    soma := 0;
    FOR i IN 1..9 LOOP
        soma := soma + substr(cpf, i, 1)::INT * (11 - i);
    END LOOP;
    resto := (soma * 10) % 11;
    IF resto = 10 THEN resto := 0; END IF;
    IF resto <> substr(cpf, 10, 1)::INT THEN
        RETURN false;
    END IF;

    soma := 0;
    FOR i IN 1..10 LOOP
        soma := soma + substr(cpf, i, 1)::INT * (12 - i);
    END LOOP;
    resto := (soma * 10) % 11;
    IF resto = 10 THEN resto := 0; END IF;
    RETURN resto = substr(cpf, 11, 1)::INT;
END;
$$;

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
    CONSTRAINT check_perfil_cpf_valido CHECK (public.cpf_valido(cpf)),
    CONSTRAINT check_perfil_papel CHECK (papel IN ('SEGURADO', 'ADMIN'))
);

ALTER TABLE public.perfil ENABLE ROW LEVEL SECURITY;

-- Tabela para armazenar informações sobre apólices de seguro

CREATE TABLE public.apolice (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    CONSTRAINT check_apolice_vigencia CHECK (fim_vigencia > inicio_vigencia),
    -- Formato PP-AAAA-NNNNNN, com o prefixo de acordo com o produto
    CONSTRAINT check_apolice_numero CHECK (
        numero ~ '^(AU|RE|VI|EM)-[0-9]{4}-[0-9]{6}$'
        AND left(numero, 2) = CASE produto
            WHEN 'AUTO' THEN 'AU'
            WHEN 'RESIDENCIAL' THEN 'RE'
            WHEN 'VIDA' THEN 'VI'
            WHEN 'EMPRESARIAL' THEN 'EM'
        END
    )
);

CREATE INDEX idx_apolice_perfil ON public.apolice (perfil_id);
CREATE INDEX idx_apolice_cpf_titular ON public.apolice (cpf_titular);

ALTER TABLE public.apolice ENABLE ROW LEVEL SECURITY;

-- Tabela para armazenar informações sobre contatos de assistência

CREATE TABLE public.contato_assistencia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    -- RESTRICT: um sinistro não some junto com a apólice
    apolice_id UUID NOT NULL REFERENCES public.apolice(id) ON DELETE RESTRICT,
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

CREATE INDEX idx_sinistro_perfil ON public.sinistro (perfil_id);
CREATE INDEX idx_sinistro_apolice ON public.sinistro (apolice_id);

ALTER TABLE public.sinistro ENABLE ROW LEVEL SECURITY;

-- Function & Trigger para gerar protocolo SIN-AAAA-NNNNNN
CREATE OR REPLACE FUNCTION public.gerar_protocolo_sinistro()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF NEW.protocolo IS NULL THEN
        NEW.protocolo := 'SIN-' || to_char(now() AT TIME ZONE 'America/Sao_Paulo', 'YYYY') || '-'
            || lpad(nextval('public.sinistro_protocolo_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_gerar_protocolo_sinistro
BEFORE INSERT ON public.sinistro
FOR EACH ROW
EXECUTE FUNCTION public.gerar_protocolo_sinistro();

-- A apólice do sinistro tem que pertencer ao mesmo perfil (seção 5.3)
CREATE OR REPLACE FUNCTION public.validar_apolice_do_sinistro()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.apolice
        WHERE id = NEW.apolice_id AND perfil_id = NEW.perfil_id
    ) THEN
        RAISE EXCEPTION 'A apólice % não pertence ao perfil %', NEW.apolice_id, NEW.perfil_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_validar_apolice_do_sinistro
BEFORE INSERT OR UPDATE OF apolice_id, perfil_id ON public.sinistro
FOR EACH ROW
EXECUTE FUNCTION public.validar_apolice_do_sinistro();

-- Mantém atualizado_em em dia a cada mudança do sinistro
CREATE OR REPLACE FUNCTION public.tocar_atualizado_em()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.atualizado_em := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_sinistro_atualizado_em
BEFORE UPDATE ON public.sinistro
FOR EACH ROW
EXECUTE FUNCTION public.tocar_atualizado_em();

-- Histórico de sinistros, com status e comentários

CREATE TABLE public.sinistro_evento (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sinistro_id UUID NOT NULL REFERENCES public.sinistro(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL,
    comentario TEXT,
    autor_id UUID REFERENCES public.perfil(id) ON DELETE SET NULL,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_sinistro_evento_status CHECK (status IN ('ABERTO', 'EM_ANALISE', 'CONCLUIDO'))
);

CREATE INDEX idx_sinistro_evento_sinistro ON public.sinistro_evento (sinistro_id, criado_em);

ALTER TABLE public.sinistro_evento ENABLE ROW LEVEL SECURITY;

-- Cotações de seguro, vinculadas a perfis, com dados em JSON e status de análise

CREATE TABLE public.cotacao (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

CREATE INDEX idx_cotacao_perfil ON public.cotacao (perfil_id);

ALTER TABLE public.cotacao ENABLE ROW LEVEL SECURITY;

-- Indicações de novos clientes, vinculadas a perfis existentes

CREATE TABLE public.indicacao (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    indicador_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    nome VARCHAR(120) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    email VARCHAR(160),
    status VARCHAR(20) NOT NULL DEFAULT 'NOVA',
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_indicacao_status CHECK (status IN ('NOVA', 'CONTATADA', 'CONVERTIDA'))
);

CREATE INDEX idx_indicacao_indicador ON public.indicacao (indicador_id);

ALTER TABLE public.indicacao ENABLE ROW LEVEL SECURITY;

-- Notificações, vinculadas a perfis, com tipos e destinos variados

CREATE TABLE public.notificacao (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    CONSTRAINT check_notificacao_destino_tipo CHECK (destino_tipo IS NULL OR destino_tipo IN ('SINISTRO', 'COTACAO', 'APOLICE')),
    CONSTRAINT check_notificacao_destino CHECK ((destino_tipo IS NULL) = (destino_id IS NULL))
);

CREATE INDEX idx_notificacao_perfil ON public.notificacao (perfil_id, criado_em DESC);
-- Fila do push: só as que ainda não foram enviadas
CREATE INDEX idx_notificacao_push_pendente ON public.notificacao (criado_em) WHERE push_enviado_em IS NULL;

ALTER TABLE public.notificacao ENABLE ROW LEVEL SECURITY;

-- Dispositivos móveis para envio de notificações push, vinculados a perfis

CREATE TABLE public.dispositivo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    perfil_id UUID NOT NULL REFERENCES public.perfil(id) ON DELETE CASCADE,
    push_token VARCHAR(255) NOT NULL UNIQUE,
    plataforma VARCHAR(10) NOT NULL,
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_dispositivo_plataforma CHECK (plataforma IN ('ANDROID', 'IOS'))
);

CREATE INDEX idx_dispositivo_perfil ON public.dispositivo (perfil_id);

ALTER TABLE public.dispositivo ENABLE ROW LEVEL SECURITY;
