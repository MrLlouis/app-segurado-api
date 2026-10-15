// Executado uma vez quando o servidor sobe (não durante o build).
// Garante que a API não sobe com variável de ambiente faltando (Etapa 0).
export async function register() {
  if (process.env.NEXT_RUNTIME !== 'nodejs') return;
  const { getEnv } = await import('@/lib/env');
  try {
    getEnv();
  } catch (err) {
    console.error(err instanceof Error ? err.message : err);
    process.exit(1);
  }
}
