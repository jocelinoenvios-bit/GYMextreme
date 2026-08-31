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
 * A CONFIRMAR NO EQUIPAMENTO: o nome exato da ação de abertura e seus
 * parâmetros dependem de como o módulo de acionamento (relé) está
 * fisicamente ligado ao iDFace Pro — relé interno do próprio aparelho
 * usa a ação "door", relé externo via módulo MAE usa "sec_box", e uma
 * catraca com giro controlado usa "catra" (parâmetro `allow`:
 * "clockwise" | "anticlockwise" | "both"). NENHUM desses foi confirmado
 * na documentação primária (bloqueio de rede impediu acessar
 * controlid.com.br neste ambiente) nem testado no equipamento físico —
 * por isso esta função NUNCA assume um valor por padrão: sem a variável
 * de ambiente `CONTROLID_ACAO_ABERTURA_JSON` configurada, retorna lista
 * vazia (o dispositivo recebe `event: 7`, "pode passar", mas nenhuma
 * instrução de acionamento — o comportamento do relé nesse caso também
 * é algo a observar na Fase de validação física).
 *
 * Configuração esperada (só depois de confirmar no equipamento): um
 * JSON de um array de `{action, parameters}`, ex.:
 * `CONTROLID_ACAO_ABERTURA_JSON='[{"action":"catra","parameters":{"allow":"both"}}]'`.
 *
 * @returns {Array<{action: string, parameters: Record<string, unknown>}>}
 */
function resolverAcoesAbertura() {
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
 * }} params
 */
function construirRespostaIdentificacao({ resultado, userIdDispositivo, userName, portalId, mensagem }) {
  const autorizado = resultado === RESULTADO.ALLOW;
  return {
    result: {
      event: autorizado ? EVENT_ACESSO_LIBERADO : EVENT_ACESSO_NEGADO,
      user_id: userIdDispositivo,
      user_name: userName,
      portal_id: portalId || '1',
      actions: autorizado ? resolverAcoesAbertura() : [],
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
