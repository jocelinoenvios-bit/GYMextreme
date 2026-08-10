import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/cargo.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/services/permission_service.dart';

void main() {
  group('Permission', () {
    test('setFromFirestoreValues ignora valores desconhecidos/legados', () {
      final permissoes = Permission.setFromFirestoreValues([
        'gerenciarAlunos',
        'valor-que-nao-existe-mais',
        'bibliotecaExercicios',
      ]);

      expect(permissoes, {
        Permission.gerenciarAlunos,
        Permission.bibliotecaExercicios,
      });
    });

    test('setFromFirestoreValues com lista nula retorna vazio', () {
      expect(Permission.setFromFirestoreValues(null), isEmpty);
    });

    // FASE 1A: Permission.planos (flag unico, nunca usado em nenhuma tela)
    // foi substituido pelos 4 granulares abaixo, no mesmo padrao ja usado
    // pra Alunos (gerenciarAlunos + cadastrar/editar/excluirAlunos).
    test('cobre as 4 permissoes granulares de planos', () {
      expect(Permission.values, contains(Permission.acessarPlanos));
      expect(Permission.values, contains(Permission.cadastrarPlanos));
      expect(Permission.values, contains(Permission.alterarPlanos));
      expect(Permission.values, contains(Permission.excluirPlanos));
    });
  });

  group('CargosPadrao.recepcionista', () {
    test('tem acesso e cadastro de planos, mas nao alterar/excluir', () {
      final permissoes = CargosPadrao.recepcionista.permissoesPadrao;

      expect(permissoes, contains(Permission.acessarPlanos));
      expect(permissoes, contains(Permission.cadastrarPlanos));
      expect(permissoes, isNot(contains(Permission.alterarPlanos)));
      expect(permissoes, isNot(contains(Permission.excluirPlanos)));
    });

    test('continua com a permissao de matriculas', () {
      expect(CargosPadrao.recepcionista.permissoesPadrao, contains(Permission.matriculas));
    });
  });

  group('AppUser.fromFirestore', () {
    test('preenche cargoId e permissoes quando presentes', () {
      final user = AppUser.fromFirestore('uid123', {
        'nome': 'Recepção Teste',
        'email': 'recepcao@gymextreme.com.br',
        'role': 'funcionario',
        'cargoId': 'sistema-recepcionista',
        'permissoes': ['gerenciarAlunos', 'abrirCaixa', 'fecharCaixa'],
      });

      expect(user.role, UserRole.funcionario);
      expect(user.cargoId, 'sistema-recepcionista');
      expect(user.permissoes, {
        Permission.gerenciarAlunos,
        Permission.abrirCaixa,
        Permission.fecharCaixa,
      });
    });

    test('conta legada sem cargoId/permissoes nao quebra', () {
      final user = AppUser.fromFirestore('uid456', {
        'nome': 'Personal Legado',
        'email': 'personal.teste@gymextreme.com.br',
        'role': 'personal',
      });

      expect(user.cargoId, isNull);
      expect(user.permissoes, isEmpty);
    });
  });

  group('PermissionService.effectivePermissions', () {
    test('adm sempre tem acesso total, mesmo sem permissoes gravadas', () {
      final adm = AppUser(
        uid: 'adm1',
        nome: 'Dono',
        email: 'adm@gymextreme.com.br',
        role: UserRole.adm,
      );

      expect(
        PermissionService.effectivePermissions(adm),
        Permission.values.toSet(),
      );
      expect(PermissionService.has(adm, Permission.configuracoes), isTrue);
    });

    test('funcionario novo usa exatamente a lista de permissoes gravada', () {
      final recepcionista = AppUser(
        uid: 'func1',
        nome: 'Recepção',
        email: 'recepcao@gymextreme.com.br',
        role: UserRole.funcionario,
        cargoId: 'sistema-recepcionista',
        permissoes: const {Permission.gerenciarAlunos, Permission.abrirCaixa},
      );

      expect(PermissionService.has(recepcionista, Permission.gerenciarAlunos), isTrue);
      expect(PermissionService.has(recepcionista, Permission.abrirCaixa), isTrue);
      expect(PermissionService.has(recepcionista, Permission.configuracoes), isFalse);
      expect(PermissionService.has(recepcionista, Permission.gerenciarFuncionarios), isFalse);
    });

    test('personal legado sem permissoes cai no fallback de compatibilidade', () {
      final personalLegado = AppUser(
        uid: 'personal1',
        nome: 'Personal Legado',
        email: 'personal.teste@gymextreme.com.br',
        role: UserRole.personal,
      );

      expect(PermissionService.has(personalLegado, Permission.gerenciarAlunos), isTrue);
      expect(PermissionService.has(personalLegado, Permission.bibliotecaExercicios), isTrue);
      expect(PermissionService.has(personalLegado, Permission.avaliacoesFisicas), isTrue);
      expect(PermissionService.has(personalLegado, Permission.financeiro), isFalse);
    });

    test('aluno nao tem nenhuma permissao de staff, em todo o catalogo', () {
      final aluno = AppUser(
        uid: 'aluno1',
        nome: 'Aluno Teste',
        email: 'aluno.teste@gymextreme.com.br',
        role: UserRole.aluno,
      );

      expect(PermissionService.effectivePermissions(aluno), isEmpty);
      for (final permissao in Permission.values) {
        expect(
          PermissionService.has(aluno, permissao),
          isFalse,
          reason: 'Aluno nao deveria ter a permissao $permissao',
        );
      }
    });

    test(
      'aluno com campo "permissoes" corrompido/preenchido por engano '
      'continua sem nenhum acesso (blindagem por role, nao so pelo campo)',
      () {
        final alunoComPermissoesIndevidas = AppUser(
          uid: 'aluno2',
          nome: 'Aluno Teste',
          email: 'aluno2.teste@gymextreme.com.br',
          role: UserRole.aluno,
          // Simula um documento corrompido — nunca deveria acontecer pelo
          // fluxo normal do app, mas a blindagem tem que segurar mesmo
          // assim, ja que os dados no Firestore nao sao imutaveis.
          permissoes: Permission.values.toSet(),
        );

        expect(
          PermissionService.effectivePermissions(alunoComPermissoesIndevidas),
          isEmpty,
        );
        expect(
          PermissionService.has(alunoComPermissoesIndevidas, Permission.gerenciarFuncionarios),
          isFalse,
        );
        expect(
          PermissionService.has(alunoComPermissoesIndevidas, Permission.financeiro),
          isFalse,
        );
        expect(
          PermissionService.has(alunoComPermissoesIndevidas, Permission.configuracoes),
          isFalse,
        );
      },
    );
  });

  group('Permission — Contas a Receber (Fase 1B)', () {
    test('cobre as 5 permissoes granulares', () {
      expect(Permission.values, contains(Permission.acessarContasReceber));
      expect(Permission.values, contains(Permission.cadastrarContasReceber));
      expect(Permission.values, contains(Permission.alterarContasReceber));
      expect(Permission.values, contains(Permission.excluirContasReceber));
      expect(Permission.values, contains(Permission.receberContasReceber));
    });

    test('ADM tem as 5 automaticamente, mesmo sem nada gravado', () {
      const adm = AppUser(
        uid: 'adm1',
        nome: 'Dono',
        email: 'adm@gymextreme.com.br',
        role: UserRole.adm,
      );
      expect(PermissionService.has(adm, Permission.acessarContasReceber), isTrue);
      expect(PermissionService.has(adm, Permission.cadastrarContasReceber), isTrue);
      expect(PermissionService.has(adm, Permission.alterarContasReceber), isTrue);
      expect(PermissionService.has(adm, Permission.excluirContasReceber), isTrue);
      expect(PermissionService.has(adm, Permission.receberContasReceber), isTrue);
    });

    test(
      'funcionario com so acessarContasReceber nao consegue cadastrar, '
      'alterar, excluir nem receber',
      () {
        const funcionario = AppUser(
          uid: 'func1',
          nome: 'Recepção',
          email: 'recepcao@gymextreme.com.br',
          role: UserRole.funcionario,
          permissoes: {Permission.acessarContasReceber},
        );

        expect(PermissionService.has(funcionario, Permission.acessarContasReceber), isTrue);
        expect(PermissionService.has(funcionario, Permission.cadastrarContasReceber), isFalse);
        expect(PermissionService.has(funcionario, Permission.alterarContasReceber), isFalse);
        expect(PermissionService.has(funcionario, Permission.excluirContasReceber), isFalse);
        expect(PermissionService.has(funcionario, Permission.receberContasReceber), isFalse);
      },
    );

    test('aluno nunca tem nenhuma das 5, mesmo com o campo corrompido', () {
      const aluno = AppUser(
        uid: 'aluno1',
        nome: 'Aluno Teste',
        email: 'aluno@gymextreme.com.br',
        role: UserRole.aluno,
        permissoes: {
          Permission.acessarContasReceber,
          Permission.cadastrarContasReceber,
          Permission.receberContasReceber,
        },
      );

      expect(PermissionService.has(aluno, Permission.acessarContasReceber), isFalse);
      expect(PermissionService.has(aluno, Permission.receberContasReceber), isFalse);
    });
  });

  group('CargosPadrao.recepcionista — Contas a Receber (Fase 1B)', () {
    test('tem acesso, cadastro e recebimento, mas nao alterar/excluir', () {
      final permissoes = CargosPadrao.recepcionista.permissoesPadrao;

      expect(permissoes, contains(Permission.acessarContasReceber));
      expect(permissoes, contains(Permission.cadastrarContasReceber));
      expect(permissoes, contains(Permission.receberContasReceber));
      expect(permissoes, isNot(contains(Permission.alterarContasReceber)));
      expect(permissoes, isNot(contains(Permission.excluirContasReceber)));
    });
  });

  group('Permission — Controle de Caixa (Fase 1C)', () {
    test('cobre as 6 permissoes granulares', () {
      expect(Permission.values, contains(Permission.acessarControleCaixa));
      expect(Permission.values, contains(Permission.abrirCaixa));
      expect(Permission.values, contains(Permission.fecharCaixa));
      expect(Permission.values, contains(Permission.realizarRetiradas));
      expect(Permission.values, contains(Permission.realizarSuprimentos));
      expect(Permission.values, contains(Permission.consultarRelatorioCaixa));
    });

    test('ADM tem as 6 automaticamente, mesmo sem nada gravado', () {
      const adm = AppUser(
        uid: 'adm1',
        nome: 'Dono',
        email: 'adm@gymextreme.com.br',
        role: UserRole.adm,
      );
      expect(PermissionService.has(adm, Permission.acessarControleCaixa), isTrue);
      expect(PermissionService.has(adm, Permission.abrirCaixa), isTrue);
      expect(PermissionService.has(adm, Permission.fecharCaixa), isTrue);
      expect(PermissionService.has(adm, Permission.realizarRetiradas), isTrue);
      expect(PermissionService.has(adm, Permission.realizarSuprimentos), isTrue);
      expect(PermissionService.has(adm, Permission.consultarRelatorioCaixa), isTrue);
    });

    test(
      'funcionario com so acessarControleCaixa nao consegue abrir, fechar, '
      'retirar, suprir nem consultar relatorio',
      () {
        const funcionario = AppUser(
          uid: 'func1',
          nome: 'Recepção',
          email: 'recepcao@gymextreme.com.br',
          role: UserRole.funcionario,
          permissoes: {Permission.acessarControleCaixa},
        );

        expect(PermissionService.has(funcionario, Permission.acessarControleCaixa), isTrue);
        expect(PermissionService.has(funcionario, Permission.abrirCaixa), isFalse);
        expect(PermissionService.has(funcionario, Permission.fecharCaixa), isFalse);
        expect(PermissionService.has(funcionario, Permission.realizarRetiradas), isFalse);
        expect(PermissionService.has(funcionario, Permission.realizarSuprimentos), isFalse);
        expect(PermissionService.has(funcionario, Permission.consultarRelatorioCaixa), isFalse);
      },
    );

    test('aluno nunca tem nenhuma das 6, mesmo com o campo corrompido', () {
      const aluno = AppUser(
        uid: 'aluno1',
        nome: 'Aluno Teste',
        email: 'aluno@gymextreme.com.br',
        role: UserRole.aluno,
        permissoes: {
          Permission.acessarControleCaixa,
          Permission.abrirCaixa,
          Permission.fecharCaixa,
        },
      );

      expect(PermissionService.has(aluno, Permission.acessarControleCaixa), isFalse);
      expect(PermissionService.has(aluno, Permission.abrirCaixa), isFalse);
      expect(PermissionService.has(aluno, Permission.fecharCaixa), isFalse);
    });
  });

  group('CargosPadrao.recepcionista — Controle de Caixa (Fase 1C)', () {
    test('tem as 6 permissoes de caixa', () {
      final permissoes = CargosPadrao.recepcionista.permissoesPadrao;

      expect(permissoes, contains(Permission.acessarControleCaixa));
      expect(permissoes, contains(Permission.abrirCaixa));
      expect(permissoes, contains(Permission.fecharCaixa));
      expect(permissoes, contains(Permission.realizarRetiradas));
      expect(permissoes, contains(Permission.realizarSuprimentos));
      expect(permissoes, contains(Permission.consultarRelatorioCaixa));
    });
  });

  group('Permission — Contas a Pagar (Fase 1D)', () {
    test('cobre as 5 permissoes granulares', () {
      expect(Permission.values, contains(Permission.acessarContasPagar));
      expect(Permission.values, contains(Permission.cadastrarContasPagar));
      expect(Permission.values, contains(Permission.alterarContasPagar));
      expect(Permission.values, contains(Permission.excluirContasPagar));
      expect(Permission.values, contains(Permission.pagarContasPagar));
    });

    test('ADM tem as 5 automaticamente, mesmo sem nada gravado', () {
      const adm = AppUser(
        uid: 'adm1',
        nome: 'Dono',
        email: 'adm@gymextreme.com.br',
        role: UserRole.adm,
      );
      expect(PermissionService.has(adm, Permission.acessarContasPagar), isTrue);
      expect(PermissionService.has(adm, Permission.cadastrarContasPagar), isTrue);
      expect(PermissionService.has(adm, Permission.alterarContasPagar), isTrue);
      expect(PermissionService.has(adm, Permission.excluirContasPagar), isTrue);
      expect(PermissionService.has(adm, Permission.pagarContasPagar), isTrue);
    });

    test(
      'funcionario com so acessarContasPagar nao consegue cadastrar, '
      'alterar, excluir nem pagar',
      () {
        const funcionario = AppUser(
          uid: 'func1',
          nome: 'Financeiro',
          email: 'financeiro@gymextreme.com.br',
          role: UserRole.funcionario,
          permissoes: {Permission.acessarContasPagar},
        );

        expect(PermissionService.has(funcionario, Permission.acessarContasPagar), isTrue);
        expect(PermissionService.has(funcionario, Permission.cadastrarContasPagar), isFalse);
        expect(PermissionService.has(funcionario, Permission.alterarContasPagar), isFalse);
        expect(PermissionService.has(funcionario, Permission.excluirContasPagar), isFalse);
        expect(PermissionService.has(funcionario, Permission.pagarContasPagar), isFalse);
      },
    );

    test('aluno nunca tem nenhuma das 5, mesmo com o campo corrompido', () {
      const aluno = AppUser(
        uid: 'aluno1',
        nome: 'Aluno Teste',
        email: 'aluno@gymextreme.com.br',
        role: UserRole.aluno,
        permissoes: {
          Permission.acessarContasPagar,
          Permission.cadastrarContasPagar,
          Permission.pagarContasPagar,
        },
      );

      expect(PermissionService.has(aluno, Permission.acessarContasPagar), isFalse);
      expect(PermissionService.has(aluno, Permission.pagarContasPagar), isFalse);
    });

    test('cargo padrao de recepcionista nao ganha contas a pagar por padrao', () {
      final permissoes = CargosPadrao.recepcionista.permissoesPadrao;

      expect(permissoes, isNot(contains(Permission.acessarContasPagar)));
      expect(permissoes, isNot(contains(Permission.pagarContasPagar)));
    });
  });
}
