import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/movimentacao_estoque.dart';
import 'package:gymextreme_app/models/produto.dart';
import 'package:gymextreme_app/screens/relatorios/relatorio_estoque_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_produto_service.dart';
import 'support/test_viewport.dart';

Widget _wrap(FakeProdutoService service) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: RelatorioEstoqueScreen(produtoService: service),
  );
}

void main() {
  testWidgets('estado vazio mostra zeros e nenhum produto abaixo do minimo', (tester) async {
    await tester.pumpWidget(_wrap(FakeProdutoService()));
    await tester.pumpAndSettle();

    expect(find.text('Relatório de estoque'), findsOneWidget);
    expect(find.text('Nenhum produto abaixo do mínimo.'), findsOneWidget);
  });

  testWidgets('lista produto abaixo do minimo', (tester) async {
    final service = FakeProdutoService(
      produtos: [
        const Produto(
          id: 'p1',
          nome: 'Creatina',
          codigo: 'CR1',
          categoria: 'Suplementos',
          unidadeMedida: 'un',
          precoCusto: 20,
          precoVenda: 40,
          estoqueAtual: 1,
          estoqueMinimo: 5,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('Creatina'), findsOneWidget);
  });

  testWidgets('drill-down por produto mostra as movimentacoes registradas', (tester) async {
    usarViewportGrande(tester);
    final service = FakeProdutoService(
      produtos: [
        const Produto(
          id: 'p1',
          nome: 'Whey Protein',
          codigo: 'WP1',
          categoria: 'Suplementos',
          unidadeMedida: 'un',
          precoCusto: 20,
          precoVenda: 40,
          estoqueAtual: 10,
          estoqueMinimo: 5,
        ),
      ],
    );
    service.movimentacoesPorProduto['p1'] = [
      MovimentacaoEstoque(
        tipo: TipoMovimentacaoEstoque.entrada,
        quantidade: 10,
        estoqueAnterior: 0,
        estoquePosterior: 10,
        staffUid: 's1',
        staffNome: 'Ana',
        criadoEm: DateTime(2026, 8, 1),
      ),
    ];

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whey Protein').last);
    await tester.pumpAndSettle();

    expect(find.text('Entrada 10'), findsOneWidget);
  });
}
