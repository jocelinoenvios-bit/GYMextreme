import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Fileira de controles da demonstração — sempre no terço inferior do
/// palco (zona de alcance do polegar), botões grandes o bastante pra
/// tocar com uma mão só segurando peso na outra. Reaproveitada tanto na
/// tela de execução quanto no modo tela cheia.
class ExecucaoControlesRow extends StatelessWidget {
  const ExecucaoControlesRow({
    super.key,
    required this.tocando,
    required this.onTogglePlay,
    required this.onReiniciar,
    required this.onFullscreen,
  });

  final bool tocando;
  final VoidCallback onTogglePlay;
  final VoidCallback onReiniciar;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CirculoControle(
          icone: Icons.replay_rounded,
          tamanho: 44,
          onTap: onReiniciar,
          tooltip: 'Reiniciar demonstração',
        ),
        const SizedBox(width: 14),
        _CirculoControle(
          icone: tocando ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tamanho: 56,
          destaque: true,
          onTap: onTogglePlay,
          tooltip: tocando ? 'Pausar' : 'Reproduzir',
        ),
        const SizedBox(width: 14),
        _CirculoControle(
          icone: Icons.open_in_full_rounded,
          tamanho: 44,
          onTap: onFullscreen,
          tooltip: 'Tela cheia',
        ),
      ],
    );
  }
}

class _CirculoControle extends StatelessWidget {
  const _CirculoControle({
    required this.icone,
    required this.tamanho,
    required this.onTap,
    required this.tooltip,
    this.destaque = false,
  });

  final IconData icone;
  final double tamanho;
  final VoidCallback onTap;
  final String tooltip;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: destaque ? AppColors.goldBright : Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: tamanho,
            height: tamanho,
            child: Icon(
              icone,
              color: destaque ? AppColors.black : Colors.white,
              size: tamanho * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge "ao vivo" no canto do palco, indicando que a demonstração está
/// em loop contínuo.
class LoopBadge extends StatelessWidget {
  const LoopBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: AppColors.musclePrimary, size: 7),
          SizedBox(width: 5),
          Text(
            'LOOP · BIBLIOTECA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
