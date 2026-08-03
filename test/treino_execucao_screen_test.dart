import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/screens/area_aluno/treino_execucao_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

const _tela = TreinoExecucaoScreen(treinoId: 'preview-mock', treinoNome: 'Treino B');

/// A tela carrega de verdade da Biblioteca Oficial (JSON real + isolate
/// via compute()) — nunca usar pumpAndSettle() aqui, porque o pulso da
/// demonstração (AnimationController em loop infinito) nunca "assenta".
/// Em vez disso, espera em passos curtos até o spinner de carregamento
/// sumir, com um teto de tentativas.
Future<void> _carregar(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(_tela));
  for (var i = 0; i < 60; i++) {
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('carrega da Biblioteca Oficial e mostra o primeiro exercicio prescrito', (
    tester,
  ) async {
    await _carregar(tester);

    expect(find.text('lever chest press'), findsWidgets);
    expect(find.text('CONCLUIR SÉRIE 1'), findsOneWidget);
    expect(find.text('Exercício 1 de 3'), findsOneWidget);
  });

  testWidgets('concluir uma serie nao-final entra em descanso; pular volta pronto pra proxima', (
    tester,
  ) async {
    await _carregar(tester);

    await tester.tap(find.text('CONCLUIR SÉRIE 1'));
    await tester.pump();
    expect(find.text('PULAR DESCANSO'), findsOneWidget);
    expect(find.text('CONCLUIR SÉRIE 1'), findsNothing);

    await tester.tap(find.text('PULAR DESCANSO'));
    await tester.pump();
    expect(find.text('CONCLUIR SÉRIE 2'), findsOneWidget);
  });

  testWidgets('concluir a ultima serie do ultimo exercicio mostra a tela de conclusao', (
    tester,
  ) async {
    await _carregar(tester);

    for (var i = 0; i < 20; i++) {
      if (find.text('Treino concluído!').evaluate().isNotEmpty) break;

      final pularDescanso = find.text('PULAR DESCANSO');
      if (pularDescanso.evaluate().isNotEmpty) {
        await tester.tap(pularDescanso);
        await tester.pump();
        continue;
      }

      final botaoConcluir = find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').startsWith('CONCLUIR SÉRIE'),
      );
      expect(botaoConcluir, findsOneWidget, reason: 'esperava um botão de concluir série ainda visível');
      await tester.tap(botaoConcluir);
      await tester.pump();
    }

    expect(find.text('Treino concluído!'), findsOneWidget);
    expect(find.text('3 exercícios finalizados'), findsOneWidget);
  });
}
