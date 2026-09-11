'use strict';

/**
 * Comprova, contra o Firestore Emulator, a correção da permissão
 * `avaliacoesFisicas`: antes, `alunos/{uid}/avaliacoes` e o campo
 * `anamnese` (embutido em `alunos/{uid}`) eram protegidos só por
 * `ehStaff()` genérico — a permissão granular existia no catálogo mas
 * nunca era checada nem na UI nem no banco. Evolução física usa a MESMA
 * subcoleção `avaliacoes`, então esta correção cobre os três módulos.
 *
 * NÃO faz deploy nem toca o projeto real — Firestore Emulator local,
 * projeto fake `demo-gymextreme-test`, mesmo padrão dos demais arquivos
 * `firestore-rules-*.emulator.js`.
 *
 * Uso: `npm run test:rules:avaliacoes-anamnese`
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via ' +
      '`npm run test:rules:avaliacoes-anamnese` (sobe o Firestore ' +
      'Emulator sozinho) em vez de chamar este arquivo direto.',
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
const ADM_UID = 'adm-av-teste';
const FUNCIONARIO_COM_PERMISSAO_UID = 'func-com-av-teste';
const FUNCIONARIO_SEM_PERMISSAO_UID = 'func-sem-av-teste';
const ALUNO_UID = 'aluno-dono-av-teste';
const OUTRO_ALUNO_UID = 'aluno-outro-av-teste';

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
        permissoes: ['avaliacoesFisicas'],
      });
    await db
      .collection('usuarios')
      .doc(FUNCIONARIO_SEM_PERMISSAO_UID)
      .set({
        role: 'funcionario',
        nome: 'Funcionário Sem Permissão',
        // Tem OUTRAS permissoes de staff, mas nao avaliacoesFisicas —
        // prova que a regra checa a permissao especifica, nao "e staff".
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

function dbAs(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function seed(docPath, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(docPath).set(data);
  });
}

function avaliacao() {
  return { data: new Date(), pesoKg: 80, alturaM: 1.8, circunferenciasCm: {} };
}

// ---------------------------------------------------------------------
// Avaliações físicas (e, por extensão, Evolução Física — mesma
// subcoleção)
// ---------------------------------------------------------------------

test('funcionário SEM avaliacoesFisicas não pode LER avaliações de nenhum aluno', async () => {
  await seed(`alunos/${ALUNO_UID}/avaliacoes/av-1`, avaliacao());

  await assertFails(
    dbAs(FUNCIONARIO_SEM_PERMISSAO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('avaliacoes')
      .get(),
  );
});

test('funcionário SEM avaliacoesFisicas não pode CRIAR avaliação', async () => {
  await assertFails(
    dbAs(FUNCIONARIO_SEM_PERMISSAO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('avaliacoes')
      .add(avaliacao()),
  );
});

test('funcionário SEM avaliacoesFisicas não pode EDITAR uma avaliação existente', async () => {
  await seed(`alunos/${ALUNO_UID}/avaliacoes/av-1`, avaliacao());

  await assertFails(
    dbAs(FUNCIONARIO_SEM_PERMISSAO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('avaliacoes')
      .doc('av-1')
      .set({ pesoKg: 999 }, { merge: true }),
  );
});

test('aluno NUNCA edita a própria avaliação (somente leitura)', async () => {
  await seed(`alunos/${ALUNO_UID}/avaliacoes/av-1`, avaliacao());

  await assertFails(
    dbAs(ALUNO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('avaliacoes')
      .doc('av-1')
      .set({ pesoKg: 999 }, { merge: true }),
  );
});

test('aluno lê a própria avaliação, mas NÃO acessa a de outro aluno', async () => {
  await seed(`alunos/${ALUNO_UID}/avaliacoes/av-1`, avaliacao());
  await seed(`alunos/${OUTRO_ALUNO_UID}/avaliacoes/av-2`, avaliacao());

  await assertSucceeds(
    dbAs(ALUNO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('avaliacoes')
      .doc('av-1')
      .get(),
  );
  await assertFails(
    dbAs(ALUNO_UID)
      .collection('alunos')
      .doc(OUTRO_ALUNO_UID)
      .collection('avaliacoes')
      .doc('av-2')
      .get(),
  );
});

test('usuário autorizado (funcionário com avaliacoesFisicas, e ADM) continua lendo/criando/editando normalmente', async () => {
  await assertSucceeds(
    dbAs(FUNCIONARIO_COM_PERMISSAO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('avaliacoes')
      .add(avaliacao()),
  );
  await assertSucceeds(
    dbAs(FUNCIONARIO_COM_PERMISSAO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('avaliacoes')
      .get(),
  );
  await assertSucceeds(
    dbAs(ADM_UID).collection('alunos').doc(ALUNO_UID).collection('avaliacoes').add(avaliacao()),
  );
});

// ---------------------------------------------------------------------
// Anamnese — campo embutido em alunos/{uid} (não subcoleção)
// ---------------------------------------------------------------------

test('funcionário SEM avaliacoesFisicas não pode escrever no campo anamnese', async () => {
  await seed(`alunos/${ALUNO_UID}`, { telefone: '11999998888' });

  await assertFails(
    dbAs(FUNCIONARIO_SEM_PERMISSAO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .set({ anamnese: { diasPorSemana: 4 } }, { merge: true }),
  );
});

test('funcionário COM avaliacoesFisicas escreve no campo anamnese normalmente', async () => {
  await seed(`alunos/${ALUNO_UID}`, { telefone: '11999998888' });

  await assertSucceeds(
    dbAs(FUNCIONARIO_COM_PERMISSAO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .set({ anamnese: { diasPorSemana: 4 } }, { merge: true }),
  );
});

test('aluno NUNCA escreve na própria anamnese (somente leitura)', async () => {
  await seed(`alunos/${ALUNO_UID}`, { telefone: '11999998888' });

  await assertFails(
    dbAs(ALUNO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .set({ anamnese: { diasPorSemana: 4 } }, { merge: true }),
  );
});

test('regressão: funcionário SEM avaliacoesFisicas continua editando dados cadastrais normalmente (campo != anamnese)', async () => {
  await seed(`alunos/${ALUNO_UID}`, { telefone: '11999998888' });

  await assertSucceeds(
    dbAs(FUNCIONARIO_SEM_PERMISSAO_UID)
      .collection('alunos')
      .doc(ALUNO_UID)
      .set({ telefone: '11987654321' }, { merge: true }),
  );
});

test('regressão: cadastrar um aluno novo continua funcionando (create não exige avaliacoesFisicas)', async () => {
  const uid = 'aluno-novo-av-teste';
  await assertSucceeds(
    dbAs(FUNCIONARIO_SEM_PERMISSAO_UID)
      .collection('alunos')
      .doc(uid)
      .set({ telefone: '11999998888', cadastradoPorUid: FUNCIONARIO_SEM_PERMISSAO_UID }),
  );
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('alunos').doc(uid).delete();
  });
});
