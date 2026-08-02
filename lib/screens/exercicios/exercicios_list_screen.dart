import 'package:flutter/material.dart';

import '../../constants/grupos_musculares.dart';
import '../../models/exercicio.dart';
import '../../services/exercicio_service.dart';
import '../../theme/app_colors.dart';
import 'exercicio_detail_screen.dart';

/// Biblioteca de exercicios: busca por nome + filtro por grupo
/// muscular. Somente leitura — o cadastro continua em um script/import
/// separado, fora do app. Os grupos musculares do filtro sao lidos
/// direto dos dados (nao ficam presos a taxonomia de uma API
/// especifica, ja que a fonte dos exercicios pode mudar).
class ExerciciosListScreen extends StatefulWidget {
  const ExerciciosListScreen({super.key, required this.exercicioService});

  final ExercicioService exercicioService;

  @override
  State<ExerciciosListScreen> createState() => _ExerciciosListScreenState();
}

class _ExerciciosListScreenState extends State<ExerciciosListScreen> {
  final _searchController = TextEditingController();
  String _busca = '';
  String? _grupoMuscularSelecionado;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de exercícios')),
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
            child: StreamBuilder<List<Exercicio>>(
              stream: widget.exercicioService.watchExercicios(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Erro ao carregar a biblioteca.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  );
                }

                final todos = snapshot.data ?? [];
                final gruposDisponiveis =
                    todos.map((e) => e.grupoMuscular).where((g) => g.isNotEmpty).toSet().toList()
                      ..sort();

                final exercicios = todos
                    .where((e) => _busca.isEmpty || e.nome.toLowerCase().contains(_busca))
                    .where(
                      (e) =>
                          _grupoMuscularSelecionado == null ||
                          e.grupoMuscular == _grupoMuscularSelecionado,
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
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  todos.isEmpty
                                      ? 'Nenhum exercício cadastrado ainda na coleção '
                                            '"exercicios" do Firestore.'
                                      : 'Nenhum exercício encontrado com esse filtro.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary),
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
                                      child:
                                          (exercicio.gifUrl != null &&
                                              exercicio.gifUrl!.isNotEmpty)
                                          ? Image.network(
                                              exercicio.gifUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const _ThumbnailFallback(),
                                            )
                                          : const _ThumbnailFallback(),
                                    ),
                                  ),
                                  title: Text(exercicio.nome),
                                  subtitle: exercicio.grupoMuscular.isEmpty
                                      ? null
                                      : Text(
                                          labelGrupoMuscular(exercicio.grupoMuscular),
                                          style: const TextStyle(color: AppColors.textSecondary),
                                        ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textSecondary,
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ExercicioDetailScreen(exercicio: exercicio),
                                    ),
                                  ),
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
