import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/caixa.dart';
import 'package:gymextreme_app/models/conta_pagar.dart';
import 'package:gymextreme_app/models/conta_receber.dart';
import 'package:gymextreme_app/screens/relatorios/relatorio_financeiro_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_caixa_service.dart';
import 'support/fake_conta_pagar_service.dart';

Widget _wrap({
  FakeAlunoService? alunoService,
  FakeContaPagarService? contaPagarService,
  FakeCaixaService? caixaService,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: RelatorioFinanceiroScreen(
      alunoService: alunoService ?? FakeAlunoService(),
      contaPagarService: contaPagarService ?? FakeContaPagarService(),
      caixaService: caixaService ?? FakeCaixaService(),
    ),
  );
}

void main() {
  testWidgets('estado vazio mostra mensagens de nenhum registro nas 3 abas', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma cobrança encontrada no período.'), findsOneWidget);

    await tester.tap(find.text('A PAGAR'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma despesa encontrada no período.'), findsOneWidget);

    await tester.tap(find.text('CAIXA'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum caixa aberto no momento.'), findsOneWidget);
  });

  testWidgets('aba a receber mostra totais e conta listada', (tester) async {
    final alunoService = FakeAlunoService(
      contasReceber: [
        ContaReceber(
          id: 'c1',
          alunoId: 'aluno-1',
          descricao: 'Mensalidade Agosto',
          valorOriginal: 150,
          vencimento: DateTime(2026, 8, 5),
        ),
      ],
    );

    await tester.pumpWidget(_wrap(alunoService: alunoService));
    await tester.pumpAndSettle();

    expect(find.text('Mensalidade Agosto'), findsOneWidget);
    expect(find.textContaining('registro(s) no período'), findsOneWidget);
  });

  testWidgets('aba caixa mostra saldo quando ha caixa aberto', (tester) async {
    final caixaService = FakeCaixaService(
      caixaAberto: Caixa(
        id: 'caixa-1',
        valorInicial: 100,
        abertoPorUid: 's1',
        abertoPorNome: 'Ana',
        abertoEm: DateTime(2026, 8, 1),
      ),
    );

    await tester.pumpWidget(_wrap(caixaService: caixaService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CAIXA'));
    await tester.pumpAndSettle();

    expect(find.text('Aberto por Ana'), findsOneWidget);
    expect(find.text('Nenhuma movimentação no período.'), findsOneWidget);
  });

  testWidgets('aba a pagar mostra a despesa cadastrada', (tester) async {
    final contaPagarService = FakeContaPagarService(
      contas: [
        ContaPagar(
          id: 'cp1',
          fornecedor: 'Energia Elétrica',
          descricao: 'Conta de luz',
          categoria: 'Utilidades',
          valorOriginal: 300,
          vencimento: DateTime(2026, 8, 10),
        ),
      ],
    );

    await tester.pumpWidget(_wrap(contaPagarService: contaPagarService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A PAGAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Energia Elétrica'), findsOneWidget);
  });
}
