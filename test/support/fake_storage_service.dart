import 'dart:typed_data';

import 'package:gymextreme_app/services/storage_service.dart';

/// Dublê de teste do [StorageService] — nunca toca o Firebase Storage de
/// verdade, só devolve um endereço fixo e guarda o último upload pra inspeção.
class FakeStorageService implements StorageService {
  String? uidDoUltimoUpload;
  Uint8List? bytesDoUltimoUpload;

  /// Quando preenchido, [enviarFotoAluno] falha com este erro.
  Object? erroAoEnviar;

  @override
  Future<String> enviarFotoAluno(String uid, Uint8List bytes) async {
    if (erroAoEnviar != null) throw erroAoEnviar!;
    uidDoUltimoUpload = uid;
    bytesDoUltimoUpload = bytes;
    return 'https://exemplo.com/alunos/$uid/foto.jpg';
  }
}
