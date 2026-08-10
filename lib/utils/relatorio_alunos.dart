import '../models/aluno.dart';
import '../models/app_user.dart';
import 'status_acesso.dart';

/// Resumo de um conjunto de alunos — sempre calculado sobre listas já
/// carregadas, nunca lê o Firestore.
class ResumoAlunos {
  const ResumoAlunos({
    required this.total,
    required this.ativos,
    required this.bloqueados,
    required this.semRegistro,
  });

  final int total;
  final int ativos;
  final int bloqueados;

  /// Alunos sem `proximoVencimento` configurado ainda (nunca bloqueados,
  /// mas também não contam como "em dia" de verdade) — ver
  /// `StatusMensalidade.semRegistro`.
  final int semRegistro;
}

/// Situação efetiva de mensalidade de UM aluno — cruza o `AppUser`
/// (identidade) com sua ficha `Aluno` (que carrega `proximoVencimento`),
/// já que as duas coisas vivem em documentos/coleções diferentes
/// (`usuarios` e `alunos`).
StatusMensalidade calcularStatusMensalidadeAluno(
  AppUser aluno,
  Map<String, Aluno> fichasPorUid, {
  DateTime? hoje,
}) {
  final ficha = fichasPorUid[aluno.uid];
  return calcularStatusAcesso(proximoVencimento: ficha?.proximoVencimento, hoje: hoje).status;
}

ResumoAlunos calcularResumoAlunos({
  required List<AppUser> alunos,
  required List<Aluno> fichasAlunos,
  DateTime? hoje,
}) {
  final fichasPorUid = {for (final ficha in fichasAlunos) ficha.uid: ficha};

  var ativos = 0;
  var bloqueados = 0;
  var semRegistro = 0;

  for (final aluno in alunos) {
    final status = calcularStatusMensalidadeAluno(aluno, fichasPorUid, hoje: hoje);
    switch (status) {
      case StatusMensalidade.bloqueado:
        bloqueados++;
      case StatusMensalidade.semRegistro:
        semRegistro++;
      case StatusMensalidade.emDia:
      case StatusMensalidade.tolerancia:
        ativos++;
    }
  }

  return ResumoAlunos(
    total: alunos.length,
    ativos: ativos,
    bloqueados: bloqueados,
    semRegistro: semRegistro,
  );
}

/// Alunos cujo `AppUser.criadoEm` cai dentro de `[de, ate]` — "novos
/// alunos por período de cadastro". Alunos sem `criadoEm` (cadastros
/// muito antigos, de antes desse campo existir) nunca entram no
/// resultado quando algum limite é informado.
List<AppUser> filtrarAlunosPorPeriodoDeCadastro(
  List<AppUser> alunos, {
  DateTime? de,
  DateTime? ate,
}) {
  return alunos.where((a) {
    if (a.criadoEm == null) return de == null && ate == null;
    return _dentroDoPeriodo(a.criadoEm!, de: de, ate: ate);
  }).toList();
}

bool _dentroDoPeriodo(DateTime data, {DateTime? de, DateTime? ate}) {
  final dia = DateTime(data.year, data.month, data.day);
  if (de != null) {
    final inicio = DateTime(de.year, de.month, de.day);
    if (dia.isBefore(inicio)) return false;
  }
  if (ate != null) {
    final fim = DateTime(ate.year, ate.month, ate.day);
    if (dia.isAfter(fim)) return false;
  }
  return true;
}
