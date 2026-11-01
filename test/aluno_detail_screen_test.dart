import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/aluno_detail_screen.dart';
import 'package:gymextreme_app/screens/alunos/tabs/dados_tab.dart';
import 'package:gymextreme_app/screens/alunos/tabs/termo_tab.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_acesso_service.dart';
import 'support/fake_aluno_service.dart';
import 'support/fake_storage_service.dart';
import 'support/test_viewport.dart';

const _ana = AppUser(
  uid: 'ana',
  nome: 'Ana Lima',
  email: 'ana@exemplo.com',
  role: UserRole.aluno,
);
const _adm = AppUser(
  uid: 'adm',
  nome: 'ADM',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);
const _semFrequencia = AppUser(
  uid: 'f1',
  nome: 'Recepção',
  email: 'r@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.gerenciarAlunos},
);

Widget _tela(AppUser staff, {Aluno? ficha, FakeAlunoService? service}) =>
    MaterialApp(
      theme: AppTheme.dark,
      home: AlunoDetailScreen(
        aluno: _ana,
        alunoService: service ?? FakeAlunoService(aluno: ficha),
        storageService: FakeStorageService(),
        staffAtual: staff,
        acessoService: FakeAcessoService(),
      ),
    );

void main() {
  testWidgets('abre no cabeçalho com os cards, sem cair direto em Dados', (
    tester,
  ) async {
    usarViewportGrande(tester);
    final vence = DateTime.now().add(const Duration(days: 10));
    await tester.pumpWidget(
      _tela(
        _adm,
        ficha: Aluno(uid: 'ana', proximoVencimento: vence),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ana@exemplo.com'), findsOneWidget);
    expect(find.text('Em dia'), findsOneWidget);
    for (final rotulo in [
      'Dados\npessoais',
      'Anamnese',
      'Termo',
      'Avaliações',
      'Treinos',
      'Frequência',
    ]) {
      expect(find.text(rotulo), findsOneWidget, reason: rotulo);
    }
    expect(find.byType(DadosTab), findsNothing);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets(
    'tocar num card abre só aquela parte, com o nome do aluno no topo',
    (tester) async {
      usarViewportGrande(tester);
      await tester.pumpWidget(_tela(_adm, ficha: const Aluno(uid: 'ana')));
      await tester.pump();

      await tester.tap(find.text('Dados\npessoais'));
      await tester.pumpAndSettle();
      expect(find.byType(DadosTab), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Dados pessoais'),
        ),
        findsOneWidget,
      );
      expect(find.text('Ana Lima'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Termo'));
      await tester.pumpAndSettle();
      expect(find.byType(TermoTab), findsOneWidget);
      expect(find.byType(DadosTab), findsNothing);
    },
  );

  testWidgets('sem a permissão de frequência, o card Frequência não aparece', (
    tester,
  ) async {
    usarViewportGrande(tester);
    await tester.pumpWidget(_tela(_semFrequencia));
    await tester.pump();

    expect(find.text('Frequência'), findsNothing);
    expect(find.text('Treinos'), findsOneWidget);
  });

  testWidgets('mensalidade vencida aparece como bloqueado no cabeçalho', (
    tester,
  ) async {
    usarViewportGrande(tester);
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    await tester.pumpWidget(
      _tela(
        _adm,
        ficha: Aluno(uid: 'ana', proximoVencimento: ontem),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bloqueado · mensalidade vencida'), findsOneWidget);
  });

  group('Gerenciar acesso', () {
    Future<void> abrir(WidgetTester tester) async {
      await tester.tap(find.text('GERENCIAR ACESSO'));
      await tester.pumpAndSettle();
    }

    testWidgets('bloquear exige motivo; a ficha mostra bloqueado e o motivo', (
      tester,
    ) async {
      usarViewportGrande(tester);
      final service = FakeAlunoService(
        aluno: Aluno(
          uid: 'ana',
          proximoVencimento: DateTime.now().add(const Duration(days: 9)),
        ),
      );
      await tester.pumpWidget(_tela(_adm, service: service));
      await tester.pump();
      await tester.pump();

      await abrir(tester);
      await tester.tap(find.text('Bloquear acesso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BLOQUEAR'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o motivo.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo'),
        'Indisciplina',
      );
      await tester.tap(find.text('BLOQUEAR'));
      await tester.pumpAndSettle();

      expect(service.ultimoMotivoBloqueio, 'Indisciplina');
      expect(find.text('Acesso bloqueado pela recepção'), findsOneWidget);
      expect(find.textContaining('Motivo: Indisciplina'), findsOneWidget);

      // E desbloqueia.
      await abrir(tester);
      await tester.tap(find.text('Desbloquear acesso'));
      await tester.pumpAndSettle();
      expect(find.text('Em dia'), findsOneWidget);
    });

    testWidgets('inativar (motivo opcional) e depois reativar recebendo', (
      tester,
    ) async {
      usarViewportGrande(tester);
      final service = FakeAlunoService(aluno: const Aluno(uid: 'ana'));
      await tester.pumpWidget(_tela(_adm, service: service));
      await tester.pump();
      await tester.pump();

      await abrir(tester);
      await tester.tap(find.text('Inativar aluno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('INATIVAR'));
      await tester.pumpAndSettle();
      expect(find.text('Inativo'), findsOneWidget);

      await abrir(tester);
      expect(find.text('Bloquear acesso'), findsNothing);
      await tester.tap(find.text('Reativar aluno'));
      await tester.pumpAndSettle();
      expect(find.text('Reativar e receber'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor recebido (R\$)'),
        '80',
      );
      await tester.tap(find.text('Dinheiro'));
      await tester.pump();
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();

      expect(service.ultimoRecebimentoMensalidade!.reativar, isTrue);
      expect(find.text('Em dia'), findsOneWidget);
    });

    testWidgets('sem a permissão de gerenciar alunos, o botão não aparece', (
      tester,
    ) async {
      usarViewportGrande(tester);
      const semGerenciar = AppUser(
        uid: 'p',
        nome: 'Personal',
        email: 'p@exemplo.com',
        role: UserRole.funcionario,
        permissoes: {Permission.criarTreinos},
      );
      await tester.pumpWidget(
        _tela(semGerenciar, ficha: const Aluno(uid: 'ana')),
      );
      await tester.pump();
      expect(find.text('GERENCIAR ACESSO'), findsNothing);
    });
  });
}
