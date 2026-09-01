import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:video_player/video_player.dart';

import '../../../models/exercise_model.dart';
import '../../../theme/app_colors.dart';

/// Estado de reprodução (tocando/pausado) e comando de reinício,
/// compartilhados entre quem quer que esteja tocando de verdade (vídeo
/// da Vital Animations ou GIF da ExerciseDB) — quem desenha os
/// controles (`ExecucaoControlesRow`) não precisa saber qual dos dois
/// está ativo.
class ExercicioMidiaController extends ChangeNotifier {
  ExercicioMidiaController({required bool tocandoInicial}) : _tocando = tocandoInicial;

  bool _tocando;
  bool get tocando => _tocando;

  int _reinicios = 0;
  int get reinicios => _reinicios;

  void alternar() {
    _tocando = !_tocando;
    notifyListeners();
  }

  void reiniciar() {
    _reinicios++;
    notifyListeners();
  }

  /// Redefine tocando/reinicia de uma vez — usado ao trocar de
  /// exercício (o player, seja vídeo ou GIF, sempre volta do zero).
  void redefinir({required bool tocandoInicial}) {
    _tocando = tocandoInicial;
    _reinicios++;
    notifyListeners();
  }
}

/// Mídia de demonstração do exercício: vídeo da Vital Animations como
/// PRIMEIRA opção (`exercise.videoUrl`), GIF da ExerciseDB como
/// fallback automático — tanto quando o exercício não tem vídeo quanto
/// quando o vídeo existe mas falha ao inicializar (arquivo
/// corrompido/formato não suportado na plataforma). Se nem vídeo nem
/// GIF estiverem disponíveis, mostra um indicador simples em vez de
/// quebrar. Nunca expõe essa troca como escolha do aluno.
class ExercicioMidia extends StatefulWidget {
  const ExercicioMidia({
    super.key,
    required this.exercise,
    required this.controller,
    required this.fit,
    this.reduceMotion = false,
  });

  final ExerciseModel exercise;
  final ExercicioMidiaController controller;
  final BoxFit fit;

  /// Quando `true`, o vídeo nem chega a ser inicializado — vai direto
  /// pro GIF estático (`Autostart.no`), mesma acessibilidade que já
  /// existia antes do vídeo.
  final bool reduceMotion;

  @override
  State<ExercicioMidia> createState() => _ExercicioMidiaState();
}

class _ExercicioMidiaState extends State<ExercicioMidia> with SingleTickerProviderStateMixin {
  VideoPlayerController? _video;
  late final GifController _gifController;
  late int _ultimoReinicios;

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
    _ultimoReinicios = widget.controller.reinicios;
    widget.controller.addListener(_sincronizar);
    _inicializarVideoSeHouver();
  }

  @override
  void didUpdateWidget(covariant ExercicioMidia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sincronizar);
      widget.controller.addListener(_sincronizar);
    }
    if (oldWidget.exercise.id != widget.exercise.id) {
      _video?.dispose();
      _video = null;
      _gifController.reset();
      _inicializarVideoSeHouver();
    }
  }

  Future<void> _inicializarVideoSeHouver() async {
    final url = widget.exercise.videoUrl;
    if (url == null || widget.reduceMotion) return;

    final exercicioAoIniciar = widget.exercise.id;
    final controller = VideoPlayerController.asset(url);
    try {
      await controller.initialize();
      // O widget pode ter trocado de exercício (ou saído da árvore)
      // enquanto o `initialize()` estava em andamento.
      if (!mounted || widget.exercise.id != exercicioAoIniciar) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      setState(() => _video = controller);
      if (widget.controller.tocando) controller.play();
    } catch (_) {
      // Vídeo indisponível/corrompido/formato não suportado — cai pro
      // GIF automaticamente, sem propagar o erro pra tela.
      await controller.dispose();
    }
  }

  void _sincronizar() {
    final reiniciou = widget.controller.reinicios != _ultimoReinicios;
    _ultimoReinicios = widget.controller.reinicios;

    final video = _video;
    if (video != null) {
      if (reiniciou) video.seekTo(Duration.zero);
      widget.controller.tocando ? video.play() : video.pause();
    } else {
      if (reiniciou) _gifController.reset();
      widget.controller.tocando ? _repetirGifSePronto() : _gifController.stop();
    }
  }

  /// `AnimationController.repeat()` exige uma duração já definida — o
  /// pacote `gif` só define isso depois de decodificar os quadros do
  /// GIF, de forma assíncrona. Se o aluno troca de exercício rapidamente
  /// (ex.: pula os últimos passos de uma série logo em seguida), o GIF
  /// do exercício novo/anterior pode ainda não ter terminado de carregar
  /// quando este método é chamado — chamar `.repeat()` nesse instante
  /// lançaria "AnimationController.repeat() called without an explicit
  /// period and with no default Duration.". Sem duração pronta, não faz
  /// nada agora: o próprio widget `Gif` assume a reprodução sozinho
  /// assim que os quadros terminarem de carregar (`autostart` no
  /// `build()`), então o pedido de "tocar" não se perde — só espera o
  /// carregamento terminar, como o comportamento sempre foi.
  void _repetirGifSePronto() {
    if (_gifController.duration == null) return;
    try {
      _gifController.repeat();
    } catch (_) {
      // Blindagem extra: nunca deixar a troca de exercício quebrar a
      // tela por causa do GIF.
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sincronizar);
    _video?.dispose();
    _gifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    if (video != null && video.value.isInitialized) {
      return FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: video.value.size.width,
          height: video.value.size.height,
          child: VideoPlayer(video),
        ),
      );
    }

    final gifPath = widget.exercise.gif360Url ?? widget.exercise.gif180Url;
    if (gifPath == null) {
      // Nem vídeo nem GIF disponíveis pra este exercício — não deveria
      // acontecer no catálogo atual (todo exercício tem ao menos um dos
      // dois), mas evita quebrar a tela se algum dia acontecer.
      return const Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary, size: 40),
      );
    }

    return Gif(
      image: AssetImage(gifPath),
      controller: _gifController,
      autostart: widget.reduceMotion ? Autostart.no : Autostart.loop,
      fit: widget.fit,
      placeholder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }
}
