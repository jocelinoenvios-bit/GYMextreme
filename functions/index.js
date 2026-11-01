'use strict';

const crypto = require('node:crypto');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { calcularStatusAcesso, mensagemNotificacaoMensalidade } = require('./lib/status-acesso');
const {
  construirRegistroNotificacao,
  idNotificacaoDoDia,
} = require('./lib/notificacao-mensalidade');
const {
  idMensagemWhatsapp,
  avaliarCicloInadimplencia,
  montarMensagemWhatsapp,
} = require('./lib/inadimplencia');
const { enviarTemplateWhatsapp } = require('./lib/whatsapp/whatsapp-sender');
const { processarEventoIdentificacao } = require('./lib/access/access-request-handler');

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
 * Identifica a mensalidade de um aluno e, se hoje for dia de notificar
 * (7/3/0 dias antes do vencimento, avisos de tolerancia, bloqueio),
 * registra a notificacao em
 * `alunos/{alunoUid}/notificacoesMensalidade/{AAAA-MM-DD}` e tenta o envio
 * push pros tokens salvos em `usuarios/{alunoUid}.fcmTokens`.
 *
 * Idempotente por dia: se o documento de hoje ja existe (reexecucao do
 * agendador, retry, reprocessamento manual), nao registra de novo nem
 * reenvia o push. Sem token nenhum, ainda registra a notificacao (auditoria
 * de que ela foi gerada) marcada como `erro: 'sem_token_fcm'`, sem chamar o
 * Messaging.
 *
 * @param {string} alunoUid
 * @param {FirebaseFirestore.DocumentData} aluno dados de `alunos/{alunoUid}`
 * @param {Date} [agora]
 */
async function processarNotificacaoMensalidade(alunoUid, aluno, agora) {
  const proximoVencimento = aluno.proximoVencimento ? aluno.proximoVencimento.toDate() : null;
  const status = calcularStatusAcesso(proximoVencimento, agora);
  const mensagem = mensagemNotificacaoMensalidade(status);
  if (!mensagem) return;

  const notifRef = db
    .collection('alunos')
    .doc(alunoUid)
    .collection('notificacoesMensalidade')
    .doc(idNotificacaoDoDia(agora));

  const jaRegistrada = await notifRef.get();
  if (jaRegistrada.exists) return;

  const usuarioSnap = await db.collection('usuarios').doc(alunoUid).get();
  const tokens = (usuarioSnap.data() || {}).fcmTokens || [];
  const registro = construirRegistroNotificacao(status, mensagem, tokens.length);

  if (tokens.length === 0) {
    await notifRef.set({ ...registro, geradaEm: FieldValue.serverTimestamp() });
    return;
  }

  try {
    const resposta = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: 'GYM XTREME', body: mensagem },
    });
    registro.enviada = resposta.successCount > 0;
    registro.tokensComFalha = resposta.failureCount;
  } catch (err) {
    console.error(`Erro ao notificar aluno ${alunoUid}:`, err);
    registro.erro = String((err && err.message) || err);
  }

  await notifRef.set({ ...registro, geradaEm: FieldValue.serverTimestamp() });
}

/**
 * Notificacoes automaticas de mensalidade — roda uma vez por dia e, pra
 * cada aluno com matricula ativa, identifica quem esta proximo do
 * vencimento ou ja vencido e processa a notificacao correspondente (ver
 * `processarNotificacaoMensalidade`).
 */
exports.enviarNotificacoesMensalidade = onSchedule(
  { schedule: '0 8 * * *', timeZone: 'America/Sao_Paulo' },
  async () => {
    const alunosSnap = await db.collection('alunos').where('ativo', '==', true).get();
    const agora = new Date();

    for (const doc of alunosSnap.docs) {
      await processarNotificacaoMensalidade(doc.id, doc.data(), agora);
    }
  },
);

// Exportado só pra teste (ver test/notificacao-mensalidade.emulator.js, que
// roda contra o Firestore Emulator) — nao faz parte da API publica das functions.
exports._processarNotificacaoMensalidade = processarNotificacaoMensalidade;

/**
 * Ciclo de inadimplência/inatividade de UM aluno (15/30/45 dias, ver
 * `lib/inadimplencia.js`): manda a mensagem de retorno de 15 dias,
 * inativa aos 30, ou manda a segunda tentativa de contato aos 45 dias de
 * inatividade — nunca mais que uma dessas por execução (ver
 * `avaliarCicloInadimplencia`).
 *
 * Idempotente por evento (chave determinística em
 * `alunos/{alunoUid}/mensagensWhatsapp/{tipo}_{AAAA-MM-DD}`, mesmo truque
 * de `idNotificacaoDoDia` acima): reexecutar não duplica nem reenvia uma
 * mensagem que já teve `status` diferente de `'erro'`. Uma falha de API
 * (`status: 'erro'`) fica elegível pra nova tentativa na próxima
 * execução — só sucesso, "sem WhatsApp" e "sem opt-in" são definitivos.
 *
 * Inativar (`ativo: false`) é idempotente por natureza: na próxima
 * execução o aluno já não entra mais na consulta `ativo == true`.
 *
 * @param {string} alunoUid
 * @param {FirebaseFirestore.DocumentData} aluno dados de `alunos/{alunoUid}`
 * @param {Date} [agora]
 */
