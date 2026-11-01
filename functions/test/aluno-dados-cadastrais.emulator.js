'use strict';

/**
 * Reproduz, contra o Firestore Emulator de verdade (persistência real,
 * merge real), o bug crítico encontrado na auditoria: salvar a aba
 * "Dados" do aluno sobrescrevia `ativo`/`bloqueado`/`proximoVencimento`/
 * `dataInativacao`/`dataReativacao`/`whatsappOptIn` com valores padrão.
 *
 * Este arquivo espelha em JS o EXATO conjunto de chaves que
 * `AlunoService.dadosCadastraisParaFirestore` (Dart, ver
 * `lib/services/aluno_service.dart`) agora grava — a garantia mais forte
 * já está provada em Dart puro por `test/aluno_service_test.dart` (o
 * mapa nunca contém as chaves operacionais, não importa o `Aluno` de
 * entrada); este arquivo prova a OUTRA metade: que a semântica de
 * `merge: true` do Firestore de verdade realmente preserva um campo
 * ausente do mapa, no mesmo projeto/coleção que o app usa em produção.
 *
 * NÃO faz deploy nem toca projeto real — Firestore Emulator local,
 * projeto fake `demo-gymextreme-test`, mesmo padrão de
 * `notificacao-mensalidade.emulator.js`.
 *
 * Uso: `npm run test:emulator:aluno-dados-cadastrais`
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via ' +
      '`npm run test:emulator:aluno-dados-cadastrais` (sobe o Firestore ' +
      'Emulator sozinho) em vez de chamar este arquivo direto.',
  );
  process.exit(1);
}

const test = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

/**
 * Mesmas chaves que `AlunoService.dadosCadastraisParaFirestore` grava —
 * NUNCA inclui os campos operacionais/financeiros, de propósito.
 */
function dadosCadastraisParaFirestore({ telefone, endereco, cpf }) {
  return {
    sexo: null,
    dataNascimento: null,
    idade: null,
    fotoUrl: null,
    cpf: cpf ?? null,
    rg: null,
    telefone: telefone ?? null,
    whatsapp: null,
    endereco: endereco ?? {},
    contatoEmergenciaNome: null,
    contatoEmergenciaTelefone: null,
    observacoes: null,
    dataInicio: null,
    diaVencimento: null,
  };
}

async function limparAluno(uid) {
  await db.collection('alunos').doc(uid).delete();
}

test('TESTE (bug crítico): editar só telefone/endereço preserva ativo/bloqueado/vencimento/inatividade/optIn', async () => {
  const uid = 'aluno-dados-cadastrais-1';
  await limparAluno(uid);

  const vencimentoOriginal = new Date(2026, 11, 10);
  const dataInativacaoOriginal = new Date(2026, 2, 1);
  const dataReativacaoOriginal = new Date(2026, 4, 20);

  // 1. Criar aluno ativo com proximoVencimento preenchido (e outros
  // campos operacionais também setados, pra provar que TODOS sobrevivem).
  await db
    .collection('alunos')
    .doc(uid)
    .set({
      telefone: '11900000000',
      ativo: true,
      bloqueado: true,
      proximoVencimento: Timestamp.fromDate(vencimentoOriginal),
      dataInativacao: Timestamp.fromDate(dataInativacaoOriginal),
      dataReativacao: Timestamp.fromDate(dataReativacaoOriginal),
      whatsappOptIn: true,
    });

  // 2 e 3. Editar SÓ telefone/endereço e salvar — mesmo shape de mapa
  // que `AlunoService.salvarDadosAluno` grava hoje.
  const dadosEditados = dadosCadastraisParaFirestore({
    telefone: '11987654321',
    endereco: { logradouro: 'Rua Nova' },
  });
  await db.collection('alunos').doc(uid).set(dadosEditados, { merge: true });

  const snap = await db.collection('alunos').doc(uid).get();
  const dados = snap.data();

  // Edição foi aplicada.
  assert.equal(dados.telefone, '11987654321');
  assert.equal(dados.endereco.logradouro, 'Rua Nova');

  // 4. ativo continua ativo.
  assert.equal(dados.ativo, true);
  // 6. bloqueado continua igual.
  assert.equal(dados.bloqueado, true);
  // 5. proximoVencimento continua igual.
  assert.equal(dados.proximoVencimento.toDate().getTime(), vencimentoOriginal.getTime());
  // 7. dataInativacao/dataReativacao continuam iguais.
  assert.equal(dados.dataInativacao.toDate().getTime(), dataInativacaoOriginal.getTime());
  assert.equal(dados.dataReativacao.toDate().getTime(), dataReativacaoOriginal.getTime());
  // 8. whatsappOptIn continua igual.
  assert.equal(dados.whatsappOptIn, true);

  await limparAluno(uid);
});

