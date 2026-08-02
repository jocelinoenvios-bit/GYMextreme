/// Um exercicio da colecao `exercicios`, alimentada pelo script
/// `importar-exercicios.js` (fora do app Flutter). O app so le esses
/// dados — cadastro/edicao continuam sendo feitos pelo script.
class Exercicio {
  const Exercicio({
    required this.id,
    required this.nome,
    required this.grupoMuscular,
    required this.alvo,
    required this.equipamento,
    this.nivel,
    this.instrucoes = const [],
    this.gifUrl,
  });

  final String id;
  final String nome;
  final String grupoMuscular;
  final String alvo;
  final String equipamento;
  final String? nivel;
  final List<String> instrucoes;
  final String? gifUrl;

  factory Exercicio.fromFirestore(String id, Map<String, dynamic> data) {
    return Exercicio(
      id: id,
      nome: data['nome'] as String? ?? 'Exercício sem nome',
      grupoMuscular: data['grupoMuscular'] as String? ?? '',
      alvo: data['alvo'] as String? ?? '',
      equipamento: data['equipamento'] as String? ?? '',
      nivel: data['nivel'] as String?,
      instrucoes: List<String>.from(data['instrucoes'] ?? const []),
      gifUrl: data['gifUrl'] as String?,
    );
  }
}
