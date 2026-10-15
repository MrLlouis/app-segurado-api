import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { getEnv } from '@/lib/env';

const opcoes = {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
} as const;

let admin: SupabaseClient | null = null;

/**
 * Cliente com service_role, compartilhado. Usar para banco/Storage/auth.admin.
 * NUNCA chamar signInWithPassword nele (guardaria a sessão de um usuário no cliente compartilhado).
 */
export function supabaseAdmin(): SupabaseClient {
  if (!admin) {
    const env = getEnv();
    admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, opcoes);
  }
  return admin;
}

/** Cliente descartável, um por requisição, para login/refresh/logout. */
export function supabaseAuth(): SupabaseClient {
  const env = getEnv();
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, opcoes);
}
