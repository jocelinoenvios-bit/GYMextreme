'use strict';

/**
 * Testes unitários puros do `idface-api-client.js` — nenhuma chamada de
 * rede real em nenhum teste (nem pro iDFace, nem pra mais nada): toda
 * chamada usa um `fetchImpl` mockado, injetado explicitamente. Não
 * precisa do Firestore Emulator (este cliente não usa Firestore) —
 * `node --test test/access/idface-api-client.test.js` já é suficiente.
 *
 * Guard-rail extra (equivalente ao FIRESTORE_EMULATOR_HOST dos arquivos
 * .emulator.js, adaptado pra um cliente HTTP): `globalThis.fetch` é
 * substituído por uma função que SEMPRE lança, do início ao fim deste
 * arquivo — se qualquer chamada, por engano, deixar de passar um
 * `fetchImpl` mockado e cair no parâmetro default, o teste falha
 * imediatamente em vez de tentar uma conexão de verdade.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  IdFaceAuthError,
  IdFaceHttpError,
  IdFaceTimeoutError,
  IdFaceNetworkError,
  IdFaceInvalidResponseError,
  IdFaceNotImplementedError,
  PONTOS_A_CONFIRMAR,
  login,
  logout,
  carregarObjetos,
  criarObjetos,
  criarUsuario,
  cadastrarFace,
  consultarEventos,
} = require('../../lib/access/idface-api-client');

const fetchOriginal = globalThis.fetch;

test.before(() => {
  globalThis.fetch = async () => {
    throw new Error(
      'globalThis.fetch NUNCA deveria ser chamado nestes testes — toda chamada precisa ' +
        'passar um fetchImpl mockado explicitamente.',
    );
  };
});

test.after(() => {
  globalThis.fetch = fetchOriginal;
});

function respostaMock({ ok, status, corpoJson, jsonLanca }) {
  return {
    ok,
    status,
    json: async () => {
      if (jsonLanca) throw new Error('corpo nao e JSON valido');
      return corpoJson;
    },
  };
}

// ---------------------------------------------------------------------
// 1) login — monta a requisição corretamente
// ---------------------------------------------------------------------
test('login: monta a requisição corretamente (POST /login.fcgi, credenciais no corpo)', async () => {
  let urlChamada = null;
  let opcoesChamadas = null;
  const fetchMock = async (url, opcoes) => {
    urlChamada = url;
    opcoesChamadas = opcoes;
    return respostaMock({ ok: true, status: 200, corpoJson: { session: 'sessao-fake-teste' } });
  };

  await login({
    baseUrl: 'http://idface-fake-teste.local',
    usuario: 'usuario-fake-teste',
    senha: 'senha-fake-teste',
    fetchImpl: fetchMock,
  });

  assert.equal(urlChamada, 'http://idface-fake-teste.local/login.fcgi');
  assert.equal(opcoesChamadas.method, 'POST');
  assert.equal(opcoesChamadas.headers['Content-Type'], 'application/json');
  const corpoEnviado = JSON.parse(opcoesChamadas.body);
  assert.equal(corpoEnviado.login, 'usuario-fake-teste');
  assert.equal(corpoEnviado.password, 'senha-fake-teste');
});

test('login: baseUrl/usuario/senha ausentes lançam erro de parâmetro, sem chamar fetch', async () => {
  await assert.rejects(() => login({ usuario: 'x', senha: 'y', fetchImpl: async () => {
    throw new Error('não deveria ser chamado');
  } }));
  await assert.rejects(() => login({ baseUrl: 'http://x', senha: 'y', fetchImpl: async () => {
    throw new Error('não deveria ser chamado');
  } }));
  await assert.rejects(() => login({ baseUrl: 'http://x', usuario: 'x', fetchImpl: async () => {
    throw new Error('não deveria ser chamado');
  } }));
});

// ---------------------------------------------------------------------
// 2) sucesso — devolve a sessão corretamente
// ---------------------------------------------------------------------
test('sucesso: login devolve { session } a partir da resposta do iDFace', async () => {
  const fetchMock = async () =>
    respostaMock({ ok: true, status: 200, corpoJson: { session: 'q/AcfpiU3QLRUqHKNrAh5srT' } });

  const resultado = await login({
    baseUrl: 'http://idface-fake-teste.local',
    usuario: 'usuario-fake-teste',
    senha: 'senha-fake-teste',
    fetchImpl: fetchMock,
  });

  assert.deepEqual(resultado, { session: 'q/AcfpiU3QLRUqHKNrAh5srT' });
});

test('sucesso: carregarObjetos/criarObjetos montam a URL com ?session= e o corpo esperado', async () => {
  let urlCarregar = null;
  const fetchCarregar = async (url) => {
    urlCarregar = url;
    return respostaMock({ ok: true, status: 200, corpoJson: { objects: [] } });
  };
  await carregarObjetos({
    baseUrl: 'http://idface-fake-teste.local',
    session: 'sessao-fake-teste',
    objeto: 'objeto-fake-de-teste',
    fetchImpl: fetchCarregar,
  });
  assert.equal(
    urlCarregar,
    'http://idface-fake-teste.local/load_objects.fcgi?session=sessao-fake-teste',
  );

  let corpoCriar = null;
  const fetchCriar = async (_url, opcoes) => {
    corpoCriar = JSON.parse(opcoes.body);
    return respostaMock({ ok: true, status: 200, corpoJson: { ids: [1] } });
  };
  await criarObjetos({
    baseUrl: 'http://idface-fake-teste.local',
    session: 'sessao-fake-teste',
    objeto: 'objeto-fake-de-teste',
    valores: [{ campo: 'valor-fake' }],
    fetchImpl: fetchCriar,
  });
  assert.equal(corpoCriar.object, 'objeto-fake-de-teste');
  assert.deepEqual(corpoCriar.values, [{ campo: 'valor-fake' }]);
});

// ---------------------------------------------------------------------
// 3) erro HTTP — status não-OK, diferente de autenticação
// ---------------------------------------------------------------------
test('erro HTTP: status 500 vira IdFaceHttpError, nunca finge sucesso', async () => {
  const fetchMock = async () => respostaMock({ ok: false, status: 500, corpoJson: {} });

  await assert.rejects(
    () =>
      login({
        baseUrl: 'http://idface-fake-teste.local',
        usuario: 'usuario-fake-teste',
        senha: 'senha-fake-teste',
        fetchImpl: fetchMock,
      }),
    (err) => {
      assert.ok(err instanceof IdFaceHttpError);
      assert.equal(err.status, 500);
      return true;
    },
  );
});

// ---------------------------------------------------------------------
// 4) erro de autenticação — 401/403
// ---------------------------------------------------------------------
test('erro de autenticação: HTTP 401 vira IdFaceAuthError (nunca IdFaceHttpError genérico)', async () => {
  const fetchMock = async () => respostaMock({ ok: false, status: 401, corpoJson: {} });

  await assert.rejects(
    () =>
      login({
        baseUrl: 'http://idface-fake-teste.local',
        usuario: 'usuario-fake-teste',
        senha: 'senha-errada-fake-teste',
        fetchImpl: fetchMock,
      }),
    (err) => {
      assert.ok(err instanceof IdFaceAuthError);
      assert.equal(err.status, 401);
      return true;
    },
  );
});

test('erro de autenticação: HTTP 403 também vira IdFaceAuthError', async () => {
  const fetchMock = async () => respostaMock({ ok: false, status: 403, corpoJson: {} });

  await assert.rejects(
    () =>
      login({
        baseUrl: 'http://idface-fake-teste.local',
        usuario: 'usuario-fake-teste',
        senha: 'senha-errada-fake-teste',
        fetchImpl: fetchMock,
      }),
    (err) => err instanceof IdFaceAuthError,
  );
});

// ---------------------------------------------------------------------
// 5) timeout
// ---------------------------------------------------------------------
test('timeout: fetch que nunca resolve vira IdFaceTimeoutError, respeitando timeoutMs', async () => {
  const fetchQueNuncaResolve = (_url, opcoes) =>
    new Promise((_resolve, reject) => {
      opcoes.signal.addEventListener('abort', () => {
        const err = new Error('esta requisicao foi abortada');
        err.name = 'AbortError';
        reject(err);
      });
    });

  await assert.rejects(
    () =>
      login({
        baseUrl: 'http://idface-fake-teste.local',
        usuario: 'usuario-fake-teste',
        senha: 'senha-fake-teste',
        timeoutMs: 20,
        fetchImpl: fetchQueNuncaResolve,
      }),
    (err) => {
      assert.ok(err instanceof IdFaceTimeoutError);
      return true;
    },
  );
});

// ---------------------------------------------------------------------
// erro de rede (não pedido como item numerado separado, mas coberto
// pelo mesmo mecanismo de normalização de erro — ver chamarComTimeout)
// ---------------------------------------------------------------------
test('erro de rede: fetch que rejeita (ex.: ECONNREFUSED) vira IdFaceNetworkError', async () => {
  const fetchQueRejeitaDeRede = async () => {
    throw new Error('connect ECONNREFUSED 192.0.2.1:80 (simulado)');
  };

  await assert.rejects(
    () =>
      login({
        baseUrl: 'http://idface-fake-teste.local',
        usuario: 'usuario-fake-teste',
        senha: 'senha-fake-teste',
        fetchImpl: fetchQueRejeitaDeRede,
      }),
    (err) => {
      assert.ok(err instanceof IdFaceNetworkError);
      assert.match(err.message, /ECONNREFUSED/);
      return true;
    },
  );
});

// ---------------------------------------------------------------------
// 6) resposta inválida
// ---------------------------------------------------------------------
test('resposta inválida: corpo que não é JSON vira IdFaceInvalidResponseError', async () => {
  const fetchMock = async () => respostaMock({ ok: true, status: 200, jsonLanca: true });

  await assert.rejects(
    () =>
      login({
        baseUrl: 'http://idface-fake-teste.local',
        usuario: 'usuario-fake-teste',
        senha: 'senha-fake-teste',
        fetchImpl: fetchMock,
      }),
    (err) => err instanceof IdFaceInvalidResponseError,
  );
});

test('resposta inválida: JSON válido mas sem o campo "session" também vira IdFaceInvalidResponseError', async () => {
  const fetchMock = async () =>
    respostaMock({ ok: true, status: 200, corpoJson: { algumOutroCampo: 'valor-fake' } });

  await assert.rejects(
    () =>
      login({
        baseUrl: 'http://idface-fake-teste.local',
        usuario: 'usuario-fake-teste',
        senha: 'senha-fake-teste',
        fetchImpl: fetchMock,
      }),
    (err) => err instanceof IdFaceInvalidResponseError,
  );
});

// ---------------------------------------------------------------------
// logout — encerramento de sessão (confirmado via documentação oficial,
// não pedido como item numerado separado, mas parte do escopo da
// revisão desta etapa: "verificar... encerramento/reutilização da
// sessão")
// ---------------------------------------------------------------------
test('logout: monta a requisição corretamente (POST /logout.fcgi?session=)', async () => {
  let urlChamada = null;
  let opcoesChamadas = null;
  const fetchMock = async (url, opcoes) => {
    urlChamada = url;
    opcoesChamadas = opcoes;
    return respostaMock({ ok: true, status: 200, corpoJson: null });
  };

  await logout({
    baseUrl: 'http://idface-fake-teste.local',
    session: 'sessao-fake-teste',
    fetchImpl: fetchMock,
  });

  assert.equal(
    urlChamada,
    'http://idface-fake-teste.local/logout.fcgi?session=sessao-fake-teste',
  );
  assert.equal(opcoesChamadas.method, 'POST');
});

test('logout: nunca tenta interpretar um corpo JSON (documentação diz "sem retorno")', async () => {
  const fetchMock = async () => ({
    ok: true,
    status: 200,
    json: async () => {
      throw new Error('logout NAO deveria tentar chamar .json() na resposta');
    },
  });

  // Não deve lançar — se a implementação chamasse .json() aqui, o mock
  // acima faria este teste falhar.
  await logout({
    baseUrl: 'http://idface-fake-teste.local',
    session: 'sessao-fake-teste',
    fetchImpl: fetchMock,
  });
});

test('logout: erro de autenticação (401) vira IdFaceAuthError, igual a login/objetos', async () => {
  const fetchMock = async () => respostaMock({ ok: false, status: 401, corpoJson: {} });

  await assert.rejects(
    () =>
      logout({
        baseUrl: 'http://idface-fake-teste.local',
        session: 'sessao-fake-teste',
        fetchImpl: fetchMock,
      }),
    (err) => err instanceof IdFaceAuthError,
  );
});

test('logout: baseUrl/session ausentes lançam erro de parâmetro, sem chamar fetch', async () => {
  await assert.rejects(() =>
    logout({ session: 'x', fetchImpl: async () => {
      throw new Error('não deveria ser chamado');
    } }),
  );
  await assert.rejects(() =>
    logout({ baseUrl: 'http://x', fetchImpl: async () => {
      throw new Error('não deveria ser chamado');
    } }),
  );
});

// ---------------------------------------------------------------------
// documentação do que ainda depende de validação física — a lista
// precisa existir e não pode estar vazia (é o ponto 2 desta revisão:
// separar claramente confirmado x pendente)
// ---------------------------------------------------------------------
test('PONTOS_A_CONFIRMAR: existe, não é vazia, e documenta os pontos pendentes de validação física', () => {
  assert.ok(Array.isArray(PONTOS_A_CONFIRMAR));
  assert.ok(PONTOS_A_CONFIRMAR.length > 0);
  assert.ok(Object.isFrozen(PONTOS_A_CONFIRMAR));
});

// ---------------------------------------------------------------------
// 7) stubs ainda não implementados
// ---------------------------------------------------------------------
test('stubs: criarUsuario/cadastrarFace/consultarEventos sempre lançam IdFaceNotImplementedError, nunca chamam fetch', async () => {
  await assert.rejects(() => criarUsuario(), (err) => err instanceof IdFaceNotImplementedError);
  await assert.rejects(() => cadastrarFace(), (err) => err instanceof IdFaceNotImplementedError);
  await assert.rejects(() => consultarEventos(), (err) => err instanceof IdFaceNotImplementedError);
});
