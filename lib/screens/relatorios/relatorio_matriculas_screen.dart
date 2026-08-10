import 'package:flutter/material.dart';

import '../../models/matricula.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/relatorio_matriculas.dart';

/// Relatório de matrículas — ativas, encerradas, vencendo em breve e
/// novas matrículas por período de criação. Carrega uma vez a partir de
/// `AlunoService.watchTodasMatriculas()`, já existente.
class RelatorioMatriculasScreen extends StatefulWidget {
  const RelatorioMatriculasScreen({super.key, required this.alunoService});

  final AlunoService alunoService;

  @override
  State<RelatorioMatriculasScreen> createState() => _RelatorioMatriculasScreenState();
}

class _RelatorioMatriculasScreenState extends State<RelatorioMatriculasScreen> {
  late Future<List<Matricula>> _future;
  DateTime? _de;
  DateTime? _ate;
  StatusMatricula? _filtroStatus;

  @override
  void initState() {
    super.initState();
    _future = widget.alunoService.watchTodasMatriculas().first;
  }

  Future<void> _escolherData(bool inicio) async {
    final atual = inicio ? _de : _ate;
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: inicio ? 'Criação de' : 'Criação até',
    );
    if (picked == null) return;
    setState(() {
      if (inicio) {
        _de = picked;
      } else {
        _ate = picked;
      }
    });
  }

  String _fmt(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de matrículas')),
      body: FutureBuilder<List<Matricula>>(
        future: _future,
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

          final todas = snapshot.data ?? [];
          final resumo = calcularResumoMatriculas(todas);
          final novas = filtrarMatriculasPorPeriodoDeCriacao(todas, de: _de, ate: _ate);
          final listadas = _filtroStatus == null
              ? todas
              : todas.where((m) => m.status == _filtroStatus).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _CartaoNumero('Ativas', '${resumo.ativas}', const Color(0xFF4CAF6D)),
                  _CartaoNumero('Encerradas', '${resumo.encerradas}', AppColors.textSecondary),
                  _CartaoNumero(
                    'Vencendo em ${diasAlertaVencimentoMatricula}d',
                    '${resumo.vencendoEmBreve}',
                    AppColors.gold,
                  ),
                  _CartaoNumero('Total', '${resumo.total}', AppColors.textPrimary),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Novas matrículas por período', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _escolherData(true),
                      child: Text(_de == null ? 'De' : _fmt(_de!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _escolherData(false),
                      child: Text(_ate == null ? 'Até' : _fmt(_ate!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${novas.length} matrícula(s) criada(s) no período selecionado'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Situação:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<StatusMatricula?>(
                      initialValue: _filtroStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas')),
                        ...StatusMatricula.values.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                        ),
                      ],
                      onChanged: (valor) => setState(() => _filtroStatus = valor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...listadas.map(
                (m) => _LinhaMatricula(
                  status: m.status,
                  vencimento: 'Venc. ${_fmt(m.dataVencimento)}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartaoNumero extends StatelessWidget {
  const _CartaoNumero(this.titulo, this.valor, this.cor);
  final String titulo;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(valor, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 22)),
          Text(titulo, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LinhaMatricula extends StatelessWidget {
  const _LinhaMatricula({required this.status, required this.vencimento});

  final StatusMatricula status;
  final String vencimento;

  Color _cor() {
    switch (status) {
      case StatusMatricula.ativa:
        return const Color(0xFF4CAF6D);
      case StatusMatricula.vencida:
        return AppColors.error;
      case StatusMatricula.cancelada:
      case StatusMatricula.suspensa:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = _cor();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(vencimento),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(status.label, style: TextStyle(color: cor, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
