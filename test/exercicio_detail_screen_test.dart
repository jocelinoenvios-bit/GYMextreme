import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/screens/exercicios/exercicio_detail_screen.dart';
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

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

FakeGifCacheService _fakeComGifNoCache(String caminho) =>
    FakeGifCacheService()..doCache[caminho] = MemoryImage(gifDeTesteValido);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sem pumpAndSettle(): o Gif roda em loop infinito (autostart
  // automático) e nunca "assenta" — mesmo motivo documentado em
  // treino_execucao_screen_test.dart e exercicio_media_stage_test.dart.

  testWidgets('mostra o GIF animado (widget Gif, nao Image estatica) em vez de so o 1o quadro', (
    tester,
  ) async {
    final fake = _fakeComGifNoCache('exercicios/gifs/0001.gif');
    await tester.pumpWidget(
      _wrap(ExercicioDetailScreen(exercicio: _exercicio, gifCacheService: fake)),
    );
    await tester.pump();

    expect(find.byType(Gif), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('usa o GIF 360 (maior resolucao, unica variante hospedada) quando disponivel', (
    tester,
  ) async {
    final fake = _fakeComGifNoCache('exercicios/gifs/0001.gif');
    await tester.pumpWidget(
      _wrap(ExercicioDetailScreen(exercicio: _exercicio, gifCacheService: fake)),
    );
    await tester.pump();

    final gif = tester.widget<Gif>(find.byType(Gif));
    expect(gif.image, isA<MemoryImage>());
  });

  testWidgets('sem variante 360 (exercicio novo da Vital Animations sem GIF): mostra indicador, sem quebrar', (
    tester,
  ) async {
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
    await tester.pumpWidget(_wrap(const ExercicioDetailScreen(exercicio: semGif)));
    await tester.pump();

    expect(find.byType(Gif), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('continua mostrando nome e informacoes do exercicio (nada de negocio quebrou)', (
    tester,
  ) async {
    final fake = _fakeComGifNoCache('exercicios/gifs/0001.gif');
    await tester.pumpWidget(
      _wrap(ExercicioDetailScreen(exercicio: _exercicio, gifCacheService: fake)),
    );
    await tester.pump();

    expect(find.text('3/4 sit-up'), findsOneWidget);
  });
}
