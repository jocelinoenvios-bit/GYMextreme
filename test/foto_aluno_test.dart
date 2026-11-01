import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/services/storage_service.dart';
import 'package:gymextreme_app/widgets/foto_aluno_image.dart';

void main() {
  test('endereço da foto no Firestore leva o uid e a versão', () {
    final url = fotoUrlDoFirestore('aluno-1', 123);
    expect(url, 'firestore://fotosAlunos/aluno-1?v=123');
    expect(uidDaFotoNoFirestore(url), 'aluno-1');
  });

  test('fotos antigas (https) e vazias não são do Firestore', () {
    expect(uidDaFotoNoFirestore('https://exemplo.com/foto.jpg'), isNull);
    expect(uidDaFotoNoFirestore(null), isNull);
    expect(uidDaFotoNoFirestore('firestore://fotosAlunos/'), isNull);
  });

  test('imagemDaFotoAluno escolhe Firestore ou internet', () {
    expect(imagemDaFotoAluno(null), isNull);
    expect(imagemDaFotoAluno(''), isNull);
    expect(imagemDaFotoAluno('https://exemplo.com/f.jpg'), isA<NetworkImage>());
    final foto = imagemDaFotoAluno(fotoUrlDoFirestore('aluno-1', 1));
    expect(foto, isA<FotoFirestoreImage>());
    expect((foto! as FotoFirestoreImage).uid, 'aluno-1');
  });

  test('trocar a foto muda a chave do cache de imagens', () {
    final antiga = imagemDaFotoAluno(fotoUrlDoFirestore('aluno-1', 1));
    final mesma = imagemDaFotoAluno(fotoUrlDoFirestore('aluno-1', 1));
    final nova = imagemDaFotoAluno(fotoUrlDoFirestore('aluno-1', 2));
    expect(antiga, mesma);
    expect(antiga, isNot(nova));
  });

  test('a foto escolhida já sai pequena', () {
    expect(ladoMaximoFoto, lessThanOrEqualTo(512));
    expect(qualidadeFoto, lessThanOrEqualTo(80));
    expect(StorageService.tamanhoMaximoBytes, lessThan(1024 * 1024));
  });
}
