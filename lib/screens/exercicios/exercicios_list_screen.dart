import 'package:flutter/material.dart';

import '../../constants/grupos_musculares.dart';
import '../../models/exercise_model.dart';
import '../../services/exercise_repository.dart';
import '../../services/gif_cache_service.dart';
import '../../theme/app_colors.dart';
import 'exercicio_detail_screen.dart';
import 'exercicios_da_categoria_screen.dart';

/// Biblioteca Oficial de Exercícios (ExerciseDB, local/offline): busca
/// por nome + as 10 categorias (grupo muscular) como cards — cada uma
/// abre `ExerciciosDaCategoriaScreen` com os exercícios daquele grupo.
/// Buscar por nome substitui os cards pelos resultados (cruza todas as
/// categorias). Somente leitura — a biblioteca em si é um asset do app,
/// sem cadastro/edição pela interface.
class ExerciciosListScreen extends StatefulWidget {
  const ExerciciosListScreen({
    super.key,
    this.repository = const LocalExerciseRepository(),
    this.onSelecionar,
    this.gifCacheService,
  });

  final ExerciseRepository repository;

  /// Quando informado, a tela (e a de categoria aberta a partir dela)
  /// vira um seletor: tocar num exercicio chama este callback (com a
  /// tela ja fechada) em vez de abrir o detalhe — usado pelo
  /// `TreinoFormScreen` pra escolher exercicios sem duplicar este
  /// browser.
  final ValueChanged<ExerciseModel>? onSelecionar;

  /// Injetável pra teste — em produção usa `FirebaseGifCacheService()`
  /// por padrão.
  final GifCacheService? gifCacheService;

  @override
  State<ExerciciosListScreen> createState() => _ExerciciosListScreenState();
}

class _ExerciciosListScreenState extends State<ExerciciosListScreen> {
  final _searchController = TextEditingController();
  String _busca = '';
  late final Future<List<ExerciseModel>> _futureTodos;
  late final GifCacheService _gifCacheService;

  @override
  void initState() {
    super.initState();
    _gifCacheService = widget.gifCacheService ?? FirebaseGifCacheService();
    _futureTodos = widget.repository.buscarTodos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.onSelecionar != null ? 'Selecionar exercício' : 'Biblioteca de exercícios',
        ),
      ),
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
            child: FutureBuilder<List<ExerciseModel>>(
              future: _futureTodos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Erro ao carregar a Biblioteca Oficial de Exercícios.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  );
                }

                final todos = snapshot.data ?? const <ExerciseModel>[];

                if (_busca.isNotEmpty) {
                  final resultados = todos
                      .where((e) => e.nomeExibicao.toLowerCase().contains(_busca))
                      .toList();
                  return _buildResultadosBusca(resultados);
                }

                return _buildGradeCategorias(todos);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadosBusca(List<ExerciseModel> resultados) {
    if (resultados.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum exercício encontrado com esse filtro.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: resultados.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final exercicio = resultados[index];
        return CartaoExercicio(
          exercicio: exercicio,
          gifCacheService: _gifCacheService,
          onTap: () => _abrirExercicio(exercicio),
        );
      },
    );
  }

  Widget _buildGradeCategorias(List<ExerciseModel> todos) {
    final categorias = todos.map((e) => e.bodyPart).where((g) => g.isNotEmpty).toSet().toList()
      ..sort();

    if (categorias.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhuma categoria disponível.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return GridView.count(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: categorias.map((categoria) {
        return _CardCategoria(
          label: labelGrupoMuscular(categoria),
          onTap: () async {
            final exerciciosDaCategoria = todos.where((e) => e.bodyPart == categoria).toList();
            final escolhido = await Navigator.of(context).push<ExerciseModel>(
              MaterialPageRoute(
                builder: (_) => ExerciciosDaCategoriaScreen(
                  titulo: labelGrupoMuscular(categoria),
                  exercicios: exerciciosDaCategoria,
                  onSelecionar: widget.onSelecionar,
                  gifCacheService: widget.gifCacheService,
                ),
              ),
            );
            // A tela de categoria só devolve um exercício (via pop) quando
            // está em modo seletor — ela mesma já fechou sozinha; agora é
            // repassar pro callback do chamador externo, que por sua vez
            // fecha ESTA tela (ExerciciosListScreen) com um único pop seu.
            if (escolhido != null && widget.onSelecionar != null) {
              widget.onSelecionar!(escolhido);
            }
          },
        );
      }).toList(),
    );
  }

  void _abrirExercicio(ExerciseModel exercicio) {
    if (widget.onSelecionar != null) {
      // Quem passou onSelecionar já é responsável por fechar esta tela
      // (ver TreinoFormScreen._adicionarExercicio, que faz
      // Navigator.pop(exercicio) dentro do próprio callback) — um pop()
      // extra aqui fechava DUAS telas de uma vez.
      widget.onSelecionar!(exercicio);
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
  }
}

/// Um card quadrado de cantos arredondados pra uma categoria (grupo
/// muscular) — mesmo padrão visual já usado em "Gerenciar Alunos" e na
/// tela inicial.
class _CardCategoria extends StatelessWidget {
  const _CardCategoria({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center_outlined, color: AppColors.gold, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
