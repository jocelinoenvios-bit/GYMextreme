import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/exercise_model.dart';
import '../../models/treino.dart';
import '../../services/aluno_service.dart';
import '../../services/exercise_repository.dart';
import '../../theme/app_colors.dart';
import '../exercicios/exercicios_list_screen.dart';

const _letrasDisponiveis = ['A', 'B', 'C', 'D', 'E', 'F'];

/// Cria (quando [treino] for nulo) ou edita uma ficha de treino: nome,
/// letra, grupo muscular do dia e a lista de exercicios (cada um
/// escolhido na Biblioteca Oficial de Exercícios, nunca digitado à
/// mão) — os `exercicioId` gravados são sempre ids da Biblioteca
/// Oficial, a mesma fonte que resolve nome/mídia na execução do treino.
class TreinoFormScreen extends StatefulWidget {
  const TreinoFormScreen({
    super.key,
    required this.alunoUid,
    required this.alunoService,
    required this.staffAtual,
    this.repository = const LocalExerciseRepository(),
    this.treino,
  });

  final String alunoUid;
  final AlunoService alunoService;
  final AppUser staffAtual;
  final ExerciseRepository repository;
  final Treino? treino;

  bool get _modoEdicao => treino != null;

  @override
  State<TreinoFormScreen> createState() => _TreinoFormScreenState();
}

