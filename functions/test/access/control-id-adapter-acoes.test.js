'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  resolverAcoesAbertura,
  construirRespostaIdentificacao,
  VARIAVEL_ACAO_ABERTURA,
} = require('../../lib/access/control-id-adapter');
const { RESULTADO } = require('../../lib/access/motivos');

test('sem configuracao nenhuma, resolverAcoesAbertura retorna lista vazia (nunca assume um comando de rele)', () => {
  delete process.env[VARIAVEL_ACAO_ABERTURA];
  assert.deepEqual(resolverAcoesAbertura(), []);
});

test('resposta de ALLOW sem nenhuma acao configurada tem actions vazio', () => {
  delete process.env[VARIAVEL_ACAO_ABERTURA];
  const resposta = construirRespostaIdentificacao({
    resultado: RESULTADO.ALLOW,
    userIdDispositivo: '1',
    userName: 'Teste',
    portalId: '1',
    mensagem: 'Acesso liberado',
  });
  assert.equal(resposta.result.event, 7);
  assert.deepEqual(resposta.result.actions, []);
});

test('com a variavel de ambiente configurada, usa a acao configurada', () => {
  process.env[VARIAVEL_ACAO_ABERTURA] = JSON.stringify([{ action: 'catra', parameters: { allow: 'both' } }]);
  const acoes = resolverAcoesAbertura();
  assert.equal(acoes.length, 1);
  assert.equal(acoes[0].action, 'catra');
  delete process.env[VARIAVEL_ACAO_ABERTURA];
});

test('JSON invalido na variavel de ambiente cai pra lista vazia, sem lancar', () => {
  process.env[VARIAVEL_ACAO_ABERTURA] = 'isso-nao-e-json-valido';
  assert.deepEqual(resolverAcoesAbertura(), []);
  delete process.env[VARIAVEL_ACAO_ABERTURA];
});

test('valor que nao e um array na variavel de ambiente cai pra lista vazia', () => {
  process.env[VARIAVEL_ACAO_ABERTURA] = JSON.stringify({ action: 'catra' });
  assert.deepEqual(resolverAcoesAbertura(), []);
  delete process.env[VARIAVEL_ACAO_ABERTURA];
});
