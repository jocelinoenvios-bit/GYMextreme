import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/matricula.dart';
import '../../models/permission.dart';
import '../../models/plano.dart';
import '../../services/aluno_service.dart';
import '../../services/permission_service.dart';
import '../../services/plano_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import 'matricula_form_screen.dart';

const _corAtiva = Color(0xFF4CAF6D);

/// Tela administrativa "Matrículas" — todas as matrículas de todos os
/// alunos, com filtro por status/aluno/plano. Criar/renovar/cancelar
/// exigem `Permission.matriculas`; qualquer staff pode visualizar.
class MatriculasListScreen extends StatefulWidget {
  const MatriculasListScreen({
    super.key,
    required this.alunoService,
    required this.planoService,
    required this.staffAtual,
  });

  final AlunoService alunoService;
  final PlanoService planoService;
  final AppUser staffAtual;

  @override
  State<MatriculasListScreen> createState() => _MatriculasListScreenState();
}

class _MatriculasListScreenState extends State<MatriculasListScreen> {
  StatusMatricula? _filtroStatus;
  String? _filtroAlunoUid;
  String? _filtroPlanoId;

  bool get _podeGerenciar => PermissionService.has(widget.staffAtual, Permission.matriculas);

  AppUser? _acharAluno(List<AppUser> alunos, String uid) {
    for (final aluno in alunos) {
      if (aluno.uid == uid) return aluno;
    }
    return null;
  }

  Plano? _acharPlano(List<Plano> planos, String id) {
    for (final plano in planos) {
      if (plano.id == id) return plano;
    }
    return null;
  }

