import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/aluno.dart';
import '../models/app_user.dart';
import '../models/mensagem.dart';
import '../models/permission.dart';
import '../models/user_role.dart';
import '../services/aluno_service.dart';
import '../services/auth_service.dart';
import '../services/caixa_service.dart';
import '../services/cargo_service.dart';
import '../services/conta_pagar_service.dart';
import '../services/funcionario_service.dart';
import '../services/notificacao_service.dart';
import '../services/permission_service.dart';
import '../services/plano_service.dart';
import '../services/produto_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/status_acesso.dart';
import '../widgets/gymextreme_logo.dart';
import '../widgets/premium.dart';
import 'alunos/alunos_list_screen.dart';
import 'alunos/enviar_mensagem_screen.dart';
import 'area_aluno/meus_dados_aluno_screen.dart';
import 'area_aluno/meus_treinos_screen.dart';
import 'area_aluno/mensagens_screen.dart';
import 'area_aluno/minha_anamnese_screen.dart';
import 'area_aluno/minha_evolucao_screen.dart';
import 'area_aluno/minha_ficha_screen.dart';
import 'area_aluno/minhas_medidas_screen.dart';
import 'caixa/caixa_screen.dart';
import 'contas_pagar/contas_pagar_list_screen.dart';
import 'contas_receber/contas_receber_list_screen.dart';
import 'exercicios/exercicios_list_screen.dart';
import 'funcionarios/funcionarios_list_screen.dart';
import 'matriculas/matriculas_list_screen.dart';
import 'planos/planos_list_screen.dart';
import 'produtos/produtos_list_screen.dart';
import 'relatorios/dashboard_screen.dart';

