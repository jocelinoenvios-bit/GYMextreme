import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/screens/alunos/avaliacao_fisica_form_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/test_viewport.dart';

/// Empurra a tela a partir de um "host" (igual ao uso real, que sempre
/// navega até aqui a partir da AvaliacoesTab) — o pop() ao salvar precisa
/// de uma rota anterior pra voltar.
Widget _host(FakeAlunoService alunoService) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AvaliacaoFisicaFormScreen(uid: 'aluno-1', alunoService: alunoService),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mostra o IMC calculado a partir de peso e altura digitados', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService();
    await tester.pumpWidget(_host(alunoService));
    await tester.tap(find.text('abrir'));
    await pumpCurto(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Peso (Kg)'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'Altura (m)'), '2');
    await tester.pump();

    expect(find.textContaining('IMC 20.0'), findsOneWidget);
    expect(find.textContaining('Peso normal'), findsOneWidget);
  });

  testWidgets('salva peso, altura e circunferencias preenchidas e fecha a tela', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService();
    await tester.pumpWidget(_host(alunoService));
    await tester.tap(find.text('abrir'));
    await pumpCurto(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Peso (Kg)'), '80');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Altura (m)'), '2');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Peito'), '100');
    await tester.pump();
    await tester.tap(find.text('SALVAR AVALIAÇÃO'));
    await pumpCurto(tester);

    final salva = alunoService.ultimaAvaliacaoSalva;
    expect(salva, isNotNull);
    expect(salva!.pesoKg, 80);
    expect(salva.alturaM, 2);
    expect(salva.circunferenciasCm['peito'], 100);
    expect(find.byType(AvaliacaoFisicaFormScreen), findsNothing);
  });
}
