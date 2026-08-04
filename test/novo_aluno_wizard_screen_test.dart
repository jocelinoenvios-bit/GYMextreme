import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/novo_aluno_wizard_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_storage_service.dart';
import 'support/test_viewport.dart';

const _staffAtual = AppUser(uid: 'staff-1', nome: 'Recepção Ana', email: 'ana@exemplo.com', role: UserRole.adm);

Widget _wrap(FakeAlunoService alunoService, FakeStorageService storageService) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: NovoAlunoWizardScreen(
      alunoService: alunoService,
      storageService: storageService,
      staffAtual: _staffAtual,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nao cria o cadastro se nome, e-mail ou senha estiverem vazios', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService();
    await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

    await tester.tap(find.text('CADASTRAR E CONTINUAR'));
    await tester.pump();

    expect(find.text('Informe o nome.'), findsOneWidget);
    expect(alunoService.aluno, isNull);
  });

  testWidgets('CPF com quantidade errada de digitos bloqueia o cadastro', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService();
    await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Carlos Souza');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'carlos@exemplo.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha inicial'), '123456');
    await tester.enterText(find.widgetWithText(TextFormField, 'CPF'), '123');

    await tester.tap(find.text('CADASTRAR E CONTINUAR'));
    await tester.pump();

    expect(find.text('CPF deve ter 11 dígitos.'), findsOneWidget);
    expect(alunoService.aluno, isNull);
  });

  testWidgets('cadastra o aluno com dados validos e avanca pro proximo passo', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService();
    await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Carlos Souza');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'carlos@exemplo.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha inicial'), '123456');
    await tester.enterText(find.widgetWithText(TextFormField, 'Telefone'), '11987654321');

    await tester.tap(find.text('CADASTRAR E CONTINUAR'));
    await pumpCurto(tester);

    expect(alunoService.aluno, isNotNull);
    expect(alunoService.aluno?.telefone, '11987654321');
    expect(alunoService.aluno?.cadastradoPorNome, 'Recepção Ana');
    expect(find.text('Dados salvos.'), findsOneWidget);
  });
}
