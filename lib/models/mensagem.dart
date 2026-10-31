import 'package:cloud_firestore/cloud_firestore.dart';

/// Uma mensagem enviada por um membro da equipe (ADM/Personal com a
/// permissão `chat`) pra um aluno específico — aparece na tela "Mensagens"
/// da Área do Aluno. Só envio manual por enquanto; os avisos automáticos
/// (vencimento de mensalidade, reengajamento depois de 45 dias sem vir)
/// ficam pra uma etapa futura, com sua própria lógica de disparo.
class Mensagem {
  const Mensagem({
    this.id,
    required this.texto,
    required this.remetenteUid,
    required this.remetenteNome,
    this.criadoEm,
  });

  final String? id;
  final String texto;
  final String remetenteUid;
  final String remetenteNome;

  /// Nulo só entre o `add()` e o próximo snapshot — o servidor preenche
  /// via `FieldValue.serverTimestamp()` (nunca o relógio do aparelho).
  final DateTime? criadoEm;

  factory Mensagem.fromFirestore(String id, Map<String, dynamic> data) {
    final criadoEmValor = data['criadoEm'];
    return Mensagem(
      id: id,
      texto: data['texto'] as String? ?? '',
      remetenteUid: data['remetenteUid'] as String? ?? '',
      remetenteNome: data['remetenteNome'] as String? ?? '',
      criadoEm: criadoEmValor is Timestamp ? criadoEmValor.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'texto': texto,
      'remetenteUid': remetenteUid,
      'remetenteNome': remetenteNome,
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }
}
