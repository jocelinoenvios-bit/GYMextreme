import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:image_picker/image_picker.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../models/endereco.dart';
import '../../models/user_role.dart';
import '../../services/aluno_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/validadores.dart';
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
    required this.storageService,
    required this.staffAtual,
  });

  final AlunoService alunoService;
  final StorageService storageService;
  final AppUser staffAtual;

  @override
  State<NovoAlunoWizardScreen> createState() => _NovoAlunoWizardScreenState();
}

class _NovoAlunoWizardScreenState extends State<NovoAlunoWizardScreen> {
  int _passoAtual = 0;
  String? _uid;
  AppUser? _alunoCriado;

  static const _titulosPasso = [
    'Dados',
    'Anamnese',
    'Regulamento',
    'Avaliação física',
  ];

  @override
  Widget build(BuildContext context) {
    if (_passoAtual == 4) {
      return _PassoConcluido(
        alunoUid: _uid!,
        alunoService: widget.alunoService,
        staffAtual: widget.staffAtual,
      );
    }

    // Causa raiz real do bug relatado (Anamnese em branco/com "VOLTAR"
    // sobreposto): esta tela fica montada (e recebe layout) enquanto o
    // Navigator empurra/remove a rota do formulário "Dados" por cima dela.
    // Nesses frames intermediários de transição de rota, o Flutter mede o
    // conteúdo com largura irrestrita (BoxConstraints sem limite máximo) —
    // e um botão (ElevatedButton) dentro de uma Row, quando medido assim,
    // quebra o layout (mesmo em release, sem crash visível — só o
    // resultado errado que apareceu no aparelho real). Não é um problema
    // do widget Stepper especificamente (acontecia mesmo depois de
    // substituí-lo por este layout mais simples) — é sobre a largura que
    // ESTA TELA recebe do Navigator durante a transição. O OverflowBox
    // abaixo trava a largura/altura do corpo da tela nas dimensões reais
    // da tela sempre, independente da largura recebida nesses frames.
    final tamanhoTela = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Novo aluno')),
      body: OverflowBox(
        fit: OverflowBoxFit.deferToChild,
        alignment: Alignment.topLeft,
        minWidth: 0,
        maxWidth: tamanhoTela.width,
        minHeight: 0,
        maxHeight: tamanhoTela.height,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IndicadorDePasso(
                  passoAtual: _passoAtual,
                  titulos: _titulosPasso,
                ),
                const SizedBox(height: 24),
                _conteudoPasso(context, _passoAtual),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteudoPasso(BuildContext context, int passo) {
    switch (passo) {
      case 0:
        return _uid == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nome, contato, documento e endereço do aluno.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _TelaCheiaPasso(
                          titulo: 'Dados do aluno',
                          child: _PassoDados(
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
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('PREENCHER DADOS'),
                  ),
                ],
              )
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Dados salvos.',
                  style: TextStyle(color: AppColors.gold),
                ),
              );
      case 1:
        // AnamneseTab tem um ListView na raiz — funciona bem como body de
        // um Scaffold próprio (é assim que a ficha do aluno já usa, dentro
        // do TabBarView), por isso abre numa tela cheia separada.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'As 13 perguntas da ficha de anamnese do aluno.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _TelaCheiaPasso(
                    titulo: 'Anamnese',
                    child: AnamneseTab(
                      uid: _uid!,
                      alunoService: widget.alunoService,
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('PREENCHER ANAMNESE'),
            ),
            const SizedBox(height: 12),
            _BotoesPasso(
              onVoltar: () => setState(() => _passoAtual = 0),
              onContinuar: () => setState(() => _passoAtual = 2),
            ),
          ],
        );
      case 2:
        // Mesmo motivo da Anamnese acima — TermoTab também tem um
        // ListView na raiz e vai pra tela cheia própria.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'As 15 regras do regulamento, com aceite digital do aluno.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _TelaCheiaPasso(
                    titulo: 'Regulamento',
                    child: TermoTab(
                      aluno: _alunoCriado!,
                      alunoService: widget.alunoService,
                      staffAtual: widget.staffAtual,
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.gavel_outlined),
              label: const Text('ABRIR REGULAMENTO'),
            ),
            const SizedBox(height: 12),
            _BotoesPasso(
              onVoltar: () => setState(() => _passoAtual = 1),
              onContinuar: () => setState(() => _passoAtual = 3),
            ),
          ],
        );
      default:
        return Column(
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
        );
    }
  }
}

/// Indicador simples de progresso ("passo N de 4") — substitui o cabeçalho
/// de ícones do Stepper original sem depender do widget `Stepper` em si.
class _IndicadorDePasso extends StatelessWidget {
  const _IndicadorDePasso({required this.passoAtual, required this.titulos});

