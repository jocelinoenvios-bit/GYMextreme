/// Endereco do aluno, embutido no documento `alunos/{uid}` (campo
/// `endereco`) — mesmo padrao de objeto aninhado ja usado por
/// `Anamnese`/`TermoAceite`.
class Endereco {
  const Endereco({
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.uf,
  });

  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? uf;

  static const vazio = Endereco();

  bool get estaPreenchido =>
      [
        cep,
        logradouro,
        numero,
        complemento,
        bairro,
        cidade,
        uf,
      ].any((campo) => campo != null && campo.trim().isNotEmpty);

  factory Endereco.fromFirestore(Map<String, dynamic> data) {
    return Endereco(
      cep: data['cep'] as String?,
      logradouro: data['logradouro'] as String?,
      numero: data['numero'] as String?,
      complemento: data['complemento'] as String?,
      bairro: data['bairro'] as String?,
      cidade: data['cidade'] as String?,
      uf: data['uf'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'cep': cep,
      'logradouro': logradouro,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'uf': uf,
    };
  }
}
