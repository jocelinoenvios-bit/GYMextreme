import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/mensagem.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/enviar_mensagem_screen.dart';
import 'package:gymextreme_app/screens/alunos/mensagens_enviadas_lista.dart';
import 'package:gymextreme_app/screens/area_aluno/mensagens_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

Mensagem _aviso({
  String id = 'm1',
  String texto = 'Sua mensalidade vence em 5 dias.',
  String alunoNome = 'Marcelo Teste',
  String alunoUid = 'aluno-1',
  DateTime? lidaEm,
  bool arquivada = false,
}) {
  return Mensagem(
    id: id,
    texto: texto,
    remetenteUid: 'staff-1',
    remetenteNome: 'Personal João',
    alunoUid: alunoUid,
    alunoNome: alunoNome,
    criadoEm: DateTime(2026, 3, 10, 14, 30),
    lidaEm: lidaEm,
    arquivadaPeloAluno: arquivada,
  );
}

const _staff = AppUser(
  uid: 'staff-1',
  nome: 'Personal João',
  email: 'joao@example.com',
  role: UserRole.personal,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mensagem', () {
    test('toFirestore leva o destinatário junto e nasce não lida', () {
      final dados = _aviso().toFirestore();

      // Sem alunoUid/alunoNome no documento, a aba "Enviadas" (que varre
      // todas as subcoleções de uma vez) não teria como dizer pra quem a
      // mensagem foi — ela só enxerga o documento, não o caminho.
      expect(dados['alunoUid'], 'aluno-1');
      expect(dados['alunoNome'], 'Marcelo Teste');
      expect(dados['lidaEm'], isNull);
      expect(dados['arquivadaPeloAluno'], isFalse);
    });

    test('fromFirestore aceita documento antigo, sem os campos novos', () {
      // Os avisos enviados antes desta mudança não têm alunoUid/lidaEm —
      // precisam continuar abrindo, só que sem destinatário conhecido.
      final mensagem = Mensagem.fromFirestore('m0', {
        'texto': 'oi',
        'remetenteUid': 'staff-1',
        'remetenteNome': 'Personal João',
      });

      expect(mensagem.alunoNome, '');
      expect(mensagem.lida, isFalse);
      expect(mensagem.arquivadaPeloAluno, isFalse);
    });
  });

  group('MensagensScreen (aluno)', () {
    testWidgets('marca como lidas as não lidas ao abrir', (tester) async {
      final service = FakeAlunoService(
        mensagens: [
          _aviso(id: 'm1'),
          _aviso(id: 'm2', lidaEm: DateTime(2026, 3, 9)),
        ],
      );

      await tester.pumpWidget(
        _wrap(MensagensScreen(uid: 'aluno-1', alunoService: service)),
      );
      await tester.pumpAndSettle();

      // Só a não lida — remarcar a que já estava lida seria escrita à toa.
      expect(service.idsMarcadosComoLidos, ['m1']);
    });

    testWidgets('não remarca em laço quando o stream reemite', (tester) async {
      final service = FakeAlunoService(mensagens: [_aviso(id: 'm1')]);

      await tester.pumpWidget(
        _wrap(MensagensScreen(uid: 'aluno-1', alunoService: service)),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      // Marcar como lida muda o documento, que reemite o stream, que
      // rodaria a marcação de novo: laço infinito de escrita no Firestore.
      expect(service.idsMarcadosComoLidos, ['m1']);
    });

    testWidgets('apagar arquiva em vez de excluir', (tester) async {
      final service = FakeAlunoService(mensagens: [_aviso(id: 'm1')]);

      await tester.pumpWidget(
        _wrap(MensagensScreen(uid: 'aluno-1', alunoService: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // O registro tem que sobreviver pro staff: numa academia interessa
      // provar que o aviso foi dado.
      expect(service.idsArquivados, ['m1']);
      expect(service.idsApagados, isEmpty);
    });

    testWidgets('não mostra o que o aluno já arquivou', (tester) async {
      final service = FakeAlunoService(
        mensagens: [
          _aviso(id: 'm1', texto: 'Aviso visível'),
          _aviso(id: 'm2', texto: 'Aviso arquivado', arquivada: true),
        ],
      );

      await tester.pumpWidget(
        _wrap(MensagensScreen(uid: 'aluno-1', alunoService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aviso visível'), findsOneWidget);
      expect(find.text('Aviso arquivado'), findsNothing);
    });

    testWidgets('sem mensagens mostra o estado vazio', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MensagensScreen(uid: 'aluno-1', alunoService: FakeAlunoService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma mensagem no momento'), findsOneWidget);
    });
  });

  group('Enviadas (staff)', () {
    testWidgets('mostra pra quem foi e se já foi lida', (tester) async {
      final service = FakeAlunoService(
        mensagens: [
          _aviso(id: 'm1', alunoNome: 'Marcelo Teste'),
          _aviso(
            id: 'm2',
            alunoNome: 'Ana Souza',
            texto: 'Bem-vinda de volta!',
            lidaEm: DateTime(2026, 3, 11),
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(Scaffold(body: MensagensEnviadasLista(alunoService: service))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marcelo Teste'), findsOneWidget);
      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('Não lida'), findsOneWidget);
      expect(find.text('Lida'), findsOneWidget);
    });

    testWidgets('busca filtra pelo nome do aluno', (tester) async {
      final service = FakeAlunoService(
        mensagens: [
          _aviso(id: 'm1', alunoNome: 'Marcelo Teste', texto: 'Para o Marcelo'),
          _aviso(id: 'm2', alunoNome: 'Ana Souza', texto: 'Para a Ana'),
        ],
      );

      await tester.pumpWidget(
        _wrap(Scaffold(body: MensagensEnviadasLista(alunoService: service))),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pumpAndSettle();

      expect(find.text('Para a Ana'), findsOneWidget);
      expect(find.text('Para o Marcelo'), findsNothing);
    });

    testWidgets('apagar pede confirmação antes, e apaga dos dois lados', (
      tester,
    ) async {
      final service = FakeAlunoService(mensagens: [_aviso(id: 'm1')]);

      await tester.pumpWidget(
        _wrap(Scaffold(body: MensagensEnviadasLista(alunoService: service))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(service.idsApagados, isEmpty, reason: 'ainda não confirmou');

      await tester.tap(find.text('APAGAR'));
      await tester.pumpAndSettle();

      expect(service.idsApagados, ['m1']);
    });

    testWidgets('sem nada enviado mostra o estado vazio', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: MensagensEnviadasLista(alunoService: FakeAlunoService()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma mensagem enviada ainda.'), findsOneWidget);
    });
  });

  group('EnviarMensagemScreen', () {
    testWidgets('tem as abas Enviar e Enviadas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EnviarMensagemScreen(
            alunoService: FakeAlunoService(),
            staffAtual: _staff,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ENVIAR'), findsWidgets);
      expect(find.text('ENVIADAS'), findsOneWidget);
    });

    testWidgets('enviar guarda o nome do aluno junto da mensagem', (
      tester,
    ) async {
      const aluno = AppUser(
        uid: 'aluno-1',
        nome: 'Marcelo Teste',
        email: 'marcelo.teste@example.com',
        role: UserRole.aluno,
      );
      final service = FakeAlunoService(alunos: const [aluno]);

      await tester.pumpWidget(
        _wrap(
          EnviarMensagemScreen(
            alunoService: service,
            staffAtual: _staff,
            alunoPreSelecionado: aluno,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Mensagem'),
        'Treino novo liberado.',
      );
      // Pelo ícone, e não por widgetWithText(ElevatedButton, 'ENVIAR'):
      // ElevatedButton.icon constrói um subtipo, que byType não casa — e
      // "ENVIAR" ainda é também o nome de uma aba.
      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pumpAndSettle();

      final enviada = service.ultimaMensagemEnviada!;
      expect(enviada.texto, 'Treino novo liberado.');
      expect(enviada.alunoUid, 'aluno-1');
      expect(enviada.alunoNome, 'Marcelo Teste');
      expect(enviada.remetenteNome, 'Personal João');
    });
  });
}
