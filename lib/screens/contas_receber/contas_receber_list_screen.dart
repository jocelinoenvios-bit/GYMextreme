import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/conta_receber.dart';
import '../../models/permission.dart';
import '../../services/aluno_service.dart';
import '../../services/caixa_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import '../../utils/status_conta_receber.dart';
import 'conta_receber_form_screen.dart';
import 'registrar_recebimento_screen.dart';

const _corPago = Color(0xFF4CAF6D);

/// Tela administrativa "Contas a Receber" — todas as cobranças de todos os
/// alunos, com filtro por status (efetivo, considerando vencimento) e por
/// aluno. Cada ação (criar/editar/excluir/receber) respeita sua própria
/// permissão granular — nunca "qualquer staff".
class ContasReceberListScreen extends StatefulWidget {
  const ContasReceberListScreen({
    super.key,
    required this.alunoService,
    required this.caixaService,
    required this.staffAtual,
  });

  final AlunoService alunoService;
  final CaixaService caixaService;
  final AppUser staffAtual;

  @override
  State<ContasReceberListScreen> createState() => _ContasReceberListScreenState();
}

class _ContasReceberListScreenState extends State<ContasReceberListScreen> {
  StatusContaReceber? _filtroStatus;
  String? _filtroAlunoUid;

  bool get _podeCadastrar =>
      PermissionService.has(widget.staffAtual, Permission.cadastrarContasReceber);
  bool get _podeAlterar =>
      PermissionService.has(widget.staffAtual, Permission.alterarContasReceber);
  bool get _podeExcluir =>
      PermissionService.has(widget.staffAtual, Permission.excluirContasReceber);
  bool get _podeReceber =>
      PermissionService.has(widget.staffAtual, Permission.receberContasReceber);

  AppUser? _acharAluno(List<AppUser> alunos, String uid) {
    for (final aluno in alunos) {
      if (aluno.uid == uid) return aluno;
    }
    return null;
  }

