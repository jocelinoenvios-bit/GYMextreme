import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cargo.dart';

/// Catalogo de cargos: os 3 embutidos (`CargosPadrao`, sempre disponiveis,
/// sem precisar de nenhum documento no Firestore) mais os customizados que
/// a propria academia crie no futuro (colecao `cargos`).
class CargoService {
  CargoService({FirebaseFirestore? firestore})
    : _cargos = (firestore ?? FirebaseFirestore.instance).collection('cargos');

  final CollectionReference<Map<String, dynamic>> _cargos;

  /// Lista completa de cargos disponiveis (embutidos + customizados),
  /// ordenada com os embutidos primeiro.
  Stream<List<Cargo>> watchCargos() {
    return _cargos.orderBy('nome').snapshots().map((snapshot) {
      final customizados = snapshot.docs
          .map((doc) => Cargo.fromFirestore(doc.id, doc.data()))
          .toList();
      return [...CargosPadrao.todos, ...customizados];
    });
  }

  Future<void> criarCargoCustomizado(Cargo cargo) {
    return _cargos.add(cargo.toFirestore());
  }
}
