import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Título amarelo com contorno preto, usado nos cabeçalhos do app.
///
/// Existe por causa do tema claro: o dourado da marca ([AppColors.gold])
/// funciona bem como preenchimento (botões, ícones), mas como texto
/// sobre fundo claro ele quase some. O contorno resolve isso sem mudar a
/// cor da marca.
///
/// O contorno é preto nos dois temas de propósito — no escuro ele se
/// confunde com o fundo e a tela fica igual à de antes do tema claro
/// existir, então não há dois caminhos de renderização pra manter.
/// Mesma solução usada no logo.
///
/// O contorno sai de sombras sem desfoque espalhadas em volta da letra,
/// e não de um segundo [Text] por cima com `PaintingStyle.stroke`: o
/// jeito do stroke exige desenhar o texto duas vezes, o que duplicaria
/// cada cabeçalho na árvore de widgets — leitor de tela lendo tudo em
/// dobro, e `find.text` achando dois widgets onde a tela mostra um.
class TextoContornado extends StatelessWidget {
  const TextoContornado(
    this.texto, {
    super.key,
    required this.estilo,
    this.espessura = 1.8,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String texto;

  /// Estilo do preenchimento. A cor dele é a cor final do texto; o
  /// contorno sempre usa [AppColors.contornoTitulo].
  final TextStyle estilo;

  /// Raio do contorno, em pixels lógicos. Acima de ~2 em texto pequeno
  /// o contorno começa a fechar os vãos das letras.
  final double espessura;

  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Oito cópias em volta: menos que isso deixa falhas nas diagonais,
  /// mais que isso não muda nada visível.
  static List<Shadow> _contorno(double raio, Color cor) {
    const lados = 8;
    return [
      for (var i = 0; i < lados; i++)
        Shadow(
          offset: Offset(
            raio * math.cos(2 * math.pi * i / lados),
            raio * math.sin(2 * math.pi * i / lados),
          ),
          color: cor,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: estilo.copyWith(
        shadows: _contorno(espessura, AppColors.contornoTitulo),
      ),
    );
  }
}
