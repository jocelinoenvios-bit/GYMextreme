import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/treino.dart';

void main() {
  group('Treino — campos de dia da semana/objetivo/vigência', () {
    test('fromFirestore lê diaSemana, objetivo e vigenciaAte quando presentes', () {
      final treino = Treino.fromFirestore('treino-1', {
        'nome': 'Treino A',
        'letra': 'A',
        'diaSemana': 1,
        'objetivo': 'Hipertrofia',
        'vigenciaAte': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });

      expect(treino.diaSemana, 1);
      expect(treino.objetivo, 'Hipertrofia');
      expect(treino.vigenciaAte, DateTime(2026, 6, 1));
    });

    test('fromFirestore aceita treino antigo sem nenhum desses campos', () {
      final treino = Treino.fromFirestore('treino-antigo', {'nome': 'Treino B', 'letra': 'B'});

      expect(treino.diaSemana, isNull);
      expect(treino.objetivo, isNull);
      expect(treino.vigenciaAte, isNull);
    });

    test('toFirestore grava diaSemana/objetivo/vigenciaAte', () {
      final treino = Treino(
        nome: 'Treino C',
        letra: 'C',
        diaSemana: 5,
        objetivo: 'Emagrecimento',
        vigenciaAte: DateTime(2026, 8, 20),
      );

      final dados = treino.toFirestore();

      expect(dados['diaSemana'], 5);
      expect(dados['objetivo'], 'Emagrecimento');
      expect((dados['vigenciaAte'] as Timestamp).toDate(), DateTime(2026, 8, 20));
    });

    test('copyWith preserva diaSemana/objetivo/vigenciaAte quando não informados', () {
      final original = Treino(
        nome: 'Treino D',
        letra: 'D',
        diaSemana: 3,
        objetivo: 'Força',
        vigenciaAte: DateTime(2026, 12, 1),
      );

      final copia = original.copyWith(nome: 'Treino D editado');

      expect(copia.diaSemana, 3);
      expect(copia.objetivo, 'Força');
      expect(copia.vigenciaAte, DateTime(2026, 12, 1));
    });

    test('copyWith troca diaSemana/objetivo/vigenciaAte quando informados', () {
      final original = Treino(nome: 'Treino E', letra: 'E', diaSemana: 1);

      final copia = original.copyWith(diaSemana: 7, objetivo: 'Novo objetivo');

      expect(copia.diaSemana, 7);
      expect(copia.objetivo, 'Novo objetivo');
    });
  });

  test('diasSemanaLabels está alinhado com a convenção DateTime.weekday (1=Segunda...7=Domingo)', () {
    expect(diasSemanaLabels[DateTime.monday], 'Segunda');
    expect(diasSemanaLabels[DateTime.sunday], 'Domingo');
  });
}
