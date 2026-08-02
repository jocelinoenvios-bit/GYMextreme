/// Calcula a idade em anos completos a partir da data de nascimento,
/// ou `null` se ela nao for informada. Considera o dia/mes atual pra nao
/// contar o aniversario do ano antes de acontecer.
int? calcularIdade(DateTime? dataNascimento, {DateTime? hoje}) {
  if (dataNascimento == null) return null;
  final referencia = hoje ?? DateTime.now();
  var idade = referencia.year - dataNascimento.year;
  final aniversarioJaPassouEsteAno =
      referencia.month > dataNascimento.month ||
      (referencia.month == dataNascimento.month && referencia.day >= dataNascimento.day);
  if (!aniversarioJaPassouEsteAno) idade--;
  return idade;
}
