import 'package:flutter/material.dart';

/// Os dois temas disponíveis. A escolha fica salva no aparelho (ver
/// `TemaController`) — não é por aluno/academia, é preferência de quem
/// está usando.
enum TemaApp { escuro, claro }

/// Uma paleta completa. Cada campo aqui tem um equivalente em
/// [AppColors]; trocar a paleta ativa troca o app inteiro de tema.
class PaletaApp {
  const PaletaApp({
    required this.brilho,
    required this.black,
    required this.surface,
    required this.surfaceHigh,
    required this.gold,
    required this.goldBright,
    required this.textPrimary,
    required this.textSecondary,
    required this.error,
  });

  final Brightness brilho;

  /// Fundo da tela. No tema claro é um branco levemente quente, que
  /// combina melhor com o dourado da marca do que branco puro.
  final Color black;
  final Color surface;
  final Color surfaceHigh;

  final Color gold;
  final Color goldBright;

  final Color textPrimary;
  final Color textSecondary;

  final Color error;

  static const escura = PaletaApp(
    brilho: Brightness.dark,
    black: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    surfaceHigh: Color(0xFF242424),
    gold: Color(0xFFD4AF37),
    goldBright: Color(0xFFFFC72C),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB3B3B3),
    error: Color(0xFFFF5A5F),
  );

  /// O dourado é exatamente o mesmo do tema escuro, por decisão de marca.
  /// Em fundo claro ele funciona bem como preenchimento (botões, ícones),
  /// mas some como texto — por isso os títulos amarelos usam
  /// `TextoContornado`, com contorno preto, em vez de um dourado mais
  /// fechado.
  static const clara = PaletaApp(
    brilho: Brightness.light,
    black: Color(0xFFF7F6F3),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEFEDE7),
    gold: Color(0xFFD4AF37),
    goldBright: Color(0xFFC9A227),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B6B6B),
    error: Color(0xFFD32F2F),
  );

  static PaletaApp de(TemaApp tema) =>
      tema == TemaApp.claro ? clara : escura;
}

/// Paleta de cores da marca GymExtreme: preto e amarelo/dourado.
///
/// Os campos deixaram de ser `const` quando o tema claro entrou: agora
/// cada um lê a paleta ativa ([paleta]), trocada por `TemaController`
/// antes de reconstruir a árvore. Por isso nada aqui pode voltar a ser
/// `const` — um `const Text(style: TextStyle(color: AppColors.gold))`
/// congelaria a cor do tema que estava ativo na primeira build.
class AppColors {
  AppColors._();

  /// Paleta ativa. Só `TemaController` troca isso, e sempre junto de um
  /// rebuild — ler direto daqui em qualquer outro lugar é seguro.
  static PaletaApp paleta = PaletaApp.escura;

  static Color get black => paleta.black;
  static Color get surface => paleta.surface;
  static Color get surfaceHigh => paleta.surfaceHigh;

  static Color get gold => paleta.gold;
  static Color get goldBright => paleta.goldBright;

  static Color get textPrimary => paleta.textPrimary;
  static Color get textSecondary => paleta.textSecondary;

  static Color get error => paleta.error;

  /// Contorno dos títulos amarelos ([TextoContornado]) — preto nos dois
  /// temas de propósito: no escuro ele some no fundo e a tela fica
  /// idêntica à de antes do tema claro existir; no claro é ele que dá
  /// legibilidade ao dourado. Mesma solução usada no logo.
  static const Color contornoTitulo = Color(0xFF0A0A0A);

  // Tela de execução do exercício: o "palco" da demonstração usa fundo
  // claro de propósito (mesma cor de fundo dos ativos 3D da Biblioteca de
  // Exercícios — ver lib/models/exercise_model.dart) — um card escuro por
  // trás do GIF pareceria um recorte quebrado, não uma escolha de design.
  // Não muda com o tema: o palco acompanha a mídia, não a interface.
  static const Color stage = Color(0xFFF3F1EC);
  static const Color stageInk = Color(0xFF1C1A16);
  static const Color musclePrimary = Color(0xFFE0392C);
  static const Color muscleSecondary = Color(0xFFEDA24F);
}
