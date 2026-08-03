import 'package:flutter/material.dart';

/// Paleta de cores da marca GymExtreme: preto e amarelo/dourado.
class AppColors {
  AppColors._();

  static const Color black = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceHigh = Color(0xFF242424);

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldBright = Color(0xFFFFC72C);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB3B3B3);

  static const Color error = Color(0xFFFF5A5F);

  // Tela de execução do exercício: o "palco" da demonstração usa fundo
  // claro de propósito (mesma cor de fundo dos ativos 3D da Biblioteca de
  // Exercícios — ver lib/models/exercise_model.dart) — um card escuro por
  // trás do GIF pareceria um recorte quebrado, não uma escolha de design.
  static const Color stage = Color(0xFFF3F1EC);
  static const Color stageInk = Color(0xFF1C1A16);
  static const Color musclePrimary = Color(0xFFE0392C);
  static const Color muscleSecondary = Color(0xFFEDA24F);
}
