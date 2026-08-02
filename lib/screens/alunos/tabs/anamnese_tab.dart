import 'package:flutter/material.dart';

import '../../../models/anamnese.dart';
import '../../../services/aluno_service.dart';
import '../../../theme/app_colors.dart';

/// Replica a ficha "ANAMNESE" em papel, pergunta a pergunta (01 a 13).
class AnamneseTab extends StatefulWidget {
  const AnamneseTab({super.key, required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  @override
  State<AnamneseTab> createState() => _AnamneseTabState();
}

class _AnamneseTabState extends State<AnamneseTab> {
  bool _isLoaded = false;
  bool _isSaving = false;

  int? _diasPorSemana;
  ObjetivoTreino? _objetivo;
  SituacaoMusculacao? _situacaoMusculacao;
  final _tempoParadoController = TextEditingController();
  bool? _problemaColunaJoelho;
  final _problemaColunaJoelhoQualController = TextEditingController();
  NivelPressaoArterial? _pressaoArterial;
  final Set<String> _condicoesClinicas = {};
  bool? _alergia;
  final _alergiaQualController = TextEditingController();
  bool? _doresCorpo;
  final _doresCorpoQualController = TextEditingController();
  bool? _lesaoOsteoMuscular;
  final _lesaoOsteoMuscularQualController = TextEditingController();
  bool? _cirurgiaRecente;
  final _cirurgiaRecenteDeQueController = TextEditingController();
  bool? _usaMedicamento;
  final _usaMedicamentoQualController = TextEditingController();
  final Set<String> _usoSubstancias = {};
  bool? _fazendoDieta;
  bool? _dietaPorContaPropria;
  bool? _dietaOrientacaoNutricionista;
  DateTime? _respondidoEm;

  @override
  void dispose() {
    _tempoParadoController.dispose();
    _problemaColunaJoelhoQualController.dispose();
    _alergiaQualController.dispose();
    _doresCorpoQualController.dispose();
    _lesaoOsteoMuscularQualController.dispose();
    _cirurgiaRecenteDeQueController.dispose();
    _usaMedicamentoQualController.dispose();
    super.dispose();
  }

  void _preencherSeNecessario(Anamnese? a) {
    if (_isLoaded || a == null) return;
    _isLoaded = true;
    _diasPorSemana = a.diasPorSemana;
    _objetivo = a.objetivo;
    _situacaoMusculacao = a.situacaoMusculacao;
    _tempoParadoController.text = a.tempoParadoMusculacao ?? '';
    _problemaColunaJoelho = a.problemaColunaJoelho;
    _problemaColunaJoelhoQualController.text = a.problemaColunaJoelhoQual ?? '';
    _pressaoArterial = a.pressaoArterial;
    _condicoesClinicas
      ..clear()
      ..addAll(a.condicoesClinicas);
    _alergia = a.alergia;
    _alergiaQualController.text = a.alergiaQual ?? '';
    _doresCorpo = a.doresCorpo;
    _doresCorpoQualController.text = a.doresCorpoQual ?? '';
    _lesaoOsteoMuscular = a.lesaoOsteoMuscular;
    _lesaoOsteoMuscularQualController.text = a.lesaoOsteoMuscularQual ?? '';
    _cirurgiaRecente = a.cirurgiaRecente;
    _cirurgiaRecenteDeQueController.text = a.cirurgiaRecenteDeQue ?? '';
    _usaMedicamento = a.usaMedicamento;
    _usaMedicamentoQualController.text = a.usaMedicamentoQual ?? '';
    _usoSubstancias
      ..clear()
      ..addAll(a.usoSubstancias);
    _fazendoDieta = a.fazendoDieta;
    _dietaPorContaPropria = a.dietaPorContaPropria;
    _dietaOrientacaoNutricionista = a.dietaOrientacaoNutricionista;
    _respondidoEm = a.respondidoEm;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      await widget.alunoService.salvarAnamnese(
        widget.uid,
        Anamnese(
          diasPorSemana: _diasPorSemana,
          objetivo: _objetivo,
          situacaoMusculacao: _situacaoMusculacao,
          tempoParadoMusculacao: _textOrNull(_tempoParadoController),
          problemaColunaJoelho: _problemaColunaJoelho,
          problemaColunaJoelhoQual: _textOrNull(_problemaColunaJoelhoQualController),
          pressaoArterial: _pressaoArterial,
          condicoesClinicas: _condicoesClinicas.toList(),
          alergia: _alergia,
          alergiaQual: _textOrNull(_alergiaQualController),
          doresCorpo: _doresCorpo,
          doresCorpoQual: _textOrNull(_doresCorpoQualController),
          lesaoOsteoMuscular: _lesaoOsteoMuscular,
          lesaoOsteoMuscularQual: _textOrNull(_lesaoOsteoMuscularQualController),
          cirurgiaRecente: _cirurgiaRecente,
          cirurgiaRecenteDeQue: _textOrNull(_cirurgiaRecenteDeQueController),
          usaMedicamento: _usaMedicamento,
          usaMedicamentoQual: _textOrNull(_usaMedicamentoQualController),
          usoSubstancias: _usoSubstancias.toList(),
          fazendoDieta: _fazendoDieta,
          dietaPorContaPropria: _dietaPorContaPropria,
          dietaOrientacaoNutricionista: _dietaOrientacaoNutricionista,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Anamnese salva.')));
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

  String? _textOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Anamnese?>(
      stream: widget.alunoService.watchAnamnese(widget.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        _preencherSeNecessario(snapshot.data);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (_respondidoEm != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Respondida em ${_formatarData(_respondidoEm!)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ),

            _Pergunta(
              numero: '01',
              texto: 'Quantos dias pretende treinar?',
              child: _singleChoiceRow<int>(
                options: const [2, 3, 4, 5, 6],
                label: (v) => '$v',
                selected: _diasPorSemana,
                onSelected: (v) => setState(() => _diasPorSemana = v),
              ),
            ),
            _Pergunta(
              numero: '02',
              texto: 'Qual o seu objetivo?',
              child: _singleChoiceRow<ObjetivoTreino>(
                options: ObjetivoTreino.values,
                label: (v) => v.label,
                selected: _objetivo,
                onSelected: (v) => setState(() => _objetivo = v),
              ),
            ),
            _Pergunta(
              numero: '03',
              texto: 'Pratica atualmente musculação?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _singleChoiceRow<SituacaoMusculacao>(
                    options: SituacaoMusculacao.values,
                    label: (v) => v.label,
                    selected: _situacaoMusculacao,
                    onSelected: (v) => setState(() => _situacaoMusculacao = v),
                  ),
                  if (_situacaoMusculacao != null &&
                      _situacaoMusculacao != SituacaoMusculacao.sim) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tempoParadoController,
                      decoration: const InputDecoration(
                        labelText: 'Se não, há quanto tempo está parado?',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _PerguntaSimNao(
              numero: '04',
              texto: 'Possui algum problema de coluna ou joelho?',
              valor: _problemaColunaJoelho,
              onChanged: (v) => setState(() => _problemaColunaJoelho = v),
              qualController: _problemaColunaJoelhoQualController,
            ),
            _Pergunta(
              numero: '05',
              texto: 'Sua pressão arterial é?',
              child: _singleChoiceRow<NivelPressaoArterial>(
                options: NivelPressaoArterial.values,
                label: (v) => v.label,
                selected: _pressaoArterial,
                onSelected: (v) => setState(() => _pressaoArterial = v),
              ),
            ),
            _Pergunta(
              numero: '06',
              texto: 'Você é:',
              child: _multiChoiceRow(
                options: condicoesClinicasDisponiveis,
                selected: _condicoesClinicas,
                onToggle: (key) => setState(() {
                  if (key == 'nenhum') {
                    _condicoesClinicas
                      ..clear()
                      ..add('nenhum');
                  } else {
                    _condicoesClinicas.remove('nenhum');
                    _condicoesClinicas.contains(key)
                        ? _condicoesClinicas.remove(key)
                        : _condicoesClinicas.add(key);
                  }
                }),
              ),
            ),
            _PerguntaSimNao(
              numero: '07',
              texto: 'Possui algum tipo de alergia?',
              valor: _alergia,
              onChanged: (v) => setState(() => _alergia = v),
              qualController: _alergiaQualController,
            ),
            _PerguntaSimNao(
              numero: '08',
              texto: 'Sente dores no corpo atualmente?',
              valor: _doresCorpo,
              onChanged: (v) => setState(() => _doresCorpo = v),
              qualController: _doresCorpoQualController,
            ),
            _PerguntaSimNao(
              numero: '09',
              texto: 'Sofreu algum acidente ou lesão osteo-muscular?',
              valor: _lesaoOsteoMuscular,
              onChanged: (v) => setState(() => _lesaoOsteoMuscular = v),
              qualController: _lesaoOsteoMuscularQualController,
            ),
            _PerguntaSimNao(
              numero: '10',
              texto: 'Fez alguma cirurgia recente?',
              valor: _cirurgiaRecente,
              onChanged: (v) => setState(() => _cirurgiaRecente = v),
              qualController: _cirurgiaRecenteDeQueController,
              qualLabel: 'De que?',
            ),
            _PerguntaSimNao(
              numero: '11',
              texto: 'Utiliza algum medicamento?',
              valor: _usaMedicamento,
              onChanged: (v) => setState(() => _usaMedicamento = v),
              qualController: _usaMedicamentoQualController,
            ),
            _Pergunta(
              numero: '12',
              texto: 'Faz uso de?',
              child: _multiChoiceRow(
                options: usoSubstanciasDisponiveis,
                selected: _usoSubstancias,
                onToggle: (key) => setState(() {
                  if (key == 'nao') {
                    _usoSubstancias
                      ..clear()
                      ..add('nao');
                  } else {
                    _usoSubstancias.remove('nao');
                    _usoSubstancias.contains(key)
                        ? _usoSubstancias.remove(key)
                        : _usoSubstancias.add(key);
                  }
                }),
              ),
            ),
            _Pergunta(
              numero: '13',
              texto: 'Está fazendo alguma dieta?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _singleChoiceRow<bool>(
                    options: const [true, false],
                    label: (v) => v ? 'Sim' : 'Não',
                    selected: _fazendoDieta,
                    onSelected: (v) => setState(() => _fazendoDieta = v),
                  ),
                  if (_fazendoDieta == true) ...[
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _dietaPorContaPropria ?? false,
                      onChanged: (v) => setState(() => _dietaPorContaPropria = v),
                      title: const Text('Por conta própria'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _dietaOrientacaoNutricionista ?? false,
                      onChanged: (v) => setState(() => _dietaOrientacaoNutricionista = v),
                      title: const Text('Orientação por nutricionista'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Caro aluno, sua ficha será elaborada com base nas suas '
              'respostas. A omissão de algum item é de sua inteira '
              'responsabilidade.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                    )
                  : const Text('SALVAR ANAMNESE'),
            ),
          ],
        );
      },
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }
}

class _Pergunta extends StatelessWidget {
  const _Pergunta({required this.numero, required this.texto, required this.child});

  final String numero;
  final String texto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: '$numero. ', style: const TextStyle(color: AppColors.gold)),
                TextSpan(text: texto, style: const TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PerguntaSimNao extends StatelessWidget {
  const _PerguntaSimNao({
    required this.numero,
    required this.texto,
    required this.valor,
    required this.onChanged,
    required this.qualController,
    this.qualLabel = 'Qual?',
  });

  final String numero;
  final String texto;
  final bool? valor;
  final ValueChanged<bool> onChanged;
  final TextEditingController qualController;
  final String qualLabel;

  @override
  Widget build(BuildContext context) {
    return _Pergunta(
      numero: numero,
      texto: texto,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _singleChoiceRow<bool>(
            options: const [true, false],
            label: (v) => v ? 'Sim' : 'Não',
            selected: valor,
            onSelected: onChanged,
          ),
          if (valor == true) ...[
            const SizedBox(height: 10),
            TextField(
              controller: qualController,
              decoration: InputDecoration(labelText: qualLabel),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _singleChoiceRow<T>({
  required List<T> options,
  required T? selected,
  required String Function(T) label,
  required ValueChanged<T> onSelected,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options
        .map(
          (option) => ChoiceChip(
            label: Text(label(option)),
            selected: selected == option,
            onSelected: (_) => onSelected(option),
            selectedColor: AppColors.gold,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected == option ? AppColors.gold : AppColors.surfaceHigh,
            ),
            labelStyle: TextStyle(
              color: selected == option ? AppColors.black : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        .toList(),
  );
}

Widget _multiChoiceRow({
  required Map<String, String> options,
  required Set<String> selected,
  required ValueChanged<String> onToggle,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.entries
        .map(
          (entry) => FilterChip(
            label: Text(entry.value),
            selected: selected.contains(entry.key),
            onSelected: (_) => onToggle(entry.key),
            selectedColor: AppColors.gold,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected.contains(entry.key) ? AppColors.gold : AppColors.surfaceHigh,
            ),
            labelStyle: TextStyle(
              color: selected.contains(entry.key) ? AppColors.black : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        .toList(),
  );
}
