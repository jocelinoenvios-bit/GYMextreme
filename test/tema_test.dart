import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/theme/app_colors.dart';
import 'package:gymextreme_app/theme/app_theme.dart';
import 'package:gymextreme_app/theme/tema_controller.dart';
import 'package:gymextreme_app/widgets/texto_contornado.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // AppColors.paleta é estado global: sem restaurar, um teste que troca
  // pro claro contaminaria todos os que rodarem depois no mesmo arquivo.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.paleta = PaletaApp.escura;
  });
  tearDown(() => AppColors.paleta = PaletaApp.escura);

  group('paleta', () {
    test('AppColors acompanha a paleta ativa', () {
      expect(AppColors.black, PaletaApp.escura.black);
      expect(AppColors.textPrimary, PaletaApp.escura.textPrimary);

      AppColors.paleta = PaletaApp.clara;

      expect(AppColors.black, PaletaApp.clara.black);
      expect(AppColors.textPrimary, PaletaApp.clara.textPrimary);
    });

    test('o dourado é o mesmo nos dois temas — decisão de marca', () {
      expect(PaletaApp.clara.gold, PaletaApp.escura.gold);
    });

    test('o fundo do tema claro é claro, e o do escuro é escuro', () {
      expect(PaletaApp.clara.brilho, Brightness.light);
      expect(PaletaApp.escura.brilho, Brightness.dark);
      expect(
        PaletaApp.clara.black.computeLuminance(),
        greaterThan(PaletaApp.escura.black.computeLuminance()),
      );
    });

    test('o palco da demonstração não muda com o tema', () {
      final antes = AppColors.stage;
      AppColors.paleta = PaletaApp.clara;
      expect(AppColors.stage, antes);
    });
  });

  group('TemaController', () {
    test('trocar aponta a paleta e avisa quem escuta', () async {
      final controller = TemaController();
      var avisos = 0;
      controller.addListener(() => avisos++);

      expect(controller.tema, TemaApp.escuro);
      expect(AppColors.paleta.brilho, Brightness.dark);

      await controller.trocar(TemaApp.claro);

      expect(controller.tema, TemaApp.claro);
      expect(AppColors.paleta.brilho, Brightness.light);
      expect(avisos, 1);
    });

    test('trocar pro tema que já está ativo não avisa à toa', () async {
      final controller = TemaController();
      var avisos = 0;
      controller.addListener(() => avisos++);

      await controller.trocar(TemaApp.escuro);

      expect(avisos, 0);
    });

    test('a escolha sobrevive ao fechar o app', () async {
      await TemaController().trocar(TemaApp.claro);

      expect(await TemaController.carregarPreferencia(), TemaApp.claro);
    });

    test('sem escolha salva, abre no escuro — como o app sempre foi', () async {
      expect(await TemaController.carregarPreferencia(), TemaApp.escuro);
    });
  });

  group('AppTheme', () {
    test('monta os dois temas a partir da paleta certa', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.light.scaffoldBackgroundColor, PaletaApp.clara.black);
      expect(AppTheme.de(TemaApp.claro).brightness, Brightness.light);
    });
  });

  group('TextoContornado', () {
    testWidgets('rende um único Text — o contorno não duplica o cabeçalho', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextoContornado(
              'MEU PERFIL',
              estilo: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
      );

      // Se o contorno voltasse a ser um segundo Text por cima, isto
      // acharia dois widgets — e todo teste que procura um cabeçalho pelo
      // texto quebraria junto.
      expect(find.text('MEU PERFIL'), findsOneWidget);
    });

    testWidgets('o contorno é preto e envolve a letra por todos os lados', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextoContornado(
              'Bem-vindo',
              espessura: 2,
              estilo: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
      );

      final sombras = tester.widget<Text>(find.text('Bem-vindo')).style!.shadows!;
      expect(sombras, hasLength(8));
      expect(sombras.every((s) => s.color == AppColors.contornoTitulo), isTrue);
      // Sem desfoque: contorno de letra, não sombra projetada.
      expect(sombras.every((s) => s.blurRadius == 0), isTrue);
      for (final sombra in sombras) {
        expect(sombra.offset.distance, closeTo(2, 0.001));
      }
    });
  });
}
