'use strict';

/**
 * Testa contra o Firestore Emulator só a metade de `DeviceSyncService`
 * que já é real hoje (cadastro de dispositivo, vínculo/desvínculo de
 * credencial) — nunca fala com nenhum equipamento. Mesmo padrão dos
 * outros `.emulator.js` deste diretório.
 *
 * Uso: npm run test:emulator:access -- (ou direto, ver comentário no
 * package.json)
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via `npm run test:emulator:access` ' +
      '(sobe o Firestore Emulator sozinho) em vez de chamar este arquivo direto.',
  );
  process.exit(1);
}

const test = require('node:test');
const assert = require('node:assert/strict');
const { getFirestore } = require('firebase-admin/firestore');
require('../../index'); // side effect: initializeApp()
const {
  cadastrarDispositivo,
  desativarDispositivo,
  vincularCredencial,
  desvincularCredencial,
} = require('../../lib/access/device-sync-service');
const { hashToken, resolverDispositivo } = require('../../lib/access/device-auth');

const db = getFirestore();

async function limpar(deviceId) {
  if (!deviceId) return;
  const credenciais = await db.collection('dispositivosAcesso').doc(deviceId).collection('credenciais').get();
  await Promise.all(credenciais.docs.map((doc) => doc.ref.delete()));
  await db.collection('dispositivosAcesso').doc(deviceId).delete();
}

test('cadastrarDispositivo grava só o hash do token (nunca o token em texto puro) e o dispositivo resolve com ele', async () => {
  const { deviceId, token } = await cadastrarDispositivo(db, {
    unidadeId: 'unidade-teste-sync',
    tipo: 'idface_pro',
    nome: 'Catraca de teste',
  });

  const doc = await db.collection('dispositivosAcesso').doc(deviceId).get();
  assert.equal(doc.data().tokenHash, hashToken(token));
  assert.notEqual(doc.data().tokenHash, token); // nunca em texto puro
  assert.equal(doc.data().ativo, true);

  const resolvido = await resolverDispositivo(db, token);
  assert.equal(resolvido.id, deviceId);

  await limpar(deviceId);
});

test('desativarDispositivo faz o token parar de resolver, sem apagar o histórico', async () => {
  const { deviceId, token } = await cadastrarDispositivo(db, {
    unidadeId: 'unidade-teste-sync',
    tipo: 'idface_pro',
  });

  await desativarDispositivo(db, deviceId);

  const resolvido = await resolverDispositivo(db, token);
  assert.equal(resolvido, null);

  const doc = await db.collection('dispositivosAcesso').doc(deviceId).get();
  assert.equal(doc.exists, true); // documento continua existindo
  assert.equal(doc.data().ativo, false);

  await limpar(deviceId);
});

test('vincularCredencial grava o mapeamento user_id -> alunoUid, desvincularCredencial remove', async () => {
  const { deviceId } = await cadastrarDispositivo(db, {
    unidadeId: 'unidade-teste-sync',
    tipo: 'idface_pro',
  });

  await vincularCredencial(db, { deviceId, userIdDispositivo: '3001', alunoUid: 'aluno-vinculo-teste' });
  let credencial = await db.collection('dispositivosAcesso').doc(deviceId).collection('credenciais').doc('3001').get();
  assert.equal(credencial.data().alunoUid, 'aluno-vinculo-teste');

  await desvincularCredencial(db, { deviceId, userIdDispositivo: '3001' });
  credencial = await db.collection('dispositivosAcesso').doc(deviceId).collection('credenciais').doc('3001').get();
  assert.equal(credencial.exists, false);

  await limpar(deviceId);
});
