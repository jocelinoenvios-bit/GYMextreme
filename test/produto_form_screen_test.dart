import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/produto.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/produtos/produto_form_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_produto_service.dart';

const _staff = AppUser(
  uid: 'staff-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
);

// O formulário tem mais campos do que cabem no viewport padrão de teste —
// sem rolar até o botão primeiro, tap() acerta um ponto fora da tela.
Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(SingleChildScrollView),
    const Offset(0, -200),
  );
  await tester.tap(finder);
}

Widget _wrap(FakeProdutoService service, {Produto? produto}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: ProdutoFormScreen(produtoService: service, staffAtual: _staff, produto: produto),
  );
}

void main() {
  testWidgets('nao salva com nome, codigo, categoria ou preco de venda vazios', (tester) async {
    final service = FakeProdutoService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await _tocar(tester, find.text('CADASTRAR PRODUTO'));
    await tester.pump();

    expect(find.text('Informe o nome.'), findsOneWidget);
    expect(service.produtos, isEmpty);
  });

  testWidgets('nao salva com estoque inicial ou minimo negativos', (tester) async {
    final service = FakeProdutoService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Whey Protein');
    await tester.enterText(find.widgetWithText(TextFormField, 'Código/SKU'), 'WP001');
    await tester.enterText(find.widgetWithText(TextFormField, 'Categoria'), 'Suplementos');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Preço de venda (R\$)'),
      '90,00',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Estoque inicial'), '-5');

    await _tocar(tester, find.text('CADASTRAR PRODUTO'));
    await tester.pump();

    expect(find.text('Não pode ser negativo.'), findsOneWidget);
    expect(service.produtos, isEmpty);
  });

  testWidgets('cadastra um produto novo com dados validos', (tester) async {
    final service = FakeProdutoService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Whey Protein');
    await tester.enterText(find.widgetWithText(TextFormField, 'Código/SKU'), 'WP001');
    await tester.enterText(find.widgetWithText(TextFormField, 'Categoria'), 'Suplementos');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Preço de venda (R\$)'),
      '90,00',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Estoque inicial'), '20');

    await _tocar(tester, find.text('CADASTRAR PRODUTO'));
    await tester.pump();

    expect(service.produtos, hasLength(1));
    final produto = service.produtos.single;
    expect(produto.nome, 'Whey Protein');
    expect(produto.codigo, 'WP001');
    expect(produto.categoria, 'Suplementos');
    expect(produto.precoVenda, 90);
    expect(produto.estoqueAtual, 20);
    expect(produto.ativo, isTrue);
    expect(produto.criadoPorNome, 'Recepção Ana');
  });

  testWidgets('modo edicao pre-preenche os campos e nao mostra estoque inicial', (tester) async {
    final service = FakeProdutoService(
      produtos: const [
        Produto(
          id: 'p1',
          nome: 'Whey Protein',
          codigo: 'WP001',
          categoria: 'Suplementos',
          unidadeMedida: 'un',
          precoCusto: 50,
          precoVenda: 90,
          estoqueAtual: 15,
          estoqueMinimo: 5,
        ),
      ],
    );
    final produto = service.produtos.single;

    await tester.pumpWidget(_wrap(service, produto: produto));
    await tester.pumpAndSettle();

    expect(find.text('Editar produto'), findsOneWidget);
    expect(find.text('Whey Protein'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Estoque inicial'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome'),
      'Whey Protein Isolado',
    );
    await _tocar(tester, find.text('SALVAR ALTERAÇÕES'));
    await tester.pump();

    final atualizado = service.produtos.single;
    expect(atualizado.nome, 'Whey Protein Isolado');
    expect(atualizado.estoqueAtual, 15, reason: 'editar cadastro nunca muda o estoque');
  });
}
