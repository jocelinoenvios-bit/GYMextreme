import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/plano.dart';

/// Catálogo de planos de mensalidade da academia (coleção `planos`, nível
/// de academia — igual padrão de `CargoService` pros cargos customizados).
class PlanoService {
  PlanoService({FirebaseFirestore? firestore})
    : _planos = (firestore ?? FirebaseFirestore.instance).collection('planos');

  final CollectionReference<Map<String, dynamic>> _planos;

  /// Todos os planos (ativos e inativos), ordenados por nome — a tela
  /// administrativa decide o que mostrar; quem só pode escolher um plano
  /// pra uma matrícula nova (ex.: formulário de matrícula) filtra por
  /// `ativo` no próprio widget.
  Stream<List<Plano>> watchPlanos() {
    return _planos.orderBy('nome').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Plano.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<Plano?> buscarPlano(String id) async {
    final doc = await _planos.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return Plano.fromFirestore(doc.id, data);
  }

  /// Cria (se `plano.id` for nulo) ou atualiza um plano.
  Future<String> salvarPlano(Plano plano) async {
    final dados = plano.toFirestore();
    if (plano.id == null) {
      final ref = await _planos.add(dados);
      return ref.id;
    }
    await _planos.doc(plano.id).set(dados, SetOptions(merge: true));
    return plano.id!;
  }

  /// "Exclui" um plano sem apagar o documento — mesmo padrão de
  /// `Aluno.ativo`/`Treino.ativo`: preserva o histórico (matrículas já
  /// contratadas continuam referenciando o plano original) e só some da
  /// lista de planos disponíveis pra novas matrículas.
  Future<void> excluirPlano(String id) {
    return _planos.doc(id).set({
      'ativo': false,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
