import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/conta_pagar.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/contas_pagar/conta_pagar_form_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_conta_pagar_service.dart';

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

Widget _wrap(FakeContaPagarService service, {ContaPagar? conta}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: ContaPagarFormScreen(
      contaPagarService: service,
      staffAtual: _staff,
      conta: conta,
    ),
  );
}

void main() {
  testWidgets('nao salva com fornecedor, descricao, categoria ou valor vazios', (tester) async {
    final service = FakeContaPagarService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await _tocar(tester, find.text('CRIAR DESPESA'));
    await tester.pump();

    expect(find.text('Informe o fornecedor.'), findsOneWidget);
    expect(service.contas, isEmpty);
  });

  testWidgets('cria uma despesa nova com dados validos', (tester) async {
    final service = FakeContaPagarService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fornecedor'),
      'Energia Elétrica S.A.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Conta de luz agosto',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Categoria'), 'Utilidades');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor original (R\$)'),
      '450,50',
    );

    await _tocar(tester, find.text('CRIAR DESPESA'));
    await tester.pump();

    expect(service.contas, hasLength(1));
    final conta = service.contas.single;
    expect(conta.fornecedor, 'Energia Elétrica S.A.');
    expect(conta.descricao, 'Conta de luz agosto');
    expect(conta.categoria, 'Utilidades');
    expect(conta.valorOriginal, 450.5);
    expect(conta.status, StatusContaPagar.pendente);
    expect(conta.criadoPorNome, 'Recepção Ana');
  });

  testWidgets('modo edicao pre-preenche os campos e salva alteracoes', (tester) async {
    final service = FakeContaPagarService(
      contas: [
        ContaPagar(
          id: 'c1',
          fornecedor: 'Fornecedor X',
          descricao: 'Aluguel',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          vencimento: DateTime(2026, 9, 5),
        ),
      ],
    );
    final conta = service.contas.single;

    await tester.pumpWidget(_wrap(service, conta: conta));
    await tester.pumpAndSettle();

    expect(find.text('Editar despesa'), findsOneWidget);
    expect(find.text('Fornecedor X'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Aluguel (corrigido)',
    );
    await _tocar(tester, find.text('SALVAR ALTERAÇÕES'));
    await tester.pump();

    expect(service.contas.single.descricao, 'Aluguel (corrigido)');
  });

  testWidgets('despesa ja paga nao permite edicao', (tester) async {
    final service = FakeContaPagarService(
      contas: [
        ContaPagar(
          id: 'c1',
          fornecedor: 'Fornecedor X',
          descricao: 'Aluguel julho',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          valorPago: 1000,
          vencimento: DateTime(2026, 7, 5),
          dataPagamento: DateTime(2026, 7, 3),
          status: StatusContaPagar.pago,
        ),
      ],
    );
    final conta = service.contas.single;

    await tester.pumpWidget(_wrap(service, conta: conta));
    await tester.pumpAndSettle();

    expect(find.text('SALVAR ALTERAÇÕES'), findsNothing);
    expect(
      find.text('Despesas pagas ou canceladas não podem mais ser editadas.'),
      findsOneWidget,
    );
  });
}
