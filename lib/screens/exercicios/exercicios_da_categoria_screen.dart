import 'package:flutter/material.dart';

import '../../constants/dificuldade_exercicio.dart';
import '../../models/exercise_model.dart';
import '../../services/gif_cache_service.dart';
import '../../theme/app_colors.dart';
import 'exercicio_detail_screen.dart';

/// Exercícios de UMA categoria (ex.: só "Peito") — aberta ao tocar num
/// dos cards de `ExerciciosListScreen`. Cada exercício aparece como um
/// cartão (miniatura, nome, nível de dificuldade), não mais uma lista
/// simples.
class ExerciciosDaCategoriaScreen extends StatefulWidget {
  const ExerciciosDaCategoriaScreen({
    super.key,
    required this.titulo,
    required this.exercicios,
    this.onSelecionar,
    this.gifCacheService,
  });

  final String titulo;
  final List<ExerciseModel> exercicios;

  /// Mesmo significado de `ExerciciosListScreen.onSelecionar` — repassado
  /// sem alteração.
  final ValueChanged<ExerciseModel>? onSelecionar;
  final GifCacheService? gifCacheService;

  @override
  State<ExerciciosDaCategoriaScreen> createState() => _ExerciciosDaCategoriaScreenState();
}

class _ExerciciosDaCategoriaScreenState extends State<ExerciciosDaCategoriaScreen> {
  final _searchController = TextEditingController();
  String _busca = '';
  late final GifCacheService _gifCacheService;

  @override
  void initState() {
    super.initState();
    _gifCacheService = widget.gifCacheService ?? FirebaseGifCacheService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercicios = widget.exercicios
        .where((e) => _busca.isEmpty || e.nomeExibicao.toLowerCase().contains(_busca))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _busca = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Buscar exercício pelo nome',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: exercicios.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum exercício encontrado com esse filtro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: exercicios.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final exercicio = exercicios[index];
                      return CartaoExercicio(
                        exercicio: exercicio,
                        gifCacheService: _gifCacheService,
                        onTap: () {
                          if (widget.onSelecionar != null) {
                            // NÃO chama onSelecionar direto daqui: esta
                            // tela é sempre aberta por dentro de
                            // ExerciciosListScreen (nunca por conta
                            // própria), que é quem efetivamente possui o
                            // callback do chamador externo (ex.:
                            // TreinoFormScreen._adicionarExercicio, que só
                            // dá UM pop esperando fechar "o seletor"
                            // inteiro). Por isso só devolve o exercício
                            // escolhido pra ExerciciosListScreen (pop
                            // desta tela), que então repassa pro callback
                            // externo — assim o chamador continua
                            // precisando de só um pop, não importa quantos
                            // níveis o seletor tem por dentro.
                            Navigator.of(context).pop(exercicio);
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExercicioDetailScreen(
                                exercicio: exercicio,
                                gifCacheService: widget.gifCacheService,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Um exercício num cartão — miniatura, nome e nível de dificuldade.
/// Usado tanto aqui quanto na busca por nome de `ExerciciosListScreen`
/// (substitui o antigo `ListTile` simples das duas telas).
class CartaoExercicio extends StatelessWidget {
  const CartaoExercicio({
    super.key,
    required this.exercicio,
    required this.gifCacheService,
    required this.onTap,
  });

  final ExerciseModel exercicio;
  final GifCacheService gifCacheService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceHigh),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 52, height: 52, child: _miniatura(exercicio, gifCacheService)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercicio.nomeExibicao,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (exercicio.dificuldade.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        labelDificuldade(exercicio.dificuldade).toUpperCase(),
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Nunca baixa do Firebase Storage: rolar a lista não conta como "abrir"
  /// o exercício. Só mostra algo se já estiver no cache local (ou for um
  /// asset de teste); caso contrário cai no ícone de reserva — mesmo
  /// comportamento de sempre, mesmo com os GIFs desligados hoje (ver
  /// `LocalExerciseRepository`).
  Widget _miniatura(ExerciseModel exercicio, GifCacheService gifCacheService) {
    final caminho = exercicio.gif360Url;
    if (caminho == null) return const _ThumbnailFallback();

    final imagem = gifCacheService.resolverImagemDoCache(caminho);
    if (imagem == null) return const _ThumbnailFallback();

    return Image(
      image: imagem,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _ThumbnailFallback(),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Icon(Icons.fitness_center_outlined, color: AppColors.textSecondary, size: 22),
    );
  }
}
