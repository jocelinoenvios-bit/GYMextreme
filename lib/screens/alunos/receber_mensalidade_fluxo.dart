import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/matricula.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/mensalidade_utils.dart';
import '../../utils/moeda.dart';
import '../../widgets/campo_forma_pagamento.dart';

/// "Receber mensalidade", do começo ao fim: pergunta valor (já com o da
/// matrícula ativa) e forma, registra tudo com
/// [AlunoService.receberMensalidade] e avisa o resultado (inclusive "sem
/// caixa aberto" e "sem matrícula ativa, a catraca não libera").
///
/// Usado na ficha do aluno (Dados pessoais → Mensalidade) e em Contas a
/// receber — um fluxo só, pra recepção receber igual nos dois lugares.
/// Devolve o resultado, ou null se cancelou ou deu erro.
Future<RecebimentoMensalidade?> receberMensalidadeFluxo(
  BuildContext context, {
  required AlunoService alunoService,
  required String alunoUid,
  String? alunoNome,
  required DateTime? proximoVencimento,
  required AppUser staff,
  ValueChanged<bool>? onSalvando,
  /// Aluno inativo voltando: só fica ativo de novo se o pagamento for
  /// registrado, e o vencimento conta a partir de hoje.
  bool reativar = false,
}) async {
  final avisos = ScaffoldMessenger.of(context);
  final matriculas = await alunoService.watchMatriculas(alunoUid).first;
  final ativa = matriculas.where((m) => m.status == StatusMatricula.ativa).firstOrNull;
  if (!context.mounted) return null;

  final dados = await showDialog<(double, String)>(
    context: context,
    builder: (_) => DialogoReceberMensalidade(
      alunoNome: alunoNome,
      valorSugerido: ativa?.valorContratado,
      vencimentoAtual: reativar ? null : proximoVencimento,
      reativar: reativar,
    ),
  );
  if (dados == null || !context.mounted) return null;
  final (valor, forma) = dados;

  RecebimentoMensalidade resultado;
  onSalvando?.call(true);
  try {
    resultado = await alunoService.receberMensalidade(
      alunoUid,
      vencimentoAtual: proximoVencimento,
      valor: valor,
      formaPagamento: forma,
      staffUid: staff.uid,
      staffNome: staff.nome,
      alunoNome: alunoNome,
      reativar: reativar,
    );
  } catch (_) {
    avisos.showSnackBar(
      SnackBar(
        content: const Text('Erro ao receber a mensalidade. Tente novamente.'),
        backgroundColor: AppColors.error,
      ),
    );
    return null;
  } finally {
    onSalvando?.call(false);
  }

  final base = '${reativar ? 'Aluno reativado. ' : ''}'
      'Mensalidade recebida${alunoNome == null ? '' : ' de $alunoNome'}: '
      '${formatarReais(valor)} ($forma). '
      'Próximo vencimento: ${_data(resultado.novoVencimento)}.';
  avisos.showSnackBar(
    SnackBar(
      content: Text(
        resultado.lancadoNoCaixa
            ? base
            : '$base Nenhum caixa aberto: ficou em Contas a receber, fora do caixa.',
      ),
    ),
  );

  if (!resultado.temMatricula && context.mounted) {
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
  return resultado;
}

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Janela do "Receber mensalidade": valor (já com o da matrícula) e forma
/// de pagamento. Devolve (valor, forma) ou null se cancelar.
class DialogoReceberMensalidade extends StatefulWidget {
  const DialogoReceberMensalidade({
    super.key,
    required this.valorSugerido,
    required this.vencimentoAtual,
    this.alunoNome,
    this.reativar = false,
  });

  final double? valorSugerido;
  final DateTime? vencimentoAtual;

  /// Mostrado no topo quando a janela é aberta fora da ficha (ex.: Contas
  /// a receber), pra não haver dúvida de quem está pagando.
  final String? alunoNome;

  /// Reativação: título próprio e o ciclo começando hoje.
  final bool reativar;

  @override
  State<DialogoReceberMensalidade> createState() => _DialogoReceberMensalidadeState();
}

class _DialogoReceberMensalidadeState extends State<DialogoReceberMensalidade> {
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
      title: Text(widget.reativar ? 'Reativar e receber' : 'Receber mensalidade'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.alunoNome != null) ...[
                Text(
                  widget.alunoNome!,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                widget.reativar
                    ? 'O aluno volta a ficar ativo ao confirmar o pagamento.\n'
                        'Próximo vencimento: ${_data(adicionarUmMes(atual))}'
                    : 'Vencimento atual: ${_data(atual)}\n'
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
