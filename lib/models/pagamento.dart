import 'package:cloud_firestore/cloud_firestore.dart';

/// Um registro de pagamento de mensalidade (coleção
/// `alunos/{uid}/pagamentos`) — a recepção marca manualmente quando recebe
/// o valor (PIX, dinheiro, cartão, transferência etc., fora do app nesta
/// primeira versão). Cada registro empurra [Aluno.proximoVencimento] pra
/// frente e fica como histórico/auditoria de quem confirmou o quê.
class Pagamento {
  const Pagamento({
    this.id,
    required this.registradoEm,
    this.vencimentoAnterior,
    required this.novoVencimento,
    this.registradoPorUid,
    this.registradoPorNome,
    this.valor,
    this.formaPagamento,
    this.contaReceberId,
  });

  final String? id;
  final DateTime registradoEm;
  final DateTime? vencimentoAnterior;
  final DateTime novoVencimento;
  final String? registradoPorUid;
  final String? registradoPorNome;

  /// Preenchidos pelo "Receber mensalidade" (registros antigos, do botão
  /// "Marcar pagamento recebido", não têm valor nem forma).
  final double? valor;
  final String? formaPagamento;

  /// A cobrança paga gerada junto (Contas a receber).
  final String? contaReceberId;

  factory Pagamento.fromFirestore(String id, Map<String, dynamic> data) {
    final registradoEm = data['registradoEm'];
    final vencimentoAnterior = data['vencimentoAnterior'];
    final novoVencimento = data['novoVencimento'];
    return Pagamento(
      id: id,
      registradoEm: registradoEm is Timestamp ? registradoEm.toDate() : DateTime.now(),
      vencimentoAnterior: vencimentoAnterior is Timestamp ? vencimentoAnterior.toDate() : null,
      novoVencimento: novoVencimento is Timestamp ? novoVencimento.toDate() : DateTime.now(),
      registradoPorUid: data['registradoPorUid'] as String?,
      registradoPorNome: data['registradoPorNome'] as String?,
      valor: (data['valor'] as num?)?.toDouble(),
      formaPagamento: data['formaPagamento'] as String?,
      contaReceberId: data['contaReceberId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'registradoEm': FieldValue.serverTimestamp(),
      'vencimentoAnterior': vencimentoAnterior != null
          ? Timestamp.fromDate(vencimentoAnterior!)
          : null,
      'novoVencimento': Timestamp.fromDate(novoVencimento),
      'registradoPorUid': registradoPorUid,
      'registradoPorNome': registradoPorNome,
      if (valor != null) 'valor': valor,
      if (formaPagamento != null) 'formaPagamento': formaPagamento,
      if (contaReceberId != null) 'contaReceberId': contaReceberId,
    };
  }
}
