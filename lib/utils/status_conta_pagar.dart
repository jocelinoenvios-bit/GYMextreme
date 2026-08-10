import '../models/conta_pagar.dart';

/// Situação "de verdade" de uma [ContaPagar] pra exibição — mesmo
/// raciocínio de `calcularStatusEfetivo` em `status_conta_receber.dart`: o
/// campo [ContaPagar.status] gravado no Firestore só muda quando alguém
/// registra o pagamento ou cancela; não existe (ainda) um job agendado
/// que marca `pendente` como `vencido` automaticamente quando a data
/// passa. Esta função calcula esse estado efetivo sem depender desse job.
///
/// `pago`/`cancelado` são estados finais e nunca são "reclassificados"
/// como vencidos, mesmo que o vencimento já tenha passado.
StatusContaPagar calcularStatusEfetivoContaPagar(ContaPagar conta, {DateTime? hoje}) {
  if (conta.status != StatusContaPagar.pendente) return conta.status;

  final referencia = _semHorario(hoje ?? DateTime.now());
  final vencimento = _semHorario(conta.vencimento);

  if (referencia.isAfter(vencimento)) return StatusContaPagar.vencido;
  return StatusContaPagar.pendente;
}

DateTime _semHorario(DateTime data) => DateTime(data.year, data.month, data.day);
