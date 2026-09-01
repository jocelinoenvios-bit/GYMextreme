import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalExerciseRepository', () {
    const repo = LocalExerciseRepository();

    test('carrega o catálogo completo da Biblioteca Oficial', () async {
      final todos = await repo.buscarTodos();
      expect(todos.length, greaterThan(1000));
    });

    test('busca um exercício real por id, com todos os campos mapeados', () async {
      final exercicio = await repo.buscarPorId('0001');

      expect(exercicio, isNotNull);
      expect(exercicio!.nome, '3/4 sit-up');
      expect(exercicio.nomeExibicao, 'Abdominal supra 3/4', reason: 'traduzido, ver traducoes_pt.json');
      expect(exercicio.bodyPart, 'waist');
      expect(exercicio.musculosPrincipais, ['abs']);
      expect(exercicio.musculosAuxiliares, isNotEmpty);
      expect(exercicio.passoAPasso, isNotEmpty);
      expect(exercicio.equipmentCategory, isNotEmpty);
      expect(exercicio.dificuldade, isNotEmpty);
    });

    test('nao perde nenhum subcampo de taxonomy — todos os 17 preservados', () async {
      final exercicio = await repo.buscarPorId('0001');
      const camposEsperados = {
        'movementFamily', 'movementPattern', 'mechanic', 'forceType',
        'planeOfMotion', 'laterality', 'bodyPosition', 'benchAngle',
        'equipmentCategory', 'loadType', 'primaryRegion', 'isCompound',
        'isUnilateral', 'isAssisted', 'isWeighted', 'signals', 'confidence',
      };
      expect(exercicio!.taxonomiaBruta.keys.toSet(), camposEsperados);
    });

    test('resolve o caminho do gif pela nomenclatura oficial (id, sem renomeação)', () async {
      final exercicio = await repo.buscarPorId('0001');
      expect(exercicio!.gif360Url, contains('0001'));
    });

    test('resolve relacionamentos com tipos e score', () async {
      final exercicio = await repo.buscarPorId('0013');

      expect(exercicio, isNotNull);
      expect(exercicio!.substituicoes, isNotEmpty);
      expect(exercicio.substituicoes.first.tipos, isNotEmpty);
      expect(exercicio.substituicoes.first.score, greaterThan(0));
    });

    test('retorna null pra id inexistente', () async {
      final exercicio = await repo.buscarPorId('id-que-nao-existe');
      expect(exercicio, isNull);
    });

    test('memoiza o índice — chamadas repetidas não reparseiam o arquivo', () async {
      final primeira = await repo.buscarTodos();
      final segunda = await repo.buscarTodos();
      expect(identical(primeira.first, segunda.first), isTrue);
    });
  });
}
