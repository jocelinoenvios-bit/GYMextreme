import 'package:flutter/material.dart';
import 'package:gymextreme_app/services/gif_cache_service.dart';

/// Dublê de teste do [GifCacheService] — nunca toca o Firebase Storage
/// nem o disco de verdade. Cada teste configura [doCache]/[doDownload]
/// (ou [erroNoDownload]) pra simular exatamente o cenário que quer
/// exercitar, e inspeciona [caminhosPedidosNoCache]/
/// [caminhosBaixados] pra confirmar o que foi (ou não) chamado.
class FakeGifCacheService implements GifCacheService {
  /// Imagem que [resolverImagemDoCache] devolve pra cada caminho — um
  /// caminho ausente daqui simula "não está no cache".
  final Map<String, ImageProvider> doCache = {};

  /// Imagem que [resolverImagem] devolve (depois de simular o download)
  /// pra cada caminho — um caminho ausente daqui, sem estar em [doCache]
  /// nem em [erroNoDownload], simula "Storage também não tem".
  final Map<String, ImageProvider> doDownload = {};

  /// Caminhos que devem fazer [resolverImagem] devolver `null` (mesmo
  /// contrato de "falha silenciosa" da implementação real: sem
  /// internet, arquivo ausente, timeout etc. — tudo vira null).
  final Set<String> erroNoDownload = {};

  final List<String> caminhosPedidosNoCache = [];
  final List<String> caminhosBaixados = [];

  @override
  ImageProvider? resolverImagemDoCache(String caminho) {
    caminhosPedidosNoCache.add(caminho);
    if (caminho.startsWith('assets/')) return AssetImage(caminho);
    return doCache[caminho];
  }

  @override
  Future<ImageProvider?> resolverImagem(String caminho) async {
    caminhosBaixados.add(caminho);
    if (caminho.startsWith('assets/')) return AssetImage(caminho);
    if (doCache.containsKey(caminho)) return doCache[caminho];
    if (erroNoDownload.contains(caminho)) return null;
    return doDownload[caminho];
  }
}
