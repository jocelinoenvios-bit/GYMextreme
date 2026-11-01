'use strict';

/**
 * Regra do vínculo "código do leitor → aluno"
 * (`dispositivosAcesso/{id}/credenciais/{codigo}`), escrito pelo app na
 * ficha do aluno (AcessoService.vincularCodigo/desvincularCodigo):
 * só com a permissão controleCatraca, só criar (nunca sobrescrever o dono
 * de um código), só números no código e só os campos esperados.
 *
 * Uso: `npm run test:rules:vinculo-catraca` (sobe/derruba o emulador).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Rode via `npm run test:rules:vinculo-catraca`.');
  process.exit(1);
}

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

const { FieldValue } = firebase.firestore;
const RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');
const DEVICE = 'idface-1';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gymextreme-test',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
  });
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('usuarios/adm').set({ role: 'adm', nome: 'ADM' });
    await db.doc('usuarios/recep').set({ role: 'funcionario', nome: 'Recepção', permissoes: ['controleCatraca'] });
    await db.doc('usuarios/personal').set({ role: 'funcionario', nome: 'Personal', permissoes: ['criarTreinos'] });
    await db.doc('usuarios/aluno-1').set({ role: 'aluno', nome: 'Aluno' });
    await db.doc(`dispositivosAcesso/${DEVICE}`).set({ nome: 'Entrada', ativo: true, tokenHash: 'x' });
    await db.doc(`dispositivosAcesso/${DEVICE}/credenciais/500`).set({ alunoUid: 'outro-aluno' });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

const db = (uid) => testEnv.authenticatedContext(uid).firestore();
const credencial = (uid, codigo) => db(uid).doc(`dispositivosAcesso/${DEVICE}/credenciais/${codigo}`);

/** Exatamente o que AcessoService.vincularCodigo grava. */
const vinculo = (staffUid, extra = {}) => ({
  alunoUid: 'aluno-1',
  vinculadoEm: FieldValue.serverTimestamp(),
  vinculadoPorUid: staffUid,
  vinculadoPorNome: 'Recepção',
  ...extra,
});

test('com controleCatraca: lê (código livre) e vincula', async () => {
  await assertSucceeds(credencial('recep', '1024').get());
  await assertSucceeds(credencial('recep', '1024').set(vinculo('recep')));
});

test('ADM vincula', async () => {
  await assertSucceeds(credencial('adm', '1025').set(vinculo('adm')));
});

test('não sobrescreve o código de outro aluno', async () => {
  await assertFails(credencial('recep', '500').set(vinculo('recep')));
  await assertFails(credencial('recep', '500').update({ alunoUid: 'aluno-1' }));
});

test('código só com números, campos só os esperados, autor verdadeiro', async () => {
  await assertFails(credencial('recep', 'abc').set(vinculo('recep')));
  await assertFails(credencial('recep', '1024').set(vinculo('recep', { extra: true })));
  await assertFails(credencial('recep', '1024').set(vinculo('adm')));
  await assertFails(credencial('recep', '1024').set(vinculo('recep', { alunoUid: '' })));
});

test('sem a permissão, e o aluno, não vinculam nem desvinculam', async () => {
  await assertFails(credencial('personal', '1024').set(vinculo('personal')));
  await assertFails(credencial('aluno-1', '1024').set(vinculo('aluno-1')));
  await assertFails(credencial('personal', '500').delete());
  await assertFails(credencial('aluno-1', '500').delete());
});

test('com controleCatraca: desvincula', async () => {
  await assertSucceeds(credencial('recep', '500').delete());
});

test('o próprio dispositivo continua só leitura pelo app', async () => {
  await assertFails(db('recep').doc(`dispositivosAcesso/${DEVICE}`).update({ ativo: false }));
});