class _TreinoFormScreenState extends State<TreinoFormScreen> {
  final _nomeController = TextEditingController();
  final _grupoMuscularController = TextEditingController();
  String _letra = _letrasDisponiveis.first;
  late List<TreinoExercicio> _exercicios;
  late final Future<List<ExerciseModel>> _futureBiblioteca;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final treino = widget.treino;
    _nomeController.text = treino?.nome ?? 'Treino $_letra';
    _grupoMuscularController.text = treino?.grupoMuscular ?? '';
    _letra = treino?.letra ?? _letrasDisponiveis.first;
    _exercicios = [...(treino?.exercicios ?? const [])];
    _futureBiblioteca = widget.repository.buscarTodos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _grupoMuscularController.dispose();
    super.dispose();
  }

  Future<void> _adicionarExercicio() async {
    final exercicio = await Navigator.of(context).push<ExerciseModel>(
      MaterialPageRoute(
        builder: (_) => ExerciciosListScreen(
          repository: widget.repository,
          onSelecionar: (e) => Navigator.of(context).pop(e),
        ),
      ),
    );
    if (exercicio == null || !mounted) return;

    final parametros = await showDialog<TreinoExercicio>(
      context: context,
      builder: (_) => _ExercicioParametrosDialog(
        exercicioNome: exercicio.nomeExibicao,
        inicial: TreinoExercicio(exercicioId: exercicio.id, ordem: _exercicios.length),
      ),
    );
    if (parametros != null) {
      setState(() => _exercicios = [..._exercicios, parametros]);
    }
  }

  Future<void> _editarExercicio(int index, String nomeExercicio) async {
    final atualizado = await showDialog<TreinoExercicio>(
      context: context,
      builder: (_) => _ExercicioParametrosDialog(
        exercicioNome: nomeExercicio,
        inicial: _exercicios[index],
      ),
    );
    if (atualizado != null) {
      setState(() {
        final copia = [..._exercicios];
        copia[index] = atualizado;
        _exercicios = copia;
      });
    }
  }

  void _removerExercicio(int index) {
    setState(() {
      final copia = [..._exercicios]..removeAt(index);
      _exercicios = [
        for (var i = 0; i < copia.length; i++) copia[i].copyWith(ordem: i),
      ];
    });
  }

  void _reordenarExercicios(int oldIndex, int newIndex) {
    setState(() {
      final copia = [..._exercicios];
      if (newIndex > oldIndex) newIndex--;
      final item = copia.removeAt(oldIndex);
      copia.insert(newIndex, item);
      _exercicios = [
        for (var i = 0; i < copia.length; i++) copia[i].copyWith(ordem: i),
      ];
    });
  }

  Future<void> _handleSave() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome para o treino.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final treinoBase = widget.treino;
      final treino = treinoBase != null
          ? treinoBase.copyWith(
              nome: _nomeController.text.trim(),
              letra: _letra,
              grupoMuscular: _grupoMuscularController.text.trim(),
              exercicios: _exercicios,
            )
          : Treino(
              nome: _nomeController.text.trim(),
              letra: _letra,
              grupoMuscular: _grupoMuscularController.text.trim(),
              exercicios: _exercicios,
            );
      await widget.alunoService.salvarTreino(
        widget.alunoUid,
        treino,
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar o treino. Tente novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget._modoEdicao ? 'Editar treino' : 'Novo treino')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue: _letra,
                    decoration: const InputDecoration(labelText: 'Letra'),
                    items: _letrasDisponiveis
                        .map((letra) => DropdownMenuItem(value: letra, child: Text(letra)))
                        .toList(),
                    onChanged: (letra) => setState(() => _letra = letra ?? _letra),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nomeController,
                    decoration: const InputDecoration(labelText: 'Nome do treino'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _grupoMuscularController,
              decoration: const InputDecoration(
                labelText: 'Foco do treino',
                helperText: 'Ex.: Peito e tríceps',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Exercícios', style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: _adicionarExercicio,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            if (_exercicios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhum exercício adicionado ainda.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              FutureBuilder<List<ExerciseModel>>(
                future: _futureBiblioteca,
                builder: (context, snapshot) {
                  final biblioteca = {
                    for (final e in snapshot.data ?? <ExerciseModel>[]) e.id: e,
                  };
                  return ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: _reordenarExercicios,
                    children: [
                      for (var i = 0; i < _exercicios.length; i++)
                        _ExercicioTreinoTile(
                          key: ValueKey('${_exercicios[i].exercicioId}-$i'),
                          treinoExercicio: _exercicios[i],
                          exercicio: biblioteca[_exercicios[i].exercicioId],
                          onEditar: () => _editarExercicio(
                            i,
                            biblioteca[_exercicios[i].exercicioId]?.nomeExibicao ?? 'Exercício',
                          ),
                          onRemover: () => _removerExercicio(i),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                    )
                  : const Text('SALVAR TREINO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExercicioTreinoTile extends StatelessWidget {
  const _ExercicioTreinoTile({
    super.key,
    required this.treinoExercicio,
    required this.exercicio,
    required this.onEditar,
    required this.onRemover,
  });

  final TreinoExercicio treinoExercicio;
  final ExerciseModel? exercicio;
  final VoidCallback onEditar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final resumo = [
      if (treinoExercicio.series != null) '${treinoExercicio.series}x',
      if (treinoExercicio.repeticoes != null) treinoExercicio.repeticoes,
      if (treinoExercicio.cargaKg != null) '${treinoExercicio.cargaKg}kg',
      if (treinoExercicio.descansoSegundos != null)
        'descanso ${treinoExercicio.descansoSegundos}s',
    ].join(' • ');

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: ListTile(
        onTap: onEditar,
        leading: const Icon(Icons.drag_handle, color: AppColors.textSecondary),
        title: Text(exercicio?.nomeExibicao ?? 'Exercício não encontrado'),
        subtitle: resumo.isEmpty
            ? null
            : Text(resumo, style: const TextStyle(color: AppColors.textSecondary)),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: onRemover,
        ),
      ),
    );
  }
}

class _ExercicioParametrosDialog extends StatefulWidget {
  const _ExercicioParametrosDialog({required this.exercicioNome, required this.inicial});

  final String exercicioNome;
  final TreinoExercicio inicial;

  @override
  State<_ExercicioParametrosDialog> createState() => _ExercicioParametrosDialogState();
}

class _ExercicioParametrosDialogState extends State<_ExercicioParametrosDialog> {
  late final _seriesController = TextEditingController(
    text: widget.inicial.series?.toString() ?? '',
  );
  late final _repeticoesController = TextEditingController(
    text: widget.inicial.repeticoes ?? '',
  );
  late final _cargaController = TextEditingController(
    text: widget.inicial.cargaKg?.toString() ?? '',
  );
  late final _descansoController = TextEditingController(
    text: widget.inicial.descansoSegundos?.toString() ?? '',
  );
  late final _observacoesController = TextEditingController(
    text: widget.inicial.observacoes ?? '',
  );

  @override
  void dispose() {
    _seriesController.dispose();
    _repeticoesController.dispose();
    _cargaController.dispose();
    _descansoController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.exercicioNome, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _seriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Séries'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _repeticoesController,
                    decoration: const InputDecoration(labelText: 'Repetições', hintText: '8-12'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cargaController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Carga (kg)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _descansoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Descanso (s)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _observacoesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            // Constroi um TreinoExercicio novo (em vez de copyWith) pra
            // permitir limpar um campo — copyWith trata null como "nao
            // mudou", o que impediria apagar um valor ja preenchido.
            Navigator.of(context).pop(
              TreinoExercicio(
                exercicioId: widget.inicial.exercicioId,
                series: int.tryParse(_seriesController.text),
                repeticoes: _repeticoesController.text.trim().isEmpty
                    ? null
                    : _repeticoesController.text.trim(),
                cargaKg: double.tryParse(_cargaController.text.replaceAll(',', '.')),
                descansoSegundos: int.tryParse(_descansoController.text),
                observacoes: _observacoesController.text.trim().isEmpty
                    ? null
                    : _observacoesController.text.trim(),
                ordem: widget.inicial.ordem,
              ),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
