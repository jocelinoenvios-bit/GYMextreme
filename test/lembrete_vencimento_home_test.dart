import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/welcome_screen.dart';
import 'package:gymextreme_app/services/auth_service.dart';
import 'package:gymextreme_app/services/cargo_service.dart';
import 'package:gymextreme_app/services/funcionario_service.dart';
import 'package:gymextreme_app/services/notificacao_service.dart';
import 'package:gymextreme_app/services/user_service.dart';
import 'package:gymextreme_app/theme/app_theme.dart';
import 'package:gymextreme_app/utils/lembrete_vencimento.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_caixa_service.dart';
import 'support/fake_conta_pagar_service.dart';
import 'support/fake_plano_service.dart';
import 'support/fake_produto_service.dart';
import 'support/fake_storage_service.dart';

const _uid = 'aluno-1';
const _usuario = AppUser(
  uid: _uid,
  nome: 'Carlos Souza',
  email: 'carlos@exemplo.com',
  role: UserRole.aluno,
);

class _UserService implements UserService {
  @override
  Stream<AppUser?> watchUser(String uid) => Stream.value(_usuario);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Serviços que a tela inicial do aluno recebe mas não usa.
class _NaoUsado
    implements
        AuthService,
        CargoService,
        FuncionarioService,
        NotificacaoService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _tela(FakeAlunoService alunoService) {
  final naoUsado = _NaoUsado();
  return MaterialApp(
    theme: AppTheme.dark,
    home: WelcomeScreen(
      uid: _uid,
      authService: naoUsado,
      userService: _UserService(),
      alunoService: alunoService,
      caixaService: FakeCaixaService(),
      cargoService: naoUsado,
      contaPagarService: FakeContaPagarService(),
      funcionarioService: naoUsado,
      notificacaoService: naoUsado,
      planoService: FakePlanoService(),
      produtoService: FakeProdutoService(),
      storageService: FakeStorageService(),
    ),
  );
}

DateTime _hoje() {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
}

void main() {
  testWidgets(
    'a 2 dias do vencimento: lembrete na caixa e aviso discreto na tela',
    (tester) async {
      final vencimento = _hoje().add(const Duration(days: 2));
      final alunoService = FakeAlunoService(
        aluno: Aluno(uid: _uid, proximoVencimento: vencimento),
      );

      await tester.pumpWidget(_tela(alunoService));
      await tester.pump();
      await tester.pump();

      expect(alunoService.lembretesPedidos, [vencimento]);
      final lembrete = alunoService.mensagens.single;
      expect(lembrete.id, idLembreteVencimento(vencimento));
      expect(lembrete.automatica, isTrue);
      expect(lembrete.lida, isFalse);
      expect(
        find.text(avisoCurtoVencimento(vencimento, _hoje())),
        findsOneWidget,
      );
    },
  );

  testWidgets('longe do vencimento: nada de lembrete nem aviso', (
    tester,
  ) async {
    final vencimento = _hoje().add(const Duration(days: 10));
    final alunoService = FakeAlunoService(
      aluno: Aluno(uid: _uid, proximoVencimento: vencimento),
    );

    await tester.pumpWidget(_tela(alunoService));
    await tester.pump();
    await tester.pump();

    expect(alunoService.lembretesPedidos, isEmpty);
    expect(alunoService.mensagens, isEmpty);
    expect(find.textContaining('Sua mensalidade vence'), findsNothing);
  });
}
