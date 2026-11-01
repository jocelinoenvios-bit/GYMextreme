import 'dart:typed_data';

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
import 'package:gymextreme_app/widgets/foto_aluno_image.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

class _GaleriaFalsa extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return XFile.fromData(Uint8List.fromList(const [1, 2, 3]), name: 'foto.jpg');
  }
}

void main() {
  setUp(() => ImagePickerPlatform.instance = _GaleriaFalsa());

  testWidgets('aluno troca a própria foto pelas Configurações', (tester) async {
    final alunoService = FakeAlunoService(aluno: const Aluno(uid: _uid));
    await tester.pumpWidget(_tela(alunoService));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TROCAR FOTO DE PERFIL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();

    expect(alunoService.ultimaFotoUrlSalva, isNotNull);
    expect(find.text('Foto atualizada.'), findsOneWidget);
  });

  testWidgets('tocar na foto do topo também abre o trocar foto, e ela está maior', (tester) async {
    final alunoService = FakeAlunoService(aluno: const Aluno(uid: _uid));
    await tester.pumpWidget(_tela(alunoService));
    await tester.pump();
    await tester.pump();

    final avatar = find.descendant(of: find.byType(AppBar), matching: find.byType(CircleAvatar));
    expect(tester.getSize(avatar).width, greaterThanOrEqualTo(64));

    await tester.tap(avatar);
    await tester.pumpAndSettle();
    expect(find.text('Escolher da galeria'), findsOneWidget);
  });

  test('foto do aluno no Firestore vira a imagem certa no topo', () {
    expect(imagemDaFotoAluno('firestore://fotosAlunos/$_uid?v=1'), isA<FotoFirestoreImage>());
  });
}
