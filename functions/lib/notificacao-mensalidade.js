'use strict';

/**
 * Monta o registro que fica salvo em
 * `alunos/{uid}/notificacoesMensalidade/{idNotificacaoDoDia}` — auditoria
 * de toda notificação de mensalidade gerada pelo job diário, mesmo quando
 * não há token pra mandar o push de verdade (`erro: 'sem_token_fcm'`).
 *
 * Puro (sem Firestore/Messaging) de propósito, mesma motivação de
 * `status-acesso.js`: dá pra testar sem emulador nenhum.
 *
 * @param {{status: string, diasParaVencimento?: number, diasAtraso?: number, diasToleranciaRestantes?: number}} status
 * @param {string} mensagem
 * @param {number} tokensAlvo quantidade de tokens FCM do aluno (0 = ninguém pra notificar ainda)
 */
function construirRegistroNotificacao(status, mensagem, tokensAlvo) {
  return {
    mensagem,
    status: status.status,
    diasParaVencimento: status.diasParaVencimento ?? null,
    diasAtraso: status.diasAtraso ?? null,
    diasToleranciaRestantes: status.diasToleranciaRestantes ?? null,
    canal: 'push',
    tokensAlvo,
    enviada: false,
    erro: tokensAlvo === 0 ? 'sem_token_fcm' : null,
  };
}

/**
 * Id do documento diário de notificação, no fuso de São Paulo
 * (`AAAA-MM-DD`) — chave natural que torna o job idempotente: reexecutar
 * no mesmo dia (retry do agendador, reprocessamento manual) sobrescreve o
 * mesmo documento em vez de duplicar o registro ou reenviar o push.
 * @param {Date} [data]
 */
function idNotificacaoDoDia(data) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(
    data ?? new Date(),
  );
}

module.exports = { construirRegistroNotificacao, idNotificacaoDoDia };
