import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:video_player/video_player.dart';

import '../../../models/exercise_model.dart';
import '../../../services/gif_cache_service.dart';
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

/// Mídia de demonstração do exercício, nesta ordem de prioridade:
///
/// 1. Vídeo da Vital Animations (`exercise.videoUrl`), local — sempre
///    funciona, mesmo offline.
/// 2. GIF da ExerciseDB, quando o vídeo não existir ou falhar ao
///    inicializar: primeiro checa o cache local (nunca toca rede);
///    se não estiver cacheado, baixa do Firebase Storage agora e grava
///    no cache pra próxima vez (ver `GifCacheService`). Só tenta baixar
///    depois que o vídeo já foi tentado — nunca faz as duas coisas em
///    paralelo, pra não gastar dado à toa quando o vídeo ia funcionar
///    mesmo.
/// 3. Se o GIF não estiver no cache nem puder ser baixado agora (sem
///    internet, por exemplo), mostra um estado "indisponível offline"
///    em vez de travar a tela.
/// 4. Se o exercício não tiver vídeo nem GIF (não deveria acontecer no
///    catálogo atual), mostra um indicador simples.
///
/// Nunca expõe essa cadeia como escolha do aluno.
class ExercicioMidia extends StatefulWidget {
  const ExercicioMidia({
    super.key,
    required this.exercise,
    required this.controller,
    required this.fit,
    this.reduceMotion = false,
    this.gifCacheService,
  });

  final ExerciseModel exercise;
  final ExercicioMidiaController controller;
  final BoxFit fit;

  /// Quando `true`, o vídeo nem chega a ser inicializado — vai direto
  /// pro GIF estático (`Autostart.no`), mesma acessibilidade que já
  /// existia antes do vídeo.
  final bool reduceMotion;

  /// Injetável pra teste (`FakeGifCacheService`) — em produção usa
  /// `FirebaseGifCacheService()` por padrão.
  final GifCacheService? gifCacheService;

  @override
  State<ExercicioMidia> createState() => _ExercicioMidiaState();
}

class _ExercicioMidiaState extends State<ExercicioMidia> with SingleTickerProviderStateMixin {
  late final GifCacheService _gifCacheService;
  VideoPlayerController? _video;
  late final GifController _gifController;
  late int _ultimoReinicios;

  ImageProvider? _gifImagem;

  /// `true` só depois de tentar resolver o GIF (cache + Storage) sem
  /// sucesso — distingue "ainda carregando" de "tentou e não tem".
  bool _gifIndisponivelAgora = false;

  @override
  void initState() {
    super.initState();
    _gifCacheService = widget.gifCacheService ?? FirebaseGifCacheService();
    _gifController = GifController(vsync: this);
    _ultimoReinicios = widget.controller.reinicios;
    widget.controller.addListener(_sincronizar);
    _carregarMidia();
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
      _gifImagem = null;
      _gifIndisponivelAgora = false;
      _gifController.reset();
      _carregarMidia();
    }
  }

  /// Orquestra a cadeia vídeo → GIF (cache → Storage) → indisponível,
  /// nessa ordem — o download do GIF só é tentado depois que a
  /// tentativa de vídeo já terminou (com ou sem sucesso).
  Future<void> _carregarMidia() async {
    final gifPath = widget.exercise.gif360Url ?? widget.exercise.gif180Url;

    // Cache local nunca custa uma chamada de rede — tenta mostrar algo
    // de cara, mesmo antes do vídeo, se esse GIF já tiver sido visto
    // (ou for um asset de teste).
    if (gifPath != null) {
      final imagemDoCache = _gifCacheService.resolverImagemDoCache(gifPath);
      if (imagemDoCache != null && mounted) {
        setState(() => _gifImagem = imagemDoCache);
      }
    }

    await _inicializarVideoSeHouver();

    if (!mounted || _video != null || gifPath == null || _gifImagem != null) return;
    await _baixarGifSeNecessario(gifPath);
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

  Future<void> _baixarGifSeNecessario(String gifPath) async {
    final exercicioAoIniciar = widget.exercise.id;
    final imagem = await _gifCacheService.resolverImagem(gifPath);
    if (!mounted || widget.exercise.id != exercicioAoIniciar) return;
    setState(() {
      if (imagem != null) {
        _gifImagem = imagem;
      } else {
        _gifIndisponivelAgora = true;
      }
    });
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
  /// GIF, de forma assíncrona (e marca essa duração como protegida,
  /// então não dá pra checar de fora se já está pronta antes de chamar).
  /// Se o aluno troca de exercício rapidamente (ex.: pula os últimos
  /// passos de uma série logo em seguida), o GIF do exercício novo/
  /// anterior pode ainda não ter terminado de carregar quando este
  /// método é chamado — chamar `.repeat()` nesse instante lançaria
  /// "AnimationController.repeat() called without an explicit period
  /// and with no default Duration.". Por isso a chamada real fica
  /// protegida por try/catch: se a duração ainda não estiver pronta, o
  /// pedido simplesmente não tem efeito agora (nunca propaga a exceção
  /// pra tela) — o próprio widget `Gif` assume a reprodução sozinho
  /// assim que os quadros terminarem de carregar (`autostart` no
  /// `build()`), então o pedido de "tocar" não se perde, só espera o
  /// carregamento terminar, como o comportamento sempre foi.
  void _repetirGifSePronto() {
    try {
      _gifController.repeat();
    } catch (_) {
      // Duração ainda não definida (GIF ainda carregando) ou qualquer
      // outra falha do AnimationController — nunca deixar a troca de
      // exercício quebrar a tela por causa do GIF.
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

    final imagem = _gifImagem;
    if (imagem != null) {
      return Gif(
        image: imagem,
        controller: _gifController,
        autostart: widget.reduceMotion ? Autostart.no : Autostart.loop,
        fit: widget.fit,
        placeholder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    if (_gifIndisponivelAgora) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.textSecondary, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Mídia indisponível offline',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Ainda checando o cache/baixando do Storage.
    return const Center(child: CircularProgressIndicator());
  }
}
