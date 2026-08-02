import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marca "GymExtreme" em destaque, usada na tela de login e telas iniciais.
///
/// Provisoria ate o logo oficial do cliente (leao dourado) ser aplicado
/// como asset de imagem no lugar do icone generico abaixo.
class GymExtremeLogo extends StatelessWidget {
  const GymExtremeLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 40.0 : 64.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize + 24,
          height: iconSize + 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Icon(
            Icons.fitness_center,
            color: AppColors.gold,
            size: iconSize,
          ),
        ),
        SizedBox(height: compact ? 8 : 16),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: compact ? 22 : 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
            children: const [
              TextSpan(
                text: 'GYM ',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              TextSpan(
                text: 'X-TREME',
                style: TextStyle(color: AppColors.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
