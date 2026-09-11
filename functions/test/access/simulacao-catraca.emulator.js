'use strict';

/**
 * FASE 7.2 — Simulação controlada do Control iDFace, SEM equipamento
 * físico conectado (sem cabo de rede, sem roteador, sem o aparelho na
 * rede da academia).
 *
 * Este arquivo NÃO fala com nenhum hardware e NÃO aciona nenhuma catraca
 * de verdade — ele chama `processarEventoIdentificacao` diretamente
 * (a MESMA função que o endpoint HTTP `controlIdNewUserIdentified` usa
 * em produção), fornecendo o payload de entrada como se fosse o
 * dispositivo, e roda inteiramente contra o Firestore Emulator. Nenhuma
 * linha de `access-authorization-service.js`, `access-event-service.js`,
 * `device-auth.js` ou `access-request-handler.js` foi alterada pra isso
 * — a simulação só fornece a entrada e verifica a saída.
 *
 * Isolamento (ver plano aprovado na sessão — Fase 7.2):
 * - Vive só aqui, em `test/access/`, nunca em `index.js` nem em `lib/access/`.
 * - Não existe nenhum "modo simulação" dentro do código de produção —
 *   nada que possa ligar sozinho, por engano, num ambiente real.
 * - `dispositivosAcesso/idface-simulado-teste` é uma fixture só de teste,
 *   nome inconfundível, criada e apagada a cada execução — nunca deve
 *   ser reaproveitada como o dispositivo real quando ele for cadastrado
 *   de verdade (isso será feito via `DeviceSyncService.cadastrarDispositivo`
 *   com um `deviceId` novo).
 * - Onde o resultado seria ALLOW, o "acionamento" é só uma linha de log
 *   com o prefixo `[SIMULAÇÃO]` — nunca existe nenhum comando de
 *   hardware, relé ou GPIO envolvido em lugar nenhum deste arquivo.
 *
 * Uso: npm run test:simulacao:catraca
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via ' +
      '`npm run test:simulacao:catraca` (sobe o Firestore Emulator sozinho) ' +
      'em vez de chamar este arquivo direto. Este arquivo NUNCA deve rodar ' +
      'contra um projeto Firebase real.',
  );
  process.exit(1);
}

const test = require('node:test');
const assert = require('node:assert/strict');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
require('../../index'); // side effect: initializeApp()
const { processarEventoIdentificacao } = require('../../lib/access/access-request-handler');
const { hashToken } = require('../../lib/access/device-auth');
const { MOTIVO_NEGACAO, RESULTADO } = require('../../lib/access/motivos');

const db = getFirestore();

// Nomes deliberadamente inconfundíveis — "simulado"/"teste" em toda parte
// — pra nunca serem confundidos com um cadastro de dispositivo real.
const DEVICE_TOKEN = 'token-simulacao-idface-teste';
const DEVICE_ID = 'idface-simulado-teste';

/**
 * Imprime o "acionamento" — sempre só texto, nunca um comando real.
 * Chamado depois de toda identificação simulada, pra deixar explícito no
 * próprio log dos testes que nenhum hardware é tocado.
 */
function logComandoSimulado(resultado) {
  if (resultado === RESULTADO.ALLOW) {
    console.log('  [SIMULAÇÃO] comando de abertura simulado (nenhum acionamento físico ocorreu)');
  } else {
    console.log('  [SIMULAÇÃO] catraca permaneceria fechada (nenhum acionamento físico ocorreu)');
  }
}

async function limparAluno(uid) {
  if (!uid) return;
  const matriculas = await db.collection('alunos').doc(uid).collection('matriculas').get();
  await Promise.all(matriculas.docs.map((doc) => doc.ref.delete()));
  await db.collection('alunos').doc(uid).delete();
}

async function limparEventos(uuidPrefixo) {
  const snap = await db.collection('eventosAcesso').get();
  await Promise.all(
    snap.docs
      .filter((doc) => (doc.data().uuid || '').startsWith(uuidPrefixo))
      .map((doc) => doc.ref.delete()),
  );
}

async function prepararDispositivoSimulado() {
  await db.collection('dispositivosAcesso').doc(DEVICE_ID).set({
    unidadeId: null,
    tipo: 'idface_simulado',
    nome: 'iDFace (SIMULAÇÃO — Fase 7.2, sem equipamento físico conectado)',
    tokenHash: hashToken(DEVICE_TOKEN),
    ativo: true,
  });
}

