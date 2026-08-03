/// Tudo que a tela de execução do exercício (Área do Aluno) precisa pra
/// ensinar o movimento — desacoplado de propósito da fonte real de dados.
///
/// Hoje a Biblioteca de Exercícios do app é `Exercicio`
/// (`lib/models/exercicio.dart`, alimentada por `exercicios` no
/// Firestore), mas ela não tem ainda a maior parte destes campos
/// (respiração, amplitude, erros comuns, cuidados, ajuste de máquina,
/// ângulo alternativo). Em vez de forçar a tela a ler `Exercicio`
/// incompleto agora, ela consome só `ExerciseModel` — quando a Biblioteca
/// oficial (ou uma API externa) tiver esses dados, basta uma nova
/// implementação de [ExerciseRepository] (ver exercise_repository.dart)
/// que converte a fonte real pra este mesmo modelo. A interface não muda.
class ExerciseModel {
  const ExerciseModel({
    required this.id,
    required this.nome,
    required this.grupoMuscular,
    required this.gifUrl,
    this.gifUrlLateral,
    this.videoUrl,
    this.musculosPrincipais = const [],
    this.musculosAuxiliares = const [],
    this.passoAPasso = const [],
    this.respiracao,
    this.amplitude,
    this.errosComuns = const [],
    this.cuidados,
    this.ajusteMaquina,
  });

  final String id;
  final String nome;
  final String grupoMuscular;

  /// Loop 3D em destaque (ângulo padrão/frontal) — o elemento dominante
  /// da tela. Nos dados mock, aponta pra um asset que não existe de
  /// verdade; a UI trata qualquer carregamento como "pré-visualização".
  final String gifUrl;

  /// Ângulo alternativo (lateral), quando a biblioteca tiver mais de um.
  /// Nulo = a tela simplesmente não mostra o seletor de ângulo.
  final String? gifUrlLateral;

  /// Vídeo completo, só como conteúdo complementar — nunca substitui o
  /// loop como demonstração principal.
  final String? videoUrl;

  final List<String> musculosPrincipais;
  final List<String> musculosAuxiliares;
  final List<String> passoAPasso;
  final String? respiracao;
  final String? amplitude;
  final List<String> errosComuns;
  final String? cuidados;

  /// Como ajustar banco/altura/apoio antes de começar — nulo em
  /// exercícios sem máquina (ex.: peso livre no chão).
  final String? ajusteMaquina;

  bool get temAnguloLateral => gifUrlLateral != null;
  bool get temVideoComplementar => videoUrl != null;
}

/// Um exercício prescrito dentro de uma sessão de execução — o par
/// "conteúdo didático" ([exercise], vem da Biblioteca) + "prescrição"
/// (séries/repetições/carga/descanso, vem do treino do personal,
/// `TreinoExercicio` no domínio real).
///
/// Assim como [ExerciseModel], é preenchido com dados mock por enquanto;
/// a tela nunca lê `Treino`/`TreinoExercicio` diretamente.
class ExercisePrescription {
  const ExercisePrescription({
    required this.exercise,
    required this.series,
    required this.repeticoes,
    this.cargaKg,
    this.descansoSegundos = 60,
    this.observacoesPersonal,
  });

  final ExerciseModel exercise;
  final int series;

  /// Texto livre ("8-12", "até a falha"), igual ao campo real de
  /// `TreinoExercicio.repeticoes`.
  final String repeticoes;

  final double? cargaKg;
  final int descansoSegundos;

  /// Observação do personal específica pra este exercício, dentro deste
  /// treino — distinta do conteúdo genérico de [exercise], que vale pra
  /// qualquer aluno que fizer esse exercício.
  final String? observacoesPersonal;
}
