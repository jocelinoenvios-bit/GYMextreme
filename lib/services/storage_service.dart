import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Upload de arquivos no Firebase Storage. Hoje so a foto de perfil do
/// aluno usa isso; fica separado do `AlunoService` (que so fala com o
/// Firestore) porque e um SDK diferente.
class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Envia a foto do aluno pra `alunos/{uid}/foto.jpg` e retorna a URL
  /// publica de download (sobrescreve a foto anterior, se existir).
  Future<String> enviarFotoAluno(String uid, Uint8List bytes) async {
    final ref = _storage.ref('alunos/$uid/foto.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
