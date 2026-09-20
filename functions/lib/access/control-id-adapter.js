'use strict';

const { RESULTADO } = require('./motivos');

const EVENT_ACESSO_LIBERADO = 7;
const EVENT_ACESSO_NEGADO = 6;

/**
 * Nome da variável de ambiente/configuração usada pra definir a ação de
 * abertura enviada quando `event: 7` — ver `resolverAcoesAbertura`.
 */
const VARIAVEL_ACAO_ABERTURA = 'CONTROLID_ACAO_ABERTURA_JSON';

/**
 * Resolve a lista de `actions` enviada numa resposta de acesso liberado.
 *
 * CONFIRMADO fisicamente (ver histórico do projeto): o iDFace de
 * laboratório abre via `{action: 'sec_box', parameters: {id: 65793,
 * reason: 3}}`. Esse `id` é do SecBox/MAE de UM dispositivo físico
 * específico — nunca assumido igual entre dispositivos diferentes
 * (cada catraca/unidade tem seu próprio relé). Por isso a fonte
 * primária é sempre `acoesConfiguradas` (lido de
 * `dispositivosAcesso/{deviceId}.acoesAbertura`, ver
 * `device-sync-service.js#configurarAcoesAbertura`) — específico do
 * dispositivo que efetivamente chamou.
 *
 * A variável de ambiente `CONTROLID_ACAO_ABERTURA_JSON` continua como
 * FALLBACK GLOBAL, só por compatibilidade (comportamento anterior à
 * configuração por dispositivo) — evitar usá-la assim que houver mais
 * de um dispositivo com relés diferentes, já que ela vale pra todos.
 *
 * Sem nenhuma das duas fontes configuradas, retorna lista vazia (nunca
 * assume um comando de relé) — o dispositivo recebe `event: 7`, "pode
 * passar", mas nenhuma instrução de acionamento.
 *
 * @param {Array<{action: string, parameters: Record<string, unknown>}>} [acoesConfiguradas]
 *   Ações específicas do dispositivo que fez a chamada (prioridade
 *   máxima quando presente e não-vazia).
 * @returns {Array<{action: string, parameters: Record<string, unknown>}>}
 */
function resolverAcoesAbertura(acoesConfiguradas) {
  if (Array.isArray(acoesConfiguradas) && acoesConfiguradas.length > 0) {
    return acoesConfiguradas;
  }

  const configuracao = process.env[VARIAVEL_ACAO_ABERTURA];
  if (!configuracao) return [];

  try {
    const acoes = JSON.parse(configuracao);
    return Array.isArray(acoes) ? acoes : [];
  } catch (err) {
    console.error(
      `Valor invalido em ${VARIAVEL_ACAO_ABERTURA} (nao e um JSON de array valido) — ` +
        'usando lista vazia. Corrija a configuracao depois de confirmar a acao no equipamento.',
      err,
    );
    return [];
  }
}

/**
 * `ControlIdAccessProvider` (metade "entrada"): traduz o payload bruto
 * que o iDFace Pro manda pro nosso endpoint (equivalente ao
 * `new_user_identified.fcgi` do lado do dispositivo) pro formato interno
 * que o resto do domínio do Gym Xtreme usa — nada fora deste arquivo
 * conhece o formato específico do Control iD.
 *
 * Campos aceitos do payload (nomes conforme a Access API — ver seção 4
 * do briefing de integração): device_id, identifier_id, event, user_id,
 * time, portal_id, uuid, card_value, qrcode_value, user_name,
 * confidence, face_mask. Nenhum é obrigatório aqui — um payload
 * incompleto vira campos `null`, e é o endpoint/serviço de autorização
 * que decide o que fazer com a ausência (normalmente STUDENT_NOT_FOUND
 * ou SYSTEM_ERROR).
 *
 * @param {Record<string, unknown>} payload
 * @returns {{
 *   deviceId: string|null,
 *   userIdDispositivo: string|null,
 *   userName: string|null,
 *   portalId: string|null,
 *   uuid: string|null,
 *   identifierId: string|null,
 *   confidence: number|null,
 *   time: string|null,
 *   metodo: 'FACE'|'CARD'|'QRCODE'|'UNKNOWN',
 * }}
 */
function interpretarEventoIdentificacao(payload) {
  payload = payload || {};

  let metodo = 'UNKNOWN';
  if (payload.card_value != null) metodo = 'CARD';
  else if (payload.qrcode_value != null) metodo = 'QRCODE';
  else if (payload.user_id != null) metodo = 'FACE';

  return {
    deviceId: payload.device_id != null ? String(payload.device_id) : null,
    userIdDispositivo: payload.user_id != null ? String(payload.user_id) : null,
    userName: typeof payload.user_name === 'string' ? payload.user_name : null,
    portalId: payload.portal_id != null ? String(payload.portal_id) : null,
    uuid: typeof payload.uuid === 'string' ? payload.uuid : null,
    identifierId: payload.identifier_id != null ? String(payload.identifier_id) : null,
    confidence: typeof payload.confidence === 'number' ? payload.confidence : null,
    time: typeof payload.time === 'string' ? payload.time : null,
    metodo,
  };
}

/**
 * `ControlIdAccessProvider` (metade "saída"): monta a resposta no
 * formato que o iDFace Pro espera de volta do evento de identificação —
 * estrutura conceitual confirmada pelo usuário (seção 5 do briefing). O
 * campo `actions` segue o formato oficial da Access API
 * (`{action, parameters}`), mas o conteúdo vem de `resolverAcoesAbertura`
 * — vazio até ser confirmado no equipamento físico (ver docstring dela).
 *
 * @param {{
 *   resultado: 'ALLOW'|'DENY',
 *   userIdDispositivo: string|null,
 *   userName: string|null,
 *   portalId: string|null,
 *   mensagem: string,
 *   acoesAbertura?: Array<{action: string, parameters: Record<string, unknown>}>,
 * }} params
 */
function construirRespostaIdentificacao({
  resultado,
  userIdDispositivo,
  userName,
  portalId,
  mensagem,
  acoesAbertura,
}) {
  const autorizado = resultado === RESULTADO.ALLOW;
  return {
    result: {
      event: autorizado ? EVENT_ACESSO_LIBERADO : EVENT_ACESSO_NEGADO,
      user_id: userIdDispositivo,
      user_name: userName,
      portal_id: portalId || '1',
      actions: autorizado ? resolverAcoesAbertura(acoesAbertura) : [],
      message: mensagem,
    },
  };
}

/**
 * `ControlIdAccessProvider` — implementação concreta do contrato
 * `AccessControlProvider` (ver `access-control-provider.js`) pro
 * fabricante Control iD/iDFace Pro. Todo o resto do domínio do Gym
 * Xtreme (`AccessAuthorizationService`, `access-request-handler.js`)
 * depende só desse objeto, nunca dos nomes de campo/formato do Control
 * iD diretamente — trocar de fabricante no futuro significa escrever um
 * novo objeto com essa mesma forma, sem tocar em nenhuma regra de
 * negócio.
 *
 * @type {import('./access-control-provider').AccessControlProvider}
 */
const controlIdAccessProvider = Object.freeze({
  id: 'control-id',
  interpretarEvento: interpretarEventoIdentificacao,
  construirResposta: construirRespostaIdentificacao,
});

module.exports = {
  EVENT_ACESSO_LIBERADO,
  EVENT_ACESSO_NEGADO,
  VARIAVEL_ACAO_ABERTURA,
  resolverAcoesAbertura,
  interpretarEventoIdentificacao,
  construirRespostaIdentificacao,
  controlIdAccessProvider,
};
