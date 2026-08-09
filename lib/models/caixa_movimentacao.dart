import 'package:cloud_firestore/cloud_firestore.dart';

/// Categoria de uma [CaixaMovimentacao].
enum TipoMovimentacaoCaixa {
  recebimento,
  suprimento,
  retirada,
  ajuste;

  String get label => switch (this) {
    TipoMovimentacaoCaixa.recebimento => 'Recebimento',
    TipoMovimentacaoCaixa.suprimento => 'Suprimento',
    TipoMovimentacaoCaixa.retirada => 'Retirada',
    TipoMovimentacaoCaixa.ajuste => 'Ajuste',
  };

  static TipoMovimentacaoCaixa fromFirestoreValue(String? value) {
    for (final tipo in TipoMovimentacaoCaixa.values) {
      if (tipo.name == value) return tipo;
    }
    return TipoMovimentacaoCaixa.ajuste;
  }
}

/// Uma movimentação dentro de um [Caixa] (coleção
/// `caixas/{caixaId}/movimentacoes`) — cada abertura/fechamento é sua
/// própria "sessão" de caixa, e as movimentações vivem só dentro dela.
///
/// [valor] é sempre a contribuição JÁ ASSINADA pro saldo do caixa:
/// positivo pra [TipoMovimentacaoCaixa.recebimento]/[TipoMovimentacaoCaixa.suprimento],
/// negativo pra [TipoMovimentacaoCaixa.retirada]. Pra
/// [TipoMovimentacaoCaixa.ajuste] o valor pode ir pros dois lados —
/// `CaixaService.registrarMovimentacao` normaliza o sinal antes de gravar,
/// então o saldo do caixa é sempre "some todos os `valor`", sem nenhuma
/// lógica condicional por tipo na hora de calcular totais.
class CaixaMovimentacao {
  const CaixaMovimentacao({
    this.id,
    required this.tipo,
    required this.valor,
    this.formaPagamento,
    this.descricao,
    this.contaReceberAlunoId,
    this.contaReceberId,
    required this.staffUid,
    required this.staffNome,
    this.criadoEm,
  });

  final String? id;
  final TipoMovimentacaoCaixa tipo;
  final double valor;
  final String? formaPagamento;
  final String? descricao;

  /// Referências pra rastrear a origem, preenchidas só quando o movimento
  /// veio de um recebimento de `ContaReceber` — ver
  /// `CaixaService.registrarRecebimentoContaReceber`. `ContaReceber.
  /// movimentacaoCaixaId` aponta de volta pra este documento, então o
  /// vínculo é sempre nos dois sentidos.
  final String? contaReceberAlunoId;
  final String? contaReceberId;

  final String staffUid;
  final String staffNome;
  final DateTime? criadoEm;

  factory CaixaMovimentacao.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final criadoEm = data['criadoEm'];
    return CaixaMovimentacao(
      id: id,
      tipo: TipoMovimentacaoCaixa.fromFirestoreValue(data['tipo'] as String?),
      valor: (data['valor'] as num?)?.toDouble() ?? 0,
      formaPagamento: data['formaPagamento'] as String?,
      descricao: data['descricao'] as String?,
      contaReceberAlunoId: data['contaReceberAlunoId'] as String?,
      contaReceberId: data['contaReceberId'] as String?,
      staffUid: data['staffUid'] as String? ?? '',
      staffNome: data['staffNome'] as String? ?? '',
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tipo': tipo.name,
      'valor': valor,
      'formaPagamento': formaPagamento,
      'descricao': descricao,
      'contaReceberAlunoId': contaReceberAlunoId,
      'contaReceberId': contaReceberId,
      'staffUid': staffUid,
      'staffNome': staffNome,
      'criadoEm': criadoEm != null
          ? Timestamp.fromDate(criadoEm!)
          : FieldValue.serverTimestamp(),
    };
  }
}
