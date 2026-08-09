import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/conta_receber.dart';
import '../../models/matricula.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';

/// Cria uma cobrança nova ou edita uma existente (passe [conta] para
/// entrar no modo edição). [alunoPreSelecionado] é sempre obrigatório —
/// quem abre esta tela (lista global) já resolveu o aluno, seja porque o
/// usuário escolheu no diálogo "Nova cobrança", seja porque é o dono da
/// [conta] sendo editada.
///
/// Integração com Matrícula: se o aluno tiver matrículas, um segundo
/// dropdown opcional deixa escolher uma — ao selecionar, preenche
/// descrição/valor/vencimento a partir dela (mesmo padrão de
/// `MatriculaFormScreen` preenchendo valor a partir do `Plano`). O
/// vínculo (`matriculaId`) é só uma referência; nada da matrícula é
/// duplicado além do que foi copiado nesse instante.
class ContaReceberFormScreen extends StatefulWidget {
  const ContaReceberFormScreen({
    super.key,
    required this.alunoService,
    required this.staffAtual,
    required this.alunoPreSelecionado,
    this.conta,
  });

  final AlunoService alunoService;
  final AppUser staffAtual;
  final AppUser alunoPreSelecionado;
  final ContaReceber? conta;

  bool get _ehEdicao => conta != null;

  @override
  State<ContaReceberFormScreen> createState() => _ContaReceberFormScreenState();
}