  void _abrirNovaMatricula(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatriculaFormScreen(
          alunoService: widget.alunoService,
          planoService: widget.planoService,
        ),
      ),
    );
  }

  void _abrirRenovacao(BuildContext context, AppUser? aluno, Plano? plano, double valor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatriculaFormScreen(
          alunoService: widget.alunoService,
          planoService: widget.planoService,
          alunoPreSelecionado: aluno,
          planoPreSelecionado: plano,
          valorPreSelecionado: valor,
        ),
      ),
    );
  }

  Future<void> _confirmarCancelamento(BuildContext context, Matricula matricula) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar matrícula'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('VOLTAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CANCELAR MATRÍCULA'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await widget.alunoService.cancelarMatricula(matricula.alunoId, matricula.id!);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Color _corDoStatus(StatusMatricula status) {
    switch (status) {
      case StatusMatricula.ativa:
        return _corAtiva;
      case StatusMatricula.vencida:
        return AppColors.gold;
      case StatusMatricula.suspensa:
        return AppColors.muscleSecondary;
      case StatusMatricula.cancelada:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matrículas')),
      floatingActionButton: _podeGerenciar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirNovaMatricula(context),
              icon: const Icon(Icons.add),
              label: const Text('Nova matrícula'),
            )
          : null,
      body: StreamBuilder<List<AppUser>>(
        stream: widget.alunoService.watchAlunos(),
        builder: (context, alunosSnapshot) {
          final alunos = alunosSnapshot.data ?? [];
          return StreamBuilder<List<Plano>>(
            stream: widget.planoService.watchPlanos(),
            builder: (context, planosSnapshot) {
              final planos = planosSnapshot.data ?? [];
              return StreamBuilder<List<Matricula>>(
                stream: widget.alunoService.watchTodasMatriculas(),
                builder: (context, matriculasSnapshot) {
                  if (matriculasSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (matriculasSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            'Erro ao carregar as matrículas.\n\n${matriculasSnapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                    );
                  }

                  var matriculas = matriculasSnapshot.data ?? [];
                  if (_filtroStatus != null) {
                    matriculas = matriculas.where((m) => m.status == _filtroStatus).toList();
                  }
                  if (_filtroAlunoUid != null) {
                    matriculas = matriculas.where((m) => m.alunoId == _filtroAlunoUid).toList();
                  }
                  if (_filtroPlanoId != null) {
                    matriculas = matriculas.where((m) => m.planoId == _filtroPlanoId).toList();
                  }

                  return Column(
                    children: [
                      _FiltrosMatricula(
                        alunos: alunos,
                        planos: planos,
                        filtroStatus: _filtroStatus,
                        filtroAlunoUid: _filtroAlunoUid,
                        filtroPlanoId: _filtroPlanoId,
                        onStatusChanged: (status) => setState(() => _filtroStatus = status),
                        onAlunoChanged: (uid) => setState(() => _filtroAlunoUid = uid),
                        onPlanoChanged: (id) => setState(() => _filtroPlanoId = id),
                      ),
                      Expanded(
                        child: matriculas.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Nenhuma matrícula encontrada.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: matriculas.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final matricula = matriculas[index];
                                  final aluno = _acharAluno(alunos, matricula.alunoId);
                                  final plano = _acharPlano(planos, matricula.planoId);
                                  return _MatriculaCard(
                                    matricula: matricula,
                                    aluno: aluno,
                                    plano: plano,
                                    corStatus: _corDoStatus(matricula.status),
                                    formatarData: _formatarData,
                                    podeGerenciar: _podeGerenciar,
                                    onRenovar: () => _abrirRenovacao(
                                      context,
                                      aluno,
                                      plano,
                                      matricula.valorContratado,
                                    ),
                                    onCancelar: matricula.status == StatusMatricula.ativa
                                        ? () => _confirmarCancelamento(context, matricula)
                                        : null,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FiltrosMatricula extends StatelessWidget {
  const _FiltrosMatricula({
    required this.alunos,
    required this.planos,
    required this.filtroStatus,
    required this.filtroAlunoUid,
    required this.filtroPlanoId,
    required this.onStatusChanged,
    required this.onAlunoChanged,
    required this.onPlanoChanged,
  });

  final List<AppUser> alunos;
  final List<Plano> planos;
  final StatusMatricula? filtroStatus;
  final String? filtroAlunoUid;
  final String? filtroPlanoId;
  final ValueChanged<StatusMatricula?> onStatusChanged;
  final ValueChanged<String?> onAlunoChanged;
  final ValueChanged<String?> onPlanoChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<StatusMatricula?>(
              initialValue: filtroStatus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...StatusMatricula.values.map(
                  (status) => DropdownMenuItem(value: status, child: Text(status.label)),
                ),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              initialValue: filtroAlunoUid,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Aluno', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...alunos.map(
                  (aluno) => DropdownMenuItem(
                    value: aluno.uid,
                    child: Text(aluno.nome, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: onAlunoChanged,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              initialValue: filtroPlanoId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Plano', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...planos.map(
                  (plano) => DropdownMenuItem(
                    value: plano.id,
                    child: Text(plano.nome, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: onPlanoChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatriculaCard extends StatelessWidget {
  const _MatriculaCard({
    required this.matricula,
    required this.aluno,
    required this.plano,
    required this.corStatus,
    required this.formatarData,
    required this.podeGerenciar,
    required this.onRenovar,
    required this.onCancelar,
  });

  final Matricula matricula;
  final AppUser? aluno;
  final Plano? plano;
  final Color corStatus;
  final String Function(DateTime) formatarData;
  final bool podeGerenciar;
  final VoidCallback onRenovar;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: corStatus.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  aluno?.nome ?? 'Aluno não encontrado',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: corStatus.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  matricula.status.label,
                  style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            plano?.nome ?? 'Plano não encontrado',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatarData(matricula.dataInicio)} — ${formatarData(matricula.dataVencimento)} '
            '· ${formatarReais(matricula.valorContratado)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (matricula.observacao != null) ...[
            const SizedBox(height: 4),
            Text(
              matricula.observacao!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          if (podeGerenciar) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCancelar != null)
                  TextButton(onPressed: onCancelar, child: const Text('CANCELAR')),
                TextButton(onPressed: onRenovar, child: const Text('RENOVAR')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
