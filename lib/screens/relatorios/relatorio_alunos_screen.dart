import 'package:flutter/material.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/relatorio_alunos.dart';
import '../../utils/status_acesso.dart';

/// Relatório de alunos — total, ativos, bloqueados, sem registro de
/// mensalidade e novos cadastros por período. Carrega os dados uma vez
/// (sem listener permanente) a partir de `AlunoService.watchAlunos()` +
/// `watchTodosAlunos()`, já existentes.
class RelatorioAlunosScreen extends StatefulWidget {
  const RelatorioAlunosScreen({super.key, required this.alunoService});

  final AlunoService alunoService;

  @override
  State<RelatorioAlunosScreen> createState() => _RelatorioAlunosScreenState();
}

class _RelatorioAlunosScreenState extends State<RelatorioAlunosScreen> {
  late Future<_DadosAlunos> _future;
  DateTime? _de;
  DateTime? _ate;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_DadosAlunos> _carregar() async {
    final alunos = await widget.alunoService.watchAlunos().first;
    final fichas = await widget.alunoService.watchTodosAlunos().first;
    return _DadosAlunos(alunos: alunos, fichas: fichas);
  }

  Future<void> _escolherData(bool inicio) async {
    final atual = inicio ? _de : _ate;
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: inicio ? 'Cadastro de' : 'Cadastro até',
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
      appBar: AppBar(title: const Text('Relatório de alunos')),
      body: FutureBuilder<_DadosAlunos>(
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

          final dados = snapshot.data!;
          final resumo = calcularResumoAlunos(alunos: dados.alunos, fichasAlunos: dados.fichas);
          final novos = filtrarAlunosPorPeriodoDeCadastro(dados.alunos, de: _de, ate: _ate);
          final fichasPorUid = {for (final f in dados.fichas) f.uid: f};

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
                  _CartaoNumero('Total', '${resumo.total}', AppColors.textPrimary),
                  _CartaoNumero('Ativos', '${resumo.ativos}', const Color(0xFF4CAF6D)),
                  _CartaoNumero('Bloqueados', '${resumo.bloqueados}', AppColors.error),
                  _CartaoNumero('Sem registro', '${resumo.semRegistro}', AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Novos cadastros por período', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Text('${novos.length} aluno(s) cadastrado(s) no período selecionado'),
              const SizedBox(height: 16),
              const Text('Situação de mensalidade', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...dados.alunos.map((aluno) {
                final status = calcularStatusMensalidadeAluno(aluno, fichasPorUid);
                return _LinhaAluno(nome: aluno.nome, status: status);
              }),
            ],
          );
        },
      ),
    );
  }
}

class _DadosAlunos {
  const _DadosAlunos({required this.alunos, required this.fichas});
  final List<AppUser> alunos;
  final List<Aluno> fichas;
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

class _LinhaAluno extends StatelessWidget {
  const _LinhaAluno({required this.nome, required this.status});

  final String nome;
  final StatusMensalidade status;

  Color _cor() {
    switch (status) {
      case StatusMensalidade.bloqueado:
        return AppColors.error;
      case StatusMensalidade.tolerancia:
        return AppColors.gold;
      case StatusMensalidade.emDia:
        return const Color(0xFF4CAF6D);
      case StatusMensalidade.semRegistro:
        return AppColors.textSecondary;
    }
  }

  String _label() {
    switch (status) {
      case StatusMensalidade.bloqueado:
        return 'Bloqueado';
      case StatusMensalidade.tolerancia:
        return 'Tolerância';
      case StatusMensalidade.emDia:
        return 'Em dia';
      case StatusMensalidade.semRegistro:
        return 'Sem registro';
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
          Expanded(child: Text(nome)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(_label(), style: TextStyle(color: cor, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
