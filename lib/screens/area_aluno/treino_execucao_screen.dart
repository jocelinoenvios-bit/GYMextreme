import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/exercise_model.dart';
import '../../services/exercise_repository.dart';
import '../../theme/app_colors.dart';
import 'widgets/exercicio_info_cards.dart';
import 'widgets/exercicio_media_stage.dart';
import 'widgets/execucao_bottom_bar.dart';
import 'widgets/treino_progress_bar.dart';

/// Tela de execução do treino (Área do Aluno) — guia o aluno exercício
/// por exercício, com a demonstração visual como elemento dominante.
///
/// Consome só [ExerciseRepository]/[ExercisePrescription]/[ExerciseModel]
/// — nunca `Treino`/`TreinoExercicio`/`Exercicio` (o domínio real) nem
/// Firestore diretamente. Quando a Biblioteca de Exercícios oficial (ou
/// uma API externa) for integrada, basta passar uma implementação real
/// de [ExerciseRepository] no lugar de [MockExerciseRepository] — nada
/// aqui muda.
class TreinoExecucaoScreen extends StatefulWidget {
  const TreinoExecucaoScreen({
    super.key,
    required this.treinoId,
    required this.treinoNome,
    this.repository = const MockExerciseRepository(),
  });

  final String treinoId;
  final String treinoNome;
  final ExerciseRepository repository;

  @override
  State<TreinoExecucaoScreen> createState() => _TreinoExecucaoScreenState();
}

class _TreinoExecucaoScreenState extends State<TreinoExecucaoScreen> {
  List<ExercisePrescription>? _exercicios;
  int _exercicioIndex = 0;
  int _seriesConcluidas = 0;
  bool _treinoConcluido = false;

  bool _emDescanso = false;
  int _segundosRestantes = 0;
  Timer? _timer;

  late final TextEditingController _cargaController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargaController = TextEditingController();
    _carregar();
  }

  Future<void> _carregar() async {
    final exercicios = await widget.repository.buscarExerciciosDoTreino(widget.treinoId);
    if (!mounted) return;
    setState(() {
      _exercicios = exercicios;
      if (exercicios.isNotEmpty) {
        _cargaController.text = _formatarCarga(exercicios.first.cargaKg);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cargaController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ExercisePrescription get _prescricaoAtual => _exercicios![_exercicioIndex];

  double get _progressoGeral {
    final exercicios = _exercicios;
    if (exercicios == null || exercicios.isEmpty) return 0;
    final totalSeries = exercicios.fold<int>(0, (soma, p) => soma + p.series);
    if (totalSeries == 0) return 0;
    final seriesAnteriores = exercicios
        .take(_exercicioIndex)
        .fold<int>(0, (soma, p) => soma + p.series);
    return (seriesAnteriores + _seriesConcluidas) / totalSeries;
  }

  String _formatarCarga(double? carga) {
    if (carga == null) return '';
    return carga == carga.roundToDouble() ? carga.toInt().toString() : carga.toString();
  }

  void _concluirSerie() {
    setState(() => _seriesConcluidas++);

    if (_seriesConcluidas < _prescricaoAtual.series) {
      _iniciarDescanso(_prescricaoAtual.descansoSegundos);
    } else {
      _avancarExercicio();
    }
  }

  void _iniciarDescanso(int segundos) {
    _timer?.cancel();
    setState(() {
      _emDescanso = true;
      _segundosRestantes = segundos;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_segundosRestantes <= 1) {
          timer.cancel();
          _emDescanso = false;
        } else {
          _segundosRestantes--;
        }
      });
    });
  }

  void _pularDescanso() {
    _timer?.cancel();
    setState(() => _emDescanso = false);
  }

  void _avancarExercicio() {
    final exercicios = _exercicios!;
    if (_exercicioIndex + 1 < exercicios.length) {
      setState(() {
        _exercicioIndex++;
        _seriesConcluidas = 0;
        _cargaController.text = _formatarCarga(exercicios[_exercicioIndex].cargaKg);
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      setState(() => _treinoConcluido = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercicios = _exercicios;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          exercicios == null || _treinoConcluido ? widget.treinoNome : _prescricaoAtual.exercise.nome,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (exercicios != null && !_treinoConcluido)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'série ${(_seriesConcluidas + 1).clamp(1, _prescricaoAtual.series).toInt()}'
                    ' de ${_prescricaoAtual.series}',
                    style: const TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: exercicios == null
          ? const Center(child: CircularProgressIndicator())
          : _treinoConcluido
          ? _TreinoConcluidoView(totalExercicios: exercicios.length)
          : Column(
              children: [
                TreinoProgressBar(
                  exercicioAtual: _exercicioIndex + 1,
                  totalExercicios: exercicios.length,
                  progresso: _progressoGeral,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      children: [
                        ExercicioMediaStage(exercise: _prescricaoAtual.exercise),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ExercicioInfoList(prescricao: _prescricaoAtual),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: (exercicios == null || _treinoConcluido)
          ? null
          : ExecucaoBottomBar(
              prescricao: _prescricaoAtual,
              serieAtual: (_seriesConcluidas + 1).clamp(1, _prescricaoAtual.series).toInt(),
              seriesConcluidas: _seriesConcluidas,
              cargaController: _cargaController,
              emDescanso: _emDescanso,
              segundosRestantes: _segundosRestantes,
              onConcluirSerie: _concluirSerie,
              onPularDescanso: _pularDescanso,
            ),
    );
  }
}

class _TreinoConcluidoView extends StatelessWidget {
  const _TreinoConcluidoView({required this.totalExercicios});

  final int totalExercicios;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.goldBright, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Treino concluído!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalExercicios exercícios finalizados',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('VOLTAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
