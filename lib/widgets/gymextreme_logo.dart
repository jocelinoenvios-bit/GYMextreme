import 'package:flutter/material.dart';

/// Marca "GYM XTREME" completa (leao, espadas cruzadas e a palavra
/// "GYM XTREME"), usada na tela de login e na barra superior das telas
/// internas.
///
/// E um unico recorte em pixel do arquivo oficial do cliente
/// (assets/branding/logo_oficial_completo.png), com a UNICA alteracao
/// sendo a remocao do tracinho/hifen indevido entre o "X" (formado
/// pelas espadas) e "TREME" — fonte, espessura, cores, leao, espadas e
/// espacamento continuam exatamente como no arquivo aprovado pelo
/// cliente, sem nenhuma recriacao.
class GymExtremeLogo extends StatelessWidget {
  const GymExtremeLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/logo_gym_xtreme.png',
      height: compact ? 40.0 : 120.0,
      fit: BoxFit.contain,
    );
  }
}
