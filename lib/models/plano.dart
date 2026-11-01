import 'package:cloud_firestore/cloud_firestore.dart';

/// Um plano de mensalidade cadastrado pela academia (coleção `planos`,
/// nível de academia — não pertence a nenhum aluno específico). Usado
/// como referência ao criar uma [Matricula]: o valor/duração contratados
/// ficam copiados na matrícula, então alterar um plano depois nunca muda
/// retroativamente o que já foi contratado.
class Plano {
  const Plano({
    this.id,
    required this.nome,
    this.descricao,
    required this.valor,
    required this.duracaoDias,
    this.ativo = true,
    this.excluido = false,
    this.criadoEm,
    this.atualizadoEm,
  });

  final String? id;
  final String nome;
  final String? descricao;
  final double valor;

  /// Duração de uma matrícula deste plano, em dias corridos (ex.: 30 =
  /// mensal, 90 = trimestral, 365 = anual).
  final int duracaoDias;

  /// Planos antigos ficam com `ativo = false` em vez de apagados — matrículas
  /// já contratadas continuam referenciando o plano original normalmente.
  final bool ativo;

  /// Excluído pelo botão de lixeira: some de todas as listas, mas o
  /// documento fica (matrículas antigas ainda apontam pra ele). Diferente
  /// de "inativo" ([ativo] false, chave "Plano ativo"), que continua na
  /// lista de Planos e pode ser reativado.
  final bool excluido;

  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  factory Plano.fromFirestore(String id, Map<String, dynamic> data) {
    final criadoEm = data['criadoEm'];
    final atualizadoEm = data['atualizadoEm'];
    return Plano(
      id: id,
      nome: data['nome'] as String? ?? 'Plano',
      descricao: data['descricao'] as String?,
      valor: (data['valor'] as num?)?.toDouble() ?? 0,
      duracaoDias: (data['duracaoDias'] as num?)?.toInt() ?? 30,
      ativo: data['ativo'] as bool? ?? true,
      excluido: data['excluido'] as bool? ?? false,
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
      atualizadoEm: atualizadoEm is Timestamp ? atualizadoEm.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'descricao': descricao,
      'valor': valor,
      'duracaoDias': duracaoDias,
      'ativo': ativo,
      'criadoEm': criadoEm != null
          ? Timestamp.fromDate(criadoEm!)
          : FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
  }

  Plano copyWith({
    String? nome,
    String? descricao,
    double? valor,
    int? duracaoDias,
    bool? ativo,
  }) {
    return Plano(
      id: id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      duracaoDias: duracaoDias ?? this.duracaoDias,
      ativo: ativo ?? this.ativo,
      excluido: excluido,
      criadoEm: criadoEm,
      atualizadoEm: atualizadoEm,
    );
  }
}
