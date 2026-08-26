import 'package:cloud_firestore/cloud_firestore.dart';

/// Situação de uma [ContaPagar]. Mesmo raciocínio de `StatusContaReceber`:
/// `vencido` é um estado persistido (não derivado automaticamente por um
/// job) — a tela calcula o status efetivo no cliente pra mostrar "Vencido"
/// sem esperar essa transição ser gravada.
enum StatusContaPagar {
  pendente,
  pago,
  vencido,
  cancelado;

  String get label => switch (this) {
    StatusContaPagar.pendente => 'Pendente',
    StatusContaPagar.pago => 'Pago',
    StatusContaPagar.vencido => 'Vencido',
    StatusContaPagar.cancelado => 'Cancelado',
  };

  static StatusContaPagar fromFirestoreValue(String? value) {
    for (final status in StatusContaPagar.values) {
      if (status.name == value) return status;
    }
    return StatusContaPagar.pendente;
  }
}

/// Uma despesa (fornecedor, conta de consumo, aluguel etc.) a pagar pela
/// academia — coleção `contasPagar`, nível de academia, mesmo padrão de
/// `Plano`/`Caixa` (não pertence a nenhum aluno, ao contrário de
/// `ContaReceber`).
///
/// Nunca é apagada: "excluir" (`ContaPagarService.excluirContaPagar`) marca
/// [status] como [StatusContaPagar.cancelado] e "pagar"
/// (`ContaPagarService.registrarPagamentoSemCaixa` ou
/// `CaixaService.registrarPagamentoContaPagar`, quando há caixa aberto)
/// marca como [StatusContaPagar.pago] — o documento e todo o histórico
/// continuam ali, mesmo raciocínio de `ContaReceber`.
class ContaPagar {
  const ContaPagar({
    this.id,
    required this.fornecedor,
    required this.descricao,
    required this.categoria,
    required this.valorOriginal,
    this.valorPago,
    this.desconto = 0,
    this.jurosMulta = 0,
    required this.vencimento,
    this.dataPagamento,
    this.status = StatusContaPagar.pendente,
    this.formaPagamento,
    this.observacao,
    this.criadoEm,
    this.atualizadoEm,
    this.criadoPorUid,
    this.criadoPorNome,
    this.pagoPorUid,
    this.pagoPorNome,
    this.movimentacaoCaixaId,
  });

  final String? id;
  final String fornecedor;
  final String descricao;
  final String categoria;
  final double valorOriginal;

  /// Preenchido só depois do pagamento.
  final double? valorPago;

  final double desconto;
  final double jurosMulta;
  final DateTime vencimento;
  final DateTime? dataPagamento;
  final StatusContaPagar status;
  final String? formaPagamento;
  final String? observacao;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  /// Auditoria: quem lançou a despesa.
  final String? criadoPorUid;
  final String? criadoPorNome;

  /// Auditoria: quem confirmou o pagamento (nulo até ser paga).
  final String? pagoPorUid;
  final String? pagoPorNome;

  /// Id da `CaixaMovimentacao` gerada quando este pagamento foi registrado
  /// com um caixa aberto (ver `CaixaService.registrarPagamentoContaPagar`).
  /// Nulo se a conta ainda não foi paga, ou se foi paga sem nenhum caixa
  /// aberto no momento — usado também como trava contra registrar o mesmo
  /// pagamento no caixa duas vezes.
  final String? movimentacaoCaixaId;

  /// Valor final: original - desconto + juros/multa. Nunca negativo (um
  /// desconto maior que o valor original zera a conta, não a deixa
  /// negativa).
  double get valorFinal => (valorOriginal - desconto + jurosMulta).clamp(0, double.infinity);

  /// O que ainda falta pagar. Negativo significa que foi pago a mais.
  double get saldoAPagar => valorFinal - (valorPago ?? 0);

  factory ContaPagar.fromFirestore(String id, Map<String, dynamic> data) {
    final vencimento = data['vencimento'];
    final dataPagamento = data['dataPagamento'];
    final criadoEm = data['criadoEm'];
    final atualizadoEm = data['atualizadoEm'];
    return ContaPagar(
      id: id,
      fornecedor: data['fornecedor'] as String? ?? '',
      descricao: data['descricao'] as String? ?? 'Despesa',
      categoria: data['categoria'] as String? ?? '',
      valorOriginal: (data['valorOriginal'] as num?)?.toDouble() ?? 0,
      valorPago: (data['valorPago'] as num?)?.toDouble(),
      desconto: (data['desconto'] as num?)?.toDouble() ?? 0,
      jurosMulta: (data['jurosMulta'] as num?)?.toDouble() ?? 0,
      vencimento: vencimento is Timestamp ? vencimento.toDate() : DateTime.now(),
      dataPagamento: dataPagamento is Timestamp ? dataPagamento.toDate() : null,
      status: StatusContaPagar.fromFirestoreValue(data['status'] as String?),
      formaPagamento: data['formaPagamento'] as String?,
      observacao: data['observacao'] as String?,
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
      atualizadoEm: atualizadoEm is Timestamp ? atualizadoEm.toDate() : null,
      criadoPorUid: data['criadoPorUid'] as String?,
      criadoPorNome: data['criadoPorNome'] as String?,
      pagoPorUid: data['pagoPorUid'] as String?,
      pagoPorNome: data['pagoPorNome'] as String?,
      movimentacaoCaixaId: data['movimentacaoCaixaId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fornecedor': fornecedor,
      'descricao': descricao,
      'categoria': categoria,
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
      if (pagoPorUid != null) 'pagoPorUid': pagoPorUid,
      if (pagoPorNome != null) 'pagoPorNome': pagoPorNome,
      if (movimentacaoCaixaId != null) 'movimentacaoCaixaId': movimentacaoCaixaId,
    };
  }

  ContaPagar copyWith({
    String? fornecedor,
    String? descricao,
    String? categoria,
    double? valorOriginal,
    double? valorPago,
    double? desconto,
    double? jurosMulta,
    DateTime? vencimento,
    DateTime? dataPagamento,
    StatusContaPagar? status,
    String? formaPagamento,
    String? observacao,
    String? pagoPorUid,
    String? pagoPorNome,
    String? movimentacaoCaixaId,
  }) {
    return ContaPagar(
      id: id,
      fornecedor: fornecedor ?? this.fornecedor,
      descricao: descricao ?? this.descricao,
      categoria: categoria ?? this.categoria,
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
      pagoPorUid: pagoPorUid ?? this.pagoPorUid,
      pagoPorNome: pagoPorNome ?? this.pagoPorNome,
      movimentacaoCaixaId: movimentacaoCaixaId ?? this.movimentacaoCaixaId,
    );
  }
}
