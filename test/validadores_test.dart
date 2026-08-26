import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/utils/validadores.dart';

void main() {
  group('validarCep', () {
    test('vazio é válido (campo opcional)', () {
      expect(validarCep(''), isNull);
    });

    test('8 dígitos é válido', () {
      expect(validarCep('01310100'), isNull);
    });

    test('menos de 8 dígitos é inválido', () {
      expect(validarCep('123'), isNotNull);
    });
  });

  group('validarCpf', () {
    test('vazio é válido (campo opcional)', () {
      expect(validarCpf(''), isNull);
    });

    test('11 dígitos é válido', () {
      expect(validarCpf('12345678900'), isNull);
    });

    test('quantidade errada de dígitos é inválida', () {
      expect(validarCpf('123456789'), isNotNull);
      expect(validarCpf('123456789012'), isNotNull);
    });
  });

  group('validarTelefone', () {
    test('vazio é válido (campo opcional)', () {
      expect(validarTelefone(''), isNull);
    });

    test('10 ou 11 dígitos são válidos', () {
      expect(validarTelefone('1140028922'), isNull);
      expect(validarTelefone('11987654321'), isNull);
    });

    test('menos de 10 ou mais de 11 dígitos é inválido', () {
      expect(validarTelefone('123'), isNotNull);
      expect(validarTelefone('119876543210'), isNotNull);
    });
  });

  group('validarDiaVencimento', () {
    test('vazio é válido (campo opcional)', () {
      expect(validarDiaVencimento(''), isNull);
    });

    test('dias entre 1 e 31 são válidos', () {
      expect(validarDiaVencimento('1'), isNull);
      expect(validarDiaVencimento('15'), isNull);
      expect(validarDiaVencimento('31'), isNull);
    });

    test('dia 0 ou maior que 31 é inválido', () {
      expect(validarDiaVencimento('0'), isNotNull);
      expect(validarDiaVencimento('32'), isNotNull);
    });

    test('texto não numérico é inválido', () {
      expect(validarDiaVencimento('abc'), isNotNull);
    });
  });
}
