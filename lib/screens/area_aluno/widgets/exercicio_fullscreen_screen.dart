import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

import '../../../models/exercise_model.dart';
import '../../../theme/app_colors.dart';
import 'exercicio_media_controls.dart';

/// Tela cheia da demonstração — remove todo o chrome do app pra quem
/// quer estudar o movimento com calma antes de começar a série. Mesmo
/// palco claro e mesmos controles da tela de execução, sem nenhuma
/// distração ao redor.
///
/// Usa `ExerciseModel.gif360Url` (em vez do `gif180Url` do palco
/// principal) — a variante de maior resolução fica reservada
/// automaticamente pra cá, onde o zoom (até 4x) mais se beneficia dela.
/// A troca nunca é uma escolha exposta ao aluno.
class ExercicioFullscreenScreen extends StatefulWidget {
  const ExercicioFullscreenScreen({super.key, required this.exercise});

  final ExerciseModel exercise;

  @override
  State<ExercicioFullscreenScreen> createState() => _ExercicioFullscreenScreenState();
}

class _ExercicioFullscreenScreenState extends State<ExercicioFullscreenScreen>
    with SingleTickerProviderStateMixin {
  late final GifController _loopController;
  late bool _tocando;

  @override
  void initState() {
    super.initState();
    _loopController = GifController(vsync: this);
    _tocando = !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  void _alternarReproducao() {
    setState(() {
      _tocando = !_tocando;
      _tocando ? _loopController.repeat() : _loopController.stop();
    });
  }

  void _reiniciar() {
    _loopController.reset();
    if (_tocando) _loopController.repeat();
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
                  child: Gif(
                    image: AssetImage(widget.exercise.gif360Url ?? widget.exercise.gif180Url),
                    controller: _loopController,
                    autostart: reduceMotion ? Autostart.no : Autostart.loop,
                    fit: BoxFit.contain,
                    placeholder: (_) => const Center(child: CircularProgressIndicator()),
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
