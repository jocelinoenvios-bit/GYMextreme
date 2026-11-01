import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Guarda a foto de perfil do aluno.
///
/// A foto fica no próprio Firestore (coleção `fotosAlunos`, um documento
/// por aluno), e não no Firebase Storage: o projeto não tem Storage
/// ativado — em projetos novos ele exige o plano pago (Blaze), e a decisão
/// é não usar nada pago. A foto já chega pequena (ver [ladoMaximoFoto] /
/// [qualidadeFoto], aplicados na hora de escolher), cabendo com folga no
/// limite de 1 MB por documento e na cota gratuita.
///
/// O nome da classe ficou o mesmo pra não mexer em quem já a usa.
class StorageService {
  StorageService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Teto de tamanho da foto já comprimida (o documento aceita até 1 MB).
  static const tamanhoMaximoBytes = 700 * 1024;

  /// Grava a foto e devolve o "endereço" dela pra ir no `Aluno.fotoUrl`
  /// (ver [fotoUrlDoFirestore]). O `?v=` muda a cada envio, pra a tela não
  /// reaproveitar a foto antiga guardada em cache.
  Future<String> enviarFotoAluno(String uid, Uint8List bytes) async {
    if (bytes.length > tamanhoMaximoBytes) {
      throw StorageServiceException('Foto grande demais. Escolha outra foto.');
    }
    await _firestore.collection('fotosAlunos').doc(uid).set({
      'imagem': Blob(bytes),
      'tamanhoBytes': bytes.length,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
    return fotoUrlDoFirestore(uid, DateTime.now().millisecondsSinceEpoch);
  }
}

/// Lado máximo (px) e qualidade JPEG pedidos ao escolher a foto — deixa a
/// foto com algumas dezenas de KB, nítida no tamanho em que o app mostra.
const ladoMaximoFoto = 512.0;
const qualidadeFoto = 75;

/// Prefixo do `fotoUrl` de foto guardada no Firestore. Fotos antigas, com
/// endereço https, continuam abrindo pela internet normalmente.
const _prefixoFirestore = 'firestore://fotosAlunos/';

String fotoUrlDoFirestore(String uid, int versao) =>
    '$_prefixoFirestore$uid?v=$versao';

/// Uid do aluno se [fotoUrl] aponta pra uma foto no Firestore; senão null.
String? uidDaFotoNoFirestore(String? fotoUrl) {
  if (fotoUrl == null || !fotoUrl.startsWith(_prefixoFirestore)) return null;
  final resto = fotoUrl.substring(_prefixoFirestore.length);
  final fim = resto.indexOf('?');
  final uid = fim < 0 ? resto : resto.substring(0, fim);
  return uid.isEmpty ? null : uid;
}

/// Erro com mensagem pronta pra mostrar na tela.
class StorageServiceException implements Exception {
  StorageServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
