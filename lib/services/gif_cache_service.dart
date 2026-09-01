import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Tamanho máximo aceito ao baixar um GIF do Storage — folga generosa
/// sobre o maior arquivo real hoje (~1,4 MB na variante 360°); existe
/// só pra não deixar `getData` sem limite nenhum.
const _tamanhoMaximoGifBytes = 15 * 1024 * 1024;

/// Resolve a imagem de um GIF da Biblioteca Oficial pra exibição —
/// asset local (só usado por fixtures de teste, caminho começando com
/// `assets/`), cache local já baixado, ou baixa do Firebase Storage
/// agora e grava no cache pra próxima vez. Fica separado do
/// `StorageService` (foto de perfil) porque é um fluxo de leitura
/// pública com cache, não upload.
///
/// Implementações previstas:
/// - [FirebaseGifCacheService] (esta etapa) — Storage de verdade + cache
///   em disco via `path_provider`.
/// - `FakeGifCacheService` (`test/support/`) — dublê determinístico pra
///   teste, nunca toca rede nem disco de verdade.
abstract class GifCacheService {
  /// Resolve a imagem SEM NUNCA baixar da internet — asset local (ver
  /// acima) ou já cacheado. `null` = precisa baixar (chamar
  /// [resolverImagem]) ou não há nada disponível ainda. Uso: qualquer
  /// lugar que não deva iniciar download por conta própria (ex.: a
  /// miniatura da lista de exercícios, que não deve baixar 1.394 GIFs
  /// só por causa da rolagem — baixar é reservado pra quando o
  /// exercício é de fato aberto).
  ImageProvider? resolverImagemDoCache(String caminho);

  /// Mesma resolução de [resolverImagemDoCache], mas quando não
  /// encontra nada localmente baixa do Firebase Storage e grava no
  /// cache antes de devolver. `null` = sem internet, arquivo não existe
  /// no Storage, ou qualquer outra falha — quem chama trata como "mídia
  /// indisponível agora", nunca deixa a exceção propagar.
  Future<ImageProvider?> resolverImagem(String caminho);
}

/// Implementação real: Firebase Storage (bucket configurado em
/// `firebase_options.dart`) + cache em disco (diretório de cache do
/// app, apagável pelo SO sob pressão de armazenamento — mesma semântica
/// de "cache" que o resto do app espera, ver `getApplicationCacheDirectory`).
class FirebaseGifCacheService implements GifCacheService {
  FirebaseGifCacheService({FirebaseStorage? storage}) : _storageInjetado = storage;

  final FirebaseStorage? _storageInjetado;

  /// `FirebaseStorage.instance` só é acessado aqui — de forma
  /// preguiçosa, na primeira vez que algo realmente precisa baixar do
  /// Storage — nunca no construtor. Isso importa porque caminhos
  /// `assets/` (usados pelos testes, ver [resolverImagemDoCache]/
  /// [resolverImagem]) nunca chegam a tocar este getter: construir
  /// `FirebaseGifCacheService()` continua seguro mesmo sem o Firebase
  /// inicializado (ex.: ambiente de teste), desde que nenhum caminho
  /// não-`assets/` seja resolvido de verdade.
  FirebaseStorage get _storage => _storageInjetado ?? FirebaseStorage.instance;

  /// Memoiza o diretório de cache resolvido (chamada assíncrona da
  /// plataforma) — depois da primeira vez, [resolverImagemDoCache]
  /// consegue checar o disco de forma síncrona sem esperar o
  /// `path_provider` de novo.
  static Directory? _diretorioResolvido;

  @override
  ImageProvider? resolverImagemDoCache(String caminho) {
    if (caminho.startsWith('assets/')) return AssetImage(caminho);

    final diretorio = _diretorioResolvido;
    if (diretorio == null) return null;

    final arquivo = _arquivoDeCache(diretorio, caminho);
    return arquivo.existsSync() ? FileImage(arquivo) : null;
  }

  @override
  Future<ImageProvider?> resolverImagem(String caminho) async {
    if (caminho.startsWith('assets/')) return AssetImage(caminho);

    try {
      final diretorio = _diretorioResolvido ??= await getApplicationCacheDirectory();
      final arquivo = _arquivoDeCache(diretorio, caminho);
      if (await arquivo.exists()) return FileImage(arquivo);

      final bytes = await _storage.ref(caminho).getData(_tamanhoMaximoGifBytes);
      if (bytes == null) return null;

      await arquivo.create(recursive: true);
      await arquivo.writeAsBytes(bytes);
      return FileImage(arquivo);
    } catch (_) {
      // Sem internet, arquivo ausente no Storage, timeout, permissão —
      // qualquer falha vira "indisponível agora", nunca propaga.
      return null;
    }
  }

  File _arquivoDeCache(Directory diretorio, String caminho) {
    final nomeArquivo = caminho.replaceAll('/', '_');
    return File('${diretorio.path}/gifs_biblioteca/$nomeArquivo');
  }
}
