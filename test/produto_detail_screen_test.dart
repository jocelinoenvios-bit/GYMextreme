import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/produto.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/produtos/produto_detail_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_produto_service.dart';

const _adm = AppUser(
  uid: 'adm-1',
  nome: 'Dono',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

const _somenteConsulta = AppUser(
  uid: 'func-1',
  nome: 'Consulta Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.acessarProdutos, Permission.acessarEstoque},
);

const _somenteCatalogo = AppUser(
  uid: 'func-2',
  nome: 'Catálogo Bia',
  email: 'bia@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.acessarProdutos},
);

Produto _produtoBase({double estoqueAtual = 10, double estoqueMinimo = 5, bool ativo = true}) {
  return Produto(
    id: 'p1',
    nome: 'Whey Protein',
    codigo: 'WP001',
    categoria: 'Suplementos',
    unidadeMedida: 'un',
    precoCusto: 50,
    precoVenda: 90,
    estoqueAtual: estoqueAtual,
    estoqueMinimo: estoqueMinimo,
    ativo: ativo,
  );
}

Widget _wrap(FakeProdutoService service, AppUser staffAtual, {String produtoId = 'p1'}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: ProdutoDetailScreen(
      produtoService: service,
      staffAtual: staffAtual,
      produtoId: produtoId,
    ),
  );
}

void main() {
  testWidgets('mostra estoque atual, minimo, custo e preco', (tester) async {
    final service = FakeProdutoService(produtos: [_produtoBase()]);

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('10 un'), findsOneWidget);
    expect(find.text('5 un'), findsOneWidget);
    expect(find.text('R\$ 50,00'), findsOneWidget);
    expect(find.text('R\$ 90,00'), findsOneWidget);
  });

  testWidgets('mostra aviso de estoque abaixo do minimo', (tester) async {
    final service = FakeProdutoService(
      produtos: [_produtoBase(estoqueAtual: 2, estoqueMinimo: 5)],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Estoque abaixo do mínimo.'), findsOneWidget);
  });

  testWidgets('esconde ENTRADA/SAÍDA/AJUSTE de quem nao tem movimentarEstoque', (tester) async {
    final service = FakeProdutoService(produtos: [_produtoBase()]);

    await tester.pumpWidget(_wrap(service, _somenteConsulta));
    await tester.pumpAndSettle();

    expect(find.text('ENTRADA'), findsNothing);
    expect(find.text('SAÍDA'), findsNothing);
    expect(find.text('AJUSTE'), findsNothing);
  });

  testWidgets(
    'esconde estoque atual/minimo e historico de quem so tem acessarProdutos '
    '(sem acessarEstoque)',
    (tester) async {
      final service = FakeProdutoService(produtos: [_produtoBase()]);
      await service.registrarEntrada(
        'p1',
        quantidade: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await tester.pumpWidget(_wrap(service, _somenteCatalogo));
      await tester.pumpAndSettle();

      // Cadastro basico continua visivel...
      expect(find.text('Whey Protein'), findsOneWidget);
      expect(find.text('R\$ 50,00'), findsOneWidget);
      // ...mas nada de estoque, sem a permissao acessarEstoque.
      expect(find.text('Estoque atual'), findsNothing);
      expect(find.text('Estoque mínimo'), findsNothing);
      expect(find.text('Histórico de movimentações'), findsNothing);
      expect(find.text('Entrada'), findsNothing);
    },
  );

  testWidgets('registra uma entrada de estoque', (tester) async {
    final service = FakeProdutoService(produtos: [_produtoBase()]);

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ENTRADA'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '5');
    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();

    expect(service.produtos.single.estoqueAtual, 15);
  });

  testWidgets('registra uma saida de estoque', (tester) async {
    final service = FakeProdutoService(produtos: [_produtoBase()]);

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAÍDA'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '4');
    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();

    expect(service.produtos.single.estoqueAtual, 6);
  });

  testWidgets('saida maior que o estoque mostra o erro do service (estoque negativo)', (
    tester,
  ) async {
    final service = FakeProdutoService(produtos: [_produtoBase(estoqueAtual: 3)]);

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAÍDA'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();

    expect(find.text('Estoque insuficiente para esta movimentação.'), findsOneWidget);
    expect(service.produtos.single.estoqueAtual, 3);
  });

  testWidgets('registra um ajuste negativo', (tester) async {
    final service = FakeProdutoService(produtos: [_produtoBase()]);

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AJUSTE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '-3');
    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();

    expect(service.produtos.single.estoqueAtual, 7);
  });

  testWidgets('lista as movimentacoes no historico', (tester) async {
    final service = FakeProdutoService(produtos: [_produtoBase()]);
    await service.registrarEntrada(
      'p1',
      quantidade: 5,
      motivo: 'Reposição',
      staffUid: 's1',
      staffNome: 'Ana',
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('Reposição'), findsOneWidget);
    expect(find.text('Nenhuma movimentação ainda.'), findsNothing);
  });

  testWidgets('desativa um produto sem apagar o historico', (tester) async {
    final service = FakeProdutoService(produtos: [_produtoBase()]);

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DESATIVAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DESATIVAR').last);
    await tester.pumpAndSettle();

    expect(service.produtos.single.ativo, isFalse);
  });
}