/**
 * @param {string} uid
 * @param {{
 *   userIdDispositivo: string,
 *   ativo?: boolean,
 *   bloqueado?: boolean,
 *   comMatriculaAtiva?: boolean,
 * }} opcoes
 */
async function prepararAluno(uid, { userIdDispositivo, ativo = true, bloqueado = false, comMatriculaAtiva = true }) {
  await db.collection('alunos').doc(uid).set({
    ativo,
    bloqueado,
    // Mensalidade sempre em dia nas fixtures desta simulação — cada
    // teste isola exatamente UMA variável (ativo/bloqueado/matrícula),
    // igual à confirmação do TESTE 4 na sessão: "aluno ativo + SEM
    // matrícula ativa/vigente" não deve também estar inadimplente, senão
    // não dá pra saber qual dos dois motivos o teste está provando.
    proximoVencimento: Timestamp.fromDate(new Date(2027, 0, 1)),
  });

  if (comMatriculaAtiva) {
    await db
      .collection('alunos')
      .doc(uid)
      .collection('matriculas')
      .add({ status: 'ativa', dataVencimento: Timestamp.fromDate(new Date(2027, 0, 1)) });
  }

  await db
    .collection('dispositivosAcesso')
    .doc(DEVICE_ID)
    .collection('credenciais')
    .doc(userIdDispositivo)
    .set({ alunoUid: uid });
}

async function identificar(userIdDispositivo, uuidSufixo) {
  const { corpo } = await processarEventoIdentificacao(db, {
    payload: {
      device_id: DEVICE_ID,
      user_id: userIdDispositivo,
      user_name: 'Aluno Simulação',
      uuid: `simulacao-${uuidSufixo}`,
    },
    deviceToken: DEVICE_TOKEN,
  });
  return corpo;
}

test.before(async () => {
  await prepararDispositivoSimulado();
});

test.after(async () => {
  await limparEventos('simulacao-');
  await db.collection('dispositivosAcesso').doc(DEVICE_ID).delete();
});

// ---------------------------------------------------------------------
// TESTE 1 — aluno ativo + matrícula vigente -> ALLOW
// ---------------------------------------------------------------------
test('TESTE 1 — aluno ativo + matrícula vigente -> ALLOW', async () => {
  const uid = 'simulacao-1-ativo';
  await limparAluno(uid);
  await prepararAluno(uid, { userIdDispositivo: 'teste-idface-001' });

  const corpo = await identificar('teste-idface-001', '1');

  assert.equal(corpo.result.event, 7);
  logComandoSimulado(RESULTADO.ALLOW);

  await limparAluno(uid);
});

// ---------------------------------------------------------------------
// TESTE 2 — aluno bloqueado -> DENY / STUDENT_BLOCKED
// ---------------------------------------------------------------------
test('TESTE 2 — aluno bloqueado -> DENY / STUDENT_BLOCKED', async () => {
  const uid = 'simulacao-2-bloqueado';
  await limparAluno(uid);
  await prepararAluno(uid, { userIdDispositivo: 'teste-idface-002', bloqueado: true });

  const corpo = await identificar('teste-idface-002', '2');

  assert.equal(corpo.result.event, 6);
  logComandoSimulado(RESULTADO.DENY);
  const evt = await db.collection('eventosAcesso').where('uuid', '==', 'simulacao-2').get();
  assert.equal(evt.docs[0].data().motivo, MOTIVO_NEGACAO.STUDENT_BLOCKED);

  await limparAluno(uid);
});

// ---------------------------------------------------------------------
// TESTE 3 — aluno inativo -> DENY / STUDENT_INACTIVE
// ---------------------------------------------------------------------
test('TESTE 3 — aluno inativo -> DENY / STUDENT_INACTIVE', async () => {
  const uid = 'simulacao-3-inativo';
  await limparAluno(uid);
  await prepararAluno(uid, { userIdDispositivo: 'teste-idface-003', ativo: false });

  const corpo = await identificar('teste-idface-003', '3');

  assert.equal(corpo.result.event, 6);
  logComandoSimulado(RESULTADO.DENY);
  const evt = await db.collection('eventosAcesso').where('uuid', '==', 'simulacao-3').get();
  assert.equal(evt.docs[0].data().motivo, MOTIVO_NEGACAO.STUDENT_INACTIVE);

  await limparAluno(uid);
});

