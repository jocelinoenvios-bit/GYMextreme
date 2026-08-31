'use strict';

/**
 * Motivos padronizados de negativa de acesso — sempre um destes valores,
 * nunca texto livre, pra dar pra filtrar/relatar depois (ver seção 11 do
 * briefing de integração com o iDFace Pro).
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
  SYSTEM_ERROR: 'SYSTEM_ERROR',
});

const RESULTADO = Object.freeze({
  ALLOW: 'ALLOW',
  DENY: 'DENY',
});

module.exports = { MOTIVO_NEGACAO, RESULTADO };
