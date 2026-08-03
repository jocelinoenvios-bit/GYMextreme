import 'package:flutter/material.dart';

import '../../../models/exercise_model.dart';
import '../../../theme/app_colors.dart';
import 'exercicio_fullscreen_screen.dart';
import 'exercicio_media_controls.dart';

/// O "palco" da demonstração — elemento dominante da tela de execução.
/// Fundo claro de propósito (ver [AppColors.stage]): é a mesma cor de
/// fundo dos ativos 3D reais da Biblioteca de Exercícios, então um card
/// escuro por trás pareceria um recorte quebrado, não uma escolha.
///
/// Hoje renderiza [MuscleLoopPlaceholder] porque os arquivos de GIF
/// reais (`ExerciseModel.gif180Url`) ainda não existem no projeto — só
/// o caminho está resolvido. Quando os arquivos forem adicionados,
/// troca-se aqui por um player de verdade (ex.: pacote `gif`, que dá
/// play/pause de verdade), sem mexer no resto da tela.
class ExercicioMediaStage extends StatefulWidget {
  const ExercicioMediaStage({super.key, required this.exercise});

  final ExerciseModel exercise;

  @override
  State<ExercicioMediaStage> createState() => _ExercicioMediaStageState();
}

class _ExercicioMediaStageState extends State<ExercicioMediaStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loopController;
  bool _tocando = true;
  bool _anguloLateral = false;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ExercicioMediaStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) {
      _anguloLateral = false;
      _tocando = true;
      _loopController
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  void _alternarReproducao() {
    setState(() {
      _tocando = !_tocando;
      _tocando ? _loopController.repeat(reverse: true) : _loopController.stop();
    });
  }

  void _reiniciar() {
    _loopController.reset();
    if (_tocando) _loopController.repeat(reverse: true);
  }

  void _abrirFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExercicioFullscreenScreen(exercise: widget.exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      height: 300,
      width: double.infinity,
      color: AppColors.stage,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 3,
              child: Center(
                child: MuscleLoopPlaceholder(
                  animation: _loopController,
                  reduceMotion: reduceMotion,
                  grupoMuscular: widget.exercise.grupoMuscular,
                ),
              ),
            ),
          ),
          const Positioned(top: 14, left: 14, child: LoopBadge()),
          if (widget.exercise.temAnguloAlternativo)
            Positioned(
              bottom: 66,
              left: 0,
              right: 0,
              child: Center(
                child: AnguloSelector(
                  lateral: _anguloLateral,
                  onChanged: (lateral) => setState(() => _anguloLateral = lateral),
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: ExecucaoControlesRow(
              tocando: _tocando,
              onTogglePlay: _alternarReproducao,
              onReiniciar: _reiniciar,
              onFullscreen: _abrirFullscreen,
            ),
          ),
        ],
      ),
    );
  }
}
