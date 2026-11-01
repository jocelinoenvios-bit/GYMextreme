'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  interpretarEventoIdentificacao,
  construirRespostaIdentificacao,
  EVENT_ACESSO_LIBERADO,
  EVENT_ACESSO_NEGADO,
} = require('../../lib/access/control-id-adapter');
const { RESULTADO } = require('../../lib/access/motivos');

test('interpreta um payload completo de identificação facial', () => {
  const evento = interpretarEventoIdentificacao({
    device_id: 12,
    identifier_id: 3,
    event: 12,
    user_id: 1528,
    time: '2026-08-15 18:32:15',
    portal_id: '1',
    uuid: 'abc-123',
    user_name: 'João Silva',
    confidence: 98.5,
    face_mask: false,
  });

  assert.equal(evento.deviceId, '12');
  assert.equal(evento.userIdDispositivo, '1528');
  assert.equal(evento.userName, 'João Silva');
  assert.equal(evento.portalId, '1');
  assert.equal(evento.uuid, 'abc-123');
  assert.equal(evento.identifierId, '3');
  assert.equal(evento.confidence, 98.5);
  assert.equal(evento.metodo, 'FACE');
});

test('payload vazio/undefined não lança — todos os campos viram null', () => {
  const evento = interpretarEventoIdentificacao(undefined);
  assert.equal(evento.deviceId, null);
  assert.equal(evento.userIdDispositivo, null);
  assert.equal(evento.metodo, 'UNKNOWN');
});

test('detecta método CARD quando card_value está presente', () => {
  const evento = interpretarEventoIdentificacao({ device_id: 1, card_value: '0011223344' });
  assert.equal(evento.metodo, 'CARD');
});

test('detecta método QRCODE quando qrcode_value está presente', () => {
  const evento = interpretarEventoIdentificacao({ device_id: 1, qrcode_value: 'xyz' });
  assert.equal(evento.metodo, 'QRCODE');
});

test('resposta de acesso liberado usa event=7 e inclui a ação de abertura', () => {
  const resposta = construirRespostaIdentificacao({
    resultado: RESULTADO.ALLOW,
    userIdDispositivo: '1528',
    userName: 'João Silva',
    portalId: '1',
    mensagem: 'Acesso liberado',
  });

  assert.equal(resposta.result.event, EVENT_ACESSO_LIBERADO);
  assert.equal(resposta.result.event, 7);
  assert.equal(resposta.result.user_id, '1528');
  assert.equal(resposta.result.message, 'Acesso liberado');
  // A lista de acoes de abertura (rele) so vem preenchida se configurada
  // via variavel de ambiente — ver control-id-adapter-acoes.test.js.
  assert.ok(Array.isArray(resposta.result.actions));
});

test('resposta de acesso negado usa event=6 e não inclui nenhuma ação', () => {
  const resposta = construirRespostaIdentificacao({
    resultado: RESULTADO.DENY,
    userIdDispositivo: '1842',
    userName: 'Maria Silva',
    portalId: '1',
    mensagem: 'Mensalidade em atraso',
  });

  assert.equal(resposta.result.event, EVENT_ACESSO_NEGADO);
  assert.equal(resposta.result.event, 6);
  assert.deepEqual(resposta.result.actions, []);
  assert.equal(resposta.result.message, 'Mensalidade em atraso');
});

test('portal_id ausente usa "1" como padrão', () => {
  const resposta = construirRespostaIdentificacao({
    resultado: RESULTADO.DENY,
    userIdDispositivo: null,
    userName: null,
    portalId: null,
    mensagem: 'Acesso negado',
  });
  assert.equal(resposta.result.portal_id, '1');
});
