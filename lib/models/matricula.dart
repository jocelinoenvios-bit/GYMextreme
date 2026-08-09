import 'package:cloud_firestore/cloud_firestore.dart';

/// Situação de uma [Matricula].
enum StatusMatricula {
  ativa,
  vencida,
  cancelada,
  suspensa;

  String get label => switch (this) {
    StatusMatricula.ativa => 'Ativa',
    StatusMatricula.vencida => 'Vencida',
    StatusMatricula.cancelada => 'Cancelada',
    StatusMatricula.suspensa => 'Suspensa',
  };

  static StatusMatricula fromFirestoreValue(String? value) {
    for (final status in StatusMatricula.values) {
      if (status.name == value) return status;
    }
    return StatusMatricula.ativa;
  }
}

/// Uma matrícula do aluno em um [Plano] (coleção `alunos/{uid}/matriculas`)
/// — diferente de `Aluno.ativo` (que só marca se a pessoa continua
/// frequentando a academia), a matrícula é o vínculo contratual com um
/// plano específico, por um período específico. Um aluno pode acumular
/// várias ao longo do tempo (renovações, trocas de plano); só uma pode
/// estar com [status] igual a [StatusMatricula.ativa] por vez — ver
/// `AlunoService.criarMatricula`.
///
/// `valorContratado` é copiado do [Plano] no momento da criação (nunca lido
/// de volta do plano) — alterar o preço do plano depois nunca muda
/// retroativamente o que já foi contratado.
class Matricula {
  const Matricula({
    this.id,
    required this.alunoId,
    required this.planoId,
    required this.dataInicio,
    required this.dataVencimento,
    this.status = StatusMatricula.ativa,
    required this.valorContratado,
    this.formaPagamento,
    this.observacao,
    this.criadoEm,
    this.atualizadoEm,
  });

  final String? id;
  final String alunoId;
  final String planoId;
  final DateTime dataInicio;
  final DateTime dataVencimento;
  final StatusMatricula status;
  final double valorContratado;
  final String? formaPagamento;
  final String? observacao;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  factory Matricula.fromFirestore(String id, Map<String, dynamic> data) {
    final dataInicio = data['dataInicio'];
    final dataVencimento = data['dataVencimento'];
    final criadoEm = data['criadoEm'];
    final atualizadoEm = data['atualizadoEm'];
    return Matricula(
      id: id,
      alunoId: data['alunoId'] as String? ?? '',
      planoId: data['planoId'] as String? ?? '',
      dataInicio: dataInicio is Timestamp ? dataInicio.toDate() : DateTime.now(),
      dataVencimento: dataVencimento is Timestamp ? dataVencimento.toDate() : DateTime.now(),
      status: StatusMatricula.fromFirestoreValue(data['status'] as String?),
      valorContratado: (data['valorContratado'] as num?)?.toDouble() ?? 0,
      formaPagamento: data['formaPagamento'] as String?,
      observacao: data['observacao'] as String?,
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
      atualizadoEm: atualizadoEm is Timestamp ? atualizadoEm.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'alunoId': alunoId,
      'planoId': planoId,
      'dataInicio': Timestamp.fromDate(dataInicio),
      'dataVencimento': Timestamp.fromDate(dataVencimento),
      'status': status.name,
      'valorContratado': valorContratado,
      'formaPagamento': formaPagamento,
      'observacao': observacao,
      'criadoEm': criadoEm != null
          ? Timestamp.fromDate(criadoEm!)
          : FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
  }

  Matricula copyWith({
    DateTime? dataInicio,
    DateTime? dataVencimento,
    StatusMatricula? status,
    double? valorContratado,
    String? formaPagamento,
    String? observacao,
  }) {
    return Matricula(
      id: id,
      alunoId: alunoId,
      planoId: planoId,
      dataInicio: dataInicio ?? this.dataInicio,
      dataVencimento: dataVencimento ?? this.dataVencimento,
      status: status ?? this.status,
      valorContratado: valorContratado ?? this.valorContratado,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      observacao: observacao ?? this.observacao,
      criadoEm: criadoEm,
      atualizadoEm: atualizadoEm,
    );
  }
}
