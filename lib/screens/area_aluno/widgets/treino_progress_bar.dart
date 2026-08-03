import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Progresso geral da sessão — soma de séries concluídas em todos os
/// exercícios, não só o exercício atual. Fica logo abaixo da barra de
/// navegação, sempre visível.
class TreinoProgressBar extends StatelessWidget {
  const TreinoProgressBar({
    super.key,
    required this.exercicioAtual,
    required this.totalExercicios,
    required this.progresso,
  });

  /// Posição do exercício atual (1-based).
  final int exercicioAtual;
  final int totalExercicios;

  /// Fração (0 a 1) de séries concluídas na sessão inteira.
  final double progresso;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Exercício $exercicioAtual de $totalExercicios',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progresso.clamp(0, 1) * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progresso.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}
