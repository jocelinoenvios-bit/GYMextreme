import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/anamnese.dart';
import 'package:gymextreme_app/screens/alunos/tabs/anamnese_tab.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/test_viewport.dart';

Widget _wrap(FakeAlunoService alunoService) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: AnamneseTab(uid: 'aluno-1', alunoService: alunoService)),
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

  testWidgets('responde as perguntas 01, 02 e 06 e salva a anamnese', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService();
    await _carregar(tester, _wrap(alunoService));

    await tester.tap(find.widgetWithText(ChoiceChip, '4'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hipertrofia'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Cardíaco'));
    await tester.pump();

    await tester.tap(find.text('SALVAR ANAMNESE'));
    await pumpCurto(tester);

    final salva = alunoService.ultimaAnamneseSalva;
    expect(salva, isNotNull);
    expect(salva!.diasPorSemana, 4);
    expect(salva.objetivo, ObjetivoTreino.hipertrofia);
    expect(salva.condicoesClinicas, contains('cardiaco'));
    expect(find.text('Anamnese salva.'), findsOneWidget);
  });

  testWidgets('anamnese ja respondida mostra a data de resposta', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(
      anamnese: Anamnese(diasPorSemana: 3, respondidoEm: DateTime(2026, 8, 1)),
    );
    await _carregar(tester, _wrap(alunoService));

    expect(find.textContaining('Respondida em 01/08/2026'), findsOneWidget);
  });
}
