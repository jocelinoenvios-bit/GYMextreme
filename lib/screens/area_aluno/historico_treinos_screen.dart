import 'package:flutter/material.dart';

import '../../models/historico_treino.dart';
import '../../models/treino.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Histórico de presença/frequência, semana a semana — sempre separado
/// da ficha prescrita (`MinhaFichaScreen`): um treino nunca some daqui
/// por falta de registro, e a falta nunca é presumida — sem registro
/// de `HistoricoTreino` pra aquela data, o status é sempre "Não
/// registrado", nunca "Falta" (só quem tem permissão de treino
/// confirma presença/falta, ver `firestore.rules`).
class HistoricoTreinosScreen extends StatefulWidget {
  const HistoricoTreinosScreen({super.key, required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  @override
  State<HistoricoTreinosScreen> createState() => _HistoricoTreinosScreenState();
}

class _HistoricoTreinosScreenState extends State<HistoricoTreinosScreen> {
  /// 0 = semana atual, -1 = semana anterior, etc. Nunca deixa navegar
  /// pra semanas futuras (>0) — não faz sentido presença futura.
  int _semanaOffset = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de treinos')),
      body: SafeArea(
        child: StreamBuilder<List<Treino>>(
          stream: widget.alunoService.watchTreinos(widget.uid),
          builder: (context, treinosSnapshot) {
            return StreamBuilder<List<HistoricoTreino>>(
              stream: widget.alunoService.watchHistoricoTreinos(widget.uid),
              builder: (context, historicoSnapshot) {
                if (treinosSnapshot.connectionState == ConnectionState.waiting ||
                    historicoSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final treinosAtivos =
                    (treinosSnapshot.data ?? []).where((t) => t.ativo && t.diaSemana != null).toList();
                final historico = historicoSnapshot.data ?? [];

                final hoje = DateTime.now();
                final segundaAtual = hoje.subtract(Duration(days: hoje.weekday - 1));
                final segundaDaSemana = DateTime(
                  segundaAtual.year,
                  segundaAtual.month,
                  segundaAtual.day,
                ).add(Duration(days: 7 * _semanaOffset));

                return Column(
                  children: [
                    _NavegacaoSemana(
                      inicio: segundaDaSemana,
                      podeAvancar: _semanaOffset < 0,
                      onAnterior: () => setState(() => _semanaOffset--),
                      onProxima: () => setState(() => _semanaOffset++),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceHigh),
                    Expanded(
                      child: treinosAtivos.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Nenhum treino tem dia da semana definido ainda — '
                                  'fale com seu personal.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                for (var i = 0; i < 7; i++)
                                  _DiaLinha(
                                    data: segundaDaSemana.add(Duration(days: i)),
                                    treinosAtivos: treinosAtivos,
                                    historico: historico,
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NavegacaoSemana extends StatelessWidget {
  const _NavegacaoSemana({
    required this.inicio,
    required this.podeAvancar,
    required this.onAnterior,
    required this.onProxima,
  });

  final DateTime inicio;
  final bool podeAvancar;
  final VoidCallback onAnterior;
  final VoidCallback onProxima;

  @override
  Widget build(BuildContext context) {
    final fim = inicio.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onAnterior,
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            tooltip: 'Semana anterior',
          ),
          Text(
            '${_fmt(inicio)} — ${_fmt(fim)}',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          IconButton(
            onPressed: podeAvancar ? onProxima : null,
            icon: const Icon(Icons.chevron_right),
            color: podeAvancar ? AppColors.textPrimary : AppColors.surfaceHigh,
            tooltip: 'Próxima semana',
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _DiaLinha extends StatelessWidget {
  const _DiaLinha({required this.data, required this.treinosAtivos, required this.historico});

  final DateTime data;
  final List<Treino> treinosAtivos;
  final List<HistoricoTreino> historico;

  bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final diaSemana = data.weekday;
    final treinoDoDia = treinosAtivos.where((t) => t.diaSemana == diaSemana).toList();
    final registro = historico
        .where((h) => _mesmoDia(h.data, data) && treinoDoDia.any((t) => t.id == h.treinoId))
        .toList();

    final String statusLabel;
    final Color statusCor;
    if (treinoDoDia.isEmpty) {
      statusLabel = 'Sem treino prescrito';
      statusCor = AppColors.textSecondary;
    } else if (registro.isEmpty) {
      statusLabel = 'Não registrado';
      statusCor = AppColors.textSecondary;
    } else if (registro.any((r) => r.status == StatusHistoricoTreino.realizado)) {
      statusLabel = 'Realizado';
      statusCor = AppColors.goldBright;
    } else {
      statusLabel = 'Falta';
      statusCor = AppColors.error;
    }

    final futuro = data.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              diasSemanaLabels[diaSemana],
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              treinoDoDia.map((t) => 'Treino ${t.letra}').join(', '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!futuro || treinoDoDia.isEmpty)
            Text(
              statusLabel,
              style: TextStyle(color: statusCor, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}
