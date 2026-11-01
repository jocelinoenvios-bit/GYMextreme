/// Tradução PT-BR de texto livre da Biblioteca Oficial (nome do exercício
/// e passo a passo) — carregada de `assets/exercicios/traducoes_pt.json`
/// por `LocalExerciseRepository`. Separada do arquivo original de
/// propósito: o dataset da ExerciseDB pode ser atualizado/re-importado
/// sem apagar a tradução, e a tradução evolui (mais frases cobertas) sem
/// tocar no dataset.
///
/// [instrucoes] é indexado pela frase original em **inglês** (não pelo
/// id do exercício) porque as mesmas instruções se repetem em muitos
/// exercícios (ex.: "Repeat for the desired number of repetitions.") —
/// traduzir a frase uma vez cobre todos os exercícios que a usam.
class TraducoesBiblioteca {
  const TraducoesBiblioteca({required this.nomes, required this.instrucoes});

  /// id do exercício -> nome em português.
  final Map<String, String> nomes;

  /// frase original em inglês -> frase em português.
  final Map<String, String> instrucoes;

  static const vazio = TraducoesBiblioteca(nomes: {}, instrucoes: {});

  factory TraducoesBiblioteca.fromJson(Map<String, dynamic> json) {
    return TraducoesBiblioteca(
      nomes: Map<String, String>.from(json['nomes'] as Map? ?? const {}),
      instrucoes: Map<String, String>.from(json['instrucoes'] as Map? ?? const {}),
    );
  }
}

/// Um exercício relacionado (similar, substituição, progressão ou
/// regressão) — a ExerciseDB já vem com o relacionamento calculado
/// (`score`/`confianca`), a app só precisa exibir, nunca recalcular.
class ExercicioRelacionado {
  const ExercicioRelacionado({
    required this.id,
    required this.nome,
    required this.score,
    required this.confianca,
    this.tipos = const [],
  });

  final String id;
  final String nome;

  /// Relevância do relacionamento (0–100), já calculada pelo fornecedor —
  /// usar pra ordenar, não pra recalcular.
  final double score;

  /// "high" ou "medium" — dá pra esconder relações de confiança baixa se
  /// a lista ficar longa demais.
  final String confianca;

  /// Vazio em "similares"; populado em substituição/progressão/regressão
  /// (ex.: "same_equipment_alternative", "higher_difficulty",
  /// "more_assisted").
  final List<String> tipos;

