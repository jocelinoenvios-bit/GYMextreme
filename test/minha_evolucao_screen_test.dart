import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/avaliacao_fisica.dart';
import 'package:gymextreme_app/screens/area_aluno/minha_evolucao_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

void main() {
  group('MinhaEvolucaoScreen', () {
    testWidgets('sem nenhuma avaliação mostra mensagem amigável, não erro', (tester) async {
      final alunoService = FakeAlunoService(avaliacoes: const []);

      await tester.pumpWidget(_wrap(MinhaEvolucaoScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Você ainda não possui uma avaliação física cadastrada.'), findsOneWidget);
    });

    testWidgets('com só 1 avaliação explica que a evolução aparece a partir da segunda', (
      tester,
    ) async {
      final alunoService = FakeAlunoService(
        avaliacoes: [AvaliacaoFisica(data: DateTime(2026, 1, 1), pesoKg: 80)],
      );

      await tester.pumpWidget(_wrap(MinhaEvolucaoScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(
        find.text(
          'Você tem só 1 avaliação registrada — a evolução aparece a '
          'partir da segunda.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('com 2+ avaliações de peso mostra o cartão de evolução com inicial/atual/diferença', (
      tester,
    ) async {
      // watchAvaliacoes() real devolve mais recente primeiro — a mais
      // recente é a primeira da lista aqui.
      final alunoService = FakeAlunoService(
        avaliacoes: [
          AvaliacaoFisica(data: DateTime(2026, 2, 1), pesoKg: 78),
          AvaliacaoFisica(data: DateTime(2026, 1, 1), pesoKg: 80),
        ],
      );

      await tester.pumpWidget(_wrap(MinhaEvolucaoScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Peso'), findsOneWidget);
      expect(find.text('80.0kg'), findsOneWidget);
      expect(find.text('78.0kg'), findsOneWidget);
      expect(find.text('-2.0kg'), findsOneWidget);
    });

    testWidgets('não inventa %gordura/massa muscular — só os campos que existem no modelo', (
      tester,
    ) async {
      final alunoService = FakeAlunoService(
        avaliacoes: [
          AvaliacaoFisica(data: DateTime(2026, 2, 1), pesoKg: 78),
          AvaliacaoFisica(data: DateTime(2026, 1, 1), pesoKg: 80),
        ],
      );

      await tester.pumpWidget(_wrap(MinhaEvolucaoScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.textContaining('gordura'), findsNothing);
      expect(find.textContaining('massa muscular'), findsNothing);
    });
  });
}
