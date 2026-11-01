'use strict';

const crypto = require('node:crypto');

/**
 * Hash do token de dispositivo — nunca guardamos o token em texto puro
 * no Firestore (`dispositivosAcesso/{id}.tokenHash`), só o hash. Mesma
 * ideia de nunca guardar senha em texto puro.
 * @param {string} token
 */
function hashToken(token) {
  return crypto.createHash('sha256').update(String(token)).digest('hex');
}

/**
 * Resolve e valida o dispositivo que fez a chamada, a partir do token
 * secreto que ele apresentou — gerado na hora do cadastro do dispositivo
 * (ver seção 16 do briefing: "um dispositivo desconhecido não pode
 * enviar eventos"). Este token é uma credencial nossa, independente do
 * login/senha do próprio iDFace na Access API (aquele serve pro sentido
 * contrário: Gym Xtreme chamando o iDFace, ver `DeviceSyncService`,
 * ainda não implementado).
 *
 * A CONFIRMAR NO EQUIPAMENTO: não há confirmação, nesta fase, de que a
 * tela de configuração "Modo Pro/Online" do iDFace Pro permite anexar um
 * header HTTP customizado na chamada de `new_user_identified` — por
 * isso o endpoint aceita o token tanto em um header quanto na própria
 * URL (query string), e a Fase 6/7 (testar comunicação sem catraca)
 * confirma qual das duas opções o aparelho realmente suporta.
 *
 * Token que não bate com nenhum dispositivo cadastrado e ativo retorna
 * `null` — quem chama decide o que responder (nunca lança exceção
 * aqui).
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string|undefined|null} deviceToken
 * @returns {Promise<{ id: string, data: FirebaseFirestore.DocumentData } | null>}
 */
async function resolverDispositivo(db, deviceToken) {
  if (!deviceToken) return null;

  const tokenHash = hashToken(deviceToken);
  const snap = await db
    .collection('dispositivosAcesso')
    .where('tokenHash', '==', tokenHash)
    .where('ativo', '==', true)
    .limit(1)
    .get();

  if (snap.empty) return null;
  const doc = snap.docs[0];
  return { id: doc.id, data: doc.data() };
}

module.exports = { hashToken, resolverDispositivo };
