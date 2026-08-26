import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/conta_receber.dart';
import 'package:gymextreme_app/models/matricula.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/contas_receber/conta_receber_form_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

const _staff = AppUser(
  uid: 'staff-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
);

const _carlos = AppUser(
  uid: 'aluno-carlos',
  nome: 'Carlos Souza',
  email: 'carlos@exemplo.com',
  role: UserRole.aluno,
);

// O formulário tem mais campos do que cabem no viewport padrão de teste —
// sem rolar até o botão primeiro, tap() acerta um ponto fora da tela.
Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
}

Widget _wrap(FakeAlunoService service, {ContaReceber? conta}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: ContaReceberFormScreen(
      alunoService: service,
      staffAtual: _staff,
      alunoPreSelecionado: _carlos,
      conta: conta,
    ),
  );
}

void main() {
  testWidgets('nao salva com descricao ou valor vazios', (tester) async {
    final service = FakeAlunoService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await _tocar(tester, find.text('CRIAR COBRANÇA'));
    await tester.pump();

    expect(find.text('Informe a descrição.'), findsOneWidget);
    expect(service.contasReceber, isEmpty);
  });

  testWidgets('cria uma cobranca nova com dados validos', (tester) async {
    final service = FakeAlunoService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Mensalidade agosto',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor original (R\$)'),
      '129,90',
    );

    await _tocar(tester, find.text('CRIAR COBRANÇA'));
    await tester.pump();

    expect(service.contasReceber, hasLength(1));
    final conta = service.contasReceber.single;
    expect(conta.alunoId, _carlos.uid);
    expect(conta.descricao, 'Mensalidade agosto');
    expect(conta.valorOriginal, 129.9);
    expect(conta.status, StatusContaReceber.pendente);
    expect(conta.criadoPorNome, 'Recepção Ana');
  });

  testWidgets('escolher uma matricula preenche descricao/valor/vencimento', (tester) async {
    final service = FakeAlunoService(
      matriculas: [
        Matricula(
          id: 'm1',
          alunoId: _carlos.uid,
          planoId: 'plano1',
          dataInicio: DateTime(2026, 8, 1),
          dataVencimento: DateTime(2026, 9, 1),
          valorContratado: 349,
        ),
      ],
    );
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(
        DropdownButtonFormField<Matricula?>,
        'Gerar a partir de uma matrícula (opcional)',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('R\$ 349,00').last);
    await tester.pumpAndSettle();

    expect(find.text('349,00'), findsOneWidget);

    await _tocar(tester, find.text('CRIAR COBRANÇA'));
    await tester.pump();

    final conta = service.contasReceber.single;
    expect(conta.matriculaId, 'm1');
    expect(conta.valorOriginal, 349);
  });

  testWidgets('modo edicao pre-preenche os campos e salva alteracoes', (tester) async {
    final service = FakeAlunoService(
      contasReceber: [
        ContaReceber(
          id: 'c1',
          alunoId: _carlos.uid,
          descricao: 'Mensalidade agosto',
          valorOriginal: 129.9,
          vencimento: DateTime(2026, 9, 1),
        ),
      ],
    );
    final conta = service.contasReceber.single;

    await tester.pumpWidget(_wrap(service, conta: conta));
    await tester.pumpAndSettle();

    expect(find.text('Editar cobrança'), findsOneWidget);
    expect(find.text('Mensalidade agosto'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Mensalidade agosto (corrigida)',
    );
    await _tocar(tester, find.text('SALVAR ALTERAÇÕES'));
    await tester.pump();

    expect(service.ultimaContaAtualizada?.descricao, 'Mensalidade agosto (corrigida)');
  });

  testWidgets('cobranca ja paga nao permite edicao', (tester) async {
    final service = FakeAlunoService(
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
    final conta = service.contasReceber.single;

    await tester.pumpWidget(_wrap(service, conta: conta));
    await tester.pumpAndSettle();

    expect(find.text('SALVAR ALTERAÇÕES'), findsNothing);
    expect(
      find.text('Cobranças pagas ou canceladas não podem mais ser editadas.'),
      findsOneWidget,
    );
  });
}
