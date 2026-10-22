-- Proteção em caso de exclusão acidental de registros importantes

-- Função que impede exclusão de mais de 1 registro por vez via instrução simples sem auditoria
CREATE OR REPLACE FUNCTION public.prevenir_delete_em_massa()
RETURNS TRIGGER AS $$
BEGIN
    -- Caso a query tentar deletar múltiplos registros de uma só vez de forma não intencional
    IF (SELECT count(*) FROM old_table) > 1 THEN
        RAISE EXCEPTION 'Ação bloqueada: Exclusão em massa não permitida diretamente nesta tabela. Remova um registro por vez ou altere a flag de segurança.';
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Aplicando trava na tabela 'perfil' e 'apolice' para evitar acidentes com ON DELETE CASCADE
CREATE TRIGGER travar_delete_massa_perfil
    AFTER DELETE ON public.perfil
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.prevenir_delete_em_massa();

CREATE TRIGGER travar_delete_massa_apolice
    AFTER DELETE ON public.apolice
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.prevenir_delete_em_massa();

-- Implementação de Soft Delete por questões de segurança e auditorias futuras

ALTER TABLE public.perfil ADD COLUMN deletado_em TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.apolice ADD COLUMN deletado_em TIMESTAMPTZ DEFAULT NULL;

-- Trigger para transformar DELETE físico em Soft Delete automático
CREATE OR REPLACE FUNCTION public.executar_soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.perfil
    SET deletado_em = now()
    WHERE id = OLD.id;
    
    -- Cancela o DELETE físico real
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_soft_delete_perfil
    BEFORE DELETE ON public.perfil
    FOR EACH ROW
    EXECUTE FUNCTION public.executar_soft_delete();