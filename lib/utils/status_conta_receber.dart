import '../models/conta_receber.dart';

/// Situação "de verdade" de uma [ContaReceber] pra exibição — igual
/// motivação de `calcularStatusAcesso` em `status_acesso.dart`: o campo
/// [ContaReceber.status] gravado no Firestore só muda quando alguém
/// registra o recebimento ou cancela; não existe (ainda) um job agendado
/// que marca `pendente` como `vencido` automaticamente quando a data
/// passa. Esta função calcula esse estado efetivo sem depender desse job
/// — a lista de Contas a Receber usa isto pra mostrar "Vencido" na hora
/// certa, sem esperar nenhuma escrita no banco.
///
/// `pago`/`cancelado` são estados finais e nunca são "reclassificados"
/// como vencidos, mesmo que o vencimento já tenha passado.
StatusContaReceber calcularStatusEfetivo(ContaReceber conta, {DateTime? hoje}) {
  if (conta.status != StatusContaReceber.pendente) return conta.status;

  final referencia = _semHorario(hoje ?? DateTime.now());
  final vencimento = _semHorario(conta.vencimento);

  if (referencia.isAfter(vencimento)) return StatusContaReceber.vencido;
  return StatusContaReceber.pendente;
}

DateTime _semHorario(DateTime data) => DateTime(data.year, data.month, data.day);
