import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';

/// Confirma a convenção de caminho do GIF oficial (360°) da Biblioteca
/// Oficial (ExerciseDB) e que os 1.394 arquivos-fonte (180°/360°) ainda
/// existem no repositório — mesmo não sendo mais empacotados no APK
/// (Fase 2: só a variante 360° vai pro Firebase Storage, baixada sob
/// demanda via `GifCacheService`, ver `gif_cache_service_test.dart` e
/// `vital_animations_test.dart`; a 180° fica de fora do upload de
/// propósito — hospedar as duas dobraria armazenamento/banda sem
/// necessidade). Esta suíte não carrega os GIFs pelo asset bundle do
/// Flutter (eles deliberadamente pararam de ser declarados em
/// pubspec.yaml) — só garante que o arquivo-fonte de cada um continua
/// no disco, pronto pro `upload-gifs-storage.js` subir pro Storage. Os
/// 44 exercícios novos da Vital Animations (só vídeo, sem GIF
/// correspondente na ExerciseDB) ficam de fora de propósito.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Biblioteca Oficial — GIF 360° (Fase 2: fonte local, servido via Storage)', () {
    const repo = LocalExerciseRepository();

    test('a convenção de caminho do Storage usa o id original, sem renomeação', () {
      expect(ExerciseModel.gif360PathPara('0577'), 'exercicios/gifs/0577.gif');
    });

    test(
      'os 1.394 exercícios da ExerciseDB têm gif360Url apontando pro Storage (não mais '
      'asset local) e gif180Url sempre nulo (só a 360° é hospedada), e o arquivo-fonte '
      '(180°/360°) de cada um ainda existe no repositório',
      () async {
        final todos = await repo.buscarTodos();
        // 1.394 da ExerciseDB (todos com GIF) + 44 novos da Vital
        // Animations (só vídeo, sem GIF) = 1.438.
        expect(todos.length, 1438);

        final comGif = todos.where((e) => e.gif360Url != null).toList();
        expect(comGif.length, 1394, reason: 'só os exercícios originais da ExerciseDB têm GIF');

        for (final exercicio in comGif) {
          expect(
            exercicio.gif180Url,
            isNull,
            reason: '${exercicio.id}: gif180Url deveria ser sempre nulo — só a 360° é hospedada',
          );
          expect(
            exercicio.gif360Url,
            'exercicios/gifs/${exercicio.id}.gif',
            reason: '${exercicio.id}: gif360Url não segue mais a convenção do Storage',
          );
          expect(
            exercicio.temVarianteAltaResolucao,
            isTrue,
            reason: '${exercicio.id}: variante 360 não sinalizada',
          );

          _expectArquivoFonteExiste('assets/exercicios/gifs/${exercicio.id}.gif');
          _expectArquivoFonteExiste('assets/exercicios/gifs_360/${exercicio.id}.gif');
        }
      },
    );
  });
}

void _expectArquivoFonteExiste(String caminhoRelativo) {
  final arquivo = File(caminhoRelativo);
  expect(
    arquivo.existsSync(),
    isTrue,
    reason:
        '$caminhoRelativo não existe mais no repositório — sem ele, '
        'upload-gifs-storage.js não tem o que subir pro Storage.',
  );
  expect(arquivo.lengthSync(), greaterThan(0), reason: '$caminhoRelativo existe mas está vazio');
}
