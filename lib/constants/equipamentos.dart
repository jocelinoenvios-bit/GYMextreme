/// Tradução dos 34 valores de `equipment` que a Biblioteca Oficial de
/// Exercícios (ExerciseDB) usa. Usado pra exibir "Halteres"/"Barra
/// olímpica" em vez do texto original em inglês.
const Map<String, String> equipamentosLabels = {
  'assisted': 'Assistido',
  'assisted (towel)': 'Assistido (toalha)',
  'band': 'Faixa elástica',
  'barbell': 'Barra reta',
  'body weight': 'Peso corporal',
  'body weight (with resistance band)': 'Peso corporal (com faixa elástica)',
  'bosu ball': 'Bosu',
  'cable': 'Cabo (polia)',
  'dumbbell': 'Halteres',
  'dumbbell (used as handles for deeper range)': 'Halteres (como apoio, maior amplitude)',
  'dumbbell, exercise ball': 'Halteres e bola suíça',
  'dumbbell, exercise ball, tennis ball': 'Halteres, bola suíça e bola de tênis',
  'elliptical machine': 'Elíptico',
  'ez barbell': 'Barra W',
  'ez barbell, exercise ball': 'Barra W e bola suíça',
  'hammer': 'Martelo',
  'kettlebell': 'Kettlebell',
  'leverage machine': 'Máquina articulada',
  'medicine ball': 'Medicine ball',
  'olympic barbell': 'Barra olímpica',
  'resistance band': 'Faixa elástica',
  'roller': 'Rolo',
  'rope': 'Corda',
  'skierg machine': 'Máquina de esqui (SkiErg)',
  'sled machine': 'Trenó (sled)',
  'smith machine': 'Smith',
  'stability ball': 'Bola suíça',
  'stationary bike': 'Bicicleta ergométrica',
  'stepmill machine': 'Escada ergométrica (StepMill)',
  'tire': 'Pneu',
  'trap bar': 'Barra hexagonal',
  'upper body ergometer': 'Ergômetro de membros superiores',
  'weighted': 'Com peso adicional',
  'wheel roller': 'Roda abdominal',
};

String labelEquipamento(String valor) {
  return equipamentosLabels[valor.toLowerCase()] ?? valor;
}
