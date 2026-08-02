import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../models/endereco.dart';
import '../../models/user_role.dart';
import '../../services/aluno_service.dart';
import '../../services/exercicio_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import 'avaliacao_fisica_form_screen.dart';
import 'tabs/anamnese_tab.dart';
import 'tabs/termo_tab.dart';
import 'treino_form_screen.dart';

/// Substitui a ficha de papel: cadastro do aluno guiado passo a passo
/// (Dados → Anamnese → Regulamento → Avaliação física), terminando com
/// a opção de já prescrever o treino. Cada etapa depois de "Dados"
/// reaproveita o mesmo widget usado na ficha do aluno já cadastrado
/// (`AnamneseTab`/`TermoTab`), então o que for preenchido aqui é
/// exatamente o que aparece depois na ficha dele.
class NovoAlunoWizardScreen extends StatefulWidget {
  const NovoAlunoWizardScreen({
    super.key,
    required this.alunoService,
    required this.exercicioService,
    required this.storageService,
    required this.staffAtual,
  });

  final AlunoService alunoService;
  final ExercicioService exercicioService;
  final StorageService storageService;
  final AppUser staffAtual;

  @override
  State<NovoAlunoWizardScreen> createState() => _NovoAlunoWizardScreenState();
}

class _NovoAlunoWizardScreenState extends State<NovoAlunoWizardScreen> {
  int _passoAtual = 0;
  String? _uid;
  AppUser? _alunoCriado;

  @override
  Widget build(BuildContext context) {
    if (_passoAtual == 4) {
      return _PassoConcluido(
        alunoUid: _uid!,
        alunoService: widget.alunoService,
        exercicioService: widget.exercicioService,
        staffAtual: widget.staffAtual,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Novo aluno')),
      body: Stepper(
        currentStep: _passoAtual,
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          Step(
            title: const Text('Dados'),
            isActive: _passoAtual >= 0,
            state: _uid != null ? StepState.complete : StepState.indexed,
            content: _PassoDados(
              alunoService: widget.alunoService,
              storageService: widget.storageService,
              staffAtual: widget.staffAtual,
              onCriado: (uid, aluno) {
                setState(() {
                  _uid = uid;
                  _alunoCriado = aluno;
                  _passoAtual = 1;
                });
              },
            ),
          ),
          Step(
            title: const Text('Anamnese'),
            isActive: _passoAtual >= 1,
            content: _uid == null
                ? const _AguardandoPassoAnterior()
                : Column(
                    children: [
                      AnamneseTab(uid: _uid!, alunoService: widget.alunoService),
                      const SizedBox(height: 12),
                      _BotoesPasso(
                        onVoltar: () => setState(() => _passoAtual = 0),
                        onContinuar: () => setState(() => _passoAtual = 2),
                      ),
                    ],
                  ),
          ),
          Step(
            title: const Text('Regulamento'),
            isActive: _passoAtual >= 2,
            content: (_uid == null || _alunoCriado == null)
                ? const _AguardandoPassoAnterior()
                : Column(
                    children: [
                      TermoTab(
                        aluno: _alunoCriado!,
                        alunoService: widget.alunoService,
                        staffAtual: widget.staffAtual,
                      ),
                      const SizedBox(height: 12),
                      _BotoesPasso(
                        onVoltar: () => setState(() => _passoAtual = 1),
                        onContinuar: () => setState(() => _passoAtual = 3),
                      ),
                    ],
                  ),
          ),
          Step(
            title: const Text('Avaliação física'),
            isActive: _passoAtual >= 3,
            content: _uid == null
                ? const _AguardandoPassoAnterior()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Peso, altura, IMC e circunferências — pode ser preenchida '
                        'agora ou depois, na ficha do aluno.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AvaliacaoFisicaFormScreen(
                              uid: _uid!,
                              alunoService: widget.alunoService,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.monitor_weight_outlined),
                        label: const Text('PREENCHER AVALIAÇÃO FÍSICA'),
                      ),
                      const SizedBox(height: 12),
                      _BotoesPasso(
                        onVoltar: () => setState(() => _passoAtual = 2),
                        onContinuar: () => setState(() => _passoAtual = 4),
                        rotuloContinuar: 'CONCLUIR CADASTRO',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AguardandoPassoAnterior extends StatelessWidget {
  const _AguardandoPassoAnterior();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Conclua o passo "Dados" primeiro.',
      style: TextStyle(color: AppColors.textSecondary),
    );
  }
}

class _BotoesPasso extends StatelessWidget {
  const _BotoesPasso({
    required this.onVoltar,
    required this.onContinuar,
    this.rotuloContinuar = 'CONTINUAR',
  });

  final VoidCallback onVoltar;
  final VoidCallback onContinuar;
  final String rotuloContinuar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(onPressed: onVoltar, child: const Text('VOLTAR')),
        const Spacer(),
        ElevatedButton(onPressed: onContinuar, child: Text(rotuloContinuar)),
      ],
    );
  }
}

