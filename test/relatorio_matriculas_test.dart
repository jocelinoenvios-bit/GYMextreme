import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/matricula.dart';
import 'package:gymextreme_app/utils/relatorio_matriculas.dart';

final _hoje = DateTime(2026, 8, 10);

Matricula _matricula({
  required String id,
  StatusMatricula status = StatusMatricula.ativa,
  DateTime? dataVencimento,
  DateTime? criadoEm,
}) {
  return Matricula(
    id: id,
    alunoId: 'a1',
    planoId: 'p1',
    dataInicio: DateTime(2026, 1, 1),
    dataVencimento: dataVencimento ?? DateTime(2026, 12, 1),
    valorContratado: 100,
    status: status,
    criadoEm: criadoEm,
  );
}

void main() {
  group('calcularResumoMatriculas', () {
    test('lista vazia da resumo zerado', () {
      final resumo = calcularResumoMatriculas(const [], hoje: _hoje);
      expect(resumo.total, 0);
      expect(resumo.ativas, 0);
      expect(resumo.encerradas, 0);
      expect(resumo.vencendoEmBreve, 0);
    });

    test('separa ativas de encerradas (vencida/cancelada/suspensa)', () {
      final resumo = calcularResumoMatriculas([
        _matricula(id: 'm1'),
        _matricula(id: 'm2', status: StatusMatricula.vencida),
        _matricula(id: 'm3', status: StatusMatricula.cancelada),
        _matricula(id: 'm4', status: StatusMatricula.suspensa),
      ], hoje: _hoje);

      expect(resumo.total, 4);
      expect(resumo.ativas, 1);
      expect(resumo.encerradas, 3);
    });

    test('conta matriculas ativas vencendo dentro da janela de alerta', () {
      final resumo = calcularResumoMatriculas([
        _matricula(id: 'm1', dataVencimento: DateTime(2026, 8, 12)), // 2 dias
        _matricula(id: 'm2', dataVencimento: DateTime(2026, 8, 30)), // fora da janela
        _matricula(
          id: 'm3',
          status: StatusMatricula.vencida,
          dataVencimento: DateTime(2026, 8, 11),
        ), // nao ativa, nao conta
      ], hoje: _hoje, diasAlerta: 7);

      expect(resumo.vencendoEmBreve, 1);
    });
  });

  group('filtrarMatriculasPorPeriodoDeCriacao', () {
    final matriculas = [
      _matricula(id: 'm1', criadoEm: DateTime(2026, 7, 1)),
      _matricula(id: 'm2', criadoEm: DateTime(2026, 8, 5)),
      _matricula(id: 'm3', criadoEm: DateTime(2026, 9, 1)),
    ];

    test('sem periodo, retorna todas', () {
      expect(filtrarMatriculasPorPeriodoDeCriacao(matriculas), hasLength(3));
    });

    test('filtra pelo intervalo de criacao', () {
      final filtradas = filtrarMatriculasPorPeriodoDeCriacao(
        matriculas,
        de: DateTime(2026, 8, 1),
        ate: DateTime(2026, 8, 31),
      );
      expect(filtradas, hasLength(1));
      expect(filtradas.single.id, 'm2');
    });
  });
}
