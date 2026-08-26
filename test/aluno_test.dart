import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/endereco.dart';
import 'package:gymextreme_app/models/pagamento.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/utils/idade.dart';

void main() {
  group('calcularIdade', () {
    test('retorna null quando a data de nascimento nao e informada', () {
      expect(calcularIdade(null), isNull);
    });

    test('calcula a idade completa quando o aniversario ja passou este ano', () {
      final idade = calcularIdade(
        DateTime(2000, 3, 10),
        hoje: DateTime(2026, 8, 2),
      );
      expect(idade, 26);
    });

    test('nao conta o ano ainda quando o aniversario nao chegou', () {
      final idade = calcularIdade(
        DateTime(2000, 12, 25),
        hoje: DateTime(2026, 8, 2),
      );
      expect(idade, 25);
    });
  });

  group('Endereco', () {
    test('fromFirestore/toFirestore fazem round-trip', () {
      final endereco = Endereco.fromFirestore({
        'cep': '01310-100',
        'logradouro': 'Av. Paulista',
        'numero': '1000',
        'bairro': 'Bela Vista',
        'cidade': 'São Paulo',
        'uf': 'SP',
      });

      expect(endereco.estaPreenchido, isTrue);
      expect(endereco.toFirestore()['cidade'], 'São Paulo');
    });

    test('Endereco.vazio nao esta preenchido', () {
      expect(Endereco.vazio.estaPreenchido, isFalse);
    });
  });

  group('Aluno.idade', () {
    test('prefere a idade calculada pela data de nascimento, mesmo com idadeInformada diferente', () {
      final aluno = Aluno(
        uid: 'uid1',
        dataNascimento: DateTime(2000, 1, 1),
        idadeInformada: 999, // valor propositalmente errado, nunca deveria vencer
      );
      expect(aluno.idade, isNot(999));
      expect(aluno.idade, calcularIdade(DateTime(2000, 1, 1)));
    });

    test('usa idadeInformada como fallback quando falta data de nascimento', () {
      final aluno = Aluno(uid: 'uid1', idadeInformada: 42);
      expect(aluno.dataNascimento, isNull);
      expect(aluno.idade, 42);
    });

    test('proximoVencimento faz round-trip por fromFirestore/toFirestore', () {
      final vencimento = DateTime(2026, 9, 10);
      final aluno = Aluno(uid: 'uid1', proximoVencimento: vencimento);

      final dados = aluno.toFirestore();
      expect(dados['proximoVencimento'], Timestamp.fromDate(vencimento));

      final reconstruido = Aluno.fromFirestore('uid1', dados);
      expect(reconstruido.proximoVencimento, vencimento);
    });

    test('proximoVencimento nulo nao quebra o round-trip', () {
      final aluno = Aluno.fromFirestore('uid1', const {});
      expect(aluno.proximoVencimento, isNull);
    });
  });

  group('Pagamento', () {
    test('fromFirestore/toFirestore preservam vencimento anterior e novo', () {
      final anterior = DateTime(2026, 7, 10);
      final novo = DateTime(2026, 8, 10);

      final pagamento = Pagamento.fromFirestore('pg1', {
        'registradoEm': Timestamp.fromDate(DateTime(2026, 8, 12)),
        'vencimentoAnterior': Timestamp.fromDate(anterior),
        'novoVencimento': Timestamp.fromDate(novo),
        'registradoPorUid': 'staff1',
        'registradoPorNome': 'Recepção Ana',
      });

      expect(pagamento.vencimentoAnterior, anterior);
      expect(pagamento.novoVencimento, novo);
      expect(pagamento.registradoPorNome, 'Recepção Ana');

      final dados = pagamento.toFirestore();
      expect(dados['novoVencimento'], Timestamp.fromDate(novo));
    });

    test('primeiro pagamento nao tem vencimento anterior', () {
      final pagamento = Pagamento.fromFirestore('pg2', {
        'registradoEm': Timestamp.fromDate(DateTime(2026, 8, 12)),
        'novoVencimento': Timestamp.fromDate(DateTime(2026, 9, 12)),
      });
      expect(pagamento.vencimentoAnterior, isNull);
    });
  });

  group('Treino', () {
    test('fromFirestore/toFirestore preservam a lista de exercicios', () {
      final treino = Treino.fromFirestore('treino1', {
        'nome': 'Treino A',
        'letra': 'A',
        'grupoMuscular': 'Peito e tríceps',
        'ordem': 0,
        'ativo': true,
        'exercicios': [
          {
            'exercicioId': 'ex1',
            'series': 4,
            'repeticoes': '8-12',
            'cargaKg': 20.0,
            'descansoSegundos': 60,
            'ordem': 0,
          },
        ],
      });

      expect(treino.id, 'treino1');
      expect(treino.exercicios, hasLength(1));
      expect(treino.exercicios.first.exercicioId, 'ex1');
      expect(treino.exercicios.first.series, 4);

      final dados = treino.toFirestore();
      expect(dados['letra'], 'A');
      expect((dados['exercicios'] as List).length, 1);
    });

    test('treino novo (sem id) nao inclui criadoPor* no fromFirestore ausente', () {
      final treino = Treino.fromFirestore('t2', {'nome': 'Treino B', 'letra': 'B'});
      expect(treino.criadoPorUid, isNull);
      expect(treino.exercicios, isEmpty);
    });
  });
}
