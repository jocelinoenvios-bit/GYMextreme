import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/imc.dart';

/// Uma entrada da ficha de avaliacao fisica (uma das 3 colunas
/// "AVALIACAO FISICA __/__/__" da ficha em papel). O aluno acumula uma
/// entrada por avaliacao ao longo do tempo, pra acompanhar evolucao.
class AvaliacaoFisica {
  const AvaliacaoFisica({
    this.id,
    required this.data,
    this.pesoKg,
    this.alturaM,
    this.circunferenciasCm = const {},
    this.observacoes,
    this.fotoUrls = const [],
  });

  final String? id;
  final DateTime data;
  final double? pesoKg;
  final double? alturaM;

  /// Chave = [CircunferenciaField.key], valor em centimetros.
  final Map<String, double?> circunferenciasCm;

  final String? observacoes;

  /// Fotos de evolucao desta avaliacao. Campo reservado pro banco ja
  /// suportar isso — captura/exibicao ainda nao tem tela (fica pra um
  /// modulo futuro de "evolucao").
  final List<String> fotoUrls;

  double? get imc => calcularImc(pesoKg: pesoKg, alturaM: alturaM);

  factory AvaliacaoFisica.fromFirestore(String id, Map<String, dynamic> data) {
    final dataAvaliacao = data['data'];
    final circunferencias = Map<String, dynamic>.from(
      data['circunferenciasCm'] ?? const {},
    );
    return AvaliacaoFisica(
      id: id,
      data: dataAvaliacao is Timestamp ? dataAvaliacao.toDate() : DateTime.now(),
      pesoKg: (data['pesoKg'] as num?)?.toDouble(),
      alturaM: (data['alturaM'] as num?)?.toDouble(),
      circunferenciasCm: circunferencias.map(
        (key, value) => MapEntry(key, (value as num?)?.toDouble()),
      ),
      observacoes: data['observacoes'] as String?,
      fotoUrls: List<String>.from(data['fotoUrls'] ?? const []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'data': Timestamp.fromDate(data),
      'pesoKg': pesoKg,
      'alturaM': alturaM,
      'circunferenciasCm': circunferenciasCm,
      'observacoes': observacoes,
      'fotoUrls': fotoUrls,
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }
}
