import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/catraca.dart';
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

  CollectionReference<Map<String, dynamic>> get _dispositivos =>
      _firestore.collection('dispositivosAcesso');

  /// Leitores ativos e os códigos deles vinculados a [alunoUid]. Uma
  /// consulta por leitor (academia tem 1 ou 2) em vez de uma consulta em
  /// todos de uma vez, que exigiria um índice extra no Firestore.
  Future<CatracaDoAluno> carregarCatraca(String alunoUid) async {
    final snap = await _dispositivos.where('ativo', isEqualTo: true).get();
    final dispositivos = [
      for (final doc in snap.docs)
        DispositivoAcesso(
          id: doc.id,
          nome: (doc.data()['nome'] as String?)?.trim().isNotEmpty == true
              ? doc.data()['nome'] as String
              : 'Leitor',
        ),
    ]..sort((a, b) => a.nome.compareTo(b.nome));

    final vinculos = <VinculoCatraca>[];
    for (final dispositivo in dispositivos) {
      final credenciais = await _dispositivos
          .doc(dispositivo.id)
          .collection('credenciais')
          .where('alunoUid', isEqualTo: alunoUid)
          .get();
      for (final doc in credenciais.docs) {
        vinculos.add(VinculoCatraca(dispositivo: dispositivo, codigo: doc.id));
      }
    }
    return CatracaDoAluno(dispositivos: dispositivos, vinculos: vinculos);
  }

  /// Vincula o [codigo] do leitor ao aluno. Recusa se o código já for de
  /// outro aluno — trocar exige desvincular primeiro, pra ninguém
  /// "roubar" a entrada de outra pessoa sem querer.
  Future<void> vincularCodigo({
    required String dispositivoId,
    required String codigo,
    required String alunoUid,
    required AppUser staff,
  }) {
    final ref = _dispositivos.doc(dispositivoId).collection('credenciais').doc(codigo.trim());
    return _firestore.runTransaction((transaction) async {
      final atual = await transaction.get(ref);
      if (atual.exists) {
        if (atual.data()?['alunoUid'] == alunoUid) return;
        throw AcessoServiceException(
          'O código ${codigo.trim()} já está vinculado a outro aluno neste leitor.',
        );
      }
      transaction.set(ref, {
        'alunoUid': alunoUid,
        'vinculadoEm': FieldValue.serverTimestamp(),
        'vinculadoPorUid': staff.uid,
        'vinculadoPorNome': staff.nome,
      });
    });
  }

  Future<void> desvincularCodigo({required String dispositivoId, required String codigo}) {
    return _dispositivos.doc(dispositivoId).collection('credenciais').doc(codigo).delete();
  }
}

/// Erro com mensagem pronta pra mostrar na tela.
class AcessoServiceException implements Exception {
  AcessoServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
