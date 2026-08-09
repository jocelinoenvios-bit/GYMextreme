import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/conta_receber.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/contas_receber/contas_receber_list_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_caixa_service.dart';

const _adm = AppUser(
  uid: 'adm-1',
  nome: 'Dono',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

const _recepcaoSoAcesso = AppUser(
  uid: 'func-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.acessarContasReceber},
);

const _recepcaoCompleta = AppUser(
  uid: 'func-2',
  nome: 'Recepção Bia',
  email: 'bia@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {
    Permission.acessarContasReceber,
    Permission.cadastrarContasReceber,
    Permission.alterarContasReceber,
    Permission.excluirContasReceber,
    Permission.receberContasReceber,
  },
);

const _carlos = AppUser(
  uid: 'aluno-carlos',
  nome: 'Carlos Souza',
  email: 'carlos@exemplo.com',
  role: UserRole.aluno,
);

Widget _wrap(FakeAlunoService service, AppUser staffAtual) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: ContasReceberListScreen(
      alunoService: service,
      caixaService: FakeCaixaService(),
      staffAtual: staffAtual,
    ),
  );
}

void main() {
  testWidgets('lista as cobrancas com aluno, descricao e status', (tester) async {
    final service = FakeAlunoService(
      alunos: const [_carlos],
      contasReceber: [
        ContaReceber(
          id: 'c1',
          alunoId: _carlos.uid,
          descricao: 'Mensalidade agosto',
          valorOriginal: 129.9,
          vencimento: DateTime(2026, 12, 1),
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Souza'), findsOneWidget);
    expect(find.text('Mensalidade agosto'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
  });

  testWidgets('conta vencida (vencimento no passado, ainda pendente) mostra "Vencido"', (
    tester,
  ) async {
    final service = FakeAlunoService(
      alunos: const [_carlos],
      contasReceber: [
        ContaReceber(
          id: 'c1',
          alunoId: _carlos.uid,
          descricao: 'Mensalidade julho',
          valorOriginal: 129.9,
          vencimento: DateTime(2020, 1, 1),
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Vencido'), findsOneWidget);
  });

  testWidgets('estado vazio mostra mensagem adequada', (tester) async {
    final service = FakeAlunoService();

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma cobrança encontrada.'), findsOneWidget);
  });

  testWidgets(
    'funcionario so com acessarContasReceber nao ve nenhum botao de acao',
    (tester) async {
      final service = FakeAlunoService(
        alunos: const [_carlos],
        contasReceber: [
          ContaReceber(
            id: 'c1',
            alunoId: _carlos.uid,
            descricao: 'Mensalidade agosto',
            valorOriginal: 129.9,
            vencimento: DateTime(2026, 12, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(service, _recepcaoSoAcesso));
      await tester.pumpAndSettle();

      expect(find.text('NOVA COBRANÇA'), findsNothing);
      expect(find.text('EDITAR'), findsNothing);
      expect(find.text('EXCLUIR'), findsNothing);
      expect(find.text('RECEBER'), findsNothing);
    },
  );

  testWidgets(
    'funcionario com todas as permissoes ve criar/editar/excluir/receber',
    (tester) async {
      final service = FakeAlunoService(
        alunos: const [_carlos],
        contasReceber: [
          ContaReceber(
            id: 'c1',
            alunoId: _carlos.uid,
            descricao: 'Mensalidade agosto',
            valorOriginal: 129.9,
            vencimento: DateTime(2026, 12, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(service, _recepcaoCompleta));
      await tester.pumpAndSettle();

      expect(find.text('NOVA COBRANÇA'), findsOneWidget);
      expect(find.text('EDITAR'), findsOneWidget);
      expect(find.text('EXCLUIR'), findsOneWidget);
      expect(find.text('RECEBER'), findsOneWidget);
    },
  );

  testWidgets('cobranca ja paga nao mostra nenhuma acao de gestao', (tester) async {
    final service = FakeAlunoService(
      alunos: const [_carlos],
      contasReceber: [
        ContaReceber(
          id: 'c1',
          alunoId: _carlos.uid,
          descricao: 'Mensalidade julho',
          valorOriginal: 129.9,
          valorPago: 129.9,
          vencimento: DateTime(2026, 7, 1),
          dataPagamento: DateTime(2026, 6, 28),
          status: StatusContaReceber.pago,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _recepcaoCompleta));
    await tester.pumpAndSettle();

    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('EDITAR'), findsNothing);
    expect(find.text('EXCLUIR'), findsNothing);
    expect(find.text('RECEBER'), findsNothing);
  });

  testWidgets(
    'tocar em excluir chama AlunoService.excluirContaReceber depois de confirmar',
    (tester) async {
      final service = FakeAlunoService(
        alunos: const [_carlos],
        contasReceber: [
          ContaReceber(
            id: 'c1',
            alunoId: _carlos.uid,
            descricao: 'Mensalidade agosto',
            valorOriginal: 129.9,
            vencimento: DateTime(2026, 12, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(service, _recepcaoCompleta));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXCLUIR'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir cobrança'), findsOneWidget);
      await tester.tap(find.text('EXCLUIR').last);
      await tester.pumpAndSettle();

      expect(service.ultimaContaExcluidaId, 'c1');
    },
  );

  testWidgets('filtro por status esconde contas que nao batem', (tester) async {
    final service = FakeAlunoService(
      alunos: const [_carlos],
      contasReceber: [
        ContaReceber(
          id: 'c1',
          alunoId: _carlos.uid,
          descricao: 'Mensalidade pendente',
          valorOriginal: 129.9,
          vencimento: DateTime(2026, 12, 1),
        ),
        ContaReceber(
          id: 'c2',
          alunoId: _carlos.uid,
          descricao: 'Mensalidade paga',
          valorOriginal: 129.9,
          valorPago: 129.9,
          vencimento: DateTime(2026, 7, 1),
          dataPagamento: DateTime(2026, 6, 28),
          status: StatusContaReceber.pago,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Mensalidade pendente'), findsOneWidget);
    expect(find.text('Mensalidade paga'), findsOneWidget);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<StatusContaReceber?>, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pago').last);
    await tester.pumpAndSettle();

    expect(find.text('Mensalidade pendente'), findsNothing);
    expect(find.text('Mensalidade paga'), findsOneWidget);
  });
}
