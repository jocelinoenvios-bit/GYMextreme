/// As 10 categorias de "bodyPart" que a Biblioteca Oficial de
/// Exercícios (ExerciseDB) usa em cada exercicio. Usado pra montar os
/// filtros da biblioteca sem depender de digitar o nome certo em
/// ingles.
const Map<String, String> gruposMuscularesLabels = {
  'back': 'Costas',
  'cardio': 'Cardio',
  'chest': 'Peito',
  'lower arms': 'Antebraços',
  'lower legs': 'Panturrilhas',
  'neck': 'Pescoço',
  'shoulders': 'Ombros',
  'upper arms': 'Braços',
  'upper legs': 'Pernas',
  'waist': 'Abdômen',
};

String labelGrupoMuscular(String valor) {
  return gruposMuscularesLabels[valor.toLowerCase()] ?? valor;
}
