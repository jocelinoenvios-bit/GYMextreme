import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marca "GYM X-TREME" em destaque, usada na tela de login e telas iniciais.
///
/// O brasao (leao dourado com espadas cruzadas) e recortado a partir do
/// logo oficial enviado pelo cliente (assets/branding/logo_leao.png).
class GymExtremeLogo extends StatelessWidget {
  const GymExtremeLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoHeight = compact ? 64.0 : 104.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/logo_leao.png',
          height: logoHeight,
          fit: BoxFit.contain,
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
