/// Formata um valor em reais como "R$ 1.234,56" — sem depender do pacote
/// `intl` (não usado em nenhum outro lugar do app ainda).
String formatarReais(double valor) {
  final negativo = valor < 0;
  final centavos = (valor.abs() * 100).round();
  final inteiro = centavos ~/ 100;
  final decimais = (centavos % 100).toString().padLeft(2, '0');

  final inteiroTexto = inteiro.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < inteiroTexto.length; i++) {
    final posicaoDaDireita = inteiroTexto.length - i;
    buffer.write(inteiroTexto[i]);
    if (posicaoDaDireita > 1 && posicaoDaDireita % 3 == 1) {
      buffer.write('.');
    }
  }

  return '${negativo ? '-' : ''}R\$ $buffer,$decimais';
}

/// Interpreta um texto digitado pelo usuário ("129,90", "129.90", "1.234,56"
/// ou "129") como valor em reais. `null` se não for um número válido.
///
/// Regra pra decidir o que é separador decimal e o que é separador de
/// milhar: vírgula presente sempre vence (formato brasileiro, "." vira
/// milhar); sem vírgula, um único "." seguido de até 2 dígitos é tratado
/// como decimal (formato americano, "129.90"); qualquer outro caso de "."
/// (vários pontos, ou mais de 2 dígitos depois do último) é milhar.
double? parseValorReais(String texto) {
  var normalizado = texto.trim();
  if (normalizado.isEmpty) return null;

  if (normalizado.contains(',')) {
    normalizado = normalizado.replaceAll('.', '').replaceAll(',', '.');
  } else {
    final pontos = '.'.allMatches(normalizado).length;
    final casasAposUltimoPonto = normalizado.length - normalizado.lastIndexOf('.') - 1;
    final ehDecimalAmericano = pontos == 1 && casasAposUltimoPonto <= 2;
    if (!ehDecimalAmericano) {
      normalizado = normalizado.replaceAll('.', '');
    }
  }

  return double.tryParse(normalizado);
}
