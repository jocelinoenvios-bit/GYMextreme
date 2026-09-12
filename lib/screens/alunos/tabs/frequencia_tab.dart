import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../models/evento_acesso.dart';
import '../../../models/historico_treino.dart';
import '../../../models/permission.dart';
import '../../../models/treino.dart';
import '../../../services/acesso_service.dart';
import '../../../services/aluno_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_colors.dart';

/// Cor de "positivo" (autorizado/realizado) — mesmo verde já usado em
/// `MensalidadeSection` pro status "Em dia" (não existe token dedicado
/// em `AppColors` pra isso ainda).
const _corPositiva = Color(0xFF4CAF6D);

/// Frequência combinada do aluno: acesso físico à academia
/// (`eventosAcesso`, controle de catraca/iDFace) + presença de treino
/// (`historicoTreinos`). A EXPERIÊNCIA é unificada numa aba só, mas as
/// duas fontes continuam tecnicamente separadas — nenhum model, service
/// ou coleção foi fundido: `AcessoService`/`EventoAcesso` de um lado,
/// `AlunoService`/`HistoricoTreino` do outro (inalterados).
///
/// Somente leitura: o aluno nunca cria, edita ou exclui a própria
/// frequência (nem acesso físico, nem presença) — reforçado em
/// `firestore.rules` em ambas as coleções, não só escondido aqui.
///
/// "Não registrado" nunca é tratado como falta: um dia com treino
/// prescrito (`Treino.diaSemana`) sem nenhum `HistoricoTreino`
/// correspondente aparece como "Não registrado", nunca "Falta" — falta
/// só existe quando o staff registrou explicitamente (mesma regra já
/// documentada em `HistoricoTreinosScreen`).
class FrequenciaTab extends StatelessWidget {
  const FrequenciaTab({
    super.key,
    required this.uid,
    required this.alunoService,
    required this.acessoService,
    required this.staffAtual,
  });

  final String uid;
  final AlunoService alunoService;
  final AcessoService acessoService;
  final AppUser staffAtual;

