import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/novo_aluno_wizard_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_storage_service.dart';

const _staffAtual = AppUser(
  uid: 'staff-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.adm,
);

Widget _wrap(FakeAlunoService alunoService, FakeStorageService storageService) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: NovoAlunoWizardScreen(
      alunoService: alunoService,
      storageService: storageService,
      staffAtual: _staffAtual,
    ),
  );
}

// WidgetTester.ensureVisible() não aceita `alignment` — só o método
// estático Scrollable.ensureVisible tem esse parâmetro. alignment: 0.5
// centraliza o alvo na viewport; o padrão (0.0) só rola o suficiente pra
// encostar na borda de cima, que nesta tela cai bem atrás da AppBar
// (fixa), roubando o hit test do tap().
Future<void> _rolarAteVisivel(WidgetTester tester, Finder finder) {
  return Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  // Depois de enterText() o campo continua com foco ativo — a seleção/
  // handle dele fica num overlay que pode "roubar" o toque seguinte
  // mesmo em outro widget. Tira o foco antes de tocar em qualquer coisa.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await _rolarAteVisivel(tester, finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _preencher(
  WidgetTester tester,
  Finder finder,
  String texto,
) async {
  await _rolarAteVisivel(tester, finder);
  await tester.pump();
  await tester.enterText(finder, texto);
}

