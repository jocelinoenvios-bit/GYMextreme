import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/area_aluno/meu_perfil_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/meus_dados_aluno_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/minha_anamnese_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/minha_evolucao_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/minha_ficha_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/minhas_medidas_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

const _usuario = AppUser(
  uid: 'aluno-1',
  nome: 'Ana Teste',
  email: 'ana@teste.com',
  role: UserRole.aluno,
);

Widget _wrap(FakeAlunoService service) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: MeuPerfilScreen(usuario: _usuario, uid: 'aluno-1', alunoService: service),
  );
}

void main() {
  group('MeuPerfilScreen', () {
    testWidgets('lista os 5 itens do hub', (tester) async {
      await tester.pumpWidget(_wrap(FakeAlunoService()));
      await tester.pump();

      expect(find.text('Dados pessoais'), findsOneWidget);
      expect(find.text('Minha ficha'), findsOneWidget);
      expect(find.text('Minhas medidas'), findsOneWidget);
      expect(find.text('Minha anamnese'), findsOneWidget);
      expect(find.text('Minha evolução'), findsOneWidget);
    });

    // Cada caso roda no seu próprio testWidgets (tester próprio) — reusar
    // um único tester num loop deixaria o Navigator com a tela anterior
    // ainda empilhada (pumpWidget de novo não reseta a pilha de rotas
    // sozinho), então o 2º toque em diante nunca acharia o item na tela.
    for (final caso in [
      ('Dados pessoais', MeusDadosAlunoScreen),
      ('Minha ficha', MinhaFichaScreen),
      ('Minhas medidas', MinhasMedidasScreen),
      ('Minha anamnese', MinhaAnamneseScreen),
      ('Minha evolução', MinhaEvolucaoScreen),
    ]) {
      testWidgets('tocar em "${caso.$1}" navega pra tela correspondente', (tester) async {
        await tester.pumpWidget(_wrap(FakeAlunoService()));
        await tester.pump();

        await tester.tap(find.text(caso.$1));
        await tester.pumpAndSettle();

        expect(find.byType(caso.$2), findsOneWidget);
      });
    }
  });
}
