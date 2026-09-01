import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/screens/area_aluno/widgets/exercicio_midia.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_gif_bytes.dart';
import 'support/fake_gif_cache_service.dart';

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
          expect(exercicio.gif360Url, isNotNull, reason: 'GIF original não deveria ter sido removido');
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
      expect(exercicio.gif360Url, isNotNull);
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
      gif360Url: 'exercicios/gifs/0001.gif',
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
      gif360Url: 'exercicios/gifs/0042.gif',
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
      final fake = FakeGifCacheService()
        ..doCache['exercicios/gifs/0001.gif'] = MemoryImage(gifDeTesteValido);

      await tester.pumpWidget(
        wrap(
          ExercicioMidia(
            exercise: semVideo,
            controller: controller,
            fit: BoxFit.contain,
            gifCacheService: fake,
          ),
        ),
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
        final fake = FakeGifCacheService()
          ..doCache['exercicios/gifs/0042.gif'] = MemoryImage(gifDeTesteValido);

        await tester.pumpWidget(
          wrap(
            ExercicioMidia(
              exercise: comVideoEGif,
              controller: controller,
              fit: BoxFit.contain,
              gifCacheService: fake,
            ),
          ),
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
      final fake = FakeGifCacheService()
        ..doCache['exercicios/gifs/0042.gif'] = MemoryImage(gifDeTesteValido);

      await tester.pumpWidget(
        wrap(
          ExercicioMidia(
            exercise: comVideoEGif,
            controller: controller,
            fit: BoxFit.contain,
            reduceMotion: true,
            gifCacheService: fake,
          ),
        ),
      );
      await tester.pump();

      final gif = tester.widget<Gif>(find.byType(Gif));
      expect(gif.autostart, Autostart.no);
    });
  });

  group('ExercicioMidia — GIF via Firebase Storage + cache (Fase 2)', () {
    Widget wrap(Widget child) =>
        MaterialApp(theme: AppTheme.dark, home: Scaffold(body: SizedBox(height: 300, child: child)));

    const semVideoGifStorage = ExerciseModel(
      id: '0577',
      nome: 'lever chest press',
      bodyPart: 'chest',
      equipmentCategory: 'machine',
      equipamentoTexto: 'leverage machine',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'chest press',
      gif360Url: 'exercicios/gifs/0577.gif',
    );

    const comVideoEGifStorage = ExerciseModel(
      id: '0042',
      nome: 'barbell front squat',
      bodyPart: 'upper legs',
      equipmentCategory: 'free_weight',
      equipamentoTexto: 'barbell',
      dificuldade: 'intermediate',
      categoria: 'strength',
      movementFamily: 'squat',
      gif360Url: 'exercicios/gifs/0042.gif',
      videoUrl: 'assets/exercicios/videos/0042.mp4',
    );

    final imagemFalsa = MemoryImage(gifDeTesteValido);

    testWidgets('b) GIF já no cache: usa direto, nunca chama o download do Storage', (tester) async {
      final controller = ExercicioMidiaController(tocandoInicial: true);
      addTearDown(controller.dispose);
      final fake = FakeGifCacheService()..doCache['exercicios/gifs/0577.gif'] = imagemFalsa;

      await tester.pumpWidget(
        wrap(
          ExercicioMidia(
            exercise: semVideoGifStorage,
            controller: controller,
            fit: BoxFit.contain,
            gifCacheService: fake,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Gif), findsOneWidget);
      final gif = tester.widget<Gif>(find.byType(Gif));
      expect(gif.image, imagemFalsa);
      expect(fake.caminhosBaixados, isEmpty, reason: 'já tinha no cache, não devia baixar de novo');
    });

    testWidgets('c) GIF não está no cache: baixa do Firebase Storage e depois exibe', (tester) async {
      final controller = ExercicioMidiaController(tocandoInicial: true);
      addTearDown(controller.dispose);
      final fake = FakeGifCacheService()..doDownload['exercicios/gifs/0577.gif'] = imagemFalsa;

      await tester.pumpWidget(
        wrap(
          ExercicioMidia(
            exercise: semVideoGifStorage,
            controller: controller,
            fit: BoxFit.contain,
            gifCacheService: fake,
          ),
        ),
      );
      // A fake resolve o download sem delay real (sem Future.delayed) —
      // não há uma janela confiável de "ainda carregando" pra testar
      // aqui (ao contrário do vídeo, que passa por um MethodChannel de
      // verdade). O que importa é o resultado: cache vazio -> passou
      // pelo download -> GIF exibido, sem quebrar.
      await tester.pump();
      await tester.pump();

      expect(find.byType(Gif), findsOneWidget);
      expect(tester.widget<Gif>(find.byType(Gif)).image, imagemFalsa);
      expect(fake.caminhosBaixados, contains('exercicios/gifs/0577.gif'));
    });

    testWidgets(
      'd) falha ao baixar (ex.: arquivo não existe no Storage): mostra estado de indisponível, sem quebrar',
      (tester) async {
        final controller = ExercicioMidiaController(tocandoInicial: true);
        addTearDown(controller.dispose);
        final fake = FakeGifCacheService()..erroNoDownload.add('exercicios/gifs/0577.gif');

        await tester.pumpWidget(
          wrap(
            ExercicioMidia(
              exercise: semVideoGifStorage,
              controller: controller,
              fit: BoxFit.contain,
              gifCacheService: fake,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(Gif), findsNothing);
        expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
        expect(find.text('Mídia indisponível offline'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'e) sem internet (download nunca resolve com sucesso): mesmo estado de indisponível, sem travar',
      (tester) async {
        // Do ponto de vista do widget, "sem internet" e "Storage não tem
        // o arquivo" são o mesmo contrato (resolverImagem devolve null)
        // -- a diferenciação de causa fica dentro do
        // FirebaseGifCacheService de verdade, que nunca deixa a exceção
        // escapar. Aqui confirmamos que o widget trata os dois igual.
        final controller = ExercicioMidiaController(tocandoInicial: true);
        addTearDown(controller.dispose);
        final fake = FakeGifCacheService(); // nem em doCache nem em doDownload = "não tem"

        await tester.pumpWidget(
          wrap(
            ExercicioMidia(
              exercise: semVideoGifStorage,
              controller: controller,
              fit: BoxFit.contain,
              gifCacheService: fake,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'f) distingue "sem mídia nenhuma pro exercício" de "mídia existe mas indisponível agora"',
      (tester) async {
        final controller = ExercicioMidiaController(tocandoInicial: true);
        addTearDown(controller.dispose);
        final fake = FakeGifCacheService()..erroNoDownload.add('exercicios/gifs/0577.gif');

        await tester.pumpWidget(
          wrap(
            ExercicioMidia(
              exercise: semVideoGifStorage,
              controller: controller,
              fit: BoxFit.contain,
              gifCacheService: fake,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Ícone diferente do "nem vídeo nem gif existem pra esse
        // exercício" (Icons.image_not_supported_outlined, já coberto
        // acima com comVideoSemGif) -- aqui o GIF existe, só não deu
        // pra buscar agora.
        expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      },
    );

    testWidgets(
      'g) com vídeo local presente: não chama o serviço de GIF em paralelo, só depois do vídeo falhar',
      (tester) async {
        final controller = ExercicioMidiaController(tocandoInicial: true);
        addTearDown(controller.dispose);
        final fake = FakeGifCacheService()..doDownload['exercicios/gifs/0042.gif'] = imagemFalsa;

        await tester.pumpWidget(
          wrap(
            ExercicioMidia(
              exercise: comVideoEGifStorage,
              controller: controller,
              fit: BoxFit.contain,
              gifCacheService: fake,
            ),
          ),
        );
        // Logo após montar (vídeo ainda tentando inicializar): nenhum
        // download de GIF foi disparado em paralelo.
        expect(fake.caminhosBaixados, isEmpty);

        // Vídeo termina de falhar (sem decoder real no teste) -- só
        // agora, como fallback, o GIF é buscado.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(fake.caminhosBaixados, contains('exercicios/gifs/0042.gif'));
        expect(find.byType(Gif), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