async function processarCicloInadimplencia(alunoUid, aluno, agora) {
  agora = agora || new Date();
  const proximoVencimento = aluno.proximoVencimento ? aluno.proximoVencimento.toDate() : null;
  const dataInativacao = aluno.dataInativacao ? aluno.dataInativacao.toDate() : null;

  const acao = avaliarCicloInadimplencia(
    { ativo: aluno.ativo !== false, proximoVencimento, dataInativacao },
    agora,
  );
  if (acao.tipo === 'nenhuma') return;

  const alunoRef = db.collection('alunos').doc(alunoUid);

  if (acao.tipo === 'inativar') {
    // NÃO cobra retroativamente os meses de afastamento: só marca o
    // status. `proximoVencimento`/histórico de pagamentos/matrículas/
    // avaliações/treinos/anamnese continuam intactos — a reativação (ver
    // `AlunoService.reativarAluno`) é quem define o próximo vencimento,
    // sempre a partir da data da reativação, nunca do vencimento antigo.
    await alunoRef.set(
      { ativo: false, dataInativacao: Timestamp.fromDate(agora) },
      { merge: true },
    );
    return;
  }

  // A partir daqui: 'mensagemRetorno15' ou 'mensagemReativacao45'.
  const dataReferencia =
    acao.tipo === 'mensagemRetorno15' ? acao.vencimentoReferencia : acao.dataInativacao;
  const msgRef = alunoRef
    .collection('mensagensWhatsapp')
    .doc(idMensagemWhatsapp(acao.tipo, dataReferencia));

  const jaProcessada = await msgRef.get();
  if (jaProcessada.exists && (jaProcessada.data() || {}).status !== 'erro') return;

  const usuarioSnap = await db.collection('usuarios').doc(alunoUid).get();
  const nome = (usuarioSnap.data() || {}).nome || null;

  const registroBase = {
    tipo: acao.tipo,
    mensagem: montarMensagemWhatsapp(acao.tipo, nome),
    vencimentoReferencia: Timestamp.fromDate(dataReferencia),
    geradaEm: FieldValue.serverTimestamp(),
  };

  if (!aluno.whatsapp) {
    await msgRef.set({ ...registroBase, status: 'sem_whatsapp' });
    return;
  }
  if (aluno.whatsappOptIn !== true) {
    await msgRef.set({ ...registroBase, status: 'sem_optin' });
    return;
  }

  try {
    const resultado = await enviarTemplateWhatsapp({
      telefone: aluno.whatsapp,
      template: acao.tipo,
      parametros: [nome || ''],
    });
    if (resultado.enviado) {
      await msgRef.set({
        ...registroBase,
        status: 'enviada',
        whatsappMessageId: resultado.whatsappMessageId || null,
      });
    } else {
      await msgRef.set({
        ...registroBase,
        status: 'erro',
        erro: resultado.erro || 'falha_desconhecida',
      });
    }
  } catch (err) {
    console.error(`Erro ao enviar WhatsApp pro aluno ${alunoUid}:`, err);
    await msgRef.set({ ...registroBase, status: 'erro', erro: String((err && err.message) || err) });
  }
}

/**
 * Automação diária de inadimplência/inatividade — roda 30 minutos depois
 * de `enviarNotificacoesMensalidade` (evita concorrência entre os dois
 * jobs), varre alunos ativos (checa 15/30 dias) e alunos já inativos
 * (checa 45 dias de afastamento) separadamente, e processa cada um pela
 * mesma regra 15/30/45 (ver `processarCicloInadimplencia`).
 */
exports.processarAutomacaoInadimplencia = onSchedule(
  { schedule: '30 8 * * *', timeZone: 'America/Sao_Paulo' },
  async () => {
    const agora = new Date();

    const ativosSnap = await db.collection('alunos').where('ativo', '==', true).get();
    for (const doc of ativosSnap.docs) {
      await processarCicloInadimplencia(doc.id, doc.data(), agora);
    }

    const inativosSnap = await db.collection('alunos').where('ativo', '==', false).get();
    for (const doc of inativosSnap.docs) {
      await processarCicloInadimplencia(doc.id, doc.data(), agora);
    }
  },
);

// Exportado só pra teste (ver test/inadimplencia.emulator.js) — nao faz
// parte da API publica das functions.
exports._processarCicloInadimplencia = processarCicloInadimplencia;

/**
 * Endpoint chamado pelo iDFace Pro (Control iD) a cada identificação
 * facial — equivalente, do ponto de vista do dispositivo, ao
 * `new_user_identified.fcgi` da Access API. Ver
 * `lib/access/access-request-handler.js` pra toda a lógica de
 * autenticação do dispositivo, decisão de acesso e registro do evento
 * — este arquivo só faz a ponte HTTP (ler o corpo/token da requisição,
 * responder com o status/corpo que o handler decidiu).
 *
 * Exposto via Firebase Hosting em
 * `/api/integrations/controlid/events/new-user-identified` (ver rewrite
 * em `firebase.json`) — a URL "crua" da própria Cloud Function também
 * funciona, mas o rewrite dá um caminho estável, independente da região
 * de deploy.
 *
 * Autenticação do dispositivo: token secreto em `X-Device-Token` (header)
 * OU `?token=` (query string) — ver docstring de
 * `lib/access/device-auth.js` pra por que os dois caminhos existem
 * (A CONFIRMAR NO EQUIPAMENTO qual o "Modo Pro/Online" do iDFace
 * realmente suporta).
 */
exports.controlIdNewUserIdentified = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  const deviceToken = req.get('X-Device-Token') || req.query.token || null;

  const { httpStatus, corpo } = await processarEventoIdentificacao(db, {
    payload: req.body,
    deviceToken,
  });

  res.status(httpStatus).json(corpo || { error: 'invalid_payload' });
});
