import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../models/historico_treino.dart';
import '../../../models/permission.dart';
import '../../../models/treino.dart';
import '../../../services/aluno_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_colors.dart';
import '../../area_aluno/treino_execucao_screen.dart';
import '../treino_form_screen.dart';
import '../copiar_treino_dialog.dart';

/// Fichas de treino do aluno (Treino A, B, C...) — cada card abre pra
/// editar; o professor cria, edita, exclui ou duplica um treino, copia
/// um treino ja pronto de outro aluno, ou executa o treino (mesmo fluxo
/// real que o aluno usa, útil pra revisar antes de liberar).
class TreinosTab extends StatelessWidget {
  const TreinosTab({
    super.key,
    required this.uid,
    required this.alunoService,
    required this.staffAtual,
  });

  final String uid;
  final AlunoService alunoService;
  final AppUser staffAtual;

  bool get _podeCriar => PermissionService.has(staffAtual, Permission.criarTreinos);
  bool get _podeEditar => PermissionService.has(staffAtual, Permission.editarTreinos);

  void _abrirNovoTreino(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TreinoFormScreen(
          alunoUid: uid,
          alunoService: alunoService,
          staffAtual: staffAtual,
        ),
      ),
    );
  }

  void _abrirCopiarTreino(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CopiarTreinoDialog(
        alunoDestinoUid: uid,
        alunoService: alunoService,
        staffAtual: staffAtual,
      ),
    );
  }

  void _abrirRegistrarPresenca(BuildContext context, Treino treino) {
    showDialog(
      context: context,
      builder: (_) => _RegistrarPresencaDialog(
        uid: uid,
        alunoService: alunoService,
        staffAtual: staffAtual,
        treino: treino,
      ),
    );
  }

  void _abrirMenuNovo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.gold),
              title: const Text('Criar treino novo'),
              onTap: () {
                Navigator.of(context).pop();
                _abrirNovoTreino(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined, color: AppColors.gold),
              title: const Text('Copiar treino de outro aluno'),
              onTap: () {
                Navigator.of(context).pop();
                _abrirCopiarTreino(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _podeCriar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirMenuNovo(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo treino'),
            )
          : null,
      body: StreamBuilder<List<Treino>>(
        stream: alunoService.watchTreinos(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erro ao carregar os treinos.',
                style: TextStyle(color: AppColors.error),
              ),
            );
          }

          final treinos = snapshot.data ?? [];
          if (treinos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _podeCriar
                      ? 'Nenhum treino cadastrado ainda. Toque em "+" para criar o primeiro.'
                      : 'Nenhum treino cadastrado ainda.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: treinos.length,
            itemBuilder: (context, index) => _TreinoCard(
              treino: treinos[index],
              podeEditar: _podeEditar,
              onRegistrarPresenca: _podeEditar && treinos[index].id != null
                  ? () => _abrirRegistrarPresenca(context, treinos[index])
                  : null,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TreinoFormScreen(
                    alunoUid: uid,
                    alunoService: alunoService,
                    staffAtual: staffAtual,
                    treino: treinos[index],
                  ),
                ),
              ),
              onExecutar: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TreinoExecucaoScreen(
                    alunoUid: uid,
                    treinoId: treinos[index].id!,
                  ),
                ),
              ),
              onDuplicar: () => alunoService.duplicarTreino(
                uid,
                treinos[index],
                staffUid: staffAtual.uid,
                staffNome: staffAtual.nome,
              ),
              onExcluir: () => alunoService.excluirTreino(uid, treinos[index].id!),
            ),
          );
        },
      ),
    );
  }
}

class _TreinoCard extends StatelessWidget {
  const _TreinoCard({
    required this.treino,
    required this.podeEditar,
    required this.onTap,
    required this.onExecutar,
    required this.onDuplicar,
    required this.onExcluir,
    this.onRegistrarPresenca,
  });

  final Treino treino;
  final bool podeEditar;
  final VoidCallback onTap;
  final VoidCallback onExecutar;
  final VoidCallback onDuplicar;
  final VoidCallback onExcluir;

  /// Nulo quando o staff não tem permissão de editar treinos, ou quando
  /// o treino ainda não foi salvo (sem id) — sem isso não há como
  /// vincular um `HistoricoTreino.treinoId`.
  final VoidCallback? onRegistrarPresenca;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.gold,
          child: Text(
            treino.letra,
            style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(treino.nome),
        subtitle: Text(
          [
            if (treino.grupoMuscular != null && treino.grupoMuscular!.isNotEmpty)
              treino.grupoMuscular!,
            '${treino.exercicios.length} exercício(s)',
          ].join(' • '),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Executar treino',
              icon: const Icon(Icons.play_circle_outline, color: AppColors.gold),
              onPressed: onExecutar,
            ),
            if (podeEditar)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (acao) {
                  if (acao == 'presenca') onRegistrarPresenca?.call();
                  if (acao == 'duplicar') onDuplicar();
                  if (acao == 'excluir') onExcluir();
                },
                itemBuilder: (context) => [
                  if (onRegistrarPresenca != null)
                    const PopupMenuItem(
                      value: 'presenca',
                      child: Text('Registrar presença/falta'),
                    ),
                  const PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
                  const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                ],
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Diálogo pra staff registrar presença/falta num dia específico — nunca
/// disparado pelo próprio aluno (ver `firestore.rules`, que bloqueia
/// escrita em `historicoTreinos` pra quem não tem `criarTreinos`/
/// `editarTreinos`). A ficha prescrita (`Treino`) não é afetada por
/// este registro; ele só alimenta o histórico de frequência.
class _RegistrarPresencaDialog extends StatefulWidget {
  const _RegistrarPresencaDialog({
    required this.uid,
    required this.alunoService,
    required this.staffAtual,
    required this.treino,
  });

  final String uid;
  final AlunoService alunoService;
  final AppUser staffAtual;
  final Treino treino;

  @override
  State<_RegistrarPresencaDialog> createState() => _RegistrarPresencaDialogState();
}

class _RegistrarPresencaDialogState extends State<_RegistrarPresencaDialog> {
  late DateTime _data = DateTime.now();
  StatusHistoricoTreino _status = StatusHistoricoTreino.realizado;
  final _observacoesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(agora.year - 1),
      lastDate: agora,
    );
    if (data != null) setState(() => _data = data);
  }

  Future<void> _confirmar() async {
    setState(() => _isSaving = true);
    try {
      await widget.alunoService.registrarHistoricoTreino(
        widget.uid,
        HistoricoTreino(
          treinoId: widget.treino.id!,
          data: DateTime(_data.year, _data.month, _data.day),
          diaSemana: _data.weekday,
          status: _status,
          observacoes: _observacoesController.text.trim().isEmpty
              ? null
              : _observacoesController.text.trim(),
        ),
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Presença — Treino ${widget.treino.letra}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _selecionarData,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                '${_data.day.toString().padLeft(2, '0')}/'
                '${_data.month.toString().padLeft(2, '0')}/${_data.year}'
                ' (${diasSemanaLabels[_data.weekday]})',
              ),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<StatusHistoricoTreino>(
            segments: const [
              ButtonSegment(
                value: StatusHistoricoTreino.realizado,
                label: Text('Realizado'),
              ),
              ButtonSegment(value: StatusHistoricoTreino.falta, label: Text('Falta')),
            ],
            selected: {_status},
            onSelectionChanged: (selecao) => setState(() => _status = selecao.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _observacoesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Observações (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _confirmar,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                )
              : const Text('SALVAR'),
        ),
      ],
    );
  }
}
