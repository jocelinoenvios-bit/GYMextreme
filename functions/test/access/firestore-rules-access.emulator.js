'use strict';

/**
 * Comprova, contra o Firestore Emulator, as regras das coleções novas da
 * integração com dispositivos de controle de acesso facial (iDFace
 * Pro/Control iD): `dispositivosAcesso` (+ subcoleção `credenciais`),
 * `eventosAcesso` e `unidades`. Mesmo padrão de
 * `test/firestore-rules-admin.emulator.js` — sobe um Firestore Emulator
 * local, projeto fake, nada de deploy nem credencial real.
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

const RULES_PATH = path.join(__dirname, '..', '..', '..', 'firestore.rules');
const ADM_UID = 'staff-adm-teste-access';
const ALUNO_UID = 'aluno-comum-teste-access';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gymextreme-test',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('usuarios').doc(ADM_UID).set({ role: 'adm', nome: 'Admin Teste' });
    await db.collection('usuarios').doc(ALUNO_UID).set({ role: 'aluno', nome: 'Aluno Teste' });
    await db.collection('dispositivosAcesso').doc('device-1').set({
      unidadeId: 'unidade-1',
      tipo: 'idface_pro',
      tokenHash: 'hash-fake',
      ativo: true,
    });
    await db
      .collection('dispositivosAcesso')
      .doc('device-1')
      .collection('credenciais')
      .doc('1001')
      .set({ alunoUid: ALUNO_UID });
    await db.collection('eventosAcesso').doc('evento-1').set({ resultado: 'ALLOW' });
    await db.collection('unidades').doc('unidade-1').set({ nome: 'Unidade Centro', ativo: true });
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

// ---------------------------------------------------------------------
// dispositivosAcesso — só leitura pra staff, escrita sempre bloqueada
// pro app cliente (só a Cloud Function, via Admin SDK, escreve)
// ---------------------------------------------------------------------

test('ADM le um dispositivo cadastrado e a credencial dele', async () => {
  const db = admDb();
  await assertSucceeds(db.collection('dispositivosAcesso').doc('device-1').get());
  await assertSucceeds(
    db.collection('dispositivosAcesso').doc('device-1').collection('credenciais').doc('1001').get(),
  );
});

test('ADM NAO consegue escrever direto em dispositivosAcesso (só a Cloud Function pode)', async () => {
  const db = admDb();
  await assertFails(db.collection('dispositivosAcesso').doc('device-2').set({ ativo: true }));
});

test('ADM NAO consegue escrever direto na subcolecao de credenciais', async () => {
  const db = admDb();
  await assertFails(
    db
      .collection('dispositivosAcesso')
      .doc('device-1')
      .collection('credenciais')
      .doc('1002')
      .set({ alunoUid: 'qualquer' }),
  );
});

test('aluno nao le dispositivosAcesso', async () => {
  const db = alunoDb();
  await assertFails(db.collection('dispositivosAcesso').doc('device-1').get());
});

test('usuario deslogado nao le dispositivosAcesso', async () => {
  const db = semAuthDb();
  await assertFails(db.collection('dispositivosAcesso').doc('device-1').get());
});

// ---------------------------------------------------------------------
// eventosAcesso — mesmo padrao: leitura só pra staff, nunca escreve pelo
// cliente (log imutável)
// ---------------------------------------------------------------------

test('ADM le o historico de eventos de acesso', async () => {
  const db = admDb();
  await assertSucceeds(db.collection('eventosAcesso').doc('evento-1').get());
});

test('ADM NAO consegue escrever/editar eventosAcesso direto', async () => {
  const db = admDb();
  await assertFails(db.collection('eventosAcesso').doc('evento-2').set({ resultado: 'ALLOW' }));
  await assertFails(db.collection('eventosAcesso').doc('evento-1').update({ resultado: 'DENY' }));
});

test('aluno nao le eventosAcesso', async () => {
  const db = alunoDb();
  await assertFails(db.collection('eventosAcesso').doc('evento-1').get());
});

// ---------------------------------------------------------------------
// unidades — staff le, só ADM (via gerenciarFuncionarios) escreve
// ---------------------------------------------------------------------

test('ADM le e cria/edita unidades', async () => {
  const db = admDb();
  await assertSucceeds(db.collection('unidades').doc('unidade-1').get());
  await assertSucceeds(
    db.collection('unidades').doc('unidade-2').set({ nome: 'Unidade Norte', ativo: true }),
  );
});

test('aluno le unidades mas nao escreve', async () => {
  const db = alunoDb();
  await assertFails(db.collection('unidades').doc('unidade-1').get());
});

test('usuario deslogado nao le nem escreve unidades', async () => {
  const db = semAuthDb();
  await assertFails(db.collection('unidades').doc('unidade-1').get());
  await assertFails(db.collection('unidades').doc('unidade-3').set({ nome: 'X' }));
});
