import '../models/aluno.dart';
import 'status_acesso.dart';

/// Regras de negócio do ciclo de inadimplência/inatividade (mensagem de
/// retorno, inativação e segunda tentativa de contato) — únicas fontes de
/// verdade dos prazos 15/30/45, reproduzidas em JS pela Cloud Function
/// agendada (`functions/lib/inadimplencia.js`), mesmo padrão já usado por
/// `toleranciaMensalidadeDias`/`status_acesso.dart`.
const int diasParaMensagemRetorno = 15;
const int diasParaInativacao = 30;
const int diasParaMensagemReativacao = 45;

/// Status "operacional" do aluno, exibido na área administrativa —
/// combina [Aluno.ativo] (já usado pela autorização de acesso da catraca)
/// com [StatusMensalidade] (derivado do vencimento) em vez de introduzir
/// um novo enum persistido: `ativo == false` sempre vence (aluno inativo
/// continua inativo mesmo que a mensalidade dele seja regularizada por
/// engano, até alguém reativar explicitamente).
enum StatusOperacionalAluno {
  ativo,
  inadimplente,
  inativo;

  String get label => switch (this) {
    StatusOperacionalAluno.ativo => 'Ativo',
    StatusOperacionalAluno.inadimplente => 'Inadimplente',
    StatusOperacionalAluno.inativo => 'Inativo',
  };
}

StatusOperacionalAluno calcularStatusOperacional(Aluno aluno, {DateTime? hoje}) {
  if (!aluno.ativo) return StatusOperacionalAluno.inativo;

  final status = calcularStatusAcesso(proximoVencimento: aluno.proximoVencimento, hoje: hoje);
  if (status.status == StatusMensalidade.bloqueado) {
    return StatusOperacionalAluno.inadimplente;
  }
  return StatusOperacionalAluno.ativo;
}

/// Filtros da tela administrativa de alunos (`AlunosListScreen`) — cada
/// valor cruza [StatusOperacionalAluno] com os prazos 15/30/45 pra achar
/// exatamente quem a recepção precisa contatar.
enum FiltroStatusAluno {
  todos,
  ativos,
  inadimplentes,
  inativos,
  atraso15Dias,
  inatividade45Dias;

  String get label => switch (this) {
    FiltroStatusAluno.todos => 'Todos',
    FiltroStatusAluno.ativos => 'Ativos',
    FiltroStatusAluno.inadimplentes => 'Inadimplentes',
    FiltroStatusAluno.inativos => 'Inativos',
    FiltroStatusAluno.atraso15Dias => '15+ dias de atraso',
    FiltroStatusAluno.inatividade45Dias => '45+ dias inativo',
  };
}

/// `true` quando [aluno] pertence ao [filtro] escolhido — `ficha` é a
/// `Aluno` correspondente (pode ser `null` se ainda não foi carregada;
/// nesse caso o aluno só aparece em [FiltroStatusAluno.todos]).
bool alunoPassaNoFiltro(
  Aluno? ficha,
  FiltroStatusAluno filtro, {
  DateTime? hoje,
}) {
  if (filtro == FiltroStatusAluno.todos) return true;
  if (ficha == null) return false;

  final status = calcularStatusOperacional(ficha, hoje: hoje);
  switch (filtro) {
    case FiltroStatusAluno.todos:
      return true;
    case FiltroStatusAluno.ativos:
      return status == StatusOperacionalAluno.ativo;
    case FiltroStatusAluno.inadimplentes:
      return status == StatusOperacionalAluno.inadimplente;
    case FiltroStatusAluno.inativos:
      return status == StatusOperacionalAluno.inativo;
    case FiltroStatusAluno.atraso15Dias:
      if (status != StatusOperacionalAluno.inadimplente) return false;
      final diasAtraso =
          calcularStatusAcesso(proximoVencimento: ficha.proximoVencimento, hoje: hoje).diasAtraso;
      return diasAtraso != null && diasAtraso >= diasParaMensagemRetorno;
    case FiltroStatusAluno.inatividade45Dias:
      if (status != StatusOperacionalAluno.inativo) return false;
      final dias = diasDesdeInativacao(ficha, hoje: hoje);
      return dias != null && dias >= diasParaMensagemReativacao;
  }
}

/// Dias corridos desde que [Aluno.dataInativacao] aconteceu, ou `null` se
/// o aluno nunca foi inativado (ou já foi reativado depois da última
/// inativação — ver [aindaInativoDesde]).
int? diasDesdeInativacao(Aluno aluno, {DateTime? hoje}) {
  if (!aindaInativoDesde(aluno)) return null;
  final referencia = _semHorario(hoje ?? DateTime.now());
  final inativacao = _semHorario(aluno.dataInativacao!);
  return referencia.difference(inativacao).inDays;
}

/// `true` quando [Aluno.dataInativacao] representa a inativação ATUAL
/// (aluno.ativo == false) — depois de reativado, `dataInativacao` continua
/// preenchida só como histórico, então nunca deve contar dias a partir
/// dela enquanto o aluno estiver ativo de novo.
bool aindaInativoDesde(Aluno aluno) => !aluno.ativo && aluno.dataInativacao != null;

DateTime _semHorario(DateTime data) => DateTime(data.year, data.month, data.day);
