import 'package:cloud_firestore/cloud_firestore.dart';

import 'endereco.dart';
import '../utils/idade.dart';

/// Sexo informado no cadastro (ficha em papel, campo "SEXO").
enum Sexo {
  masculino('Masculino'),
  feminino('Feminino'),
  outro('Outro');

  const Sexo(this.label);

  final String label;
}

Sexo? _sexoOrNull(dynamic name) {
  if (name is! String) return null;
  for (final sexo in Sexo.values) {
    if (sexo.name == name) return sexo;
  }
  return null;
}

/// Dados de cadastro do aluno na academia (colecao `alunos`, documento com
/// o mesmo id do usuario/uid). Complementa o perfil basico de
/// `usuarios/{uid}` (nome, e-mail, role) com os campos especificos da
/// ficha em papel: dados pessoais, contato, endereco, contato de
/// emergencia e o vinculo com a academia (inicio, vencimento).
class Aluno {
  const Aluno({
    required this.uid,
    this.sexo,
    this.dataNascimento,
    this.idadeInformada,
    this.fotoUrl,
    this.cpf,
    this.rg,
    this.telefone,
    this.whatsapp,
    this.endereco = Endereco.vazio,
    this.contatoEmergenciaNome,
    this.contatoEmergenciaTelefone,
    this.observacoes,
    this.dataInicio,
    this.diaVencimento,
    this.cadastradoPorUid,
    this.cadastradoPorNome,
  });

  final String uid;
  final Sexo? sexo;
  final DateTime? dataNascimento;

  /// Idade digitada manualmente — só existe em cadastros antigos, feitos
  /// antes do campo `dataNascimento` existir. Prefira sempre [idade].
  final int? idadeInformada;

  final String? fotoUrl;
  final String? cpf;
  final String? rg;
  final String? telefone;
  final String? whatsapp;
  final Endereco endereco;
  final String? contatoEmergenciaNome;
  final String? contatoEmergenciaTelefone;
  final String? observacoes;

  final DateTime? dataInicio;

  /// Dia do mes (1-31) em que a mensalidade vence ("DIA PAGO" na ficha).
  final int? diaVencimento;

  /// Auditoria: qual funcionario cadastrou este aluno.
  final String? cadastradoPorUid;
  final String? cadastradoPorNome;

  /// Idade calculada a partir de [dataNascimento]; cai para
  /// [idadeInformada] em cadastros antigos que ainda não têm data de
  /// nascimento preenchida.
  int? get idade => calcularIdade(dataNascimento) ?? idadeInformada;

  factory Aluno.fromFirestore(String uid, Map<String, dynamic> data) {
    final inicio = data['dataInicio'];
    final nascimento = data['dataNascimento'];
    final enderecoData = data['endereco'];
    return Aluno(
      uid: uid,
      sexo: _sexoOrNull(data['sexo']),
      dataNascimento: nascimento is Timestamp ? nascimento.toDate() : null,
      idadeInformada: (data['idade'] as num?)?.toInt(),
      fotoUrl: data['fotoUrl'] as String?,
      cpf: data['cpf'] as String?,
      rg: data['rg'] as String?,
      telefone: data['telefone'] as String?,
      whatsapp: data['whatsapp'] as String?,
      endereco: enderecoData is Map
          ? Endereco.fromFirestore(Map<String, dynamic>.from(enderecoData))
          : Endereco.vazio,
      contatoEmergenciaNome: data['contatoEmergenciaNome'] as String?,
      contatoEmergenciaTelefone: data['contatoEmergenciaTelefone'] as String?,
      observacoes: data['observacoes'] as String?,
      dataInicio: inicio is Timestamp ? inicio.toDate() : null,
      diaVencimento: (data['diaVencimento'] as num?)?.toInt(),
      cadastradoPorUid: data['cadastradoPorUid'] as String?,
      cadastradoPorNome: data['cadastradoPorNome'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sexo': sexo?.name,
      'dataNascimento': dataNascimento != null
          ? Timestamp.fromDate(dataNascimento!)
          : null,
      'idade': idadeInformada,
      'fotoUrl': fotoUrl,
      'cpf': cpf,
      'rg': rg,
      'telefone': telefone,
      'whatsapp': whatsapp,
      'endereco': endereco.toFirestore(),
      'contatoEmergenciaNome': contatoEmergenciaNome,
      'contatoEmergenciaTelefone': contatoEmergenciaTelefone,
      'observacoes': observacoes,
      'dataInicio': dataInicio != null ? Timestamp.fromDate(dataInicio!) : null,
      'diaVencimento': diaVencimento,
      if (cadastradoPorUid != null) 'cadastradoPorUid': cadastradoPorUid,
      if (cadastradoPorNome != null) 'cadastradoPorNome': cadastradoPorNome,
    };
  }

  Aluno copyWith({
    Sexo? sexo,
    DateTime? dataNascimento,
    int? idadeInformada,
    String? fotoUrl,
    String? cpf,
    String? rg,
    String? telefone,
    String? whatsapp,
    Endereco? endereco,
    String? contatoEmergenciaNome,
    String? contatoEmergenciaTelefone,
    String? observacoes,
    DateTime? dataInicio,
    int? diaVencimento,
    String? cadastradoPorUid,
    String? cadastradoPorNome,
  }) {
    return Aluno(
      uid: uid,
      sexo: sexo ?? this.sexo,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      idadeInformada: idadeInformada ?? this.idadeInformada,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      cpf: cpf ?? this.cpf,
      rg: rg ?? this.rg,
      telefone: telefone ?? this.telefone,
      whatsapp: whatsapp ?? this.whatsapp,
      endereco: endereco ?? this.endereco,
      contatoEmergenciaNome: contatoEmergenciaNome ?? this.contatoEmergenciaNome,
      contatoEmergenciaTelefone:
          contatoEmergenciaTelefone ?? this.contatoEmergenciaTelefone,
      observacoes: observacoes ?? this.observacoes,
      dataInicio: dataInicio ?? this.dataInicio,
      diaVencimento: diaVencimento ?? this.diaVencimento,
      cadastradoPorUid: cadastradoPorUid ?? this.cadastradoPorUid,
      cadastradoPorNome: cadastradoPorNome ?? this.cadastradoPorNome,
    );
  }
}
