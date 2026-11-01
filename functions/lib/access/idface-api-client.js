'use strict';

/**
 * `idface-api-client.js` — cliente HTTP isolado pra Access API do
 * Control iD / iDFace, sentido Gym Xtreme → iDFace (o contrário da
 * integração já validada: `control-id-adapter.js`/
 * `access-request-handler.js` cuidam do sentido iDFace → Gym Xtreme,
 * que já está pronto, testado e NÃO é tocado por este arquivo).
 *
 * Fase 7.3 — só a camada de comunicação. Este arquivo:
 * - NÃO contém nenhuma regra de negócio de autorização (isso é só
 *   `access-authorization-service.js`, sempre).
 * - NÃO está importado/chamado por nenhum outro lugar do sistema ainda
 *   (nem `device-sync-service.js`, nem `index.js`) — fica isolado, de
 *   propósito, até os detalhes pendentes abaixo serem confirmados no
 *   equipamento físico.
 * - NÃO faz nenhuma chamada de rede nos testes — toda chamada usa um
 *   `fetchImpl` injetável (default `globalThis.fetch`, nunca invocado
 *   nos testes, que sempre passam um mock).
 *
 * O que está implementado de verdade (mecanismo confirmado via busca à
 * documentação oficial — `WebFetch` pra controlid.com.br está bloqueado
 * neste ambiente, igual estava pra quem implementou o resto da
 * integração; os nomes de campo abaixo vêm de resumos de busca com
 * fonte, não de uma leitura direta da página — ver `PONTOS_A_CONFIRMAR`
 * no final deste arquivo):
 * - `login()` — `POST /login.fcgi`, retorna `{ session }`.
 * - `logout()` — `POST /logout.fcgi?session=`, sem parâmetros nem
 *   retorno (fonte: "Fazer logout - API Linha de Acesso").
 * - `carregarObjetos()`/`criarObjetos()` — wrappers genéricos pra
 *   `POST /load_objects.fcgi` e `POST /create_objects.fcgi` (API
 *   genérica de objetos da Control iD — confirmada que existe; quem
 *   chama informa o nome do objeto/tabela e os campos).
 *
 * Sessão — reutilização, nunca cache automático: a documentação
 * confirma que a MESMA sessão devolvida por `login()` deve ser reusada
 * em todas as chamadas seguintes (nunca logar de novo a cada chamada).
 * Este cliente é deliberadamente sem estado: não guarda a sessão em
 * nenhuma variável de módulo nem a renova sozinho — quem chama
 * (`login()` uma vez, guarda `{session}`, passa esse valor em cada
 * `carregarObjetos`/`criarObjetos`/`logout` seguinte) é responsável por
 * isso. Cache/expiração automática de sessão fica pra uma camada acima
 * (quando este cliente for de fato ligado a algo), pra não esconder bug
 * nenhum de sessão expirada atrás de uma re-autenticação silenciosa.
 *
 * O que fica como STUB, lançando erro explícito (nunca finge
 * funcionar — mesmo padrão já usado em `device-sync-service.js`):
 * - `criarUsuario()` — precisa do nome exato do objeto/tabela de
 *   usuários e dos campos obrigatórios, não confirmados.
 * - `cadastrarFace()` — endpoint dedicado existe (`facial-enroll`), mas
 *   o formato do payload (base64? upload separado? campos?) não foi
 *   confirmado.
 * - `consultarEventos()` — precisa do nome exato do objeto/tabela de
 *   eventos/logs de acesso, não confirmado.
 */

const DEFAULT_TIMEOUT_MS = 8000;

class IdFaceAuthError extends Error {
  constructor(mensagem, { status } = {}) {
    super(mensagem);
    this.name = 'IdFaceAuthError';
    this.status = status ?? null;
  }
}

class IdFaceHttpError extends Error {
  constructor(mensagem, { status } = {}) {
    super(mensagem);
    this.name = 'IdFaceHttpError';
    this.status = status ?? null;
  }
}

class IdFaceTimeoutError extends Error {
  constructor(mensagem) {
    super(mensagem);
    this.name = 'IdFaceTimeoutError';
  }
}

class IdFaceNetworkError extends Error {
  constructor(mensagem, { causa } = {}) {
    super(mensagem);
    this.name = 'IdFaceNetworkError';
    this.causa = causa ?? null;
  }
}

class IdFaceInvalidResponseError extends Error {
  constructor(mensagem) {
    super(mensagem);
    this.name = 'IdFaceInvalidResponseError';
  }
}

