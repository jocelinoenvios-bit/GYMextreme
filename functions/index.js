'use strict';

const crypto = require('node:crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { calcularStatusAcesso, mensagemNotificacaoMensalidade } = require('./lib/status-acesso');

initializeApp();
const db = getFirestore();

// Janela de validade da autorizacao (segundos) — curta de proposito, pra
// um pulso antigo nunca poder ser reaproveitado (replay).
const VALIDADE_AUTORIZACAO_SEGUNDOS = 10;

/**
 * Camada de Autorizacao da arquitetura da catraca (ver arquitetura
 * publicada — identificacao / autorizacao / acionamento desacoplados).
 *
 * Chamada pelo modulo de identificacao (facial, biometria, QR, NFC...)
 * com o credencialId que aquele leitor resolveu. Nunca conhece hardware
 * de catraca — so decide "pode entrar?" e grava o resultado assinado em
 * `academias/{academiaId}/autorizacoesAcesso`, onde o servico local
 * escuta em tempo real.
 */
exports.solicitarAutorizacaoAcesso = onCall(async (request) => {
  const { credencialId, metodo, academiaId } = request.data || {};
  if (!credencialId || !metodo || !academiaId) {
    throw new HttpsError(
      'invalid-argument',
      'credencialId, metodo e academiaId sao obrigatorios.',
    );
  }

  let autorizado = false;
  let motivoNegacao = null;
  let alunoUid = null;

  const credencialSnap = await db.collection('credenciais').doc(credencialId).get();
  const credencial = credencialSnap.data();

  if (!credencialSnap.exists || credencial.ativo === false || !credencial.alunoUid) {
    motivoNegacao = 'aluno_nao_encontrado';
  } else {
    alunoUid = credencial.alunoUid;
    const alunoSnap = await db.collection('alunos').doc(alunoUid).get();
    const aluno = alunoSnap.data();

    if (!alunoSnap.exists) {
      motivoNegacao = 'aluno_nao_encontrado';
    } else if (aluno.ativo === false) {
      motivoNegacao = 'matricula_inativa';
    } else {
      const proximoVencimento = aluno.proximoVencimento
        ? aluno.proximoVencimento.toDate()
        : null;
      const status = calcularStatusAcesso(proximoVencimento);
      if (!status.podeAcessar) {
        motivoNegacao = 'mensalidade_atrasada';
      } else {
        autorizado = true;
      }
    }
  }

  const agora = new Date();
  const expiraEm = new Date(agora.getTime() + VALIDADE_AUTORIZACAO_SEGUNDOS * 1000);
  const assinatura = crypto.randomBytes(16).toString('hex');

  await db
    .collection('academias')
    .doc(academiaId)
    .collection('autorizacoesAcesso')
    .add({
      autorizado,
      alunoUid,
      academiaId,
      metodo,
      motivoNegacao,
      emitidaEm: FieldValue.serverTimestamp(),
      expiraEm: Timestamp.fromDate(expiraEm),
      assinatura,
      consumida: false,
    });

  // Resposta imediata pra quem chamou (ex.: acender luz verde/vermelha no
  // proprio leitor) — o serviço local reage de forma independente, via
  // listener no documento gravado acima.
  return { autorizado, motivoNegacao };
});

/**
 * Notificacoes automaticas de mensalidade — roda uma vez por dia e manda,
 * pra cada aluno com matricula ativa, a mensagem do fluxo combinado (7/3/0
 * dias antes do vencimento, aviso do 1o dia de atraso, contagem regressiva
 * diaria da tolerancia, ultimo dia, e aviso do bloqueio).
 *
 * Depende de `usuarios/{uid}.fcmTokens` (array) — ainda nao populado pelo
 * app Flutter nesta primeira versao (falta adicionar firebase_messaging
 * no cliente e testar em um dispositivo real antes de habilitar isso pra
 * valer).
 */
exports.enviarNotificacoesMensalidade = onSchedule(
  { schedule: '0 8 * * *', timeZone: 'America/Sao_Paulo' },
  async () => {
    const alunosSnap = await db.collection('alunos').where('ativo', '==', true).get();

    for (const doc of alunosSnap.docs) {
      const aluno = doc.data();
      const proximoVencimento = aluno.proximoVencimento ? aluno.proximoVencimento.toDate() : null;
      const status = calcularStatusAcesso(proximoVencimento);
      const mensagem = mensagemNotificacaoMensalidade(status);
      if (!mensagem) continue;

      const usuarioSnap = await db.collection('usuarios').doc(doc.id).get();
      const tokens = (usuarioSnap.data() || {}).fcmTokens || [];
      if (tokens.length === 0) continue;

      try {
        await getMessaging().sendEachForMulticast({
          tokens,
          notification: { title: 'GYM XTREME', body: mensagem },
        });
      } catch (err) {
        console.error(`Erro ao notificar aluno ${doc.id}:`, err);
      }
    }
  },
);
