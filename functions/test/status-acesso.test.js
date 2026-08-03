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

test('1o dia de atraso: tolerancia com 7 dias restantes', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 11));
  assert.equal(status.status, 'tolerancia');
  assert.equal(status.podeAcessar, true);
  assert.equal(status.diasAtraso, 1);
  assert.equal(status.diasToleranciaRestantes, 7);
});

test('2o dia de atraso: restam 6 dias', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 12));
  assert.equal(status.diasToleranciaRestantes, 6);
});

test('7o dia de atraso: ultimo dia, ainda libera', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 17));
  assert.equal(status.status, 'tolerancia');
  assert.equal(status.podeAcessar, true);
  assert.equal(status.diasToleranciaRestantes, 1);
});

test('8o dia de atraso: bloqueado', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 18));
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

test('mensagem: 1o dia de atraso avisa da tolerancia', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 11));
  assert.equal(
    mensagemNotificacaoMensalidade(status),
    'Sua mensalidade está vencida. Você possui 7 dias de tolerância para continuar utilizando normalmente a academia.',
  );
});

test('mensagem: meio da tolerancia informa dias restantes', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 14));
  assert.equal(mensagemNotificacaoMensalidade(status), 'Restam 4 dias de tolerância.');
});

test('mensagem: ultimo dia de tolerancia', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 17));
  assert.equal(
    mensagemNotificacaoMensalidade(status),
    'Hoje é o último dia de tolerância. Regularize sua mensalidade para evitar o bloqueio.',
  );
});

test('mensagem: primeiro dia bloqueado avisa da suspensao', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 18));
  assert.equal(
    mensagemNotificacaoMensalidade(status),
    'Sua mensalidade permanece em atraso. Seu acesso ao aplicativo e à academia foi bloqueado até a regularização do pagamento.',
  );
});

test('mensagem: dias seguintes bloqueado nao repetem', () => {
  const status = calcularStatusAcesso(vencimento, new Date(2026, 7, 25));
  assert.equal(mensagemNotificacaoMensalidade(status), null);
});
