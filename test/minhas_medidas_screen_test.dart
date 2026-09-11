import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/avaliacao_fisica.dart';
import 'package:gymextreme_app/screens/area_aluno/minhas_medidas_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

void main() {
  group('MinhasMedidasScreen', () {
    testWidgets('sem nenhuma avaliação mostra mensagem amigável, não erro', (tester) async {
      final alunoService = FakeAlunoService(avaliacoes: const []);

      await tester.pumpWidget(_wrap(MinhasMedidasScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Você ainda não possui uma avaliação física cadastrada.'), findsOneWidget);
    });

    testWidgets('mostra só os campos que existem — peso, altura e IMC calculado', (tester) async {
      final alunoService = FakeAlunoService(
        avaliacoes: [
          AvaliacaoFisica(data: DateTime(2026, 1, 15), pesoKg: 80, alturaM: 1.8),
        ],
      );

      await tester.pumpWidget(_wrap(MinhasMedidasScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.textContaining('Peso'), findsOneWidget);
      expect(find.textContaining('Altura'), findsOneWidget);
      expect(find.textContaining('IMC'), findsOneWidget);
      expect(find.textContaining('gordura'), findsNothing);
      expect(find.textContaining('massa muscular'), findsNothing);
    });
  });
}
