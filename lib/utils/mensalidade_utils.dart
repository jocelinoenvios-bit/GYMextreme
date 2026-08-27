/// Mesmo dia do mes, um mes a frente — com fallback pro ultimo dia do mes
/// de destino quando ele for mais curto (ex.: 31/01 -> 28 ou 29/02). Usada
/// por qualquer fluxo que avança `Aluno.proximoVencimento` em 1 mes a
/// partir de um pagamento confirmado (`AlunoService.marcarPagamentoRecebido`,
/// `AlunoService.registrarRecebimento`, `CaixaService.registrarRecebimentoContaReceber`)
/// — uma única implementação, pra nunca calcular esse avanço de dois jeitos
/// diferentes.
DateTime adicionarUmMes(DateTime data) {
  final novoMes = data.month == 12 ? 1 : data.month + 1;
  final novoAno = data.month == 12 ? data.year + 1 : data.year;
  final ultimoDiaDoNovoMes = DateTime(novoAno, novoMes + 1, 0).day;
  final dia = data.day > ultimoDiaDoNovoMes ? ultimoDiaDoNovoMes : data.day;
  return DateTime(novoAno, novoMes, dia);
}
