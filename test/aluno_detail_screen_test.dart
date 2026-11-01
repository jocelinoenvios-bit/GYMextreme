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

Widget _tela(AppUser staff, {Aluno? ficha}) => MaterialApp(
  theme: AppTheme.dark,
  home: AlunoDetailScreen(
    aluno: _ana,
    alunoService: FakeAlunoService(aluno: ficha),
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
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Dados pessoais')), findsOneWidget);
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
}