test('editar dados de um aluno INATIVO não o reativa nem limpa o histórico de inativação', async () => {
  const uid = 'aluno-dados-cadastrais-2';
  await limparAluno(uid);

  const dataInativacaoOriginal = new Date(2026, 2, 1);
  await db.collection('alunos').doc(uid).set({
    ativo: false,
    bloqueado: false,
    dataInativacao: Timestamp.fromDate(dataInativacaoOriginal),
  });

  const dadosEditados = dadosCadastraisParaFirestore({ cpf: '12345678900' });
  await db.collection('alunos').doc(uid).set(dadosEditados, { merge: true });

  const snap = await db.collection('alunos').doc(uid).get();
  const dados = snap.data();

  assert.equal(dados.cpf, '12345678900');
  assert.equal(dados.ativo, false);
  assert.equal(dados.dataInativacao.toDate().getTime(), dataInativacaoOriginal.getTime());

  await limparAluno(uid);
});

test('operação que DEVE alterar os campos operacionais (reativação) continua funcionando', async () => {
  const uid = 'aluno-dados-cadastrais-3';
  await limparAluno(uid);

  await db.collection('alunos').doc(uid).set({
    ativo: false,
    dataInativacao: Timestamp.fromDate(new Date(2026, 2, 1)),
  });

  // Mesmo shape que `AlunoService.reativarAluno` grava — um mapa
  // pequeno e explícito, nunca via `Aluno.toFirestore()`.
  const agora = new Date(2026, 5, 1);
  await db
    .collection('alunos')
    .doc(uid)
    .set(
      {
        ativo: true,
        dataReativacao: Timestamp.fromDate(agora),
        proximoVencimento: Timestamp.fromDate(new Date(2026, 6, 1)),
        reativadoPorUid: 'staff-1',
        reativadoPorNome: 'Ana',
      },
      { merge: true },
    );

  const snap = await db.collection('alunos').doc(uid).get();
  const dados = snap.data();
  assert.equal(dados.ativo, true);
  assert.ok(dados.dataReativacao);
  assert.ok(dados.proximoVencimento);
  // dataInativacao é preservada como histórico (nunca apagada).
  assert.ok(dados.dataInativacao);

  await limparAluno(uid);
});

test('operação que DEVE alterar proximoVencimento (marcarPagamentoRecebido) continua funcionando', async () => {
  const uid = 'aluno-dados-cadastrais-4';
  await limparAluno(uid);

  await db.collection('alunos').doc(uid).set({
    ativo: true,
    telefone: '11999998888',
  });

  const novoVencimento = new Date(2026, 7, 1);
  await db
    .collection('alunos')
    .doc(uid)
    .set({ proximoVencimento: Timestamp.fromDate(novoVencimento) }, { merge: true });

  const snap = await db.collection('alunos').doc(uid).get();
  const dados = snap.data();
  assert.equal(dados.proximoVencimento.toDate().getTime(), novoVencimento.getTime());
  // Campos não tocados por essa operação continuam intactos.
  assert.equal(dados.telefone, '11999998888');

  await limparAluno(uid);
});
