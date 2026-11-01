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

/// Primeiro vencimento de um aluno recém-cadastrado: 1 mês depois do dia
/// do cadastro (cadastrou em 10/03, vence em 10/04). Sem horário — vence o
/// dia inteiro.
DateTime primeiroVencimento(DateTime cadastro) {
  return adicionarUmMes(DateTime(cadastro.year, cadastro.month, cadastro.day));
}

/// [data] somada de [meses] meses, no mesmo dia do mês — ou no último dia
/// do mês de destino, quando ele for mais curto. Sempre a partir da data
/// original (somar 1 mês várias vezes faria 31/01 → 28/02 → 28/03).
DateTime somarMeses(DateTime data, int meses) {
  final total = data.year * 12 + (data.month - 1) + meses;
  final ano = total ~/ 12;
  final mes = total % 12 + 1;
  final ultimoDia = DateTime(ano, mes + 1, 0).day;
  return DateTime(ano, mes, data.day > ultimoDia ? ultimoDia : data.day);
}

/// Vencimento pra aluno antigo, cadastrado antes do vencimento automático:
/// a próxima vez (depois de hoje) que cai o dia do mês em que ele começou
/// — começou 10/08, vence 10/11. Nunca uma data passada: preencher não
/// pode deixar ninguém inadimplente de uma hora pra outra. Sem data de
/// início, vale a regra do cadastro novo (1 mês a partir de hoje).
DateTime vencimentoParaAlunoAntigo({DateTime? inicio, required DateTime hoje}) {
  final dia = DateTime(hoje.year, hoje.month, hoje.day);
  if (inicio == null) return primeiroVencimento(dia);
  final base = DateTime(inicio.year, inicio.month, inicio.day);
  var meses = 1;
  if (base.isBefore(dia)) {
    // Pula direto pra perto de hoje em vez de contar mês a mês desde o início.
    meses = (dia.year - base.year) * 12 + (dia.month - base.month);
    if (meses < 1) meses = 1;
  }
  while (!somarMeses(base, meses).isAfter(dia)) {
    meses++;
  }
  return somarMeses(base, meses);
}
