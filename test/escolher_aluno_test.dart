import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/copiar_treino_dialog.dart';
import 'package:gymextreme_app/theme/app_theme.dart';
import 'package:gymextreme_app/utils/busca.dart';
import 'package:gymextreme_app/widgets/escolher_aluno.dart';

import 'support/fake_aluno_service.dart';

const _flavio = AppUser(
  uid: 'flavio',
  nome: 'Flávio Santos',
  email: 'flavio@exemplo.com',
  role: UserRole.aluno,
);
const _ana = AppUser(
  uid: 'ana',
  nome: 'Ana Lima',
  email: 'analima@exemplo.com',
  role: UserRole.aluno,
);
const _joao = AppUser(
  uid: 'joao',
  nome: 'JOÃO Pereira',
  email: 'jp@exemplo.com',
  role: UserRole.aluno,
);
const _alunos = [_flavio, _ana, _joao];

/// Campo de filtro (com "Todos") guardando o uid escolhido.
class _Filtro extends StatefulWidget {
  const _Filtro();

  @override
  State<_Filtro> createState() => _FiltroState();
}

class _FiltroState extends State<_Filtro> {
  String? uid;

  @override
  Widget build(BuildContext context) {
    return CampoAluno(
      alunos: _alunos,
      uidSelecionado: uid,
      textoNenhum: 'Todos',
      onChanged: (aluno) => setState(() => uid = aluno?.uid),
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  test('paraBusca ignora acento e maiuscula', () {
    expect(paraBusca('Flávio'), 'flavio');
    expect(paraBusca('JOÃO Conceição'), 'joao conceicao');
  });

  testWidgets('pesquisa sem acento acha o aluno com acento', (tester) async {
    await tester.pumpWidget(_wrap(const _Filtro()));
    await tester.tap(find.byType(CampoAluno));
    await tester.pumpAndSettle();

    // Janela aberta com todos, em ordem alfabética.
    expect(find.text('Pesquisar pelo nome'), findsOneWidget);
    expect(find.text('Ana Lima'), findsOneWidget);
    expect(find.text('Flávio Santos'), findsOneWidget);
    expect(find.text('JOÃO Pereira'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'flavio');
    await tester.pumpAndSettle();
    expect(find.text('Flávio Santos'), findsOneWidget);
    expect(find.text('Ana Lima'), findsNothing);
    expect(find.text('JOÃO Pereira'), findsNothing);

    await tester.enterText(find.byType(TextField), 'joao');
    await tester.pumpAndSettle();
    expect(find.text('JOÃO Pereira'), findsOneWidget);
    expect(find.text('Flávio Santos'), findsNothing);

    // Também acha pelo e-mail.
    await tester.enterText(find.byType(TextField), 'analima');
    await tester.pumpAndSettle();
    expect(find.text('Ana Lima'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum aluno encontrado com "zzz".'), findsOneWidget);
  });

  testWidgets('escolher mostra o nome no campo e o X volta pra Todos', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _Filtro()));
    expect(find.text('Todos'), findsOneWidget);

    await tester.tap(find.byType(CampoAluno));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Lima'));
    await tester.pumpAndSettle();

    expect(find.text('Pesquisar pelo nome'), findsNothing);
    expect(find.text('Ana Lima'), findsOneWidget);
    expect(find.text('Todos'), findsNothing);

    await tester.tap(find.byTooltip('Limpar'));
    await tester.pumpAndSettle();
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Ana Lima'), findsNothing);
  });

  testWidgets('cancelar a janela nao muda a escolha', (tester) async {
    await tester.pumpWidget(_wrap(const _Filtro()));
    await tester.tap(find.byType(CampoAluno));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(find.text('Todos'), findsOneWidget);
  });

  testWidgets('copiar treino tem pesquisa e nao lista o proprio aluno', (
    tester,
  ) async {
    final alunoService = FakeAlunoService(alunos: _alunos);
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => CopiarTreinoDialog(
                alunoDestinoUid: _ana.uid,
                alunoService: alunoService,
                staffAtual: const AppUser(
                  uid: 'adm',
                  nome: 'ADM',
                  email: 'adm@exemplo.com',
                  role: UserRole.adm,
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Lima'), findsNothing);
    expect(find.text('Flávio Santos'), findsOneWidget);
    expect(find.text('JOÃO Pereira'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'joão');
    await tester.pumpAndSettle();
    expect(find.text('JOÃO Pereira'), findsOneWidget);
    expect(find.text('Flávio Santos'), findsNothing);

    await tester.tap(find.text('JOÃO Pereira'));
    await tester.pumpAndSettle();
    expect(find.text('Copiar qual treino?'), findsOneWidget);
  });
}
