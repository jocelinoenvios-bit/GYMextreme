'use strict';

/**
 * Comprova, contra o Firestore Emulator, a regra do lembrete automático de
 * vencimento em `alunos/{uid}/mensagens/lembrete-vencimento-AAAA-MM-DD`:
 * o próprio aluno cria o lembrete dele (e só nesse formato exato), mas
 * não cria mensagem comum, não cria na caixa de outro aluno e não
 * sobrescreve um lembrete que já existe.
 *
 * NÃO faz deploy nem toca o projeto real — Firestore Emulator local,
 * projeto fake `demo-gymextreme-test`.
 *
 * Uso: `npm run test:rules:lembrete-vencimento` (sobe/derruba o emulador
 * sozinho).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via ' +
      '`npm run test:rules:lembrete-vencimento`.',
  );
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

const serverTimestamp = () => firebase.firestore.FieldValue.serverTimestamp();
const doc = (db, ...segmentos) => db.doc(segmentos.join('/'));
const setDoc = (docRef, data) => docRef.set(data);
const getDoc = (docRef) => docRef.get();

const RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');
const ALUNO_UID = 'aluno-lembrete-teste';
const OUTRO_ALUNO_UID = 'aluno-outro-lembrete-teste';
const ID = 'lembrete-vencimento-2026-11-05';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gymextreme-test',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'usuarios', ALUNO_UID), { role: 'aluno', nome: 'Aluno' });
    await setDoc(doc(db, 'usuarios', OUTRO_ALUNO_UID), { role: 'aluno', nome: 'Outro' });
  });
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'usuarios', ALUNO_UID), { role: 'aluno', nome: 'Aluno' });
    await setDoc(doc(db, 'usuarios', OUTRO_ALUNO_UID), { role: 'aluno', nome: 'Outro' });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

function alunoDb() {
  return testEnv.authenticatedContext(ALUNO_UID).firestore();
}

/** O mesmo documento que `Mensagem.toFirestore()` grava no app. */
function lembrete(extra = {}) {
  return {
    texto: 'Lembrete: sua mensalidade vence em 05/11. Se já pagou, pode desconsiderar esta mensagem.',
    remetenteUid: 'sistema',
    remetenteNome: 'GYM XTREME',
    alunoUid: ALUNO_UID,
    alunoNome: 'Aluno',
    criadoEm: serverTimestamp(),
    lidaEm: null,
    arquivadaPeloAluno: false,
    automatica: true,
    ...extra,
  };
}

function ref(db, uid, id) {
  return doc(db, 'alunos', uid, 'mensagens', id);
}

test('aluno le (inexistente) e cria o proprio lembrete', async () => {
  const db = alunoDb();
  await assertSucceeds(getDoc(ref(db, ALUNO_UID, ID)));
  await assertSucceeds(setDoc(ref(db, ALUNO_UID, ID), lembrete()));
});

test('aluno nao sobrescreve um lembrete que ja existe', async () => {
  const db = alunoDb();
  await assertSucceeds(setDoc(ref(db, ALUNO_UID, ID), lembrete()));
  await assertFails(setDoc(ref(db, ALUNO_UID, ID), lembrete()));
});

test('aluno nao cria mensagem comum nem com id fora do padrao', async () => {
  const db = alunoDb();
  await assertFails(setDoc(ref(db, ALUNO_UID, 'qualquer'), lembrete()));
  await assertFails(setDoc(ref(db, ALUNO_UID, 'lembrete-vencimento-amanha'), lembrete()));
});

test('aluno nao cria lembrete fora do formato', async () => {
  const db = alunoDb();
  await assertFails(setDoc(ref(db, ALUNO_UID, ID), lembrete({ automatica: false })));
  await assertFails(setDoc(ref(db, ALUNO_UID, ID), lembrete({ remetenteUid: 'adm' })));
  await assertFails(setDoc(ref(db, ALUNO_UID, ID), lembrete({ alunoUid: OUTRO_ALUNO_UID })));
  await assertFails(setDoc(ref(db, ALUNO_UID, ID), lembrete({ lidaEm: serverTimestamp() })));
  await assertFails(setDoc(ref(db, ALUNO_UID, ID), lembrete({ extra: 'x' })));
  await assertFails(setDoc(ref(db, ALUNO_UID, ID), lembrete({ texto: 'x'.repeat(301) })));
});

test('aluno nao cria lembrete na caixa de outro aluno', async () => {
  const db = alunoDb();
  await assertFails(
    setDoc(ref(db, OUTRO_ALUNO_UID, ID), lembrete({ alunoUid: OUTRO_ALUNO_UID })),
  );
});

test('deslogado nao cria lembrete', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(setDoc(ref(db, ALUNO_UID, ID), lembrete()));
});
