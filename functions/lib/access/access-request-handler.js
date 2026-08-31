'use strict';

const { FieldValue } = require('firebase-admin/firestore');
const { controlIdAccessProvider } = require('./control-id-adapter');
const { resolverDispositivo } = require('./device-auth');
const { avaliarAcesso } = require('./access-authorization-service');
const { construirRegistroEvento, registrarEvento } = require('./access-event-service');
const { mensagemParaMotivo } = require('./mensagens');
const { MOTIVO_NEGACAO, RESULTADO } = require('./motivos');
const { resolverIntervaloMinimoMs, passouIntervaloMinimo } = require('./rate-limit');

/**
 * Um payload é "utilizável" se for um objeto simples (nunca `null`,
 * array, string solta etc.) — não precisa ter nenhum campo específico
 * preenchido (isso quem decide é `provider.interpretarEvento`), só
 * precisa dar pra tentar interpretar. Requisição fora disso nem chega a
 * virar um evento — 400 direto, sem gastar leitura nenhuma no Firestore
 * (ver seção 16 do briefing: "validação de payload").
 * @param {unknown} payload
 */
function payloadUtilizavel(payload) {
  return payload != null && typeof payload === 'object' && !Array.isArray(payload);
}

/**
 * Nega o acesso direto, sem chamar `AccessAuthorizationService` — usado
 * pros casos que nem chegam a virar uma decisão sobre o aluno (device
 * não autorizado, credencial corrompida, rate limit). Sempre registra o
 * evento e monta a resposta no formato do provider, exatamente como o
 * caminho normal.
 */
async function negarDireto(db, { provider, evento, dispositivo, motivo, inicio }) {
  await registrarEvento(
    db,
    construirRegistroEvento({
      deviceId: dispositivo ? dispositivo.id : evento.deviceId,
      unidadeId: dispositivo ? dispositivo.data.unidadeId : null,
      userIdDispositivo: evento.userIdDispositivo,
      userName: evento.userName,
      metodo: evento.metodo,
      resultado: RESULTADO.DENY,
      motivo,
      confidence: evento.confidence,
      portalId: evento.portalId,
      uuid: evento.uuid,
      tempoProcessamentoMs: Date.now() - inicio,
    }),
  );

  return {
    httpStatus: 200,
    corpo: provider.construirResposta({
      resultado: RESULTADO.DENY,
      userIdDispositivo: evento.userIdDispositivo,
      userName: evento.userName,
      portalId: evento.portalId,
      mensagem: mensagemParaMotivo(motivo),
    }),
  };
}

/**
 * Processa um evento de identificação de ponta a ponta: resolve o
 * dispositivo (`DeviceAuth`), interpreta o payload
 * (`AccessControlProvider`, por padrão `controlIdAccessProvider` — ver
 * `access-control-provider.js` pro contrato), localiza o aluno, decide
 * ALLOW/DENY (`AccessAuthorizationService`) e registra o evento
 * (`AccessEventService`) — devolve só o que o endpoint HTTP precisa pra
 * responder. Nunca lança: qualquer erro inesperado vira `SYSTEM_ERROR`,
 * pro dispositivo sempre receber uma resposta válida (nunca travar
 * esperando).
 *
 * Sempre responde HTTP 200 pra qualquer requisição com payload
 * utilizável — mesmo em negativa (`event: 6` no corpo, no caso do
 * Control iD). A segurança de "nunca abrir sem autorização" está
 * inteiramente no corpo da resposta, nunca no status HTTP: como o
 * comportamento exato do firmware do iDFace diante de um status
 * diferente de 200 não está confirmado (A CONFIRMAR NO EQUIPAMENTO),
 * essa é a escolha que garante falha seguindo pro lado fechado (nunca
 * aberto) em qualquer cenário. A única exceção é um payload que nem dá
 * pra interpretar (`400`, ver `payloadUtilizavel`) — nesse caso não tem
 * corpo de resposta nenhum pra montar.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{
 *   payload: unknown,
 *   deviceToken: string|null|undefined,
 *   provider?: import('./access-control-provider').AccessControlProvider,
 * }} entrada
 * @returns {Promise<{ httpStatus: number, corpo: Record<string, unknown>|null }>}
 */
