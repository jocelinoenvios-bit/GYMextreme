'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { processarEventoIdentificacao, payloadUtilizavel } = require('../../lib/access/access-request-handler');

function dbNuncaChamado() {
  return {
    collection() {
      throw new Error('nao deveria consultar o Firestore com um payload invalido');
    },
  };
}

test('payloadUtilizavel: objeto simples e utilizavel', () => {
  assert.equal(payloadUtilizavel({}), true);
  assert.equal(payloadUtilizavel({ user_id: '1' }), true);
});

test('payloadUtilizavel: null, array e tipos primitivos nao sao utilizaveis', () => {
  assert.equal(payloadUtilizavel(null), false);
  assert.equal(payloadUtilizavel(undefined), false);
  assert.equal(payloadUtilizavel([]), false);
  assert.equal(payloadUtilizavel('texto'), false);
  assert.equal(payloadUtilizavel(42), false);
});

test('payload malformado retorna HTTP 400 sem consultar o Firestore', async () => {
  const resultado = await processarEventoIdentificacao(dbNuncaChamado(), {
    payload: 'nao-e-um-objeto',
    deviceToken: 'qualquer',
  });
  assert.equal(resultado.httpStatus, 400);
  assert.equal(resultado.corpo, null);
});

test('payload null retorna HTTP 400 sem consultar o Firestore', async () => {
  const resultado = await processarEventoIdentificacao(dbNuncaChamado(), {
    payload: null,
    deviceToken: 'qualquer',
  });
  assert.equal(resultado.httpStatus, 400);
});

/**
 * Fake mínimo do Firestore — só o suficiente pro caminho "dispositivo
 * não encontrado" (device-auth consulta `dispositivosAcesso`,
 * access-event-service grava em `eventosAcesso`). Sem nenhuma
 * dependência do Firestore Emulator.
 */
function dbComDispositivoInexistente() {
  return {
    collection(nome) {
      if (nome === 'dispositivosAcesso') {
        return {
          where: () => ({
            where: () => ({
              limit: () => ({ get: async () => ({ empty: true, docs: [] }) }),
            }),
          }),
        };
      }
      if (nome === 'eventosAcesso') {
        return {
          add: async () => ({ id: 'evento-fake' }),
        };
      }
      throw new Error(`colecao inesperada no teste: ${nome}`);
    },
  };
}

test('usa o AccessControlProvider injetado, nao so o do Control iD (inversao de dependencia)', async () => {
  const providerFalso = {
    id: 'provider-falso-de-teste',
    interpretarEvento: () => ({
      deviceId: 'd1',
      userIdDispositivo: null,
      userName: null,
      portalId: null,
      uuid: null,
      confidence: null,
      metodo: 'UNKNOWN',
    }),
    construirResposta: (params) => ({ formatoCustomizado: true, ...params }),
  };

  const resultado = await processarEventoIdentificacao(dbComDispositivoInexistente(), {
    payload: { device_id: 'd1' },
    deviceToken: 'algum-token',
    provider: providerFalso,
  });

  assert.equal(resultado.corpo.formatoCustomizado, true);
  assert.equal(resultado.corpo.resultado, 'DENY');
});
