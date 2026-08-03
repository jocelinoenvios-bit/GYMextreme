import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../models/permission.dart';
import '../../../services/aluno_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/status_acesso.dart';

/// Situação da mensalidade do aluno + ação da recepção pra confirmar um
/// pagamento recebido fora do app (dinheiro, PIX, cartão, transferência —
/// sem gateway integrado nesta primeira versão; ver [AlunoService.marcarPagamentoRecebido]).
class MensalidadeSection extends StatefulWidget {
  const MensalidadeSection({
    super.key,
    required this.alunoUid,
    required this.proximoVencimento,
    required this.alunoService,
    required this.staffAtual,
  });

  final String alunoUid;
  final DateTime? proximoVencimento;
  final AlunoService alunoService;
  final AppUser staffAtual;

  @override
  State<MensalidadeSection> createState() => _MensalidadeSectionState();
}

class _MensalidadeSectionState extends State<MensalidadeSection> {
  bool _isSaving = false;

  bool get _podeReceber =>
      PermissionService.has(widget.staffAtual, Permission.receberMensalidades);

  Future<void> _escolherVencimentoInicial() async {
    final agora = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: DateTime(agora.year - 1),
      lastDate: DateTime(agora.year + 2),
      helpText: 'Primeiro vencimento',
    );
    if (picked == null) return;
    await _executar(() => widget.alunoService.definirVencimentoInicial(widget.alunoUid, picked));
  }

  Future<void> _marcarPagamentoRecebido() async {
    await _executar(
      () => widget.alunoService.marcarPagamentoRecebido(
        widget.alunoUid,
        vencimentoAtual: widget.proximoVencimento,
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      ),
    );
  }

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() => _isSaving = true);
    try {
      await acao();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mensalidade atualizada.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar. Tente novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _corDoStatus(StatusMensalidade status) {
    switch (status) {
      case StatusMensalidade.emDia:
        return const Color(0xFF4CAF6D);
      case StatusMensalidade.tolerancia:
        return AppColors.gold;
      case StatusMensalidade.bloqueado:
        return AppColors.error;
      case StatusMensalidade.semRegistro:
        return AppColors.textSecondary;
    }
  }

  String _rotuloStatus(StatusAcesso status) {
    switch (status.status) {
      case StatusMensalidade.emDia:
        return 'Em dia';
      case StatusMensalidade.tolerancia:
        return 'Tolerância · restam ${status.diasToleranciaRestantes} dia(s)';
      case StatusMensalidade.bloqueado:
        return 'Bloqueado por atraso';
      case StatusMensalidade.semRegistro:
        return 'Cobrança não configurada';
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = calcularStatusAcesso(proximoVencimento: widget.proximoVencimento);
    final cor = _corDoStatus(status.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _rotuloStatus(status),
              style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.proximoVencimento != null
                ? 'Próximo vencimento: ${_formatarData(widget.proximoVencimento!)}'
                : 'Nenhuma cobrança configurada ainda.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          if (_podeReceber) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : (widget.proximoVencimento == null
                          ? _escolherVencimentoInicial
                          : _marcarPagamentoRecebido),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.proximoVencimento == null
                            ? 'DEFINIR PRIMEIRO VENCIMENTO'
                            : 'MARCAR PAGAMENTO RECEBIDO',
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
