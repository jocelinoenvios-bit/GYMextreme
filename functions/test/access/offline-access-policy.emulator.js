'use strict';

/**
 * Testa `resolverPoliticaOfflineConfigurada` (a metade que lê o
 * Firestore) contra o Firestore Emulator. Mesmo padrão dos outros
 * `.emulator.js` deste diretório.
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
  POLITICA_OFFLINE,
  POLITICA_OFFLINE_PADRAO,
  CAMINHO_CONFIGURACAO,
  resolverPoliticaOfflineConfigurada,
} = require('../../lib/access/offline-access-policy');

const db = getFirestore();
const ref = db.collection(CAMINHO_CONFIGURACAO.colecao).doc(CAMINHO_CONFIGURACAO.documento);

test('sem documento de configuracao, resolve pro padrao (DENY_ALL)', async () => {
  await ref.delete();
  const politica = await resolverPoliticaOfflineConfigurada(db);
  assert.equal(politica, POLITICA_OFFLINE_PADRAO);
});

test('com documento configurado, resolve pro valor gravado', async () => {
  await ref.set({ politica: POLITICA_OFFLINE.ALLOW_SYNCHRONIZED_ACTIVE_USERS });
  const politica = await resolverPoliticaOfflineConfigurada(db);
  assert.equal(politica, POLITICA_OFFLINE.ALLOW_SYNCHRONIZED_ACTIVE_USERS);
  await ref.delete();
});

test('valor invalido gravado no documento cai pro padrao, nunca quebra', async () => {
  await ref.set({ politica: 'VALOR_QUE_NAO_EXISTE' });
  const politica = await resolverPoliticaOfflineConfigurada(db);
  assert.equal(politica, POLITICA_OFFLINE_PADRAO);
  await ref.delete();
});