class IdFaceNotImplementedError extends Error {
  constructor(mensagem) {
    super(mensagem);
    this.name = 'IdFaceNotImplementedError';
  }
}

/**
 * Executa uma chamada HTTP com timeout, normalizando qualquer falha de
 * transporte (nunca deixa um erro cru do `fetch` vazar) em
 * `IdFaceTimeoutError` ou `IdFaceNetworkError`.
 *
 * @param {typeof fetch} fetchImpl
 * @param {string} url
 * @param {RequestInit} opcoes
 * @param {number} timeoutMs
 */
async function chamarComTimeout(fetchImpl, url, opcoes, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetchImpl(url, { ...opcoes, signal: controller.signal });
  } catch (err) {
    if (err && err.name === 'AbortError') {
      throw new IdFaceTimeoutError(
        `iDFace nao respondeu dentro de ${timeoutMs}ms (${url}).`,
      );
    }
    throw new IdFaceNetworkError(`Falha de rede ao chamar o iDFace (${url}): ${err.message}`, {
      causa: err,
    });
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Interpreta a resposta HTTP crua: status 401/403 vira `IdFaceAuthError`,
 * qualquer outro status não-OK vira `IdFaceHttpError`, corpo que não é
 * JSON válido vira `IdFaceInvalidResponseError`. Nunca deixa um erro cru
 * de parsing vazar sem contexto.
 *
 * @param {Response} resposta
 * @param {string} contexto rótulo curto pra mensagem de erro (ex.: "login")
 */
async function interpretarResposta(resposta, contexto) {
  if (resposta.status === 401 || resposta.status === 403) {
    throw new IdFaceAuthError(
      `iDFace rejeitou a autenticacao em "${contexto}" (HTTP ${resposta.status}).`,
      { status: resposta.status },
    );
  }
  if (!resposta.ok) {
    throw new IdFaceHttpError(`iDFace respondeu HTTP ${resposta.status} em "${contexto}".`, {
      status: resposta.status,
    });
  }

  let corpo;
  try {
    corpo = await resposta.json();
  } catch (err) {
    throw new IdFaceInvalidResponseError(
      `Resposta do iDFace em "${contexto}" nao e um JSON valido: ${err.message}`,
    );
  }
  return corpo;
}

/**
 * `POST /login.fcgi` — autentica na Access API do iDFace e devolve o
 * código de sessão a usar nas chamadas seguintes (`?session=<codigo>`).
 *
 * Mecanismo confirmado via documentação oficial (busca, com fonte —
 * `WebFetch` bloqueado neste ambiente): a resposta traz um campo
 * `session` (string). Os nomes exatos dos campos do corpo da requisição
 * (`login`/`password`) vêm do mesmo resumo de busca — se o equipamento
 * real usar nomes diferentes, é um ponto a corrigir na Fase de validação
 * física, não algo que este código assume silenciosamente certo.
 *
 * @param {{
 *   baseUrl: string,
 *   usuario: string,
 *   senha: string,
 *   timeoutMs?: number,
 *   fetchImpl?: typeof fetch,
 * }} params
 * @returns {Promise<{ session: string }>}
 */
async function login({ baseUrl, usuario, senha, timeoutMs = DEFAULT_TIMEOUT_MS, fetchImpl = globalThis.fetch }) {
  if (!baseUrl) throw new Error('baseUrl e obrigatorio (endereco do iDFace na rede local).');
  if (!usuario) throw new Error('usuario e obrigatorio.');
  if (!senha) throw new Error('senha e obrigatoria.');

  const resposta = await chamarComTimeout(
    fetchImpl,
    `${baseUrl}/login.fcgi`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      // Nomes de campo ("login"/"password") conforme a documentacao
      // oficial (resumo de busca com fonte) — ver PONTOS_A_CONFIRMAR se
      // o equipamento real usar nomes diferentes.
      body: JSON.stringify({ login: usuario, password: senha }),
    },
    timeoutMs,
  );

  const corpo = await interpretarResposta(resposta, 'login');

  if (!corpo || typeof corpo.session !== 'string' || !corpo.session) {
    throw new IdFaceInvalidResponseError(
      'Resposta do login nao trouxe o campo "session" esperado.',
    );
  }

  return { session: corpo.session };
}