  Future<void> _abrirNovaCobranca(BuildContext context, List<AppUser> alunos) async {
    final aluno = await showDialog<AppUser>(
      context: context,
      builder: (context) => _EscolherAlunoDialog(alunos: alunos),
    );
    if (aluno == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContaReceberFormScreen(
          alunoService: widget.alunoService,
          staffAtual: widget.staffAtual,
          alunoPreSelecionado: aluno,
        ),
      ),
    );
  }

  void _abrirEdicao(BuildContext context, AppUser aluno, ContaReceber conta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContaReceberFormScreen(
          alunoService: widget.alunoService,
          staffAtual: widget.staffAtual,
          alunoPreSelecionado: aluno,
          conta: conta,
        ),
      ),
    );
  }

  void _abrirRecebimento(BuildContext context, ContaReceber conta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegistrarRecebimentoScreen(
          alunoService: widget.alunoService,
          caixaService: widget.caixaService,
          staffAtual: widget.staffAtual,
          conta: conta,
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, ContaReceber conta) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cobrança'),
        content: const Text(
          'A cobrança fica marcada como cancelada — o registro e o histórico '
          'continuam existindo, só some das pendências.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('VOLTAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await widget.alunoService.excluirContaReceber(conta.alunoId, conta.id!);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Color _corDoStatus(StatusContaReceber status) {
    switch (status) {
      case StatusContaReceber.pendente:
        return AppColors.gold;
      case StatusContaReceber.pago:
        return _corPago;
      case StatusContaReceber.vencido:
        return AppColors.error;
      case StatusContaReceber.cancelado:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contas a Receber')),
      body: StreamBuilder<List<AppUser>>(
        stream: widget.alunoService.watchAlunos(),
        builder: (context, alunosSnapshot) {
          final alunos = alunosSnapshot.data ?? [];
          return StreamBuilder<List<ContaReceber>>(
            stream: widget.alunoService.watchTodasContasReceber(),
            builder: (context, contasSnapshot) {
              if (contasSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (contasSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        'Erro ao carregar as contas a receber.\n\n${contasSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                );
              }

              var contas = contasSnapshot.data ?? [];
              if (_filtroAlunoUid != null) {
                contas = contas.where((c) => c.alunoId == _filtroAlunoUid).toList();
              }
              if (_filtroStatus != null) {
                contas = contas
                    .where((c) => calcularStatusEfetivo(c) == _filtroStatus)
                    .toList();
              }

              return Column(
                children: [
                  _FiltrosContaReceber(
                    alunos: alunos,
                    filtroStatus: _filtroStatus,
                    filtroAlunoUid: _filtroAlunoUid,
                    onStatusChanged: (status) => setState(() => _filtroStatus = status),
                    onAlunoChanged: (uid) => setState(() => _filtroAlunoUid = uid),
                  ),
                  if (_podeCadastrar)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _abrirNovaCobranca(context, alunos),
                          icon: const Icon(Icons.add),
                          label: const Text('NOVA COBRANÇA'),
                        ),
                      ),
                    ),
                  Expanded(
                    child: contas.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Nenhuma cobrança encontrada.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: contas.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final conta = contas[index];
                              final aluno = _acharAluno(alunos, conta.alunoId);
                              final statusEfetivo = calcularStatusEfetivo(conta);
                              final podeAgir =
                                  statusEfetivo != StatusContaReceber.pago &&
                                  statusEfetivo != StatusContaReceber.cancelado;
                              return _ContaReceberCard(
                                conta: conta,
                                aluno: aluno,
                                statusEfetivo: statusEfetivo,
                                corStatus: _corDoStatus(statusEfetivo),
                                formatarData: _formatarData,
                                onEditar: (aluno != null && _podeAlterar && podeAgir)
                                    ? () => _abrirEdicao(context, aluno, conta)
                                    : null,
                                onExcluir: (_podeExcluir && podeAgir)
                                    ? () => _confirmarExclusao(context, conta)
                                    : null,
                                onReceber: (_podeReceber && podeAgir)
                                    ? () => _abrirRecebimento(context, conta)
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
      ),
    );
  }
}

class _EscolherAlunoDialog extends StatelessWidget {
  const _EscolherAlunoDialog({required this.alunos});

  final List<AppUser> alunos;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escolha o aluno'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: alunos.length,
          itemBuilder: (context, index) {
            final aluno = alunos[index];
            return ListTile(
              title: Text(aluno.nome),
              onTap: () => Navigator.of(context).pop(aluno),
            );
          },
        ),
      ),
    );
  }
}

class _FiltrosContaReceber extends StatelessWidget {
  const _FiltrosContaReceber({
    required this.alunos,
    required this.filtroStatus,
    required this.filtroAlunoUid,
    required this.onStatusChanged,
    required this.onAlunoChanged,
  });

  final List<AppUser> alunos;
  final StatusContaReceber? filtroStatus;
  final String? filtroAlunoUid;
  final ValueChanged<StatusContaReceber?> onStatusChanged;
  final ValueChanged<String?> onAlunoChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<StatusContaReceber?>(
              initialValue: filtroStatus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...StatusContaReceber.values.map(
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
        ],
      ),
    );
  }
}

class _ContaReceberCard extends StatelessWidget {
  const _ContaReceberCard({
    required this.conta,
    required this.aluno,
    required this.statusEfetivo,
    required this.corStatus,
    required this.formatarData,
    required this.onEditar,
    required this.onExcluir,
    required this.onReceber,
  });

  final ContaReceber conta;
  final AppUser? aluno;
  final StatusContaReceber statusEfetivo;
  final Color corStatus;
  final String Function(DateTime) formatarData;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;
  final VoidCallback? onReceber;

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
                  statusEfetivo.label,
                  style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(conta.descricao, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'Vencimento: ${formatarData(conta.vencimento)} · ${formatarReais(conta.valorLiquido)}'
            '${conta.status == StatusContaReceber.pago ? ' · pago em ${formatarData(conta.dataPagamento!)}' : ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (onEditar != null || onExcluir != null || onReceber != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onExcluir != null)
                  TextButton(onPressed: onExcluir, child: const Text('EXCLUIR')),
                if (onEditar != null)
                  TextButton(onPressed: onEditar, child: const Text('EDITAR')),
                if (onReceber != null)
                  TextButton(onPressed: onReceber, child: const Text('RECEBER')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
