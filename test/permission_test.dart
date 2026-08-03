import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
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
}
