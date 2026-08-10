import 'package:flutter/material.dart';

import '../../constants/circunferencia_fields.dart';
import '../../models/app_user.dart';
import '../../models/avaliacao_fisica.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/simple_line_chart.dart';

/// Evolução física — escolhe um aluno e mostra o histórico já existente
/// de [AvaliacaoFisica] (peso, IMC e medidas) ao longo do tempo, com um
/// gráfico simples de peso e de IMC. Reaproveita `AlunoService.watchAlunos()`
/// (pro seletor) e `watchAvaliacoes(uid)` (pro histórico do aluno
/// escolhido) — nenhum dado novo, essa é a primeira tela a exibir o que
/// já era gravado desde a ficha de avaliação física.
class EvolucaoFisicaScreen extends StatefulWidget {
  const EvolucaoFisicaScreen({super.key, required this.alunoService});

  final AlunoService alunoService;

  @override
  State<EvolucaoFisicaScreen> createState() => _EvolucaoFisicaScreenState();
}

class _EvolucaoFisicaScreenState extends State<EvolucaoFisicaScreen> {
  late Future<List<AppUser>> _alunosFuture;
  String? _alunoSelecionadoUid;
  Future<List<AvaliacaoFisica>>? _avaliacoesFuture;

  @override
  void initState() {
    super.initState();
    _alunosFuture = widget.alunoService.watchAlunos().first;
  }

  void _selecionarAluno(String? uid) {
    setState(() {
      _alunoSelecionadoUid = uid;
      _avaliacoesFuture = uid == null ? null : widget.alunoService.watchAvaliacoes(uid).first;
    });
  }

  String _fmt(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evolução física')),
      body: FutureBuilder<List<AppUser>>(
        future: _alunosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final alunos = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _alunoSelecionadoUid,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Selecione um aluno',
                ),
                items: alunos
                    .map((a) => DropdownMenuItem(value: a.uid, child: Text(a.nome)))
                    .toList(),
                onChanged: _selecionarAluno,
              ),
              const SizedBox(height: 16),
              if (_avaliacoesFuture == null)
                const Text(
                  'Selecione um aluno para ver a evolução física.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                FutureBuilder<List<AvaliacaoFisica>>(
                  future: _avaliacoesFuture,
                  builder: (context, avSnap) {
                    if (avSnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (avSnap.hasError) {
                      return Text(
                        'Erro ao carregar avaliações.\n\n${avSnap.error}',
                        style: const TextStyle(color: AppColors.error),
                      );
                    }

                    // watchAvaliacoes já vem mais recente primeiro; o
                    // gráfico precisa da ordem cronológica (mais antiga
                    // primeiro), então inverte só pra exibição.
                    final avaliacoes = (avSnap.data ?? []).reversed.toList();
                    if (avaliacoes.isEmpty) {
                      return const Text(
                        'Nenhuma avaliação física registrada para este aluno.',
                        style: TextStyle(color: AppColors.textSecondary),
                      );
                    }

                    final pesoPontos = [
                      for (final a in avaliacoes)
                        if (a.pesoKg != null) ChartPoint(a.data, a.pesoKg!),
                    ];
                    final imcPontos = [
                      for (final a in avaliacoes)
                        if (a.imc != null) ChartPoint(a.data, a.imc!),
                    ];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Peso (kg)', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SimpleLineChart(
                          pontos: pesoPontos,
                          corLinha: AppColors.gold,
                          sufixo: 'kg',
                        ),
                        const SizedBox(height: 24),
                        const Text('IMC', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SimpleLineChart(pontos: imcPontos, corLinha: const Color(0xFF4CAF6D)),
                        const SizedBox(height: 24),
                        const Text('Histórico', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...avaliacoes.reversed.map(
                          (a) => _CartaoAvaliacao(avaliacao: a, fmt: _fmt),
                        ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CartaoAvaliacao extends StatelessWidget {
  const _CartaoAvaliacao({required this.avaliacao, required this.fmt});

  final AvaliacaoFisica avaliacao;
  final String Function(DateTime) fmt;

  @override
  Widget build(BuildContext context) {
    final medidas = circunferenciaFields
        .where((f) => avaliacao.circunferenciasCm[f.key] != null)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fmt(avaliacao.data), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            children: [
              if (avaliacao.pesoKg != null)
                Text('Peso: ${avaliacao.pesoKg!.toStringAsFixed(1)} kg'),
              if (avaliacao.imc != null) Text('IMC: ${avaliacao.imc!.toStringAsFixed(1)}'),
            ],
          ),
          if (medidas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: medidas
                  .map(
                    (f) => Text(
                      '${f.label}: ${avaliacao.circunferenciasCm[f.key]!.toStringAsFixed(1)}cm',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (avaliacao.observacoes != null && avaliacao.observacoes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              avaliacao.observacoes!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
