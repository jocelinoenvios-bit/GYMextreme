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

/// Seletor "Frontal / Lateral" sobreposto ao palco — só aparece quando
/// `ExerciseModel.temAnguloLateral` é verdadeiro.
class AnguloSelector extends StatelessWidget {
  const AnguloSelector({super.key, required this.lateral, required this.onChanged});

  final bool lateral;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _opcao(context, 'Frontal', !lateral, () => onChanged(false)),
          _opcao(context, 'Lateral', lateral, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _opcao(BuildContext context, String label, bool selecionado, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selecionado ? AppColors.stageInk : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Representação abstrata do grupo muscular trabalhado, no lugar do GIF
/// real (que ainda não existe — `ExerciseModel.gifUrl` é só um valor
/// mock). Deliberadamente não tenta imitar uma figura anatômica de
/// verdade; é só um espaço reservado honesto, com o mesmo destaque em
/// vermelho que os ativos reais da Biblioteca usam pro músculo
/// trabalhado.
class MuscleLoopPlaceholder extends StatelessWidget {
  const MuscleLoopPlaceholder({
    super.key,
    required this.animation,
    required this.reduceMotion,
    required this.grupoMuscular,
  });

  final Animation<double> animation;
  final bool reduceMotion;
  final String grupoMuscular;

  @override
  Widget build(BuildContext context) {
    final pulso = reduceMotion
        ? const AlwaysStoppedAnimation<double>(0.8)
        : Tween<double>(begin: 0.55, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: pulso,
                child: Container(
                  width: 90,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.musclePrimary.withValues(alpha: 0.55),
                        AppColors.musclePrimary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.accessibility_new_rounded,
                size: 150,
                color: AppColors.stageInk.withValues(alpha: 0.28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          grupoMuscular,
          style: const TextStyle(
            color: AppColors.stageInk,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          'pré-visualização · asset real na integração',
          style: TextStyle(
            color: AppColors.stageInk.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
