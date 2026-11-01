'use strict';

/**
 * Teste de integração do fluxo completo de identificação do iDFace Pro
 * (`processarEventoIdentificacao`) contra o Firestore Emulator — mesmo
 * padrão de `test/notificacao-mensalidade.emulator.js` (extensão
 * `.emulator.js` de propósito, pra não ser descoberto por `node --test
 * test/`; nenhuma chamada de rede real).
 *
 * Cobre os testes 1, 2, 3, 7, 8 e 10 do roteiro de integração (aluno em
 * dia, mensalidade atrasada, aluno inexistente/nunca sincronizado,
 * unidade não permitida, dispositivo não autorizado, evento duplicado).
 *
 * Uso:
 *   npm run test:emulator
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via `npm run test:emulator` ' +
      '(sobe o Firestore Emulator sozinho) em vez de chamar este arquivo direto.',
  );
  process.exit(1);
}

const test = require('node:test');
const assert = require('node:assert/strict');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
require('../../index'); // side effect: initializeApp()
const { processarEventoIdentificacao } = require('../../lib/access/access-request-handler');
const { hashToken } = require('../../lib/access/device-auth');
const { MOTIVO_NEGACAO } = require('../../lib/access/motivos');

const db = getFirestore();

const DEVICE_TOKEN = 'token-teste-idface-1';
const DEVICE_ID = 'idface-teste-1';
const UNIDADE_ID = 'unidade-teste-1';

async function limparTudo(alunoUid) {
  const eventos = await db.collection('eventosAcesso').get();
  await Promise.all(eventos.docs.map((doc) => doc.ref.delete()));

  const credenciais = await db
    .collection('dispositivosAcesso')
    .doc(DEVICE_ID)
    .collection('credenciais')
    .get();
  await Promise.all(credenciais.docs.map((doc) => doc.ref.delete()));
  await db.collection('dispositivosAcesso').doc(DEVICE_ID).delete();

  if (alunoUid) {
    const matriculas = await db.collection('alunos').doc(alunoUid).collection('matriculas').get();
    await Promise.all(matriculas.docs.map((doc) => doc.ref.delete()));
    await db.collection('alunos').doc(alunoUid).delete();
  }
}

async function prepararDispositivo() {
  await db.collection('dispositivosAcesso').doc(DEVICE_ID).set({
    unidadeId: UNIDADE_ID,
    tipo: 'idface_pro',
    tokenHash: hashToken(DEVICE_TOKEN),
    ativo: true,
  });
}

async function prepararAluno(alunoUid, { userIdDispositivo, proximoVencimento, unidadeId, matriculaVencimento }) {
  await db
    .collection('alunos')
    .doc(alunoUid)
    .set({
      ativo: true,
      unidadeId: unidadeId === undefined ? UNIDADE_ID : unidadeId,
      proximoVencimento: proximoVencimento ? Timestamp.fromDate(proximoVencimento) : null,
    });
  await db.collection('alunos').doc(alunoUid).collection('matriculas').add({
    status: 'ativa',
    dataVencimento: Timestamp.fromDate(matriculaVencimento),
  });
  await db
    .collection('dispositivosAcesso')
    .doc(DEVICE_ID)
    .collection('credenciais')
    .doc(userIdDispositivo)
    .set({ alunoUid });
}

test('Teste 1 — aluno em dia: ALLOW, event=7, registra o evento', async () => {
  const alunoUid = 'aluno-teste-em-dia';
  await limparTudo(alunoUid);
  await prepararDispositivo();
  await prepararAluno(alunoUid, {
    userIdDispositivo: '1001',
    proximoVencimento: new Date(2027, 0, 1),
    matriculaVencimento: new Date(2027, 0, 1),
  });

  const { httpStatus, corpo } = await processarEventoIdentificacao(db, {
    payload: { device_id: DEVICE_ID, user_id: '1001', user_name: 'Aluno Em Dia', uuid: 'evento-1' },
    deviceToken: DEVICE_TOKEN,
  });

  assert.equal(httpStatus, 200);
  assert.equal(corpo.result.event, 7);
  // Sem CONTROLID_ACAO_ABERTURA_JSON configurada (não deve estar, neste
  // teste), a lista de ações vem vazia de propósito — ver docstring de
  // `resolverAcoesAbertura` em control-id-adapter.js: nunca assume o
  // comando do relé sem confirmação no equipamento físico.
  assert.deepEqual(corpo.result.actions, []);

  const eventos = await db.collection('eventosAcesso').where('uuid', '==', 'evento-1').get();
  assert.equal(eventos.size, 1);
  assert.equal(eventos.docs[0].data().resultado, 'ALLOW');

  await limparTudo(alunoUid);
});

test('Teste 2 — mensalidade atrasada: DENY, event=6, motivo PAYMENT_OVERDUE', async () => {
  const alunoUid = 'aluno-teste-atrasado';
  await limparTudo(alunoUid);
  await prepararDispositivo();
  await prepararAluno(alunoUid, {
    userIdDispositivo: '1002',
    proximoVencimento: new Date(2020, 0, 1), // bem no passado
    matriculaVencimento: new Date(2027, 0, 1),
  });

  const { corpo } = await processarEventoIdentificacao(db, {
    payload: { device_id: DEVICE_ID, user_id: '1002', uuid: 'evento-2' },
    deviceToken: DEVICE_TOKEN,
  });

  assert.equal(corpo.result.event, 6);
  assert.deepEqual(corpo.result.actions, []);

  const eventos = await db.collection('eventosAcesso').where('uuid', '==', 'evento-2').get();
  assert.equal(eventos.docs[0].data().motivo, MOTIVO_NEGACAO.PAYMENT_OVERDUE);

  await limparTudo(alunoUid);
});

test('Teste 3 — user_id nunca sincronizado (sem credencial): DENY, STUDENT_NOT_FOUND', async () => {
  await limparTudo(null);
  await prepararDispositivo();

  const { corpo } = await processarEventoIdentificacao(db, {
    payload: { device_id: DEVICE_ID, user_id: '9999-nunca-existiu', uuid: 'evento-3' },
    deviceToken: DEVICE_TOKEN,
  });

  assert.equal(corpo.result.event, 6);
  const eventos = await db.collection('eventosAcesso').where('uuid', '==', 'evento-3').get();
  assert.equal(eventos.docs[0].data().motivo, MOTIVO_NEGACAO.STUDENT_NOT_FOUND);

  await limparTudo(null);
});

test('Teste 7 — aluno de outra unidade: DENY, UNIT_NOT_ALLOWED', async () => {
  const alunoUid = 'aluno-teste-outra-unidade';
  await limparTudo(alunoUid);
  await prepararDispositivo();
  await prepararAluno(alunoUid, {
    userIdDispositivo: '1007',
    proximoVencimento: new Date(2027, 0, 1),
    matriculaVencimento: new Date(2027, 0, 1),
    unidadeId: 'unidade-outra',
  });

  const { corpo } = await processarEventoIdentificacao(db, {
    payload: { device_id: DEVICE_ID, user_id: '1007', uuid: 'evento-7' },
    deviceToken: DEVICE_TOKEN,
  });

  assert.equal(corpo.result.event, 6);
  const eventos = await db.collection('eventosAcesso').where('uuid', '==', 'evento-7').get();
  assert.equal(eventos.docs[0].data().motivo, MOTIVO_NEGACAO.UNIT_NOT_ALLOWED);

  await limparTudo(alunoUid);
});

test('Teste 8 — dispositivo não autorizado (token errado): DENY, DEVICE_NOT_AUTHORIZED', async () => {
  await limparTudo(null);
  await prepararDispositivo();

  const { httpStatus, corpo } = await processarEventoIdentificacao(db, {
    payload: { device_id: DEVICE_ID, user_id: '1001', uuid: 'evento-8' },
    deviceToken: 'token-errado',
  });

  assert.equal(httpStatus, 200); // nunca um status diferente de 200 — ver docstring do handler
  assert.equal(corpo.result.event, 6);
  const eventos = await db.collection('eventosAcesso').where('uuid', '==', 'evento-8').get();
  assert.equal(eventos.docs[0].data().motivo, MOTIVO_NEGACAO.DEVICE_NOT_AUTHORIZED);

  await limparTudo(null);
});

test('Teste 10 — evento duplicado (mesmo uuid) não cria um segundo registro', async () => {
  const alunoUid = 'aluno-teste-duplicado';
  await limparTudo(alunoUid);
  await prepararDispositivo();
  await prepararAluno(alunoUid, {
    userIdDispositivo: '1010',
    proximoVencimento: new Date(2027, 0, 1),
    matriculaVencimento: new Date(2027, 0, 1),
  });

  const payload = { device_id: DEVICE_ID, user_id: '1010', uuid: 'evento-duplicado' };
  await processarEventoIdentificacao(db, { payload, deviceToken: DEVICE_TOKEN });
  await processarEventoIdentificacao(db, { payload, deviceToken: DEVICE_TOKEN });
  await processarEventoIdentificacao(db, { payload, deviceToken: DEVICE_TOKEN });

  const eventos = await db.collection('eventosAcesso').where('uuid', '==', 'evento-duplicado').get();
  assert.equal(eventos.size, 1, 'reenvio do mesmo uuid nao pode gerar mais de um evento gravado');

  await limparTudo(alunoUid);
});
