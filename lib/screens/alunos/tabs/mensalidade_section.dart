import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/app_user.dart';
import '../../../models/matricula.dart';
import '../../../models/permission.dart';
import '../../../services/aluno_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/campo_forma_pagamento.dart';
import '../../../utils/mensalidade_utils.dart';
import '../../../utils/moeda.dart';
import '../../../utils/status_acesso.dart';
import '../../../utils/whatsapp.dart';

/// Situação da mensalidade do aluno + ação da recepção pra confirmar um
/// pagamento recebido fora do app (dinheiro, PIX, cartão, transferência —
/// sem gateway integrado nesta primeira versão; ver [AlunoService.marcarPagamentoRecebido]).
class MensalidadeSection extends StatefulWidget {
  const MensalidadeSection({
    super.key,
    required this.alunoUid,
    this.alunoNome,
    required this.proximoVencimento,
    this.dataInicio,
    required this.alunoService,
    required this.staffAtual,
    this.whatsapp,
    this.ativo = true,
    this.dataInativacao,
    this.dataReativacao,
  });

  final String alunoUid;

  /// Vai na descrição do lançamento no caixa ("Mensalidade — Nome").
  final String? alunoNome;
  final DateTime? proximoVencimento;

  /// Base da sugestão de vencimento pra aluno antigo, cadastrado antes do
  /// vencimento automático: 1 mês depois do início (ver
  /// [_escolherVencimentoInicial]).
  final DateTime? dataInicio;
  final AlunoService alunoService;
  final AppUser staffAtual;

  /// `Aluno.ativo` — quando `false`, esta seção mostra o selo "Inativo"
  /// (ciclo de inadimplência chegou aos 30 dias, ou inativação manual)
  /// em vez do status normal de mensalidade, e troca a ação disponível
  /// por "Reativar aluno" (ver `AlunoService.reativarAluno`).
  final bool ativo;
  final DateTime? dataInativacao;
  final DateTime? dataReativacao;

  /// Número de WhatsApp cadastrado na ficha do aluno (só dígitos, sem
  /// código do país) — quando presente e a mensalidade não está em dia,
  /// mostra o botão "Chamar no WhatsApp" (ver [linkWhatsapp]).
  final String? whatsapp;

  @override
  State<MensalidadeSection> createState() => _MensalidadeSectionState();
}

class _MensalidadeSectionState extends State<MensalidadeSection> {
  bool _isSaving = false;

  bool get _podeReceber =>
      PermissionService.has(widget.staffAtual, Permission.receberMensalidades);

  Future<void> _escolherVencimentoInicial() async {
    final agora = DateTime.now();
    final primeiro = DateTime(agora.year - 1);
    final ultimo = DateTime(agora.year + 2);
    // Já vem sugerido do mesmo jeito que no cadastro novo: 1 mês depois
    // do início — é só confirmar.
    var sugerido = primeiroVencimento(widget.dataInicio ?? agora);
    if (sugerido.isBefore(primeiro) || sugerido.isAfter(ultimo)) {
      sugerido = primeiroVencimento(agora);
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: sugerido,
      firstDate: primeiro,
      lastDate: ultimo,
      helpText: 'Primeiro vencimento',
    );
    if (picked == null) return;
    await _executar(() => widget.alunoService.definirVencimentoInicial(widget.alunoUid, picked));
  }

  /// "Receber mensalidade": pergunta valor e forma, e o serviço registra
  /// tudo de uma vez (cobrança paga, caixa, vencimento, matrícula) — ver
  /// [AlunoService.receberMensalidade].
  Future<void> _receberMensalidade() async {
    final matriculas = await widget.alunoService.watchMatriculas(widget.alunoUid).first;
    final ativa = matriculas.where((m) => m.status == StatusMatricula.ativa).firstOrNull;
    if (!mounted) return;

    final dados = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _DialogoReceberMensalidade(
        valorSugerido: ativa?.valorContratado,
        vencimentoAtual: widget.proximoVencimento,
      ),
    );
    if (dados == null || !mounted) return;
    final (valor, forma) = dados;

    RecebimentoMensalidade? resultado;
    await _executar(
      () async {
        resultado = await widget.alunoService.receberMensalidade(
          widget.alunoUid,
          vencimentoAtual: widget.proximoVencimento,
          valor: valor,
          formaPagamento: forma,
          staffUid: widget.staffAtual.uid,
          staffNome: widget.staffAtual.nome,
          alunoNome: widget.alunoNome,
        );
      },
      sucesso: () {
        final r = resultado!;
        final base = 'Mensalidade recebida: ${formatarReais(valor)} ($forma). '
            'Próximo vencimento: ${_formatarData(r.novoVencimento)}.';
        return r.lancadoNoCaixa
            ? base
            : '$base Nenhum caixa aberto: ficou em Contas a receber, fora do caixa.';
      },
    );

