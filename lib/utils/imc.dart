import 'package:flutter/material.dart';

/// Calcula o IMC (Kg/m2) a partir do peso e altura, ou `null` se faltar
/// algum dado. Mesma formula do quadro "INDICE DE MASSA CORPORAL" da
/// ficha em papel: Peso / (Altura x Altura).
double? calcularImc({required double? pesoKg, required double? alturaM}) {
  if (pesoKg == null || alturaM == null || alturaM <= 0) return null;
  return pesoKg / (alturaM * alturaM);
}

/// Classificacao de IMC (OMS), igual a tabela impressa na ficha.
class ImcClassificacao {
  const ImcClassificacao(this.rotulo, this.cor);

  final String rotulo;
  final Color cor;
}

ImcClassificacao classificarImc(double imc) {
  if (imc < 18.5) {
    return const ImcClassificacao('Abaixo do peso', Color(0xFF4FA8E8));
  }
  if (imc < 25.0) {
    return const ImcClassificacao('Peso normal', Color(0xFF4CAF6D));
  }
  if (imc < 30.0) {
    return const ImcClassificacao('Levemente acima do peso', Color(0xFFE8C34F));
  }
  if (imc < 35.0) {
    return const ImcClassificacao('Obesidade grau I', Color(0xFFE89A4F));
  }
  if (imc < 40.0) {
    return const ImcClassificacao('Obesidade grau II (severa)', Color(0xFFE86B4F));
  }
  return const ImcClassificacao('Obesidade grau III (mórbida)', Color(0xFFD64545));
}
