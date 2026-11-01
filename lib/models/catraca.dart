/// Um leitor de acesso (iDFace) cadastrado no sistema — coleção
/// `dispositivosAcesso`, criada pelo comando `npm run catraca --
/// cadastrar-dispositivo` no computador da academia.
class DispositivoAcesso {
  const DispositivoAcesso({required this.id, required this.nome});

  final String id;
  final String nome;
}

/// "O código X do leitor Y é este aluno" — documento
/// `dispositivosAcesso/{deviceId}/credenciais/{codigo}`. É o que o porteiro
/// consulta pra saber quem o iDFace reconheceu.
class VinculoCatraca {
  const VinculoCatraca({required this.dispositivo, required this.codigo});

  final DispositivoAcesso dispositivo;
  final String codigo;
}

/// O que a ficha do aluno precisa mostrar na parte da catraca: os leitores
/// existentes e os códigos já vinculados a este aluno.
class CatracaDoAluno {
  const CatracaDoAluno({required this.dispositivos, required this.vinculos});

  final List<DispositivoAcesso> dispositivos;
  final List<VinculoCatraca> vinculos;
}

/// Código de usuário do iDFace: só números (é a numeração interna do
/// aparelho). Devolve a mensagem de erro, ou null se estiver ok.
String? validarCodigoCatraca(String? valor) {
  final codigo = (valor ?? '').trim();
  if (codigo.isEmpty) return 'Informe o código que o leitor deu ao aluno.';
  if (!RegExp(r'^\d{1,12}$').hasMatch(codigo)) return 'O código tem só números.';
  return null;
}
