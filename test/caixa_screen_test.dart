import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/caixa.dart';
import 'package:gymextreme_app/models/caixa_movimentacao.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/caixa/caixa_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_caixa_service.dart';

const _admin = AppUser(
  uid: 'adm-1',
  nome: 'Dono',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

const _recepcaoSoAcesso = AppUser(
  uid: 'func-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.acessarControleCaixa},
);

Widget _wrap(FakeCaixaService service, AppUser staffAtual) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: CaixaScreen(caixaService: service, staffAtual: staffAtual),
  );
}

void main() {
  group('CaixaScreen — sem caixa aberto', () {
    testWidgets('mostra o estado vazio e o botao ABRIR CAIXA pra quem tem permissao', (
      tester,
    ) async {
      final service = FakeCaixaService();

      await tester.pumpWidget(_wrap(service, _admin));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum caixa aberto no momento.'), findsOneWidget);
      expect(find.text('ABRIR CAIXA'), findsOneWidget);
    });

    testWidgets('esconde o botao ABRIR CAIXA de quem nao tem a permissao abrirCaixa', (
      tester,
    ) async {
      final service = FakeCaixaService();

      await tester.pumpWidget(_wrap(service, _recepcaoSoAcesso));
      await tester.pumpAndSettle();

      expect(find.text('ABRIR CAIXA'), findsNothing);
    });

    testWidgets('abre um novo caixa com o valor inicial informado', (tester) async {
      final service = FakeCaixaService();

      await tester.pumpWidget(_wrap(service, _admin));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ABRIR CAIXA'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '150,00');
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      expect(service.caixaAberto, isNotNull);
      expect(service.ultimoValorInicialAbertura, 150);
    });

    testWidgets('icone de historico so aparece pra quem tem consultarRelatorioCaixa', (
      tester,
    ) async {
      final service = FakeCaixaService();

      await tester.pumpWidget(_wrap(service, _recepcaoSoAcesso));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsNothing);

      await tester.pumpWidget(_wrap(service, _admin));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsOneWidget);
    });
  });

  group('CaixaScreen — caixa aberto', () {
    Caixa caixaAberta() => Caixa(
      id: 'caixa-1',
      valorInicial: 100,
      abertoPorUid: 'adm-1',
      abertoPorNome: 'Dono',
      abertoEm: DateTime(2026, 8, 9, 9),
    );

    testWidgets('mostra status, saldo inicial e saldo esperado calculado', (tester) async {
      final service = FakeCaixaService(
        caixaAberto: caixaAberta(),
        movimentacoes: [
          CaixaMovimentacao(
            id: 'm1',
            tipo: TipoMovimentacaoCaixa.suprimento,
            valor: 50,
            staffUid: 'adm-1',
            staffNome: 'Dono',
            criadoEm: DateTime(2026, 8, 9, 10),
          ),
          CaixaMovimentacao(
            id: 'm2',
            tipo: TipoMovimentacaoCaixa.retirada,
            valor: -20,
            staffUid: 'adm-1',
            staffNome: 'Dono',
            criadoEm: DateTime(2026, 8, 9, 11),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(service, _admin));
      await tester.pumpAndSettle();

      expect(find.text('Aberto'), findsOneWidget);
      expect(find.text('Saldo inicial: R\$ 100,00'), findsOneWidget);
      // Esperado: 100 + 50 - 20 = 130.
      expect(find.text('R\$ 130,00'), findsOneWidget);
    });

    testWidgets('esconde RETIRADA/SUPRIMENTO/FECHAR CAIXA sem as permissoes', (tester) async {
      final service = FakeCaixaService(caixaAberto: caixaAberta());

      await tester.pumpWidget(_wrap(service, _recepcaoSoAcesso));
      await tester.pumpAndSettle();

      expect(find.text('RETIRADA'), findsNothing);
      expect(find.text('SUPRIMENTO'), findsNothing);
      expect(find.text('FECHAR CAIXA'), findsNothing);
    });

    testWidgets('registra uma retirada', (tester) async {
      final service = FakeCaixaService(caixaAberto: caixaAberta());

      await tester.pumpWidget(_wrap(service, _admin));
      await tester.pumpAndSettle();

      await tester.tap(find.text('RETIRADA'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '30,00');
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();

      expect(service.ultimaMovimentacaoRegistrada?.tipo, TipoMovimentacaoCaixa.retirada);
      expect(service.ultimaMovimentacaoRegistrada?.valor, -30);
    });

    testWidgets('registra um suprimento', (tester) async {
      final service = FakeCaixaService(caixaAberto: caixaAberta());

      await tester.pumpWidget(_wrap(service, _admin));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SUPRIMENTO'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '40,00');
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();

      expect(service.ultimaMovimentacaoRegistrada?.tipo, TipoMovimentacaoCaixa.suprimento);
      expect(service.ultimaMovimentacaoRegistrada?.valor, 40);
    });

    testWidgets('lista as movimentacoes registradas', (tester) async {
      final service = FakeCaixaService(
        caixaAberto: caixaAberta(),
        movimentacoes: [
          CaixaMovimentacao(
            id: 'm1',
            tipo: TipoMovimentacaoCaixa.suprimento,
            valor: 50,
            staffUid: 'adm-1',
            staffNome: 'Dono',
            criadoEm: DateTime(2026, 8, 9, 10),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(service, _admin));
      await tester.pumpAndSettle();

      expect(find.text('Suprimento'), findsOneWidget);
      expect(find.text('Nenhuma movimentação ainda.'), findsNothing);
    });
  });
}