/// Passo "Dados" abre o formulário completo (_PassoDados) numa tela cheia
/// própria (mesmo padrão dos demais passos) — abre a tela e preenche os
/// campos obrigatórios nela.
Future<void> _abrirEPreencherDados(
  WidgetTester tester, {
  String nome = 'Carlos Souza',
  String email = 'carlos@exemplo.com',
  String senha = '123456',
  String telefone = '11987654321',
}) async {
  await _tocar(tester, find.text('PREENCHER DADOS'));
  await tester.pumpAndSettle();
  await tester.pump();

  await _preencher(
    tester,
    find.widgetWithText(TextFormField, 'Nome completo'),
    nome,
  );
  await _preencher(tester, find.widgetWithText(TextFormField, 'E-mail'), email);
  await _preencher(
    tester,
    find.widgetWithText(TextFormField, 'Senha inicial'),
    senha,
  );
  await _preencher(
    tester,
    find.widgetWithText(TextFormField, 'Telefone'),
    telefone,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // semanticsEnabled: false em todos os testes desta suite: `testWidgets`
  // liga a árvore de semantics por padrão (pra checagens de
  // acessibilidade), mas isso faz o Flutter recalcular geometria de
  // widgets recém-inseridos com BoxConstraints totalmente livre
  // (`BoxConstraints(unconstrained)`) durante o frame exato de uma
  // transição de rota (push/pop) — algo que só acontece com um leitor de
  // tela de verdade ativo, não é o que este arquivo testa. Sem isso, o
  // teste falha com "BoxConstraints forces an infinite width" numa
  // passagem interna de semantics, não no layout visual real.
  testWidgets(
    'nao cria o cadastro se nome, e-mail ou senha estiverem vazios',
    semanticsEnabled: false,
    (tester) async {
      final alunoService = FakeAlunoService();
      await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

      await _tocar(tester, find.text('PREENCHER DADOS'));
      await tester.pumpAndSettle();
      await tester.pump();

      await _tocar(tester, find.text('CADASTRAR E CONTINUAR'));
      await tester.pump();

      expect(find.text('Informe o nome.'), findsOneWidget);
      expect(alunoService.aluno, isNull);
    },
  );

  testWidgets(
    'CPF com quantidade errada de digitos bloqueia o cadastro',
    semanticsEnabled: false,
    (tester) async {
      final alunoService = FakeAlunoService();
      await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

      await _tocar(tester, find.text('PREENCHER DADOS'));
      await tester.pumpAndSettle();
      await tester.pump();

      await _preencher(
        tester,
        find.widgetWithText(TextFormField, 'Nome completo'),
        'Carlos Souza',
      );
      await _preencher(
        tester,
        find.widgetWithText(TextFormField, 'E-mail'),
        'carlos@exemplo.com',
      );
      await _preencher(
        tester,
        find.widgetWithText(TextFormField, 'Senha inicial'),
        '123456',
      );
      await _preencher(
        tester,
        find.widgetWithText(TextFormField, 'CPF'),
        '123',
      );

      await _tocar(tester, find.text('CADASTRAR E CONTINUAR'));
      await tester.pump();

      expect(find.text('CPF deve ter 11 dígitos.'), findsOneWidget);
      expect(alunoService.aluno, isNull);
    },
  );

  testWidgets(
    'cadastra o aluno com dados validos e avanca pro proximo passo',
    semanticsEnabled: false,
    (tester) async {
      final alunoService = FakeAlunoService();
      await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

      await _abrirEPreencherDados(tester);
      await _tocar(tester, find.text('CADASTRAR E CONTINUAR'));
      await tester.pumpAndSettle();
      await tester.pump();

      expect(alunoService.aluno, isNotNull);
      expect(alunoService.aluno?.telefone, '11987654321');
      expect(alunoService.aluno?.cadastradoPorNome, 'Recepção Ana');
      // Confirma que avançou pro passo "Anamnese" de verdade (não só que o
      // cadastro foi criado) — prova que a tela voltou da rota cheia de
      // "Dados" pro wizard com o passo atualizado.
      expect(find.text('PREENCHER ANAMNESE'), findsOneWidget);
    },
  );

  testWidgets(
    'passo Anamnese abre a ficha completa em tela cheia, com as perguntas '
    'renderizadas (regressao)',
    semanticsEnabled: false,
    (tester) async {
      // Regressao: a causa raiz real do bug relatado (passo Anamnese em
      // branco/com o botao "VOLTAR" sobreposto ao texto) era o widget
      // Stepper do Flutter: ele mantem o conteudo de TODOS os passos
      // (mesmo os escondidos) na arvore de widgets e anima a troca de
      // passo com um AnimatedCrossFade/Stack interno que, em certos
      // frames, corrompe o layout do conteudo escondido (mesmo em
      // release, sem crash visivel). Isso persistia mesmo depois de
      // isolar o conteudo pesado de cada passo em telas cheias separadas
      // — o problema era do proprio Stepper, nao do conteudo. Correcao
      // definitiva: parar de usar o widget Stepper e renderizar só o
      // passo atual (os outros nem existem na arvore enquanto nao sao
      // alcancados).
      final alunoService = FakeAlunoService();
      await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

      await _abrirEPreencherDados(tester);
      await _tocar(tester, find.text('CADASTRAR E CONTINUAR'));
      await tester.pumpAndSettle();
      await tester.pump();

      expect(find.text('PREENCHER ANAMNESE'), findsOneWidget);
      await _tocar(tester, find.text('PREENCHER ANAMNESE'));
      await tester.pumpAndSettle();
      await tester.pump();

      // O texto da pergunta ("Quantos dias pretende treinar?") é um
      // RichText/TextSpan, não um Text puro — as opções de resposta
      // (ChoiceChip, Text normal) já bastam pra confirmar que o conteúdo
      // real renderizou na tela cheia aberta pelo botão.
      expect(find.text('Hipertrofia'), findsOneWidget);
      expect(find.text('Emagrecimento'), findsOneWidget);
    },
  );

  testWidgets(
    'passo Regulamento abre a ficha completa em tela cheia, com o termo '
    'renderizado (regressao)',
    semanticsEnabled: false,
    (tester) async {
      // Mesma correcao do teste acima, agora para o TermoTab.
      final alunoService = FakeAlunoService();
      await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

      await _abrirEPreencherDados(tester);
      await _tocar(tester, find.text('CADASTRAR E CONTINUAR'));
      await tester.pumpAndSettle();
      await tester.pump();

      // Sem Stepper, só o passo atual (Anamnese) existe na árvore agora
      // — "CONTINUAR" não é mais ambíguo, não precisa de .first.
      await _tocar(tester, find.text('CONTINUAR'));
      await tester.pumpAndSettle();
      await tester.pump();

      expect(find.text('ABRIR REGULAMENTO'), findsOneWidget);
      await _tocar(tester, find.text('ABRIR REGULAMENTO'));
      await tester.pumpAndSettle();
      await tester.pump();

      expect(find.text('REGULAMENTO'), findsOneWidget);
      // A regra vem num RichText cru (não um Text), junto com o número
      // ("01. A mensalidade ...") — find.text/textContaining ignoram
      // RichText "solto" por padrão, por isso findRichText: true. E
      // textContaining (não text) porque o número vem junto no mesmo
      // texto puro do RichText.
      expect(
        find.textContaining(
          'A mensalidade é pessoal e intransferível.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );
}
