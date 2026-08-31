'use strict';

const crypto = require('node:crypto');
const { FieldValue } = require('firebase-admin/firestore');
const { hashToken } = require('./device-auth');

/**
 * `DeviceSyncService` — responsável pela sincronização entre o Gym
 * Xtreme e os dispositivos de identificação (iDFace Pro/Control iD e,
 * futuramente, outros).
 *
 * Este arquivo tem DOIS tipos de método bem diferentes, de propósito:
 *
 * 1. Os que só mexem no NOSSO Firestore (cadastrar um dispositivo,
 *    vincular/desvincular uma credencial) — totalmente reais,
 *    executáveis e testados agora, sem precisar do equipamento físico.
 *
 * 2. Os que precisariam falar com a Access API do próprio iDFace
 *    (criar o usuário no aparelho, cadastrar o rosto) — ainda NÃO
 *    implementados. Eles existem aqui só como assinatura/documentação
 *    do que vai ser preciso, e sempre lançam um erro explícito se
 *    chamados. Não fingem funcionar: implementar de verdade depende de
 *    confirmar no equipamento físico (Fase de validação física) como a
 *    Access API cria usuário/cadastra biometria — algo que não dá pra
 *    fazer sem o aparelho em mãos nem foi possível confirmar na
 *    documentação primária (bloqueio de rede neste ambiente).
 */

const TAMANHO_TOKEN_BYTES = 24;

/**
 * Cadastra um novo dispositivo — gera um token secreto aleatório, grava
 * só o hash dele em `dispositivosAcesso/{id}` (nunca o token em texto
 * puro) e devolve o token em texto puro UMA ÚNICA VEZ, pra você
 * configurar no aparelho. Depois deste retorno, o token não existe mais
 * em lugar nenhum que dê pra recuperar — só o hash, que só serve pra
 * comparar, nunca pra "ler de volta" (mesma lógica de uma senha).
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{ unidadeId: string, tipo: string, nome?: string }} dados
 * @returns {Promise<{ deviceId: string, token: string }>}
 */
async function cadastrarDispositivo(db, { unidadeId, tipo, nome }) {
  if (!unidadeId) throw new Error('unidadeId e obrigatorio pra cadastrar um dispositivo.');
  if (!tipo) throw new Error('tipo e obrigatorio pra cadastrar um dispositivo (ex.: "idface_pro").');

  const token = crypto.randomBytes(TAMANHO_TOKEN_BYTES).toString('hex');
  const ref = await db.collection('dispositivosAcesso').add({
    unidadeId,
    tipo,
    nome: nome || null,
    tokenHash: hashToken(token),
    ativo: true,
    criadoEm: FieldValue.serverTimestamp(),
  });

  return { deviceId: ref.id, token };
}

/**
 * Desativa um dispositivo (não apaga — preserva o histórico de eventos
 * já registrados, que continuam referenciando este `deviceId`). Um
 * dispositivo inativo nunca mais passa por `resolverDispositivo`
 * (`device-auth.js`), então qualquer chamada dele passa a ser tratada
 * como `DEVICE_NOT_AUTHORIZED`.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} deviceId
 */
async function desativarDispositivo(db, deviceId) {
  await db.collection('dispositivosAcesso').doc(deviceId).set(
    { ativo: false, desativadoEm: FieldValue.serverTimestamp() },
    { merge: true },
  );
}

/**
 * Vincula um `user_id` (a numeração interna do dispositivo) a um aluno
 * do Gym Xtreme — é este documento que `access-request-handler.js` lê
 * pra saber "quem é" quando o dispositivo manda um evento. Só grava no
 * NOSSO Firestore; não confirma nem verifica nada no aparelho (isso é
 * responsabilidade de quem cadastrou o rosto/usuário nele — hoje,
 * manual; ver docstring do arquivo).
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{ deviceId: string, userIdDispositivo: string, alunoUid: string }} dados
 */
async function vincularCredencial(db, { deviceId, userIdDispositivo, alunoUid }) {
  if (!deviceId) throw new Error('deviceId e obrigatorio.');
  if (!userIdDispositivo) throw new Error('userIdDispositivo e obrigatorio.');
  if (!alunoUid) throw new Error('alunoUid e obrigatorio.');

  await db
    .collection('dispositivosAcesso')
    .doc(deviceId)
    .collection('credenciais')
    .doc(userIdDispositivo)
    .set({ alunoUid, vinculadoEm: FieldValue.serverTimestamp() });
}

/**
 * Remove o vínculo — o `user_id` deixa de resolver pra qualquer aluno
 * (a próxima identificação com esse `user_id` vira `STUDENT_NOT_FOUND`).
 * Não mexe em nada no aparelho: se o rosto/usuário continuar cadastrado
 * fisicamente nele, ele continua sendo reconhecido, só que sem
 * corresponder a ninguém do nosso lado — é por isso que, na prática,
 * desvincular sem também remover do aparelho physical não é suficiente
 * sozinho (ver `removerUsuarioDoDispositivo`, ainda não implementado).
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{ deviceId: string, userIdDispositivo: string }} dados
 */
async function desvincularCredencial(db, { deviceId, userIdDispositivo }) {
  if (!deviceId) throw new Error('deviceId e obrigatorio.');
  if (!userIdDispositivo) throw new Error('userIdDispositivo e obrigatorio.');

  await db
    .collection('dispositivosAcesso')
    .doc(deviceId)
    .collection('credenciais')
    .doc(userIdDispositivo)
    .delete();
}

/**
 * NÃO IMPLEMENTADO — depende de falar com a Access API do próprio
 * dispositivo (`login.fcgi` + endpoint de criação de usuário), cujo
 * formato exato não foi possível confirmar (bloqueio de rede impediu
 * acessar a documentação primária neste ambiente, e não há equipamento
 * físico disponível pra testar). Existe aqui só como assinatura, pra
 * documentar a próxima peça que falta — chamar isso hoje sempre lança.
 *
 * @param {FirebaseFirestore.Firestore} _db
 * @param {{ deviceId: string, alunoUid: string }} _dados
 * @returns {Promise<never>}
 */
async function sincronizarUsuarioNoDispositivo(_db, _dados) {
  throw new Error(
    'sincronizarUsuarioNoDispositivo ainda nao implementado — depende de confirmar, no ' +
      'equipamento fisico (Fase de validacao fisica), como a Access API do iDFace Pro cria ' +
      'um usuario e cadastra o rosto dele. Ver functions/README.md.',
  );
}

/**
 * NÃO IMPLEMENTADO — mesmo motivo de `sincronizarUsuarioNoDispositivo`,
 * na direção contrária (remover do aparelho).
 * @param {FirebaseFirestore.Firestore} _db
 * @param {{ deviceId: string, userIdDispositivo: string }} _dados
 * @returns {Promise<never>}
 */
async function removerUsuarioDoDispositivo(_db, _dados) {
  throw new Error(
    'removerUsuarioDoDispositivo ainda nao implementado — mesmo motivo de ' +
      'sincronizarUsuarioNoDispositivo (ver docstring). Ver functions/README.md.',
  );
}

module.exports = {
  cadastrarDispositivo,
  desativarDispositivo,
  vincularCredencial,
  desvincularCredencial,
  sincronizarUsuarioNoDispositivo,
  removerUsuarioDoDispositivo,
};
