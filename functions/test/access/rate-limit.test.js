'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { passouIntervaloMinimo, resolverIntervaloMinimoMs, VARIAVEL_INTERVALO_MINIMO_MS } = require(
  '../../lib/access/rate-limit',
);

test('sem intervaloMinimoMs configurado (null), sempre permite', () => {
  const permitido = passouIntervaloMinimo({
    ultimaComunicacaoEm: new Date(2026, 0, 1, 12, 0, 0),
    agora: new Date(2026, 0, 1, 12, 0, 0, 1), // 1ms depois
    intervaloMinimoMs: null,
  });
  assert.equal(permitido, true);
});

test('sem nenhuma comunicacao anterior, sempre permite (primeira vez)', () => {
  const permitido = passouIntervaloMinimo({
    ultimaComunicacaoEm: null,
    agora: new Date(),
    intervaloMinimoMs: 1000,
  });
  assert.equal(permitido, true);
});

test('bloqueia quando o intervalo desde a ultima comunicacao e menor que o minimo', () => {
  const permitido = passouIntervaloMinimo({
    ultimaComunicacaoEm: new Date(2026, 0, 1, 12, 0, 0, 0),
    agora: new Date(2026, 0, 1, 12, 0, 0, 100), // 100ms depois
    intervaloMinimoMs: 1000,
  });
  assert.equal(permitido, false);
});

test('permite quando o intervalo desde a ultima comunicacao e maior ou igual ao minimo', () => {
  const permitido = passouIntervaloMinimo({
    ultimaComunicacaoEm: new Date(2026, 0, 1, 12, 0, 0, 0),
    agora: new Date(2026, 0, 1, 12, 0, 1, 0), // 1000ms depois
    intervaloMinimoMs: 1000,
  });
  assert.equal(permitido, true);
});

test('resolverIntervaloMinimoMs retorna null quando a variavel de ambiente nao esta definida', () => {
  delete process.env[VARIAVEL_INTERVALO_MINIMO_MS];
  assert.equal(resolverIntervaloMinimoMs(), null);
});

test('resolverIntervaloMinimoMs retorna o numero configurado', () => {
  process.env[VARIAVEL_INTERVALO_MINIMO_MS] = '500';
  assert.equal(resolverIntervaloMinimoMs(), 500);
  delete process.env[VARIAVEL_INTERVALO_MINIMO_MS];
});

test('resolverIntervaloMinimoMs retorna null pra valor invalido (nao numerico ou <= 0)', () => {
  process.env[VARIAVEL_INTERVALO_MINIMO_MS] = 'abc';
  assert.equal(resolverIntervaloMinimoMs(), null);
  process.env[VARIAVEL_INTERVALO_MINIMO_MS] = '-5';
  assert.equal(resolverIntervaloMinimoMs(), null);
  delete process.env[VARIAVEL_INTERVALO_MINIMO_MS];
});
