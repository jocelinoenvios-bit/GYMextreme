import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/caixa.dart';
import 'package:gymextreme_app/models/conta_pagar.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/contas_pagar/registrar_pagamento_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_caixa_service.dart';
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

Widget _wrap(
  FakeContaPagarService service,
  ContaPagar conta, {
  FakeCaixaService? caixaService,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: RegistrarPagamentoScreen(
      contaPagarService: service,
      caixaService: caixaService ?? FakeCaixaService(),
      staffAtual: _staff,
      conta: conta,
    ),
  );
}

void main() {
  testWidgets('valor pago ja vem preenchido com o valor final esperado', (tester) async {
    final conta = ContaPagar(
      id: 'c1',
      fornecedor: 'Fornecedor X',
      descricao: 'Aluguel',
      categoria: 'Aluguel',
      valorOriginal: 1000,
      desconto: 100,
      vencimento: DateTime(2026, 9, 5),
    );
    final service = FakeContaPagarService(contas: [conta]);

    await tester.pumpWidget(_wrap(service, conta));
    await tester.pumpAndSettle();

    expect(find.text('900,00'), findsOneWidget);
  });

  testWidgets('nao confirma sem forma de pagamento', (tester) async {
    final conta = ContaPagar(
      id: 'c1',
      fornecedor: 'Fornecedor X',
      descricao: 'Aluguel',
      categoria: 'Aluguel',
      valorOriginal: 1000,
      vencimento: DateTime(2026, 9, 5),
    );
    final service = FakeContaPagarService(contas: [conta]);

    await tester.pumpWidget(_wrap(service, conta));
    await tester.pumpAndSettle();

    await _tocar(tester, find.text('CONFIRMAR PAGAMENTO'));
    await tester.pump();

    expect(find.text('Informe a forma de pagamento.'), findsOneWidget);
    expect(service.ultimaContaPagaId, isNull);
  });

  testWidgets(
    'sem caixa aberto, confirma via ContaPagarService.registrarPagamentoSemCaixa',
    (tester) async {
      final conta = ContaPagar(
        id: 'c1',
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
      );
      final service = FakeContaPagarService(contas: [conta]);

      await tester.pumpWidget(_wrap(service, conta));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Forma de pagamento'),
        'PIX',
      );
      await _tocar(tester, find.text('CONFIRMAR PAGAMENTO'));
      await tester.pump();

      expect(service.ultimaContaPagaId, 'c1');
      expect(service.contas.single.status, StatusContaPagar.pago);
      expect(service.contas.single.valorPago, 1000);
    },
  );

  testWidgets(
    'com caixa aberto, confirma via CaixaService.registrarPagamentoContaPagar',
    (tester) async {
      final conta = ContaPagar(
        id: 'c1',
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
      );
      final service = FakeContaPagarService(contas: [conta]);
      final caixaService = FakeCaixaService(
        caixaAberto: Caixa(
          id: 'caixa-1',
          valorInicial: 500,
          abertoPorUid: 'adm1',
          abertoPorNome: 'Dono',
          abertoEm: DateTime(2026, 9, 5, 9),
        ),
      );

      await tester.pumpWidget(_wrap(service, conta, caixaService: caixaService));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Forma de pagamento'),
        'PIX',
      );
      await _tocar(tester, find.text('CONFIRMAR PAGAMENTO'));
      await tester.pump();

      expect(caixaService.ultimoPagamentoViaCaixa?.contaPagarId, 'c1');
      expect(caixaService.movimentacoes.single.valor, -1000);
      // Sem caixa aberto no fake, ContaPagarService.registrarPagamentoSemCaixa
      // NAO deveria ter sido chamado — o pagamento so passou pelo caixa.
      expect(service.ultimaContaPagaId, isNull);
    },
  );

  testWidgets('pagamento duplicado exibe a mensagem do service', (tester) async {
    final conta = ContaPagar(
      id: 'c1',
      fornecedor: 'Fornecedor X',
      descricao: 'Aluguel',
      categoria: 'Aluguel',
      valorOriginal: 1000,
      status: StatusContaPagar.pago,
      valorPago: 1000,
      dataPagamento: DateTime(2026, 9, 1),
      vencimento: DateTime(2026, 9, 5),
    );
    final service = FakeContaPagarService(contas: [conta]);

    await tester.pumpWidget(_wrap(service, conta));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Forma de pagamento'),
      'PIX',
    );
    await _tocar(tester, find.text('CONFIRMAR PAGAMENTO'));
    await tester.pump();

    expect(find.text('Esta conta já foi paga.'), findsOneWidget);
  });
}
