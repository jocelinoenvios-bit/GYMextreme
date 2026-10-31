import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';

/// Confirma que o GIF foi desligado de propósito pro catálogo inteiro
/// (apareciam corrompidos em aparelho real) — os arquivos-fonte
/// (`assets/exercicios/gifs/` e `gifs_360/`) foram removidos do
/// repositório, e a Biblioteca de Exercícios hoje só mostra os 50
/// exercícios com vídeo (Vital Animations).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Biblioteca Oficial — GIF removido, só vídeo', () {
    const repo = LocalExerciseRepository();

    test('a convenção de caminho do Storage usa o id original, sem renomeação', () {
      expect(ExerciseModel.gif360PathPara('0577'), 'exercicios/gifs/0577.gif');
    });

    test('nenhum exercício expõe gif360Url — GIF foi desligado pro catálogo inteiro', () async {
      final todos = await repo.buscarTodos();
      // 1.394 da ExerciseDB + 44 novos da Vital Animations = 1.438.
      expect(todos.length, 1438);

      expect(
        todos.every((e) => e.gif360Url == null),
        isTrue,
        reason: 'LocalExerciseRepository deve passar temGif: false pra todo exercício',
      );
    });
  });
}
