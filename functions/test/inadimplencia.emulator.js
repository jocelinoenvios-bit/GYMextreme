'use strict';

/**
 * Teste de integração de `processarCicloInadimplencia` contra o
 * Firestore Emulator — mesmo padrão de
 * `notificacao-mensalidade.emulator.js`: NÃO roda no `npm test` normal
 * (sem sufixo `.test.js` de propósito) e nunca chama a Cloud API da Meta
 * de verdade (sem `WHATSAPP_CLOUD_API_TOKEN` configurado, o stub em
 * `lib/whatsapp/whatsapp-sender.js` sempre devolve "não enviado" sem
 * nenhuma chamada de rede).
 *
 * Uso (emulador sobe e desce sozinho, projeto fake, nada de credencial
 * real nem de deploy):
 *
 *   npm run test:emulator:inadimplencia
 */

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    'FIRESTORE_EMULATOR_HOST nao definido — rode via ' +
      '`npm run test:emulator:inadimplencia` (sobe o Firestore Emulator ' +
      'sozinho) em vez de chamar este arquivo direto.',
  );
  process.exit(1);
}

const test = require('node:test');
const assert = require('node:assert/strict');
const { getFirestore } = require('firebase-admin/firestore');
const { _processarCicloInadimplencia: processarCicloInadimplencia } = require('../index');
const { idMensagemWhatsapp, DIAS_INATIVACAO, DIAS_MENSAGEM_REATIVACAO } = require('../lib/inadimplencia');

const db = getFirestore();

function ts(date) {
  return { toDate: () => date };
}

async function limparAluno(uid) {
  const msgs = await db.collection('alunos').doc(uid).collection('mensagensWhatsapp').get();
  await Promise.all(msgs.docs.map((doc) => doc.ref.delete()));
  await db.collection('alunos').doc(uid).delete();
  await db.collection('usuarios').doc(uid).delete();
}

test('TESTE 10: aluno sem whatsapp — registra sem_whatsapp, nao quebra a automacao', async () => {
  const uid = 'aluno-ht-sem-whatsapp';
  await limparAluno(uid);
  await db.collection('usuarios').doc(uid).set({ nome: 'Aluno Teste' });

  const vencimento = new Date(2026, 7, 1);
  const agora = new Date(2026, 7, 16); // 15 dias de atraso
  const aluno = { ativo: true, proximoVencimento: ts(vencimento), whatsapp: null };

  await processarCicloInadimplencia(uid, aluno, agora);

  const msgRef = db
    .collection('alunos')
    .doc(uid)
    .collection('mensagensWhatsapp')
    .doc(idMensagemWhatsapp('mensagemRetorno15', vencimento));
  const snap = await msgRef.get();
  assert.equal(snap.exists, true);
  assert.equal(snap.data().status, 'sem_whatsapp');

  await limparAluno(uid);
});

test('TESTE 11: aluno com whatsapp mas sem opt-in — registra sem_optin, nunca envia', async () => {
  const uid = 'aluno-ht-sem-optin';
  await limparAluno(uid);
  await db.collection('usuarios').doc(uid).set({ nome: 'Aluno Teste' });

  const vencimento = new Date(2026, 7, 1);
  const agora = new Date(2026, 7, 16);
  const aluno = {
    ativo: true,
    proximoVencimento: ts(vencimento),
    whatsapp: '11999998888',
    whatsappOptIn: false,
  };

  await processarCicloInadimplencia(uid, aluno, agora);

  const msgRef = db
    .collection('alunos')
    .doc(uid)
    .collection('mensagensWhatsapp')
    .doc(idMensagemWhatsapp('mensagemRetorno15', vencimento));
  const snap = await msgRef.get();
  assert.equal(snap.data().status, 'sem_optin');

  await limparAluno(uid);
});

test('TESTE 12: mesma mensagem nao e duplicada quando o status ja e definitivo (sem_optin)', async () => {
  const uid = 'aluno-ht-idempotente';
  await limparAluno(uid);
  await db.collection('usuarios').doc(uid).set({ nome: 'Aluno Teste' });

  const vencimento = new Date(2026, 7, 1);
  const agora = new Date(2026, 7, 16);
  const aluno = {
    ativo: true,
    proximoVencimento: ts(vencimento),
    whatsapp: '11999998888',
    whatsappOptIn: false,
  };

  await processarCicloInadimplencia(uid, aluno, agora);
  const msgRef = db
    .collection('alunos')
    .doc(uid)
    .collection('mensagensWhatsapp')
    .doc(idMensagemWhatsapp('mensagemRetorno15', vencimento));

  // Marca manualmente pra provar que a segunda chamada nao regravou.
  await msgRef.update({ mensagem: 'marcador-de-que-nao-foi-reprocessado' });
  await processarCicloInadimplencia(uid, aluno, agora);

  const snapDepois = await msgRef.get();
  assert.equal(snapDepois.data().mensagem, 'marcador-de-que-nao-foi-reprocessado');

  await limparAluno(uid);
});

