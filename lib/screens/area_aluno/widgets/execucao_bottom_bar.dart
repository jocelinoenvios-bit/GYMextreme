import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../../models/exercise_model.dart';
import '../../../theme/app_colors.dart';

/// Barra fixa no rodapé da tela de execução — a única ação que se repete
/// várias vezes no mesmo exercício, por isso não depende de rolar até o
/// fim da lista de informações toda vez. Ver o racional completo no
/// projeto de UX aprovado.
///
/// Dois estados: pronto pra próxima série (registra carga e conclui), ou
/// em descanso (cronômetro regressivo, com opção de pular). Todo o
/// estado (série atual, tempo restante) é dono da tela — este widget só
/// exibe e dispara callbacks.
class ExecucaoBottomBar extends StatelessWidget {
  const ExecucaoBottomBar({
    super.key,
    required this.prescricao,
    required this.serieAtual,
    required this.seriesConcluidas,
    required this.cargaController,
    required this.emDescanso,
    required this.segundosRestantes,
    required this.onConcluirSerie,
    required this.onPularDescanso,
  });

  final ExercisePrescription prescricao;

  /// Próxima série a executar (1-based).
  final int serieAtual;
  final int seriesConcluidas;
  final TextEditingController cargaController;
  final bool emDescanso;
  final int segundosRestantes;
  final VoidCallback onConcluirSerie;
  final VoidCallback onPularDescanso;

  String _formatarTempo(int segundos) {
    final min = (segundos ~/ 60).toString().padLeft(2, '0');
    final seg = (segundos % 60).toString().padLeft(2, '0');
    return '$min:$seg';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceHigh)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: emDescanso ? _buildDescanso(context) : _buildPronto(context),
    );
  }

  Widget _buildDescanso(BuildContext context) {
    final total = prescricao.descansoSegundos;
    final progresso = total == 0 ? 0.0 : 1 - (segundosRestantes / total).clamp(0, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.gold, size: 18),
            const SizedBox(width: 8),
            const Text(
              'DESCANSO',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              _formatarTempo(segundosRestantes),
              style: const TextStyle(
                color: AppColors.goldBright,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progresso.toDouble(),
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: const AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onPularDescanso,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            side: const BorderSide(color: AppColors.surfaceHigh),
            foregroundColor: AppColors.textPrimary,
          ),
          child: const Text('PULAR DESCANSO'),
        ),
      ],
    );
  }

  Widget _buildPronto(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _SeriesDots(total: prescricao.series, concluidas: seriesConcluidas),
            const Spacer(),
            Text(
              'Prescrito: ${prescricao.series}×${prescricao.repeticoes}'
              '${prescricao.cargaKg != null ? ' · ${_formatarCarga(prescricao.cargaKg!)}kg' : ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: cargaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Carga usada (kg)',
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: onConcluirSerie,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text('CONCLUIR SÉRIE $serieAtual'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatarCarga(double carga) {
    return carga == carga.roundToDouble() ? carga.toInt().toString() : carga.toString();
  }
}

class _SeriesDots extends StatelessWidget {
  const _SeriesDots({required this.total, required this.concluidas});

  final int total;
  final int concluidas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final feita = i < concluidas;
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: feita ? AppColors.gold : AppColors.surfaceHigh,
            ),
          ),
        );
      }),
    );
  }
}
