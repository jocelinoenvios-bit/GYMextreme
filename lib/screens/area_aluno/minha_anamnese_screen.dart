import 'package:flutter/material.dart';

import '../../models/anamnese.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Ficha de anamnese do próprio aluno, somente leitura — quem
/// preenche/edita é a academia/personal (ver `AnamneseTab`). Mostra só
/// as respostas já dadas; perguntas sem resposta ficam de fora, em vez
/// de aparecer em branco.
class MinhaAnamneseScreen extends StatelessWidget {
  const MinhaAnamneseScreen({super.key, required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minha anamnese')),
      body: SafeArea(
        child: StreamBuilder<Anamnese?>(
          stream: alunoService.watchAnamnese(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final anamnese = snapshot.data;
            final linhas = anamnese == null ? const <_LinhaAnamnese>[] : _linhasDe(anamnese);
            if (anamnese == null || linhas.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Você ainda não possui uma anamnese cadastrada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (anamnese.respondidoEm != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Respondida em ${_formatarData(anamnese.respondidoEm!)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ),
                for (final linha in linhas) _LinhaTile(linha: linha),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}

class _LinhaAnamnese {
  const _LinhaAnamnese(this.pergunta, this.resposta);

  final String pergunta;
  final String resposta;
}

/// Só inclui perguntas que têm resposta — não mostra "não informado"
/// pra cada uma das 13, o que deixaria a tela poluída.
List<_LinhaAnamnese> _linhasDe(Anamnese a) {
  final linhas = <_LinhaAnamnese>[];
  void add(String pergunta, String? resposta) {
    if (resposta != null && resposta.isNotEmpty) linhas.add(_LinhaAnamnese(pergunta, resposta));
  }

  add('Dias pretendidos de treino por semana', a.diasPorSemana?.toString());
  add('Objetivo', a.objetivo?.label);
  add(
    'Pratica musculação atualmente',
    a.situacaoMusculacao == null
        ? null
        : '${a.situacaoMusculacao!.label}'
              '${a.tempoParadoMusculacao?.isNotEmpty == true ? ' — parado há ${a.tempoParadoMusculacao}' : ''}',
  );
  add(
    'Problema de coluna ou joelho',
    a.problemaColunaJoelho == null
        ? null
        : (a.problemaColunaJoelho!
              ? 'Sim${a.problemaColunaJoelhoQual?.isNotEmpty == true ? ' — ${a.problemaColunaJoelhoQual}' : ''}'
              : 'Não'),
  );
  add('Pressão arterial', a.pressaoArterial?.label);
  add(
    'Condições clínicas',
    a.condicoesClinicas.isEmpty
        ? null
        : a.condicoesClinicas.map((c) => condicoesClinicasDisponiveis[c] ?? c).join(', '),
  );
  add(
    'Alergia',
    a.alergia == null
        ? null
        : (a.alergia! ? 'Sim${a.alergiaQual?.isNotEmpty == true ? ' — ${a.alergiaQual}' : ''}' : 'Não'),
  );
  add(
    'Dores no corpo',
    a.doresCorpo == null
        ? null
        : (a.doresCorpo!
              ? 'Sim${a.doresCorpoQual?.isNotEmpty == true ? ' — ${a.doresCorpoQual}' : ''}'
              : 'Não'),
  );
  add(
    'Lesão osteomuscular',
    a.lesaoOsteoMuscular == null
        ? null
        : (a.lesaoOsteoMuscular!
              ? 'Sim${a.lesaoOsteoMuscularQual?.isNotEmpty == true ? ' — ${a.lesaoOsteoMuscularQual}' : ''}'
              : 'Não'),
  );
  add(
    'Cirurgia recente',
    a.cirurgiaRecente == null
        ? null
        : (a.cirurgiaRecente!
              ? 'Sim${a.cirurgiaRecenteDeQue?.isNotEmpty == true ? ' — ${a.cirurgiaRecenteDeQue}' : ''}'
              : 'Não'),
  );
  add(
    'Usa medicamento',
    a.usaMedicamento == null
        ? null
        : (a.usaMedicamento!
              ? 'Sim${a.usaMedicamentoQual?.isNotEmpty == true ? ' — ${a.usaMedicamentoQual}' : ''}'
              : 'Não'),
  );
  add(
    'Faz uso de',
    a.usoSubstancias.isEmpty
        ? null
        : a.usoSubstancias.map((s) => usoSubstanciasDisponiveis[s] ?? s).join(', '),
  );
  if (a.fazendoDieta != null) {
    final detalhes = <String>[
      if (a.dietaPorContaPropria == true) 'por conta própria',
      if (a.dietaOrientacaoNutricionista == true) 'orientação de nutricionista',
    ];
    add(
      'Fazendo dieta',
      a.fazendoDieta! ? 'Sim${detalhes.isEmpty ? '' : ' — ${detalhes.join(', ')}'}' : 'Não',
    );
  }
  return linhas;
}

class _LinhaTile extends StatelessWidget {
  const _LinhaTile({required this.linha});

  final _LinhaAnamnese linha;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            linha.pergunta,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            linha.resposta,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.3),
          ),
        ],
      ),
    );
  }
}
