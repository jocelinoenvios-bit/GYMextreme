import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';

void main() {
  group('MockExerciseRepository', () {
    test('retorna os exercicios prescritos, na ordem de execucao', () async {
      const repo = MockExerciseRepository();
      final exercicios = await repo.buscarExerciciosDoTreino('qualquer-treino-id');

      expect(exercicios.length, 3);
      expect(exercicios[0].exercise.nome, 'Voador na Máquina');
      expect(exercicios[1].exercise.nome, 'Remada Baixa');
      expect(exercicios[2].exercise.nome, 'Agachamento Livre');
    });

    test('cada exercicio traz a prescricao completa', () async {
      const repo = MockExerciseRepository();
      final exercicios = await repo.buscarExerciciosDoTreino('qualquer-treino-id');

      final voador = exercicios.first;
      expect(voador.series, 3);
      expect(voador.repeticoes, '12');
      expect(voador.cargaKg, 18);
      expect(voador.observacoesPersonal, isNotNull);
    });

    test('exercicios sem ajuste de maquina nao quebram (campo opcional)', () async {
      const repo = MockExerciseRepository();
      final exercicios = await repo.buscarExerciciosDoTreino('qualquer-treino-id');

      final agachamento = exercicios.last;
      expect(agachamento.exercise.ajusteMaquina, isNull);
    });

    test('ignora o treinoId — mesma prescricao pra qualquer id (placeholder)', () async {
      const repo = MockExerciseRepository();
      final a = await repo.buscarExerciciosDoTreino('id-a');
      final b = await repo.buscarExerciciosDoTreino('id-b-completamente-diferente');

      expect(a.length, b.length);
      expect(a.first.exercise.id, b.first.exercise.id);
    });
  });
}
