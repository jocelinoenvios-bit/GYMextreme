import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/anamnese.dart';
import 'package:gymextreme_app/screens/area_aluno/minha_anamnese_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

void main() {
  group('MinhaAnamneseScreen', () {
    testWidgets('sem nenhuma anamnese cadastrada mostra mensagem amigável, não erro', (
      tester,
    ) async {
      final alunoService = FakeAlunoService(anamnese: null);

      await tester.pumpWidget(_wrap(MinhaAnamneseScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Você ainda não possui uma anamnese cadastrada.'), findsOneWidget);
    });

    testWidgets('mostra só as perguntas já respondidas', (tester) async {
      final alunoService = FakeAlunoService(
        anamnese: const Anamnese(
          diasPorSemana: 4,
          objetivo: ObjetivoTreino.hipertrofia,
        ),
      );

      await tester.pumpWidget(_wrap(MinhaAnamneseScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Dias pretendidos de treino por semana'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Objetivo'), findsOneWidget);
      expect(find.text('Hipertrofia'), findsOneWidget);
      // Perguntas sem resposta não devem aparecer em branco.
      expect(find.text('Pressão arterial'), findsNothing);
    });
  });
}
