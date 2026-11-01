import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/avaliacao_fisica.dart';
import 'package:gymextreme_app/screens/area_aluno/minhas_medidas_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/rich_text_finder.dart';

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

      // "Peso"/"Altura" são rótulos de um RichText (_InfoChip) — não um
      // Text simples — então usam o finder que lê o texto plano do
      // RichText. O selo de IMC é um Text de verdade.
      expect(findRichTextContaining('Peso'), findsOneWidget);
      expect(findRichTextContaining('Altura'), findsOneWidget);
      expect(find.textContaining('IMC'), findsOneWidget);
      expect(findRichTextContaining('gordura'), findsNothing);
      expect(findRichTextContaining('massa muscular'), findsNothing);
    });
  });
}
