'use strict';

/**
 * Simulador de iDFace Pro — dispara os cenários de identificação mais
 * importantes contra o Firestore Emulator e imprime a resposta completa
 * (`event`, `message`, `actions`) exatamente como
 * `access-request-handler.js` monta pra devolver ao dispositivo. Serve
 * pra "sentir" o fluxo funcionando de ponta a ponta antes do iDFace Pro
 * físico chegar — não abre nenhuma conexão de rede real, não fala com
 * nenhum equipamento.
 *
 * Uso:
 *   npm run mock:idface
 *
 * (sobe/derruba o Firestore Emulator sozinho, projeto fake — mesmo
 * padrão dos testes em test/access/*.emulator.js)
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via `npm run mock:idface` ' +
      '(sobe o Firestore Emulator sozinho) em vez de chamar este arquivo direto.',
  );
  process.exit(1);
}

const { getFirestore, Timestamp } = require('firebase-admin/firestore');
require('../index'); // side effect: initializeApp()
const { processarEventoIdentificacao } = require('../lib/access/access-request-handler');
const { hashToken } = require('../lib/access/device-auth');

const db = getFirestore();

const DEVICE_TOKEN = 'token-mock-idface';
const DEVICE_ID = 'idface-mock';
const UNIDADE_ID = 'unidade-mock';

async function limpar() {
  const colecoes = ['eventosAcesso'];
  for (const nome of colecoes) {
    const snap = await db.collection(nome).get();
    await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
  }
  const credenciais = await db
    .collection('dispositivosAcesso')
    .doc(DEVICE_ID)
    .collection('credenciais')
    .get();
  await Promise.all(credenciais.docs.map((doc) => doc.ref.delete()));

  for (const uid of ['mock-em-dia', 'mock-atrasado', 'mock-bloqueado', 'mock-outra-unidade']) {
    const matriculas = await db.collection('alunos').doc(uid).collection('matriculas').get();
    await Promise.all(matriculas.docs.map((doc) => doc.ref.delete()));
    await db.collection('alunos').doc(uid).delete();
  }
}

async function preparar() {
  await db.collection('dispositivosAcesso').doc(DEVICE_ID).set({
    unidadeId: UNIDADE_ID,
    tipo: 'idface_pro',
    tokenHash: hashToken(DEVICE_TOKEN),
    ativo: true,
    nome: 'iDFace mock (catraca de teste)',
  });

  const cenarios = [
    {
      uid: 'mock-em-dia',
      userId: '2001',
      nome: 'Ana Adimplente',
      ativo: true,
      bloqueado: false,
      proximoVencimento: new Date(2027, 0, 1),
      unidadeId: UNIDADE_ID,
    },
    {
      uid: 'mock-atrasado',
      userId: '2002',
      nome: 'Bruno Atrasado',
      ativo: true,
      bloqueado: false,
      proximoVencimento: new Date(2020, 0, 1),
      unidadeId: UNIDADE_ID,
    },
    {
      uid: 'mock-bloqueado',
      userId: '2003',
      nome: 'Carla Bloqueada',
      ativo: true,
      bloqueado: true,
      proximoVencimento: new Date(2027, 0, 1),
      unidadeId: UNIDADE_ID,
    },
    {
      uid: 'mock-outra-unidade',
      userId: '2004',
      nome: 'Diego Outra Unidade',
      ativo: true,
      bloqueado: false,
      proximoVencimento: new Date(2027, 0, 1),
      unidadeId: 'unidade-outra',
    },
  ];

  for (const cenario of cenarios) {
    await db.collection('alunos').doc(cenario.uid).set({
      ativo: cenario.ativo,
      bloqueado: cenario.bloqueado,
      unidadeId: cenario.unidadeId,
      proximoVencimento: Timestamp.fromDate(cenario.proximoVencimento),
    });
    await db.collection('alunos').doc(cenario.uid).collection('matriculas').add({
      status: 'ativa',
      dataVencimento: Timestamp.fromDate(new Date(2027, 0, 1)),
    });
    await db
      .collection('dispositivosAcesso')
      .doc(DEVICE_ID)
      .collection('credenciais')
      .doc(cenario.userId)
      .set({ alunoUid: cenario.uid });
  }

  return cenarios;
}

function formatarLinha(rotulo, corpo) {
  const r = corpo.result;
  const status = r.event === 7 ? 'LIBERADO' : 'NEGADO  ';
  const acoes = r.actions.length > 0 ? JSON.stringify(r.actions) : '(nenhuma — ver control-id-adapter.js)';
  return (
    `${status}  event=${r.event}  ${rotulo.padEnd(28)}  ` +
    `"${r.message}"  actions=${acoes}`
  );
}

async function main() {
  await limpar();
  const cenarios = await preparar();

  console.log('\n=== Simulador iDFace Pro — cenários contra o Firestore Emulator ===\n');

  for (const cenario of cenarios) {
    const { corpo } = await processarEventoIdentificacao(db, {
      payload: {
        device_id: DEVICE_ID,
        user_id: cenario.userId,
        user_name: cenario.nome,
        uuid: `mock-${cenario.userId}-${Date.now()}`,
      },
      deviceToken: DEVICE_TOKEN,
    });
    console.log(formatarLinha(cenario.nome, corpo));
  }

  // Cenários que não dependem de aluno nenhum.
  const { corpo: naoSincronizado } = await processarEventoIdentificacao(db, {
    payload: { device_id: DEVICE_ID, user_id: '9999-nunca-sincronizado', uuid: `mock-9999-${Date.now()}` },
    deviceToken: DEVICE_TOKEN,
  });
  console.log(formatarLinha('(user_id nunca sincronizado)', naoSincronizado));

  const { corpo: tokenErrado } = await processarEventoIdentificacao(db, {
    payload: { device_id: DEVICE_ID, user_id: '2001', uuid: `mock-token-errado-${Date.now()}` },
    deviceToken: 'token-invalido',
  });
  console.log(formatarLinha('(token de dispositivo errado)', tokenErrado));

  const { httpStatus } = await processarEventoIdentificacao(db, {
    payload: 'isso-nao-e-um-objeto',
    deviceToken: DEVICE_TOKEN,
  });
  console.log(`HTTP ${httpStatus}                             (payload malformado)`);

  console.log('\n=== Fim da simulação ===\n');

  await limpar();
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Erro no simulador:', err);
    process.exit(1);
  });
