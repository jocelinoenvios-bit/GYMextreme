import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';

/// Confirma que os 50 vídeos da Vital Animations são referenciados como
/// asset local (dentro do APK) — nunca um caminho de Firebase Storage —
/// e que o arquivo-fonte de cada um existe de verdade no repositório.
/// Decisão de arquitetura confirmada: os vídeos NUNCA dependem do
/// Storage pra tocar (ao contrário dos GIFs da ExerciseDB, que vivem no
/// Storage a partir da Fase 2, ver `exercise_gifs_test.dart`) — o
/// player (`ExercicioMidia`) usa `VideoPlayerController.asset(url)`
/// diretamente, então funcionam 100% offline, mesmo sem o Firebase
/// configurado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vital Animations — 50 vídeos são asset local, nunca Storage', () {
    const repo = LocalExerciseRepository();

    /// Fonte da verdade do mapeamento id -> vídeo (o mesmo arquivo que
    /// `LocalExerciseRepository` carrega em produção) — lido direto do
    /// disco, sem depender do asset bundle do Flutter, pra não acoplar
    /// esta suíte ao pubspec.yaml.
    Map<String, String> lerMapaDeVideos() {
      final texto = File('assets/exercicios/videos_vital_animations.json').readAsStringSync();
      return Map<String, String>.from(json.decode(texto) as Map);
    }

    test('o mapa id -> vídeo tem exatamente 50 entradas', () {
      expect(lerMapaDeVideos().length, 50);
    });

    test(
      'os 50 vídeos são assets locais (assets/exercicios/videos/{id}.mp4), nunca um caminho '
      'de Storage, e o arquivo-fonte de cada um existe de verdade no repositório',
      () async {
        final mapaDeVideos = lerMapaDeVideos();
        final todos = await repo.buscarTodos();
        final porId = {for (final exercicio in todos) exercicio.id: exercicio};

        for (final entry in mapaDeVideos.entries) {
          final id = entry.key;
          final caminhoEsperado = 'assets/exercicios/videos/$id.mp4';
          expect(
            entry.value,
            caminhoEsperado,
            reason: '$id: videos_vital_animations.json não segue a convenção esperada',
          );

          final exercicio = porId[id];
          expect(exercicio, isNotNull, reason: '$id: tem vídeo mas não existe no catálogo');
          expect(
            exercicio!.videoUrl,
            caminhoEsperado,
            reason: '$id: ExerciseModel.videoUrl não bate com o mapeamento',
          );
          expect(
            exercicio.videoUrl!.startsWith('assets/'),
            isTrue,
            reason: '$id: videoUrl deveria ser sempre um asset local, nunca um caminho de Storage',
          );

          _expectArquivoFonteExiste(caminhoEsperado);
        }
      },
    );

    test('nenhum exercício fora do mapa de vídeos tem videoUrl (nada além dos 50)', () async {
      final mapaDeVideos = lerMapaDeVideos();
      final todos = await repo.buscarTodos();
      final comVideo = todos.where((e) => e.videoUrl != null).toList();

      expect(comVideo.length, 50, reason: 'só os ids do mapa deveriam ter videoUrl populado');
      for (final exercicio in comVideo) {
        expect(
          mapaDeVideos.containsKey(exercicio.id),
          isTrue,
          reason: '${exercicio.id}: tem videoUrl mas não está em videos_vital_animations.json',
        );
      }
    });
  });
}

void _expectArquivoFonteExiste(String caminhoRelativo) {
  final arquivo = File(caminhoRelativo);
  expect(
    arquivo.existsSync(),
    isTrue,
    reason: '$caminhoRelativo não existe no repositório — o app não vai conseguir tocar esse vídeo.',
  );
  expect(arquivo.lengthSync(), greaterThan(0), reason: '$caminhoRelativo existe mas está vazio');
}
