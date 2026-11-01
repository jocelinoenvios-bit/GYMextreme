import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/utils/lembrete_vencimento.dart';
import 'package:gymextreme_app/utils/mensalidade_utils.dart';

void main() {
  group('primeiroVencimento', () {
    test('1 mes depois do dia do cadastro, sem horario', () {
      expect(
        primeiroVencimento(DateTime(2026, 3, 10, 17, 45)),
        DateTime(2026, 4, 10),
      );
      expect(primeiroVencimento(DateTime(2026, 12, 5)), DateTime(2027, 1, 5));
    });

    test('mes seguinte mais curto cai no ultimo dia dele', () {
      expect(primeiroVencimento(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    });
  });

  group('deveLembrarVencimento', () {
    final vencimento = DateTime(2026, 11, 10);

    test('de 3 dias antes ate o dia do vencimento', () {
      expect(
        deveLembrarVencimento(vencimento, DateTime(2026, 11, 6, 23, 59)),
        isFalse,
      );
      expect(
        deveLembrarVencimento(vencimento, DateTime(2026, 11, 7, 0, 1)),
        isTrue,
      );
      expect(deveLembrarVencimento(vencimento, DateTime(2026, 11, 9)), isTrue);
      expect(
        deveLembrarVencimento(vencimento, DateTime(2026, 11, 10, 22)),
        isTrue,
      );
    });

    test('depois de vencido ou sem vencimento nao lembra', () {
      expect(
        deveLembrarVencimento(vencimento, DateTime(2026, 11, 11)),
        isFalse,
      );
      expect(deveLembrarVencimento(null, DateTime(2026, 11, 9)), isFalse);
    });

    test('atravessa a virada do mes', () {
      expect(
        deveLembrarVencimento(DateTime(2026, 12, 1), DateTime(2026, 11, 28)),
        isTrue,
      );
      expect(
        deveLembrarVencimento(DateTime(2026, 12, 1), DateTime(2026, 11, 27)),
        isFalse,
      );
    });
  });

  test('id fixo por vencimento, no formato da regra do Firestore', () {
    expect(
      idLembreteVencimento(DateTime(2026, 3, 5, 14)),
      'lembrete-vencimento-2026-03-05',
    );
    expect(
      RegExp(
        r'^lembrete-vencimento-[0-9]{4}-[0-9]{2}-[0-9]{2}$',
      ).hasMatch(idLembreteVencimento(DateTime(2027, 12, 31))),
      isTrue,
    );
  });

  test('texto da mensagem leva a data; aviso curto e relativo a hoje', () {
    final vencimento = DateTime(2026, 11, 10);
    expect(textoLembreteVencimento(vencimento), contains('10/11'));
    expect(textoLembreteVencimento(vencimento).length, lessThanOrEqualTo(300));
    expect(
      avisoCurtoVencimento(vencimento, DateTime(2026, 11, 7)),
      'Sua mensalidade vence em 10/11',
    );
    expect(
      avisoCurtoVencimento(vencimento, DateTime(2026, 11, 9)),
      'Sua mensalidade vence amanhã',
    );
    expect(
      avisoCurtoVencimento(vencimento, DateTime(2026, 11, 10)),
      'Sua mensalidade vence hoje',
    );
  });
}
