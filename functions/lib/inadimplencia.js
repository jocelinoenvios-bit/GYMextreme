'use strict';

/**
 * Regra de negócio do ciclo de inadimplência/inatividade — 15 dias de
 * atraso (mensagem de retorno), 30 dias (inativação automática) e 45
 * dias de inatividade (segunda tentativa de contato). Porta fiel de
 * `lib/utils/status_operacional_aluno.dart` (Flutter) — os prazos
 * precisam ficar idênticos nos dois lados, mesma motivação de
 * `status-acesso.js`.
 *
 * Puro de propósito (sem Firestore/WhatsApp): dá pra testar a decisão
 * isolada, sem emulador nenhum — quem grava/envia de verdade é
 * `index.js` (`processarAutomacaoInadimplencia`), mesmo padrão já usado
 * por `processarNotificacaoMensalidade`/`status-acesso.js`.
 */

const { calcularStatusAcesso } = require('./status-acesso');

const DIAS_MENSAGEM_RETORNO = 15;
const DIAS_INATIVACAO = 30;
const DIAS_MENSAGEM_REATIVACAO = 45;

const UM_DIA_MS = 24 * 60 * 60 * 1000;

function semHorario(data) {
  return new Date(data.getFullYear(), data.getMonth(), data.getDate());
}

function diasEntre(inicio, fim) {
  return Math.round((semHorario(fim).getTime() - semHorario(inicio).getTime()) / UM_DIA_MS);
}

/**
 * Id determinístico do documento de auditoria em
 * `alunos/{uid}/mensagensWhatsapp/{id}` — chave natural de idempotência:
 * reexecutar a automação (retry, reprocessamento) sempre bate no mesmo
 * documento em vez de duplicar/reenviar. Reativar o aluno troca
 * `proximoVencimento`/gera uma `dataInativacao` nova no próximo ciclo, o
 * que automaticamente produz chaves diferentes — o evento antigo nunca é
 * reaproveitado (ver `AlunoService.reativarAluno`).
 *
 * @param {'mensagemRetorno15'|'mensagemReativacao45'} tipo
 * @param {Date} dataReferencia vencimento (mensagemRetorno15) ou
 *   dataInativacao (mensagemReativacao45)
 */
function idMensagemWhatsapp(tipo, dataReferencia) {
  const dia = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(
    dataReferencia,
  );
  return `${tipo}_${dia}`;
}

/**
 * Decide a PRÓXIMA ação do ciclo de inadimplência/inatividade de um
 * aluno — nunca decide duas ações no mesmo dia (os prazos 15/30/45 nunca
 * colidem), então quem chama só precisa agir sobre o resultado, sem
 * ficar checando "e se for os dois ao mesmo tempo".
 *
 * @param {{ativo: boolean, proximoVencimento: Date|null, dataInativacao: Date|null}} aluno
 * @param {Date} [agora]
 * @returns {
 *   {tipo: 'nenhuma'} |
 *   {tipo: 'mensagemRetorno15', vencimentoReferencia: Date} |
 *   {tipo: 'inativar'} |
 *   {tipo: 'mensagemReativacao45', dataInativacao: Date}
 * }
 */
function avaliarCicloInadimplencia(aluno, agora) {
  agora = agora || new Date();

  if (aluno.ativo === false) {
    // Já inativo — só resta checar os 45 dias de afastamento. Sem
    // `dataInativacao` (inativação manual de antes desta automação
    // existir, ou dado incompleto) nunca dispara: sem uma data de
    // referência não há como saber se já passaram 45 dias de verdade,
    // e nunca se deve assumir que sim.
    if (!aluno.dataInativacao) return { tipo: 'nenhuma' };

    const dias = diasEntre(aluno.dataInativacao, agora);
    if (dias >= DIAS_MENSAGEM_REATIVACAO) {
      return { tipo: 'mensagemReativacao45', dataInativacao: aluno.dataInativacao };
    }
    return { tipo: 'nenhuma' };
  }

  // Aluno ativo — segue o vencimento da mensalidade clássica
  // (`Aluno.proximoVencimento`), mesma fonte que já alimenta
  // `calcularStatusAcesso`/`enviarNotificacoesMensalidade`.
  const status = calcularStatusAcesso(aluno.proximoVencimento, agora);
  const diasAtraso = status.diasAtraso;
  if (diasAtraso == null) return { tipo: 'nenhuma' };

  // >= 30 sempre vence sobre >= 15: se a automação não rodou por alguns
  // dias (job atrasado, reprocessamento manual), inativar tem prioridade
  // — nunca manda a mensagem de "retorno" quando já devia estar inativo.
  if (diasAtraso >= DIAS_INATIVACAO) return { tipo: 'inativar' };
  if (diasAtraso >= DIAS_MENSAGEM_RETORNO) {
    return { tipo: 'mensagemRetorno15', vencimentoReferencia: aluno.proximoVencimento };
  }
  return { tipo: 'nenhuma' };
}

/**
 * Texto do template de WhatsApp pra cada tipo de mensagem — fonte única,
 * pra nunca ter o texto duplicado/dessincronizado entre quem monta o
 * registro de auditoria e quem (no futuro) chama a Cloud API de verdade.
 * @param {'mensagemRetorno15'|'mensagemReativacao45'} tipo
 * @param {string|null} nomeAluno
 */
function montarMensagemWhatsapp(tipo, nomeAluno) {
  const primeiroNome = (nomeAluno || '').trim().split(/\s+/)[0] || 'aluno';

  if (tipo === 'mensagemRetorno15') {
    return (
      `Olá, ${primeiroNome}! Sentimos sua falta na GYMEXTREME! 💪\n\n` +
      'Identificamos que sua mensalidade está em aberto.\n\n' +
      'Se quiser voltar aos treinos, fale conosco. Estamos esperando por você! 🏋️'
    );
  }

  return (
    `Olá, ${primeiroNome}! 👋\n\n` +
    'Já faz um tempo que você não treina com a gente.\n\n' +
    'Sentimos sua falta na GYMEXTREME! 💪\n\n' +
    'Se quiser voltar, entre em contato conosco. Podemos te ajudar a retomar seus treinos.'
  );
}

module.exports = {
  DIAS_MENSAGEM_RETORNO,
  DIAS_INATIVACAO,
  DIAS_MENSAGEM_REATIVACAO,
  idMensagemWhatsapp,
  avaliarCicloInadimplencia,
  montarMensagemWhatsapp,
};
