import 'package:cloud_firestore/cloud_firestore.dart';

/// Situação de uma [ContaReceber]. `vencido` é um estado persistido (não
/// derivado automaticamente por um job) — ver `calcularStatusEfetivo` em
/// `lib/utils/status_conta_receber.dart` pra saber se uma conta ainda
/// `pendente` já passou do vencimento, sem precisar esperar essa transição
/// ser gravada.
enum StatusContaReceber {
  pendente,
  pago,
  vencido,
  cancelado;

  String get label => switch (this) {
    StatusContaReceber.pendente => 'Pendente',
    StatusContaReceber.pago => 'Pago',
    StatusContaReceber.vencido => 'Vencido',
    StatusContaReceber.cancelado => 'Cancelado',
  };

  static StatusContaReceber fromFirestoreValue(String? value) {
    for (final status in StatusContaReceber.values) {
      if (status.name == value) return status;
    }
    return StatusContaReceber.pendente;
  }
}

/// Uma cobrança em aberto (ou já resolvida) de um aluno — coleção
/// `alunos/{uid}/contasReceber`. Mensalidade "clássica" continua usando o
/// fluxo simples de [Aluno.proximoVencimento]/`Pagamento`
/// (`AlunoService.marcarPagamentoRecebido`); `ContaReceber` é um registro
/// financeiro mais completo (desconto, juros/multa, vínculo opcional com
/// uma [Matricula]), pra qualquer cobrança que precise desse detalhe —
/// os dois convivem, um não substitui o outro nesta fase.
///
/// Nunca é apagada: "excluir" (`AlunoService.excluirContaReceber`) marca
/// [status] como [StatusContaReceber.cancelado] e "receber"
/// (`AlunoService.registrarRecebimento`) marca como
/// [StatusContaReceber.pago] — o documento e todo o histórico de quem fez
/// o quê continuam ali.
class ContaReceber {
  const ContaReceber({
    this.id,
    required this.alunoId,
    this.matriculaId,
    required this.descricao,
    required this.valorOriginal,
    this.valorPago,
    this.desconto = 0,
    this.jurosMulta = 0,
    required this.vencimento,
    this.dataPagamento,
    this.status = StatusContaReceber.pendente,
    this.formaPagamento,
    this.observacao,
    this.criadoEm,
    this.atualizadoEm,
    this.criadoPorUid,
    this.criadoPorNome,
    this.recebidoPorUid,
    this.recebidoPorNome,
    this.movimentacaoCaixaId,
  });

  final String? id;
  final String alunoId;

  /// Matrícula que originou esta cobrança, se houver — ver
  /// `AlunoService.criarContaReceberDeMatricula`. Nunca duplica campos da
  /// matrícula (só guarda o id); valor/vencimento são copiados uma vez na
  /// criação, exatamente como `Matricula.valorContratado` copia do
  /// `Plano` — mudar a matrícula depois não altera cobranças já geradas.
  final String? matriculaId;

  final String descricao;
  final double valorOriginal;

  /// Preenchido só depois do recebimento (`AlunoService.registrarRecebimento`).
  final double? valorPago;

  /// Desconto concedido — pode ser ajustado tanto na criação/edição quanto
  /// no momento do recebimento (ex.: desconto por pagamento à vista).
  final double desconto;

  /// Juros/multa por atraso — mesmo raciocínio do desconto: pode ser
  /// definido antes ou só na hora de receber.
  final double jurosMulta;

  final DateTime vencimento;
  final DateTime? dataPagamento;
  final StatusContaReceber status;
  final String? formaPagamento;
  final String? observacao;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  /// Auditoria: quem lançou a cobrança.
  final String? criadoPorUid;
  final String? criadoPorNome;

  /// Auditoria: quem confirmou o recebimento (nulo até ser paga).
  final String? recebidoPorUid;
  final String? recebidoPorNome;

  /// Id da `CaixaMovimentacao` gerada quando este recebimento foi
  /// registrado com um caixa aberto (ver
  /// `CaixaService.registrarRecebimentoContaReceber`). Nulo se a cobrança
  /// ainda não foi paga, ou se foi paga sem nenhum caixa aberto no
  /// momento — usado também como trava contra registrar o mesmo
  /// recebimento no caixa duas vezes.
  final String? movimentacaoCaixaId;

  /// Valor líquido esperado: original - desconto + juros/multa. Nunca
  /// negativo (um desconto maior que o valor original zera a cobrança,
  /// não a deixa negativa).
  double get valorLiquido => (valorOriginal - desconto + jurosMulta).clamp(0, double.infinity);

