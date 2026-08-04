import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/constants/grupos_musculares.dart';

void main() {
  test('labelGrupoMuscular traduz valores conhecidos e mantem desconhecidos', () {
    expect(labelGrupoMuscular('chest'), 'Peito');
    expect(labelGrupoMuscular('Upper Legs'), 'Pernas');
    expect(labelGrupoMuscular('categoria-nova-da-biblioteca'), 'categoria-nova-da-biblioteca');
  });
}
