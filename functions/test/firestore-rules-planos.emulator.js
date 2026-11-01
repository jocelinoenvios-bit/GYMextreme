'use strict';

/**
 * Regra de `planos` pro "Excluir" (PlanoService.excluirPlano): quem tem só
 * a permissão excluirPlanos pode marcar ativo=false + excluido=true, e
 * nada além disso. Apagar o documento continua proibido (matrículas
 * antigas apontam pra ele).
 *
 * Uso: `npm run test:rules:planos` (sobe/derruba o emulador).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Rode via `npm run test:rules:planos`.');
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
    await db.doc('usuarios/so-excluir').set({ role: 'funcionario', nome: 'X', permissoes: ['excluirPlanos'] });
    await db.doc('usuarios/sem-permissao').set({ role: 'funcionario', nome: 'Y', permissoes: ['acessarPlanos'] });
    await db.doc('usuarios/adm').set({ role: 'adm', nome: 'ADM' });
    await db.doc('planos/p1').set({ nome: 'Irmão', valor: 0.01, duracaoDias: 365, ativo: false });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

const plano = (uid) => testEnv.authenticatedContext(uid).firestore().doc('planos/p1');

/** Exatamente o que PlanoService.excluirPlano envia. */
const exclusao = { ativo: false, excluido: true, atualizadoEm: FieldValue.serverTimestamp() };

test('quem tem excluirPlanos exclui (ativo + excluido)', async () => {
  await assertSucceeds(plano('so-excluir').set(exclusao, { merge: true }));
});

test('quem tem só excluirPlanos não mexe em valor ou nome junto', async () => {
  await assertFails(plano('so-excluir').set({ ...exclusao, valor: 1 }, { merge: true }));
});

test('sem a permissão não exclui; ninguém apaga o documento', async () => {
  await assertFails(plano('sem-permissao').set(exclusao, { merge: true }));
  await assertFails(plano('adm').delete());
});

test('ADM exclui', async () => {
  await assertSucceeds(plano('adm').set(exclusao, { merge: true }));
});