class _ContaReceberFormScreenState extends State<ContaReceberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _descricaoController = TextEditingController(text: widget.conta?.descricao);
  late final _valorController = TextEditingController(
    text: widget.conta != null
        ? formatarReais(widget.conta!.valorOriginal).replaceFirst('R\$ ', '')
        : null,
  );
  late final _descontoController = TextEditingController(
    text: formatarReais(widget.conta?.desconto ?? 0).replaceFirst('R\$ ', ''),
  );
  late final _jurosMultaController = TextEditingController(
    text: formatarReais(widget.conta?.jurosMulta ?? 0).replaceFirst('R\$ ', ''),
  );
  late final _formaPagamentoController = TextEditingController(
    text: widget.conta?.formaPagamento,
  );
  late final _observacaoController = TextEditingController(text: widget.conta?.observacao);

  Matricula? _matriculaSelecionada;
  late DateTime _vencimento;
  bool _isSaving = false;

  bool get _podeEditar =>
      widget.conta == null ||
      (widget.conta!.status != StatusContaReceber.pago &&
          widget.conta!.status != StatusContaReceber.cancelado);

  @override
  void initState() {
    super.initState();
    _vencimento = widget.conta?.vencimento ?? DateTime.now();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _descontoController.dispose();
    _jurosMultaController.dispose();
    _formaPagamentoController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Matricula? _acharMatricula(List<Matricula> matriculas) {
    if (widget.conta?.matriculaId == null) return null;
    for (final matricula in matriculas) {
      if (matricula.id == widget.conta!.matriculaId) return matricula;
    }
    return null;
  }

  void _selecionarMatricula(Matricula? matricula) {
    setState(() {
      _matriculaSelecionada = matricula;
      if (matricula == null) return;
      _descricaoController.text = 'Mensalidade';
      _valorController.text = formatarReais(matricula.valorContratado).replaceFirst('R\$ ', '');
      _vencimento = matricula.dataVencimento;
      if (matricula.formaPagamento != null) {
        _formaPagamentoController.text = matricula.formaPagamento!;
      }
    });
  }

  Future<void> _escolherVencimento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vencimento,
      firstDate: DateTime(_vencimento.year - 1),
      lastDate: DateTime(_vencimento.year + 3),
      helpText: 'Vencimento',
    );
    if (picked == null) return;
    setState(() => _vencimento = picked);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = parseValorReais(_valorController.text)!;
    final desconto = parseValorReais(_descontoController.text) ?? 0;
    final jurosMulta = parseValorReais(_jurosMultaController.text) ?? 0;
    final formaPagamento = _formaPagamentoController.text.trim().isEmpty
        ? null
        : _formaPagamentoController.text.trim();
    final observacao = _observacaoController.text.trim().isEmpty
        ? null
        : _observacaoController.text.trim();

    setState(() => _isSaving = true);
    try {
      if (widget._ehEdicao) {
        await widget.alunoService.atualizarContaReceber(
          widget.alunoPreSelecionado.uid,
          widget.conta!.id!,
          matriculaId: _matriculaSelecionada?.id ?? widget.conta!.matriculaId,
          descricao: _descricaoController.text.trim(),
          valorOriginal: valor,
          desconto: desconto,
          jurosMulta: jurosMulta,
          vencimento: _vencimento,
          observacao: observacao,
        );
      } else {
        await widget.alunoService.criarContaReceber(
          widget.alunoPreSelecionado.uid,
          matriculaId: _matriculaSelecionada?.id,
          descricao: _descricaoController.text.trim(),
          valorOriginal: valor,
          desconto: desconto,
          jurosMulta: jurosMulta,
          vencimento: _vencimento,
          formaPagamento: formaPagamento,
          observacao: observacao,
          staffUid: widget.staffAtual.uid,
          staffNome: widget.staffAtual.nome,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Erro ao salvar a cobrança. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget._ehEdicao ? 'Editar cobrança' : 'Nova cobrança')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.alunoPreSelecionado.nome,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<Matricula>>(
                  stream: widget.alunoService.watchMatriculas(widget.alunoPreSelecionado.uid),
                  builder: (context, snapshot) {
                    final matriculas = snapshot.data ?? [];
                    if (matriculas.isEmpty) return const SizedBox.shrink();
                    final selecionada = _matriculaSelecionada ?? _acharMatricula(matriculas);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<Matricula?>(
                          initialValue: selecionada,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Gerar a partir de uma matrícula (opcional)',
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Nenhuma')),
                            ...matriculas.map(
                              (matricula) => DropdownMenuItem(
                                value: matricula,
                                child: Text(
                                  '${_formatarData(matricula.dataVencimento)} · '
                                  '${formatarReais(matricula.valorContratado)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: _podeEditar ? _selecionarMatricula : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                    );
                  },
                ),
                TextFormField(
                  controller: _descricaoController,
                  enabled: _podeEditar,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe a descrição.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _valorController,
                  enabled: _podeEditar,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor original (R\$)'),
                  validator: (value) {
                    final valor = parseValorReais(value ?? '');
                    if (valor == null) return 'Informe um valor válido.';
                    if (valor <= 0) return 'O valor deve ser maior que zero.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _descontoController,
                        enabled: _podeEditar,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Desconto (R\$)'),
                        validator: (value) =>
                            parseValorReais(value ?? '0') == null ? 'Valor inválido.' : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _jurosMultaController,
                        enabled: _podeEditar,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Juros/multa (R\$)'),
                        validator: (value) =>
                            parseValorReais(value ?? '0') == null ? 'Valor inválido.' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vencimento'),
                  subtitle: Text(_formatarData(_vencimento)),
                  trailing: const Icon(Icons.calendar_today_outlined, color: AppColors.gold),
                  onTap: _podeEditar ? _escolherVencimento : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _formaPagamentoController,
                  enabled: _podeEditar,
                  decoration: const InputDecoration(labelText: 'Forma de pagamento (opcional)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _observacaoController,
                  enabled: _podeEditar,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observação (opcional)'),
                ),
                const SizedBox(height: 20),
                if (_podeEditar)
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.black,
                            ),
                          )
                        : Text(widget._ehEdicao ? 'SALVAR ALTERAÇÕES' : 'CRIAR COBRANÇA'),
                  )
                else
                  const Text(
                    'Cobranças pagas ou canceladas não podem mais ser editadas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
