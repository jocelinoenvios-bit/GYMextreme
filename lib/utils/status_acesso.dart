import '../constants/mensalidade.dart';

/// Situação da mensalidade de um aluno em relação ao vencimento e à
/// tolerância — usado tanto pelo aplicativo (bloquear/liberar telas)
/// quanto pela autorização de acesso da catraca.
enum StatusMensalidade {
  /// Nenhum vencimento configurado ainda (aluno cadastrado antes da
  /// recepção começar a controlar mensalidade, ou nunca configurado).
  /// Nunca bloqueia — evita trancar o acesso de alunos existentes no dia
  /// em que este recurso for ligado.
  semRegistro,
  emDia,
  tolerancia,
  bloqueado,
}

/// Resultado do cálculo de [calcularStatusAcesso] — mesma lógica usada
/// pelo aplicativo e (portada para JS) pela Cloud Function de autorização
/// da catraca, pra nunca decidir a liberação em dois lugares diferentes.
class StatusAcesso {
  const StatusAcesso({
    required this.status,
    required this.podeAcessar,
    this.diasParaVencimento,
    this.diasAtraso,
    this.diasToleranciaRestantes,
  });

  final StatusMensalidade status;
  final bool podeAcessar;

  /// Dias corridos até o vencimento (0 = vence hoje). Só preenchido
  /// quando [status] é [StatusMensalidade.emDia].
  final int? diasParaVencimento;

  /// N-ésimo dia de atraso (1 = primeiro dia após o vencimento). Preenchido
  /// em [StatusMensalidade.tolerancia] e [StatusMensalidade.bloqueado].
  final int? diasAtraso;

  /// Dias de tolerância restantes, contando hoje (1 = último dia antes do
  /// bloqueio). Só preenchido em [StatusMensalidade.tolerancia].
  final int? diasToleranciaRestantes;
}

/// Calcula a situação de acesso do aluno a partir do próximo vencimento.
///
/// Regra confirmada com o cliente: durante os [toleranciaDias] dias após o
/// vencimento o aluno continua acessando normalmente (app + catraca);
/// depois disso, bloqueado até a recepção confirmar o pagamento.
StatusAcesso calcularStatusAcesso({
  required DateTime? proximoVencimento,
  DateTime? hoje,
  int toleranciaDias = toleranciaMensalidadeDias,
}) {
  if (proximoVencimento == null) {
    return const StatusAcesso(
      status: StatusMensalidade.semRegistro,
      podeAcessar: true,
    );
  }

  final referencia = _semHorario(hoje ?? DateTime.now());
  final vencimento = _semHorario(proximoVencimento);

  if (!referencia.isAfter(vencimento)) {
    return StatusAcesso(
      status: StatusMensalidade.emDia,
      podeAcessar: true,
      diasParaVencimento: vencimento.difference(referencia).inDays,
    );
  }

  final diasAtraso = referencia.difference(vencimento).inDays;
  final ultimoDiaTolerancia = vencimento.add(Duration(days: toleranciaDias));

  if (!referencia.isAfter(ultimoDiaTolerancia)) {
    return StatusAcesso(
      status: StatusMensalidade.tolerancia,
      podeAcessar: true,
      diasAtraso: diasAtraso,
      diasToleranciaRestantes: ultimoDiaTolerancia.difference(referencia).inDays + 1,
    );
  }

  return StatusAcesso(
    status: StatusMensalidade.bloqueado,
    podeAcessar: false,
    diasAtraso: diasAtraso,
  );
}

DateTime _semHorario(DateTime data) => DateTime(data.year, data.month, data.day);

/// Texto da notificação automática do dia, ou `null` se nenhuma mensagem
/// deve ser enviada hoje pra esse [status]. Fonte única do texto — a
/// Cloud Function agendada (fora do app Flutter) reproduz exatamente esta
/// mesma regra em JavaScript.
String? mensagemNotificacaoMensalidade(StatusAcesso status) {
  switch (status.status) {
    case StatusMensalidade.semRegistro:
      return null;
    case StatusMensalidade.emDia:
      switch (status.diasParaVencimento) {
        case 7:
          return 'Atenção! Sua mensalidade vence em 7 dias.';
        case 3:
          return 'Sua mensalidade está próxima do vencimento.';
        case 0:
          return 'Sua mensalidade vence hoje.';
        default:
          return null;
      }
    case StatusMensalidade.tolerancia:
      if (status.diasAtraso == 1) {
        return 'Sua mensalidade está vencida. Você possui '
            '$toleranciaMensalidadeDias dias de tolerância para continuar '
            'utilizando normalmente a academia.';
      }
      if (status.diasToleranciaRestantes == 1) {
        return 'Hoje é o último dia de tolerância. Regularize sua '
            'mensalidade para evitar o bloqueio.';
      }
      if (status.diasToleranciaRestantes != null) {
        return 'Restam ${status.diasToleranciaRestantes} dias de tolerância.';
      }
      return null;
    case StatusMensalidade.bloqueado:
      // So no primeiro dia de bloqueio — nao repete a mensagem todo dia
      // enquanto o aluno continuar inadimplente.
      if (status.diasAtraso == toleranciaMensalidadeDias + 1) {
        return 'Sua mensalidade permanece em atraso. Seu acesso ao '
            'aplicativo e à academia foi bloqueado até a regularização do '
            'pagamento.';
      }
      return null;
  }
}
