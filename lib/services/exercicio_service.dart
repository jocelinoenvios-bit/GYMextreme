import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exercicio.dart';

/// Leitura da biblioteca de exercicios (colecao `exercicios`). Somente
/// leitura: o cadastro e feito pelo script `importar-exercicios.js`,
/// fora do app.
class ExercicioService {
  ExercicioService({FirebaseFirestore? firestore})
    : _exercicios = (firestore ?? FirebaseFirestore.instance).collection(
        'exercicios',
      );

  final CollectionReference<Map<String, dynamic>> _exercicios;

  /// Acompanha toda a biblioteca, ordenada por nome. A lista costuma
  /// caber tranquilamente em memoria (referencia, nao um feed), entao a
  /// tela filtra por busca/grupo muscular localmente, sem refazer a
  /// consulta a cada letra digitada.
  Stream<List<Exercicio>> watchExercicios() {
    return _exercicios.orderBy('nome').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Exercicio.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }
}
