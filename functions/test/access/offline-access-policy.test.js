'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  POLITICA_OFFLINE,
  POLITICA_OFFLINE_PADRAO,
  avaliarPoliticaOffline,
  resolverPoliticaOfflineConfigurada,
} = require('../../lib/access/offline-access-policy');

/**
 * Cenário 1 do pedido do usuário ("dispositivo online → autorização
 * normal pelo Gym Xtreme") não é testado aqui: quando o dispositivo
 * está online, ele passa pelo fluxo normal de
 * `access-request-handler.js` (já coberto pelos outros testes de
 * ponta a ponta) — esta política offline nunca entra em jogo nesse
 * caminho, é esse o ponto.
 */

test('padrao e DENY_ALL', () => {
  assert.equal(POLITICA_OFFLINE_PADRAO, POLITICA_OFFLINE.DENY_ALL);
});

// Cenário 2: dispositivo offline + DENY_ALL → acesso negado
test('Cenario 2: DENY_ALL sempre nega, independente de qualquer outro dado', () => {
  const semSincronizado = avaliarPoliticaOffline({ politica: POLITICA_OFFLINE.DENY_ALL });
  assert.equal(semSincronizado.resultado, 'DENY');

  const comSincronizado = avaliarPoliticaOffline({
    politica: POLITICA_OFFLINE.DENY_ALL,
    usuarioSincronizadoEAtivo: true,
  });
  assert.equal(comSincronizado.resultado, 'DENY');
});

// Cenário 3: dispositivo offline + ALLOW_SYNCHRONIZED_ACTIVE_USERS →
// usa só dados previamente sincronizados
test('Cenario 3: ALLOW_SYNCHRONIZED_ACTIVE_USERS libera só quem já estava sincronizado e ativo', () => {
  const sincronizado = avaliarPoliticaOffline({
    politica: POLITICA_OFFLINE.ALLOW_SYNCHRONIZED_ACTIVE_USERS,
    usuarioSincronizadoEAtivo: true,
  });
  assert.equal(sincronizado.resultado, 'ALLOW');

  const naoSincronizado = avaliarPoliticaOffline({
    politica: POLITICA_OFFLINE.ALLOW_SYNCHRONIZED_ACTIVE_USERS,
    usuarioSincronizadoEAtivo: false,
  });
  assert.equal(naoSincronizado.resultado, 'DENY');
  assert.equal(naoSincronizado.motivo, 'OFFLINE_NAO_SINCRONIZADO');
});

// Cenário 4: dispositivo offline + HYBRID → estrutura preparada, sem
// comportamento implementado
test('Cenario 4: HYBRID existe como valor valido mas nao tem comportamento implementado', () => {
  assert.equal(POLITICA_OFFLINE.HYBRID, 'HYBRID');
  assert.throws(
    () => avaliarPoliticaOffline({ politica: POLITICA_OFFLINE.HYBRID }),
    /ainda nao tem comportamento definido/,
  );
});

test('politica desconhecida lanca erro (nunca decide silenciosamente)', () => {
  assert.throws(() => avaliarPoliticaOffline({ politica: 'ALGO_INVENTADO' }));
});
