'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { hashToken, resolverDispositivo } = require('../../lib/access/device-auth');

test('hashToken é determinístico (mesmo token sempre gera o mesmo hash)', () => {
  assert.equal(hashToken('segredo-123'), hashToken('segredo-123'));
});

test('hashToken de tokens diferentes gera hashes diferentes', () => {
  assert.notEqual(hashToken('segredo-123'), hashToken('segredo-456'));
});

test('hashToken nunca retorna o token original (não é um "hash" vazio/identidade)', () => {
  assert.notEqual(hashToken('segredo-123'), 'segredo-123');
});

test('resolverDispositivo retorna null sem token (nunca consulta o Firestore)', async () => {
  const dbNuncaChamado = {
    collection() {
      throw new Error('não deveria consultar o Firestore sem token');
    },
  };
  const resultado = await resolverDispositivo(dbNuncaChamado, null);
  assert.equal(resultado, null);
});
