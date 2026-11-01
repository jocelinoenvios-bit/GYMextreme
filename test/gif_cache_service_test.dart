import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/services/gif_cache_service.dart';

/// Cobre só a parte de [FirebaseGifCacheService] que dá pra testar sem
/// Firebase de verdade nem disco real: o desvio pra asset local (usado
/// pelos fixtures de teste do resto do app) nunca toca
/// `FirebaseStorage.instance` nem `path_provider` — é o que permite
/// construir `FirebaseGifCacheService()` (o padrão de
/// `ExercicioMidia`/`ExerciciosListScreen` quando nada é injetado) num
/// ambiente de teste sem `Firebase.initializeApp()`, sem lançar
/// exceção. O download real do Storage é coberto indiretamente pelos
/// testes de `ExercicioMidia` com `FakeGifCacheService`
/// (vital_animations_test.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseGifCacheService', () {
    test('construir a instância não toca Firebase nem path_provider (lazy)', () {
      // Se isso lançasse, seria porque o construtor tentou acessar
      // FirebaseStorage.instance sem Firebase.initializeApp() — exatamente
      // o bug que quebraria todo widget test do app depois da Fase 2.
      expect(() => FirebaseGifCacheService(), returnsNormally);
    });

    test('resolverImagemDoCache com caminho assets/ devolve AssetImage direto, sem tocar disco', () {
      final service = FirebaseGifCacheService();
      final imagem = service.resolverImagemDoCache('assets/exercicios/gifs/0001.gif');

      expect(imagem, isA<AssetImage>());
      expect((imagem as AssetImage).assetName, 'assets/exercicios/gifs/0001.gif');
    });

    test(
      'resolverImagemDoCache com caminho do Storage (sem cache resolvido ainda) devolve null, sem lançar',
      () {
        final service = FirebaseGifCacheService();
        expect(service.resolverImagemDoCache('exercicios/gifs_360/0577.gif'), isNull);
      },
    );

    test('resolverImagem com caminho assets/ devolve AssetImage direto, sem tocar o Storage', () async {
      final service = FirebaseGifCacheService();
      final imagem = await service.resolverImagem('assets/exercicios/gifs_360/0577.gif');

      expect(imagem, isA<AssetImage>());
      expect((imagem as AssetImage).assetName, 'assets/exercicios/gifs_360/0577.gif');
    });
  });
}
