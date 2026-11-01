'use strict';

/**
 * Porteiro local (porteiro-local.js) de ponta a ponta contra o Firestore
 * Emulator: sobe o servidor HTTP de verdade numa porta livre e faz as
 * requisições como o iDFace faria — mesmo pipeline da versão em nuvem.
 *
 * Uso: `npm run test:porteiro` (sobe/derruba o emulador).
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Rode via `npm run test:porteiro`.');
  process.exit(1);
}

const test = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { criarServidor, CAMINHO_EVENTO } = require('../../porteiro-local');
const { hashToken } = require('../../lib/access/device-auth');
const { MOTIVO_NEGACAO } = require('../../lib/access/motivos');

initializeApp({ projectId: 'demo-gymextreme-test' });
const db = getFirestore();

const TOKEN = 'token-porteiro-teste';
const DEVICE = 'idface-porteiro';
const dias = (n) => new Date(Date.now() + n * 24 * 60 * 60 * 1000);

let servidor;
let base;
const linhasDeLog = [];

async function aluno(uid, codigo, { proximoVencimento, matriculaAte }) {
  await db.doc(`alunos/${uid}`).set({ ativo: true, proximoVencimento: Timestamp.fromDate(proximoVencimento) });
  await db.collection(`alunos/${uid}/matriculas`).add({
    status: 'ativa',
    dataVencimento: Timestamp.fromDate(matriculaAte),
  });
  await db.doc(`dispositivosAcesso/${DEVICE}/credenciais/${codigo}`).set({ alunoUid: uid });
}

async function post(caminho, corpo, { token = TOKEN, viaQuery = false } = {}) {
  const url = viaQuery ? `${base}${caminho}?token=${token}` : `${base}${caminho}`;
  const resposta = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(viaQuery ? {} : { 'X-Device-Token': token }) },
    body: typeof corpo === 'string' ? corpo : JSON.stringify(corpo),
  });
  return { status: resposta.status, corpo: await resposta.json() };
}

async function motivoDoEvento(uuid) {
  const snap = await db.collection('eventosAcesso').where('uuid', '==', uuid).get();
  assert.equal(snap.size, 1);
  return snap.docs[0].data().motivo;
}

test.before(async () => {
  await db.doc(`dispositivosAcesso/${DEVICE}`).set({
    unidadeId: 'principal',
    tipo: 'idface_pro',
    tokenHash: hashToken(TOKEN),
    ativo: true,
  });
  await aluno('em-dia', '101', { proximoVencimento: dias(10), matriculaAte: dias(10) });
  await aluno('atrasado', '102', { proximoVencimento: dias(-40), matriculaAte: dias(10) });
  await aluno('matricula-vencida', '103', { proximoVencimento: dias(10), matriculaAte: dias(-2) });

  servidor = criarServidor(db, { log: (linha) => linhasDeLog.push(linha) });
  await new Promise((resolve) => servidor.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${servidor.address().port}`;
});

test.after(async () => {
  await new Promise((resolve) => servidor.close(resolve));
});

test('página de conferência responde no navegador', async () => {
  const resposta = await fetch(`${base}/`);
  assert.equal(resposta.status, 200);
  assert.equal((await resposta.json()).funcionando, true);
});

test('aluno em dia: libera (event 7) e registra o evento', async () => {
  const { status, corpo } = await post(CAMINHO_EVENTO, { device_id: DEVICE, user_id: '101', uuid: 'p-1' });
  assert.equal(status, 200);
  assert.equal(corpo.result.event, 7);
  assert.equal(await motivoDoEvento('p-1'), null);
  assert.ok(linhasDeLog.some((l) => l.includes('LIBERADO') && l.includes('user_id=101')));
});

test('caminho curto do aparelho (new_user_identified.fcgi) com token na URL', async () => {
  const { corpo } = await post('/new_user_identified.fcgi', { device_id: DEVICE, user_id: '101', uuid: 'p-2' }, { viaQuery: true });
  assert.equal(corpo.result.event, 7);
});

test('mensalidade atrasada: nega (event 6)', async () => {
  const { corpo } = await post(CAMINHO_EVENTO, { device_id: DEVICE, user_id: '102', uuid: 'p-3' });
  assert.equal(corpo.result.event, 6);
  assert.equal(await motivoDoEvento('p-3'), MOTIVO_NEGACAO.PAYMENT_OVERDUE);
});

test('matrícula vencida: nega com plano expirado', async () => {
  const { corpo } = await post(CAMINHO_EVENTO, { device_id: DEVICE, user_id: '103', uuid: 'p-4' });
  assert.equal(corpo.result.event, 6);
  assert.equal(await motivoDoEvento('p-4'), MOTIVO_NEGACAO.PLAN_EXPIRED);
});

test('token errado: nega como dispositivo não autorizado', async () => {
  const { corpo } = await post(CAMINHO_EVENTO, { device_id: DEVICE, user_id: '101', uuid: 'p-5' }, { token: 'errado' });
  assert.equal(corpo.result.event, 6);
  assert.equal(await motivoDoEvento('p-5'), MOTIVO_NEGACAO.DEVICE_NOT_AUTHORIZED);
});

test('código sem aluno vinculado: nega', async () => {
  const { corpo } = await post(CAMINHO_EVENTO, { device_id: DEVICE, user_id: '999', uuid: 'p-6' });
  assert.equal(corpo.result.event, 6);
  assert.equal(await motivoDoEvento('p-6'), MOTIVO_NEGACAO.STUDENT_NOT_FOUND);
});

test('corpo que não é JSON: 400, sem registrar nada', async () => {
  const { status } = await post(CAMINHO_EVENTO, 'isto nao e json');
  assert.equal(status, 400);
});

test('caminho desconhecido: 404; "estou vivo" do aparelho: 200', async () => {
  assert.equal((await post('/qualquer', {})).status, 404);
  assert.equal((await post('/device_is_alive.fcgi', {})).status, 200);
});

test('comandos de configuração: acha o aluno pelo e-mail e cria a unidade padrão', async () => {
  const { alunoPorEmail, garantirUnidadePadrao } = require('../../scripts/catraca');
  await db.doc('usuarios/ana').set({ nome: 'Ana', email: 'ana@exemplo.com', role: 'aluno' });
  await db.doc('usuarios/adm').set({ nome: 'ADM', email: 'adm@exemplo.com', role: 'adm' });

  assert.deepEqual(await alunoPorEmail(db, ' ana@exemplo.com '), { uid: 'ana', nome: 'Ana' });
  await assert.rejects(alunoPorEmail(db, 'adm@exemplo.com'), /Nenhum aluno/);

  await garantirUnidadePadrao(db);
  assert.equal((await db.doc('unidades/principal').get()).exists, true);
});
