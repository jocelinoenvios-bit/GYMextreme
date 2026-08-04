import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/aluno.dart';
import '../../../models/app_user.dart';
import '../../../models/endereco.dart';
import '../../../services/aluno_service.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/idade.dart';
import '../../../utils/validadores.dart';
import 'mensalidade_section.dart';

class DadosTab extends StatefulWidget {
  const DadosTab({
    super.key,
    required this.aluno,
    required this.alunoService,
    required this.storageService,
    required this.staffAtual,
  });

  final AppUser aluno;
  final AlunoService alunoService;
  final StorageService storageService;
  final AppUser staffAtual;

  @override
  State<DadosTab> createState() => _DadosTabState();
}

class _DadosTabState extends State<DadosTab> {
  /// Criada uma única vez — se fosse recriada a cada `build()` (chamando
  /// `watchAluno` direto no `StreamBuilder`), qualquer `setState` local
  /// (ex.: trocar o Sexo, escolher uma data) resetaria o StreamBuilder pra
  /// "carregando", piscando o spinner por cima do formulário inteiro.
  late final Stream<Aluno?> _alunoStream = widget.alunoService.watchAluno(widget.aluno.uid);

  final _formKey = GlobalKey<FormState>();
  final _idadeController = TextEditingController();
  final _diaVencimentoController = TextEditingController();
  final _cpfController = TextEditingController();
  final _rgController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _contatoEmergenciaNomeController = TextEditingController();
  final _contatoEmergenciaTelefoneController = TextEditingController();
  final _observacoesController = TextEditingController();

  DateTime? _dataInicio;
  DateTime? _dataNascimento;
  Sexo? _sexo;
  String? _fotoUrl;
  Uint8List? _fotoNovaBytes;
  bool _isSaving = false;
  bool _isUploadingFoto = false;
  bool _isLoaded = false;

