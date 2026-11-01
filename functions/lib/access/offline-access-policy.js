'use strict';

/**
 * Política de acesso quando o dispositivo NÃO consegue se comunicar com
 * o Gym Xtreme — ver seção 17 do briefing original. Importante: essa
 * decisão, quando acontece de verdade, é tomada PELO PRÓPRIO
 * DISPOSITIVO (ele decide localmente, sem internet) — o Gym Xtreme
 * nunca executa este código nesse momento, porque se o dispositivo está
 * mesmo offline, ele nunca chega a chamar
 * `controlIdNewUserIdentified` nenhuma vez.
 *
 * O que existe aqui serve pra duas coisas: (1) guardar QUAL política
 * está configurada (pra, na Fase de validação física / Fase 6, saber o
 * que configurar no aparelho — como fazer essa configuração chegar até
 * o dispositivo de verdade ainda não foi implementado, é
 * `DeviceSyncService`); (2) `avaliarPoliticaOffline` simula o que essa
 * política decidiria, útil pra testar a estrutura antes de existir
 * qualquer jeito de aplicá-la de verdade no equipamento.
 *
 * O Gym Xtreme é a autoridade de autorização — por isso o padrão é
 * `DENY_ALL`: sem conseguir confirmar situação financeira, plano,
 * bloqueio etc., a decisão mais segura é nunca liberar sozinho.
 */

const POLITICA_OFFLINE = Object.freeze({
  DENY_ALL: 'DENY_ALL',
  ALLOW_SYNCHRONIZED_ACTIVE_USERS: 'ALLOW_SYNCHRONIZED_ACTIVE_USERS',
  HYBRID: 'HYBRID',
});

const POLITICA_OFFLINE_PADRAO = POLITICA_OFFLINE.DENY_ALL;

/** Caminho do documento singleton de configuração no Firestore. */
const CAMINHO_CONFIGURACAO = { colecao: 'configuracaoAcesso', documento: 'politicaOffline' };

/**
 * Simula a decisão que a política offline configurada tomaria — nunca é
 * chamada pelo fluxo real de `access-request-handler.js` (que só roda
 * quando o dispositivo ESTÁ online); serve pra testar a estrutura e pra
 * documentar o comportamento esperado antes de existir um jeito de
 * aplicá-la de verdade no equipamento.
 *
 * @param {{
 *   politica: 'DENY_ALL'|'ALLOW_SYNCHRONIZED_ACTIVE_USERS'|'HYBRID',
 *   usuarioSincronizadoEAtivo?: boolean,
 * }} params
 * @returns {{ resultado: 'ALLOW'|'DENY', motivo: string|null }}
 */
function avaliarPoliticaOffline({ politica, usuarioSincronizadoEAtivo }) {
  switch (politica) {
    case POLITICA_OFFLINE.DENY_ALL:
      return { resultado: 'DENY', motivo: 'OFFLINE_DENY_ALL' };

    case POLITICA_OFFLINE.ALLOW_SYNCHRONIZED_ACTIVE_USERS:
      return usuarioSincronizadoEAtivo
        ? { resultado: 'ALLOW', motivo: null }
        : { resultado: 'DENY', motivo: 'OFFLINE_NAO_SINCRONIZADO' };

    case POLITICA_OFFLINE.HYBRID:
      // Estrutura reservada, de propósito NÃO implementada além disso —
      // ver seção 17 do briefing ("suporte futuro para HYBRID") e a
      // instrução explícita de não implementar HYBRID agora além da
      // estrutura necessária.
      throw new Error(
        'Politica HYBRID ainda nao tem comportamento definido/implementado — so a estrutura ' +
          '(o valor existe em POLITICA_OFFLINE e e aceito por resolverPoliticaOfflineConfigurada) ' +
          'esta pronta. Definir o comportamento e uma etapa futura.',
      );

    default:
      throw new Error(`Politica offline desconhecida: ${politica}`);
  }
}

/**
 * Lê a política configurada em `configuracaoAcesso/politicaOffline` —
 * `POLITICA_OFFLINE_PADRAO` (`DENY_ALL`) se o documento não existir ou
 * o campo `politica` não for um valor reconhecido. Pensado pra, no
 * futuro, um painel administrativo escrever esse mesmo documento sem
 * precisar mexer em código nenhum.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @returns {Promise<'DENY_ALL'|'ALLOW_SYNCHRONIZED_ACTIVE_USERS'|'HYBRID'>}
 */
async function resolverPoliticaOfflineConfigurada(db) {
  const snap = await db
    .collection(CAMINHO_CONFIGURACAO.colecao)
    .doc(CAMINHO_CONFIGURACAO.documento)
    .get();

  if (!snap.exists) return POLITICA_OFFLINE_PADRAO;

  const politica = snap.data().politica;
  return Object.values(POLITICA_OFFLINE).includes(politica) ? politica : POLITICA_OFFLINE_PADRAO;
}

module.exports = {
  POLITICA_OFFLINE,
  POLITICA_OFFLINE_PADRAO,
  CAMINHO_CONFIGURACAO,
  avaliarPoliticaOffline,
  resolverPoliticaOfflineConfigurada,
};
