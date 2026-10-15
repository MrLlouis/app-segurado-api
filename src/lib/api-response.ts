import { NextResponse } from 'next/server';
import type { z } from 'zod';

/** Códigos de erro da seção 6.12 da especificação. */
export type CodigoErro =
  | 'VALIDACAO'
  | 'NAO_AUTENTICADO'
  | 'SEM_PERMISSAO'
  | 'NAO_ENCONTRADO'
  | 'CONFLITO'
  | 'LIMITE_EXCEDIDO'
  | 'INDISPONIVEL'
  | 'ERRO_INTERNO';

/** Resposta de sucesso: o corpo é o próprio dado, sem envelope (ver exemplos do PLANO 2.1). */
export function ok<T>(data: T, status = 200, init?: { headers?: HeadersInit }) {
  return NextResponse.json(data, { status, headers: init?.headers });
}

/** Erro no formato da seção 6.12: { status, erro, mensagem, campos? } */
export function erro(
  status: number,
  codigo: CodigoErro,
  mensagem: string,
  opts?: { campos?: Record<string, string>; headers?: HeadersInit },
) {
  return NextResponse.json(
    { status, erro: codigo, mensagem, ...(opts?.campos ? { campos: opts.campos } : {}) },
    { status, headers: opts?.headers },
  );
}

/** Converte um ZodError em 400 VALIDACAO com o mapa `campos`. */
export function erroValidacao(error: z.ZodError) {
  const campos: Record<string, string> = {};
  for (const issue of error.issues) {
    const chave = issue.path.join('.') || '_';
    campos[chave] ??= issue.message;
  }
  const primeira = error.issues[0];
  const mensagem = primeira
    ? `${primeira.path.join('.') || 'entrada'} inválido`
    : 'entrada inválida';
  return erro(400, 'VALIDACAO', mensagem, { campos });
}
