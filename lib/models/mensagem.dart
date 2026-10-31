import 'package:cloud_firestore/cloud_firestore.dart';

/// Um aviso enviado por um membro da equipe (ADM/Personal com a permissão
/// `chat`) pra um aluno específico — aparece na tela "Mensagens" da Área
/// do Aluno. A comunicação é de mão única por decisão de produto: o aluno
/// lê, marca como lida e pode tirar da lista dele, mas não responde.
///
/// Só envio manual por enquanto; os avisos automáticos (vencimento de
/// mensalidade, reengajamento depois de 45 dias sem vir) ficam pra uma
/// etapa futura, com sua própria lógica de disparo.
class Mensagem {
  const Mensagem({
    this.id,
    required this.texto,
    required this.remetenteUid,
    required this.remetenteNome,
    this.alunoUid = '',
    this.alunoNome = '',
    this.criadoEm,
    this.lidaEm,
    this.arquivadaPeloAluno = false,
  });

  final String? id;
  final String texto;
  final String remetenteUid;
  final String remetenteNome;

  /// Destinatário repetido dentro do documento. Redundante com o caminho
  /// (`alunos/{alunoUid}/mensagens/...`) de propósito: a lista de
  /// enviadas do staff varre todas as subcoleções de uma vez
  /// (collection group) e ali só se enxerga o documento, não o caminho —
  /// sem estes campos, não dava pra dizer pra quem a mensagem foi.
  final String alunoUid;
  final String alunoNome;

  /// Nulo só entre o `add()` e o próximo snapshot — o servidor preenche
  /// via `FieldValue.serverTimestamp()` (nunca o relógio do aparelho).
  final DateTime? criadoEm;

  /// Quando o aluno abriu a tela de mensagens com esta na lista. Nulo
  /// enquanto não foi lida — é o que alimenta o selo de não lidas e o
  /// "visto"/"não visto" na tela de enviadas do staff.
  final DateTime? lidaEm;

  /// O aluno tirou da lista dele. Não apaga o documento: o registro
  /// continua nas enviadas do staff, porque numa academia interessa
  /// provar que o aviso foi dado. Quem apaga de verdade é o staff.
  final bool arquivadaPeloAluno;

  bool get lida => lidaEm != null;

  factory Mensagem.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? paraData(Object? valor) =>
        valor is Timestamp ? valor.toDate() : null;

    return Mensagem(
      id: id,
      texto: data['texto'] as String? ?? '',
      remetenteUid: data['remetenteUid'] as String? ?? '',
      remetenteNome: data['remetenteNome'] as String? ?? '',
      alunoUid: data['alunoUid'] as String? ?? '',
      alunoNome: data['alunoNome'] as String? ?? '',
      criadoEm: paraData(data['criadoEm']),
      lidaEm: paraData(data['lidaEm']),
      arquivadaPeloAluno: data['arquivadaPeloAluno'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'texto': texto,
      'remetenteUid': remetenteUid,
      'remetenteNome': remetenteNome,
      'alunoUid': alunoUid,
      'alunoNome': alunoNome,
      'criadoEm': FieldValue.serverTimestamp(),
      'lidaEm': null,
      'arquivadaPeloAluno': false,
    };
  }
}
