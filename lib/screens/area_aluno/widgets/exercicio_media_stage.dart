import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

import '../../../models/exercise_model.dart';
import '../../../theme/app_colors.dart';
import 'exercicio_fullscreen_screen.dart';
import 'exercicio_media_controls.dart';

/// O "palco" da demonstração — elemento dominante da tela de execução.
/// Fundo claro de propósito (ver [AppColors.stage]): é a mesma cor de
/// fundo dos ativos 3D reais da Biblioteca de Exercícios, então um card
/// escuro por trás pareceria um recorte quebrado, não uma escolha.
///
/// Renderiza o GIF oficial (`ExerciseModel.gif360Url`, com fallback pro
/// `gif180Url` caso a variante maior não exista) via `AssetImage` —
/// resolvido/decodificado sob demanda pelo próprio Flutter só quando
/// este widget entra em tela (nenhum carregamento em lote). A troca de
/// resolução é automática e nunca aparece como opção pro aluno.
class ExercicioMediaStage extends StatefulWidget {
  const ExercicioMediaStage({super.key, required this.exercise});

  final ExerciseModel exercise;

  @override
  State<ExercicioMediaStage> createState() => _ExercicioMediaStageState();
}

class _ExercicioMediaStageState extends State<ExercicioMediaStage>
    with SingleTickerProviderStateMixin {
  late final GifController _loopController;
  late bool _tocando;

  @override
  void initState() {
    super.initState();
    _loopController = GifController(vsync: this);
    // Mesma fonte que MediaQuery.of(context).disableAnimations usa por
    // baixo — segura de ler aqui porque não depende de um BuildContext
    // já anexado à árvore (ao contrário de MediaQuery.of, que não pode
    // ser chamado dentro de initState).
    _tocando = !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  void didUpdateWidget(covariant ExercicioMediaStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) {
      // A troca de `key` no Gif (ver build) já força um widget novo pro
      // próximo exercício — reseta o controller pra não herdar posição
      // de quadro do gif anterior.
      _tocando = !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
      _loopController.reset();
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
      _tocando ? _loopController.repeat() : _loopController.stop();
    });
  }

  void _reiniciar() {
    _loopController.reset();
    if (_tocando) _loopController.repeat();
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
                child: Gif(
                  key: ValueKey(widget.exercise.id),
                  image: AssetImage(widget.exercise.gif360Url ?? widget.exercise.gif180Url),
                  controller: _loopController,
                  autostart: reduceMotion ? Autostart.no : Autostart.loop,
                  fit: BoxFit.contain,
                  placeholder: (_) => const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ),
          const Positioned(top: 14, left: 14, child: LoopBadge()),
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
