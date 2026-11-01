'use strict';

/**
 * "Receber mensalidade" (AlunoService.receberMensalidade) contra as regras
 * reais, como uma recepcionista que só tem a permissão
 * receberMensalidades: lê o caixa aberto, cria a cobrança já paga, lança
 * no caixa, avança o vencimento, renova a matrícula e grava o histórico —
 * tudo num lote só (como a transação do app).
 *
 * Uso: `npm run test:rules:receber-mensalidade` (sobe/derruba o emulador).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Rode via `npm run test:rules:receber-mensalidade`.');
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

const { FieldValue, Timestamp } = firebase.firestore;
const RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');
const ALUNO = 'aluno-1';
const VENCE = Timestamp.fromDate(new Date('2026-11-10T03:00:00Z'));
const NOVO = Timestamp.fromDate(new Date('2026-12-10T03:00:00Z'));

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
    await db.doc('usuarios/recep').set({ role: 'funcionario', nome: 'Recepção', permissoes: ['receberMensalidades'] });
    await db.doc('usuarios/personal').set({ role: 'funcionario', nome: 'Personal', permissoes: ['criarTreinos'] });
    await db.doc(`usuarios/${ALUNO}`).set({ role: 'aluno', nome: 'Ana' });
    await db.doc(`alunos/${ALUNO}`).set({ ativo: true, proximoVencimento: VENCE });
    await db.doc(`alunos/${ALUNO}/matriculas/m1`).set({ alunoId: ALUNO, status: 'ativa', dataVencimento: VENCE, valorContratado: 80 });
    await db.doc('caixas/c1').set({ status: 'aberto' });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

/** As gravações de receberMensalidade, iguais às do app. */
function lote(db, uid, { cobranca = {}, movimentacao = {}, comCaixa = true } = {}) {
  const batch = db.batch();
  const conta = db.collection(`alunos/${ALUNO}/contasReceber`).doc();
  const mov = db.collection('caixas/c1/movimentacoes').doc();
  batch.set(conta, {
    alunoId: ALUNO, matriculaId: 'm1', descricao: 'Mensalidade (vencimento 10/11)',
    valorOriginal: 80, valorPago: 80, desconto: 0, jurosMulta: 0,
    vencimento: VENCE, dataPagamento: Timestamp.now(), status: 'pago', formaPagamento: 'Pix',
    observacao: null, criadoEm: FieldValue.serverTimestamp(), atualizadoEm: FieldValue.serverTimestamp(),
    criadoPorUid: uid, criadoPorNome: 'Recepção', recebidoPorUid: uid, recebidoPorNome: 'Recepção',
    ...(comCaixa ? { movimentacaoCaixaId: mov.id } : {}),
    ...cobranca,
  });
  if (comCaixa) {
    batch.set(mov, {
      tipo: 'recebimento', valor: 80, formaPagamento: 'Pix', descricao: 'Mensalidade — Ana',
      contaReceberAlunoId: ALUNO, contaReceberId: conta.id, contaPagarId: null,
      staffUid: uid, staffNome: 'Recepção', criadoEm: FieldValue.serverTimestamp(),
      ...movimentacao,
    });
  }
  batch.set(db.doc(`alunos/${ALUNO}`), { proximoVencimento: NOVO }, { merge: true });
  batch.update(db.doc(`alunos/${ALUNO}/matriculas/m1`), {
    dataVencimento: NOVO, renovadaPorPagamentoEm: FieldValue.serverTimestamp(), atualizadoEm: FieldValue.serverTimestamp(),
  });
  batch.set(db.collection(`alunos/${ALUNO}/pagamentos`).doc(), {
    registradoEm: FieldValue.serverTimestamp(), vencimentoAnterior: VENCE, novoVencimento: NOVO,
    registradoPorUid: uid, registradoPorNome: 'Recepção', valor: 80, formaPagamento: 'Pix', contaReceberId: conta.id,
  });
  return batch.commit();
}

const db = (uid) => testEnv.authenticatedContext(uid).firestore();

test('recepção (só receberMensalidades) vê o caixa aberto', async () => {
  await assertSucceeds(db('recep').collection('caixas').where('status', '==', 'aberto').limit(1).get());
  await assertSucceeds(db('recep').doc('caixas/c1').get());
});

test('recepção recebe a mensalidade com caixa aberto: tudo de uma vez', async () => {
  await assertSucceeds(lote(db('recep'), 'recep'));
});

test('recepção recebe sem caixa aberto (só cobrança, vencimento, matrícula, histórico)', async () => {
  await assertSucceeds(lote(db('recep'), 'recep', { comCaixa: false }));
});

test('não grava cobrança paga com desconto escondido ou em nome de outra pessoa', async () => {
  await assertFails(lote(db('recep'), 'recep', { cobranca: { valorPago: 50 } }));
  await assertFails(lote(db('recep'), 'recep', { cobranca: { recebidoPorUid: 'outra-pessoa' } }));
  await assertFails(lote(db('recep'), 'recep', { cobranca: { alunoId: 'outro-aluno' } }));
});

test('não lança no caixa em nome de outra pessoa', async () => {
  await assertFails(lote(db('recep'), 'recep', { movimentacao: { staffUid: 'outra-pessoa' } }));
});

test('sem a permissão não recebe nem vê o caixa', async () => {
  await assertFails(lote(db('personal'), 'personal'));
  await assertFails(db('personal').doc('caixas/c1').get());
});
