import 'package:flutter/material.dart';

import '../widgets/premium.dart';
import 'app_colors.dart';

/// Tema visual do GymExtreme — o visual "premium": fundo preto com a faixa
/// dourada no rodapé, botões em degradê dourado com brilho, cards escuros
/// com brilho dourado embaixo.
///
/// Quase tudo que o app tem de visual passa por aqui, de propósito: assim
/// todas as telas ficam premium sem cada uma precisar se estilizar.
class AppTheme {
  AppTheme._();

  static const _glowTexto = [Shadow(color: Color(0x80FFC72C), blurRadius: 8)];

  static const _cardEscuro = Color(0xFF151515);
  static const _campo = Color(0xFF141414);
  static const _bordaEscura = Color(0xFF2A2A2A);

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: OuroPremium.tinta,
      secondary: AppColors.goldBright,
      onSecondary: OuroPremium.tinta,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      // Transparente: o fundo (preto + faixa dourada) é pintado por
      // FundoPremium, por trás de cada página — ver TransicaoPremium.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: const Color(0xFF161616),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TransicaoPremium(
            ZoomPageTransitionsBuilder(),
          ),
          TargetPlatform.iOS: TransicaoPremium(
            CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.macOS: TransicaoPremium(
            CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.linux: TransicaoPremium(ZoomPageTransitionsBuilder()),
          TargetPlatform.windows: TransicaoPremium(
            ZoomPageTransitionsBuilder(),
          ),
          TargetPlatform.fuchsia: TransicaoPremium(
            ZoomPageTransitionsBuilder(),
          ),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: OuroPremium.texto,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: OuroPremium.texto,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          shadows: _glowTexto,
        ),
        iconTheme: IconThemeData(color: OuroPremium.texto, shadows: _glowTexto),
        actionsIconTheme: IconThemeData(
          color: OuroPremium.texto,
          shadows: _glowTexto,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: OuroPremium.texto,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
        titleLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _campo,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: OuroPremium.texto),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _bordaEscura),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OuroPremium.texto, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // O degradê vem do backgroundBuilder; a cor de fundo fica
          // transparente pra não aparecer por trás dele.
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: OuroPremium.tinta,
          disabledForegroundColor: AppColors.textSecondary,
          shadowColor: const Color(0xCCFFBE28),
          elevation: 6,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundBuilder: (context, states, child) {
            final desabilitado = states.contains(WidgetState.disabled);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: desabilitado ? null : OuroPremium.degrade,
                color: desabilitado ? const Color(0xFF2A2A2A) : null,
              ),
              child: child,
            );
          },
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OuroPremium.texto,
          side: const BorderSide(color: OuroPremium.texto, width: 1.4),
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldBright,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: OuroPremium.medio,
        foregroundColor: OuroPremium.tinta,
        elevation: 8,
        extendedTextStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      cardTheme: CardThemeData(
        color: _cardEscuro,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x99FFBE28),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _bordaEscura),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: OuroPremium.texto,
        textColor: AppColors.textPrimary,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: OuroPremium.texto,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: OuroPremium.texto,
        dividerColor: Color(0xFF222222),
        labelStyle: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF161616),
        selectedColor: Color(0x40F5C02A),
        side: BorderSide(color: _bordaEscura),
        checkmarkColor: OuroPremium.texto,
        labelStyle: TextStyle(color: AppColors.textPrimary),
        shape: StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF141414),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: OuroPremium.texto,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x40F5C02A)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF141414),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          side: BorderSide(color: Color(0x40F5C02A)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF161616),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _bordaEscura),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1C1C1C),
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        actionTextColor: OuroPremium.texto,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x40F5C02A)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF232323)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? OuroPremium.tinta
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? OuroPremium.medio
              : const Color(0xFF2A2A2A),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? OuroPremium.medio : null,
        ),
        checkColor: const WidgetStatePropertyAll(OuroPremium.tinta),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? OuroPremium.medio
              : AppColors.textSecondary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: OuroPremium.texto,
      ),
    );
  }
}
