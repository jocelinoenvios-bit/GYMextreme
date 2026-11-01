'use strict';

/**
 * Comprova, contra o Firestore Emulator, a correção do bug de
 * auto-escalonamento de privilégio em `usuarios/{uid}`: antes, qualquer
 * conta com a permissão `gerenciarFuncionarios` podia reescrever
 * QUALQUER campo do PRÓPRIO documento (inclusive `role`), porque a
 * regra de `update` não excluía esse caso — abrindo caminho pra um
 * `funcionario` se auto-promover a `adm` via SDK direto, contornando a
 * UI (que nunca oferece essa ação, mas isso não protege o banco).
 *
 * NÃO faz deploy nem toca o projeto real — Firestore Emulator local,
 * projeto fake `demo-gymextreme-test`, mesmo padrão de
 * `firestore-rules-admin.emulator.js`.
 *
 * Uso: `npm run test:rules:usuarios-escalonamento`
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via ' +
      '`npm run test:rules:usuarios-escalonamento` (sobe o Firestore ' +
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
const ADM_UID = 'adm-esc-teste';
const FUNCIONARIO_COM_GERENCIAR_UID = 'func-com-gerenciar-esc-teste';
const FUNCIONARIO_SEM_GERENCIAR_UID = 'func-sem-gerenciar-esc-teste';
const OUTRO_FUNCIONARIO_UID = 'outro-func-esc-teste';
const ALUNO_UID = 'aluno-esc-teste';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gymextreme-test',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
  });
});

test.beforeEach(async () => {
  // Reseta os documentos de usuarios antes de CADA teste — vários
  // testes tentam mutar o próprio documento do editor, então o estado
  // precisa voltar ao original a cada vez.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db
      .collection('usuarios')
      .doc(ADM_UID)
      .set({ role: 'adm', nome: 'Admin Teste', permissoes: [] });
    await db
      .collection('usuarios')
      .doc(FUNCIONARIO_COM_GERENCIAR_UID)
      .set({
        role: 'funcionario',
        nome: 'Funcionário Com Gerenciar',
        permissoes: ['gerenciarFuncionarios'],
      });
    await db
      .collection('usuarios')
      .doc(FUNCIONARIO_SEM_GERENCIAR_UID)
      .set({
        role: 'funcionario',
        nome: 'Funcionário Sem Gerenciar',
        permissoes: ['acessarProdutos'],
      });
    await db
      .collection('usuarios')
      .doc(OUTRO_FUNCIONARIO_UID)
      .set({
        role: 'funcionario',
        nome: 'Outro Funcionário',
        permissoes: ['acessarProdutos'],
      });
    await db
      .collection('usuarios')
      .doc(ALUNO_UID)
      .set({ role: 'aluno', nome: 'Aluno Teste' });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

function dbAs(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

// ---------------------------------------------------------------------
// 1) Usuário comum (aluno) tentando alterar o próprio role
// ---------------------------------------------------------------------

test('aluno NUNCA consegue alterar o próprio role, mesmo via merge parcial', async () => {
  await assertFails(
    dbAs(ALUNO_UID)
      .collection('usuarios')
      .doc(ALUNO_UID)
      .set({ role: 'adm' }, { merge: true }),
  );
});

// ---------------------------------------------------------------------
// 2) Funcionário com gerenciarFuncionarios tentando virar ADM (a si
//    mesmo) — o CERNE do bug corrigido.
// ---------------------------------------------------------------------

test('funcionário com gerenciarFuncionarios NÃO consegue promover a SI MESMO a adm', async () => {
  await assertFails(
    dbAs(FUNCIONARIO_COM_GERENCIAR_UID)
      .collection('usuarios')
      .doc(FUNCIONARIO_COM_GERENCIAR_UID)
      .set({ role: 'adm' }, { merge: true }),
  );
});

test('funcionário com gerenciarFuncionarios NÃO consegue conceder a si mesmo mais permissões', async () => {
  await assertFails(
    dbAs(FUNCIONARIO_COM_GERENCIAR_UID)
      .collection('usuarios')
      .doc(FUNCIONARIO_COM_GERENCIAR_UID)
      .set({ permissoes: ['gerenciarFuncionarios', 'financeiro', 'acessarControleCaixa'] }, { merge: true }),
  );
});

test('funcionário com gerenciarFuncionarios só pode tocar o PRÓPRIO doc via fcmTokens (self-service já existente)', async () => {
  await assertSucceeds(
    dbAs(FUNCIONARIO_COM_GERENCIAR_UID)
      .collection('usuarios')
      .doc(FUNCIONARIO_COM_GERENCIAR_UID)
      .set({ fcmTokens: ['token-1'] }, { merge: true }),
  );
});

// ---------------------------------------------------------------------
// 3) ADM alterando funcionário — continua funcionando livremente,
//    inclusive promovendo outro pra adm (autoridade adequada).
// ---------------------------------------------------------------------

test('ADM altera role/permissões de QUALQUER funcionário livremente', async () => {
  await assertSucceeds(
    dbAs(ADM_UID)
      .collection('usuarios')
      .doc(FUNCIONARIO_SEM_GERENCIAR_UID)
      .set({ permissoes: ['acessarProdutos', 'gerenciarFuncionarios'] }, { merge: true }),
  );
  await assertSucceeds(
    dbAs(ADM_UID)
      .collection('usuarios')
      .doc(FUNCIONARIO_SEM_GERENCIAR_UID)
      .set({ role: 'adm' }, { merge: true }),
  );
});

test('ADM continua podendo editar o PRÓPRIO documento livremente (já é o privilégio máximo, sem risco de escalonamento)', async () => {
  await assertSucceeds(
    dbAs(ADM_UID)
      .collection('usuarios')
      .doc(ADM_UID)
      .set({ nome: 'Admin Renomeado' }, { merge: true }),
  );
});

// ---------------------------------------------------------------------
// 4) Funcionário alterando OUTRO funcionário conforme suas permissões
//    — continua funcionando (é o fluxo real de
//    FuncionarioService.atualizarPermissoes), só não pode tocar `role`.
// ---------------------------------------------------------------------

test('funcionário com gerenciarFuncionarios altera PERMISSÕES de outro funcionário (fluxo real de atualizarPermissoes)', async () => {
  await assertSucceeds(
    dbAs(FUNCIONARIO_COM_GERENCIAR_UID)
      .collection('usuarios')
      .doc(OUTRO_FUNCIONARIO_UID)
      .set({ permissoes: ['acessarProdutos', 'acessarEstoque'] }, { merge: true }),
  );
});

test('funcionário com gerenciarFuncionarios NÃO pode promover um TERCEIRO a adm (não é adm)', async () => {
  await assertFails(
    dbAs(FUNCIONARIO_COM_GERENCIAR_UID)
      .collection('usuarios')
      .doc(OUTRO_FUNCIONARIO_UID)
      .set({ role: 'adm' }, { merge: true }),
  );
});

test('funcionário SEM gerenciarFuncionarios não altera nenhum outro usuário', async () => {
  await assertFails(
    dbAs(FUNCIONARIO_SEM_GERENCIAR_UID)
      .collection('usuarios')
      .doc(OUTRO_FUNCIONARIO_UID)
      .set({ permissoes: ['financeiro'] }, { merge: true }),
  );
});

// ---------------------------------------------------------------------
// 5) Tentativa de alterar campos sensíveis por quem não devia
// ---------------------------------------------------------------------

test('usuário deslogado nunca escreve em usuarios/{uid} nenhum', async () => {
  await assertFails(
    testEnv
      .unauthenticatedContext()
      .firestore()
      .collection('usuarios')
      .doc(ALUNO_UID)
      .set({ role: 'adm' }, { merge: true }),
  );
});

test('regressão: qualquer usuário autenticado continua podendo atualizar o próprio fcmTokens', async () => {
  await assertSucceeds(
    dbAs(ALUNO_UID)
      .collection('usuarios')
      .doc(ALUNO_UID)
      .set({ fcmTokens: ['token-aluno'] }, { merge: true }),
  );
});