/// Etapa final: aluno já cadastrado, com anamnese/termo/avaliação
/// preenchidos (ou pulados) — falta só decidir se prescreve o treino
/// agora ou deixa pra depois.
class _PassoConcluido extends StatelessWidget {
  const _PassoConcluido({
    required this.alunoUid,
    required this.alunoService,
    required this.exercicioService,
    required this.staffAtual,
  });

  final String alunoUid;
  final AlunoService alunoService;
  final ExercicioService exercicioService;
  final AppUser staffAtual;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro concluído')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.gold, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Aluno cadastrado com sucesso.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => TreinoFormScreen(
                      alunoUid: alunoUid,
                      alunoService: alunoService,
                      exercicioService: exercicioService,
                      staffAtual: staffAtual,
                    ),
                  ),
                ),
                icon: const Icon(Icons.fitness_center),
                label: const Text('PRESCREVER TREINO AGORA'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('FINALIZAR POR AGORA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cria a conta (Firebase Auth + `usuarios`) e o restante dos dados
/// cadastrais (`alunos/{uid}`) do aluno novo.
class _PassoDados extends StatefulWidget {
  const _PassoDados({
    required this.alunoService,
    required this.storageService,
    required this.staffAtual,
    required this.onCriado,
  });

  final AlunoService alunoService;
  final StorageService storageService;
  final AppUser staffAtual;
  final void Function(String uid, AppUser aluno) onCriado;

  @override
  State<_PassoDados> createState() => _PassoDadosState();
}

class _PassoDadosState extends State<_PassoDados> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
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
  final _diaVencimentoController = TextEditingController();

  Sexo? _sexo;
  DateTime? _dataNascimento;
  final DateTime _dataInicio = DateTime.now();
  Uint8List? _fotoBytes;
  bool _isSaving = false;
  bool _concluido = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
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
    _diaVencimentoController.dispose();
    super.dispose();
  }

  String? _textOrNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _escolherFoto() async {
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (arquivo == null) return;
    final bytes = await arquivo.readAsBytes();
    setState(() => _fotoBytes = bytes);
  }

  Future<void> _pickDataNascimento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _dataNascimento = picked);
  }

  Future<void> _handleCriar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final endereco = Endereco(
        cep: _textOrNull(_cepController.text),
        logradouro: _textOrNull(_logradouroController.text),
        numero: _textOrNull(_numeroController.text),
        complemento: _textOrNull(_complementoController.text),
        bairro: _textOrNull(_bairroController.text),
        cidade: _textOrNull(_cidadeController.text),
        uf: _textOrNull(_ufController.text),
      );

      final uid = await widget.alunoService.cadastrarAluno(
        nome: _nomeController.text,
        email: _emailController.text,
        senhaInicial: _senhaController.text,
        sexo: _sexo,
        dataNascimento: _dataNascimento,
        cpf: _textOrNull(_cpfController.text),
        rg: _textOrNull(_rgController.text),
        telefone: _textOrNull(_telefoneController.text),
        whatsapp: _textOrNull(_whatsappController.text),
        endereco: endereco,
        contatoEmergenciaNome: _textOrNull(_contatoEmergenciaNomeController.text),
        contatoEmergenciaTelefone: _textOrNull(_contatoEmergenciaTelefoneController.text),
        observacoes: _textOrNull(_observacoesController.text),
        dataInicio: _dataInicio,
        diaVencimento: int.tryParse(_diaVencimentoController.text),
        cadastradoPorUid: widget.staffAtual.uid,
        cadastradoPorNome: widget.staffAtual.nome,
      );

      if (_fotoBytes != null) {
        final fotoUrl = await widget.storageService.enviarFotoAluno(uid, _fotoBytes!);
        await widget.alunoService.salvarDadosAluno(
          Aluno(
            uid: uid,
            sexo: _sexo,
            dataNascimento: _dataNascimento,
            fotoUrl: fotoUrl,
            cpf: _textOrNull(_cpfController.text),
            rg: _textOrNull(_rgController.text),
            telefone: _textOrNull(_telefoneController.text),
            whatsapp: _textOrNull(_whatsappController.text),
            endereco: endereco,
            contatoEmergenciaNome: _textOrNull(_contatoEmergenciaNomeController.text),
            contatoEmergenciaTelefone:
                _textOrNull(_contatoEmergenciaTelefoneController.text),
            observacoes: _textOrNull(_observacoesController.text),
            dataInicio: _dataInicio,
            diaVencimento: int.tryParse(_diaVencimentoController.text),
            cadastradoPorUid: widget.staffAtual.uid,
            cadastradoPorNome: widget.staffAtual.nome,
          ),
        );
      }

      if (mounted) {
        setState(() => _concluido = true);
        widget.onCriado(
          uid,
          AppUser(
            uid: uid,
            nome: _nomeController.text.trim(),
            email: _emailController.text.trim(),
            role: UserRole.aluno,
          ),
        );
      }
    } on AlunoServiceException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Erro inesperado ao cadastrar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_concluido) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Dados salvos.', style: TextStyle(color: AppColors.gold)),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.surfaceHigh,
                  backgroundImage: _fotoBytes != null ? MemoryImage(_fotoBytes!) : null,
                  child: _fotoBytes == null
                      ? const Icon(Icons.person_outline, size: 40, color: AppColors.gold)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _escolherFoto,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: AppColors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome completo'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Informe o nome.' : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Sexo>(
                  initialValue: _sexo,
                  decoration: const InputDecoration(labelText: 'Sexo'),
                  items: Sexo.values
                      .map((sexo) => DropdownMenuItem(value: sexo, child: Text(sexo.label)))
                      .toList(),
                  onChanged: (sexo) => setState(() => _sexo = sexo),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickDataNascimento,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Nascimento'),
                    child: Text(
                      _dataNascimento == null
                          ? '--/--/----'
                          : '${_dataNascimento!.day.toString().padLeft(2, '0')}/'
                                '${_dataNascimento!.month.toString().padLeft(2, '0')}/'
                                '${_dataNascimento!.year}',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cpfController,
                  decoration: const InputDecoration(labelText: 'CPF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _rgController,
                  decoration: const InputDecoration(labelText: 'RG'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Informe o e-mail.';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Informe um e-mail válido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _senhaController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Senha inicial',
              helperText: 'O aluno pode trocar depois em "Esqueci minha senha".',
            ),
            validator: (value) =>
                (value == null || value.length < 6) ? 'Mínimo de 6 caracteres.' : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _telefoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextFormField(
                  controller: _cepController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'CEP'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
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
                child: TextFormField(
                  controller: _numeroController,
                  decoration: const InputDecoration(labelText: 'Número'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _complementoController,
                  decoration: const InputDecoration(labelText: 'Complemento'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _bairroController,
            decoration: const InputDecoration(labelText: 'Bairro'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _cidadeController,
                  decoration: const InputDecoration(labelText: 'Cidade'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ufController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  decoration: const InputDecoration(labelText: 'UF', counterText: ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _contatoEmergenciaNomeController,
            decoration: const InputDecoration(labelText: 'Contato de emergência — nome'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _contatoEmergenciaTelefoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Contato de emergência — telefone'),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _diaVencimentoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Dia pago',
              helperText: 'Dia do mês (1-31)',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _observacoesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Observações'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleCriar,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                  )
                : const Text('CADASTRAR E CONTINUAR'),
          ),
        ],
      ),
    );
  }
}
