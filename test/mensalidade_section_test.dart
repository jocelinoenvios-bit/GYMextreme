import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
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
}
