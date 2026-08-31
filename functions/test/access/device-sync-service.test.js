'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  vincularCredencial,
  desvincularCredencial,
  cadastrarDispositivo,
  sincronizarUsuarioNoDispositivo,
  removerUsuarioDoDispositivo,
} = require('../../lib/access/device-sync-service');

function dbNuncaChamado() {
  return {
    collection() {
      throw new Error('nao deveria consultar o Firestore antes da validacao dos parametros');
    },
  };
}

test('vincularCredencial exige deviceId, userIdDispositivo e alunoUid', async () => {
  await assert.rejects(() => vincularCredencial(dbNuncaChamado(), { userIdDispositivo: '1', alunoUid: 'a' }));
  await assert.rejects(() => vincularCredencial(dbNuncaChamado(), { deviceId: 'd', alunoUid: 'a' }));
  await assert.rejects(() => vincularCredencial(dbNuncaChamado(), { deviceId: 'd', userIdDispositivo: '1' }));
});

test('desvincularCredencial exige deviceId e userIdDispositivo', async () => {
  await assert.rejects(() => desvincularCredencial(dbNuncaChamado(), { userIdDispositivo: '1' }));
  await assert.rejects(() => desvincularCredencial(dbNuncaChamado(), { deviceId: 'd' }));
});

test('cadastrarDispositivo exige unidadeId e tipo', async () => {
  await assert.rejects(() => cadastrarDispositivo(dbNuncaChamado(), { tipo: 'idface_pro' }));
  await assert.rejects(() => cadastrarDispositivo(dbNuncaChamado(), { unidadeId: 'u1' }));
});

test('sincronizarUsuarioNoDispositivo NAO esta implementado — sempre lanca, nunca finge sincronizar', async () => {
  await assert.rejects(
    () => sincronizarUsuarioNoDispositivo(dbNuncaChamado(), { deviceId: 'd', alunoUid: 'a' }),
    /ainda nao implementado/,
  );
});

test('removerUsuarioDoDispositivo NAO esta implementado — sempre lanca', async () => {
  await assert.rejects(
    () => removerUsuarioDoDispositivo(dbNuncaChamado(), { deviceId: 'd', userIdDispositivo: '1' }),
    /ainda nao implementado/,
  );
});
