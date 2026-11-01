import 'package:flutter/material.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../models/permission.dart';
import '../../services/acesso_service.dart';
import '../../services/aluno_service.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/status_acesso.dart';
import '../../widgets/foto_aluno_image.dart';
import '../../widgets/premium.dart';
import 'receber_mensalidade_fluxo.dart';
import 'tabs/anamnese_tab.dart';
import 'tabs/avaliacoes_tab.dart';
import 'tabs/dados_tab.dart';
import 'tabs/frequencia_tab.dart';
import 'tabs/termo_tab.dart';
import 'tabs/treinos_tab.dart';

/// Ficha do aluno: um cabeçalho (foto, nome, e-mail e situação da
/// mensalidade) e as partes da ficha em cards, no mesmo visual da tela
/// inicial. Cada card abre só aquela parte, numa tela própria — antes a
/// ficha abria direto em "Dados", com as outras partes em abas.
///
/// Treinos, Anamnese e Avaliações aparecem pra qualquer staff; criar ou
/// editar dentro delas exige a permissão específica (ver cada tela, e
/// reforçado em `firestore.rules`). Frequência é a única cuja
/// visibilidade depende de permissão (`Permission.frequencia`).
class AlunoDetailScreen extends StatelessWidget {
  AlunoDetailScreen({
    super.key,
    required this.aluno,
    required this.alunoService,
    required this.storageService,
    required this.staffAtual,
    AcessoService? acessoService,
  }) : acessoService = acessoService ?? AcessoService();

  final AppUser aluno;
  final AlunoService alunoService;
  final StorageService storageService;
  final AppUser staffAtual;
  final AcessoService acessoService;

  bool get _podeGerenciarAcesso =>
      PermissionService.has(staffAtual, Permission.gerenciarAlunos);
  bool get _podeReceberMensalidade =>
      PermissionService.has(staffAtual, Permission.receberMensalidades);

