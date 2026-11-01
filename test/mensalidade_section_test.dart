import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/matricula.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/tabs/mensalidade_section.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

const _staff = AppUser(
  uid: 'staff-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
);

const _adm = AppUser(
  uid: 'adm-1',
  nome: 'Admin Teste',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

Widget _wrap({required DateTime? proximoVencimento, String? whatsapp}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: MensalidadeSection(
        alunoUid: 'aluno-1',
        proximoVencimento: proximoVencimento,
        alunoService: FakeAlunoService(),
        staffAtual: _staff,
        whatsapp: whatsapp,
      ),
    ),
  );
}

Widget _wrapInativo({
  required AppUser staff,
  required FakeAlunoService alunoService,
  DateTime? dataInativacao,
  DateTime? dataReativacao,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: MensalidadeSection(
        alunoUid: 'aluno-1',
        proximoVencimento: DateTime(2026, 1, 10),
        alunoService: alunoService,
        staffAtual: staff,
        ativo: false,
        dataInativacao: dataInativacao,
        dataReativacao: dataReativacao,
      ),
    ),
  );
}

void main() {
  group('botão "Chamar no WhatsApp"', () {
    testWidgets('não aparece quando a mensalidade está em dia', (tester) async {
      await tester.pumpWidget(
        _wrap(proximoVencimento: DateTime.now().add(const Duration(days: 5)), whatsapp: '11999998888'),
      );

      expect(find.text('CHAMAR NO WHATSAPP'), findsNothing);
    });

    testWidgets('não aparece quando o aluno não tem WhatsApp cadastrado', (tester) async {
      await tester.pumpWidget(
        _wrap(proximoVencimento: DateTime.now().subtract(const Duration(days: 20)), whatsapp: null),
      );

      expect(find.text('CHAMAR NO WHATSAPP'), findsNothing);
    });

    testWidgets('aparece quando a mensalidade está em tolerância e há WhatsApp cadastrado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(proximoVencimento: DateTime.now().subtract(const Duration(days: 2)), whatsapp: '11999998888'),
      );

      expect(find.text('CHAMAR NO WHATSAPP'), findsOneWidget);
    });

    testWidgets('aparece quando a mensalidade está bloqueada por atraso e há WhatsApp cadastrado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(proximoVencimento: DateTime.now().subtract(const Duration(days: 20)), whatsapp: '11999998888'),
      );

      expect(find.text('CHAMAR NO WHATSAPP'), findsOneWidget);
    });
  });

  group('aluno inativo', () {
    testWidgets('mostra o selo "Inativo" e a data de inativação, nunca o status de mensalidade', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapInativo(
          staff: _adm,
          alunoService: FakeAlunoService(),
          dataInativacao: DateTime(2026, 3, 1),
        ),
      );

      expect(find.text('Inativo'), findsOneWidget);
      expect(find.textContaining('Inativo desde 01/03/2026'), findsOneWidget);
      expect(find.text('MARCAR PAGAMENTO RECEBIDO'), findsNothing);
    });

    testWidgets('staff sem permissão de receber mensalidade não vê o botão de reativar', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapInativo(staff: _staff, alunoService: FakeAlunoService()));

      expect(find.text('REATIVAR ALUNO'), findsNothing);
    });

    testWidgets('tocar em "Reativar aluno" chama AlunoService.reativarAluno', (tester) async {
      final alunoService = FakeAlunoService();

      await tester.pumpWidget(_wrapInativo(staff: _adm, alunoService: alunoService));
      expect(find.text('REATIVAR ALUNO'), findsOneWidget);

      await tester.tap(find.text('REATIVAR ALUNO'));
      await tester.pumpAndSettle();

      expect(alunoService.ultimaReativacao, isNotNull);
      expect(alunoService.ultimaReativacao!.staffUid, 'adm-1');
    });
  });

  group('Receber mensalidade', () {
    final vencimento = DateTime.now().add(const Duration(days: 3));
    final venceDia = DateTime(vencimento.year, vencimento.month, vencimento.day);

    Widget tela(FakeAlunoService service) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: MensalidadeSection(
          alunoUid: 'aluno-1',
          alunoNome: 'Ana',
          proximoVencimento: venceDia,
          alunoService: service,
          staffAtual: _adm,
        ),
      ),
    );

    Matricula matricula80() => Matricula(
      id: 'm1',
      alunoId: 'aluno-1',
      planoId: '',
      dataInicio: DateTime(2026, 1, 1),
      dataVencimento: venceDia,
      valorContratado: 80,
    );

    Future<void> abrir(WidgetTester tester) async {
      await tester.tap(find.text('RECEBER MENSALIDADE'));
      await tester.pumpAndSettle();
    }

    testWidgets('valor já vem da matrícula; exige a forma; recebe e confirma', (tester) async {
      final service = FakeAlunoService(matriculas: [matricula80()]);
      await tester.pumpWidget(tela(service));
      await abrir(tester);

      expect(find.text('Receber mensalidade'), findsOneWidget);
      expect(find.text('80,00'), findsOneWidget);

      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();
      expect(find.text('Escolha a forma de pagamento.'), findsOneWidget);
      expect(service.ultimoRecebimentoMensalidade, isNull);

      await tester.tap(find.text('Pix'));
      await tester.pump();
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();

      final recebido = service.ultimoRecebimentoMensalidade!;
      expect(recebido.valor, 80);
      expect(recebido.formaPagamento, 'Pix');
      expect(recebido.vencimentoAtual, venceDia);
      expect(find.textContaining('Mensalidade recebida: R\$ 80,00 (Pix)'), findsOneWidget);
      expect(find.textContaining('Nenhum caixa aberto'), findsNothing);
    });

    testWidgets('sem caixa aberto: avisa que ficou fora do caixa', (tester) async {
      final service = FakeAlunoService(matriculas: [matricula80()])..caixaAbertoAoReceber = false;
      await tester.pumpWidget(tela(service));
      await abrir(tester);
      await tester.tap(find.text('Dinheiro'));
      await tester.pump();
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhum caixa aberto'), findsOneWidget);
    });

    testWidgets('sem matrícula: valor em branco e, depois, aviso da catraca', (tester) async {
      final service = FakeAlunoService()..temMatriculaAtivaAoReceber = false;
      await tester.pumpWidget(tela(service));
      await abrir(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Valor recebido (R\$)'), '75');
      await tester.tap(find.text('Cartão'));
      await tester.pump();
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();

      expect(service.ultimoRecebimentoMensalidade!.valor, 75);
      expect(find.text('Aluno sem matrícula ativa'), findsOneWidget);
      expect(find.textContaining('A catraca não vai liberar'), findsOneWidget);
    });

    testWidgets('cancelar não recebe nada', (tester) async {
      final service = FakeAlunoService(matriculas: [matricula80()]);
      await tester.pumpWidget(tela(service));
      await abrir(tester);
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(service.ultimoRecebimentoMensalidade, isNull);
    });
  });
}
