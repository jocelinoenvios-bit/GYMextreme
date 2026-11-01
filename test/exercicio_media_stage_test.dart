import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/screens/area_aluno/widgets/exercicio_fullscreen_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/widgets/exercicio_media_stage.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_gif_bytes.dart';
import 'support/fake_gif_cache_service.dart';

const _exercicio = ExerciseModel(
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

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child));

FakeGifCacheService _fakeComGifNoCache(String caminho) =>
    FakeGifCacheService()..doCache[caminho] = MemoryImage(gifDeTesteValido);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('palco principal usa o GIF 360 (unica variante hospedada) quando disponivel', (
    tester,
  ) async {
    final fake = _fakeComGifNoCache('exercicios/gifs/0001.gif');
    await tester.pumpWidget(
      _wrap(ExercicioMediaStage(exercise: _exercicio, gifCacheService: fake)),
    );
    await tester.pump();

    final gif = tester.widget<Gif>(find.byType(Gif));
    expect(gif.image, isA<MemoryImage>());

    // O seletor "Frontal/Lateral" foi removido — a troca de resolução é
    // sempre automática, nunca uma escolha exposta ao aluno.
    expect(find.text('Frontal'), findsNothing);
    expect(find.text('Lateral'), findsNothing);
  });

  testWidgets('palco principal sem GIF disponivel: mostra indicador, sem quebrar', (tester) async {
    const semGif = ExerciseModel(
      id: '9999',
      nome: 'exercicio sem gif',
      bodyPart: 'waist',
      equipmentCategory: 'bodyweight',
      equipamentoTexto: 'body weight',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'sit up',
    );
    await tester.pumpWidget(_wrap(const ExercicioMediaStage(exercise: semGif)));
    await tester.pump();

    expect(find.byType(Gif), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('tela cheia usa o GIF 360 automaticamente, sem escolha do usuario', (tester) async {
    final fake = _fakeComGifNoCache('exercicios/gifs/0001.gif');
    await tester.pumpWidget(
      _wrap(ExercicioFullscreenScreen(exercise: _exercicio, gifCacheService: fake)),
    );
    await tester.pump();

    final gif = tester.widget<Gif>(find.byType(Gif));
    expect(gif.image, isA<MemoryImage>());

    expect(find.text('Frontal'), findsNothing);
    expect(find.text('Lateral'), findsNothing);
  });

  testWidgets('tela cheia sem GIF disponivel: mostra indicador, sem quebrar', (tester) async {
    const semGif = ExerciseModel(
      id: '9999',
      nome: 'exercicio sem gif',
      bodyPart: 'waist',
      equipmentCategory: 'bodyweight',
      equipamentoTexto: 'body weight',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'sit up',
    );
    await tester.pumpWidget(_wrap(const ExercicioFullscreenScreen(exercise: semGif)));
    await tester.pump();

    expect(find.byType(Gif), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
