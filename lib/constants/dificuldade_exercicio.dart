/// Tradução dos 3 valores de `difficulty` que a Biblioteca Oficial de
/// Exercícios (ExerciseDB) usa.
const Map<String, String> dificuldadeLabels = {
  'beginner': 'Iniciante',
  'intermediate': 'Intermediário',
  'advanced': 'Avançado',
};

String labelDificuldade(String valor) {
  return dificuldadeLabels[valor.toLowerCase()] ?? valor;
}
