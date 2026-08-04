import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/tabs/dados_tab.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_storage_service.dart';
import 'support/test_viewport.dart';

const _appUser = AppUser(uid: 'aluno-1', nome: 'Carlos Souza', email: 'carlos@exemplo.com', role: UserRole.aluno);
const _staffAtual = AppUser(uid: 'staff-1', nome: 'Recepção Ana', email: 'ana@exemplo.com', role: UserRole.adm);

Widget _wrap(FakeAlunoService alunoService, FakeStorageService storageService) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: DadosTab(
        aluno: _appUser,
        alunoService: alunoService,
        storageService: storageService,
        staffAtual: _staffAtual,
      ),
    ),
  );
}

/// A StreamBuilder da tela resolve o primeiro valor de forma assíncrona
/// (Stream.value emite via microtask) — espera em passos curtos até o
/// spinner de carregamento sumir, mesmo padrão já usado em
/// treino_execucao_screen_test.dart.
Future<void> _carregar(WidgetTester tester, Widget tela) async {
  await tester.pumpWidget(tela);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('carrega os dados cadastrais existentes do aluno nos campos', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(
      aluno: const Aluno(uid: 'aluno-1', cpf: '12345678900', telefone: '11987654321'),
    );

    await _carregar(tester, _wrap(alunoService, FakeStorageService()));

    expect(find.text('12345678900'), findsOneWidget);
    expect(find.text('11987654321'), findsOneWidget);
  });

  testWidgets('CPF com quantidade errada de dígitos bloqueia o salvamento', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(aluno: const Aluno(uid: 'aluno-1'));

    await _carregar(tester, _wrap(alunoService, FakeStorageService()));

    await tester.enterText(find.widgetWithText(TextFormField, 'CPF'), '123');
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(find.text('CPF deve ter 11 dígitos.'), findsOneWidget);
    expect(alunoService.ultimoAlunoSalvo, isNull);
  });

  testWidgets('editar telefone com formato valido salva os dados atualizados', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(aluno: const Aluno(uid: 'aluno-1'));

    await _carregar(tester, _wrap(alunoService, FakeStorageService()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Telefone'), '11987654321');
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(alunoService.ultimoAlunoSalvo?.telefone, '11987654321');
    expect(find.text('Dados atualizados.'), findsOneWidget);
  });
}
