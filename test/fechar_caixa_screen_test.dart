import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/caixa.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/caixa/fechar_caixa_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_caixa_service.dart';

const _staff = AppUser(
  uid: 'adm-1',
  nome: 'Dono',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

final _caixa = Caixa(
  id: 'caixa-1',
  valorInicial: 100,
  abertoPorUid: 'adm-1',
  abertoPorNome: 'Dono',
  abertoEm: DateTime(2026, 8, 9, 9),
);

Widget _wrap(FakeCaixaService service, {double saldoEsperado = 130}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: FecharCaixaScreen(
      caixaService: service,
      staffAtual: _staff,
      caixa: _caixa,
      saldoEsperadoAtual: saldoEsperado,
    ),
  );
}

void main() {
  testWidgets('mostra o saldo esperado recebido da tela anterior', (tester) async {
    final service = FakeCaixaService(caixaAberto: _caixa);

    await tester.pumpWidget(_wrap(service, saldoEsperado: 130));
    await tester.pumpAndSettle();

    expect(find.text('Saldo esperado: R\$ 130,00'), findsOneWidget);
  });

  testWidgets('mostra "Falta" quando o valor contado e menor que o esperado', (tester) async {
    final service = FakeCaixaService(caixaAberto: _caixa);

    await tester.pumpWidget(_wrap(service, saldoEsperado: 130));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '110,00');
    await tester.pump();

    expect(find.text('Falta'), findsOneWidget);
    expect(find.text('-R\$ 20,00'), findsOneWidget);
  });

  testWidgets('mostra "Sobra" quando o valor contado e maior que o esperado', (tester) async {
    final service = FakeCaixaService(caixaAberto: _caixa);

    await tester.pumpWidget(_wrap(service, saldoEsperado: 130));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '150,00');
    await tester.pump();

    expect(find.text('Sobra'), findsOneWidget);
    expect(find.text('R\$ 20,00'), findsOneWidget);
  });

  testWidgets('confirma o fechamento e chama CaixaService.fecharCaixa', (tester) async {
    final service = FakeCaixaService(caixaAberto: _caixa);

    await tester.pumpWidget(_wrap(service, saldoEsperado: 130));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '130,00');
    await tester.pump();
    await tester.tap(find.text('CONFIRMAR FECHAMENTO'));
    await tester.pumpAndSettle();

    expect(service.ultimoCaixaFechadoId, 'caixa-1');
    expect(service.ultimoValorContadoFechamento, 130);
    expect(service.caixaAberto, isNull);
    expect(service.historico, hasLength(1));
    expect(service.historico.single.status, StatusCaixa.fechado);
  });

  testWidgets('caixa ja fechado: mostra o erro do service ao tentar confirmar de novo', (
    tester,
  ) async {
    // caixaAberto == null no fake simula "este caixa nao esta mais aberto"
    // (ja foi fechado por outra sessao entre abrir a tela e confirmar).
    final service = FakeCaixaService();

    await tester.pumpWidget(_wrap(service, saldoEsperado: 130));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '130,00');
    await tester.pump();
    await tester.tap(find.text('CONFIRMAR FECHAMENTO'));
    await tester.pumpAndSettle();

    expect(find.text('Este caixa já está fechado.'), findsOneWidget);
  });
}
