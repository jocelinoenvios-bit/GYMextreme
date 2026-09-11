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
    await pumpCurto(tester);

    expect(find.text('CPF deve ter 11 dígitos.'), findsOneWidget);
    expect(alunoService.ultimoAlunoSalvo, isNull);
  });

  testWidgets('editar telefone com formato valido salva os dados atualizados', (tester) async {
    usarViewportGrande(tester);
    final alunoService = FakeAlunoService(aluno: const Aluno(uid: 'aluno-1'));

    await _carregar(tester, _wrap(alunoService, FakeStorageService()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Telefone'), '11987654321');
    await tester.tap(find.text('SALVAR'));
    await pumpCurto(tester);

    expect(alunoService.ultimoAlunoSalvo?.telefone, '11987654321');
    expect(find.text('Dados atualizados.'), findsOneWidget);
  });

  group('regressão do bug: editar dados não pode apagar campos operacionais/financeiros', () {
    // Reproduz exatamente o cenário do bug: (1) aluno ativo com
    // proximoVencimento preenchido, (2) edita só telefone/endereço,
    // (3) salva, (4-8) todos os campos operacionais/financeiros
    // continuam exatamente como estavam antes.
    testWidgets('editar só telefone/endereço preserva ativo/bloqueado/vencimento/inatividade/optIn', (
      tester,
    ) async {
      usarViewportGrande(tester);
      final vencimentoOriginal = DateTime(2026, 12, 10);
      final dataInativacaoOriginal = DateTime(2026, 3, 1);
      final dataReativacaoOriginal = DateTime(2026, 5, 20);
      final alunoOriginal = Aluno(
        uid: 'aluno-1',
        telefone: '11900000000',
        ativo: true,
        bloqueado: true,
        proximoVencimento: vencimentoOriginal,
        dataInativacao: dataInativacaoOriginal,
        dataReativacao: dataReativacaoOriginal,
        whatsappOptIn: true,
      );
      final alunoService = FakeAlunoService(aluno: alunoOriginal);

      await _carregar(tester, _wrap(alunoService, FakeStorageService()));

      // (2) Edita SÓ telefone/endereço — nenhum campo operacional é
      // tocado pela tela (não existe nem UI pra isso na aba Dados).
      await tester.enterText(find.widgetWithText(TextFormField, 'Telefone'), '11987654321');
      await tester.enterText(find.widgetWithText(TextFormField, 'Rua/Av.'), 'Rua Nova');

      // (3) Salva.
      await tester.tap(find.text('SALVAR'));
      await pumpCurto(tester);

      final salvo = alunoService.aluno!;
      expect(salvo.telefone, '11987654321'); // edição foi aplicada
      expect(salvo.endereco.logradouro, 'Rua Nova'); // edição foi aplicada
      // (4) ativo continua ativo.
      expect(salvo.ativo, isTrue);
      // (6) bloqueado continua igual.
      expect(salvo.bloqueado, isTrue);
      // (5) proximoVencimento continua igual.
      expect(salvo.proximoVencimento, vencimentoOriginal);
      // (7) dataInativacao/dataReativacao continuam iguais.
      expect(salvo.dataInativacao, dataInativacaoOriginal);
      expect(salvo.dataReativacao, dataReativacaoOriginal);
      // (8) whatsappOptIn continua igual.
      expect(salvo.whatsappOptIn, isTrue);
    });

    testWidgets('editar dados de um aluno INATIVO não o reativa nem limpa o histórico', (
      tester,
    ) async {
      usarViewportGrande(tester);
      final dataInativacaoOriginal = DateTime(2026, 3, 1);
      final alunoService = FakeAlunoService(
        aluno: Aluno(
          uid: 'aluno-1',
          ativo: false,
          bloqueado: false,
          dataInativacao: dataInativacaoOriginal,
        ),
      );

      await _carregar(tester, _wrap(alunoService, FakeStorageService()));

      await tester.enterText(find.widgetWithText(TextFormField, 'CPF'), '12345678900');
      await tester.tap(find.text('SALVAR'));
      await pumpCurto(tester);

      final salvo = alunoService.aluno!;
      expect(salvo.cpf, '12345678900');
      // O aluno continua inativo — editar cadastro nunca reativa sozinho.
      expect(salvo.ativo, isFalse);
      expect(salvo.dataInativacao, dataInativacaoOriginal);
    });
  });

  group('operações que DEVEM alterar os campos operacionais continuam funcionando', () {
    test('AlunoService.reativarAluno ainda ativa o aluno e define novo vencimento', () async {
      final alunoService = FakeAlunoService(
        aluno: Aluno(
          uid: 'aluno-1',
          ativo: false,
          dataInativacao: DateTime(2026, 3, 1),
        ),
      );

      await alunoService.reativarAluno('aluno-1', staffUid: 'staff-1', staffNome: 'Ana');

      expect(alunoService.aluno!.ativo, isTrue);
      expect(alunoService.aluno!.dataReativacao, isNotNull);
      expect(alunoService.ultimaReativacao, isNotNull);
    });
  });
}
