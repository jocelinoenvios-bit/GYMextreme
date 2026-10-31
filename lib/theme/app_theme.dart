import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema visual do GymExtreme: detalhes em dourado sobre fundo preto
/// (tema escuro) ou sobre fundo claro (tema claro). Os dois saem da
/// mesma montagem — só muda a paleta, ver [PaletaApp].
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _montar(PaletaApp.escura);

  static ThemeData get light => _montar(PaletaApp.clara);

  static ThemeData de(TemaApp tema) => _montar(PaletaApp.de(tema));

  /// Lê as cores da [paleta] recebida, e não de [AppColors], pra poder
  /// montar um tema sem depender de qual está ativo no momento.
  static ThemeData _montar(PaletaApp paleta) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: paleta.gold,
      brightness: paleta.brilho,
      primary: paleta.gold,
      onPrimary: const Color(0xFF0A0A0A),
      secondary: paleta.goldBright,
      onSecondary: const Color(0xFF0A0A0A),
      surface: paleta.surface,
      onSurface: paleta.textPrimary,
      error: paleta.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: paleta.brilho,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paleta.black,
      appBarTheme: AppBarTheme(
        backgroundColor: paleta.black,
        foregroundColor: paleta.gold,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: paleta.gold,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        titleLarge: TextStyle(color: paleta.textPrimary),
        bodyMedium: TextStyle(color: paleta.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paleta.surface,
        labelStyle: TextStyle(color: paleta.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleta.surfaceHigh),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleta.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleta.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: paleta.gold,
          foregroundColor: const Color(0xFF0A0A0A),
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: paleta.goldBright),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: paleta.surfaceHigh,
        contentTextStyle: TextStyle(color: paleta.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: paleta.gold),
    );
  }
}
