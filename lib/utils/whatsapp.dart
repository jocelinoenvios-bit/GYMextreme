/// Monta o link "wa.me" a partir de um número de WhatsApp cadastrado no
/// app — só dígitos, sem código do país (ver `digitsOnlyFormatter` nos
/// formulários de cadastro/edição do aluno, sempre DDD + número
/// brasileiro, 10 ou 11 dígitos, conforme `validarTelefone`). Antepõe o
/// código do país (55) automaticamente, a menos que o número já venha com
/// ele na frente.
///
/// Abrir esse link (`url_launcher`) abre o WhatsApp do aparelho (Android)
/// ou o WhatsApp Web (navegador, ex.: computador da academia) já com a
/// conversa desse número pronta pra digitar a mensagem — a recepção
/// escreve e envia manualmente, nada é disparado sozinho.
String linkWhatsapp(String numero) {
  final digitos = numero.replaceAll(RegExp(r'[^0-9]'), '');
  final comCodigoPais = digitos.startsWith('55') && digitos.length >= 12
      ? digitos
      : '55$digitos';
  return 'https://wa.me/$comCodigoPais';
}