  factory ExercicioRelacionado.fromExerciseDbJson(Map<String, dynamic> json) {
    return ExercicioRelacionado(
      id: json['id'] as String,
      nome: json['name'] as String,
      score: (json['score'] as num).toDouble(),
      confianca: json['confidence'] as String,
      tipos: (json['types'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

/// Tudo que a tela de execução do exercício (Área do Aluno) precisa pra
/// ensinar o movimento — desacoplado da fonte de dados por design (ver
/// `ExerciseRepository`).
///
/// Mapeia campo a campo a Biblioteca Oficial de Exercícios (ExerciseDB
/// Mobile) licenciada, que passou a ser a fonte principal do catálogo de
/// exercícios do GymExtreme. Preserva o `id` original do fornecedor (não
/// gera um novo) — é o que mantém intactos os 18 mil relacionamentos
/// (similares/substituições/progressões/regressões) que já vêm prontos
/// no arquivo.
class ExerciseModel {
  const ExerciseModel({
    required this.id,
    required this.nome,
    this.nomeLocalizado,
    required this.bodyPart,
    required this.equipmentCategory,
    required this.equipamentoTexto,
    required this.dificuldade,
    required this.categoria,
    required this.movementFamily,
    this.taxonomiaBruta = const {},
    this.musculosPrincipais = const [],
    this.musculosAuxiliares = const [],
    this.passoAPasso = const [],
    this.passoAPassoLocalizado,
    this.descricao,
    this.gif180Url,
    this.gif360Url,
    this.videoUrl,
    this.similares = const [],
    this.substituicoes = const [],
    this.progressoes = const [],
    this.regressoes = const [],
    this.respiracao,
    this.amplitude,
    this.errosComuns = const [],
    this.cuidados,
    this.ajusteMaquina,
  });

  /// Id original da Biblioteca Oficial (ex.: "0001") — nunca gerado pelo
  /// GymExtreme. É o valor que `TreinoExercicio.exercicioId` vai
  /// referenciar no Firestore.
  final String id;

  final String nome;

  /// Tradução pra português — nula até a tradução acontecer (ver Plano
  /// Mestre da Biblioteca). A UI cai pro nome original em inglês
  /// enquanto isso.
  final String? nomeLocalizado;
  String get nomeExibicao => nomeLocalizado ?? nome;

  /// Parte do corpo, ampla (10 valores: "waist", "chest", "back"...) —
  /// vira o badge/filtro amplo que a tela já mostra.
  final String bodyPart;
  String get grupoMuscular => bodyPart;

  /// Categoria de equipamento limpa (6 valores: bodyweight, cable,
  /// machine, accessory, free_weight, band) — usar pra filtro; mais
  /// confiável que o texto livre de [equipamentoTexto].
  final String equipmentCategory;

  /// Texto de exibição do equipamento (ex.: "dumbbell, exercise ball") —
  /// pode ser composto, só pra leitura.
  final String equipamentoTexto;

  /// "beginner" | "intermediate" | "advanced".
  final String dificuldade;

  /// "strength" | "stretching" | "cardio" | "mobility" | "plyometrics" |
  /// "rehabilitation" | "balance".
  final String categoria;

  /// Família de movimento (ex.: "biceps curl", "squat") — motor interno
  /// do "exercícios parecidos"; não precisa ser traduzido pra exibição.
  final String movementFamily;

  /// O bloco `taxonomy` inteiro do arquivo original, sem perder nenhum
  /// subcampo — inclui os 15 valores que ainda não viraram propriedade
  /// própria (movementPattern, mechanic, forceType, planeOfMotion,
  /// laterality, bodyPosition, benchAngle, loadType, primaryRegion,
  /// isCompound, isUnilateral, isAssisted, isWeighted, signals,
  /// confidence). Reservados pra uso futuro (ex.: lógica de
  /// periodização na Área do Personal) — em vez de descartá-los ou
  /// promover 15 campos que nada usa ainda, ficam disponíveis aqui.
  final Map<String, dynamic> taxonomiaBruta;

  /// = `target` no arquivo original — músculo principal trabalhado.
  final List<String> musculosPrincipais;

  /// = `secondaryMuscles` no arquivo original.
  final List<String> musculosAuxiliares;

  /// = `instructions` no arquivo original — passo a passo da execução,
  /// sempre em inglês (fonte original, nunca traduzida em memória).
  final List<String> passoAPasso;

  /// [passoAPasso] traduzido linha a linha — só populado por quem carrega
  /// a `TraducoesBiblioteca` (ver `LocalExerciseRepository`). Cada linha
  /// cai pro original em inglês se aquela frase especifica ainda não
  /// tiver tradução (tradução incremental nunca deixa a tela com um
  /// buraco ou mistura estranha de idioma a nível de frase inteira).
  final List<String>? passoAPassoLocalizado;

  /// O que a UI deve exibir — traduzido quando disponível, senão o
  /// original em inglês. Mesmo padrão de [nomeExibicao].
  List<String> get passoAPassoExibicao => passoAPassoLocalizado ?? passoAPasso;

  /// = `description` no arquivo original — reservado; não faz parte da
  /// tela de execução aprovada hoje.
  final String? descricao;

  /// Variante 180° do loop — nunca hospedada no Firebase Storage a
  /// partir da Fase 2 (hospedar as duas variantes dobraria
  /// armazenamento/banda sem necessidade; só [gif360Url] cobre tanto a
  /// lista quanto o fullscreen). Por isso este campo fica sempre nulo
  /// pros exercícios da ExerciseDB — mantido (em vez de removido) só
  /// pra não quebrar quem já desestrutura o construtor.
  final String? gif180Url;

  /// Loop de demonstração do exercício (ExerciseDB), na única variante
  /// hospedada — caminho resolvido a partir do [id] (ver
  /// `LocalExerciseRepository`/`gif360PathPara`), nomenclatura oficial
  /// da ExerciseDB, sem renomeação. A partir da Fase 2 (Firebase
  /// Storage + cache), este é um caminho do Storage
  /// (`exercicios/gifs/{id}.gif`), não mais um asset embutido no APK —
  /// resolvido sob demanda por `GifCacheService` (ver `ExercicioMidia`),
  /// nunca lido diretamente como `AssetImage`. A única exceção é um
  /// caminho começando com `assets/` (usado por fixtures de teste que
  /// montam o objeto na mão): esse prefixo é tratado como um asset
  /// local de verdade, sem tocar rede — é assim que os testes
  /// existentes continuam funcionando sem depender do Firebase. Nulo
  /// para os exercícios que só têm vídeo (Vital Animations, sem GIF
  /// correspondente na ExerciseDB) — nesse caso [videoUrl] é a única
  /// mídia disponível.
  final String? gif360Url;

  /// Caminho local (asset) do vídeo de demonstração da Vital Animations,
  /// quando existir pra este exercício — mídia PRIMÁRIA (o GIF vira
  /// fallback automático, usado quando não há vídeo ou quando ele falha
  /// ao carregar). Nulo para a maioria dos exercícios, que só têm GIF.
  final String? videoUrl;

  bool get temVarianteAltaResolucao => gif360Url != null;
  bool get temVideoComplementar => videoUrl != null;

  final List<ExercicioRelacionado> similares;
  final List<ExercicioRelacionado> substituicoes;
  final List<ExercicioRelacionado> progressoes;
  final List<ExercicioRelacionado> regressoes;

  /// Curadoria opcional — a ExerciseDB não fornece estes campos. Ficam
  /// nulos/vazios até uma curadoria manual futura (armazenada à parte,
  /// nunca dentro do arquivo local da biblioteca). A tela de execução já
  /// esconde a seção correspondente quando o valor é nulo.
  final String? respiracao;
  final String? amplitude;
  final List<String> errosComuns;
  final String? cuidados;
  final String? ajusteMaquina;

  /// Constrói a partir de um registro bruto da Biblioteca Oficial
  /// (ExerciseDB Mobile) — nomes de campo iguais ao arquivo original
  /// (`bodyPart`, `target`, `secondaryMuscles`, `taxonomy.*` etc.). Sem
  /// dependências externas (só transforma dados), pra poder rodar dentro
  /// de um isolate via `compute()`.
  ///
  /// [traducoes] é opcional e vem de `traducoes_pt.json` (ver
  /// `TraducoesBiblioteca`/`LocalExerciseRepository`) — quando ausente
  /// (ex.: testes que montam o JSON bruto na mão), o exercício continua
  /// funcionando 100% em inglês, exatamente como antes desta tradução.
  ///
  /// [temGif] é `false` só para os exercícios novos da Vital Animations
  /// que não existem na ExerciseDB (sem GIF correspondente) — nesse
  /// caso [gif360Url] fica nulo em vez de apontar pra um asset que não
  /// existe ([gif180Url] fica sempre nulo, ver seu doc). [videosPorId] (ver
  /// `LocalExerciseRepository`) é o mapa id -> caminho do vídeo da
  /// Vital Animations; quando o [id] deste exercício está no mapa,
  /// popula [videoUrl].
  factory ExerciseModel.fromExerciseDbJson(
    Map<String, dynamic> json, {
    TraducoesBiblioteca? traducoes,
    bool temGif = true,
    Map<String, String>? videosPorId,
  }) {
    final id = json['id'] as String;
    final taxonomy = json['taxonomy'] as Map<String, dynamic>? ?? const {};
    final instrucoesOriginais =
        (json['instructions'] as List<dynamic>?)?.cast<String>() ?? const [];

    List<ExercicioRelacionado> relacionados(String campo) {
      final lista = json[campo] as List<dynamic>? ?? const [];
      return lista
          .map((item) => ExercicioRelacionado.fromExerciseDbJson(item as Map<String, dynamic>))
          .toList();
    }

    return ExerciseModel(
      id: id,
      nome: json['name'] as String,
      nomeLocalizado: traducoes?.nomes[id],
      bodyPart: json['bodyPart'] as String,
      equipmentCategory: taxonomy['equipmentCategory'] as String? ?? 'unknown',
      equipamentoTexto: json['equipment'] as String,
      dificuldade: json['difficulty'] as String,
      categoria: json['category'] as String,
      movementFamily: taxonomy['movementFamily'] as String? ?? '',
      taxonomiaBruta: taxonomy,
      musculosPrincipais: [json['target'] as String],
      musculosAuxiliares: (json['secondaryMuscles'] as List<dynamic>?)?.cast<String>() ?? const [],
      passoAPasso: instrucoesOriginais,
      passoAPassoLocalizado: traducoes == null
          ? null
          : [for (final linha in instrucoesOriginais) traducoes.instrucoes[linha] ?? linha],
      descricao: json['description'] as String?,
      gif180Url: null,
      gif360Url: temGif ? gif360PathPara(id) : null,
      videoUrl: videosPorId?[id],
      similares: relacionados('similarExercises'),
      substituicoes: relacionados('substitutions'),
      progressoes: relacionados('progressions'),
      regressoes: relacionados('regressions'),
    );
  }

  /// Convenção de caminho do GIF no Firebase Storage — nomenclatura
  /// oficial da ExerciseDB (o próprio `id`), sem renomeação. Só a
  /// variante 360° (maior resolução) é hospedada — hospedar as duas
  /// dobraria armazenamento/banda sem necessidade, já que a 360° cobre
  /// tanto a lista quanto o fullscreen. Centralizado aqui de propósito:
  /// é o único lugar a ajustar se a convenção de pasta mudar no futuro
  /// — e é exatamente o que `upload-gifs-storage.js` espelha do lado do
  /// upload.
  static String gif360PathPara(String id) => 'exercicios/gifs/$id.gif';
}

/// Um exercício prescrito dentro de uma sessão de execução — o par
/// "conteúdo didático" ([exercise], vem da Biblioteca Oficial) +
/// "prescrição" (séries/repetições/carga/descanso/observações, vem do
/// treino do personal — mesmo formato de `TreinoExercicio`, o domínio
/// real).
///
/// A tela de execução só conhece esta classe; quem a monta (resolvendo
/// `TreinoExercicio.exercicioId` via `ExerciseRepository.buscarPorId`)
/// fica fora da tela, o que preserva a separação entre onde a
/// prescrição é guardada (Firestore, por treino) e onde o conteúdo do
/// exercício vive (biblioteca local, por id).
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
