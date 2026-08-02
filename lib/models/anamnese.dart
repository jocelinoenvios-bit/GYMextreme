import 'package:cloud_firestore/cloud_firestore.dart';

/// Pergunta 02 da anamnese: "Qual o seu objetivo?".
enum ObjetivoTreino {
  hipertrofia,
  emagrecimento,
  indicacaoMedica;

  String get label => switch (this) {
    ObjetivoTreino.hipertrofia => 'Hipertrofia',
    ObjetivoTreino.emagrecimento => 'Emagrecimento',
    ObjetivoTreino.indicacaoMedica => 'Indicação médica',
  };
}

/// Pergunta 03: "Pratica atualmente musculação?".
enum SituacaoMusculacao {
  sim,
  nao,
  nuncaFez;

  String get label => switch (this) {
    SituacaoMusculacao.sim => 'Sim',
    SituacaoMusculacao.nao => 'Não',
    SituacaoMusculacao.nuncaFez => 'Nunca fez',
  };
}

/// Pergunta 05: "Sua pressão arterial é?".
enum NivelPressaoArterial {
  normal,
  alta,
  baixa,
  naoSei;

  String get label => switch (this) {
    NivelPressaoArterial.normal => 'Normal',
    NivelPressaoArterial.alta => 'Alta',
    NivelPressaoArterial.baixa => 'Baixa',
    NivelPressaoArterial.naoSei => 'Não sei',
  };
}

/// Opcoes da pergunta 06 ("Você é:") — multipla escolha.
const condicoesClinicasDisponiveis = {
  'hipertenso': 'Hipertenso',
  'cardiaco': 'Cardíaco',
  'diabetico': 'Diabético',
  'nenhum': 'Nenhum',
};

/// Opcoes da pergunta 12 ("Faz uso de?") — multipla escolha.
const usoSubstanciasDisponiveis = {
  'alcool': 'Álcool',
  'cigarro': 'Cigarro',
  'nao': 'Não',
};

/// Respostas da ficha de anamnese (questionario de saude), replicando a
/// ficha "ANAMNESE" em papel, pergunta a pergunta.
class Anamnese {
  const Anamnese({
    this.diasPorSemana,
    this.objetivo,
    this.situacaoMusculacao,
    this.tempoParadoMusculacao,
    this.problemaColunaJoelho,
    this.problemaColunaJoelhoQual,
    this.pressaoArterial,
    this.condicoesClinicas = const [],
    this.alergia,
    this.alergiaQual,
    this.doresCorpo,
    this.doresCorpoQual,
    this.lesaoOsteoMuscular,
    this.lesaoOsteoMuscularQual,
    this.cirurgiaRecente,
    this.cirurgiaRecenteDeQue,
    this.usaMedicamento,
    this.usaMedicamentoQual,
    this.usoSubstancias = const [],
    this.fazendoDieta,
    this.dietaPorContaPropria,
    this.dietaOrientacaoNutricionista,
    this.respondidoEm,
  });

  final int? diasPorSemana; // 01
  final ObjetivoTreino? objetivo; // 02
  final SituacaoMusculacao? situacaoMusculacao; // 03
  final String? tempoParadoMusculacao; // 03 (se nao/nunca fez)
  final bool? problemaColunaJoelho; // 04
  final String? problemaColunaJoelhoQual;
  final NivelPressaoArterial? pressaoArterial; // 05
  final List<String> condicoesClinicas; // 06
  final bool? alergia; // 07
  final String? alergiaQual;
  final bool? doresCorpo; // 08
  final String? doresCorpoQual;
  final bool? lesaoOsteoMuscular; // 09
  final String? lesaoOsteoMuscularQual;
  final bool? cirurgiaRecente; // 10
  final String? cirurgiaRecenteDeQue;
  final bool? usaMedicamento; // 11
  final String? usaMedicamentoQual;
  final List<String> usoSubstancias; // 12
  final bool? fazendoDieta; // 13
  final bool? dietaPorContaPropria;
  final bool? dietaOrientacaoNutricionista;
  final DateTime? respondidoEm;

  factory Anamnese.fromFirestore(Map<String, dynamic> data) {
    final respondido = data['respondidoEm'];
    return Anamnese(
      diasPorSemana: (data['diasPorSemana'] as num?)?.toInt(),
      objetivo: _enumOrNull(ObjetivoTreino.values, data['objetivo']),
      situacaoMusculacao: _enumOrNull(
        SituacaoMusculacao.values,
        data['situacaoMusculacao'],
      ),
      tempoParadoMusculacao: data['tempoParadoMusculacao'] as String?,
      problemaColunaJoelho: data['problemaColunaJoelho'] as bool?,
      problemaColunaJoelhoQual: data['problemaColunaJoelhoQual'] as String?,
      pressaoArterial: _enumOrNull(
        NivelPressaoArterial.values,
        data['pressaoArterial'],
      ),
      condicoesClinicas: List<String>.from(data['condicoesClinicas'] ?? const []),
      alergia: data['alergia'] as bool?,
      alergiaQual: data['alergiaQual'] as String?,
      doresCorpo: data['doresCorpo'] as bool?,
      doresCorpoQual: data['doresCorpoQual'] as String?,
      lesaoOsteoMuscular: data['lesaoOsteoMuscular'] as bool?,
      lesaoOsteoMuscularQual: data['lesaoOsteoMuscularQual'] as String?,
      cirurgiaRecente: data['cirurgiaRecente'] as bool?,
      cirurgiaRecenteDeQue: data['cirurgiaRecenteDeQue'] as String?,
      usaMedicamento: data['usaMedicamento'] as bool?,
      usaMedicamentoQual: data['usaMedicamentoQual'] as String?,
      usoSubstancias: List<String>.from(data['usoSubstancias'] ?? const []),
      fazendoDieta: data['fazendoDieta'] as bool?,
      dietaPorContaPropria: data['dietaPorContaPropria'] as bool?,
      dietaOrientacaoNutricionista: data['dietaOrientacaoNutricionista'] as bool?,
      respondidoEm: respondido is Timestamp ? respondido.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'diasPorSemana': diasPorSemana,
      'objetivo': objetivo?.name,
      'situacaoMusculacao': situacaoMusculacao?.name,
      'tempoParadoMusculacao': tempoParadoMusculacao,
      'problemaColunaJoelho': problemaColunaJoelho,
      'problemaColunaJoelhoQual': problemaColunaJoelhoQual,
      'pressaoArterial': pressaoArterial?.name,
      'condicoesClinicas': condicoesClinicas,
      'alergia': alergia,
      'alergiaQual': alergiaQual,
      'doresCorpo': doresCorpo,
      'doresCorpoQual': doresCorpoQual,
      'lesaoOsteoMuscular': lesaoOsteoMuscular,
      'lesaoOsteoMuscularQual': lesaoOsteoMuscularQual,
      'cirurgiaRecente': cirurgiaRecente,
      'cirurgiaRecenteDeQue': cirurgiaRecenteDeQue,
      'usaMedicamento': usaMedicamento,
      'usaMedicamentoQual': usaMedicamentoQual,
      'usoSubstancias': usoSubstancias,
      'fazendoDieta': fazendoDieta,
      'dietaPorContaPropria': dietaPorContaPropria,
      'dietaOrientacaoNutricionista': dietaOrientacaoNutricionista,
      'respondidoEm': FieldValue.serverTimestamp(),
    };
  }

  static T? _enumOrNull<T extends Enum>(List<T> values, dynamic name) {
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
