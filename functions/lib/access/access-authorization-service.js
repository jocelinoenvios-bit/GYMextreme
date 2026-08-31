'use strict';

const { calcularStatusAcesso } = require('../status-acesso');
const { MOTIVO_NEGACAO, RESULTADO } = require('./motivos');

function negar(motivo) {
  return { resultado: RESULTADO.DENY, motivo };
}

const PERMITIR = Object.freeze({ resultado: RESULTADO.ALLOW, motivo: null });

/**
 * `AccessAuthorizationService` — decide se um aluno pode acessar a
 * academia agora. Pura, sem nenhuma leitura de Firestore aqui dentro:
 * quem chama (o endpoint do iDFace, ou futuramente qualquer outro leitor
 * — QR, NFC, catraca de outro fabricante) já resolveu os documentos e
 * entrega prontos. Nunca conhece o formato de nenhum fabricante de
 * hardware — só regras de negócio do Gym Xtreme.
 *
 * Ordem das checagens segue a lista do briefing (aluno → plano →
 * financeiro → horário → unidade) — a primeira que falhar já decide,
 * sem checar o resto.
 *
 * Horário de acesso: AINDA NÃO EXISTE nenhuma tela/config de restrição
 * de horário no app (nem por aluno, nem por plano) — então essa
 * checagem é, por enquanto, sempre "sem restrição" (nunca bloqueia). O
 * dia em que essa configuração existir, a lógica entra aqui, sem mudar
 * a assinatura da função.
 *
 * @param {{
 *   aluno: (Record<string, unknown> & {
 *     ativo?: boolean,
 *     bloqueado?: boolean,
 *     proximoVencimento?: {toDate: () => Date} | null,
 *     unidadeId?: string | null,
 *   }) | null,
 *   matriculaAtiva: (Record<string, unknown> & {
 *     dataVencimento?: {toDate: () => Date},
 *   }) | null,
 *   dispositivo: { unidadeId?: string | null },
 *   agora?: Date,
 * }} input
 * @returns {{ resultado: 'ALLOW'|'DENY', motivo: string|null }}
 */
function avaliarAcesso({ aluno, matriculaAtiva, dispositivo, agora }) {
  agora = agora || new Date();
  dispositivo = dispositivo || {};

  if (!aluno) {
    return negar(MOTIVO_NEGACAO.STUDENT_NOT_FOUND);
  }
  if (aluno.ativo === false) {
    return negar(MOTIVO_NEGACAO.STUDENT_INACTIVE);
  }
  if (aluno.bloqueado === true) {
    return negar(MOTIVO_NEGACAO.STUDENT_BLOCKED);
  }

  // Plano: precisa de uma matrícula ativa vigente. `status` é mantido
  // manualmente nas telas hoje (nunca transicionado sozinho por um job),
  // então também checamos a data de vencimento da matrícula diretamente
  // — não dá pra confiar só no campo `status` pra saber se já expirou.
  if (!matriculaAtiva) {
    return negar(MOTIVO_NEGACAO.PLAN_EXPIRED);
  }
  const vencimentoMatricula = matriculaAtiva.dataVencimento
    ? matriculaAtiva.dataVencimento.toDate()
    : null;
  if (vencimentoMatricula && vencimentoMatricula.getTime() < agora.getTime()) {
    return negar(MOTIVO_NEGACAO.PLAN_EXPIRED);
  }

  // Financeiro: mesma regra de tolerância usada no resto do app (ver
  // lib/utils/status_acesso.dart / functions/lib/status-acesso.js) —
  // uma única fonte de verdade, nunca duplicada aqui.
  const proximoVencimento = aluno.proximoVencimento ? aluno.proximoVencimento.toDate() : null;
  const statusMensalidade = calcularStatusAcesso(proximoVencimento, agora);
  if (!statusMensalidade.podeAcessar) {
    return negar(MOTIVO_NEGACAO.PAYMENT_OVERDUE);
  }

  // Horário — ver docstring acima: sem-op de propósito, ainda não existe
  // essa configuração no app.

  // Unidade: só bloqueia se o aluno tiver uma unidade definida E ela for
  // diferente da unidade do dispositivo. Aluno sem `unidadeId` (cadastro
  // legado, ou academia ainda de unidade única) nunca é barrado por isso
  // — mesmo padrão de "campo nulo nunca bloqueia" já usado em
  // `proximoVencimento`.
  if (aluno.unidadeId && dispositivo.unidadeId && aluno.unidadeId !== dispositivo.unidadeId) {
    return negar(MOTIVO_NEGACAO.UNIT_NOT_ALLOWED);
  }

  return PERMITIR;
}

module.exports = { avaliarAcesso };
