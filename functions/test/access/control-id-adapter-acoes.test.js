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

// ---------------------------------------------------------------------
// Acao configurada POR DISPOSITIVO (dispositivosAcesso/{id}.acoesAbertura)
// — sempre tem prioridade sobre a variavel de ambiente global, ja que o
// id do SecBox/MAE (ex.: 65793, confirmado fisicamente) e especifico de
// CADA dispositivo, nunca igual entre dispositivos diferentes.
// ---------------------------------------------------------------------

test('acao configurada por dispositivo tem prioridade sobre a variavel de ambiente global', () => {
  process.env[VARIAVEL_ACAO_ABERTURA] = JSON.stringify([{ action: 'catra', parameters: { allow: 'both' } }]);
  const acoesDoDispositivo = [{ action: 'sec_box', parameters: { id: 65793, reason: 3 } }];

  const acoes = resolverAcoesAbertura(acoesDoDispositivo);

  assert.equal(acoes.length, 1);
  assert.equal(acoes[0].action, 'sec_box');
  assert.deepEqual(acoes[0].parameters, { id: 65793, reason: 3 });
  delete process.env[VARIAVEL_ACAO_ABERTURA];
});

test('sem acao configurada no dispositivo, cai pra variavel de ambiente global (compatibilidade)', () => {
  process.env[VARIAVEL_ACAO_ABERTURA] = JSON.stringify([{ action: 'catra', parameters: { allow: 'both' } }]);

  assert.deepEqual(resolverAcoesAbertura(undefined), [{ action: 'catra', parameters: { allow: 'both' } }]);
  assert.deepEqual(resolverAcoesAbertura([]), [{ action: 'catra', parameters: { allow: 'both' } }]);
  assert.deepEqual(resolverAcoesAbertura(null), [{ action: 'catra', parameters: { allow: 'both' } }]);

  delete process.env[VARIAVEL_ACAO_ABERTURA];
});

test('sem acao no dispositivo NEM variavel de ambiente, retorna lista vazia (nunca assume rele)', () => {
  delete process.env[VARIAVEL_ACAO_ABERTURA];
  assert.deepEqual(resolverAcoesAbertura(undefined), []);
});

test('construirRespostaIdentificacao (ALLOW) usa a acao especifica do dispositivo quando informada', () => {
  const resposta = construirRespostaIdentificacao({
    resultado: RESULTADO.ALLOW,
    userIdDispositivo: '1',
    userName: 'Teste',
    portalId: '1',
    mensagem: 'Acesso liberado',
    acoesAbertura: [{ action: 'sec_box', parameters: { id: 65793, reason: 3 } }],
  });

  assert.deepEqual(resposta.result.actions, [{ action: 'sec_box', parameters: { id: 65793, reason: 3 } }]);
});

test('construirRespostaIdentificacao (DENY) nunca inclui acao de abertura, mesmo com acoesAbertura informado', () => {
  const resposta = construirRespostaIdentificacao({
    resultado: RESULTADO.DENY,
    userIdDispositivo: '1',
    userName: 'Teste',
    portalId: '1',
    mensagem: 'Acesso negado',
    acoesAbertura: [{ action: 'sec_box', parameters: { id: 65793, reason: 3 } }],
  });

  assert.deepEqual(resposta.result.actions, []);
});
