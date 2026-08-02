/// As 10 categorias de "grupoMuscular" (bodyPart) que o importador
/// (`importar-exercicios.js`) grava em cada exercicio, na mesma
/// taxonomia da API de origem. Usado pra montar os filtros da
/// biblioteca sem depender de digitar o nome certo em ingles.
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
