import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/conta_pagar.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/contas_pagar/contas_pagar_list_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_caixa_service.dart';
import 'support/fake_conta_pagar_service.dart';

const _adm = AppUser(
  uid: 'adm-1',
  nome: 'Dono',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

const _financeiroSoAcesso = AppUser(
  uid: 'func-1',
  nome: 'Financeiro Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.acessarContasPagar},
);

const _financeiroCompleto = AppUser(
  uid: 'func-2',
  nome: 'Financeiro Bia',
  email: 'bia@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {
    Permission.acessarContasPagar,
    Permission.cadastrarContasPagar,
    Permission.alterarContasPagar,
    Permission.excluirContasPagar,
    Permission.pagarContasPagar,
  },
);

Widget _wrap(FakeContaPagarService service, AppUser staffAtual) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: ContasPagarListScreen(
      contaPagarService: service,
      caixaService: FakeCaixaService(),
      staffAtual: staffAtual,
    ),
  );
}

void main() {
  testWidgets('lista as despesas com fornecedor, descricao e status', (tester) async {
    final service = FakeContaPagarService(
      contas: [
        ContaPagar(
          id: 'c1',
          fornecedor: 'Fornecedor X',
          descricao: 'Aluguel',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          vencimento: DateTime(2026, 12, 1),
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Fornecedor X'), findsOneWidget);
    expect(find.text('Aluguel · Aluguel'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
  });

  testWidgets('despesa vencida (vencimento no passado, ainda pendente) mostra "Vencido"', (
    tester,
  ) async {
    final service = FakeContaPagarService(
      contas: [
        ContaPagar(
          id: 'c1',
          fornecedor: 'Fornecedor X',
          descricao: 'Aluguel julho',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          vencimento: DateTime(2020, 1, 1),
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Vencido'), findsOneWidget);
  });

  testWidgets('estado vazio mostra mensagem adequada', (tester) async {
    final service = FakeContaPagarService();

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma despesa encontrada.'), findsOneWidget);
  });

  testWidgets(
    'funcionario so com acessarContasPagar nao ve nenhum botao de acao',
    (tester) async {
      final service = FakeContaPagarService(
        contas: [
          ContaPagar(
            id: 'c1',
            fornecedor: 'Fornecedor X',
            descricao: 'Aluguel',
            categoria: 'Aluguel',
            valorOriginal: 1000,
            vencimento: DateTime(2026, 12, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(service, _financeiroSoAcesso));
      await tester.pumpAndSettle();

      expect(find.text('NOVA DESPESA'), findsNothing);
      expect(find.text('EDITAR'), findsNothing);
      expect(find.text('EXCLUIR'), findsNothing);
      expect(find.text('PAGAR'), findsNothing);
    },
  );

  testWidgets(
    'funcionario com todas as permissoes ve criar/editar/excluir/pagar',
    (tester) async {
      final service = FakeContaPagarService(
        contas: [
          ContaPagar(
            id: 'c1',
            fornecedor: 'Fornecedor X',
            descricao: 'Aluguel',
            categoria: 'Aluguel',
            valorOriginal: 1000,
            vencimento: DateTime(2026, 12, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(service, _financeiroCompleto));
      await tester.pumpAndSettle();

      expect(find.text('NOVA DESPESA'), findsOneWidget);
      expect(find.text('EDITAR'), findsOneWidget);
      expect(find.text('EXCLUIR'), findsOneWidget);
      expect(find.text('PAGAR'), findsOneWidget);
    },
  );

  testWidgets('despesa ja paga nao mostra nenhuma acao de gestao', (tester) async {
    final service = FakeContaPagarService(
      contas: [
        ContaPagar(
          id: 'c1',
          fornecedor: 'Fornecedor X',
          descricao: 'Aluguel julho',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          valorPago: 1000,
          vencimento: DateTime(2026, 7, 1),
          dataPagamento: DateTime(2026, 6, 28),
          status: StatusContaPagar.pago,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _financeiroCompleto));
    await tester.pumpAndSettle();

    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('EDITAR'), findsNothing);
    expect(find.text('EXCLUIR'), findsNothing);
    expect(find.text('PAGAR'), findsNothing);
  });

  testWidgets(
    'tocar em excluir chama ContaPagarService.excluirContaPagar depois de confirmar',
    (tester) async {
      final service = FakeContaPagarService(
        contas: [
          ContaPagar(
            id: 'c1',
            fornecedor: 'Fornecedor X',
            descricao: 'Aluguel',
            categoria: 'Aluguel',
            valorOriginal: 1000,
            vencimento: DateTime(2026, 12, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(service, _financeiroCompleto));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXCLUIR'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir despesa'), findsOneWidget);
      await tester.tap(find.text('EXCLUIR').last);
      await tester.pumpAndSettle();

      expect(service.ultimaContaExcluidaId, 'c1');
    },
  );

  testWidgets('filtro por status esconde despesas que nao batem', (tester) async {
    final service = FakeContaPagarService(
      contas: [
        ContaPagar(
          id: 'c1',
          fornecedor: 'Fornecedor X',
          descricao: 'Despesa pendente',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          vencimento: DateTime(2026, 12, 1),
        ),
        ContaPagar(
          id: 'c2',
          fornecedor: 'Fornecedor Y',
          descricao: 'Despesa paga',
          categoria: 'Utilidades',
          valorOriginal: 500,
          valorPago: 500,
          vencimento: DateTime(2026, 7, 1),
          dataPagamento: DateTime(2026, 6, 28),
          status: StatusContaPagar.pago,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.textContaining('Despesa pendente'), findsOneWidget);
    expect(find.textContaining('Despesa paga'), findsOneWidget);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<StatusContaPagar?>, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pago').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Despesa pendente'), findsNothing);
    expect(find.textContaining('Despesa paga'), findsOneWidget);
  });

  testWidgets('filtro por fornecedor esconde despesas de outro fornecedor', (tester) async {
    final service = FakeContaPagarService(
      contas: [
        ContaPagar(
          id: 'c1',
          fornecedor: 'Fornecedor X',
          descricao: 'Despesa X',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          vencimento: DateTime(2026, 12, 1),
        ),
        ContaPagar(
          id: 'c2',
          fornecedor: 'Fornecedor Y',
          descricao: 'Despesa Y',
          categoria: 'Utilidades',
          valorOriginal: 500,
          vencimento: DateTime(2026, 12, 1),
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Fornecedor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fornecedor X').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Despesa X'), findsOneWidget);
    expect(find.textContaining('Despesa Y'), findsNothing);
  });
}
