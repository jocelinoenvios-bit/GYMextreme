import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import 'meus_dados_aluno_screen.dart';
import 'minha_anamnese_screen.dart';
import 'minha_evolucao_screen.dart';
import 'minha_ficha_screen.dart';
import 'minhas_medidas_screen.dart';

/// Hub "Meu perfil" do aluno — ponto de entrada único pras telas novas
/// de autoconsulta (ficha por dia da semana, histórico de presença,
/// medidas, anamnese e evolução), todas somente leitura. Não substitui
/// "MEUS TREINOS" (execução dos treinos, já existente em
/// `MeusTreinosScreen`) nem "BIBLIOTECA DE EXERCÍCIOS" — só organiza o
/// que era novo desta área.
class MeuPerfilScreen extends StatelessWidget {
  const MeuPerfilScreen({
    super.key,
    required this.usuario,
    required this.uid,
    required this.alunoService,
  });

  final AppUser usuario;
  final String uid;
  final AlunoService alunoService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ItemPerfil(
              icone: Icons.badge_outlined,
              titulo: 'Dados pessoais',
              subtitulo: 'Seus dados de cadastro',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MeusDadosAlunoScreen(
                    usuario: usuario,
                    uid: uid,
                    alunoService: alunoService,
                  ),
                ),
              ),
            ),
            _ItemPerfil(
              icone: Icons.calendar_view_week_outlined,
              titulo: 'Minha ficha',
              subtitulo: 'Treinos prescritos por dia da semana e histórico',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MinhaFichaScreen(uid: uid, alunoService: alunoService),
                ),
              ),
            ),
            _ItemPerfil(
              icone: Icons.straighten_outlined,
              titulo: 'Minhas medidas',
              subtitulo: 'Avaliações físicas registradas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MinhasMedidasScreen(uid: uid, alunoService: alunoService),
                ),
              ),
            ),
            _ItemPerfil(
              icone: Icons.assignment_outlined,
              titulo: 'Minha anamnese',
              subtitulo: 'Suas respostas cadastradas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MinhaAnamneseScreen(uid: uid, alunoService: alunoService),
                ),
              ),
            ),
            _ItemPerfil(
              icone: Icons.show_chart_outlined,
              titulo: 'Minha evolução',
              subtitulo: 'Peso, IMC e circunferências ao longo do tempo',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MinhaEvolucaoScreen(uid: uid, alunoService: alunoService),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemPerfil extends StatelessWidget {
  const _ItemPerfil({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.gold.withValues(alpha: 0.15),
          child: Icon(icone, color: AppColors.goldBright),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitulo, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
