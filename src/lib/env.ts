import { z } from 'zod';

// Nomes conforme a seção 8.2 da especificação.
// Sem NEXT_PUBLIC_: nenhuma chave do Supabase vai para o cliente (seção 2.2),
// e NEXT_PUBLIC_* é embutido no build, o que quebra o build do Docker sem .env.
const envSchema = z.object({
  SUPABASE_URL: z.url('SUPABASE_URL inválida'),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1, 'SUPABASE_SERVICE_ROLE_KEY é obrigatória'),
  SUPABASE_JWT_SECRET: z.string().optional(),
  CORS_ALLOWED_ORIGINS: z
    .string()
    .default('')
    .transform((v) => v.split(',').map((s) => s.trim()).filter(Boolean))
    .refine((list) => !list.includes('*'), 'CORS_ALLOWED_ORIGINS não aceita "*"'),
  COOKIE_SECURE: z
    .enum(['true', 'false'])
    .default('true')
    .transform((v) => v === 'true'),
  INTERNAL_API_KEY: z.string().optional(),
});

export type Env = z.infer<typeof envSchema>;

let cached: Env | null = null;

/**
 * Lê e valida o ambiente na primeira chamada (não no import).
 * Assim o `next build` não precisa do .env; a validação no start
 * fica em src/instrumentation.ts.
 */
export function getEnv(): Env {
  if (cached) return cached;
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    const detalhes = z.prettifyError(parsed.error);
    throw new Error(`Variáveis de ambiente inválidas ou ausentes:\n${detalhes}`);
  }
  cached = parsed.data;
  return cached;
}