// ---------------------------------------------------------------------
// TESTE 4 — aluno ativo SEM matrícula ativa/vigente -> DENY / PLAN_EXPIRED
// (confirmado explicitamente na sessão: não é pra alterar essa regra)
// ---------------------------------------------------------------------
test('TESTE 4 — aluno ativo sem matrícula vigente -> DENY / PLAN_EXPIRED', async () => {
  const uid = 'simulacao-4-sem-matricula';
  await limparAluno(uid);
  await prepararAluno(uid, { userIdDispositivo: 'teste-idface-004', comMatriculaAtiva: false });

  const corpo = await identificar('teste-idface-004', '4');

  assert.equal(corpo.result.event, 6);
  logComandoSimulado(RESULTADO.DENY);
  const evt = await db.collection('eventosAcesso').where('uuid', '==', 'simulacao-4').get();
  assert.equal(evt.docs[0].data().motivo, MOTIVO_NEGACAO.PLAN_EXPIRED);

  await limparAluno(uid);
});

// ---------------------------------------------------------------------
// TESTE 5 — ID do iDFace desconhecido -> DENY / STUDENT_NOT_FOUND
// ---------------------------------------------------------------------
test('TESTE 5 — ID do iDFace desconhecido -> DENY / STUDENT_NOT_FOUND', async () => {
  // Nunca cadastrado em dispositivosAcesso/{DEVICE_ID}/credenciais —
  // exatamente o caso "aparelho identificou um rosto que nunca foi
  // vinculado a nenhum aluno".
  const corpo = await identificar('teste-idface-999-desconhecido', '5');

  assert.equal(corpo.result.event, 6);
  logComandoSimulado(RESULTADO.DENY);
  const evt = await db.collection('eventosAcesso').where('uuid', '==', 'simulacao-5').get();
  assert.equal(evt.docs[0].data().motivo, MOTIVO_NEGACAO.STUDENT_NOT_FOUND);
});

// ---------------------------------------------------------------------
// TESTE 6 — identificação válida -> evento registrado corretamente
// ---------------------------------------------------------------------
test('TESTE 6 — identificação válida registra o evento corretamente em eventosAcesso', async () => {
  const uid = 'simulacao-6-evento-allow';
  await limparAluno(uid);
  await prepararAluno(uid, { userIdDispositivo: 'teste-idface-006' });

  await identificar('teste-idface-006', '6');

  const evt = await db.collection('eventosAcesso').where('uuid', '==', 'simulacao-6').get();
  assert.equal(evt.size, 1);
  const dados = evt.docs[0].data();
  assert.equal(dados.resultado, RESULTADO.ALLOW);
  assert.equal(dados.motivo, null);
  assert.equal(dados.alunoUid, uid);
  assert.equal(dados.userIdDispositivo, 'teste-idface-006');
  assert.equal(dados.deviceId, DEVICE_ID);
  assert.equal(dados.metodo, 'FACE'); // control-id-adapter.js: user_id presente => FACE
  assert.ok(dados.criadoEm, 'criadoEm (data/hora) precisa estar preenchido');

  await limparAluno(uid);
});

// ---------------------------------------------------------------------
// TESTE 7 — identificação negada -> evento registrado com motivo
// ---------------------------------------------------------------------
test('TESTE 7 — identificação negada registra o evento com resultado DENY e motivo preenchido', async () => {
  const uid = 'simulacao-7-evento-deny';
  await limparAluno(uid);
  await prepararAluno(uid, { userIdDispositivo: 'teste-idface-007', bloqueado: true });

  await identificar('teste-idface-007', '7');

  const evt = await db.collection('eventosAcesso').where('uuid', '==', 'simulacao-7').get();
  assert.equal(evt.size, 1);
  const dados = evt.docs[0].data();
  assert.equal(dados.resultado, RESULTADO.DENY);
  assert.equal(dados.motivo, MOTIVO_NEGACAO.STUDENT_BLOCKED);
  assert.ok(dados.motivo, 'motivo precisa estar preenchido, nunca null numa negativa');
  assert.equal(dados.alunoUid, uid);
  assert.ok(dados.criadoEm, 'criadoEm (data/hora) precisa estar preenchido');

  await limparAluno(uid);
});
