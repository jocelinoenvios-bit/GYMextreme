'use strict';

/**
 * Comprova, contra o Firestore Emulator, a regra que deixa quem dá baixa
 * na mensalidade renovar a matrícula (modelo A: pagar renova a matrícula —
 * `renovarMatriculaPorPagamento` no app): só ESTENDER a validade de uma
 * matrícula ATIVA, mexendo só em dataVencimento/renovadaPorPagamentoEm/
 * atualizadoEm. Nada de encurtar, mexer em plano/valor/status ou renovar
 * matrícula cancelada.
 *
 * Uso: `npm run test:rules:renovacao-matricula` (sobe/derruba o emulador).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Rode via `npm run test:rules:renovacao-matricula`.');
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

const { Timestamp, FieldValue } = firebase.firestore;
const RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');
const ALUNO = 'aluno-renov';
const VENCE = Timestamp.fromDate(new Date('2026-11-10T00:00:00Z'));
const DEPOIS = Timestamp.fromDate(new Date('2026-12-10T00:00:00Z'));
const ANTES = Timestamp.fromDate(new Date('2026-10-10T00:00:00Z'));

let testEnv;

async function seed() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('usuarios/adm').set({ role: 'adm', nome: 'ADM' });
    await db.doc('usuarios/recep').set({ role: 'funcionario', nome: 'Recepção', permissoes: ['receberMensalidades'] });
    await db.doc('usuarios/caixa').set({ role: 'funcionario', nome: 'Caixa', permissoes: ['receberContasReceber'] });
    await db.doc('usuarios/personal').set({ role: 'funcionario', nome: 'Personal', permissoes: ['criarTreinos'] });
    await db.doc(`usuarios/${ALUNO}`).set({ role: 'aluno', nome: 'Aluno' });
    const base = { alunoId: ALUNO, planoId: 'mensal', dataInicio: ANTES, valorContratado: 100 };
    await db.doc(`alunos/${ALUNO}/matriculas/ativa`).set({ ...base, status: 'ativa', dataVencimento: VENCE });
    await db.doc(`alunos/${ALUNO}/matriculas/cancelada`).set({ ...base, status: 'cancelada', dataVencimento: VENCE });
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gymextreme-test',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
  });
});
test.beforeEach(seed);
test.after(async () => {
  await testEnv.cleanup();
});

const db = (uid) => testEnv.authenticatedContext(uid).firestore();
const matricula = (uid, id) => db(uid).doc(`alunos/${ALUNO}/matriculas/${id}`);

/** Exatamente o que renovarMatriculaPorPagamento envia. */
const renovacao = (vencimento) => ({
  dataVencimento: vencimento,
  renovadaPorPagamentoEm: FieldValue.serverTimestamp(),
  atualizadoEm: FieldValue.serverTimestamp(),
});

test('recepção (receberMensalidades) estende a matrícula ativa', async () => {
  await assertSucceeds(matricula('recep', 'ativa').update(renovacao(DEPOIS)));
});

test('caixa (receberContasReceber) também estende', async () => {
  await assertSucceeds(matricula('caixa', 'ativa').update(renovacao(DEPOIS)));
});

test('recepção não encurta nem mantém a mesma data', async () => {
  await assertFails(matricula('recep', 'ativa').update(renovacao(ANTES)));
  await assertFails(matricula('recep', 'ativa').update(renovacao(VENCE)));
});

test('recepção não mexe em plano, valor ou status', async () => {
  await assertFails(matricula('recep', 'ativa').update({ ...renovacao(DEPOIS), valorContratado: 1 }));
  await assertFails(matricula('recep', 'ativa').update({ ...renovacao(DEPOIS), planoId: 'anual' }));
  await assertFails(matricula('recep', 'ativa').update({ status: 'cancelada' }));
});

test('recepção não renova matrícula cancelada nem cria matrícula', async () => {
  await assertFails(matricula('recep', 'cancelada').update(renovacao(DEPOIS)));
  await assertFails(
    matricula('recep', 'nova').set({ alunoId: ALUNO, status: 'ativa', dataVencimento: DEPOIS }),
  );
});

test('sem a permissão, e o próprio aluno, não renovam', async () => {
  await assertFails(matricula('personal', 'ativa').update(renovacao(DEPOIS)));
  await assertFails(matricula(ALUNO, 'ativa').update(renovacao(DEPOIS)));
});

test('ADM continua podendo tudo na matrícula', async () => {
  await assertSucceeds(matricula('adm', 'ativa').update({ status: 'cancelada' }));
});