  @override
  void dispose() {
    _idadeController.dispose();
    _diaVencimentoController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _telefoneController.dispose();
    _whatsappController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    _contatoEmergenciaNomeController.dispose();
    _contatoEmergenciaTelefoneController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  void _preencherSeNecessario(Aluno? aluno) {
    if (_isLoaded) return;
    _isLoaded = true;
    _idadeController.text = aluno?.idadeInformada?.toString() ?? '';
    _diaVencimentoController.text = aluno?.diaVencimento?.toString() ?? '';
    _cpfController.text = aluno?.cpf ?? '';
    _rgController.text = aluno?.rg ?? '';
    _telefoneController.text = aluno?.telefone ?? '';
    _whatsappController.text = aluno?.whatsapp ?? '';
    _cepController.text = aluno?.endereco.cep ?? '';
    _logradouroController.text = aluno?.endereco.logradouro ?? '';
    _numeroController.text = aluno?.endereco.numero ?? '';
    _complementoController.text = aluno?.endereco.complemento ?? '';
    _bairroController.text = aluno?.endereco.bairro ?? '';
    _cidadeController.text = aluno?.endereco.cidade ?? '';
    _ufController.text = aluno?.endereco.uf ?? '';
    _contatoEmergenciaNomeController.text = aluno?.contatoEmergenciaNome ?? '';
    _contatoEmergenciaTelefoneController.text =
        aluno?.contatoEmergenciaTelefone ?? '';
    _observacoesController.text = aluno?.observacoes ?? '';
    _dataInicio = aluno?.dataInicio;
    _dataNascimento = aluno?.dataNascimento;
    _sexo = aluno?.sexo;
    _fotoUrl = aluno?.fotoUrl;
  }

  Future<void> _pickData({
    required DateTime? atual,
    required String titulo,
    required ValueChanged<DateTime> onEscolhida,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: titulo,
    );
    if (picked != null) onEscolhida(picked);
  }

  String _formatarData(DateTime? data) {
    if (data == null) return 'Não informada';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  Future<void> _escolherFoto(ImageSource origem) async {
    final picker = ImagePicker();
    final arquivo = await picker.pickImage(
      source: origem,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (arquivo == null) return;
    final bytes = await arquivo.readAsBytes();
    setState(() => _fotoNovaBytes = bytes);
  }

  void _abrirSeletorDeFoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.gold),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.of(context).pop();
                _escolherFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.of(context).pop();
                _escolherFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _textOrNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      var fotoUrl = _fotoUrl;
      if (_fotoNovaBytes != null) {
        setState(() => _isUploadingFoto = true);
        fotoUrl = await widget.storageService.enviarFotoAluno(
          widget.aluno.uid,
          _fotoNovaBytes!,
        );
        setState(() => _isUploadingFoto = false);
      }

      await widget.alunoService.salvarDadosAluno(
        Aluno(
          uid: widget.aluno.uid,
          sexo: _sexo,
          dataNascimento: _dataNascimento,
          idadeInformada: int.tryParse(_idadeController.text),
          fotoUrl: fotoUrl,
          cpf: _textOrNull(_cpfController.text),
          rg: _textOrNull(_rgController.text),
          telefone: _textOrNull(_telefoneController.text),
          whatsapp: _textOrNull(_whatsappController.text),
          endereco: Endereco(
            cep: _textOrNull(_cepController.text),
            logradouro: _textOrNull(_logradouroController.text),
            numero: _textOrNull(_numeroController.text),
            complemento: _textOrNull(_complementoController.text),
            bairro: _textOrNull(_bairroController.text),
            cidade: _textOrNull(_cidadeController.text),
            uf: _textOrNull(_ufController.text),
          ),
          contatoEmergenciaNome: _textOrNull(_contatoEmergenciaNomeController.text),
          contatoEmergenciaTelefone:
              _textOrNull(_contatoEmergenciaTelefoneController.text),
          observacoes: _textOrNull(_observacoesController.text),
          dataInicio: _dataInicio,
          diaVencimento: int.tryParse(_diaVencimentoController.text),
        ),
      );
      if (mounted) {
        setState(() {
          _fotoUrl = fotoUrl;
          _fotoNovaBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados atualizados.')),
        );
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Aluno?>(
      stream: _alunoStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        _preencherSeNecessario(snapshot.data);
        final idadeCalculada = calcularIdade(_dataNascimento);

        return Form(
          key: _formKey,
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.surfaceHigh,
                    backgroundImage: _fotoNovaBytes != null
                        ? MemoryImage(_fotoNovaBytes!)
                        : (_fotoUrl != null ? NetworkImage(_fotoUrl!) : null)
                              as ImageProvider?,
                    child: (_fotoNovaBytes == null && _fotoUrl == null)
                        ? const Icon(Icons.person_outline, size: 44, color: AppColors.gold)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: _isUploadingFoto ? null : _abrirSeletorDeFoto,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingFoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.black,
                                ),
                              )
                            : const Icon(Icons.camera_alt, size: 18, color: AppColors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ReadOnlyField(label: 'Nome', value: widget.aluno.nome),
            const SizedBox(height: 14),
            _ReadOnlyField(label: 'E-mail', value: widget.aluno.email),
            const SizedBox(height: 20),
            const _SecaoTitulo('Dados pessoais'),
            DropdownButtonFormField<Sexo>(
              initialValue: _sexo,
              decoration: const InputDecoration(labelText: 'Sexo'),
              items: Sexo.values
                  .map((sexo) => DropdownMenuItem(value: sexo, child: Text(sexo.label)))
                  .toList(),
              onChanged: (sexo) => setState(() => _sexo = sexo),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _pickData(
                atual: _dataNascimento,
                titulo: 'Data de nascimento',
                onEscolhida: (data) => setState(() => _dataNascimento = data),
              ),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data de nascimento',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  helperText: idadeCalculada != null ? '$idadeCalculada anos' : null,
                ),
                child: Text(_formatarData(_dataNascimento)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _idadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Idade (se não souber a data de nascimento)',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [digitsOnlyFormatter],
                    decoration: const InputDecoration(labelText: 'CPF'),
                    validator: validarCpf,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rgController,
                    decoration: const InputDecoration(labelText: 'RG'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SecaoTitulo('Contato'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _telefoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [digitsOnlyFormatter],
                    decoration: const InputDecoration(labelText: 'Telefone'),
                    validator: validarTelefone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [digitsOnlyFormatter],
                    decoration: const InputDecoration(labelText: 'WhatsApp'),
                    validator: validarTelefone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SecaoTitulo('Endereço'),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    controller: _cepController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [digitsOnlyFormatter],
                    decoration: const InputDecoration(labelText: 'CEP'),
                    validator: validarCep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _logradouroController,
                    decoration: const InputDecoration(labelText: 'Rua/Av.'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _numeroController,
                    decoration: const InputDecoration(labelText: 'Número'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _complementoController,
                    decoration: const InputDecoration(labelText: 'Complemento'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bairroController,
              decoration: const InputDecoration(labelText: 'Bairro'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _cidadeController,
                    decoration: const InputDecoration(labelText: 'Cidade'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ufController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                    decoration: const InputDecoration(labelText: 'UF', counterText: ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SecaoTitulo('Contato de emergência'),
            TextField(
              controller: _contatoEmergenciaNomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contatoEmergenciaTelefoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [digitsOnlyFormatter],
              decoration: const InputDecoration(labelText: 'Telefone'),
              validator: validarTelefone,
            ),
            const SizedBox(height: 20),
            const _SecaoTitulo('Academia'),
            TextFormField(
              controller: _diaVencimentoController,
              keyboardType: TextInputType.number,
              inputFormatters: [digitsOnlyFormatter],
              decoration: const InputDecoration(
                labelText: 'Dia de vencimento',
                helperText: 'Dia do mês em que a mensalidade vence (1-31), não uma data',
              ),
              validator: validarDiaVencimento,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _pickData(
                atual: _dataInicio,
                titulo: 'Data de início',
                onEscolhida: (data) => setState(() => _dataInicio = data),
              ),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de início',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_formatarData(_dataInicio)),
              ),
            ),
            const SizedBox(height: 20),
            const _SecaoTitulo('Mensalidade'),
            MensalidadeSection(
              alunoUid: widget.aluno.uid,
              proximoVencimento: snapshot.data?.proximoVencimento,
              alunoService: widget.alunoService,
              staffAtual: widget.staffAtual,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _observacoesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                    )
                  : const Text('SALVAR'),
            ),
          ],
          ),
        );
      },
    );
  }
}

class _SecaoTitulo extends StatelessWidget {
  const _SecaoTitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        ],
      ),
    );
  }
}
