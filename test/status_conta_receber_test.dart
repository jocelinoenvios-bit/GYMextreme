import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/conta_receber.dart';
import 'package:gymextreme_app/utils/status_conta_receber.dart';

ContaReceber _conta({
  required DateTime vencimento,
  StatusContaReceber status = StatusContaReceber.pendente,
}) {
  return ContaReceber(
    alunoId: 'aluno1',
    descricao: 'Mensalidade',
    valorOriginal: 100,
    vencimento: vencimento,
    status: status,
  );
}

void main() {
  group('calcularStatusEfetivo', () {
    test('pendente antes do vencimento continua pendente', () {
      final status = calcularStatusEfetivo(
        _conta(vencimento: DateTime(2026, 9, 10)),
        hoje: DateTime(2026, 9, 5),
      );
      expect(status, StatusContaReceber.pendente);
    });

    test('pendente no dia exato do vencimento ainda nao e vencido', () {
      final status = calcularStatusEfetivo(
        _conta(vencimento: DateTime(2026, 9, 10)),
        hoje: DateTime(2026, 9, 10),
      );
      expect(status, StatusContaReceber.pendente);
    });

    test('pendente um dia depois do vencimento vira vencido', () {
      final status = calcularStatusEfetivo(
        _conta(vencimento: DateTime(2026, 9, 10)),
        hoje: DateTime(2026, 9, 11),
      );
      expect(status, StatusContaReceber.vencido);
    });

    test('paga nao vira vencida mesmo com o vencimento no passado', () {
      final status = calcularStatusEfetivo(
        _conta(vencimento: DateTime(2026, 1, 1), status: StatusContaReceber.pago),
        hoje: DateTime(2026, 9, 11),
      );
      expect(status, StatusContaReceber.pago);
    });

    test('cancelada nao vira vencida mesmo com o vencimento no passado', () {
      final status = calcularStatusEfetivo(
        _conta(vencimento: DateTime(2026, 1, 1), status: StatusContaReceber.cancelado),
        hoje: DateTime(2026, 9, 11),
      );
      expect(status, StatusContaReceber.cancelado);
    });
  });
}
