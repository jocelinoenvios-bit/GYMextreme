import 'package:cloud_firestore/cloud_firestore.dart';

/// Se o aluno treinou ou faltou num dia específico — só existe registro
/// quando algum membro da equipe confirma (ver `StatusTreinoRegistrado`
/// pra como a UI trata "sem registro nenhum", que é diferente de
/// "faltou").
enum StatusHistoricoTreino {
  realizado,
  falta;

  String get label => switch (this) {
    StatusHistoricoTreino.realizado => 'Realizado',
    StatusHistoricoTreino.falta => 'Falta',
  };
}

/// Um registro de presença/frequência do aluno num treino prescrito
/// (coleção `alunos/{uid}/historicoTreinos`) — sempre separado da ficha
/// prescrita (`Treino`): a ficha nunca desaparece por falta de registro
/// aqui, e este registro nunca é criado pelo próprio aluno (ver
/// `firestore.rules` — só quem tem `criarTreinos`/`editarTreinos`
/// grava). Sem registro pra uma data = "não registrado" na UI, nunca
/// assumido como falta.
class HistoricoTreino {
  const HistoricoTreino({
    this.id,
    required this.treinoId,
    required this.data,
    required this.diaSemana,
    required this.status,
    this.observacoes,
    this.registradoPorUid,
    this.registradoPorNome,
    this.registradoEm,
  });

  final String? id;

  /// Referencia o `Treino.id` que estava prescrito nessa data — permite
  /// mostrar nome/letra do treino junto do status na tela de histórico
  /// sem duplicar esses dados aqui.
  final String treinoId;

  /// Data (dia civil, sem hora) a que este registro se refere — não é
  /// necessariamente "hoje": o staff pode registrar retroativamente.
  final DateTime data;

  /// Dia da semana de [data], na convenção de `DateTime.weekday` (1 =
  /// segunda ... 7 = domingo) — guardado explicitamente (em vez de só
  /// derivado de `data.weekday` na hora de ler) pra permitir agrupar
  /// por dia da semana com uma leitura simples, sem reprocessar datas.
  final int diaSemana;

  final StatusHistoricoTreino status;
  final String? observacoes;

  /// Auditoria: qual membro da equipe registrou — nunca o próprio
  /// aluno (bloqueado em `firestore.rules`).
  final String? registradoPorUid;
  final String? registradoPorNome;
  final DateTime? registradoEm;

  factory HistoricoTreino.fromFirestore(String id, Map<String, dynamic> data) {
    final dataRegistro = data['data'];
    final registradoEm = data['registradoEm'];
    return HistoricoTreino(
      id: id,
      treinoId: data['treinoId'] as String? ?? '',
      data: dataRegistro is Timestamp ? dataRegistro.toDate() : DateTime.now(),
      diaSemana: (data['diaSemana'] as num?)?.toInt() ?? 1,
      status: _statusOrNull(data['status']) ?? StatusHistoricoTreino.falta,
      observacoes: data['observacoes'] as String?,
      registradoPorUid: data['registradoPorUid'] as String?,
      registradoPorNome: data['registradoPorNome'] as String?,
      registradoEm: registradoEm is Timestamp ? registradoEm.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'treinoId': treinoId,
      'data': Timestamp.fromDate(data),
      'diaSemana': diaSemana,
      'status': status.name,
      'observacoes': observacoes,
      'registradoEm': FieldValue.serverTimestamp(),
    };
  }

  static StatusHistoricoTreino? _statusOrNull(dynamic name) {
    if (name is! String) return null;
    for (final status in StatusHistoricoTreino.values) {
      if (status.name == name) return status;
    }
    return null;
  }
}
