import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';

/// Confirma que os GIFs oficiais (180° e 360°) cobrem os 1.394
/// exercícios da Biblioteca Oficial (ExerciseDB), carregando de verdade
/// através do asset bundle do Flutter — não só checando o caminho. Os
/// 44 exercícios novos da Vital Animations (só vídeo, sem GIF
/// correspondente na ExerciseDB) ficam de fora desta checagem de
/// propósito — ver `exercicio_midia_test.dart` pra cobertura deles.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Biblioteca Oficial — GIFs 180°/360°', () {
    const repo = LocalExerciseRepository();

    test(
      'os 1.394 exercícios da ExerciseDB têm GIF 180 e 360 carregando corretamente, sem exceção',
      () async {
        final todos = await repo.buscarTodos();
        // 1.394 da ExerciseDB (todos com GIF) + 44 novos da Vital
        // Animations (só vídeo, sem GIF) = 1.438.
        expect(todos.length, 1438);

        final comGif = todos.where((e) => e.gif180Url != null).toList();
        expect(
          comGif.length,
          1394,
          reason: 'só os exercícios originais da ExerciseDB têm GIF',
        );

        for (final exercicio in comGif) {
          final gif360 = exercicio.gif360Url;
          expect(
            gif360,
            isNotNull,
            reason: '${exercicio.id}: sem gif360Url — todo exercício da ExerciseDB deveria ter a variante 360',
          );
          expect(
            exercicio.temVarianteAltaResolucao,
            isTrue,
            reason: '${exercicio.id}: variante 360 não sinalizada',
          );

          await _expectGifCarrega(exercicio.gif180Url!);
          await _expectGifCarrega(gif360!);
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test('a convenção de caminho usa o id original, sem renomeação', () {
      expect(ExerciseModel.gif180PathPara('0577'), 'assets/exercicios/gifs/0577.gif');
      expect(ExerciseModel.gif360PathPara('0577'), 'assets/exercicios/gifs_360/0577.gif');
    });
  });
}

Future<void> _expectGifCarrega(String path) async {
  final bytes = await rootBundle.load(path);
  expect(bytes.lengthInBytes, greaterThan(0), reason: '$path carregou vazio');
  final assinatura = String.fromCharCodes(bytes.buffer.asUint8List(bytes.offsetInBytes, 6));
  expect(
    ['GIF87a', 'GIF89a'].contains(assinatura),
    isTrue,
    reason: '$path não é um GIF válido (assinatura: $assinatura)',
  );
}
