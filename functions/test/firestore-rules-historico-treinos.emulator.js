'use strict';

/**
 * Comprova, contra o Firestore Emulator, a regra nova de
 * `alunos/{uid}/historicoTreinos/{registroId}` (registro de
 * presença/falta de um treino prescrito) — e faz uma regressão rápida da
 * regra vizinha `alunos/{uid}/treinos/{treinoId}`, que não foi tocada
 * nesta mudança mas fica logo ao lado dela no arquivo.
 *
 * Cobre exatamente os requisitos pedidos:
 * - aluno lê só o próprio historicoTreinos, nunca o de outro aluno;
 * - aluno nunca cria/edita/exclui um registro de presença (mesmo o
 *   próprio) — só o staff com `criarTreinos`/`editarTreinos` pode;
 * - ADM (acesso total) e funcionário com a permissão granular
 *   continuam funcionando; funcionário SEM essa permissão continua
 *   bloqueado (testa o caso granular, não só "é staff" — `ehAdm()`
 *   nunca checa a lista `permissoes`, então só testar ADM não provaria
 *   que `temPermissao('criarTreinos')` está lendo a lista certa).
 *
 * NÃO faz deploy nem toca o projeto real — mesmo padrão de
 * `test/firestore-rules-admin.emulator.js`: Firestore Emulator local,
 * projeto fake `demo-gymextreme-test`, `@firebase/rules-unit-testing`
 * trocando a identidade autenticada a cada chamada.
 *
 * Uso: `npm run test:rules:historico-treinos` (sobe/derruba o emulador
 * sozinho).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via ' +
      '`npm run test:rules:historico-treinos` (sobe o Firestore Emulator ' +
      'sozinho) em vez de chamar este arquivo direto.',
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
const ADM_UID = 'staff-adm-ht-teste';
const FUNCIONARIO_COM_PERMISSAO_UID = 'staff-func-com-permissao-ht-teste';
const FUNCIONARIO_SEM_PERMISSAO_UID = 'staff-func-sem-permissao-ht-teste';
const ALUNO_UID = 'aluno-dono-ht-teste';
const OUTRO_ALUNO_UID = 'aluno-outro-ht-teste';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gymextreme-test',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('usuarios').doc(ADM_UID).set({ role: 'adm', nome: 'Admin Teste' });
    await db
      .collection('usuarios')
      .doc(FUNCIONARIO_COM_PERMISSAO_UID)
      .set({
        role: 'funcionario',
        nome: 'Funcionário Com Permissão',
        permissoes: ['criarTreinos', 'editarTreinos'],
      });
    await db
      .collection('usuarios')
      .doc(FUNCIONARIO_SEM_PERMISSAO_UID)
      .set({
        role: 'funcionario',
        nome: 'Funcionário Sem Permissão',
        // Tem OUTRAS permissoes de staff, mas nenhuma de treino — prova
        // que a regra checa a permissao especifica, nao "e funcionario".
        permissoes: ['acessarProdutos'],
      });
    await db.collection('usuarios').doc(ALUNO_UID).set({ role: 'aluno', nome: 'Aluno Dono' });
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

function funcionarioComPermissaoDb() {
  return testEnv.authenticatedContext(FUNCIONARIO_COM_PERMISSAO_UID).firestore();
}

function funcionarioSemPermissaoDb() {
  return testEnv.authenticatedContext(FUNCIONARIO_SEM_PERMISSAO_UID).firestore();
}

function alunoDb() {
  return testEnv.authenticatedContext(ALUNO_UID).firestore();
}

function outroAlunoDb() {
  return testEnv.authenticatedContext(OUTRO_ALUNO_UID).firestore();
}

function semAuthDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seed(docPath, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(docPath).set(data);
  });
}

function registroPresenca({ status = 'realizado' } = {}) {
  return {
    treinoId: 'treino-a',
    data: new Date(),
    diaSemana: 1,
    status,
    observacoes: null,
    registradoPorUid: ADM_UID,
    registradoPorNome: 'Admin Teste',
    registradoEm: new Date(),
  };
}

// ---------------------------------------------------------------------
// Regressão rápida: a ficha prescrita (`treinos`), vizinha da regra
// nova, continua exatamente como antes.
// ---------------------------------------------------------------------

test('regressao: aluno le a propria ficha de treino, staff sem permissao de treino nao escreve', async () => {
  await seed(`alunos/${ALUNO_UID}/treinos/treino-a`, {
    nome: 'Treino A',
    letra: 'A',
    grupoMuscular: 'Peito',
    ordem: 0,
    ativo: true,
    exercicios: [],
    diaSemana: 1,
    objetivo: null,
    vigenciaAte: null,
  });

  await assertSucceeds(
    alunoDb().collection('alunos').doc(ALUNO_UID).collection('treinos').doc('treino-a').get(),
  );
  await assertFails(
    outroAlunoDb().collection('alunos').doc(ALUNO_UID).collection('treinos').doc('treino-a').get(),
  );
  await assertFails(
    funcionarioSemPermissaoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('treinos')
      .doc('treino-a')
      .set({ nome: 'Hack', letra: 'A', ordem: 0, ativo: true, exercicios: [] }),
  );
  await assertSucceeds(
    funcionarioComPermissaoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('treinos')
      .doc('treino-a')
      .set(
        { nome: 'Treino A (ajustado)', letra: 'A', ordem: 0, ativo: true, exercicios: [] },
        { merge: true },
      ),
  );
});

// ---------------------------------------------------------------------
// historicoTreinos — leitura
// ---------------------------------------------------------------------

test('aluno le o proprio historicoTreinos, mas nao o de outro aluno', async () => {
  await seed(`alunos/${ALUNO_UID}/historicoTreinos/reg-1`, registroPresenca());
  await seed(`alunos/${OUTRO_ALUNO_UID}/historicoTreinos/reg-2`, registroPresenca());

  await assertSucceeds(
    alunoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .doc('reg-1')
      .get(),
  );
  await assertSucceeds(
    alunoDb().collection('alunos').doc(ALUNO_UID).collection('historicoTreinos').get(),
  );

  await assertFails(
    alunoDb()
      .collection('alunos')
      .doc(OUTRO_ALUNO_UID)
      .collection('historicoTreinos')
      .doc('reg-2')
      .get(),
  );
  await assertFails(
    alunoDb().collection('alunos').doc(OUTRO_ALUNO_UID).collection('historicoTreinos').get(),
  );
});

test('ADM e staff com permissao leem o historicoTreinos de qualquer aluno', async () => {
  await seed(`alunos/${ALUNO_UID}/historicoTreinos/reg-1`, registroPresenca());

  await assertSucceeds(
    admDb().collection('alunos').doc(ALUNO_UID).collection('historicoTreinos').get(),
  );
  await assertSucceeds(
    funcionarioComPermissaoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .get(),
  );
  // Staff generico (sem NENHUMA permissao de treino) ainda assim e
  // "ehStaff()" — a leitura usa o mesmo `ehStaff()` generico que
  // `treinos`/`avaliacoes` ja usam, so a ESCRITA e granular.
  await assertSucceeds(
    funcionarioSemPermissaoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .get(),
  );
});

test('usuario deslogado nao le historicoTreinos de ninguem', async () => {
  await seed(`alunos/${ALUNO_UID}/historicoTreinos/reg-1`, registroPresenca());

  await assertFails(
    semAuthDb().collection('alunos').doc(ALUNO_UID).collection('historicoTreinos').get(),
  );
});

// ---------------------------------------------------------------------
// historicoTreinos — o ALUNO nunca escreve (create/update/delete)
// ---------------------------------------------------------------------

test('aluno NUNCA cria o proprio registro de presenca (bloqueia frequencia fraudada)', async () => {
  await assertFails(
    alunoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .add(registroPresenca({ status: 'realizado' })),
  );
});

test('aluno NUNCA edita um registro de presenca ja existente, nem o proprio', async () => {
  await seed(`alunos/${ALUNO_UID}/historicoTreinos/reg-1`, registroPresenca({ status: 'falta' }));

  await assertFails(
    alunoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .doc('reg-1')
      .set({ status: 'realizado' }, { merge: true }),
  );
});

test('aluno NUNCA exclui um registro de presenca', async () => {
  await seed(`alunos/${ALUNO_UID}/historicoTreinos/reg-1`, registroPresenca());

  await assertFails(
    alunoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .doc('reg-1')
      .delete(),
  );
});

// ---------------------------------------------------------------------
// historicoTreinos — staff com a permissao de treino cria/edita/exclui
// ---------------------------------------------------------------------

test('ADM cria, edita e exclui um registro de presenca', async () => {
  const ref = admDb()
    .collection('alunos')
    .doc(ALUNO_UID)
    .collection('historicoTreinos')
    .doc('reg-adm');

  await assertSucceeds(ref.set(registroPresenca({ status: 'realizado' })));
  await assertSucceeds(ref.set({ status: 'falta' }, { merge: true }));
  await assertSucceeds(ref.delete());
});

test('funcionario com criarTreinos/editarTreinos cria, edita e exclui um registro de presenca', async () => {
  const ref = funcionarioComPermissaoDb()
    .collection('alunos')
    .doc(ALUNO_UID)
    .collection('historicoTreinos')
    .doc('reg-func');

  await assertSucceeds(ref.set(registroPresenca({ status: 'falta' })));
  await assertSucceeds(ref.set({ status: 'realizado' }, { merge: true }));
  await assertSucceeds(ref.delete());
});

test('funcionario SEM criarTreinos/editarTreinos nao cria, nao edita e nao exclui', async () => {
  await seed(`alunos/${ALUNO_UID}/historicoTreinos/reg-bloqueado`, registroPresenca());

  await assertFails(
    funcionarioSemPermissaoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .add(registroPresenca()),
  );
  await assertFails(
    funcionarioSemPermissaoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .doc('reg-bloqueado')
      .set({ status: 'realizado' }, { merge: true }),
  );
  await assertFails(
    funcionarioSemPermissaoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('historicoTreinos')
      .doc('reg-bloqueado')
      .delete(),
  );
});

test('usuario deslogado nao cria nem escreve historicoTreinos', async () => {
  await assertFails(
    semAuthDb().collection('alunos').doc(ALUNO_UID).collection('historicoTreinos').add(
      registroPresenca(),
    ),
  );
});