test('falha da automacao (status erro) e reprocessada na proxima execucao', async () => {
  const uid = 'aluno-ht-retry';
  await limparAluno(uid);
  await db.collection('usuarios').doc(uid).set({ nome: 'Aluno Teste' });

  const vencimento = new Date(2026, 7, 1);
  const agora = new Date(2026, 7, 16);
  // Com whatsapp + opt-in, mas sem token da Meta configurado — o stub
  // sempre devolve `erro: 'integracao_pendente'`, então o status grava
  // como 'erro' (elegível pra retry), nunca como terminal.
  const aluno = {
    ativo: true,
    proximoVencimento: ts(vencimento),
    whatsapp: '11999998888',
    whatsappOptIn: true,
  };

  await processarCicloInadimplencia(uid, aluno, agora);
  const msgRef = db
    .collection('alunos')
    .doc(uid)
    .collection('mensagensWhatsapp')
    .doc(idMensagemWhatsapp('mensagemRetorno15', vencimento));
  const primeiraTentativa = await msgRef.get();
  assert.equal(primeiraTentativa.data().status, 'erro');

  await msgRef.update({ mensagem: 'marcador-que-deve-ser-sobrescrito' });
  await processarCicloInadimplencia(uid, aluno, agora);
  const segundaTentativa = await msgRef.get();
  assert.notEqual(segundaTentativa.data().mensagem, 'marcador-que-deve-ser-sobrescrito');

  await limparAluno(uid);
});

test('TESTE 5/6: 30 dias de atraso inativa o aluno sem apagar nada, e a partir dai segue o ciclo de 45 dias', async () => {
  const uid = 'aluno-ht-inativacao';
  await limparAluno(uid);
  await db.collection('usuarios').doc(uid).set({ nome: 'Aluno Teste' });

  const vencimento = new Date(2026, 7, 1);
  const agora30 = new Date(vencimento.getTime() + DIAS_INATIVACAO * 24 * 60 * 60 * 1000);
  await db.collection('alunos').doc(uid).set({ ativo: true, proximoVencimento: vencimento });

  await processarCicloInadimplencia(uid, { ativo: true, proximoVencimento: ts(vencimento) }, agora30);

  const alunoSnap = await db.collection('alunos').doc(uid).get();
  assert.equal(alunoSnap.data().ativo, false);
  assert.ok(alunoSnap.data().dataInativacao);

  // Nenhuma mensagem de WhatsApp e criada so por causa da inativacao —
  // so o campo do aluno muda.
  const msgs = await db.collection('alunos').doc(uid).collection('mensagensWhatsapp').get();
  assert.equal(msgs.empty, true);

  // Reprocessar no MESMO dia com o estado real (ativo=false) que o
  // Firestore agora tem nao inativa de novo nem manda mensagem antes dos
  // 45 dias — simula a proxima execucao diaria lendo o documento ja
  // atualizado.
  const dataInativacao = alunoSnap.data().dataInativacao.toDate();
  await processarCicloInadimplencia(
    uid,
    { ativo: false, dataInativacao: ts(dataInativacao) },
    new Date(dataInativacao.getTime() + 1 * 24 * 60 * 60 * 1000),
  );
  const msgsDepois = await db.collection('alunos').doc(uid).collection('mensagensWhatsapp').get();
  assert.equal(msgsDepois.empty, true);

  // Aos 45 dias de inatividade, a segunda mensagem e gerada.
  const agora45 = new Date(dataInativacao.getTime() + DIAS_MENSAGEM_REATIVACAO * 24 * 60 * 60 * 1000);
  await processarCicloInadimplencia(uid, { ativo: false, dataInativacao: ts(dataInativacao) }, agora45);
  const msgRef45 = db
    .collection('alunos')
    .doc(uid)
    .collection('mensagensWhatsapp')
    .doc(idMensagemWhatsapp('mensagemReativacao45', dataInativacao));
  const snap45 = await msgRef45.get();
  assert.equal(snap45.exists, true);
  assert.equal(snap45.data().tipo, 'mensagemReativacao45');

  await limparAluno(uid);
});
