'use strict';

const { RESULTADO } = require('./motivos');

const EVENT_ACESSO_LIBERADO = 7;
const EVENT_ACESSO_NEGADO = 6;

// A CONFIRMAR NO EQUIPAMENTO: o nome exato da ação de abertura e seus
// parâmetros dependem de como o módulo de acionamento (relé) está
// fisicamente ligado ao iDFace Pro — relé interno do próprio aparelho
// usa a ação "door", relé externo via módulo MAE usa "sec_box", e uma
// catraca com giro controlado usa "catra" (parâmetro `allow`:
// "clockwise" | "anticlockwise" | "both"). O valor abaixo foi apurado
// via busca (não confirmado na documentação primária — bloqueio de rede
// impediu acessar controlid.com.br neste ambiente) e é só um ponto de
// partida: a decisão final é da Fase 9 do roteiro, testando no
// equipamento físico antes de ligar a solenoide de verdade (Fase 10).
const ACAO_ABERTURA_PADRAO = Object.freeze({
  action: 'catra',
  parameters: Object.freeze({ allow: 'both' }),
});

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
 * (`{action, parameters}`), mas o conteúdo exato de `ACAO_ABERTURA_PADRAO`
 * só fica 100% certo testando no equipamento físico (ver comentário
 * acima).
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
      actions: autorizado ? [ACAO_ABERTURA_PADRAO] : [],
      message: mensagem,
    },
  };
}

module.exports = {
  EVENT_ACESSO_LIBERADO,
  EVENT_ACESSO_NEGADO,
  ACAO_ABERTURA_PADRAO,
  interpretarEventoIdentificacao,
  construirRespostaIdentificacao,
};
