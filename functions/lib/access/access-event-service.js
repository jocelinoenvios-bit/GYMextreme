'use strict';

const { FieldValue } = require('firebase-admin/firestore');

/**
 * `AccessEventService` (metade pura): monta o registro de uma tentativa
 * de acesso (coleção `eventosAcesso`) a partir dos dados já resolvidos —
 * sem nenhuma dependência do Firestore, testável isolada.
 *
 * @param {{
 *   deviceId?: string|null,
 *   unidadeId?: string|null,
 *   alunoUid?: string|null,
 *   userIdDispositivo?: string|null,
 *   userName?: string|null,
 *   metodo?: string|null,
 *   resultado: 'ALLOW'|'DENY',
 *   motivo?: string|null,
 *   confidence?: number|null,
 *   portalId?: string|null,
 *   uuid?: string|null,
 *   tempoProcessamentoMs?: number|null,
 *   erro?: string|null,
 * }} dados
 */
function construirRegistroEvento(dados) {
  return {
    deviceId: dados.deviceId || null,
    unidadeId: dados.unidadeId || null,
    alunoUid: dados.alunoUid || null,
    userIdDispositivo: dados.userIdDispositivo || null,
    userName: dados.userName || null,
    metodo: dados.metodo || 'UNKNOWN',
    resultado: dados.resultado,
    motivo: dados.motivo || null,
    confidence: dados.confidence == null ? null : dados.confidence,
    portalId: dados.portalId || null,
    uuid: dados.uuid || null,
    tempoProcessamentoMs: dados.tempoProcessamentoMs == null ? null : dados.tempoProcessamentoMs,
    erro: dados.erro || null,
  };
}

/**
 * `AccessEventService` (metade Firestore): grava o evento — idempotente
 * pelo `uuid` do dispositivo quando presente (um evento duplicado com o
 * mesmo `uuid`, ex.: o iDFace reenviando por timeout de rede, não gera
 * um segundo registro; retorna o id do documento já existente em vez de
 * criar outro). Sem `uuid` (payload incompleto), sempre cria um novo
 * registro — não dá pra deduplicar com segurança sem uma chave estável.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {ReturnType<typeof construirRegistroEvento>} registro
 * @returns {Promise<string>} id do documento (novo ou reaproveitado)
 */
async function registrarEvento(db, registro) {
  const colecao = db.collection('eventosAcesso');

  if (registro.uuid) {
    const existente = await colecao.where('uuid', '==', registro.uuid).limit(1).get();
    if (!existente.empty) {
      return existente.docs[0].id;
    }
  }

  const ref = await colecao.add({ ...registro, criadoEm: FieldValue.serverTimestamp() });
  return ref.id;
}

module.exports = { construirRegistroEvento, registrarEvento };
