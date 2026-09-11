import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/screens/area_aluno/treino_detalhe_aluno_screen.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

class _FakeExerciseRepository implements ExerciseRepository {
  const _FakeExerciseRepository();

  static const _catalogo = <String, ExerciseModel>{
    '0577': ExerciseModel(
      id: '0577',
      nome: 'lever chest press',
      bodyPart: 'chest',
      equipmentCategory: 'machine',
      equipamentoTexto: 'leverage machine',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'chest press',
      musculosPrincipais: ['chest'],
      gif180Url: 'assets/exercicios/gifs/0577.gif',
    ),
  };

  @override
  Future<ExerciseModel?> buscarPorId(String id) async => _catalogo[id];

  @override
  Future<List<ExerciseModel>> buscarTodos() async => _catalogo.values.toList(growable: false);
}

void main() {
  group('TreinoDetalheAlunoScreen', () {
    testWidgets('mostra nome, badges de dia/objetivo e os exercícios prescritos', (tester) async {
      const treino = Treino(
        id: 'treino-a',
        nome: 'Treino A',
        letra: 'A',
        diaSemana: 1,
        objetivo: 'Hipertrofia',
        exercicios: [
          TreinoExercicio(exercicioId: '0577', series: 3, repeticoes: '12', ordem: 0),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          const TreinoDetalheAlunoScreen(
            alunoUid: 'aluno-1',
            treino: treino,
            repository: _FakeExerciseRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Treino A'), findsOneWidget);
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('Hipertrofia'), findsOneWidget);
      expect(find.text('lever chest press'), findsOneWidget);
      expect(find.textContaining('3 séries'), findsOneWidget);
    });

    testWidgets('ficha inativa (anterior) mostra o selo "Ficha anterior"', (tester) async {
      const treino = Treino(id: 'treino-antigo', nome: 'Treino Z', letra: 'Z', ativo: false);

      await tester.pumpWidget(
        _wrap(
          const TreinoDetalheAlunoScreen(
            alunoUid: 'aluno-1',
            treino: treino,
            repository: _FakeExerciseRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ficha anterior'), findsOneWidget);
    });

    testWidgets('sem exercícios cadastrados mostra mensagem amigável, não lista vazia quebrada', (
      tester,
    ) async {
      const treino = Treino(id: 'treino-vazio', nome: 'Treino Vazio', letra: 'V');

      await tester.pumpWidget(
        _wrap(
          const TreinoDetalheAlunoScreen(
            alunoUid: 'aluno-1',
            treino: treino,
            repository: _FakeExerciseRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Este treino ainda não tem exercícios cadastrados.'), findsOneWidget);
    });
  });
}
