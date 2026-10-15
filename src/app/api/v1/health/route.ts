import { connection } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase/server';
import { ok, erro } from '@/lib/api-response';

// Antes da Etapa 1 a tabela `perfil` não existe. Esses códigos de erro
// significam "tabela não encontrada": provam que o banco respondeu.
const TABELA_INEXISTENTE = new Set(['PGRST205', '42P01']);

// GET /api/v1/health — pública; usada no healthcheck do contêiner (seção 6.2).
export async function GET() {
  // Health é sempre em tempo real: impede o Next de executar a rota no build.
  await connection();

  try {
    const { error } = await supabaseAdmin().from('perfil').select('id').limit(1);

    if (error && !TABELA_INEXISTENTE.has(error.code)) {
      console.error('[health] erro no banco:', error);
      return erro(503, 'INDISPONIVEL', 'Banco de dados indisponível');
    }

    return ok({ status: 'ok', banco: 'ok', timestamp: new Date().toISOString() });
  } catch (err) {
    console.error('[health]', err);
    return erro(503, 'INDISPONIVEL', 'Banco de dados indisponível');
  }
}
