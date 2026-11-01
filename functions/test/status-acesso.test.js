'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { calcularStatusAcesso, mensagemNotificacaoMensalidade } = require('../lib/status-acesso');

const vencimento = new Date(2026, 7, 10); // 10/ago/2026 (mes 0-indexado)

test('sem vencimento configurado libera acesso', () => {
  const status = calcularStatusAcesso(null);
  assert.equal(status.status, 'semRegistro');
  assert.equal(status.podeAcessar, true);
});

test('antes do vencimento fica em dia', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 3));
  assert.equal(status.status, 'emDia');
  assert.equal(status.diasParaVencimento, 7);
});

test('exatamente no vencimento ainda fica em dia', () => {
  const status = calcularStatusAcesso(vencimento, vencimento);
  assert.equal(status.status, 'emDia');
  assert.equal(status.diasParaVencimento, 0);
});

test('regra atual (tolerancia zero): no dia seguinte ao vencimento ja bloqueia', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 11, 6));
  assert.equal(status.status, 'bloqueado');
  assert.equal(status.podeAcessar, false);
  assert.equal(status.diasAtraso, 1);
});

test('tolerancia de 7 dias (parametro): 1o dia de atraso, restam 7', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 11), 7);
  assert.equal(status.status, 'tolerancia');
  assert.equal(status.podeAcessar, true);
  assert.equal(status.diasAtraso, 1);
  assert.equal(status.diasToleranciaRestantes, 7);
});

test('tolerancia de 7 dias (parametro): 2o dia, restam 6', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 12), 7);
  assert.equal(status.diasToleranciaRestantes, 6);
});

test('tolerancia de 7 dias (parametro): 7o dia ainda libera', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 17), 7);
  assert.equal(status.status, 'tolerancia');
  assert.equal(status.podeAcessar, true);
  assert.equal(status.diasToleranciaRestantes, 1);
});

test('tolerancia de 7 dias (parametro): 8o dia bloqueia', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 18), 7);
  assert.equal(status.status, 'bloqueado');
  assert.equal(status.podeAcessar, false);
});

test('continua bloqueado bem depois', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 8, 10));
  assert.equal(status.status, 'bloqueado');
  assert.equal(status.podeAcessar, false);
});

test('mensagens: 7/3/0 dias antes do vencimento', () => {
  assert.equal(
    mensagemNotificacaoMensalidade(calcularStatusAcesso(vencimento, new Date(2026, 7, 3))),
    'Atenção! Sua mensalidade vence em 7 dias.',
  );
  assert.equal(
    mensagemNotificacaoMensalidade(calcularStatusAcesso(vencimento, new Date(2026, 7, 7))),
    'Sua mensalidade está próxima do vencimento.',
  );
  assert.equal(
    mensagemNotificacaoMensalidade(calcularStatusAcesso(vencimento, vencimento)),
    'Sua mensalidade vence hoje.',
  );
});

test('mensagem: dia comum sem notificacao', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 5));
  assert.equal(mensagemNotificacaoMensalidade(status), null);
});

test('mensagem: primeiro dia bloqueado (dia seguinte ao vencimento) avisa da suspensao', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 11));
  assert.equal(
    mensagemNotificacaoMensalidade(status),
    'Sua mensalidade permanece em atraso. Seu acesso ao aplicativo e à academia foi bloqueado até a regularização do pagamento.',
  );
});

test('mensagem: dias seguintes bloqueado nao repetem', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 25));
  assert.equal(mensagemNotificacaoMensalidade(status), null);
});