async function processarEventoIdentificacao(db, { payload, deviceToken, provider }) {
  provider = provider || controlIdAccessProvider;

  if (!payloadUtilizavel(payload)) {
    return { httpStatus: 400, corpo: null };
  }

  const inicio = Date.now();
  const evento = provider.interpretarEvento(payload);

  try {
    const dispositivo = await resolverDispositivo(db, deviceToken);
    if (!dispositivo) {
      return negarDireto(db, {
        provider,
        evento,
        dispositivo: null,
        motivo: MOTIVO_NEGACAO.DEVICE_NOT_AUTHORIZED,
        inicio,
      });
    }

    const intervaloMinimoMs = resolverIntervaloMinimoMs();
    const ultimaComunicacaoTimestamp = dispositivo.data.ultimaComunicacaoEm;
    const permitidoPeloRateLimit = passouIntervaloMinimo({
      ultimaComunicacaoEm: ultimaComunicacaoTimestamp ? ultimaComunicacaoTimestamp.toDate() : null,
      agora: new Date(),
      intervaloMinimoMs,
    });
    if (!permitidoPeloRateLimit) {
      return negarDireto(db, {
        provider,
        evento,
        dispositivo,
        motivo: MOTIVO_NEGACAO.RATE_LIMITED,
        inicio,
      });
    }

    let alunoUid = null;
    let motivoForcado = null;

    if (evento.userIdDispositivo) {
      const credencialSnap = await db
        .collection('dispositivosAcesso')
        .doc(dispositivo.id)
        .collection('credenciais')
        .doc(evento.userIdDispositivo)
        .get();

      if (credencialSnap.exists) {
        alunoUid = credencialSnap.data().alunoUid || null;
        if (!alunoUid) motivoForcado = MOTIVO_NEGACAO.INVALID_CREDENTIAL;
      }
      // Sem documento de credencial: alunoUid continua null, e
      // `avaliarAcesso` decide STUDENT_NOT_FOUND — dispositivo nunca
      // teve esse usuario sincronizado (ver `DeviceSyncService`).
    }

    let aluno = null;
    let matriculaAtiva = null;

    if (alunoUid && !motivoForcado) {
      const alunoSnap = await db.collection('alunos').doc(alunoUid).get();
      if (!alunoSnap.exists) {
        // A credencial aponta pra um aluno que nao existe (mais) —
        // referencia quebrada, diferente de "nunca sincronizado".
        motivoForcado = MOTIVO_NEGACAO.INVALID_CREDENTIAL;
      } else {
        aluno = alunoSnap.data();
        const matriculasSnap = await db
          .collection('alunos')
          .doc(alunoUid)
          .collection('matriculas')
          .where('status', '==', 'ativa')
          .limit(1)
          .get();
        if (!matriculasSnap.empty) {
          matriculaAtiva = matriculasSnap.docs[0].data();
        }
      }
    }

    // Atualiza o "ultima vez que este dispositivo falou com a gente" —
    // usado pelo health check (seção 18) e pelo rate limit acima —
    // independente do resultado da decisao.
    await db
      .collection('dispositivosAcesso')
      .doc(dispositivo.id)
      .set({ ultimaComunicacaoEm: FieldValue.serverTimestamp() }, { merge: true });

    if (motivoForcado) {
      return negarDireto(db, { provider, evento, dispositivo, motivo: motivoForcado, inicio });
    }

    const decisao = avaliarAcesso({
      aluno,
      matriculaAtiva,
      dispositivo: dispositivo.data,
      agora: new Date(),
    });

    await registrarEvento(
      db,
      construirRegistroEvento({
        deviceId: dispositivo.id,
        unidadeId: dispositivo.data.unidadeId,
        alunoUid,
        userIdDispositivo: evento.userIdDispositivo,
        userName: evento.userName,
        metodo: evento.metodo,
        resultado: decisao.resultado,
        motivo: decisao.motivo,
        confidence: evento.confidence,
        portalId: evento.portalId,
        uuid: evento.uuid,
        tempoProcessamentoMs: Date.now() - inicio,
      }),
    );

    return {
      httpStatus: 200,
      corpo: provider.construirResposta({
        resultado: decisao.resultado,
        userIdDispositivo: evento.userIdDispositivo,
        userName: evento.userName,
        portalId: evento.portalId,
        mensagem:
          decisao.resultado === RESULTADO.ALLOW
            ? 'Acesso liberado'
            : mensagemParaMotivo(decisao.motivo),
      }),
    };
  } catch (err) {
    console.error('Erro ao processar evento de identificacao:', err);
    try {
      await registrarEvento(
        db,
        construirRegistroEvento({
          deviceId: evento.deviceId,
          userIdDispositivo: evento.userIdDispositivo,
          userName: evento.userName,
          metodo: evento.metodo,
          resultado: RESULTADO.DENY,
          motivo: MOTIVO_NEGACAO.SYSTEM_ERROR,
          confidence: evento.confidence,
          portalId: evento.portalId,
          uuid: evento.uuid,
          tempoProcessamentoMs: Date.now() - inicio,
          erro: String((err && err.message) || err),
        }),
      );
    } catch (erroAoRegistrar) {
      console.error('Erro ao registrar evento de SYSTEM_ERROR:', erroAoRegistrar);
    }

    return {
      httpStatus: 200,
      corpo: provider.construirResposta({
        resultado: RESULTADO.DENY,
        userIdDispositivo: evento.userIdDispositivo,
        userName: evento.userName,
        portalId: evento.portalId,
        mensagem: mensagemParaMotivo(MOTIVO_NEGACAO.SYSTEM_ERROR),
      }),
    };
  }
}

module.exports = { processarEventoIdentificacao, payloadUtilizavel };
