import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/cargo.dart';
import '../../services/cargo_service.dart';
import '../../services/funcionario_service.dart';
import '../../theme/app_colors.dart';
import 'funcionario_form_screen.dart';

/// Lista de funcionarios (ADM, Personal e Recepcionista/cargos
/// customizados), ponto de entrada do ADM para cadastrar gente nova e
/// ajustar permissoes individuais.
class FuncionariosListScreen extends StatelessWidget {
  const FuncionariosListScreen({
    super.key,
    required this.funcionarioService,
    required this.cargoService,
  });

  final FuncionarioService funcionarioService;
  final CargoService cargoService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Funcionários')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FuncionarioFormScreen(
              funcionarioService: funcionarioService,
              cargoService: cargoService,
            ),
          ),
        ),
        tooltip: 'Novo funcionário',
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
      body: StreamBuilder<List<Cargo>>(
        stream: cargoService.watchCargos(),
        builder: (context, cargosSnapshot) {
          final cargos = cargosSnapshot.data ?? CargosPadrao.todos;

          return StreamBuilder<List<AppUser>>(
            stream: funcionarioService.watchFuncionarios(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                // Mesma consulta where+orderBy em campos diferentes do
                // watchAlunos — mostra o erro real, provavelmente um link
                // do Firestore pra criar o índice composto que falta.
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        'Erro ao carregar os funcionários.\n\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                );
              }

              final funcionarios = snapshot.data ?? [];
              if (funcionarios.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhum funcionário cadastrado ainda. Toque em "+" '
                      'para cadastrar o primeiro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: funcionarios.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: AppColors.surfaceHigh),
                itemBuilder: (context, index) {
                  final funcionario = funcionarios[index];
                  String? cargoNome;
                  for (final cargo in cargos) {
                    if (cargo.id == funcionario.cargoId) {
                      cargoNome = cargo.nome;
                      break;
                    }
                  }

                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceHigh,
                      child: Icon(Icons.badge_outlined, color: AppColors.gold),
                    ),
                    title: Text(funcionario.nome),
                    subtitle: Text(
                      cargoNome ?? funcionario.role.welcomeLabel,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FuncionarioFormScreen(
                          funcionarioService: funcionarioService,
                          cargoService: cargoService,
                          funcionario: funcionario,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
