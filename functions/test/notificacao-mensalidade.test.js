'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  construirRegistroNotificacao,
  idNotificacaoDoDia,
} = require('../lib/notificacao-mensalidade');
const { calcularStatusAcesso } = require('../lib/status-acesso');

const vencimento = new Date(2026, 7, 10); // 10/ago/2026

test('registro sem token fica marcado como sem_token_fcm e nao enviado', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 3));
  const registro = construirRegistroNotificacao(status, 'Atenção! Sua mensalidade vence em 7 dias.', 0);

  assert.equal(registro.enviada, false);
  assert.equal(registro.erro, 'sem_token_fcm');
  assert.equal(registro.tokensAlvo, 0);
  assert.equal(registro.canal, 'push');
  assert.equal(registro.mensagem, 'Atenção! Sua mensalidade vence em 7 dias.');
});

test('registro com token disponivel nao marca erro (envio real fica por conta do chamador)', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 3));
  const registro = construirRegistroNotificacao(status, 'Atenção! Sua mensalidade vence em 7 dias.', 2);

  assert.equal(registro.erro, null);
  assert.equal(registro.tokensAlvo, 2);
  // `enviada` só é verdadeiro depois de uma tentativa de envio bem-sucedida
  // — o helper puro nunca fala com o Firebase Messaging, então começa false.
  assert.equal(registro.enviada, false);
});

test('registro carrega os dias calculados pelo status (tolerancia)', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 14));
  const registro = construirRegistroNotificacao(status, 'Restam 4 dias de tolerância.', 1);

  assert.equal(registro.status, 'tolerancia');
  assert.equal(registro.diasAtraso, 4);
  assert.equal(registro.diasToleranciaRestantes, 4);
  assert.equal(registro.diasParaVencimento, null);
});

test('registro carrega dias para o vencimento (em dia)', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 7));
  const registro = construirRegistroNotificacao(status, 'Sua mensalidade está próxima do vencimento.', 1);

  assert.equal(registro.status, 'emDia');
  assert.equal(registro.diasParaVencimento, 3);
  assert.equal(registro.diasAtraso, null);
  assert.equal(registro.diasToleranciaRestantes, null);
});

test('id do dia usa fuso de Sao Paulo no formato AAAA-MM-DD', () => {
  // 2026-08-15T02:30:00Z ainda é 14/ago as 23h30 em Sao Paulo (UTC-3).
  const antesDaMeiaNoiteEmSp = new Date('2026-08-15T02:30:00Z');
  assert.equal(idNotificacaoDoDia(antesDaMeiaNoiteEmSp), '2026-08-14');

  const depoisDaMeiaNoiteEmSp = new Date('2026-08-15T04:30:00Z');
  assert.equal(idNotificacaoDoDia(depoisDaMeiaNoiteEmSp), '2026-08-15');
});

test('id do dia e estavel pra duas chamadas no mesmo dia (idempotencia)', () => {
  const a = idNotificacaoDoDia(new Date('2026-08-14T11:00:00Z'));
  const b = idNotificacaoDoDia(new Date('2026-08-14T19:00:00Z'));
  assert.equal(a, b);
});
