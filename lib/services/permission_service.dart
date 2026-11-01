import '../models/app_user.dart';
import '../models/permission.dart';
import '../models/user_role.dart';

/// Ponto unico de autorizacao do app: toda tela consulta esta classe em vez
/// de espalhar checagens de `role`/`permissoes` pelo codigo.
///
/// Estatica e sem estado (so opera sobre um `AppUser` ja carregado) — nao
/// precisa de instancia nem injecao via construtor.
class PermissionService {
  PermissionService._();

  /// Fallback de compatibilidade para contas `personal` gravadas antes
  /// deste sistema existir (sem `permissoes` no Firestore): mantem
  /// exatamente o acesso que "personal" ja tinha hoje (gerenciar alunos +
  /// biblioteca de exercicios + avaliacoes fisicas + criar/editar
  /// treinos), sem exigir nenhuma migracao manual no Firestore.
  ///
  /// `criarTreinos`/`editarTreinos` foram adicionados aqui depois de uma
  /// auditoria apontar que faltavam — sem eles, um personal legado
  /// (conta antiga, sem `permissoes` gravado) perdia silenciosamente a
  /// capacidade de prescrever/editar treino, a função mais básica do
  /// cargo, mesmo o comentário original dizendo que o fallback preservava
  /// "o acesso que personal já tinha".
  static const Set<Permission> _personalLegadoFallback = {
    Permission.gerenciarAlunos,
    Permission.bibliotecaExercicios,
    Permission.avaliacoesFisicas,
    Permission.criarTreinos,
    Permission.editarTreinos,
  };

  /// Permissoes efetivas de [user], já resolvendo a regra de
  /// compatibilidade:
  /// - `adm` sempre tem acesso total.
  /// - Se o documento ja tiver `permissoes` (contas novas, criadas pela
  ///   tela de funcionarios), usa exatamente essa lista.
  /// - `personal` legado sem `permissoes` cai no fallback fixo acima.
  /// - Qualquer outro caso (aluno, ou funcionario sem permissoes por algum
  ///   motivo) nao tem nenhuma permissao de staff.
  static Set<Permission> effectivePermissions(AppUser user) {
    if (user.role == UserRole.adm) return Permission.values.toSet();
    // Blindagem: aluno nunca tem permissao de staff, mesmo se o campo
    // `permissoes` do documento estiver preenchido por engano/corrupcao de
    // dados — a checagem de role vem antes de olhar pra esse campo.
    if (user.role == UserRole.aluno) return const {};
    if (user.permissoes.isNotEmpty) return user.permissoes;
    if (user.role == UserRole.personal) return _personalLegadoFallback;
    return const {};
  }

  static bool has(AppUser user, Permission permission) =>
      effectivePermissions(user).contains(permission);
}
