import 'package:cloud_firestore/cloud_firestore.dart';

/// Dados de cadastro do aluno na academia (colecao `alunos`, documento com
/// o mesmo id do usuario/uid). Complementa o perfil basico de
/// `usuarios/{uid}` (nome, e-mail, role) com os campos especificos da
/// ficha em papel: idade, data de inicio e dia de vencimento.
class Aluno {
  const Aluno({
    required this.uid,
    this.idade,
    this.dataInicio,
    this.diaVencimento,
  });

  final String uid;
  final int? idade;
  final DateTime? dataInicio;

  /// Dia do mes (1-31) em que a mensalidade vence ("DIA PAGO" na ficha).
  final int? diaVencimento;

  factory Aluno.fromFirestore(String uid, Map<String, dynamic> data) {
    final inicio = data['dataInicio'];
    return Aluno(
      uid: uid,
      idade: (data['idade'] as num?)?.toInt(),
      dataInicio: inicio is Timestamp ? inicio.toDate() : null,
      diaVencimento: (data['diaVencimento'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'idade': idade,
      'dataInicio': dataInicio != null ? Timestamp.fromDate(dataInicio!) : null,
      'diaVencimento': diaVencimento,
    };
  }

  Aluno copyWith({int? idade, DateTime? dataInicio, int? diaVencimento}) {
    return Aluno(
      uid: uid,
      idade: idade ?? this.idade,
      dataInicio: dataInicio ?? this.dataInicio,
      diaVencimento: diaVencimento ?? this.diaVencimento,
    );
  }
}
