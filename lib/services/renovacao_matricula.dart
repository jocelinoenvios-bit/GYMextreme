import 'package:cloud_firestore/cloud_firestore.dart';

/// Pagar a mensalidade renova a matrícula (regra confirmada com o cliente:
/// o pagamento é na recepção, e quem paga em dia não pode ser barrado na
/// catraca por "plano expirado"). Estende a matrícula `ativa` do aluno até
/// [novoVencimento] — nunca encurta uma matrícula que já vai além disso
/// (ex.: plano trimestral pago adiantado).
///
/// Devolve `false` quando o aluno não tem nenhuma matrícula ativa — a
/// catraca nega acesso sem matrícula, e quem chamou deve avisar a
/// recepção.
///
/// Função solta (e não método de um serviço) porque os três caminhos de
/// baixa de mensalidade usam: `AlunoService.marcarPagamentoRecebido`,
/// `AlunoService.registrarRecebimento` e
/// `CaixaService.registrarRecebimentoContaReceber`.
Future<bool> renovarMatriculaPorPagamento(
  FirebaseFirestore firestore,
  String alunoUid,
  DateTime novoVencimento,
) async {
  final ativas = await firestore
      .collection('alunos')
      .doc(alunoUid)
      .collection('matriculas')
      .where('status', isEqualTo: 'ativa')
      .get();
  if (ativas.docs.isEmpty) return false;

  for (final doc in ativas.docs) {
    final atual = doc.data()['dataVencimento'];
    final vencimentoAtual = atual is Timestamp ? atual.toDate() : null;
    if (vencimentoAtual != null && !vencimentoAtual.isBefore(novoVencimento)) {
      continue;
    }
    await doc.reference.update({
      'dataVencimento': Timestamp.fromDate(novoVencimento),
      'renovadaPorPagamentoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }
  return true;
}
