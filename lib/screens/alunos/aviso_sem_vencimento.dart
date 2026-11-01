import 'package:flutter/material.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/mensalidade_utils.dart';

/// Aluno sem vencimento definido e a data que ele vai receber.
class AlunoSemVencimento {
  const AlunoSemVencimento({required this.aluno, required this.vencimento});

  final AppUser aluno;
  final DateTime vencimento;
}

/// Alunos ativos sem vencimento — os cadastrados antes do vencimento
/// automático — com a data que cada um vai receber
/// ([vencimentoParaAlunoAntigo]: o dia do mês em que começou, na próxima
/// vez que ele cair). Ordem alfabética.
List<AlunoSemVencimento> alunosSemVencimento({
  required List<AppUser> alunos,
  required List<Aluno> fichas,
  required DateTime hoje,
}) {
  final fichaPorUid = {for (final ficha in fichas) ficha.uid: ficha};
  final pendentes = <AlunoSemVencimento>[];
  for (final aluno in alunos) {
    final ficha = fichaPorUid[aluno.uid];
    if (ficha?.proximoVencimento != null) continue;
    if (ficha != null && !ficha.ativo) continue;
    pendentes.add(
      AlunoSemVencimento(
        aluno: aluno,
        vencimento: vencimentoParaAlunoAntigo(
          inicio: ficha?.dataInicio ?? aluno.criadoEm,
          hoje: hoje,
        ),
      ),
    );
  }
  pendentes.sort(
    (a, b) => a.aluno.nome.toLowerCase().compareTo(b.aluno.nome.toLowerCase()),
  );
  return pendentes;
}

String _data(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

/// Faixa na tela Alunos: "N alunos sem vencimento" + botão pra preencher
/// todos de uma vez (com confirmação mostrando a data de cada um). Some
/// sozinha quando não há mais nenhum pendente.
class AvisoSemVencimento extends StatefulWidget {
  const AvisoSemVencimento({super.key, required this.alunoService});

  final AlunoService alunoService;

  @override
  State<AvisoSemVencimento> createState() => _AvisoSemVencimentoState();
}

class _AvisoSemVencimentoState extends State<AvisoSemVencimento> {
  late final Stream<List<AppUser>> _alunos = widget.alunoService.watchAlunos();
  late final Stream<List<Aluno>> _fichas = widget.alunoService
      .watchTodosAlunos();
  bool _salvando = false;

  Future<void> _confirmar(List<AlunoSemVencimento> pendentes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preencher vencimentos'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cada aluno vence no mesmo dia do mês em que começou, '
                'na próxima vez que esse dia chegar. Ninguém fica atrasado.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in pendentes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.aluno.nome,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _data(item.vencimento),
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('PREENCHER'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await widget.alunoService.definirVencimentosEmLote({
        for (final item in pendentes) item.aluno.uid: item.vencimento,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vencimento preenchido para ${pendentes.length} aluno(s).',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Erro ao preencher os vencimentos. Tente novamente.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _alunos,
      builder: (context, alunosSnap) {
        return StreamBuilder<List<Aluno>>(
          stream: _fichas,
          builder: (context, fichasSnap) {
            if (!alunosSnap.hasData || !fichasSnap.hasData) {
              return const SizedBox.shrink();
            }
            final pendentes = alunosSemVencimento(
              alunos: alunosSnap.data!,
              fichas: fichasSnap.data!,
              hoje: DateTime.now(),
            );
            if (pendentes.isEmpty) return const SizedBox.shrink();

            final n = pendentes.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_busy_outlined, color: AppColors.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        n == 1
                            ? '1 aluno sem vencimento'
                            : '$n alunos sem vencimento',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _salvando ? null : () => _confirmar(pendentes),
                      child: _salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('PREENCHER'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
