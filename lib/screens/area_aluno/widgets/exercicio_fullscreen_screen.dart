import 'package:flutter/material.dart';

import '../../../models/exercise_model.dart';
import '../../../theme/app_colors.dart';
import 'exercicio_media_controls.dart';

/// Tela cheia da demonstração — remove todo o chrome do app pra quem
/// quer estudar o movimento com calma antes de começar a série. Mesmo
/// palco claro e mesmos controles da tela de execução, sem nenhuma
/// distração ao redor.
class ExercicioFullscreenScreen extends StatefulWidget {
  const ExercicioFullscreenScreen({super.key, required this.exercise});

  final ExerciseModel exercise;

  @override
  State<ExercicioFullscreenScreen> createState() => _ExercicioFullscreenScreenState();
}

class _ExercicioFullscreenScreenState extends State<ExercicioFullscreenScreen>
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

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: AppColors.stage,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: MuscleLoopPlaceholder(
                    animation: _loopController,
                    reduceMotion: reduceMotion,
                    grupoMuscular: widget.exercise.grupoMuscular,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
            if (widget.exercise.temAnguloLateral)
              Positioned(
                bottom: 100,
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
              bottom: 36,
              left: 0,
              right: 0,
              child: ExecucaoControlesRow(
                tocando: _tocando,
                onTogglePlay: _alternarReproducao,
                onReiniciar: _reiniciar,
                onFullscreen: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
