import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/utils/moeda.dart';

void main() {
  group('formatarReais', () {
    test('valores simples', () {
      expect(formatarReais(129.9), 'R\$ 129,90');
      expect(formatarReais(0), 'R\$ 0,00');
    });

    test('milhar com separador de ponto', () {
      expect(formatarReais(1234.56), 'R\$ 1.234,56');
      expect(formatarReais(1234567.89), 'R\$ 1.234.567,89');
    });

    test('valor negativo', () {
      expect(formatarReais(-50), '-R\$ 50,00');
    });
  });

  group('parseValorReais', () {
    test('formato brasileiro com virgula', () {
      expect(parseValorReais('129,90'), 129.9);
      expect(parseValorReais('1.234,56'), 1234.56);
    });

    test('formato americano com ponto decimal', () {
      expect(parseValorReais('129.90'), 129.9);
      expect(parseValorReais('129.9'), 129.9);
    });

    test('milhar sem decimais (ponto tratado como milhar)', () {
      expect(parseValorReais('1.234'), 1234);
    });

    test('numero inteiro simples', () {
      expect(parseValorReais('129'), 129);
    });

    test('texto vazio ou invalido retorna null', () {
      expect(parseValorReais(''), isNull);
      expect(parseValorReais('abc'), isNull);
    });
  });
}
