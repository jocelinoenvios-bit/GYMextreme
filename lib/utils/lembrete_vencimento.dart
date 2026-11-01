/// Lembrete de vencimento da mensalidade, que vai pra caixa de mensagens do
/// aluno nos 3 dias antes do vencimento.
///
/// O lembrete é criado pelo próprio app do aluno quando ele abre o app
/// dentro dessa janela (ver `AlunoService.garantirLembreteVencimento`).
/// Assim funciona sem servidor agendado, e o aluno que abre o app sempre
/// encontra o aviso.
library;

/// Quantos dias antes do vencimento o lembrete aparece.
const diasAntesDoLembrete = 3;

DateTime _soData(DateTime data) => DateTime(data.year, data.month, data.day);

/// Dias inteiros de [hoje] até [vencimento] (0 = vence hoje, negativo =
/// já venceu). Ignora o horário dos dois lados.
int diasAteVencimento(DateTime vencimento, DateTime hoje) {
  // Pela diferença em UTC, pra horário de verão nunca virar "meio dia".
  final v = _soData(vencimento);
  final h = _soData(hoje);
  return DateTime.utc(v.year, v.month, v.day)
      .difference(DateTime.utc(h.year, h.month, h.day))
      .inDays;
}

/// Se [hoje] está na janela do lembrete: de 3 dias antes até o próprio dia
/// do vencimento. Depois de vencido não é mais lembrete (aí é atraso, outro
/// fluxo).
bool deveLembrarVencimento(DateTime? vencimento, DateTime hoje) {
  if (vencimento == null) return false;
  final dias = diasAteVencimento(vencimento, hoje);
  return dias >= 0 && dias <= diasAntesDoLembrete;
}

/// Id fixo do documento do lembrete — um por vencimento. É o que impede o
/// mesmo aviso de chegar duas vezes, por mais que o aluno abra o app.
/// Precisa bater com a regra do Firestore (`lembrete-vencimento-AAAA-MM-DD`).
String idLembreteVencimento(DateTime vencimento) {
  final ano = vencimento.year.toString().padLeft(4, '0');
  final mes = vencimento.month.toString().padLeft(2, '0');
  final dia = vencimento.day.toString().padLeft(2, '0');
  return 'lembrete-vencimento-$ano-$mes-$dia';
}

String _ddMm(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';

/// Texto da mensagem. Leva a data, e não "faltam 3 dias": a mensagem
/// fica na caixa e seria lida depois, quando a contagem já mudou.
String textoLembreteVencimento(DateTime vencimento) {
  return 'Lembrete: sua mensalidade vence em ${_ddMm(vencimento)}. '
      'Se já pagou, pode desconsiderar esta mensagem.';
}

/// Frase curta da tela inicial do aluno, essa sim relativa ao dia de hoje.
String avisoCurtoVencimento(DateTime vencimento, DateTime hoje) {
  final dias = diasAteVencimento(vencimento, hoje);
  if (dias <= 0) return 'Sua mensalidade vence hoje';
  if (dias == 1) return 'Sua mensalidade vence amanhã';
  return 'Sua mensalidade vence em ${_ddMm(vencimento)}';
}

/// `remetenteUid` do lembrete automático — não é uma pessoa. A regra do
/// Firestore exige este valor pro aluno poder criar o lembrete.
const remetenteLembreteAutomatico = 'sistema';
