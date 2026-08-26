import 'dart:typed_data';

import 'package:gymextreme_app/services/storage_service.dart';

/// Dublê de teste do [StorageService] — nunca toca o Firebase Storage de
/// verdade, só devolve uma URL fixa e guarda o último upload pra inspeção.
class FakeStorageService implements StorageService {
  String? uidDoUltimoUpload;
  Uint8List? bytesDoUltimoUpload;

  @override
  Future<String> enviarFotoAluno(String uid, Uint8List bytes) async {
    uidDoUltimoUpload = uid;
    bytesDoUltimoUpload = bytes;
    return 'https://exemplo.com/alunos/$uid/foto.jpg';
  }
}