  /// Bloquear/desbloquear, inativar e reativar (esta, recebendo a
  /// mensalidade) — catraca e app do aluno respeitam os dois estados.
  Future<void> _gerenciarAcesso(BuildContext context, Aluno? ficha) async {
    final inativo = ficha != null && !ficha.ativo;
    final bloqueado = ficha?.bloqueado ?? false;
    final escolha = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inativo)
              ListTile(
                leading: Icon(Icons.how_to_reg_outlined, color: AppColors.gold),
                title: const Text('Reativar aluno'),
                subtitle: Text(
                  _podeReceberMensalidade
                      ? 'Recebendo a mensalidade. O novo vencimento conta a partir de hoje.'
                      : 'Precisa da permissão de receber mensalidades.',
                ),
                enabled: _podeReceberMensalidade,
                onTap: () => Navigator.of(sheet).pop('reativar'),
              )
            else ...[
              if (bloqueado)
                ListTile(
                  leading: Icon(Icons.lock_open_outlined, color: AppColors.gold),
                  title: const Text('Desbloquear acesso'),
                  subtitle: const Text('Volta a entrar na catraca e a usar o app.'),
                  onTap: () => Navigator.of(sheet).pop('desbloquear'),
                )
              else
                ListTile(
                  leading: Icon(Icons.block, color: AppColors.error),
                  title: const Text('Bloquear acesso'),
                  subtitle: const Text('Suspensão temporária, mesmo com a mensalidade em dia.'),
                  onTap: () => Navigator.of(sheet).pop('bloquear'),
                ),
              ListTile(
                leading: Icon(Icons.person_off_outlined, color: AppColors.textSecondary),
                title: const Text('Inativar aluno'),
                subtitle: const Text('Saiu da academia. Vai pra lista de Inativos.'),
                onTap: () => Navigator.of(sheet).pop('inativar'),
              ),
            ],
          ],
        ),
      ),
    );
    if (escolha == null || !context.mounted) return;

    if (escolha == 'reativar') {
      await receberMensalidadeFluxo(
        context,
        alunoService: alunoService,
        alunoUid: aluno.uid,
        alunoNome: aluno.nome,
        proximoVencimento: ficha?.proximoVencimento,
        staff: staffAtual,
        reativar: true,
      );
      return;
    }

    final avisos = ScaffoldMessenger.of(context);
    final ehBloqueio = escolha == 'bloquear';
    final ehInativacao = escolha == 'inativar';
    String? motivo;
    if (ehBloqueio || ehInativacao) {
      motivo = await showDialog<String>(
        context: context,
        builder: (_) => _DialogoMotivo(
          titulo: ehBloqueio ? 'Bloquear acesso de ${aluno.nome}' : 'Inativar ${aluno.nome}',
          explicacao: ehBloqueio
              ? 'O aluno fica barrado na catraca e no app até ser desbloqueado.'
              : 'O aluno vai pra lista de Inativos e fica barrado na catraca e no app. '
                    'Pra voltar, use Reativar (recebendo a mensalidade).',
          motivoObrigatorio: ehBloqueio,
          confirmar: ehBloqueio ? 'BLOQUEAR' : 'INATIVAR',
        ),
      );
      if (motivo == null) return;
    }

    try {
      switch (escolha) {
        case 'bloquear':
          await alunoService.bloquearAluno(
            aluno.uid,
            motivo: motivo!,
            staffUid: staffAtual.uid,
            staffNome: staffAtual.nome,
          );
          avisos.showSnackBar(SnackBar(content: Text('Acesso de ${aluno.nome} bloqueado.')));
        case 'desbloquear':
          await alunoService.desbloquearAluno(
            aluno.uid,
            staffUid: staffAtual.uid,
            staffNome: staffAtual.nome,
          );
          avisos.showSnackBar(SnackBar(content: Text('Acesso de ${aluno.nome} desbloqueado.')));
        case 'inativar':
          await alunoService.inativarAluno(
            aluno.uid,
            motivo: motivo,
            staffUid: staffAtual.uid,
            staffNome: staffAtual.nome,
          );
          avisos.showSnackBar(SnackBar(content: Text('${aluno.nome} agora está inativo.')));
      }
    } catch (_) {
      avisos.showSnackBar(
        SnackBar(
          content: const Text('Não foi possível salvar. Tente novamente.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  bool get _temFrequencia =>
      PermissionService.has(staffAtual, Permission.frequencia);

  void _abrir(BuildContext context, String titulo, Widget conteudo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ParteDaFichaScreen(
          titulo: titulo,
          alunoNome: aluno.nome,
          child: conteudo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      CardPremium(
        desenho: Desenhos.cartao,
        rotulo: 'Dados\npessoais',
        onTap: () => _abrir(
          context,
          'Dados pessoais',
          DadosTab(
            aluno: aluno,
            alunoService: alunoService,
            storageService: storageService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      CardPremium(
        desenho: Desenhos.anamnese,
        rotulo: 'Anamnese',
        onTap: () => _abrir(
          context,
          'Anamnese',
          AnamneseTab(
            uid: aluno.uid,
            alunoService: alunoService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      CardPremium(
        desenho: Desenhos.escudo,
        rotulo: 'Termo',
        onTap: () => _abrir(
          context,
          'Termo',
          TermoTab(
            aluno: aluno,
            alunoService: alunoService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      CardPremium(
        desenho: Desenhos.medidas,
        rotulo: 'Avaliações',
        onTap: () => _abrir(
          context,
          'Avaliações',
          AvaliacoesTab(
            uid: aluno.uid,
            alunoService: alunoService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      CardPremium(
        desenho: Desenhos.ficha,
        rotulo: 'Treinos',
        onTap: () => _abrir(
          context,
          'Treinos',
          TreinosTab(
            uid: aluno.uid,
            alunoService: alunoService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      if (_temFrequencia)
        CardPremium(
          desenho: Desenhos.evolucao,
          rotulo: 'Frequência',
          onTap: () => _abrir(
            context,
            'Frequência',
            FrequenciaTab(
              uid: aluno.uid,
              alunoService: alunoService,
              acessoService: acessoService,
              staffAtual: staffAtual,
            ),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(aluno.nome, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            StreamBuilder<Aluno?>(
              stream: alunoService.watchAluno(aluno.uid),
              builder: (context, snapshot) => _Cabecalho(
                aluno: aluno,
                ficha: snapshot.data,
                onGerenciarAcesso: _podeGerenciarAcesso
                    ? () => _gerenciarAcesso(context, snapshot.data)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.94,
              children: cards,
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto com aro dourado, nome, e-mail e a situação da mensalidade.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.aluno, required this.ficha, this.onGerenciarAcesso});

  /// Null esconde o botão "Gerenciar acesso" (sem permissão).
  final VoidCallback? onGerenciarAcesso;

  final AppUser aluno;
  final Aluno? ficha;

  (String, Color) _situacao() {
    final f = ficha;
    if (f != null && !f.ativo) return ('Inativo', AppColors.textSecondary);
    if (f != null && f.bloqueado) {
      return ('Acesso bloqueado pela recepção', AppColors.error);
    }
    final status = calcularStatusAcesso(
      proximoVencimento: f?.proximoVencimento,
    );
    switch (status.status) {
      case StatusMensalidade.emDia:
        return status.diasParaVencimento == 0
            ? ('Vence hoje', AppColors.gold)
            : ('Em dia', const Color(0xFF4CAF6D));
      case StatusMensalidade.tolerancia:
        return ('Vencida', AppColors.gold);
      case StatusMensalidade.bloqueado:
        return ('Bloqueado · mensalidade vencida', AppColors.error);
      case StatusMensalidade.semRegistro:
        return ('Sem vencimento', AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = imagemDaFotoAluno(ficha?.fotoUrl);
    final inicial = aluno.nome.trim().isEmpty
        ? '?'
        : aluno.nome.trim()[0].toUpperCase();
    final (texto, cor) = _situacao();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9941A), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x59FFBE28), blurRadius: 14),
            ],
          ),
          child: CircleAvatar(
            radius: 46,
            backgroundColor: const Color(0xFF1A1A1A),
            backgroundImage: foto,
            onBackgroundImageError: foto != null ? (_, _) {} : null,
            child: foto == null
                ? Text(
                    inicial,
                    style: const TextStyle(
                      color: OuroPremium.texto,
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          aluno.nome,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          aluno.email,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        ),
        if (_detalhe() != null) ...[
          const SizedBox(height: 6),
          Text(
            _detalhe()!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
        if (onGerenciarAcesso != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onGerenciarAcesso,
            icon: const Icon(Icons.manage_accounts_outlined, size: 20),
            label: const Text('GERENCIAR ACESSO'),
          ),
        ],
      ],
    );
  }

  /// Motivo e autor do bloqueio/inativação manual, quando houver.
  String? _detalhe() {
    final f = ficha;
    if (f == null) return null;
    String data(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (!f.ativo) {
      final partes = [
        if (f.dataInativacao != null) 'Desde ${data(f.dataInativacao!)}',
        if (f.inativadoPorNome != null) 'por ${f.inativadoPorNome}',
      ];
      final motivo = f.motivoInativacao;
      final linha = partes.join(' ');
      if (motivo == null && linha.isEmpty) return null;
      return [if (motivo != null) 'Motivo: $motivo', if (linha.isNotEmpty) linha].join('\n');
    }
    if (f.bloqueado) {
      final quem = [
        if (f.bloqueadoPorNome != null) 'por ${f.bloqueadoPorNome}',
        if (f.bloqueadoEm != null) 'em ${data(f.bloqueadoEm!)}',
      ].join(' ');
      return [
        if (f.motivoBloqueio != null) 'Motivo: ${f.motivoBloqueio}',
        if (quem.isNotEmpty) 'Bloqueado $quem',
      ].join('\n');
    }
    return null;
  }
}

/// Uma parte da ficha (Dados, Anamnese...) em tela cheia.
class _ParteDaFichaScreen extends StatelessWidget {
  const _ParteDaFichaScreen({
    required this.titulo,
    required this.alunoNome,
    required this.child,
  });

  final String titulo;
  final String alunoNome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(titulo, overflow: TextOverflow.ellipsis),
            Text(
              alunoNome,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

/// Confirmação com motivo (obrigatório pra bloquear, opcional pra
/// inativar). Devolve o motivo ('' se vazio e opcional), ou null se
/// cancelar.
class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({
    required this.titulo,
    required this.explicacao,
    required this.motivoObrigatorio,
    required this.confirmar,
  });

  final String titulo;
  final String explicacao;
  final bool motivoObrigatorio;
  final String confirmar;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _formKey = GlobalKey<FormState>();
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_motivo.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.explicacao, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _motivo,
              autofocus: true,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.motivoObrigatorio ? 'Motivo' : 'Motivo (opcional)',
              ),
              validator: (texto) => widget.motivoObrigatorio && (texto ?? '').trim().isEmpty
                  ? 'Informe o motivo.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCELAR')),
        TextButton(onPressed: _confirmar, child: Text(widget.confirmar)),
      ],
    );
  }
}
