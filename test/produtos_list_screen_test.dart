import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/produto.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/produtos/produtos_list_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_produto_service.dart';

const _adm = AppUser(
  uid: 'adm-1',
  nome: 'Dono',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

const _semPermissaoDeCadastro = AppUser(
  uid: 'func-1',
  nome: 'Estoquista Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.acessarProdutos},
);

Widget _wrap(FakeProdutoService service, AppUser staffAtual) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: ProdutosListScreen(produtoService: service, staffAtual: staffAtual),
  );
}

Produto _produto({
  required String id,
  required String nome,
  required String codigo,
  required String categoria,
  double estoqueAtual = 10,
  double estoqueMinimo = 5,
  bool ativo = true,
}) {
  return Produto(
    id: id,
    nome: nome,
    codigo: codigo,
    categoria: categoria,
    unidadeMedida: 'un',
    precoCusto: 10,
    precoVenda: 20,
    estoqueAtual: estoqueAtual,
    estoqueMinimo: estoqueMinimo,
    ativo: ativo,
  );
}

void main() {
  testWidgets('lista os produtos com nome, codigo e categoria', (tester) async {
    final service = FakeProdutoService(
      produtos: [_produto(id: 'p1', nome: 'Whey Protein', codigo: 'WP001', categoria: 'Suplementos')],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Whey Protein'), findsOneWidget);
    expect(find.textContaining('WP001'), findsOneWidget);
  });

  testWidgets('estado vazio mostra mensagem adequada', (tester) async {
    final service = FakeProdutoService();

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum produto encontrado.'), findsOneWidget);
  });

  testWidgets('produtos inativos ficam escondidos por padrao', (tester) async {
    final service = FakeProdutoService(
      produtos: [
        _produto(id: 'p1', nome: 'Produto Ativo', codigo: 'A1', categoria: 'Cat'),
        _produto(id: 'p2', nome: 'Produto Inativo', codigo: 'I1', categoria: 'Cat', ativo: false),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Produto Ativo'), findsOneWidget);
    expect(find.text('Produto Inativo'), findsNothing);

    await tester.tap(find.text('Mostrar inativos'));
    await tester.pumpAndSettle();

    expect(find.text('Produto Inativo'), findsOneWidget);
  });

  testWidgets('busca por nome filtra a lista', (tester) async {
    final service = FakeProdutoService(
      produtos: [
        _produto(id: 'p1', nome: 'Whey Protein', codigo: 'WP001', categoria: 'Suplementos'),
        _produto(id: 'p2', nome: 'Creatina', codigo: 'CR001', categoria: 'Suplementos'),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar por nome ou código'),
      'Creatina',
    );
    await tester.pumpAndSettle();

    expect(find.text('Whey Protein'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Creatina'), findsOneWidget);
  });

  testWidgets('busca por codigo tambem filtra a lista', (tester) async {
    final service = FakeProdutoService(
      produtos: [
        _produto(id: 'p1', nome: 'Whey Protein', codigo: 'WP001', categoria: 'Suplementos'),
        _produto(id: 'p2', nome: 'Creatina', codigo: 'CR001', categoria: 'Suplementos'),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar por nome ou código'),
      'CR001',
    );
    await tester.pumpAndSettle();

    expect(find.text('Whey Protein'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Creatina'), findsOneWidget);
  });

  testWidgets('filtro de estoque baixo mostra so produtos abaixo do minimo', (tester) async {
    final service = FakeProdutoService(
      produtos: [
        _produto(
          id: 'p1',
          nome: 'Estoque ok',
          codigo: 'OK1',
          categoria: 'Cat',
          estoqueAtual: 20,
          estoqueMinimo: 5,
        ),
        _produto(
          id: 'p2',
          nome: 'Produto Zerado',
          codigo: 'BX1',
          categoria: 'Cat',
          estoqueAtual: 2,
          estoqueMinimo: 5,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Estoque ok'), findsOneWidget);
    expect(find.text('Produto Zerado'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Estoque baixo'));
    await tester.pumpAndSettle();

    expect(find.text('Estoque ok'), findsNothing);
  });

  testWidgets('filtro por categoria esconde produtos de outra categoria', (tester) async {
    final service = FakeProdutoService(
      produtos: [
        _produto(id: 'p1', nome: 'Whey Protein', codigo: 'WP001', categoria: 'Suplementos'),
        _produto(id: 'p2', nome: 'Toalha', codigo: 'TL001', categoria: 'Acessórios'),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suplementos').last);
    await tester.pumpAndSettle();

    expect(find.text('Whey Protein'), findsOneWidget);
    expect(find.text('Toalha'), findsNothing);
  });

  testWidgets('esconde NOVO PRODUTO de quem nao tem cadastrarProdutos', (tester) async {
    final service = FakeProdutoService();

    await tester.pumpWidget(_wrap(service, _semPermissaoDeCadastro));
    await tester.pumpAndSettle();

    expect(find.text('NOVO PRODUTO'), findsNothing);
  });

  testWidgets('mostra NOVO PRODUTO pra quem tem cadastrarProdutos', (tester) async {
    final service = FakeProdutoService();

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('NOVO PRODUTO'), findsOneWidget);
  });
}
