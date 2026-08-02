import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/utils/imc.dart';

void main() {
  test('calcularImc retorna null quando faltam dados', () {
    expect(calcularImc(pesoKg: null, alturaM: 1.7), isNull);
    expect(calcularImc(pesoKg: 70, alturaM: null), isNull);
    expect(calcularImc(pesoKg: 70, alturaM: 0), isNull);
  });

  test('calcularImc calcula peso / altura ao quadrado', () {
    final imc = calcularImc(pesoKg: 70, alturaM: 1.75);
    expect(imc, closeTo(22.86, 0.01));
  });

  test('classificarImc segue as faixas da OMS', () {
    expect(classificarImc(17).rotulo, 'Abaixo do peso');
    expect(classificarImc(22).rotulo, 'Peso normal');
    expect(classificarImc(27).rotulo, 'Levemente acima do peso');
    expect(classificarImc(32).rotulo, 'Obesidade grau I');
    expect(classificarImc(37).rotulo, 'Obesidade grau II (severa)');
    expect(classificarImc(41).rotulo, 'Obesidade grau III (mórbida)');
  });
}