/// Tela pos-login: cada botao aparece de acordo com as permissoes
/// individuais do usuario logado (ver `PermissionService`), nao mais um
/// unico bloco "staff vs aluno". As demais telas de cada perfil chegam nos
/// proximos modulos.
///
/// O aluno tem uma tela inicial própria (`_buildHomeAluno`), redesenhada
/// pra ficar mais parecida com um app de rede social/menu de celular —
/// staff continua com a tela genérica de sempre (`_scaffoldGenerico` +
/// `_buildConteudoPadrao`).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.uid,
    required this.authService,
    required this.userService,
    required this.alunoService,
    required this.caixaService,
    required this.cargoService,
    required this.contaPagarService,
    required this.funcionarioService,
    required this.notificacaoService,
    required this.planoService,
    required this.produtoService,
    required this.storageService,
  });

  final String uid;
  final AuthService authService;
  final UserService userService;
  final AlunoService alunoService;
  final CaixaService caixaService;
  final CargoService cargoService;
  final ContaPagarService contaPagarService;
  final FuncionarioService funcionarioService;
  final NotificacaoService notificacaoService;
  final PlanoService planoService;
  final ProdutoService produtoService;
  final StorageService storageService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: userService.watchUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _scaffoldGenerico(
            context,
            const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _scaffoldGenerico(
            context,
            Center(
              child: Text(
                'Erro ao carregar seu perfil.',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return _scaffoldGenerico(
            context,
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Login efetuado, mas nao encontramos seu cadastro na '
                  'colecao "usuarios" do Firestore. Peça para a '
                  'administracao criar seu perfil com o campo "role".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          );
        }

        if (user.role == UserRole.aluno) {
          return StreamBuilder<Aluno?>(
            stream: alunoService.watchAluno(uid),
            builder: (context, alunoSnapshot) {
              final status = calcularStatusAcesso(
                proximoVencimento: alunoSnapshot.data?.proximoVencimento,
              );
              if (status.status == StatusMensalidade.bloqueado) {
                return _scaffoldGenerico(context, const _AcessoSuspenso());
              }
              return _buildHomeAluno(context, user, alunoSnapshot.data);
            },
          );
        }

        return _scaffoldGenerico(
          context,
          _buildConteudoPadrao(context, user),
          user: user,
        );
      },
    );
  }

  /// Scaffold "de sempre" (logo + botão de sair na AppBar) — usado pro
  /// staff inteiro e pelos estados genéricos (carregando/erro/bloqueado)
  /// de qualquer papel, inclusive aluno. Com [user] informado (telas de
  /// staff já carregadas), ganha a engrenagem de configurações no canto
  /// superior esquerdo — nome/e-mail saem da tela principal e vão pra lá,
  /// mesmo padrão já usado na tela inicial do aluno. Sem [user] (telas de
  /// carregando/erro/bloqueado), não tem o que mostrar nas configurações
  /// ainda, então a engrenagem fica de fora.
  Scaffold _scaffoldGenerico(
    BuildContext context,
    Widget body, {
    AppUser? user,
  }) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        leading: user == null
            ? null
            : IconButton(
                tooltip: 'Configurações',
                icon: const Icon(
                  Icons.settings_outlined,
                  color: OuroPremium.texto,
                  size: 28,
                  shadows: [Shadow(color: Color(0x80FFC72C), blurRadius: 8)],
                ),
                onPressed: () => _abrirConfiguracoes(context, user),
              ),
        title: const GymExtremeLogo(compact: true),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(
              Icons.logout,
              color: OuroPremium.texto,
              size: 28,
              shadows: [Shadow(color: Color(0x80FFC72C), blurRadius: 8)],
            ),
            onPressed: () => _sair(),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Future<void> _sair() async {
    // Remove o token FCM deste aparelho ANTES de sair — depois do
    // signOut() o Firestore ja nao autoriza mais essa escrita (regra
    // exige request.auth.uid == uid).
    await notificacaoService.removerTokenDoAparelho(uid);
    await authService.signOut();
  }

  /// Tela inicial do aluno, no visual premium: foto com aro dourado no
  /// canto superior esquerdo, halter dourado de destaque, saudação com o
  /// nome, os 2 atalhos principais em botões dourados e as funções do
  /// perfil em cards. Nome/e-mail e "Sair" ficam na engrenagem (canto
  /// inferior direito).
  Widget _buildHomeAluno(BuildContext context, AppUser user, Aluno? aluno) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _AvatarAluno(
              nome: user.nome,
              fotoUrl: aluno?.fotoUrl,
              raio: 21,
            ),
          ),
        ),
        leadingWidth: 68,
        title: const GymExtremeLogo(compact: true),
        centerTitle: true,
      ),
      floatingActionButton: _EngrenagemOuro(
        onTap: () => _abrirConfiguracoes(context, user),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FaixaDouradaRodape(altura: 190),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                // Espaço embaixo pra engrenagem não cobrir o último card.
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DestaquePremium(
                      desenho: Desenhos.halter,
                      largura: 214,
                      altura: 120,
                    ),
                    SaudacaoPremium(nome: user.nome, tamanho: 27),
                    const SizedBox(height: 20),
                    BotaoOuro(
                      icone: Icons.fitness_center,
                      giroIcone: -math.pi / 4,
                      rotulo: 'BIBLIOTECA DE EXERCÍCIOS',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExerciciosListScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    BotaoOuro(
                      icone: Icons.trending_up,
                      rotulo: 'MEUS TREINOS',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MeusTreinosScreen(
                            uid: uid,
                            alunoService: alunoService,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _TituloSecao('MEU PERFIL'),
                    const SizedBox(height: 14),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.94,
                      children: [
                        CardPremium(
                          desenho: Desenhos.cartao,
                          rotulo: 'Dados\npessoais',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MeusDadosAlunoScreen(
                                usuario: user,
                                uid: uid,
                                alunoService: alunoService,
                              ),
                            ),
                          ),
                        ),
                        CardPremium(
                          desenho: Desenhos.ficha,
                          rotulo: 'Minha\nficha',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MinhaFichaScreen(
                                uid: uid,
                                alunoService: alunoService,
                              ),
                            ),
                          ),
                        ),
                        CardPremium(
                          desenho: Desenhos.medidas,
                          rotulo: 'Minhas\nmedidas',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MinhasMedidasScreen(
                                uid: uid,
                                alunoService: alunoService,
                              ),
                            ),
                          ),
                        ),
                        CardPremium(
                          desenho: Desenhos.anamnese,
                          rotulo: 'Minha\nanamnese',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MinhaAnamneseScreen(
                                uid: uid,
                                alunoService: alunoService,
                              ),
                            ),
                          ),
                        ),
                        CardPremium(
                          desenho: Desenhos.evolucao,
                          rotulo: 'Minha\nevolução',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MinhaEvolucaoScreen(
                                uid: uid,
                                alunoService: alunoService,
                              ),
                            ),
                          ),
                        ),
                        // Reaproveita o mesmo stream que a tela de mensagens
                        // usa, em vez de uma consulta só de contagem: o
                        // volume de avisos por aluno é pequeno e assim o selo
                        // zera junto com a leitura, sem um segundo listener.
                        StreamBuilder<List<Mensagem>>(
                          stream: alunoService.watchMensagens(uid),
                          builder: (context, snapshot) {
                            final naoLidas =
                                (snapshot.data ?? const <Mensagem>[])
                                    .where((mensagem) => !mensagem.lida)
                                    .length;
                            return CardPremium(
                              desenho: Desenhos.mensagens,
                              rotulo: 'Mensagens',
                              naoLidas: naoLidas,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MensagensScreen(
                                    uid: uid,
                                    alunoService: alunoService,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Painel de configurações (nome completo, e-mail, sair) — aberto pelo
  /// botão de engrenagem da tela inicial do aluno.
  void _abrirConfiguracoes(BuildContext context, AppUser user) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurações',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  user.nome,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _sair();
                    },
                    icon: Icon(Icons.logout, color: AppColors.error),
                    label: Text(
                      'SAIR',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Tela inicial do staff (ADM, Personal e Funcionário), no visual
  /// premium: escudo dourado de destaque, saudação e um card por módulo —
  /// cada card só aparece pra quem tem a permissão daquele módulo.
  Widget _buildConteudoPadrao(BuildContext context, AppUser user) {
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FaixaDouradaRodape(),
        ),
        // Rolável porque a quantidade de cards varia com as permissões —
        // um ADM com tudo liberado não cabe inteiro em muitos aparelhos.
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              children: [
                const DestaquePremium(
                  desenho: Desenhos.escudo,
                  largura: 112,
                  altura: 112,
                  comSilhuetas: true,
                ),
                const SizedBox(height: 6),
                SaudacaoPremium(
                  nome: user.role.welcomeLabel,
                  tamanho: 31,
                  nomeItalico: true,
                ),
                const SizedBox(height: 22),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    if (PermissionService.has(user, Permission.relatorios))
                      CardPremium(
                        desenho: Desenhos.painel,
                        rotulo: 'Painel e\nrelatórios',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DashboardScreen(
                              alunoService: alunoService,
                              caixaService: caixaService,
                              contaPagarService: contaPagarService,
                              produtoService: produtoService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(user, Permission.gerenciarAlunos))
                      CardPremium(
                        desenho: Desenhos.alunos,
                        rotulo: 'Gerenciar\nalunos',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AlunosListScreen(
                              alunoService: alunoService,
                              storageService: storageService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(user, Permission.chat))
                      CardPremium(
                        desenho: Desenhos.enviarMensagem,
                        rotulo: 'Enviar\nmensagem',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EnviarMensagemScreen(
                              alunoService: alunoService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(user, Permission.acessarPlanos))
                      CardPremium(
                        desenho: Desenhos.planos,
                        rotulo: 'Planos',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlanosListScreen(
                              planoService: planoService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(user, Permission.matriculas))
                      CardPremium(
                        desenho: Desenhos.cartao,
                        rotulo: 'Matrículas',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MatriculasListScreen(
                              alunoService: alunoService,
                              planoService: planoService,
                              storageService: storageService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(
                      user,
                      Permission.acessarContasReceber,
                    ))
                      CardPremium(
                        desenho: Desenhos.contasReceber,
                        rotulo: 'Contas a\nreceber',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ContasReceberListScreen(
                              alunoService: alunoService,
                              caixaService: caixaService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(
                      user,
                      Permission.acessarControleCaixa,
                    ))
                      CardPremium(
                        desenho: Desenhos.caixa,
                        rotulo: 'Controle de\ncaixa',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CaixaScreen(
                              caixaService: caixaService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(
                      user,
                      Permission.acessarContasPagar,
                    ))
                      CardPremium(
                        desenho: Desenhos.contasPagar,
                        rotulo: 'Contas a\npagar',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ContasPagarListScreen(
                              contaPagarService: contaPagarService,
                              caixaService: caixaService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(user, Permission.acessarProdutos))
                      CardPremium(
                        desenho: Desenhos.produtos,
                        rotulo: 'Produtos',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProdutosListScreen(
                              produtoService: produtoService,
                              staffAtual: user,
                            ),
                          ),
                        ),
                      ),
                    if (PermissionService.has(
                      user,
                      Permission.bibliotecaExercicios,
                    ))
                      CardPremium(
                        desenho: Desenhos.biblioteca,
                        rotulo: 'Biblioteca de\nexercícios',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ExerciciosListScreen(),
                          ),
                        ),
                      ),
                    if (PermissionService.has(
                      user,
                      Permission.gerenciarFuncionarios,
                    ))
                      CardPremium(
                        desenho: Desenhos.funcionarios,
                        rotulo: 'Gerenciar\nfuncionários',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FuncionariosListScreen(
                              funcionarioService: funcionarioService,
                              cargoService: cargoService,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Foto do aluno (ou círculo com a inicial do nome, se não tiver foto
/// cadastrada), com aro dourado — canto superior esquerdo da tela
/// inicial do aluno.
class _AvatarAluno extends StatelessWidget {
  const _AvatarAluno({
    required this.nome,
    required this.fotoUrl,
    required this.raio,
  });

  final String nome;
  final String? fotoUrl;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC9941A), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x59FFBE28), blurRadius: 12)],
      ),
      child: CircleAvatar(
        radius: raio,
        backgroundColor: const Color(0xFF1A1A1A),
        backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl!) : null,
        child: fotoUrl == null
            ? Text(
                inicial,
                style: TextStyle(
                  color: OuroPremium.texto,
                  fontWeight: FontWeight.bold,
                  fontSize: raio * 0.95,
                ),
              )
            : null,
      ),
    );
  }
}

/// Botão redondo dourado da engrenagem de configurações do aluno.
class _EngrenagemOuro extends StatelessWidget {
  const _EngrenagemOuro({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x8CFFBE28), blurRadius: 22)],
      ),
      child: Material(
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(gradient: OuroPremium.degrade),
          child: InkWell(
            onTap: onTap,
            child: const Tooltip(
              message: 'Configurações',
              child: Center(
                child: Icon(
                  Icons.settings_outlined,
                  color: OuroPremium.tinta,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de seção em dourado com uma linha que some à direita.
class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          texto,
          style: const TextStyle(
            color: OuroPremium.texto,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: SizedBox(
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFC9941A), Color(0x00C9941A)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tela mostrada no lugar do conteudo normal quando a mensalidade do aluno
/// passou dos dias de tolerancia — mesmo texto usado na notificacao
/// (`mensagemNotificacaoMensalidade`), sempre visivel enquanto bloqueado
/// (nao so no primeiro dia).
class _AcessoSuspenso extends StatelessWidget {
  const _AcessoSuspenso();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: AppColors.error, size: 56),
            const SizedBox(height: 16),
            Text(
              'Acesso suspenso',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            Text(
              'Sua mensalidade permanece em atraso. Seu acesso ao '
              'aplicativo e à academia foi bloqueado até a regularização '
              'do pagamento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Procure a recepção para regularizar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
