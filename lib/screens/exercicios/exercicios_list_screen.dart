import 'package:flutter/material.dart';

import '../../constants/grupos_musculares.dart';
import '../../models/exercise_model.dart';
import '../../services/exercise_repository.dart';
import '../../theme/app_colors.dart';
import 'exercicio_detail_screen.dart';

/// Biblioteca Oficial de Exercícios (ExerciseDB, local/offline): busca
/// por nome + filtro por grupo muscular. Somente leitura — a biblioteca
/// em si é um asset do app, sem cadastro/edição pela interface.
class ExerciciosListScreen extends StatefulWidget {
  const ExerciciosListScreen({
    super.key,
    this.repository = const LocalExerciseRepository(),
    this.onSelecionar,
  });

  final ExerciseRepository repository;

  /// Quando informado, a tela vira um seletor: tocar num exercicio chama
  /// este callback (com a tela ja fechada) em vez de abrir o detalhe —
  /// usado pelo `TreinoFormScreen` pra escolher exercicios sem duplicar
  /// este browser.
  final ValueChanged<ExerciseModel>? onSelecionar;

  @override
  State<ExerciciosListScreen> createState() => _ExerciciosListScreenState();
}

class _ExerciciosListScreenState extends State<ExerciciosListScreen> {
  final _searchController = TextEditingController();
  String _busca = '';
  String? _grupoMuscularSelecionado;
  late final Future<List<ExerciseModel>> _futureTodos;

  @override
  void initState() {
    super.initState();
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
                final gruposDisponiveis =
                    todos.map((e) => e.bodyPart).where((g) => g.isNotEmpty).toSet().toList()
                      ..sort();

                final exercicios = todos
                    .where((e) => _busca.isEmpty || e.nomeExibicao.toLowerCase().contains(_busca))
                    .where(
                      (e) =>
                          _grupoMuscularSelecionado == null ||
                          e.bodyPart == _grupoMuscularSelecionado,
                    )
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gruposDisponiveis.isNotEmpty)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _FiltroChip(
                              label: 'Todos',
                              selecionado: _grupoMuscularSelecionado == null,
                              onTap: () => setState(() => _grupoMuscularSelecionado = null),
                            ),
                            const SizedBox(width: 8),
                            ...gruposDisponiveis.map(
                              (grupo) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _FiltroChip(
                                  label: labelGrupoMuscular(grupo),
                                  selecionado: _grupoMuscularSelecionado == grupo,
                                  onTap: () => setState(
                                    () => _grupoMuscularSelecionado =
                                        _grupoMuscularSelecionado == grupo ? null : grupo,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: exercicios.isEmpty
                          ? const Center(
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
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, color: AppColors.surfaceHigh),
                              itemBuilder: (context, index) {
                                final exercicio = exercicios[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: Image.asset(
                                        exercicio.gif180Url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const _ThumbnailFallback(),
                                      ),
                                    ),
                                  ),
                                  title: Text(exercicio.nomeExibicao),
                                  subtitle: Text(
                                    labelGrupoMuscular(exercicio.bodyPart),
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textSecondary,
                                  ),
                                  onTap: () {
                                    if (widget.onSelecionar != null) {
                                      // Quem passou onSelecionar já é
                                      // responsável por fechar esta tela
                                      // (ver TreinoFormScreen._adicionarExercicio,
                                      // que faz Navigator.pop(exercicio) dentro
                                      // do próprio callback) — um pop() extra
                                      // aqui fechava DUAS telas de uma vez
                                      // (a lista de exercícios e a tela por
                                      // baixo dela, ex.: "Editar treino"),
                                      // porque a primeira pop() já deixava
                                      // essa tela no topo da pilha.
                                      widget.onSelecionar!(exercicio);
                                      return;
                                    }
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ExercicioDetailScreen(exercicio: exercicio),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({required this.label, required this.selecionado, required this.onTap});

  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.gold,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selecionado ? AppColors.gold : AppColors.surfaceHigh),
      labelStyle: TextStyle(
        color: selecionado ? AppColors.black : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
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
      child: const Icon(Icons.fitness_center_outlined, color: AppColors.textSecondary, size: 22),
    );
  }
}
