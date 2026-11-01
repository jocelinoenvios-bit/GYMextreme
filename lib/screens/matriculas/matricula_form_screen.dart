import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/plano.dart';
import '../../services/aluno_service.dart';
import '../../services/plano_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import '../../widgets/escolher_aluno.dart';
import '../../widgets/campo_forma_pagamento.dart';

/// Cria uma matrícula nova. Também usada pro fluxo de "renovar" — nesse
/// caso o chamador já resolveu o aluno/plano/valor atuais (a lista de
/// matrículas já tem essa informação em mãos) e passa em
/// [alunoPreSelecionado]/[planoPreSelecionado]/[valorPreSelecionado], só
/// trocando o período. `AlunoService.criarMatricula` encerra sozinho
/// qualquer matrícula anterior que ainda estivesse ativa.
class MatriculaFormScreen extends StatefulWidget {
  const MatriculaFormScreen({
    super.key,
    required this.alunoService,
    required this.planoService,
    this.alunoPreSelecionado,
    this.planoPreSelecionado,
    this.valorPreSelecionado,
  });

  final AlunoService alunoService;
  final PlanoService planoService;
  final AppUser? alunoPreSelecionado;
  final Plano? planoPreSelecionado;
  final double? valorPreSelecionado;

  bool get _ehRenovacao => alunoPreSelecionado != null;

  @override
  State<MatriculaFormScreen> createState() => _MatriculaFormScreenState();
}

class _MatriculaFormScreenState extends State<MatriculaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _valorController = TextEditingController(
    text: _textoValorInicial(),
  );
  final _formaPagamentoController = TextEditingController();
  final _observacaoController = TextEditingController();

  AppUser? _alunoSelecionado;
  Plano? _planoSelecionado;
  late DateTime _dataInicio;
  late DateTime _dataVencimento;
  bool _isSaving = false;

  String? _textoValorInicial() {
    final valor =
        widget.valorPreSelecionado ?? widget.planoPreSelecionado?.valor;
    if (valor == null) return null;
    return formatarReais(valor).replaceFirst('R\$ ', '');
  }

  @override
  void initState() {
    super.initState();
    _alunoSelecionado = widget.alunoPreSelecionado;
    _planoSelecionado = widget.planoPreSelecionado;
    _dataInicio = DateTime.now();
    _dataVencimento = _calcularVencimento(
      _dataInicio,
      widget.planoPreSelecionado,
    );
  }

  @override
  void dispose() {
    _valorController.dispose();
    _formaPagamentoController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  DateTime _calcularVencimento(DateTime inicio, Plano? plano) {
    if (plano == null) return inicio;
    return inicio.add(Duration(days: plano.duracaoDias));
  }

  void _selecionarPlano(Plano plano) {
    setState(() {
      _planoSelecionado = plano;
      _dataVencimento = _calcularVencimento(_dataInicio, plano);
      _valorController.text = formatarReais(
        plano.valor,
      ).replaceFirst('R\$ ', '');
    });
  }

  Future<void> _escolherData({required bool inicio}) async {
    final atual = inicio ? _dataInicio : _dataVencimento;
    final picked = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(atual.year - 1),
      lastDate: DateTime(atual.year + 3),
      helpText: inicio ? 'Início da matrícula' : 'Vencimento da matrícula',
    );
    if (picked == null) return;
    setState(() {
      if (inicio) {
        _dataInicio = picked;
      } else {
        _dataVencimento = picked;
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_alunoSelecionado == null) {
      _showError('Selecione o aluno.');
      return;
    }
    if (_planoSelecionado == null) {
      _showError('Selecione o plano.');
      return;
    }
    if (_dataVencimento.isBefore(_dataInicio)) {
      _showError('O vencimento não pode ser antes do início.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.alunoService.criarMatricula(
        _alunoSelecionado!.uid,
        planoId: _planoSelecionado!.id!,
        dataInicio: _dataInicio,
        dataVencimento: _dataVencimento,
        valorContratado: parseValorReais(_valorController.text)!,
        formaPagamento: _formaPagamentoController.text.trim().isEmpty
            ? null
            : _formaPagamentoController.text.trim(),
        observacao: _observacaoController.text.trim().isEmpty
            ? null
            : _observacaoController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Erro ao salvar a matrícula. Tente novamente.');
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
      appBar: AppBar(
        title: Text(
          widget._ehRenovacao ? 'Renovar matrícula' : 'Nova matrícula',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget._ehRenovacao) ...[
                  Text(
                    widget.alunoPreSelecionado!.nome,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A matrícula ativa atual (se houver) é encerrada '
                    'automaticamente ao confirmar.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  StreamBuilder<List<AppUser>>(
                    stream: widget.alunoService.watchAlunos(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(
                            color: AppColors.gold,
                          ),
                        );
                      }

                      // Escolha com pesquisa (CampoAluno), e não dropdown:
                      // com muita gente cadastrada a lista corrida fica
                      // inutilizável. O campo trabalha pelo uid — se o
                      // aluno escolhido sumir da lista (excluído com a tela
                      // aberta), ele só volta a ficar vazio.
                      return CampoAluno(
                        alunos: snapshot.data ?? const <AppUser>[],
                        uidSelecionado: _alunoSelecionado?.uid,
                        onChanged: (aluno) =>
                            setState(() => _alunoSelecionado = aluno),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                StreamBuilder<List<Plano>>(
                  stream: widget.planoService.watchPlanos(),
                  builder: (context, snapshot) {
                    // Mesmo motivo do dropdown de aluno acima: o valor é o
                    // id (String), e não o Plano. Plano não tem == própria,
                    // então quando a lista chegava de novo (o que acontece
                    // a cada rebuild — escolher o aluno depois do plano já
                    // bastava) o plano selecionado era outra instância e o
                    // dropdown quebrava com "Either zero or 2 or more
                    // DropdownMenuItems". Também é o que deixa a renovação
                    // abrir com o plano pré-selecionado sem quebrar.
                    final planosPorId = <String, Plano>{};
                    for (final plano in snapshot.data ?? const <Plano>[]) {
                      final id = plano.id;
                      if (id == null) continue;
                      if (plano.ativo || id == _planoSelecionado?.id) {
                        planosPorId[id] = plano;
                      }
                    }
                    final planos = planosPorId.values.toList();
                    final idSelecionado =
                        planosPorId.containsKey(_planoSelecionado?.id)
                        ? _planoSelecionado?.id
                        : null;

                    return DropdownButtonFormField<String>(
                      initialValue: idSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Plano'),
                      items: planos
                          .map(
                            (plano) => DropdownMenuItem(
                              value: plano.id,
                              child: Text(
                                plano.nome,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        final plano = planosPorId[id];
                        if (plano != null) _selecionarPlano(plano);
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Início'),
                  subtitle: Text(_formatarData(_dataInicio)),
                  trailing: Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.gold,
                  ),
                  onTap: () => _escolherData(inicio: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vencimento'),
                  subtitle: Text(_formatarData(_dataVencimento)),
                  trailing: Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.gold,
                  ),
                  onTap: () => _escolherData(inicio: false),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor contratado (R\$)',
                  ),
                  validator: (value) {
                    final valor = parseValorReais(value ?? '');
                    if (valor == null) return 'Informe um valor válido.';
                    if (valor <= 0) return 'O valor deve ser maior que zero.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                CampoFormaPagamento(controller: _formaPagamentoController),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _observacaoController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.black,
                          ),
                        )
                      : Text(
                          widget._ehRenovacao
                              ? 'CONFIRMAR RENOVAÇÃO'
                              : 'CRIAR MATRÍCULA',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
