import 'package:flutter/material.dart';

import '../models/aluno.dart';
import '../models/app_user.dart';
import '../models/permission.dart';
import '../models/user_role.dart';
import '../services/aluno_service.dart';
import '../services/auth_service.dart';
import '../services/cargo_service.dart';
import '../services/funcionario_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/status_acesso.dart';
import '../widgets/gymextreme_logo.dart';
import 'alunos/alunos_list_screen.dart';
import 'exercicios/exercicios_list_screen.dart';
import 'funcionarios/funcionarios_list_screen.dart';

/// Tela pos-login: cada botao aparece de acordo com as permissoes
/// individuais do usuario logado (ver `PermissionService`), nao mais um
/// unico bloco "staff vs aluno". As demais telas de cada perfil chegam nos
/// proximos modulos.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.uid,
    required this.authService,
    required this.userService,
    required this.alunoService,
    required this.cargoService,
    required this.funcionarioService,
    required this.storageService,
  });

  final String uid;
  final AuthService authService;
  final UserService userService;
  final AlunoService alunoService;
  final CargoService cargoService;
  final FuncionarioService funcionarioService;
  final StorageService storageService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const GymExtremeLogo(compact: true),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<AppUser?>(
        stream: userService.watchUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar seu perfil.',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(
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
                  return const _AcessoSuspenso();
                }
                return _buildConteudoPadrao(context, user);
              },
            );
          }

          return _buildConteudoPadrao(context, user);
        },
      ),
    );
  }

  Widget _buildConteudoPadrao(BuildContext context, AppUser user) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(user.role), color: AppColors.gold, size: 56),
            const SizedBox(height: 16),
            Text(
              'Bem-vindo, ${user.role.welcomeLabel}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              user.nome,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
            if (PermissionService.has(user, Permission.gerenciarAlunos)) ...[
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlunosListScreen(
                      alunoService: alunoService,
                      storageService: storageService,
                      staffAtual: user,
                    ),
                  ),
                ),
                icon: const Icon(Icons.groups_outlined),
                label: const Text('GERENCIAR ALUNOS'),
              ),
            ],
            // Permission.bibliotecaExercicios é uma permissão de staff (o
            // aluno nunca tem nenhuma, por blindagem em
            // PermissionService.effectivePermissions) — mas a Biblioteca
            // Oficial é só um catálogo de referência, sem escrita, então
            // faz sentido pro aluno também ver, sem depender do sistema
            // de permissões de equipe.
            if (user.role == UserRole.aluno ||
                PermissionService.has(user, Permission.bibliotecaExercicios)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ExerciciosListScreen(),
                  ),
                ),
                icon: const Icon(Icons.fitness_center_outlined),
                label: const Text('BIBLIOTECA DE EXERCÍCIOS'),
              ),
            ],
            if (PermissionService.has(user, Permission.gerenciarFuncionarios)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FuncionariosListScreen(
                      funcionarioService: funcionarioService,
                      cargoService: cargoService,
                    ),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('GERENCIAR FUNCIONÁRIOS'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(UserRole role) {
    switch (role) {
      case UserRole.adm:
        return Icons.admin_panel_settings_outlined;
      case UserRole.personal:
        return Icons.sports_gymnastics_outlined;
      case UserRole.funcionario:
        return Icons.badge_outlined;
      case UserRole.aluno:
        return Icons.fitness_center_outlined;
    }
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
            const Icon(Icons.lock_outline, color: AppColors.error, size: 56),
            const SizedBox(height: 16),
            Text(
              'Acesso suspenso',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sua mensalidade permanece em atraso. Seu acesso ao '
              'aplicativo e à academia foi bloqueado até a regularização '
              'do pagamento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
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
