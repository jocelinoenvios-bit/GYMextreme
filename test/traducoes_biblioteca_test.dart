import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/constants/categoria_exercicio.dart';
import 'package:gymextreme_app/constants/dificuldade_exercicio.dart';
import 'package:gymextreme_app/constants/equipamentos.dart';
import 'package:gymextreme_app/constants/grupos_musculares.dart';
import 'package:gymextreme_app/constants/musculos.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tradução da Biblioteca Oficial', () {
    test('label* traduzem exemplos conhecidos e preservam valor desconhecido', () {
      expect(labelEquipamento('barbell'), 'Barra reta');
      expect(labelEquipamento('Dumbbell'), 'Halteres');
      expect(labelEquipamento('equipamento-novo'), 'equipamento-novo');

      expect(labelMusculo('pectorals'), 'Peitorais');
      expect(labelMusculo('Quads'), 'Quadríceps');
      expect(labelMusculo('musculo-novo'), 'musculo-novo');

      expect(labelDificuldade('beginner'), 'Iniciante');
      expect(labelDificuldade('ADVANCED'), 'Avançado');
      expect(labelDificuldade('nivel-novo'), 'nivel-novo');

      expect(labelCategoriaExercicio('strength'), 'Força');
      expect(labelCategoriaExercicio('Cardio'), 'Cardio');
      expect(labelCategoriaExercicio('categoria-nova'), 'categoria-nova');
    });

    test(
      'todo bodyPart/equipamento/músculo/dificuldade/categoria dos 1.394 exercícios reais tem tradução',
      () async {
        const repo = LocalExerciseRepository();
        final todos = await repo.buscarTodos();
        expect(todos, isNotEmpty);

        final semTraducao = <String>{};
        for (final exercicio in todos) {
          if (!gruposMuscularesLabels.containsKey(exercicio.bodyPart.toLowerCase())) {
            semTraducao.add('bodyPart: ${exercicio.bodyPart}');
          }
          if (!equipamentosLabels.containsKey(exercicio.equipamentoTexto.toLowerCase())) {
            semTraducao.add('equipment: ${exercicio.equipamentoTexto}');
          }
          if (!dificuldadeLabels.containsKey(exercicio.dificuldade.toLowerCase())) {
            semTraducao.add('difficulty: ${exercicio.dificuldade}');
          }
          if (!categoriaExercicioLabels.containsKey(exercicio.categoria.toLowerCase())) {
            semTraducao.add('category: ${exercicio.categoria}');
          }
          for (final musculo in [
            ...exercicio.musculosPrincipais,
            ...exercicio.musculosAuxiliares,
          ]) {
            if (!musculosLabels.containsKey(musculo.toLowerCase())) {
              semTraducao.add('musculo: $musculo');
            }
          }
        }

        expect(semTraducao, isEmpty, reason: 'valores sem tradução: $semTraducao');
      },
    );
  });
}
