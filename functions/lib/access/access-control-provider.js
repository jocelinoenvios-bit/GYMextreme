'use strict';

/**
 * `AccessControlProvider` — o contrato que qualquer integração de
 * identificação de acesso (Control iD/iDFace, um leitor de QR Code, um
 * leitor NFC, outra marca de catraca...) precisa implementar pra se
 * plugar no `AccessAuthorizationService`/`AccessEventService` sem que o
 * resto do domínio do Gym Xtreme precise conhecer o formato específico
 * de nenhum fabricante.
 *
 * Este arquivo não tem código executável — é só a documentação do
 * formato (JSDoc), usada pelas implementações concretas (ver
 * `control-id-adapter.js`, que exporta `controlIdAccessProvider`
 * seguindo exatamente esta forma) e por quem for revisar/estender a
 * integração.
 *
 * @typedef {Object} EventoIdentificacao
 * @property {string|null} deviceId Identificador do dispositivo que
 *   originou o evento, no formato que o próprio dispositivo usa.
 * @property {string|null} userIdDispositivo Identificador do usuário
 *   reconhecido, na numeração interna do dispositivo — nunca o uid do
 *   Gym Xtreme diretamente (ver `dispositivosAcesso/{id}/credenciais`
 *   pra esse vínculo).
 * @property {string|null} userName Nome como o dispositivo o conhece
 *   (só editorial/exibição — nunca a fonte de verdade do nome do aluno).
 * @property {string|null} portalId Identificador do portal/saída física
 *   deste dispositivo, quando ele tiver mais de uma.
 * @property {string|null} uuid Identificador único do evento em si
 *   (quando o dispositivo fornecer) — usado pra idempotência
 *   (`AccessEventService.registrarEvento`).
 * @property {number|null} confidence Confiança da identificação (0-100
 *   ou 0-1, depende do fabricante), quando aplicável.
 * @property {string} metodo Um de `'FACE'|'CARD'|'QRCODE'|'UNKNOWN'`
 *   (outros métodos futuros entram aqui conforme necessário).
 *
 * @typedef {Object} RespostaIdentificacao
 * Formato de retorno HTTP — cada provider decide sua própria forma
 * interna (ex.: `{result: {...}}` no caso do Control iD); o único
 * contrato é que `construirResposta` sempre devolve algo serializável
 * como JSON pronto pra resposta HTTP.
 *
 * @typedef {Object} AccessControlProvider
 * @property {string} id Identificador curto do provider (ex.:
 *   `'control-id'`) — usado em logs/diagnóstico, nunca em regra de
 *   negócio.
 * @property {(payload: Record<string, unknown>) => EventoIdentificacao} interpretarEvento
 *   Traduz o payload bruto que o dispositivo mandou pro formato interno
 *   acima. Nunca lança — payload incompleto vira campos `null`.
 * @property {(params: {
 *   resultado: 'ALLOW'|'DENY',
 *   userIdDispositivo: string|null,
 *   userName: string|null,
 *   portalId: string|null,
 *   mensagem: string,
 * }) => RespostaIdentificacao} construirResposta
 *   Monta a resposta HTTP no formato que ESTE fabricante espera, a
 *   partir da decisão já tomada por `AccessAuthorizationService`. Nunca
 *   decide ALLOW/DENY sozinho — só formata uma decisão que já veio
 *   pronta.
 */

module.exports = {};
