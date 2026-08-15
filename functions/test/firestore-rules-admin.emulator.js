'use strict';

/**
 * Comprova, contra o Firestore Emulator, que `firestore.rules` dá ao ADM
 * acesso de leitura/escrita nos módulos administrativos (planos, produtos,
 * contas a pagar, contas a receber, controle de caixa) usando exatamente
 * os formatos de documento que os serviços do app (`PlanoService`,
 * `ProdutoService`, `ContaPagarService`, `AlunoService`, `CaixaService`)
 * realmente enviam — e que aluno/usuário comum e visitante deslogado
 * continuam bloqueados nesses mesmos módulos.
 *
 * NÃO faz deploy nem toca o projeto real — sobe um Firestore Emulator
 * local (projeto fake `demo-gymextreme-test`) e usa
 * `@firebase/rules-unit-testing`, que troca o SDK de identidade a cada
 * chamada (autenticado como ADM, como aluno, ou sem autenticação nenhuma)
 * pra exercitar as regras de verdade, não um "modo admin" que as ignora.
 *
 * Uso: `npm run test:rules` (sobe/derruba o emulador sozinho).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via `npm run test:rules` ' +
      '(sobe o Firestore Emulator sozinho) em vez de chamar este arquivo direto.',
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

const RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');
const ADM_UID = 'staff-adm-teste';
const ALUNO_UID = 'aluno-comum-teste';
const OUTRO_ALUNO_UID = 'aluno-outro-teste';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gymextreme-test',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
  });

  // Seed dos documentos `usuarios/{uid}` que `ehAdm()`/`ehStaff()` leem —
  // via withSecurityRulesDisabled (bypassa as regras, equivalente ao
  // Admin SDK) porque isto é preparação de cenário, não o que está sendo
  // testado.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('usuarios').doc(ADM_UID).set({ role: 'adm', nome: 'Admin Teste' });
    await db.collection('usuarios').doc(ALUNO_UID).set({ role: 'aluno', nome: 'Aluno Teste' });
    await db
      .collection('usuarios')
      .doc(OUTRO_ALUNO_UID)
      .set({ role: 'aluno', nome: 'Outro Aluno' });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

function admDb() {
  return testEnv.authenticatedContext(ADM_UID).firestore();
}

function alunoDb() {
  return testEnv.authenticatedContext(ALUNO_UID).firestore();
}

function semAuthDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seed(docPath, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(docPath).set(data);
  });
}

// ---------------------------------------------------------------------
// ADM: acesso completo aos 5 módulos administrativos
// ---------------------------------------------------------------------

test('ADM le e cria planos (PlanoService)', async () => {
  await seed('planos/plano-leitura', {
    nome: 'Mensal',
    descricao: null,
    valor: 100,
    duracaoDias: 30,
    ativo: true,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });

  await assertSucceeds(admDb().collection('planos').get());
  await assertSucceeds(
    admDb().collection('planos').add({
      nome: 'Trimestral',
      descricao: null,
      valor: 270,
      duracaoDias: 90,
      ativo: true,
      criadoEm: new Date(),
      atualizadoEm: new Date(),
    }),
  );
});

test('ADM edita um plano existente (PlanoService.salvarPlano)', async () => {
  await seed('planos/plano-editar', {
    nome: 'Mensal',
    descricao: null,
    valor: 100,
    duracaoDias: 30,
    ativo: true,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });

  await assertSucceeds(
    admDb().collection('planos').doc('plano-editar').set(
      {
        nome: 'Mensal (reajustado)',
        descricao: null,
        valor: 120,
        duracaoDias: 30,
        ativo: true,
        criadoEm: new Date(),
        atualizadoEm: new Date(),
      },
      { merge: true },
    ),
  );
});

test('ADM le, cria e movimenta estoque de produtos (ProdutoService)', async () => {
  await seed('produtos/produto-leitura', {
    nome: 'Whey',
    codigo: 'W1',
    categoria: 'Suplementos',
    descricao: null,
    unidadeMedida: 'un',
    precoCusto: 10,
    precoVenda: 20,
    estoqueAtual: 5,
    estoqueMinimo: 1,
    ativo: true,
    fornecedor: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });

  await assertSucceeds(admDb().collection('produtos').get());

  const criado = admDb().collection('produtos').doc('produto-criado');
  await assertSucceeds(
    criado.set({
      nome: 'Creatina',
      codigo: 'C1',
      categoria: 'Suplementos',
      descricao: null,
      unidadeMedida: 'un',
      precoCusto: 15,
      precoVenda: 30,
      estoqueAtual: 0,
      estoqueMinimo: 2,
      ativo: true,
      fornecedor: null,
      criadoEm: new Date(),
      atualizadoEm: new Date(),
    }),
  );

  // Edicao completa do cadastro (ProdutoService.atualizarProduto).
  await assertSucceeds(
    criado.set(
      {
        nome: 'Creatina Monohidratada',
        codigo: 'C1',
        categoria: 'Suplementos',
        descricao: 'Pote 300g',
        unidadeMedida: 'un',
        precoCusto: 15,
        precoVenda: 32,
        estoqueMinimo: 2,
        fornecedor: 'Fornecedor X',
        atualizadoEm: new Date(),
      },
      { merge: true },
    ),
  );

  // Movimentacao de estoque (ProdutoService.registrarEntrada): só toca
  // estoqueAtual/atualizadoEm no produto...
  await assertSucceeds(
    criado.set({ estoqueAtual: 10, atualizadoEm: new Date() }, { merge: true }),
  );
  // ...e cria o registro de movimentacao correspondente.
  await assertSucceeds(
    criado.collection('movimentacoes').add({
      tipo: 'entrada',
      quantidade: 10,
      estoqueAnterior: 0,
      estoquePosterior: 10,
      motivo: null,
      staffUid: ADM_UID,
      staffNome: 'Admin Teste',
      criadoEm: new Date(),
    }),
  );
});

test('ADM le e cria contas a pagar, e registra pagamento com movimentacaoCaixaId (ContaPagarService/CaixaService)', async () => {
  await seed('contasPagar/cp-leitura', {
    fornecedor: 'Fornecedor X',
    descricao: 'Aluguel',
    categoria: 'Fixas',
    valorOriginal: 500,
    valorPago: null,
    desconto: 0,
    jurosMulta: 0,
    vencimento: new Date(),
    dataPagamento: null,
    status: 'pendente',
    formaPagamento: null,
    observacao: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });

  await assertSucceeds(admDb().collection('contasPagar').get());

  const conta = admDb().collection('contasPagar').doc('cp-pagar');
  await seed('contasPagar/cp-pagar', {
    fornecedor: 'Fornecedor Y',
    descricao: 'Água',
    categoria: 'Consumo',
    valorOriginal: 80,
    valorPago: null,
    desconto: 0,
    jurosMulta: 0,
    vencimento: new Date(),
    dataPagamento: null,
    status: 'pendente',
    formaPagamento: null,
    observacao: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });

  // Mesmo formato de CaixaService.registrarPagamentoContaPagar (inclui
  // movimentacaoCaixaId) — já funcionava antes desta correção, serve de
  // controle positivo.
  await assertSucceeds(
    conta.set(
      {
        status: 'pago',
        valorPago: 80,
        desconto: 0,
        jurosMulta: 0,
        dataPagamento: new Date(),
        formaPagamento: 'pix',
        observacao: null,
        pagoPorUid: ADM_UID,
        pagoPorNome: 'Admin Teste',
        movimentacaoCaixaId: 'mov-1',
        atualizadoEm: new Date(),
      },
      { merge: true },
    ),
  );
});

test('ADM le, cria e recebe contas a receber — inclusive com caixa aberto (regressao do bug corrigido)', async () => {
  await seed(`alunos/${ALUNO_UID}/contasReceber/cr-leitura`, {
    alunoId: ALUNO_UID,
    matriculaId: null,
    descricao: 'Mensalidade',
    valorOriginal: 100,
    valorPago: null,
    desconto: 0,
    jurosMulta: 0,
    vencimento: new Date(),
    dataPagamento: null,
    status: 'pendente',
    formaPagamento: null,
    observacao: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });

  await assertSucceeds(admDb().collectionGroup('contasReceber').get());

  await assertSucceeds(
    admDb().collection('alunos').doc(ALUNO_UID).collection('contasReceber').add({
      alunoId: ALUNO_UID,
      matriculaId: null,
      descricao: 'Taxa de matrícula',
      valorOriginal: 50,
      valorPago: null,
      desconto: 0,
      jurosMulta: 0,
      vencimento: new Date(),
      dataPagamento: null,
      status: 'pendente',
      formaPagamento: null,
      observacao: null,
      criadoEm: new Date(),
      atualizadoEm: new Date(),
    }),
  );

  // Recebimento SEM caixa aberto (AlunoService.registrarRecebimento) — já
  // funcionava antes, serve de controle positivo.
  const semCaixaPath = `alunos/${ALUNO_UID}/contasReceber/cr-sem-caixa`;
  await seed(semCaixaPath, {
    alunoId: ALUNO_UID,
    matriculaId: null,
    descricao: 'Mensalidade',
    valorOriginal: 100,
    valorPago: null,
    desconto: 0,
    jurosMulta: 0,
    vencimento: new Date(),
    dataPagamento: null,
    status: 'pendente',
    formaPagamento: null,
    observacao: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });
  await assertSucceeds(
    admDb().doc(semCaixaPath).set(
      {
        status: 'pago',
        valorPago: 100,
        desconto: 0,
        jurosMulta: 0,
        dataPagamento: new Date(),
        formaPagamento: 'pix',
        observacao: null,
        recebidoPorUid: ADM_UID,
        recebidoPorNome: 'Admin Teste',
        atualizadoEm: new Date(),
      },
      { merge: true },
    ),
  );

  // Recebimento COM caixa aberto (CaixaService.registrarRecebimentoContaReceber,
  // que também grava `movimentacaoCaixaId`) — este é o caso que estava
  // caindo em permission-denied antes da correção desta regra.
  const comCaixaPath = `alunos/${ALUNO_UID}/contasReceber/cr-com-caixa`;
  await seed(comCaixaPath, {
    alunoId: ALUNO_UID,
    matriculaId: null,
    descricao: 'Mensalidade',
    valorOriginal: 100,
    valorPago: null,
    desconto: 0,
    jurosMulta: 0,
    vencimento: new Date(),
    dataPagamento: null,
    status: 'pendente',
    formaPagamento: null,
    observacao: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });
  await assertSucceeds(
    admDb().doc(comCaixaPath).set(
      {
        status: 'pago',
        valorPago: 100,
        desconto: 0,
        jurosMulta: 0,
        dataPagamento: new Date(),
        formaPagamento: 'dinheiro',
        observacao: null,
        recebidoPorUid: ADM_UID,
        recebidoPorNome: 'Admin Teste',
        movimentacaoCaixaId: 'mov-2',
        atualizadoEm: new Date(),
      },
      { merge: true },
    ),
  );
});

test('ADM abre, le e fecha caixa, e lanca movimentacoes de cada tipo (CaixaService)', async () => {
  const caixaAberto = admDb().collection('caixas').doc('caixa-fluxo');
  await assertSucceeds(
    caixaAberto.set({
      valorInicial: 100,
      status: 'aberto',
      abertoPorUid: ADM_UID,
      abertoPorNome: 'Admin Teste',
      abertoEm: new Date(),
      valorContado: null,
      valorEsperadoNoFechamento: null,
      diferenca: null,
      fechadoPorUid: null,
      fechadoPorNome: null,
      fechadoEm: null,
      observacaoFechamento: null,
    }),
  );

  await assertSucceeds(admDb().collection('caixas').get());

  await assertSucceeds(
    caixaAberto.collection('movimentacoes').add({
      tipo: 'suprimento',
      valor: 50,
      formaPagamento: null,
      descricao: 'Troco inicial',
      contaReceberAlunoId: null,
      contaReceberId: null,
      contaPagarId: null,
      staffUid: ADM_UID,
      staffNome: 'Admin Teste',
      criadoEm: new Date(),
    }),
  );
  await assertSucceeds(
    caixaAberto.collection('movimentacoes').add({
      tipo: 'retirada',
      valor: -20,
      formaPagamento: null,
      descricao: 'Sangria',
      contaReceberAlunoId: null,
      contaReceberId: null,
      contaPagarId: null,
      staffUid: ADM_UID,
      staffNome: 'Admin Teste',
      criadoEm: new Date(),
    }),
  );
  await assertSucceeds(
    caixaAberto.collection('movimentacoes').add({
      tipo: 'ajuste',
      valor: 5,
      formaPagamento: null,
      descricao: 'Correção',
      contaReceberAlunoId: null,
      contaReceberId: null,
      contaPagarId: null,
      staffUid: ADM_UID,
      staffNome: 'Admin Teste',
      criadoEm: new Date(),
    }),
  );

  await assertSucceeds(
    caixaAberto.set(
      {
        status: 'fechado',
        valorContado: 135,
        valorEsperadoNoFechamento: 135,
        diferenca: 0,
        fechadoPorUid: ADM_UID,
        fechadoPorNome: 'Admin Teste',
        fechadoEm: new Date(),
        observacaoFechamento: null,
      },
      { merge: true },
    ),
  );
});

// ---------------------------------------------------------------------
// Aluno / usuário comum: sem acesso administrativo
// ---------------------------------------------------------------------

test('aluno nao le nem escreve nos 5 modulos administrativos', async () => {
  await assertFails(alunoDb().collection('planos').get());
  await assertFails(
    alunoDb().collection('planos').add({
      nome: 'Hack',
      descricao: null,
      valor: 1,
      duracaoDias: 1,
      ativo: true,
      criadoEm: new Date(),
      atualizadoEm: new Date(),
    }),
  );

  await assertFails(alunoDb().collection('produtos').get());
  await assertFails(
    alunoDb().collection('produtos').add({
      nome: 'Hack',
      codigo: 'X',
      categoria: 'X',
      descricao: null,
      unidadeMedida: 'un',
      precoCusto: 0,
      precoVenda: 0,
      estoqueAtual: 0,
      estoqueMinimo: 0,
      ativo: true,
      fornecedor: null,
      criadoEm: new Date(),
      atualizadoEm: new Date(),
    }),
  );

  await assertFails(alunoDb().collection('contasPagar').get());
  await assertFails(
    alunoDb().collection('contasPagar').add({
      fornecedor: 'Hack',
      descricao: 'Hack',
      categoria: 'Hack',
      valorOriginal: 1,
      desconto: 0,
      jurosMulta: 0,
      vencimento: new Date(),
      status: 'pendente',
      criadoEm: new Date(),
      atualizadoEm: new Date(),
    }),
  );

  await assertFails(alunoDb().collection('caixas').get());
  await assertFails(
    alunoDb().collection('caixas').add({
      valorInicial: 0,
      status: 'aberto',
      abertoPorUid: ALUNO_UID,
      abertoPorNome: 'Aluno Teste',
      abertoEm: new Date(),
    }),
  );
});

test('aluno le a propria conta a receber mas nao a de outro aluno, nem via collectionGroup', async () => {
  await seed(`alunos/${ALUNO_UID}/contasReceber/cr-propria`, {
    alunoId: ALUNO_UID,
    matriculaId: null,
    descricao: 'Mensalidade',
    valorOriginal: 100,
    valorPago: null,
    desconto: 0,
    jurosMulta: 0,
    vencimento: new Date(),
    dataPagamento: null,
    status: 'pendente',
    formaPagamento: null,
    observacao: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });
  await seed(`alunos/${OUTRO_ALUNO_UID}/contasReceber/cr-de-outro`, {
    alunoId: OUTRO_ALUNO_UID,
    matriculaId: null,
    descricao: 'Mensalidade',
    valorOriginal: 100,
    valorPago: null,
    desconto: 0,
    jurosMulta: 0,
    vencimento: new Date(),
    dataPagamento: null,
    status: 'pendente',
    formaPagamento: null,
    observacao: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  });

  await assertSucceeds(
    alunoDb().collection('alunos').doc(ALUNO_UID).collection('contasReceber').doc('cr-propria').get(),
  );
  await assertFails(
    alunoDb()
      .collection('alunos')
      .doc(OUTRO_ALUNO_UID)
      .collection('contasReceber')
      .doc('cr-de-outro')
      .get(),
  );
  await assertFails(alunoDb().collectionGroup('contasReceber').get());
});

// ---------------------------------------------------------------------
// Deslogado: nenhum acesso
// ---------------------------------------------------------------------

test('usuario deslogado nao le nenhum dos 5 modulos administrativos', async () => {
  await assertFails(semAuthDb().collection('planos').get());
  await assertFails(semAuthDb().collection('produtos').get());
  await assertFails(semAuthDb().collection('contasPagar').get());
  await assertFails(semAuthDb().collection('caixas').get());
  await assertFails(semAuthDb().collectionGroup('contasReceber').get());
  await assertFails(
    semAuthDb().collection('alunos').doc(ALUNO_UID).collection('contasReceber').get(),
  );
});
