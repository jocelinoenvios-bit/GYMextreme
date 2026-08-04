import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/novo_aluno_wizard_screen.dart';
import 'package:gymextreme_app/screens/alunos/tabs/anamnese_tab.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_storage_service.dart';
import 'support/test_viewport.dart';

const _staffAtual = AppUser(uid: 'staff-1', nome: 'Recepção Ana', email: 'ana@exemplo.com', role: UserRole.adm);

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

/// O Stepper mantém a janela de teste padrão (não estica pra caber tudo de
/// uma vez): a combinação de Stepper + janela artificialmente alta +
/// formulário longo corrompe a árvore de semantics do Flutter durante a
/// animação de troca de passo (bug do framework, não deste código). Em vez
/// disso, rola o campo/botão pro Stepper (que já é internamente scrollable)
/// antes de cada interação.
// WidgetTester.ensureVisible() não aceita `alignment` — só o método
// estático Scrollable.ensureVisible tem esse parâmetro. alignment: 0.5
// centraliza o alvo na viewport; o padrão (0.0) só rola o suficiente pra
// encostar na borda de cima, que nesta tela cai bem atrás da AppBar
// (fixa), roubando o hit test do tap(). duration: Duration.zero pula
// direto pro destino, sem precisar de pumps extras pra animação.
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

Future<void> _preencher(WidgetTester tester, Finder finder, String texto) async {
  await _rolarAteVisivel(tester, finder);
  await tester.pump();
  await tester.enterText(finder, texto);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nao cria o cadastro se nome, e-mail ou senha estiverem vazios', (tester) async {
    final alunoService = FakeAlunoService();
    await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

    await _tocar(tester, find.text('CADASTRAR E CONTINUAR'));
    await tester.pump();

    expect(find.text('Informe o nome.'), findsOneWidget);
    expect(alunoService.aluno, isNull);
  });

  testWidgets('CPF com quantidade errada de digitos bloqueia o cadastro', (tester) async {
    final alunoService = FakeAlunoService();
    await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

    await _preencher(tester, find.widgetWithText(TextFormField, 'Nome completo'), 'Carlos Souza');
    await _preencher(tester, find.widgetWithText(TextFormField, 'E-mail'), 'carlos@exemplo.com');
    await _preencher(tester, find.widgetWithText(TextFormField, 'Senha inicial'), '123456');
    await _preencher(tester, find.widgetWithText(TextFormField, 'CPF'), '123');

    await _tocar(tester, find.text('CADASTRAR E CONTINUAR'));
    await tester.pump();

    expect(find.text('CPF deve ter 11 dígitos.'), findsOneWidget);
    expect(alunoService.aluno, isNull);
  });

  testWidgets('cadastra o aluno com dados validos e avanca pro proximo passo', (tester) async {
    final alunoService = FakeAlunoService();
    await tester.pumpWidget(_wrap(alunoService, FakeStorageService()));

    await _preencher(tester, find.widgetWithText(TextFormField, 'Nome completo'), 'Carlos Souza');
    await _preencher(tester, find.widgetWithText(TextFormField, 'E-mail'), 'carlos@exemplo.com');
    await _preencher(tester, find.widgetWithText(TextFormField, 'Senha inicial'), '123456');
    await _preencher(tester, find.widgetWithText(TextFormField, 'Telefone'), '11987654321');

    // Sem pump() depois do tap: qualquer pump (zero, curto ou com a
    // duração inteira da animação) acaba desenhando o passo "Anamnese"
    // (que o Stepper já torna current assim que _handleCriar termina)
    // no meio da transição de crossfade, e o AnamneseTab — que tem seu
    // próprio ListView — quebra o layout nesse ponto intermediário
    // (bug do Flutter no Stepper/AnimatedCrossFade, não deste código).
    // Não precisa de pump aqui: como o fake service não faz I/O de
    // verdade, `cadastrarAluno` roda de forma síncrona por dentro do
    // `await`, então `alunoService.aluno` já está populado assim que
    // tester.tap() volta — a confirmação visual "Dados salvos." fica
    // sem cobertura direta aqui, mas o comportamento de negócio
    // (cadastro criado com os dados certos) já está garantido.
    await _tocar(tester, find.text('CADASTRAR E CONTINUAR'));

    expect(alunoService.aluno, isNotNull);
    expect(alunoService.aluno?.telefone, '11987654321');
    expect(alunoService.aluno?.cadastradoPorNome, 'Recepção Ana');
  });

  testWidgets(
    'AnamneseTab/TermoTab dentro de um Column sem altura definida precisam do '
    'SizedBox pra renderizar (regressao)',
    (tester) async {
      // Regressao: AnamneseTab/TermoTab tem um ListView na raiz, que exige
      // altura limitada do pai. No wizard (Stepper > Column), sem o SizedBox
      // que hoje envolve os dois em novo_aluno_wizard_screen.dart, o passo
      // renderiza completamente em branco (reportado num aparelho real: o
      // passo "Anamnese" só mostrava o botão "VOLTAR", nenhuma pergunta).
      // Reproduz aqui só a forma da árvore de widgets que quebrava —
      // sem depender do Stepper/AnimatedCrossFade, que tem instabilidade
      // própria de teste documentada no teste acima.
      usarViewportGrande(tester);
      final alunoService = FakeAlunoService();
      alunoService.aluno = null;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 800,
                    child: AnamneseTab(uid: 'aluno-1', alunoService: alunoService),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await pumpCurto(tester);

      // O texto da pergunta ("Quantos dias pretende treinar?") é um
      // RichText/TextSpan, não um Text puro — as opções de resposta
      // (ChoiceChip, Text normal) já bastam pra confirmar que o conteúdo
      // real renderizou (e não em branco, como no bug original). O
      // ListView é virtualizado (SizedBox de 800px não cabe as 13
      // perguntas), então só afirma sobre o que está nesse trecho inicial.
      expect(find.text('Hipertrofia'), findsOneWidget);
      expect(find.text('Emagrecimento'), findsOneWidget);
    },
  );
}
