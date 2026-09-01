import 'package:flutter/material.dart';

import '../../../models/exercise_model.dart';
import '../../../services/gif_cache_service.dart';
import '../../../theme/app_colors.dart';
import 'exercicio_media_controls.dart';
import 'exercicio_midia.dart';

/// Tela cheia da demonstração — remove todo o chrome do app pra quem
/// quer estudar o movimento com calma antes de começar a série. Mesmo
/// palco claro e mesmos controles da tela de execução, sem nenhuma
/// distração ao redor.
///
/// Mesma prioridade vídeo-primeiro/GIF-fallback do palco principal (ver
/// `ExercicioMidia`), usando `gif360Url` quando cai pro GIF — a única
/// variante hospedada, e a que mais se beneficia do zoom (até 4x) daqui.
/// A troca nunca é uma escolha exposta ao aluno.
class ExercicioFullscreenScreen extends StatefulWidget {
  const ExercicioFullscreenScreen({super.key, required this.exercise, this.gifCacheService});

  final ExerciseModel exercise;

  /// Injetável pra teste (`FakeGifCacheService`) — em produção usa o
  /// padrão de `ExercicioMidia` (`FirebaseGifCacheService()`).
  final GifCacheService? gifCacheService;

  @override
  State<ExercicioFullscreenScreen> createState() => _ExercicioFullscreenScreenState();
}

class _ExercicioFullscreenScreenState extends State<ExercicioFullscreenScreen> {
  late final ExercicioMidiaController _midiaController;

  @override
  void initState() {
    super.initState();
    _midiaController = ExercicioMidiaController(
      tocandoInicial: !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations,
    );
  }

  @override
  void dispose() {
    _midiaController.dispose();
    super.dispose();
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
                  child: ExercicioMidia(
                    exercise: widget.exercise,
                    controller: _midiaController,
                    fit: BoxFit.contain,
                    reduceMotion: reduceMotion,
                    gifCacheService: widget.gifCacheService,
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
              child: ListenableBuilder(
                listenable: _midiaController,
                builder: (context, _) => ExecucaoControlesRow(
                  tocando: _midiaController.tocando,
                  onTogglePlay: _midiaController.alternar,
                  onReiniciar: _midiaController.reiniciar,
                  onFullscreen: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
