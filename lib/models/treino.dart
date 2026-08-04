import 'package:cloud_firestore/cloud_firestore.dart';

/// Um exercicio dentro de uma ficha de treino — referencia um exercicio
/// da Biblioteca Oficial de Exercícios (asset local, ver
/// `ExerciseRepository`/`LocalExerciseRepository`) pelo mesmo `id` do
/// fornecedor, e nunca duplica nome/gif/instrucoes, so os parametros de
/// execucao.
class TreinoExercicio {
  const TreinoExercicio({
    required this.exercicioId,
    this.series,
    this.repeticoes,
    this.cargaKg,
    this.descansoSegundos,
    this.observacoes,
    required this.ordem,
  });

  final String exercicioId;
  final int? series;

  /// Texto livre ("8-12", "até a falha" etc.) — repeticoes nem sempre
  /// sao um numero fixo.
  final String? repeticoes;
  final double? cargaKg;
  final int? descansoSegundos;
  final String? observacoes;
  final int ordem;

  factory TreinoExercicio.fromFirestore(Map<String, dynamic> data) {
    return TreinoExercicio(
      exercicioId: data['exercicioId'] as String? ?? '',
      series: (data['series'] as num?)?.toInt(),
      repeticoes: data['repeticoes'] as String?,
      cargaKg: (data['cargaKg'] as num?)?.toDouble(),
      descansoSegundos: (data['descansoSegundos'] as num?)?.toInt(),
      observacoes: data['observacoes'] as String?,
      ordem: (data['ordem'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'exercicioId': exercicioId,
      'series': series,
      'repeticoes': repeticoes,
      'cargaKg': cargaKg,
      'descansoSegundos': descansoSegundos,
      'observacoes': observacoes,
      'ordem': ordem,
    };
  }

  TreinoExercicio copyWith({
    int? series,
    String? repeticoes,
    double? cargaKg,
    int? descansoSegundos,
    String? observacoes,
    int? ordem,
  }) {
    return TreinoExercicio(
      exercicioId: exercicioId,
      series: series ?? this.series,
      repeticoes: repeticoes ?? this.repeticoes,
      cargaKg: cargaKg ?? this.cargaKg,
      descansoSegundos: descansoSegundos ?? this.descansoSegundos,
      observacoes: observacoes ?? this.observacoes,
      ordem: ordem ?? this.ordem,
    );
  }
}

/// Uma ficha de treino do aluno (colecao `alunos/{uid}/treinos`) — os
/// treinos "A", "B", "C"... que o personal monta. A lista de exercicios
/// fica embutida no proprio documento (poucos itens, sempre editados
/// junto com o treino).
class Treino {
  const Treino({
    this.id,
    required this.nome,
    required this.letra,
    this.grupoMuscular,
    this.ordem = 0,
    this.ativo = true,
    this.exercicios = const [],
    this.criadoPorUid,
    this.criadoPorNome,
    this.criadoEm,
    this.atualizadoPorUid,
    this.atualizadoPorNome,
    this.atualizadoEm,
  });

  final String? id;
  final String nome;

  /// "A", "B", "C", "D", "E" ou "F" — rotulo curto usado nos cards.
  final String letra;

  /// Foco do dia (ex.: "Peito e Tríceps"). Texto livre — um treino
  /// costuma combinar mais de um grupo muscular, entao nao usa a mesma
  /// taxonomia fixa da biblioteca de exercicios.
  final String? grupoMuscular;

  final int ordem;

  /// Treinos antigos ficam com `ativo = false` em vez de apagados, pra
  /// manter o historico do que o aluno ja treinou.
  final bool ativo;

  final List<TreinoExercicio> exercicios;

  final String? criadoPorUid;
  final String? criadoPorNome;
  final DateTime? criadoEm;
  final String? atualizadoPorUid;
  final String? atualizadoPorNome;
  final DateTime? atualizadoEm;

  factory Treino.fromFirestore(String id, Map<String, dynamic> data) {
    final criadoEm = data['criadoEm'];
    final atualizadoEm = data['atualizadoEm'];
    final exerciciosData = data['exercicios'] as List<dynamic>? ?? const [];
    return Treino(
      id: id,
      nome: data['nome'] as String? ?? 'Treino',
      letra: data['letra'] as String? ?? '',
      grupoMuscular: data['grupoMuscular'] as String?,
      ordem: (data['ordem'] as num?)?.toInt() ?? 0,
      ativo: data['ativo'] as bool? ?? true,
      exercicios: exerciciosData
          .map(
            (item) => TreinoExercicio.fromFirestore(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      criadoPorUid: data['criadoPorUid'] as String?,
      criadoPorNome: data['criadoPorNome'] as String?,
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
      atualizadoPorUid: data['atualizadoPorUid'] as String?,
      atualizadoPorNome: data['atualizadoPorNome'] as String?,
      atualizadoEm: atualizadoEm is Timestamp ? atualizadoEm.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'letra': letra,
      'grupoMuscular': grupoMuscular,
      'ordem': ordem,
      'ativo': ativo,
      'exercicios': exercicios.map((e) => e.toFirestore()).toList(),
      if (criadoPorUid != null) 'criadoPorUid': criadoPorUid,
      if (criadoPorNome != null) 'criadoPorNome': criadoPorNome,
      'criadoEm': criadoEm != null ? Timestamp.fromDate(criadoEm!) : FieldValue.serverTimestamp(),
      if (atualizadoPorUid != null) 'atualizadoPorUid': atualizadoPorUid,
      if (atualizadoPorNome != null) 'atualizadoPorNome': atualizadoPorNome,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
  }

  Treino copyWith({
    String? nome,
    String? letra,
    String? grupoMuscular,
    int? ordem,
    bool? ativo,
    List<TreinoExercicio>? exercicios,
  }) {
    return Treino(
      id: id,
      nome: nome ?? this.nome,
      letra: letra ?? this.letra,
      grupoMuscular: grupoMuscular ?? this.grupoMuscular,
      ordem: ordem ?? this.ordem,
      ativo: ativo ?? this.ativo,
      exercicios: exercicios ?? this.exercicios,
      criadoPorUid: criadoPorUid,
      criadoPorNome: criadoPorNome,
      criadoEm: criadoEm,
      atualizadoPorUid: atualizadoPorUid,
      atualizadoPorNome: atualizadoPorNome,
      atualizadoEm: atualizadoEm,
    );
  }
}
