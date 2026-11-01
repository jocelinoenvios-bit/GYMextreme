'use strict';

/**
 * Comprova, contra o Firestore Emulator, a regra nova de
 * `alunos/{uid}/mensagensWhatsapp/{mensagemId}` (auditoria das mensagens
 * automáticas do ciclo de inadimplência/inatividade) — mesmo padrão
 * exato de `notificacoesMensalidade`: só a Cloud Function (Admin SDK)
 * escreve, o app cliente (aluno OU staff) nunca escreve nada aqui.
 *
 * NÃO faz deploy nem toca o projeto real — Firestore Emulator local,
 * projeto fake `demo-gymextreme-test`, mesmo padrão de
 * `firestore-rules-historico-treinos.emulator.js`.
 *
 * Uso: `npm run test:rules:mensagens-whatsapp` (sobe/derruba o emulador
 * sozinho).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via ' +
      '`npm run test:rules:mensagens-whatsapp` (sobe o Firestore Emulator ' +
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
const ADM_UID = 'staff-adm-wa-teste';
const ALUNO_UID = 'aluno-dono-wa-teste';
const OUTRO_ALUNO_UID = 'aluno-outro-wa-teste';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gymextreme-test',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('usuarios').doc(ADM_UID).set({ role: 'adm', nome: 'Admin Teste' });
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

function mensagem() {
  return {
    tipo: 'mensagemRetorno15',
    mensagem: 'Olá! Sentimos sua falta.',
    status: 'sem_optin',
  };
}

test('aluno le a propria mensagem, mas nao a de outro aluno', async () => {
  await seed(`alunos/${ALUNO_UID}/mensagensWhatsapp/msg-1`, mensagem());
  await seed(`alunos/${OUTRO_ALUNO_UID}/mensagensWhatsapp/msg-2`, mensagem());

  await assertSucceeds(
    alunoDb().collection('alunos').doc(ALUNO_UID).collection('mensagensWhatsapp').doc('msg-1').get(),
  );
  await assertFails(
    alunoDb()
      .collection('alunos')
      .doc(OUTRO_ALUNO_UID)
      .collection('mensagensWhatsapp')
      .doc('msg-2')
      .get(),
  );
});

test('ADM/staff le a mensagem de qualquer aluno', async () => {
  await seed(`alunos/${ALUNO_UID}/mensagensWhatsapp/msg-1`, mensagem());

  await assertSucceeds(
    admDb().collection('alunos').doc(ALUNO_UID).collection('mensagensWhatsapp').get(),
  );
});

test('usuario deslogado nao le nenhuma mensagem', async () => {
  await seed(`alunos/${ALUNO_UID}/mensagensWhatsapp/msg-1`, mensagem());

  await assertFails(
    semAuthDb().collection('alunos').doc(ALUNO_UID).collection('mensagensWhatsapp').get(),
  );
});

test('NINGUEM escreve — nem o proprio aluno, nem outro aluno, nem ADM (so a Cloud Function via Admin SDK)', async () => {
  await assertFails(
    alunoDb().collection('alunos').doc(ALUNO_UID).collection('mensagensWhatsapp').add(mensagem()),
  );
  await assertFails(
    outroAlunoDb()
      .collection('alunos')
      .doc(ALUNO_UID)
      .collection('mensagensWhatsapp')
      .add(mensagem()),
  );
  await assertFails(
    admDb().collection('alunos').doc(ALUNO_UID).collection('mensagensWhatsapp').add(mensagem()),
  );
});
