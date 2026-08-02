import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/constants/grupos_musculares.dart';
import 'package:gymextreme_app/models/exercicio.dart';

void main() {
  test('labelGrupoMuscular traduz valores conhecidos e mantem desconhecidos', () {
    expect(labelGrupoMuscular('chest'), 'Peito');
    expect(labelGrupoMuscular('Upper Legs'), 'Pernas');
    expect(labelGrupoMuscular('categoria-nova-da-outra-api'), 'categoria-nova-da-outra-api');
  });

  test('Exercicio.fromFirestore preenche valores padrao quando faltam dados', () {
    final exercicio = Exercicio.fromFirestore('abc123', {
      'nome': 'Supino reto',
      'grupoMuscular': 'chest',
      'alvo': 'pectorals',
      'equipamento': 'barbell',
    });

    expect(exercicio.id, 'abc123');
    expect(exercicio.nome, 'Supino reto');
    expect(exercicio.nivel, isNull);
    expect(exercicio.instrucoes, isEmpty);
  });
}
