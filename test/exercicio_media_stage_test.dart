import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/screens/area_aluno/widgets/exercicio_fullscreen_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/widgets/exercicio_media_stage.dart';
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

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('palco principal usa o GIF 180 e nao expoe nenhum seletor de angulo', (tester) async {
    await tester.pumpWidget(_wrap(const ExercicioMediaStage(exercise: _exercicio)));
    await tester.pump();

    final gif = tester.widget<Gif>(find.byType(Gif));
    expect((gif.image as AssetImage).assetName, 'assets/exercicios/gifs/0001.gif');

    // O seletor "Frontal/Lateral" foi removido — a troca de resolução é
    // sempre automática, nunca uma escolha exposta ao aluno.
    expect(find.text('Frontal'), findsNothing);
    expect(find.text('Lateral'), findsNothing);
  });

  testWidgets('tela cheia usa o GIF 360 automaticamente, sem escolha do usuario', (tester) async {
    await tester.pumpWidget(_wrap(const ExercicioFullscreenScreen(exercise: _exercicio)));
    await tester.pump();

    final gif = tester.widget<Gif>(find.byType(Gif));
    expect((gif.image as AssetImage).assetName, 'assets/exercicios/gifs_360/0001.gif');

    expect(find.text('Frontal'), findsNothing);
    expect(find.text('Lateral'), findsNothing);
  });

  testWidgets('tela cheia cai pro GIF 180 se, por algum motivo, nao houver variante 360', (tester) async {
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
    await tester.pumpWidget(_wrap(const ExercicioFullscreenScreen(exercise: semVariante360)));
    await tester.pump();

    final gif = tester.widget<Gif>(find.byType(Gif));
    expect((gif.image as AssetImage).assetName, 'assets/exercicios/gifs/0001.gif');
  });
}