    if (resultado != null && !resultado!.temMatricula && mounted) {
      // Recebido, mas sem matrícula ativa a catraca nega a entrada — a
      // recepção precisa saber na hora.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aluno sem matrícula ativa'),
          content: const Text(
            'A mensalidade foi recebida, mas este aluno não tem matrícula ativa. '
            'A catraca não vai liberar a entrada até ser feita uma matrícula '
            '(tela Matrículas → Nova matrícula).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ENTENDI'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _reativarAluno() async {
    await _executar(
      () => widget.alunoService.reativarAluno(
        widget.alunoUid,
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      ),
    );
  }

  Future<void> _chamarNoWhatsapp() async {
    final whatsapp = widget.whatsapp;
    if (whatsapp == null || whatsapp.isEmpty) return;
    final uri = Uri.parse(linkWhatsapp(whatsapp));
    var abriu = false;
    try {
      abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      abriu = false;
    }
    if (!abriu && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível abrir o WhatsApp.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// [sucesso] troca a mensagem padrão de sucesso; devolvendo `null`, não
  /// mostra nenhuma (quem chamou vai avisar de outro jeito).
  Future<void> _executar(
    Future<void> Function() acao, {
    String? Function()? sucesso,
  }) async {
    setState(() => _isSaving = true);
    try {
      await acao();
      final mensagem = sucesso == null ? 'Mensalidade atualizada.' : sucesso();
      if (mounted && mensagem != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagem)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
        return 'Inadimplente · ${status.diasAtraso} dia(s) de atraso';
      case StatusMensalidade.semRegistro:
        return 'Cobrança não configurada';
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Widget _badge(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildInativo(BuildContext context) {
    final cor = AppColors.textSecondary;
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
          _badge('Inativo', cor),
          const SizedBox(height: 10),
          Text(
            widget.dataInativacao != null
                ? 'Inativo desde ${_formatarData(widget.dataInativacao!)}'
                : 'Inativo.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          if (widget.dataReativacao != null) ...[
            const SizedBox(height: 4),
            Text(
              'Última reativação: ${_formatarData(widget.dataReativacao!)}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ],
          if (_podeReceber) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSaving ? null : _reativarAluno,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('REATIVAR ALUNO'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ativo) return _buildInativo(context);

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
          _badge(_rotuloStatus(status), cor),
          const SizedBox(height: 10),
          Text(
            widget.proximoVencimento != null
                ? 'Próximo vencimento: ${_formatarData(widget.proximoVencimento!)}'
                : 'Nenhuma cobrança configurada ainda.',
            style: TextStyle(color: AppColors.textPrimary),
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
                          : _receberMensalidade),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.proximoVencimento == null
                            ? 'DEFINIR PRIMEIRO VENCIMENTO'
                            : 'RECEBER MENSALIDADE',
                      ),
              ),
            ),
          ],
          if (widget.whatsapp != null &&
              widget.whatsapp!.isNotEmpty &&
              (status.status == StatusMensalidade.tolerancia ||
                  status.status == StatusMensalidade.bloqueado)) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _chamarNoWhatsapp,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('CHAMAR NO WHATSAPP'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Janela do "Receber mensalidade": valor (já com o da matrícula) e forma
/// de pagamento. Devolve (valor, forma) ou null se cancelar.
class _DialogoReceberMensalidade extends StatefulWidget {
  const _DialogoReceberMensalidade({required this.valorSugerido, required this.vencimentoAtual});

  final double? valorSugerido;
  final DateTime? vencimentoAtual;

  @override
  State<_DialogoReceberMensalidade> createState() => _DialogoReceberMensalidadeState();
}

class _DialogoReceberMensalidadeState extends State<_DialogoReceberMensalidade> {
  final _formKey = GlobalKey<FormState>();
  late final _valor = TextEditingController(
    text: widget.valorSugerido == null
        ? ''
        : formatarReais(widget.valorSugerido!).replaceFirst('R\$ ', ''),
  );
  final _forma = TextEditingController();

  @override
  void dispose() {
    _valor.dispose();
    _forma.dispose();
    super.dispose();
  }

  String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((parseValorReais(_valor.text)!, _forma.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final atual = widget.vencimentoAtual ?? DateTime(hoje.year, hoje.month, hoje.day);
    return AlertDialog(
      title: const Text('Receber mensalidade'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vencimento atual: ${_data(atual)}\n'
                'Próximo vencimento: ${_data(adicionarUmMes(atual))}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valor,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor recebido (R\$)'),
                validator: (texto) {
                  final valor = parseValorReais(texto ?? '');
                  if (valor == null) return 'Informe um valor válido.';
                  if (valor <= 0) return 'O valor deve ser maior que zero.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              CampoFormaPagamento(controller: _forma, obrigatorio: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCELAR')),
        TextButton(onPressed: _confirmar, child: const Text('CONFIRMAR')),
      ],
    );
  }
}
