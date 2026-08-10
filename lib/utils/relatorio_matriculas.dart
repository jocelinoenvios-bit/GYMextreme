import '../models/matricula.dart';

/// Resumo de um conjunto de matrículas — sempre calculado sobre uma lista
/// já carregada, nunca lê o Firestore.
class ResumoMatriculas {
  const ResumoMatriculas({
    required this.total,
    required this.ativas,
    required this.encerradas,
    required this.vencendoEmBreve,
  });

  final int total;
  final int ativas;

  /// Soma de vencida + cancelada + suspensa — "encerrada" no sentido
  /// amplo de "não está mais valendo hoje".
  final int encerradas;

  /// Matrículas ativas cujo `dataVencimento` cai nos próximos
  /// [diasAlertaVencimento] dias (usado pra alertar sobre renovação).
  final int vencendoEmBreve;
}

const diasAlertaVencimentoMatricula = 7;

ResumoMatriculas calcularResumoMatriculas(
  List<Matricula> matriculas, {
  DateTime? hoje,
  int diasAlerta = diasAlertaVencimentoMatricula,
}) {
  final referencia = _semHorario(hoje ?? DateTime.now());
  final limiteAlerta = referencia.add(Duration(days: diasAlerta));

  var ativas = 0;
  var encerradas = 0;
  var vencendoEmBreve = 0;

  for (final matricula in matriculas) {
    if (matricula.status == StatusMatricula.ativa) {
      ativas++;
      final vencimento = _semHorario(matricula.dataVencimento);
      if (!vencimento.isBefore(referencia) && !vencimento.isAfter(limiteAlerta)) {
        vencendoEmBreve++;
      }
    } else {
      encerradas++;
    }
  }

  return ResumoMatriculas(
    total: matriculas.length,
    ativas: ativas,
    encerradas: encerradas,
    vencendoEmBreve: vencendoEmBreve,
  );
}

/// Matrículas cujo `criadoEm` cai dentro de `[de, ate]` — "novas
/// matrículas por período". Matrículas sem `criadoEm` nunca entram no
/// resultado quando algum limite é informado.
List<Matricula> filtrarMatriculasPorPeriodoDeCriacao(
  List<Matricula> matriculas, {
  DateTime? de,
  DateTime? ate,
}) {
  return matriculas.where((m) {
    if (m.criadoEm == null) return de == null && ate == null;
    return _dentroDoPeriodo(m.criadoEm!, de: de, ate: ate);
  }).toList();
}

bool _dentroDoPeriodo(DateTime data, {DateTime? de, DateTime? ate}) {
  final dia = _semHorario(data);
  if (de != null) {
    final inicio = _semHorario(de);
    if (dia.isBefore(inicio)) return false;
  }
  if (ate != null) {
    final fim = _semHorario(ate);
    if (dia.isAfter(fim)) return false;
  }
  return true;
}

DateTime _semHorario(DateTime data) => DateTime(data.year, data.month, data.day);
