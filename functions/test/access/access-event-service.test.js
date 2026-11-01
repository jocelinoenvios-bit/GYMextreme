'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { construirRegistroEvento } = require('../../lib/access/access-event-service');

test('monta o registro com todos os campos informados', () => {
  const registro = construirRegistroEvento({
    deviceId: 'device-1',
    unidadeId: 'unidade-1',
    alunoUid: 'aluno-1',
    userIdDispositivo: '1528',
    userName: 'João Silva',
    metodo: 'FACE',
    resultado: 'ALLOW',
    motivo: null,
    confidence: 98.5,
    portalId: '1',
    uuid: 'abc-123',
    tempoProcessamentoMs: 42,
    erro: null,
  });

  assert.equal(registro.deviceId, 'device-1');
  assert.equal(registro.resultado, 'ALLOW');
  assert.equal(registro.confidence, 98.5);
  assert.equal(registro.tempoProcessamentoMs, 42);
});

test('campos ausentes viram null (nunca undefined) — Firestore não aceita undefined', () => {
  const registro = construirRegistroEvento({ resultado: 'DENY' });

  for (const chave of Object.keys(registro)) {
    assert.notEqual(registro[chave], undefined, `campo ${chave} não pode ser undefined`);
  }
  assert.equal(registro.deviceId, null);
  assert.equal(registro.motivo, null);
  assert.equal(registro.metodo, 'UNKNOWN');
});
