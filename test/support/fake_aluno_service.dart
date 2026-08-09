import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/anamnese.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/avaliacao_fisica.dart';
import 'package:gymextreme_app/models/endereco.dart';
import 'package:gymextreme_app/models/matricula.dart';
import 'package:gymextreme_app/models/pagamento.dart';
import 'package:gymextreme_app/models/termo_aceite.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/services/aluno_service.dart';

/// Dublê de teste do [AlunoService] — implementa a mesma interface pública
/// sem tocar o Firestore de verdade (mesmo padrão já usado para
/// `ExerciseRepository` nos testes da Biblioteca Oficial). Guarda o que foi
/// salvo em cada chamada pra o teste inspecionar depois (`ultimo*`).
class FakeAlunoService implements AlunoService {
  FakeAlunoService({
    this.aluno,
    this.anamnese,
    this.termo = TermoAceite.naoAceito,
    this.avaliacoes = const [],
    this.treinos = const [],
    this.alunos = const [],
    this.matriculas = const [],
  });

  Aluno? aluno;
  Anamnese? anamnese;
  TermoAceite termo;
  List<AvaliacaoFisica> avaliacoes;
  List<Treino> treinos;
  List<AppUser> alunos;
  List<Matricula> matriculas;

  Aluno? ultimoAlunoSalvo;
  Anamnese? ultimaAnamneseSalva;
  TermoAceite? ultimoTermoSalvo;
  AvaliacaoFisica? ultimaAvaliacaoSalva;
  String? ultimaMatriculaCanceladaId;

  @override
  Stream<List<AppUser>> watchAlunos() => Stream.value(alunos);

  @override
  Stream<Aluno?> watchAluno(String uid) => Stream.value(aluno);

  @override
  Stream<Anamnese?> watchAnamnese(String uid) => Stream.value(anamnese);

  @override
  Stream<TermoAceite> watchTermoAceite(String uid) => Stream.value(termo);

  @override
  Stream<List<AvaliacaoFisica>> watchAvaliacoes(String uid) => Stream.value(avaliacoes);

  @override
  Future<void> salvarDadosAluno(Aluno aluno) async {
    ultimoAlunoSalvo = aluno;
    this.aluno = aluno;
  }

  @override
  Future<void> salvarAnamnese(String uid, Anamnese anamnese) async {
    ultimaAnamneseSalva = anamnese;
    this.anamnese = anamnese;
  }

  @override
  Future<void> salvarTermoAceite(String uid, TermoAceite termo) async {
    ultimoTermoSalvo = termo;
    this.termo = termo;
  }

  @override
  Future<void> adicionarAvaliacao(String uid, AvaliacaoFisica avaliacao) async {
    ultimaAvaliacaoSalva = avaliacao;
    avaliacoes = [...avaliacoes, avaliacao];
  }

  @override
  Stream<List<Pagamento>> watchPagamentos(String uid) => Stream.value(const []);

  @override
  Future<void> marcarPagamentoRecebido(
    String uid, {
    required DateTime? vencimentoAtual,
    required String staffUid,
    required String staffNome,
  }) async {}

  @override
  Future<void> definirVencimentoInicial(String uid, DateTime vencimento) async {}

  @override
  Stream<List<Matricula>> watchMatriculas(String uid) =>
      Stream.value(matriculas.where((m) => m.alunoId == uid).toList());

  @override
  Stream<List<Matricula>> watchTodasMatriculas() => Stream.value(matriculas);

  @override
  Future<String> criarMatricula(
    String alunoUid, {
    required String planoId,
    required DateTime dataInicio,
    required DateTime dataVencimento,
    required double valorContratado,
    String? formaPagamento,
    String? observacao,
  }) async {
    final id = 'matricula-${matriculas.length + 1}';
    matriculas = [
      for (final matricula in matriculas)
        if (matricula.alunoId == alunoUid && matricula.status == StatusMatricula.ativa)
          matricula.copyWith(status: StatusMatricula.cancelada)
        else
          matricula,
      Matricula(
        id: id,
        alunoId: alunoUid,
        planoId: planoId,
        dataInicio: dataInicio,
        dataVencimento: dataVencimento,
        valorContratado: valorContratado,
        formaPagamento: formaPagamento,
        observacao: observacao,
      ),
    ];
    return id;
  }

  @override
  Future<void> cancelarMatricula(String alunoUid, String matriculaId) async {
    ultimaMatriculaCanceladaId = matriculaId;
    matriculas = [
      for (final matricula in matriculas)
        if (matricula.id == matriculaId)
          matricula.copyWith(status: StatusMatricula.cancelada)
        else
          matricula,
    ];
  }

  @override
  Stream<List<Treino>> watchTreinos(String uid) => Stream.value(treinos);

  @override
  Future<Treino?> buscarTreino(String alunoUid, String treinoId) async {
    for (final treino in treinos) {
      if (treino.id == treinoId) return treino;
    }
    return null;
  }

  @override
  Future<String> salvarTreino(
    String alunoUid,
    Treino treino, {
    required String staffUid,
    required String staffNome,
  }) async {
    final id = treino.id ?? 'novo-treino';
    treinos = [
      ...treinos.where((t) => t.id != id),
      Treino(
        id: id,
        nome: treino.nome,
        letra: treino.letra,
        grupoMuscular: treino.grupoMuscular,
        ordem: treino.ordem,
        exercicios: treino.exercicios,
      ),
    ];
    return id;
  }

  @override
  Future<void> excluirTreino(String alunoUid, String treinoId) async {
    treinos = treinos.where((t) => t.id != treinoId).toList();
  }

  @override
  Future<String> duplicarTreino(
    String alunoUid,
    Treino treino, {
    required String staffUid,
    required String staffNome,
  }) {
    return salvarTreino(
      alunoUid,
      Treino(
        nome: '${treino.nome} (cópia)',
        letra: treino.letra,
        grupoMuscular: treino.grupoMuscular,
        ordem: treino.ordem,
        exercicios: treino.exercicios,
      ),
      staffUid: staffUid,
      staffNome: staffNome,
    );
  }

  @override
  Future<String> copiarTreinoDeOutroAluno({
    required String origemUid,
    required String treinoId,
    required String destinoUid,
    required String staffUid,
    required String staffNome,
  }) async {
    throw UnimplementedError('nao usado nos testes atuais');
  }

  @override
  Future<String> cadastrarAluno({
    required String nome,
    required String email,
    required String senhaInicial,
    Sexo? sexo,
    DateTime? dataNascimento,
    int? idade,
    String? cpf,
    String? rg,
    String? telefone,
    String? whatsapp,
    Endereco endereco = Endereco.vazio,
    String? contatoEmergenciaNome,
    String? contatoEmergenciaTelefone,
    String? observacoes,
    DateTime? dataInicio,
    int? diaVencimento,
    required String cadastradoPorUid,
    required String cadastradoPorNome,
  }) async {
    const uid = 'aluno-novo';
    aluno = Aluno(
      uid: uid,
      sexo: sexo,
      dataNascimento: dataNascimento,
      idadeInformada: idade,
      cpf: cpf,
      rg: rg,
      telefone: telefone,
      whatsapp: whatsapp,
      endereco: endereco,
      contatoEmergenciaNome: contatoEmergenciaNome,
      contatoEmergenciaTelefone: contatoEmergenciaTelefone,
      observacoes: observacoes,
      dataInicio: dataInicio,
      diaVencimento: diaVencimento,
      cadastradoPorUid: cadastradoPorUid,
      cadastradoPorNome: cadastradoPorNome,
    );
    return uid;
  }
}
