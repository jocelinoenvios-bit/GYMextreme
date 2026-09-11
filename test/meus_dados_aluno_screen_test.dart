import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/area_aluno/meus_dados_aluno_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/rich_text_finder.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

const _usuario = AppUser(
  uid: 'aluno-1',
  nome: 'Ana Teste',
  email: 'ana@teste.com',
  role: UserRole.aluno,
);

void main() {
  group('MeusDadosAlunoScreen', () {
    testWidgets('mostra nome/e-mail mesmo sem nenhum dado de cadastro adicional', (tester) async {
      final alunoService = FakeAlunoService(aluno: null);

      await tester.pumpWidget(
        _wrap(
          MeusDadosAlunoScreen(usuario: _usuario, uid: 'aluno-1', alunoService: alunoService),
        ),
      );
      await tester.pump();

      expect(findRichTextContaining('Ana Teste'), findsOneWidget);
      expect(findRichTextContaining('ana@teste.com'), findsOneWidget);
    });

    testWidgets('mostra os dados pessoais preenchidos e omite os vazios', (tester) async {
      final alunoService = FakeAlunoService(
        aluno: const Aluno(
          uid: 'aluno-1',
          sexo: Sexo.feminino,
          telefone: '11999990000',
        ),
      );

      await tester.pumpWidget(
        _wrap(
          MeusDadosAlunoScreen(usuario: _usuario, uid: 'aluno-1', alunoService: alunoService),
        ),
      );
      await tester.pump();

      expect(findRichTextContaining('Feminino'), findsOneWidget);
      expect(findRichTextContaining('11999990000'), findsOneWidget);
      // CPF não foi preenchido — não deve aparecer nenhuma linha em branco.
      expect(findRichTextContaining('CPF'), findsNothing);
    });
  });
}
