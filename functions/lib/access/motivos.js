'use strict';

/**
 * Motivos padronizados de negativa de acesso — sempre um destes valores,
 * nunca texto livre, pra dar pra filtrar/relatar depois (ver seção 11 do
 * briefing de integração com o iDFace Pro).
 *
 * `RATE_LIMITED` é uma adição além da lista original do briefing — não
 * tinha nenhum código lá pra "chamadas rápidas demais do mesmo
 * dispositivo" (seção 16 pede "rate limiting" como parte da segurança da
 * integração), então precisava de um.
 */
const MOTIVO_NEGACAO = Object.freeze({
  STUDENT_NOT_FOUND: 'STUDENT_NOT_FOUND',
  STUDENT_INACTIVE: 'STUDENT_INACTIVE',
  STUDENT_BLOCKED: 'STUDENT_BLOCKED',
  PLAN_EXPIRED: 'PLAN_EXPIRED',
  PAYMENT_OVERDUE: 'PAYMENT_OVERDUE',
  OUTSIDE_ALLOWED_HOURS: 'OUTSIDE_ALLOWED_HOURS',
  UNIT_NOT_ALLOWED: 'UNIT_NOT_ALLOWED',
  INVALID_CREDENTIAL: 'INVALID_CREDENTIAL',
  DEVICE_NOT_AUTHORIZED: 'DEVICE_NOT_AUTHORIZED',
  RATE_LIMITED: 'RATE_LIMITED',
  SYSTEM_ERROR: 'SYSTEM_ERROR',
});

const RESULTADO = Object.freeze({
  ALLOW: 'ALLOW',
  DENY: 'DENY',
});

module.exports = { MOTIVO_NEGACAO, RESULTADO };
