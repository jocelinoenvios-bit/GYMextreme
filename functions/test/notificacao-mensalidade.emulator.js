'use strict';

/**
 * Teste de integracao de `processarNotificacaoMensalidade` contra o
 * Firestore Emulator — NAO roda no `npm test` normal (sem sufixo
 * `.test.js` de proposito, pra nao ser descoberto por `node --test
 * test/`) e NUNCA chama o Firebase Messaging de verdade: só exercita o
 * caminho sem token FCM (`erro: 'sem_token_fcm'`), que grava o registro em
 * `alunos/{uid}/notificacoesMensalidade` sem tentar nenhum envio.
 *
 * Uso (emulador sobe e desce sozinho, projeto fake, nada de credencial
 * real nem de deploy):
 *
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
const { getFirestore } = require('firebase-admin/firestore');
const { _processarNotificacaoMensalidade: processarNotificacaoMensalidade } = require('../index');
const { idNotificacaoDoDia } = require('../lib/notificacao-mensalidade');

const db = getFirestore();

async function limparAluno(uid) {
  const notifs = await db.collection('alunos').doc(uid).collection('notificacoesMensalidade').get();
  await Promise.all(notifs.docs.map((doc) => doc.ref.delete()));
  await db.collection('alunos').doc(uid).delete();
  await db.collection('usuarios').doc(uid).delete();
}

test('sem fcmTokens: registra a notificacao com erro sem_token_fcm e nao chama o Messaging', async () => {
  const uid = 'aluno-teste-sem-token';
  await limparAluno(uid);

  // Vencimento 3 dias no futuro a partir de "agora" (fixo no teste) —
  // dispara a mensagem "próxima do vencimento" (ver mensagemNotificacaoMensalidade).
  const agora = new Date(2026, 7, 3);
  const vencimento = new Date(2026, 7, 6);
  await db.collection('alunos').doc(uid).set({ ativo: true, proximoVencimento: vencimento });
  // De propósito sem `fcmTokens` em usuarios/{uid} — é exatamente o caso
  // que este teste cobre.
  await db.collection('usuarios').doc(uid).set({ nome: 'Aluno Teste' });

  await processarNotificacaoMensalidade(uid, { ativo: true, proximoVencimento: { toDate: () => vencimento } }, agora);

  const notifId = idNotificacaoDoDia(agora);
  const snap = await db
    .collection('alunos')
    .doc(uid)
    .collection('notificacoesMensalidade')
    .doc(notifId)
    .get();

  assert.equal(snap.exists, true);
  const registro = snap.data();
  assert.equal(registro.enviada, false);
  assert.equal(registro.erro, 'sem_token_fcm');
  assert.equal(registro.tokensAlvo, 0);
  assert.equal(registro.status, 'emDia');
  assert.equal(registro.mensagem, 'Sua mensalidade está próxima do vencimento.');

  // Idempotencia: reprocessar o mesmo dia nao deve sobrescrever/duplicar —
  // alteramos o doc manualmente e confirmamos que uma segunda chamada
  // NAO mexe nele (ela sai cedo por já existir).
  await snap.ref.update({ mensagem: 'marcador-de-que-nao-foi-reprocessado' });
  await processarNotificacaoMensalidade(uid, { ativo: true, proximoVencimento: { toDate: () => vencimento } }, agora);
  const snapDepois = await snap.ref.get();
  assert.equal(snapDepois.data().mensagem, 'marcador-de-que-nao-foi-reprocessado');

  await limparAluno(uid);
});

test('sem mensagem devida hoje: nao registra nada', async () => {
  const uid = 'aluno-teste-sem-notificacao-hoje';
  await limparAluno(uid);

  const agora = new Date(2026, 7, 1);
  const vencimento = new Date(2026, 7, 20); // longe do vencimento, nenhum gatilho de mensagem
  await processarNotificacaoMensalidade(uid, { ativo: true, proximoVencimento: { toDate: () => vencimento } }, agora);

  const notifs = await db.collection('alunos').doc(uid).collection('notificacoesMensalidade').get();
  assert.equal(notifs.empty, true);

  await limparAluno(uid);
});
