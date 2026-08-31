'use strict';

const { calcularStatusAcesso } = require('../status-acesso');
const { MOTIVO_NEGACAO, RESULTADO } = require('./motivos');
const { resolverHorariosPermitidos, estaDentroDoHorarioPermitido } = require('./schedule-service');

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
 * Horário de acesso: configurável por aluno, por plano ou por unidade
 * (ver `schedule-service.js`) — nenhum documento real tem esse campo
 * preenchido hoje, então na prática esta checagem continua sempre "sem
 * restrição" até alguém cadastrar um horário de verdade em algum dos
 * três níveis (o dia que isso acontecer, passa a valer sozinho, sem
 * precisar mudar nada aqui).
 *
 * @param {{
 *   aluno: (Record<string, unknown> & {
 *     ativo?: boolean,
 *     bloqueado?: boolean,
 *     proximoVencimento?: {toDate: () => Date} | null,
 *     unidadeId?: string | null,
 *     horariosPermitidos?: Record<string, Array<{inicio: string, fim: string}>>,
 *   }) | null,
 *   matriculaAtiva: (Record<string, unknown> & {
 *     dataVencimento?: {toDate: () => Date},
 *   }) | null,
 *   dispositivo: { unidadeId?: string | null },
 *   plano?: (Record<string, unknown> & {
 *     horariosPermitidos?: Record<string, Array<{inicio: string, fim: string}>>,
 *   }) | null,
 *   unidade?: (Record<string, unknown> & {
 *     horariosPermitidos?: Record<string, Array<{inicio: string, fim: string}>>,
 *   }) | null,
 *   agora?: Date,
 * }} input
 * @returns {{ resultado: 'ALLOW'|'DENY', motivo: string|null }}
 */
function avaliarAcesso({ aluno, matriculaAtiva, dispositivo, plano, unidade, agora }) {
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

  // Horário: aluno > plano > unidade > sem restrição (ver
  // resolverHorariosPermitidos). Continua sendo sem-op na prática hoje
  // (nenhum dos três documentos tem o campo preenchido no banco real).
  const horariosPermitidos = resolverHorariosPermitidos({ aluno, plano, unidade });
  if (!estaDentroDoHorarioPermitido({ horariosPermitidos, agora })) {
    return negar(MOTIVO_NEGACAO.OUTSIDE_ALLOWED_HOURS);
  }

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
