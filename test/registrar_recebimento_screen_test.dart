import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/conta_receber.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/contas_receber/registrar_recebimento_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_caixa_service.dart';

const _staff = AppUser(
  uid: 'staff-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
);

// O formulário tem mais campos do que cabem no viewport padrão de teste —
// sem rolar até o botão primeiro, tap() acerta um ponto fora da tela.
Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
}

Widget _wrap(FakeAlunoService service, ContaReceber conta, {FakeCaixaService? caixaService}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: RegistrarRecebimentoScreen(
      alunoService: service,
      caixaService: caixaService ?? FakeCaixaService(),
      staffAtual: _staff,
      conta: conta,
    ),
  );
}

void main() {
  testWidgets('valor recebido ja vem preenchido com o valor liquido esperado', (tester) async {
    final conta = ContaReceber(
      id: 'c1',
      alunoId: 'aluno1',
      descricao: 'Mensalidade agosto',
      valorOriginal: 129.9,
      desconto: 10,
      vencimento: DateTime(2026, 9, 1),
    );
    final service = FakeAlunoService(contasReceber: [conta]);

    await tester.pumpWidget(_wrap(service, conta));
    await tester.pumpAndSettle();

    expect(find.text('119,90'), findsOneWidget);
  });

  testWidgets('nao confirma sem forma de pagamento', (tester) async {
    final conta = ContaReceber(
      id: 'c1',
      alunoId: 'aluno1',
      descricao: 'Mensalidade agosto',
      valorOriginal: 129.9,
      vencimento: DateTime(2026, 9, 1),
    );
    final service = FakeAlunoService(contasReceber: [conta]);

    await tester.pumpWidget(_wrap(service, conta));
    await tester.pumpAndSettle();

    await _tocar(tester, find.text('CONFIRMAR RECEBIMENTO'));
    await tester.pump();

    expect(find.text('Informe a forma de pagamento.'), findsOneWidget);
    expect(service.ultimoRecebimentoRegistrado, isNull);
  });

  testWidgets('confirma o recebimento e chama AlunoService.registrarRecebimento', (tester) async {
    final conta = ContaReceber(
      id: 'c1',
      alunoId: 'aluno1',
      descricao: 'Mensalidade agosto',
      valorOriginal: 129.9,
      vencimento: DateTime(2026, 9, 1),
    );
    final service = FakeAlunoService(contasReceber: [conta]);

    await tester.pumpWidget(_wrap(service, conta));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Forma de pagamento'),
      'PIX',
    );

    await _tocar(tester, find.text('CONFIRMAR RECEBIMENTO'));
    await tester.pump();

    final registrado = service.ultimoRecebimentoRegistrado;
    expect(registrado, isNotNull);
    expect(registrado!.status, StatusContaReceber.pago);
    expect(registrado.valorPago, 129.9);
    expect(registrado.formaPagamento, 'PIX');
    expect(registrado.recebidoPorNome, 'Recepção Ana');
    // Cobrança avulsa (sem matrícula vinculada) nunca mexe no vencimento.
    expect(service.proximoVencimentoAvancadoPara, isNull);
  });

  testWidgets(
    'cobrança vinculada a uma matrícula também avança o vencimento do aluno',
    (tester) async {
      final conta = ContaReceber(
        id: 'c1',
        alunoId: 'aluno1',
        matriculaId: 'matricula-1',
        descricao: 'Mensalidade agosto',
        valorOriginal: 129.9,
        vencimento: DateTime(2026, 9, 1),
      );
      final service = FakeAlunoService(contasReceber: [conta]);

      await tester.pumpWidget(_wrap(service, conta));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Forma de pagamento'),
        'PIX',
      );

      await _tocar(tester, find.text('CONFIRMAR RECEBIMENTO'));
      await tester.pump();

      expect(service.ultimoRecebimentoRegistrado?.status, StatusContaReceber.pago);
      expect(service.proximoVencimentoAvancadoPara, DateTime(2026, 10, 1));
    },
  );
}
