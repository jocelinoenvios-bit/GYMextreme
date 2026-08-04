import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/avaliacao_fisica.dart';
import 'package:gymextreme_app/screens/alunos/tabs/avaliacoes_tab.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(FakeAlunoService alunoService) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: AvaliacoesTab(uid: 'aluno-1', alunoService: alunoService)),
  );
}

Future<void> _carregar(WidgetTester tester, Widget tela) async {
  await tester.pumpWidget(tela);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sem nenhuma avaliacao mostra o estado vazio', (tester) async {
    await _carregar(tester, _wrap(FakeAlunoService()));

    expect(find.text('Nenhuma avaliação física registrada ainda.'), findsOneWidget);
  });

  testWidgets('lista as avaliacoes com IMC e medidas', (tester) async {
    final alunoService = FakeAlunoService(
      avaliacoes: [
        AvaliacaoFisica(
          data: DateTime(2026, 8, 1),
          pesoKg: 80,
          alturaM: 2,
          circunferenciasCm: const {'peito': 100.0},
        ),
      ],
    );
    await _carregar(tester, _wrap(alunoService));

    expect(find.text('01/08/2026'), findsOneWidget);
    expect(find.text('IMC 20.0'), findsOneWidget);
    // _InfoChip usa RichText (múltiplos TextSpans), então precisa
    // findRichText pra comparar o texto concatenado.
    expect(find.textContaining('Peso: 80', findRichText: true), findsOneWidget);
    expect(find.textContaining('Circunferências: 1 medidas', findRichText: true), findsOneWidget);
  });
}