  /// O que ainda falta receber. Negativo significa que foi pago a mais
  /// (a tela decide como exibir isso, o cálculo aqui não esconde o sinal).
  double get saldoDevedor => valorLiquido - (valorPago ?? 0);

  factory ContaReceber.fromFirestore(String id, Map<String, dynamic> data) {
    final vencimento = data['vencimento'];
    final dataPagamento = data['dataPagamento'];
    final criadoEm = data['criadoEm'];
    final atualizadoEm = data['atualizadoEm'];
    return ContaReceber(
      id: id,
      alunoId: data['alunoId'] as String? ?? '',
      matriculaId: data['matriculaId'] as String?,
      descricao: data['descricao'] as String? ?? 'Cobrança',
      valorOriginal: (data['valorOriginal'] as num?)?.toDouble() ?? 0,
      valorPago: (data['valorPago'] as num?)?.toDouble(),
      desconto: (data['desconto'] as num?)?.toDouble() ?? 0,
      jurosMulta: (data['jurosMulta'] as num?)?.toDouble() ?? 0,
      vencimento: vencimento is Timestamp ? vencimento.toDate() : DateTime.now(),
      dataPagamento: dataPagamento is Timestamp ? dataPagamento.toDate() : null,
      status: StatusContaReceber.fromFirestoreValue(data['status'] as String?),
      formaPagamento: data['formaPagamento'] as String?,
      observacao: data['observacao'] as String?,
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
      atualizadoEm: atualizadoEm is Timestamp ? atualizadoEm.toDate() : null,
      criadoPorUid: data['criadoPorUid'] as String?,
      criadoPorNome: data['criadoPorNome'] as String?,
      recebidoPorUid: data['recebidoPorUid'] as String?,
      recebidoPorNome: data['recebidoPorNome'] as String?,
      movimentacaoCaixaId: data['movimentacaoCaixaId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'alunoId': alunoId,
      'matriculaId': matriculaId,
      'descricao': descricao,
      'valorOriginal': valorOriginal,
      'valorPago': valorPago,
      'desconto': desconto,
      'jurosMulta': jurosMulta,
      'vencimento': Timestamp.fromDate(vencimento),
      'dataPagamento': dataPagamento != null ? Timestamp.fromDate(dataPagamento!) : null,
      'status': status.name,
      'formaPagamento': formaPagamento,
      'observacao': observacao,
      'criadoEm': criadoEm != null
          ? Timestamp.fromDate(criadoEm!)
          : FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
      if (criadoPorUid != null) 'criadoPorUid': criadoPorUid,
      if (criadoPorNome != null) 'criadoPorNome': criadoPorNome,
      if (recebidoPorUid != null) 'recebidoPorUid': recebidoPorUid,
      if (recebidoPorNome != null) 'recebidoPorNome': recebidoPorNome,
      if (movimentacaoCaixaId != null) 'movimentacaoCaixaId': movimentacaoCaixaId,
    };
  }

  ContaReceber copyWith({
    String? matriculaId,
    String? descricao,
    double? valorOriginal,
    double? valorPago,
    double? desconto,
    double? jurosMulta,
    DateTime? vencimento,
    DateTime? dataPagamento,
    StatusContaReceber? status,
    String? formaPagamento,
    String? observacao,
    String? recebidoPorUid,
    String? recebidoPorNome,
    String? movimentacaoCaixaId,
  }) {
    return ContaReceber(
      id: id,
      alunoId: alunoId,
      matriculaId: matriculaId ?? this.matriculaId,
      descricao: descricao ?? this.descricao,
      valorOriginal: valorOriginal ?? this.valorOriginal,
      valorPago: valorPago ?? this.valorPago,
      desconto: desconto ?? this.desconto,
      jurosMulta: jurosMulta ?? this.jurosMulta,
      vencimento: vencimento ?? this.vencimento,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      status: status ?? this.status,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      observacao: observacao ?? this.observacao,
      criadoEm: criadoEm,
      atualizadoEm: atualizadoEm,
      criadoPorUid: criadoPorUid,
      criadoPorNome: criadoPorNome,
      recebidoPorUid: recebidoPorUid ?? this.recebidoPorUid,
      recebidoPorNome: recebidoPorNome ?? this.recebidoPorNome,
      movimentacaoCaixaId: movimentacaoCaixaId ?? this.movimentacaoCaixaId,
    );
  }
}
