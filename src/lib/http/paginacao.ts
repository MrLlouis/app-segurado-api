import { z } from 'zod';

/** ?pagina=1&limite=20 (máximo 50) — seção 6.1. */
export const paginacaoSchema = z.object({
  pagina: z.coerce.number().int().min(1).default(1),
  limite: z.coerce.number().int().min(1).max(50).default(20),
});

export type Paginacao = z.infer<typeof paginacaoSchema>;

export function lerPaginacao(url: URL) {
  return paginacaoSchema.safeParse({
    pagina: url.searchParams.get('pagina') ?? undefined,
    limite: url.searchParams.get('limite') ?? undefined,
  });
}

/** Faixa para o Supabase: .range(from, to) */
export function faixa({ pagina, limite }: Paginacao) {
  const from = (pagina - 1) * limite;
  return { from, to: from + limite - 1 };
}

/** Envelope de lista: { itens, pagina, limite, total } */
export function lista<T>(itens: T[], { pagina, limite }: Paginacao, total: number) {
  return { itens, pagina, limite, total };
}
