import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/screens/area_aluno/widgets/exercicio_midia.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

/// Cobre a integração dos 50 vídeos da Vital Animations: mesclagem no
/// catálogo (sem colisão de id, sem duplicata, sem alterar o que já
/// existia) e o comportamento vídeo-primeiro/GIF-fallback do widget de
/// mídia. Não valida reprodução real do vídeo (o ambiente de teste do
/// Flutter não tem um decoder de vídeo de verdade) — só que o app nunca
/// quebra e sempre cai pro GIF quando o vídeo não pode ser inicializado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalExerciseRepository — mesclagem da Vital Animations', () {
    const repo = LocalExerciseRepository();

    test('catálogo final tem 1.438 exercícios (1.394 da ExerciseDB + 44 novos)', () async {
      final todos = await repo.buscarTodos();
      expect(todos.length, 1438);
    });

    test('nenhum id duplicado após a mesclagem', () async {
      final todos = await repo.buscarTodos();
      final ids = todos.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test(
      'os 6 exercícios já existentes que casaram por nome ganharam vídeo sem perder nome/GIF/id',
      () async {
        const casados = {
          '0042': 'barbell front squat',
          '0085': 'barbell romanian deadlift',
          '1760': 'dumbbell goblet squat',
          '0549': 'kettlebell swing',
          '0120': 'barbell upright row',
          '0437': 'dumbbell upright row',
        };
        for (final entry in casados.entries) {
          final exercicio = await repo.buscarPorId(entry.key);
          expect(exercicio, isNotNull, reason: 'id ${entry.key} deveria continuar existindo');
          expect(exercicio!.nome, entry.value);
          expect(exercicio.videoUrl, 'assets/exercicios/videos/${entry.key}.mp4');
          expect(exercicio.gif180Url, isNotNull, reason: 'GIF original não deveria ter sido removido');
        }
      },
    );

    test('exercícios novos da Vital Animations (ids 9001-9044) têm vídeo e não têm GIF', () async {
      final pecDeck = await repo.buscarPorId('9001');
      expect(pecDeck, isNotNull);
      expect(pecDeck!.nome, 'pec deck machine fly');
      expect(pecDeck.videoUrl, 'assets/exercicios/videos/9001.mp4');
      expect(pecDeck.gif180Url, isNull);
      expect(pecDeck.gif360Url, isNull);

      final ultimoNovo = await repo.buscarPorId('9044');
      expect(ultimoNovo, isNotNull);
      expect(ultimoNovo!.nome, 'rear delt cable fly');
      expect(ultimoNovo.videoUrl, 'assets/exercicios/videos/9044.mp4');
    });

    test('exercício que não tem vídeo continua sem videoUrl (nada mudou pra ele)', () async {
      final exercicio = await repo.buscarPorId('0001');
      expect(exercicio, isNotNull);
      expect(exercicio!.videoUrl, isNull);
      expect(exercicio.gif180Url, isNotNull);
    });
  });

  group('ExercicioMidia — prioridade vídeo, fallback GIF', () {
    Widget wrap(Widget child) =>
        MaterialApp(theme: AppTheme.dark, home: Scaffold(body: SizedBox(height: 300, child: child)));

    const semVideo = ExerciseModel(
      id: '0001',
      nome: '3/4 sit-up',
      bodyPart: 'waist',
      equipmentCategory: 'bodyweight',
      equipamentoTexto: 'body weight',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'sit up',
      gif180Url: 'assets/exercicios/gifs/0001.gif',
      gif360Url: 'assets/exercicios/gifs_360/0001.gif',
    );

    const comVideoEGif = ExerciseModel(
      id: '0042',
      nome: 'barbell front squat',
      bodyPart: 'upper legs',
      equipmentCategory: 'free_weight',
      equipamentoTexto: 'barbell',
      dificuldade: 'intermediate',
      categoria: 'strength',
      movementFamily: 'squat',
      gif180Url: 'assets/exercicios/gifs/0042.gif',
      gif360Url: 'assets/exercicios/gifs_360/0042.gif',
      videoUrl: 'assets/exercicios/videos/0042.mp4',
    );

    const comVideoSemGif = ExerciseModel(
      id: '9001',
      nome: 'pec deck machine fly',
      bodyPart: 'chest',
      equipmentCategory: 'unknown',
      equipamentoTexto: 'machine',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: '',
      videoUrl: 'assets/exercicios/videos/9001.mp4',
    );

    testWidgets('sem videoUrl: usa o GIF direto, nunca tenta inicializar vídeo', (tester) async {
      final controller = ExercicioMidiaController(tocandoInicial: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(ExercicioMidia(exercise: semVideo, controller: controller, fit: BoxFit.contain)),
      );
      await tester.pump();

      expect(find.byType(Gif), findsOneWidget);
    });

    testWidgets(
      'com videoUrl (e GIF de reserva): a inicializacao do vídeo falha no ambiente de teste '
      '(sem decoder real) e cai pro GIF automaticamente, sem quebrar a tela',
      (tester) async {
        final controller = ExercicioMidiaController(tocandoInicial: true);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          wrap(ExercicioMidia(exercise: comVideoEGif, controller: controller, fit: BoxFit.contain)),
        );
        // Dá tempo pro `VideoPlayerController.initialize()` falhar
        // (MissingPluginException, sem platform channel no teste) e o
        // catch cair pro fallback.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(Gif), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'com videoUrl e sem GIF de reserva: falha do vídeo mostra indicador em vez de quebrar',
      (tester) async {
        final controller = ExercicioMidiaController(tocandoInicial: true);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          wrap(ExercicioMidia(exercise: comVideoSemGif, controller: controller, fit: BoxFit.contain)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(Gif), findsNothing);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('reduceMotion: nem tenta inicializar o vídeo, vai direto pro GIF parado', (
      tester,
    ) async {
      final controller = ExercicioMidiaController(tocandoInicial: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          ExercicioMidia(
            exercise: comVideoEGif,
            controller: controller,
            fit: BoxFit.contain,
            reduceMotion: true,
          ),
        ),
      );
      await tester.pump();

      final gif = tester.widget<Gif>(find.byType(Gif));
      expect(gif.autostart, Autostart.no);
    });
  });
}
