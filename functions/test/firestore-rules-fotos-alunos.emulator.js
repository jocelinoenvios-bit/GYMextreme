'use strict';

/**
 * Regra da foto de perfil do aluno guardada no Firestore
 * (`fotosAlunos/{uid}`, ver StorageService no app): staff grava (só a
 * imagem, até 700 KB), o aluno lê só a própria, deslogado não lê.
 *
 * Uso: `npm run test:rules:fotos-alunos` (sobe/derruba o emulador).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Rode via `npm run test:rules:fotos-alunos`.');
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

const { Blob, FieldValue } = firebase.firestore;
const RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');

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
    await db.doc('usuarios/recep').set({ role: 'funcionario', nome: 'Recepção', permissoes: [] });
    await db.doc('usuarios/ana').set({ role: 'aluno', nome: 'Ana' });
    await db.doc('usuarios/bia').set({ role: 'aluno', nome: 'Bia' });
    await db.doc('fotosAlunos/bia').set({ imagem: Blob.fromUint8Array(new Uint8Array([1, 2, 3])) });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

const db = (uid) => (uid ? testEnv.authenticatedContext(uid) : testEnv.unauthenticatedContext()).firestore();

/** Exatamente o que StorageService.enviarFotoAluno grava. */
const foto = (bytes, extra = {}) => ({
  imagem: Blob.fromUint8Array(new Uint8Array(bytes)),
  tamanhoBytes: bytes,
  atualizadoEm: FieldValue.serverTimestamp(),
  ...extra,
});

test('staff grava e troca a foto de um aluno (foto de ~60 KB)', async () => {
  await assertSucceeds(db('recep').doc('fotosAlunos/ana').set(foto(60 * 1024)));
  await assertSucceeds(db('recep').doc('fotosAlunos/bia').set(foto(40 * 1024)));
});

test('foto acima de 700 KB ou com outros campos é recusada', async () => {
  await assertFails(db('recep').doc('fotosAlunos/ana').set(foto(701 * 1024)));
  await assertFails(db('recep').doc('fotosAlunos/ana').set(foto(1024, { extra: 1 })));
  await assertFails(db('recep').doc('fotosAlunos/ana').set({ imagem: 'nao e imagem' }));
});

test('aluno lê a própria foto, não a de outro, e não grava', async () => {
  await assertSucceeds(db('bia').doc('fotosAlunos/bia').get());
  await assertFails(db('ana').doc('fotosAlunos/bia').get());
  await assertFails(db('ana').doc('fotosAlunos/ana').set(foto(1024)));
});

test('staff lê qualquer foto; deslogado não lê', async () => {
  await assertSucceeds(db('recep').doc('fotosAlunos/bia').get());
  await assertFails(db(null).doc('fotosAlunos/bia').get());
});
