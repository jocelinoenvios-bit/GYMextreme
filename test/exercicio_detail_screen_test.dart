import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/screens/exercicios/exercicio_detail_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

const _exercicio = ExerciseModel(
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

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sem pumpAndSettle(): o Gif roda em loop infinito (autostart
  // automático) e nunca "assenta" — mesmo motivo documentado em
  // treino_execucao_screen_test.dart e exercicio_media_stage_test.dart.

  testWidgets('mostra o GIF animado (widget Gif, nao Image estatica) em vez de so o 1o quadro', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ExercicioDetailScreen(exercicio: _exercicio)));
    await tester.pump();

    expect(find.byType(Gif), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('usa o GIF 360 (maior resolucao) quando disponivel', (tester) async {
    await tester.pumpWidget(_wrap(const ExercicioDetailScreen(exercicio: _exercicio)));
    await tester.pump();

    final gif = tester.widget<Gif>(find.byType(Gif));
    expect((gif.image as AssetImage).assetName, 'assets/exercicios/gifs_360/0001.gif');
  });

  testWidgets('cai pro GIF 180 se, por algum motivo, nao houver variante 360', (tester) async {
    const semVariante360 = ExerciseModel(
      id: '9999',
      nome: 'exercicio sem 360',
      bodyPart: 'waist',
      equipmentCategory: 'bodyweight',
      equipamentoTexto: 'body weight',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'sit up',
      gif180Url: 'assets/exercicios/gifs/0001.gif',
    );
    await tester.pumpWidget(_wrap(const ExercicioDetailScreen(exercicio: semVariante360)));
    await tester.pump();

    final gif = tester.widget<Gif>(find.byType(Gif));
    expect((gif.image as AssetImage).assetName, 'assets/exercicios/gifs/0001.gif');
  });

  testWidgets('continua mostrando nome e informacoes do exercicio (nada de negocio quebrou)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ExercicioDetailScreen(exercicio: _exercicio)));
    await tester.pump();

    expect(find.text('3/4 sit-up'), findsOneWidget);
  });
}