  /// Controla só a visibilidade da seção de acesso físico — a leitura
  /// real de `eventosAcesso` já é protegida por `temPermissao
  /// ('controleCatraca')` em `firestore.rules`; esconder aqui também é
  /// só pra não mostrar uma lista vazia/erro de permissão pra quem não
  /// tem a permissão, nunca a única camada de proteção.
  bool get _podeVerAcessoFisico => PermissionService.has(staffAtual, Permission.controleCatraca);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Acesso físico'),
              Tab(text: 'Presença de treino'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _podeVerAcessoFisico
                    ? _AcessoFisicoSection(uid: uid, acessoService: acessoService)
                    : const _MensagemCentralizada(
                        'Você não tem permissão para ver o acesso físico deste aluno.',
                      ),
                _PresencaTreinoSection(uid: uid, alunoService: alunoService),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MensagemCentralizada extends StatelessWidget {
  const _MensagemCentralizada(this.mensagem);

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _AcessoFisicoSection extends StatelessWidget {
  const _AcessoFisicoSection({required this.uid, required this.acessoService});

  final String uid;
  final AcessoService acessoService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventoAcesso>>(
      stream: acessoService.watchEventosAcesso(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _MensagemCentralizada('Erro ao carregar o histórico de acesso físico.');
        }

        final eventos = snapshot.data ?? [];
        if (eventos.isEmpty) {
          return const _MensagemCentralizada(
            'Nenhum registro de acesso físico ainda.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: eventos.length,
          itemBuilder: (context, index) => _EventoAcessoCard(evento: eventos[index]),
        );
      },
    );
  }
}

class _EventoAcessoCard extends StatelessWidget {
  const _EventoAcessoCard({required this.evento});

  final EventoAcesso evento;

  @override
  Widget build(BuildContext context) {
    final cor = evento.autorizado ? _corPositiva : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatarDataHora(evento.criadoEm),
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  evento.autorizado ? 'Autorizado' : 'Negado',
                  style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          if (!evento.autorizado) ...[
            const SizedBox(height: 6),
            Text(evento.motivoLabel, style: const TextStyle(color: AppColors.textSecondary)),
          ],
          if (evento.metodo != null) ...[
            const SizedBox(height: 4),
            Text(
              'Método: ${evento.metodo}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  String _formatarDataHora(DateTime? data) {
    if (data == null) return 'Data não disponível';
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year} às $hora:$minuto';
  }
}

enum _StatusPresenca { realizado, falta, naoRegistrado }

class _LinhaPresenca {
  const _LinhaPresenca({required this.data, required this.treino, this.registro});

  final DateTime data;
  final Treino treino;
  final HistoricoTreino? registro;

  _StatusPresenca get status {
    final registroAtual = registro;
    if (registroAtual == null) return _StatusPresenca.naoRegistrado;
    return registroAtual.status == StatusHistoricoTreino.realizado
        ? _StatusPresenca.realizado
        : _StatusPresenca.falta;
  }
}

class _PresencaTreinoSection extends StatelessWidget {
  const _PresencaTreinoSection({required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  /// Últimos 14 dias (incluindo hoje) em que havia algum treino ativo
  /// prescrito pro dia da semana correspondente — nunca olha pra dias
  /// futuros (presença futura não existe). Cruza com `HistoricoTreino`
  /// pra decidir Realizado/Falta/Não registrado.
  List<_LinhaPresenca> _construirLinhas(List<Treino> treinosAtivos, List<HistoricoTreino> historico) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final linhas = <_LinhaPresenca>[];

    for (var i = 0; i < 14; i++) {
      final dia = hoje.subtract(Duration(days: i));
      final treinoDoDia = _primeiroTreinoDoDia(treinosAtivos, dia.weekday);
      if (treinoDoDia == null) continue;

      linhas.add(
        _LinhaPresenca(
          data: dia,
          treino: treinoDoDia,
          registro: _primeiroRegistroDoDia(historico, dia),
        ),
      );
    }
    return linhas;
  }

  Treino? _primeiroTreinoDoDia(List<Treino> treinos, int diaSemana) {
    for (final treino in treinos) {
      if (treino.diaSemana == diaSemana) return treino;
    }
    return null;
  }

  HistoricoTreino? _primeiroRegistroDoDia(List<HistoricoTreino> historico, DateTime dia) {
    for (final registro in historico) {
      if (registro.data.year == dia.year &&
          registro.data.month == dia.month &&
          registro.data.day == dia.day) {
        return registro;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Treino>>(
      stream: alunoService.watchTreinos(uid),
      builder: (context, treinosSnapshot) {
        return StreamBuilder<List<HistoricoTreino>>(
          stream: alunoService.watchHistoricoTreinos(uid),
          builder: (context, historicoSnapshot) {
            if (treinosSnapshot.connectionState == ConnectionState.waiting ||
                historicoSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (treinosSnapshot.hasError || historicoSnapshot.hasError) {
              return const _MensagemCentralizada('Erro ao carregar a presença de treino.');
            }

            final treinosAtivos = (treinosSnapshot.data ?? [])
                .where((t) => t.ativo && t.diaSemana != null)
                .toList();
            final historico = historicoSnapshot.data ?? [];
            final linhas = _construirLinhas(treinosAtivos, historico);

            if (linhas.isEmpty) {
              return const _MensagemCentralizada(
                'Nenhum treino prescrito com dia da semana definido ainda.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: linhas.length,
              itemBuilder: (context, index) => _LinhaPresencaCard(linha: linhas[index]),
            );
          },
        );
      },
    );
  }
}

class _LinhaPresencaCard extends StatelessWidget {
  const _LinhaPresencaCard({required this.linha});

  final _LinhaPresenca linha;

  @override
  Widget build(BuildContext context) {
    final (rotulo, cor) = switch (linha.status) {
      _StatusPresenca.realizado => ('Realizado', _corPositiva),
      _StatusPresenca.falta => ('Falta', AppColors.error),
      _StatusPresenca.naoRegistrado => ('Não registrado', AppColors.textSecondary),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatarData(linha.data),
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Treino ${linha.treino.letra} — ${linha.treino.nome}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              rotulo,
              style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }
}
