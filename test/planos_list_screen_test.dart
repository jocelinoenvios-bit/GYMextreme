import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/plano.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/planos/planos_list_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_plano_service.dart';

const _adm = AppUser(
  uid: 'adm-1',
  nome: 'Dono',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

const _recepcaoSemPermissao = AppUser(
  uid: 'func-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.gerenciarAlunos},
);

Widget _wrap(FakePlanoService service, AppUser staffAtual) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: PlanosListScreen(planoService: service, staffAtual: staffAtual),
  );
}

void main() {
  testWidgets('lista os planos cadastrados com valor e duracao', (tester) async {
    final service = FakePlanoService(
      planos: const [
        Plano(id: 'p1', nome: 'Mensal', valor: 129.9, duracaoDias: 30),
        Plano(id: 'p2', nome: 'Trimestral', valor: 349, duracaoDias: 90),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pump();

    expect(find.text('Mensal'), findsOneWidget);
    expect(find.text('Trimestral'), findsOneWidget);
    expect(find.textContaining('R\$ 129,90'), findsOneWidget);
  });

  testWidgets('estado vazio mostra mensagem adequada', (tester) async {
    final service = FakePlanoService();

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pump();

    expect(find.textContaining('Nenhum plano cadastrado'), findsOneWidget);
  });

  testWidgets('ADM ve o botao de novo plano', (tester) async {
    final service = FakePlanoService();

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pump();

    expect(find.text('Novo plano'), findsOneWidget);
  });

  testWidgets(
    'funcionario sem permissao de planos nao ve o botao de novo plano nem '
    'excluir',
    (tester) async {
      final service = FakePlanoService(
        planos: const [Plano(id: 'p1', nome: 'Mensal', valor: 129.9, duracaoDias: 30)],
      );

      await tester.pumpWidget(_wrap(service, _recepcaoSemPermissao));
      await tester.pump();

      expect(find.text('Novo plano'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    },
  );

  testWidgets('plano inativo mostra a etiqueta "Inativo"', (tester) async {
    final service = FakePlanoService(
      planos: const [
        Plano(id: 'p1', nome: 'Plano antigo', valor: 99, duracaoDias: 30, ativo: false),
      ],
    );

    await tester.pumpWidget(_wrap(service, _adm));
    await tester.pump();

    expect(find.text('Inativo'), findsOneWidget);
  });

  testWidgets(
    'tocar em excluir chama PlanoService.excluirPlano depois de confirmar',
    (tester) async {
      final service = FakePlanoService(
        planos: const [Plano(id: 'p1', nome: 'Mensal', valor: 129.9, duracaoDias: 30)],
      );

      await tester.pumpWidget(_wrap(service, _adm));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Excluir plano'), findsOneWidget);
      await tester.tap(find.text('EXCLUIR'));
      await tester.pumpAndSettle();

      expect(service.ultimoPlanoExcluidoId, 'p1');
    },
  );
}
