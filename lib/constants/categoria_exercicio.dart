/// Tradução dos 7 valores de `category` que a Biblioteca Oficial de
/// Exercícios (ExerciseDB) usa.
const Map<String, String> categoriaExercicioLabels = {
  'balance': 'Equilíbrio',
  'cardio': 'Cardio',
  'mobility': 'Mobilidade',
  'plyometrics': 'Pliometria',
  'rehabilitation': 'Reabilitação',
  'strength': 'Força',
  'stretching': 'Alongamento',
};

String labelCategoriaExercicio(String valor) {
  return categoriaExercicioLabels[valor.toLowerCase()] ?? valor;
}
