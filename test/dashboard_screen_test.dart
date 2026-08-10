import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/produto.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/relatorios/dashboard_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_caixa_service.dart';
import 'support/fake_conta_pagar_service.dart';
import 'support/fake_produto_service.dart';
import 'support/test_viewport.dart';

const _staff = AppUser(uid: 'adm1', nome: 'Dono', email: 'adm@exemplo.com', role: UserRole.adm);

Widget _wrap({
  FakeAlunoService? alunoService,
  FakeCaixaService? caixaService,
  FakeContaPagarService? contaPagarService,
  FakeProdutoService? produtoService,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: DashboardScreen(
      alunoService: alunoService ?? FakeAlunoService(),
      caixaService: caixaService ?? FakeCaixaService(),
      contaPagarService: contaPagarService ?? FakeContaPagarService(),
      produtoService: produtoService ?? FakeProdutoService(),
      staffAtual: _staff,
    ),
  );
}

void main() {
  testWidgets('estado vazio mostra painel sem quebrar e sem caixa aberto', (tester) async {
    usarViewportGrande(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Painel administrativo'), findsOneWidget);
    expect(find.text('Nenhum caixa aberto no momento.'), findsOneWidget);
  });

  testWidgets('mostra contagem real de produtos com estoque baixo', (tester) async {
    usarViewportGrande(tester);
    final produtoService = FakeProdutoService(
      produtos: [
        const Produto(
          id: 'p1',
          nome: 'Whey',
          codigo: 'W1',
          categoria: 'Suplementos',
          unidadeMedida: 'un',
          precoCusto: 10,
          precoVenda: 20,
          estoqueAtual: 1,
          estoqueMinimo: 5,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(produtoService: produtoService));
    await tester.pumpAndSettle();

    expect(find.text('Estoque baixo'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('botao atualizar refaz a carga sem erro', (tester) async {
    usarViewportGrande(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Atualizar'));
    await tester.pumpAndSettle();

    expect(find.text('Painel administrativo'), findsOneWidget);
  });

  testWidgets('link Estoque navega para o relatorio de estoque', (tester) async {
    usarViewportGrande(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Estoque'));
    await tester.pumpAndSettle();

    expect(find.text('Relatório de estoque'), findsOneWidget);
  });

  testWidgets('link Evolucao fisica navega para a tela dedicada', (tester) async {
    usarViewportGrande(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Evolução física'));
    await tester.pumpAndSettle();

    expect(find.text('Evolução física'), findsWidgets);
  });
}
