import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/termo_aceite.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/tabs/termo_tab.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/test_viewport.dart';

const _aluno = AppUser(uid: 'aluno-1', nome: 'Carlos Souza', email: 'carlos@exemplo.com', role: UserRole.aluno);
const _staffAtual = AppUser(uid: 'staff-1', nome: 'Recepção Ana', email: 'ana@exemplo.com', role: UserRole.adm);

Widget _wrap(FakeAlunoService alunoService) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: TermoTab(aluno: _aluno, alunoService: alunoService, staffAtual: _staffAtual),
    ),
  );
}

Future<void> _carregar(WidgetTester tester, Widget tela) async {
  await tester.pumpWidget(tela);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('aluno maior de idade aceita e assina sem precisar de responsavel', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(
      aluno: Aluno(uid: 'aluno-1', dataNascimento: DateTime(DateTime.now().year - 30, 1, 1)),
    );
    await _carregar(tester, _wrap(alunoService));

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('ACEITAR E ASSINAR'));
    await pumpCurto(tester);

    expect(alunoService.ultimoTermoSalvo?.aceito, isTrue);
    expect(alunoService.ultimoTermoSalvo?.nomeAssinatura, 'Carlos Souza');
  });

  testWidgets('aluno menor de idade nao consegue assinar sozinho sem informar o responsavel', (
    tester,
  ) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(
      aluno: Aluno(uid: 'aluno-1', dataNascimento: DateTime(DateTime.now().year - 10, 1, 1)),
    );
    await _carregar(tester, _wrap(alunoService));

    expect(find.textContaining('menor de idade'), findsWidgets);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('ACEITAR E ASSINAR'));
    await tester.pump();

    expect(
      find.text('Aluno menor de idade: informe o nome do responsável que está assinando.'),
      findsOneWidget,
    );
    expect(alunoService.ultimoTermoSalvo, isNull);
  });

  testWidgets('aluno menor de idade consegue assinar depois de informar o responsavel', (
    tester,
  ) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(
      aluno: Aluno(uid: 'aluno-1', dataNascimento: DateTime(DateTime.now().year - 10, 1, 1)),
    );
    await _carregar(tester, _wrap(alunoService));

    await tester.enterText(find.widgetWithText(TextFormField, 'Responsável *'), 'João Souza (pai)');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('ACEITAR E ASSINAR'));
    await pumpCurto(tester);

    expect(alunoService.ultimoTermoSalvo?.aceito, isTrue);
    expect(alunoService.ultimoTermoSalvo?.responsavel, 'João Souza (pai)');
  });

  testWidgets('termo ja aceito mostra a confirmacao em vez do formulario', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(
      aluno: Aluno(uid: 'aluno-1', dataNascimento: DateTime(DateTime.now().year - 30, 1, 1)),
      termo: TermoAceite(
        aceito: true,
        nomeAssinatura: 'Carlos Souza',
        aceitoEm: DateTime(2026, 8, 1, 10, 0),
      ),
    );
    await _carregar(tester, _wrap(alunoService));

    expect(find.text('Termo aceito'), findsOneWidget);
    expect(find.text('ACEITAR E ASSINAR'), findsNothing);
  });
}