/**
 * `POST /logout.fcgi?session=<session>` — encerra a sessão obtida por
 * `login()`. Mecanismo confirmado via documentação oficial (busca, com
 * fonte: "Fazer logout - API Linha de Acesso") — sem parâmetros no
 * corpo e SEM retorno, por isso esta função não tenta interpretar
 * nenhum JSON de resposta (diferente de `login()`/`chamarObjetos()`):
 * fazer isso seria assumir um formato de corpo que a própria
 * documentação diz que não existe.
 *
 * @param {{
 *   baseUrl: string,
 *   session: string,
 *   timeoutMs?: number,
 *   fetchImpl?: typeof fetch,
 * }} params
 * @returns {Promise<void>}
 */
async function logout({ baseUrl, session, timeoutMs = DEFAULT_TIMEOUT_MS, fetchImpl = globalThis.fetch }) {
  if (!baseUrl) throw new Error('baseUrl e obrigatorio.');
  if (!session) throw new Error('session e obrigatoria (ver login()).');

  const resposta = await chamarComTimeout(
    fetchImpl,
    `${baseUrl}/logout.fcgi?session=${encodeURIComponent(session)}`,
    { method: 'POST' },
    timeoutMs,
  );

  if (resposta.status === 401 || resposta.status === 403) {
    throw new IdFaceAuthError(
      `iDFace rejeitou a autenticacao em "logout" (HTTP ${resposta.status}).`,
      { status: resposta.status },
    );
  }
  if (!resposta.ok) {
    throw new IdFaceHttpError(`iDFace respondeu HTTP ${resposta.status} em "logout".`, {
      status: resposta.status,
    });
  }
  // Documentacao: sem retorno — nao ha corpo pra interpretar aqui, de
  // proposito (nunca assume um formato de resposta nao confirmado).
}

/**
 * Wrapper genérico pra API de objetos da Control iD
 * (`load_objects.fcgi`/`create_objects.fcgi`) — mecanismo confirmado
 * (a API de objetos existe e segue este formato geral), mas o nome do
 * objeto/tabela e os campos são responsabilidade de quem chama: este
 * arquivo não assume nenhum nome de tabela específico (usuários, eventos
 * etc.) por conta própria.
 *
 * @param {{
 *   baseUrl: string,
 *   session: string,
 *   endpoint: 'load_objects' | 'create_objects',
 *   corpo: Record<string, unknown>,
 *   timeoutMs?: number,
 *   fetchImpl?: typeof fetch,
 * }} params
 */
