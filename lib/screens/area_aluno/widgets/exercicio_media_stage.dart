import 'package:flutter/material.dart';

import '../../../models/exercise_model.dart';
import '../../../services/gif_cache_service.dart';
import '../../../theme/app_colors.dart';
import 'exercicio_fullscreen_screen.dart';
import 'exercicio_media_controls.dart';
import 'exercicio_midia.dart';

/// O "palco" da demonstração — elemento dominante da tela de execução.
/// Fundo claro de propósito (ver [AppColors.stage]): é a mesma cor de
/// fundo dos ativos 3D reais da Biblioteca de Exercícios, então um card
/// escuro por trás pareceria um recorte quebrado, não uma escolha.
///
/// Renderiza o vídeo da Vital Animations (`ExerciseModel.videoUrl`)
/// quando existir — mídia primária, qualidade superior ao GIF — com
/// fallback automático pro GIF oficial (`gif360Url`) quando não há
/// vídeo ou ele falha ao carregar (ver `ExercicioMidia`). A troca nunca
/// aparece como opção pro aluno.
class ExercicioMediaStage extends StatefulWidget {
  const ExercicioMediaStage({super.key, required this.exercise, this.gifCacheService});

  final ExerciseModel exercise;

  /// Injetável pra teste (`FakeGifCacheService`) — em produção usa o
  /// padrão de `ExercicioMidia` (`FirebaseGifCacheService()`). Também
  /// repassado pro `ExercicioFullscreenScreen` aberto a partir daqui.
  final GifCacheService? gifCacheService;

  @override
  State<ExercicioMediaStage> createState() => _ExercicioMediaStageState();
}

class _ExercicioMediaStageState extends State<ExercicioMediaStage> {
  late final ExercicioMidiaController _midiaController;

  @override
  void initState() {
    super.initState();
    // Mesma fonte que MediaQuery.of(context).disableAnimations usa por
    // baixo — segura de ler aqui porque não depende de um BuildContext
    // já anexado à árvore (ao contrário de MediaQuery.of, que não pode
    // ser chamado dentro de initState).
    _midiaController = ExercicioMidiaController(
      tocandoInicial: !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations,
    );
  }

  @override
  void didUpdateWidget(covariant ExercicioMediaStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      _midiaController.redefinir(tocandoInicial: !reduceMotion);
    }
  }

  @override
  void dispose() {
    _midiaController.dispose();
    super.dispose();
  }

  void _abrirFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExercicioFullscreenScreen(
          exercise: widget.exercise,
          gifCacheService: widget.gifCacheService,
        ),
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
        // StackFit.expand: cada filho não-posicionado (a mídia) recebe
        // constraints TIGHT batendo com os 300px do Container, sem
        // ambiguidade nenhuma sobre o tamanho — troca definitiva do
        // InteractiveViewer (zoom/pinça), que ficou confirmado como a
        // causa raiz de a mídia nunca chegar a desenhar nada nesta tela
        // num aparelho físico real (RepaintBoundary não resolveu; o
        // vídeo prova funcionar perfeitamente na mesma estrutura simples
        // usada pela Biblioteca de Exercícios, sem InteractiveViewer).
        // Sacrifica o zoom aqui — a demonstração continua sempre visível,
        // que é o que importa.
        fit: StackFit.expand,
        children: [
          ExercicioMidia(
            key: ValueKey(widget.exercise.id),
            exercise: widget.exercise,
            controller: _midiaController,
            fit: BoxFit.contain,
            reduceMotion: reduceMotion,
            gifCacheService: widget.gifCacheService,
          ),
          const Positioned(top: 14, left: 14, child: LoopBadge()),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: ListenableBuilder(
              listenable: _midiaController,
              builder: (context, _) => ExecucaoControlesRow(
                tocando: _midiaController.tocando,
                onTogglePlay: _midiaController.alternar,
                onReiniciar: _midiaController.reiniciar,
                onFullscreen: _abrirFullscreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
