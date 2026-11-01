import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/storage_service.dart';

/// A imagem certa pra um `Aluno.fotoUrl`: foto guardada no Firestore
/// ([FotoFirestoreImage]) ou, pra fotos antigas, o endereço da internet.
ImageProvider? imagemDaFotoAluno(String? fotoUrl) {
  if (fotoUrl == null || fotoUrl.isEmpty) return null;
  final uid = uidDaFotoNoFirestore(fotoUrl);
  if (uid != null) return FotoFirestoreImage(uid: uid, fotoUrl: fotoUrl);
  return NetworkImage(fotoUrl);
}

/// Carrega a foto do aluno de `fotosAlunos/{uid}` (ver [StorageService]).
/// Igualdade pelo [fotoUrl] inteiro (que leva a versão), então trocar a
/// foto invalida o cache de imagens sozinho.
@immutable
class FotoFirestoreImage extends ImageProvider<FotoFirestoreImage> {
  const FotoFirestoreImage({
    required this.uid,
    required this.fotoUrl,
    this.firestore,
  });

  final String uid;
  final String fotoUrl;
  final FirebaseFirestore? firestore;

  @override
  Future<FotoFirestoreImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FotoFirestoreImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    FotoFirestoreImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _carregar(decode),
      scale: 1,
      debugLabel: fotoUrl,
    );
  }

  Future<ui.Codec> _carregar(ImageDecoderCallback decode) async {
    final doc = await (firestore ?? FirebaseFirestore.instance)
        .collection('fotosAlunos')
        .doc(uid)
        .get();
    final imagem = doc.data()?['imagem'];
    if (imagem is! Blob) {
      throw StateError('Foto do aluno $uid não encontrada.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(imagem.bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is FotoFirestoreImage && other.fotoUrl == fotoUrl;

  @override
  int get hashCode => fotoUrl.hashCode;

  @override
  String toString() => 'FotoFirestoreImage($fotoUrl)';
}
