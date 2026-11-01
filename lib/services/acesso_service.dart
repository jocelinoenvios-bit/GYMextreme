import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/evento_acesso.dart';

/// Leitura (SOMENTE leitura) do histórico de acesso físico do aluno —
/// coleção `eventosAcesso`, gravada exclusivamente pela Cloud Function
/// do pipeline do Control iDFace (`functions/lib/access/
/// access-event-service.js`, via Admin SDK). Nenhum método de escrita
/// existe aqui de propósito: `firestore.rules` já bloqueia qualquer
/// escrita do cliente (`allow write: if false`) — duplicar esse
/// controle no app só criaria a falsa impressão de que o app poderia
/// escrever se quisesse.
///
/// Não confundir com `AlunoService.watchHistoricoTreinos` — aquele é
/// presença de TREINO (`alunos/{uid}/historicoTreinos`), este é acesso
/// FÍSICO à academia (`eventosAcesso`, coleção raiz, nunca subcoleção
/// do aluno). São conceitos e coleções deliberadamente separados, só
/// combinados visualmente na aba "Frequência" (ver `FrequenciaTab`).
class AcessoService {
  AcessoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _eventosAcesso =>
      _firestore.collection('eventosAcesso');

  /// Histórico de tentativas de acesso físico (autorizado ou negado) de
  /// UM aluno, mais recente primeiro. `limite` evita carregar um
  /// histórico sem fim numa tela de detalhe (padrão 50).
  Stream<List<EventoAcesso>> watchEventosAcesso(String alunoUid, {int limite = 50}) {
    return _eventosAcesso
        .where('alunoUid', isEqualTo: alunoUid)
        .orderBy('criadoEm', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => EventoAcesso.fromFirestore(doc.id, doc.data())).toList(),
        );
  }
}