async function chamarObjetos({ baseUrl, session, endpoint, corpo, timeoutMs = DEFAULT_TIMEOUT_MS, fetchImpl = globalThis.fetch }) {
  if (!baseUrl) throw new Error('baseUrl e obrigatorio.');
  if (!session) throw new Error('session e obrigatoria (ver login()).');
  if (!corpo || typeof corpo !== 'object') throw new Error('corpo e obrigatorio.');

  const resposta = await chamarComTimeout(
    fetchImpl,
    `${baseUrl}/${endpoint}.fcgi?session=${encodeURIComponent(session)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(corpo),
    },
    timeoutMs,
  );

  return interpretarResposta(resposta, endpoint);
}

/**
 * `POST /load_objects.fcgi` — lê objetos de uma tabela do dispositivo.
 * Genérico de propósito: quem chama informa `objeto` (ex.: o nome exato
 * da tabela de eventos, quando confirmado) e campos extras do corpo
 * (`fields`, `where` etc., conforme a documentação da tabela específica).
 *
 * @param {{ baseUrl: string, session: string, objeto: string, camposExtras?: Record<string, unknown>, timeoutMs?: number, fetchImpl?: typeof fetch }} params
 */
async function carregarObjetos({ baseUrl, session, objeto, camposExtras = {}, timeoutMs, fetchImpl }) {
  if (!objeto) throw new Error('objeto e obrigatorio (nome da tabela a carregar).');
  return chamarObjetos({
    baseUrl,
    session,
    endpoint: 'load_objects',
    corpo: { object: objeto, ...camposExtras },
    timeoutMs,
    fetchImpl,
  });
}

/**
 * `POST /create_objects.fcgi` — cria objeto(s) numa tabela do
 * dispositivo. Genérico de propósito, mesma ideia de `carregarObjetos`.
 *
 * @param {{ baseUrl: string, session: string, objeto: string, valores: Record<string, unknown>[], timeoutMs?: number, fetchImpl?: typeof fetch }} params
 */
async function criarObjetos({ baseUrl, session, objeto, valores, timeoutMs, fetchImpl }) {
  if (!objeto) throw new Error('objeto e obrigatorio (nome da tabela onde criar).');
  if (!Array.isArray(valores) || valores.length === 0) {
    throw new Error('valores e obrigatorio (array de objetos a criar).');
  }
  return chamarObjetos({
    baseUrl,
    session,
    endpoint: 'create_objects',
    corpo: { object: objeto, values: valores },
    timeoutMs,
    fetchImpl,
  });
}

/**
 * NÃO IMPLEMENTADO — cadastrar um usuário novo no iDFace. Precisa do
 * nome exato do objeto/tabela de usuários e dos campos obrigatórios na
 * `create_objects.fcgi`, o que não foi possível confirmar (bloqueio de
 * rede impediu ler a documentação primária, e não há equipamento físico
 * disponível pra testar). Existe aqui só como assinatura/documentação —
 * chamar isto hoje sempre lança um erro explícito, nunca finge
 * funcionar. Ver `carregarObjetos`/`criarObjetos` acima: o mecanismo já
 * está pronto, só falta confirmar o nome do objeto/campos no
 * equipamento pra implementar de verdade em cima deles.
 *
 * @returns {Promise<never>}
 */
async function criarUsuario() {
  throw new IdFaceNotImplementedError(
    'criarUsuario ainda nao implementado — depende de confirmar, no equipamento fisico ' +
      '(Fase de validacao fisica), o nome exato do objeto/tabela de usuarios e os campos ' +
      'obrigatorios da create_objects.fcgi. O mecanismo generico ja existe (criarObjetos) — ' +
      'falta so essa confirmacao pra usar ele aqui.',
  );
}

/**
 * NÃO IMPLEMENTADO — cadastrar a foto/rosto de um usuário já existente
 * no iDFace. O endpoint dedicado (`facial-enroll`) existe na
 * documentação oficial, mas o formato exato do payload (imagem em
 * base64 inline? upload em outra chamada? quais campos?) não foi
 * confirmado pelo mesmo motivo de `criarUsuario`. Sempre lança.
 *
 * @returns {Promise<never>}
 */
async function cadastrarFace() {
  throw new IdFaceNotImplementedError(
    'cadastrarFace ainda nao implementado — o endpoint de enrollment facial existe na ' +
      'documentacao oficial da Control iD, mas o formato exato do payload nao foi confirmado ' +
      '(sem acesso a documentacao primaria nem ao equipamento fisico). Ver functions/README.md.',
  );
}

/**
 * NÃO IMPLEMENTADO — consultar eventos/logs de acesso registrados
 * diretamente no iDFace (via `load_objects.fcgi`). Precisa do nome
 * exato do objeto/tabela de eventos, não confirmado. Sempre lança. O
 * mecanismo genérico (`carregarObjetos`) já está pronto — falta só essa
 * confirmação.
 *
 * @returns {Promise<never>}
 */
async function consultarEventos() {
  throw new IdFaceNotImplementedError(
    'consultarEventos ainda nao implementado — depende de confirmar, no equipamento fisico, ' +
      'o nome exato do objeto/tabela de eventos/logs de acesso na load_objects.fcgi. O ' +
      'mecanismo generico ja existe (carregarObjetos) — falta so essa confirmacao.',
  );
}

/**
 * Lista consolidada de tudo que este arquivo NÃO assume como certo —
 * cada item só pode ser fechado de verdade na Fase de validação física
 * (equipamento em mãos) ou com acesso direto à documentação primária
 * (bloqueada neste ambiente). Nenhuma função acima finge que um destes
 * pontos já foi confirmado.
 */
const PONTOS_A_CONFIRMAR = Object.freeze([
  'Nomes exatos dos campos do corpo de login.fcgi ("login"/"password" vêm de um resumo de busca, não de leitura direta da documentação primária).',
  'Se logout.fcgi realmente não traz nenhum corpo de resposta (assumido pela documentação, não observado num equipamento real).',
  'Nome exato do objeto/tabela de usuários em create_objects.fcgi (bloqueia criarUsuario).',
  'Formato exato do payload do endpoint de enrollment facial — facial-enroll (bloqueia cadastrarFace).',
  'Nome exato do objeto/tabela de eventos/logs de acesso em load_objects.fcgi (bloqueia consultarEventos).',
  'Se o "Modo Pro/Online" do iDFace aceita anexar credenciais/headers customizados, ou só o payload documentado.',
]);

module.exports = {
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
};
