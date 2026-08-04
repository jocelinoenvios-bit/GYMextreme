import 'package:flutter/services.dart';

/// Restringe o campo a dígitos — usado em CPF, CEP, telefone/WhatsApp e
/// dia de vencimento, os únicos campos da ficha que são sempre numéricos
/// (RG varia por estado, às vezes com letra, então fica livre).
final digitsOnlyFormatter = FilteringTextInputFormatter.digitsOnly;

/// Todos os validadores abaixo seguem a mesma regra: o campo é opcional
/// (ficha em papel não exige nenhum deles), mas se algo for digitado tem
/// que ter o formato certo — nunca bloqueia o cadastro por campo vazio,
/// só por um valor com contagem de dígitos claramente errada.
///
/// O parâmetro é `String?` (não `String`) porque é assim que
/// `FormFieldValidator<String>` (o tipo esperado por `TextFormField.validator`)
/// é declarado — `TextFormField` pode chamar o validator antes de qualquer
/// texto ser digitado, com `value == null`.
String? validarCep(String? value) {
  final digitos = value?.trim() ?? '';
  if (digitos.isEmpty) return null;
  if (digitos.length != 8) return 'CEP deve ter 8 dígitos.';
  return null;
}

String? validarCpf(String? value) {
  final digitos = value?.trim() ?? '';
  if (digitos.isEmpty) return null;
  if (digitos.length != 11) return 'CPF deve ter 11 dígitos.';
  return null;
}

String? validarTelefone(String? value) {
  final digitos = value?.trim() ?? '';
  if (digitos.isEmpty) return null;
  if (digitos.length < 10 || digitos.length > 11) {
    return 'Telefone deve ter 10 ou 11 dígitos (DDD + número).';
  }
  return null;
}

String? validarDiaVencimento(String? value) {
  final texto = value?.trim() ?? '';
  if (texto.isEmpty) return null;
  final dia = int.tryParse(texto);
  if (dia == null || dia < 1 || dia > 31) return 'Dia deve ser entre 1 e 31.';
  return null;
}
