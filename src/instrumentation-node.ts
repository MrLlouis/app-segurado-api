import { getEnv } from '@/lib/env';

// A API não sobe com variável de ambiente faltando (Etapa 0).
try {
  getEnv();
} catch (err) {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
}
