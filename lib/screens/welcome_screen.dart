import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/permission.dart';
import '../models/user_role.dart';
import '../services/aluno_service.dart';
import '../services/auth_service.dart';
import '../services/cargo_service.dart';
import '../services/exercicio_service.dart';
import '../services/funcionario_service.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
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
    required this.exercicioService,
    required this.cargoService,
    required this.funcionarioService,
  });

  final String uid;
  final AuthService authService;
  final UserService userService;
  final AlunoService alunoService;
  final ExercicioService exercicioService;
  final CargoService cargoService;
  final FuncionarioService funcionarioService;

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
                  Text(
                    user.email,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (PermissionService.has(user, Permission.gerenciarAlunos)) ...[
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlunosListScreen(alunoService: alunoService),
                        ),
                      ),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('GERENCIAR ALUNOS'),
                    ),
                  ],
                  if (PermissionService.has(user, Permission.bibliotecaExercicios)) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciciosListScreen(exercicioService: exercicioService),
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
        },
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