  final int passoAtual;
  final List<String> titulos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passo ${passoAtual + 1} de ${titulos.length}: ${titulos[passoAtual]}',
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (passoAtual + 1) / titulos.length,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.gold,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

/// Envolve `AnamneseTab`/`TermoTab` numa tela cheia própria (com
/// `Scaffold`/`AppBar`) — dá a altura limitada que o `ListView` deles
/// precisa pra funcionar.
class _TelaCheiaPasso extends StatelessWidget {
  const _TelaCheiaPasso({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: child,
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
    // Sem Spacer/Expanded de propósito: evita depender de largura finita
    // pro espaçamento entre os botões. E cada botão vai dentro de um
    // IntrinsicWidth: em certos frames (ex.: bem no instante em que o
    // Navigator termina de remover a rota do formulário "Dados" por cima
    // desta tela), este Row pode ser medido com largura totalmente livre
    // (`BoxConstraints` sem limite máximo) — e um ElevatedButton medido
    // assim, sem nenhuma largura de referência, quebra o layout (mesmo em
    // release, sem crash visível — só o resultado errado que apareceu no
    // aparelho real). IntrinsicWidth calcula a largura natural do botão a
    // partir do próprio conteúdo (o texto), então cada botão sempre recebe
    // uma largura finita, não importa a largura que o Row receber.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IntrinsicWidth(
          child: TextButton(onPressed: onVoltar, child: const Text('VOLTAR')),
        ),
        IntrinsicWidth(
          child: ElevatedButton(
            onPressed: onContinuar,
            child: Text(rotuloContinuar),
          ),
        ),
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
    required this.staffAtual,
  });

  final String alunoUid;
  final AlunoService alunoService;
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
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.gold,
                size: 64,
              ),
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

  String? _textOrNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

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
        contatoEmergenciaNome: _textOrNull(
          _contatoEmergenciaNomeController.text,
        ),
        contatoEmergenciaTelefone: _textOrNull(
          _contatoEmergenciaTelefoneController.text,
        ),
        observacoes: _textOrNull(_observacoesController.text),
        dataInicio: _dataInicio,
        diaVencimento: int.tryParse(_diaVencimentoController.text),
        cadastradoPorUid: widget.staffAtual.uid,
        cadastradoPorNome: widget.staffAtual.nome,
      );

      if (_fotoBytes != null) {
        final fotoUrl = await widget.storageService.enviarFotoAluno(
          uid,
          _fotoBytes!,
        );
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
            contatoEmergenciaNome: _textOrNull(
              _contatoEmergenciaNomeController.text,
            ),
            contatoEmergenciaTelefone: _textOrNull(
              _contatoEmergenciaTelefoneController.text,
            ),
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
        // _PassoDados vive numa tela cheia própria (empurrada pelo passo
        // "Dados" do wizard) — fecha ela de volta assim que o cadastro é
        // criado, mesmo padrão do AvaliacaoFisicaFormScreen.
        Navigator.of(context).pop();
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

    // Antes vivia direto no Step.content do Stepper, que já fornecia
    // rolagem (era o próprio ListView shrinkWrap do Stepper). Agora que
    // este formulário abre numa tela cheia própria (Scaffold simples, sem
    // rolagem embutida), precisa da sua própria área rolável.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
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
                    backgroundImage: _fotoBytes != null
                        ? MemoryImage(_fotoBytes!)
                        : null,
                    child: _fotoBytes == null
                        ? const Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppColors.gold,
                          )
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
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: AppColors.black,
                        ),
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
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Informe o nome.'
                  : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Sexo>(
                    initialValue: _sexo,
                    decoration: const InputDecoration(labelText: 'Sexo'),
                    items: Sexo.values
                        .map(
                          (sexo) => DropdownMenuItem(
                            value: sexo,
                            child: Text(sexo.label),
                          ),
                        )
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
                      decoration: const InputDecoration(
                        labelText: 'Nascimento',
                      ),
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
                    keyboardType: TextInputType.number,
                    inputFormatters: [digitsOnlyFormatter],
                    decoration: const InputDecoration(labelText: 'CPF'),
                    validator: validarCpf,
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
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o e-mail.';
                }
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
                helperText:
                    'O aluno pode trocar depois em "Esqueci minha senha".',
              ),
              validator: (value) => (value == null || value.length < 6)
                  ? 'Mínimo de 6 caracteres.'
                  : null,
            ),
            const SizedBox(height: 14),
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
                    decoration: const InputDecoration(
                      labelText: 'UF',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _contatoEmergenciaNomeController,
              decoration: const InputDecoration(
                labelText: 'Contato de emergência — nome',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contatoEmergenciaTelefoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [digitsOnlyFormatter],
              decoration: const InputDecoration(
                labelText: 'Contato de emergência — telefone',
              ),
              validator: validarTelefone,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _diaVencimentoController,
              keyboardType: TextInputType.number,
              inputFormatters: [digitsOnlyFormatter],
              decoration: const InputDecoration(
                labelText: 'Dia de vencimento',
                helperText:
                    'Dia do mês em que a mensalidade vence (1-31), não uma data',
              ),
              validator: validarDiaVencimento,
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.black,
                      ),
                    )
                  : const Text('CADASTRAR E CONTINUAR'),
            ),
          ],
        ),
      ),
    );
  }
}
