'use strict';

const { MOTIVO_NEGACAO } = require('./motivos');

/**
 * Texto curto (aparece na tela do próprio iDFace) pra cada motivo de
 * negativa — nunca expõe detalhe sensível (ex.: nunca diz "mensalidade
 * vencida há 12 dias", só "Acesso negado"), evitando qualquer trecho de
 * dado financeiro na tela do aparelho, que fica visível pra qualquer
 * pessoa por perto.
 * @param {string|null} motivo
 * @returns {string}
 */
function mensagemParaMotivo(motivo) {
  switch (motivo) {
    case MOTIVO_NEGACAO.STUDENT_NOT_FOUND:
    case MOTIVO_NEGACAO.INVALID_CREDENTIAL:
      return 'Cadastro não encontrado';
    case MOTIVO_NEGACAO.STUDENT_INACTIVE:
      return 'Matrícula inativa';
    case MOTIVO_NEGACAO.STUDENT_BLOCKED:
      return 'Acesso bloqueado';
    case MOTIVO_NEGACAO.PLAN_EXPIRED:
      return 'Plano expirado';
    case MOTIVO_NEGACAO.PAYMENT_OVERDUE:
      return 'Mensalidade em atraso';
    case MOTIVO_NEGACAO.OUTSIDE_ALLOWED_HOURS:
      return 'Fora do horário permitido';
    case MOTIVO_NEGACAO.UNIT_NOT_ALLOWED:
      return 'Acesso não permitido nesta unidade';
    case MOTIVO_NEGACAO.DEVICE_NOT_AUTHORIZED:
      return 'Dispositivo não autorizado';
    case MOTIVO_NEGACAO.RATE_LIMITED:
      return 'Aguarde um instante e tente novamente';
    case MOTIVO_NEGACAO.SYSTEM_ERROR:
      return 'Erro no sistema — tente novamente';
    default:
      return 'Acesso negado';
  }
}

module.exports = { mensagemParaMotivo };
