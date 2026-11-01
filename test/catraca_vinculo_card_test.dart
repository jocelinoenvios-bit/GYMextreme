import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/catraca.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/tabs/catraca_vinculo_card.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_acesso_service.dart';

const _adm = AppUser(uid: 'adm', nome: 'ADM', email: 'adm@exemplo.com', role: UserRole.adm);
const _entrada = DispositivoAcesso(id: 'd1', nome: 'Entrada principal');
const _fundos = DispositivoAcesso(id: 'd2', nome: 'Porta dos fundos');

Widget _tela(FakeAcessoService service) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: CatracaVinculoCard(alunoUid: 'aluno-1', acessoService: service, staffAtual: _adm),
  ),
);

void main() {
  test('validarCodigoCatraca: só números', () {
    expect(validarCodigoCatraca(''), isNotNull);
    expect(validarCodigoCatraca('12a'), isNotNull);
    expect(validarCodigoCatraca(' 1024 '), isNull);
  });

  testWidgets('sem leitor cadastrado: explica onde cadastrar', (tester) async {
    await tester.pumpWidget(_tela(FakeAcessoService()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum leitor cadastrado'), findsOneWidget);
    expect(find.text('VINCULAR CÓDIGO'), findsNothing);
  });

  testWidgets('vincula um código e mostra na ficha', (tester) async {
    final service = FakeAcessoService(dispositivos: const [_entrada]);
    await tester.pumpWidget(_tela(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('a catraca não vai liberar'), findsOneWidget);
    await tester.tap(find.text('VINCULAR CÓDIGO'));
    await tester.pumpAndSettle();

    // Vazio não passa.
    await tester.tap(find.text('VINCULAR'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o código que o leitor deu ao aluno.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '1024');
    await tester.tap(find.text('VINCULAR'));
    await tester.pumpAndSettle();

    expect(service.credenciais['d1'], {'1024': 'aluno-1'});
    expect(find.text('Código 1024'), findsOneWidget);
    expect(find.textContaining('a catraca não vai liberar'), findsNothing);
  });

  testWidgets('código de outro aluno: recusa com mensagem', (tester) async {
    final service = FakeAcessoService(dispositivos: const [_entrada]);
    service.credenciais['d1'] = {'7': 'outro-aluno'};
    await tester.pumpWidget(_tela(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VINCULAR CÓDIGO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '7');
    await tester.tap(find.text('VINCULAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('já está vinculado a outro aluno'), findsOneWidget);
    expect(service.credenciais['d1'], {'7': 'outro-aluno'});
  });

  testWidgets('dois leitores: escolhe o leitor e mostra o nome dele', (tester) async {
    final service = FakeAcessoService(dispositivos: const [_entrada, _fundos]);
    await tester.pumpWidget(_tela(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VINCULAR CÓDIGO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrada principal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Porta dos fundos').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '55');
    await tester.tap(find.text('VINCULAR'));
    await tester.pumpAndSettle();

    expect(service.credenciais['d2'], {'55': 'aluno-1'});
    expect(find.text('Código 55 · Porta dos fundos'), findsOneWidget);
  });

  testWidgets('desvincular pede confirmação e remove', (tester) async {
    final service = FakeAcessoService(dispositivos: const [_entrada]);
    service.credenciais['d1'] = {'1024': 'aluno-1'};
    await tester.pumpWidget(_tela(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Desvincular'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DESVINCULAR'));
    await tester.pumpAndSettle();

    expect(service.credenciais['d1'], isEmpty);
    expect(find.text('Código 1024'), findsNothing);
  });
}
