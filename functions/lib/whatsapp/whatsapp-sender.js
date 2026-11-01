'use strict';

/**
 * Interface de envio de mensagens de template via WhatsApp Business
 * Platform (Cloud API da Meta) — HOJE é um STUB: sem token configurado,
 * nunca chama a API de verdade, só devolve que a integração ainda não
 * está disponível (sem quebrar a automação que chama isto todo dia).
 *
 * Preparado pra virar uma chamada HTTPS real pra Graph API
 * (`https://graph.facebook.com/v.../{phone-number-id}/messages`) assim
 * que a conta Business estiver verificada — o token viverá num Secret do
 * Cloud Functions (`defineSecret`/Secret Manager), nunca em código-fonte,
 * variável de ambiente commitada, ou (pior) no aplicativo Flutter, que
 * nunca fala com a Meta diretamente.
 */

/**
 * @param {{telefone: string, template: string, parametros: string[]}} params
 *   `telefone` só dígitos com código do país (mesmo formato que
 *   `linkWhatsapp` já usa no app); `template` é o nome do template
 *   aprovado na Meta (ex.: "retorno15dias"); `parametros` preenche as
 *   variáveis do template, na ordem.
 * @returns {Promise<{enviado: boolean, whatsappMessageId?: string, erro?: string}>}
 */
async function enviarTemplateWhatsapp({ telefone, template, parametros }) {
  const token = process.env.WHATSAPP_CLOUD_API_TOKEN;
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;

  if (!token || !phoneNumberId) {
    // Integração ainda não configurada — comportamento esperado até a
    // conta Business Cloud API da Meta ser ligada. Nunca lança: quem
    // chama grava este resultado como auditoria e segue em frente.
    return { enviado: false, erro: 'integracao_pendente' };
  }

  // TODO(whatsapp-cloud-api): chamada HTTPS real quando a integração for
  // ligada — algo como:
  //   POST https://graph.facebook.com/v20.0/{phoneNumberId}/messages
  //   Authorization: Bearer {token vindo do Secret Manager}
  //   body: { messaging_product: 'whatsapp', to: telefone, type: 'template',
  //           template: { name: template, language: {code: 'pt_BR'},
  //                       components: [...parametros] } }
  // Guardar `messages[0].id` da resposta como `whatsappMessageId`.
  return { enviado: false, erro: 'integracao_nao_implementada' };
}

module.exports = { enviarTemplateWhatsapp };
