import 'package:cloud_firestore/cloud_firestore.dart';

/// Registro do aceite do Termo de Responsabilidade (regulamento) por um
/// aluno — substitui a assinatura no papel por um aceite digital com
/// nome, data/hora e, se menor de idade, o responsavel.
class TermoAceite {
  const TermoAceite({
    required this.aceito,
    this.aceitoEm,
    this.nomeAssinatura,
    this.responsavel,
    this.versaoRegulamento,
    this.registradoPorUid,
    this.registradoPorNome,
  });

  final bool aceito;
  final DateTime? aceitoEm;
  final String? nomeAssinatura;

  /// Preenchido apenas quando o aluno assinante e menor de idade.
  final String? responsavel;

  final String? versaoRegulamento;

  /// Auditoria: qual funcionario da recepcao registrou este aceite (
  /// diferente de [nomeAssinatura], que e quem assinou — aluno ou
  /// responsavel).
  final String? registradoPorUid;
  final String? registradoPorNome;

  static const naoAceito = TermoAceite(aceito: false);

  factory TermoAceite.fromFirestore(Map<String, dynamic> data) {
    final aceitoEm = data['aceitoEm'];
    return TermoAceite(
      aceito: data['aceito'] as bool? ?? false,
      aceitoEm: aceitoEm is Timestamp ? aceitoEm.toDate() : null,
      nomeAssinatura: data['nomeAssinatura'] as String?,
      responsavel: data['responsavel'] as String?,
      versaoRegulamento: data['versaoRegulamento'] as String?,
      registradoPorUid: data['registradoPorUid'] as String?,
      registradoPorNome: data['registradoPorNome'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'aceito': aceito,
      'aceitoEm': FieldValue.serverTimestamp(),
      'nomeAssinatura': nomeAssinatura,
      'responsavel': responsavel,
      'versaoRegulamento': versaoRegulamento,
      'registradoPorUid': registradoPorUid,
      'registradoPorNome': registradoPorNome,
    };
  }
}
