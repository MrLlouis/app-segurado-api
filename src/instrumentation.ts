// Executado uma vez quando o servidor sobe (não durante o build).
// O Next chama register() nos runtimes Node e Edge; a validação usa
// process.exit, que só existe no Node, por isso fica em arquivo separado.
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./instrumentation-node');
  }
}
