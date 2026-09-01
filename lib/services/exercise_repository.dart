import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../models/exercise_model.dart';

/// Fonte de dados da Biblioteca de Exercícios. Toda a aplicação
/// consome só esta interface — nunca o Firestore, nem um arquivo local,
/// nem uma API, diretamente.
///
/// Implementações previstas:
/// - [LocalExerciseRepository] (esta etapa) — lê a Biblioteca Oficial
///   (ExerciseDB Mobile) empacotada como asset, 100% offline.
/// - `RemoteExerciseRepository` (futuro, não implementada ainda) — API
///   V2, vídeos MP4 e conteúdo adicional, só quando houver internet.
/// - `HybridExerciseRepository` (futuro, não implementada ainda) — usa
///   [LocalExerciseRepository] como fonte principal (funciona sempre,
///   mesmo offline) e enriquece o resultado com dados da API remota
///   quando disponível (ex.: preencher `ExerciseModel.videoUrl`) sem
///   nunca depender dela pra funcionar.
///
/// Trocar de implementação nunca exige mudar uma tela — é só decidir,
/// no lugar onde o repositório é construído, qual instância injetar.
abstract class ExerciseRepository {
  /// Um exercício pelo id da Biblioteca Oficial (o mesmo id que
  /// `TreinoExercicio.exercicioId` referencia no Firestore). `null` se
  /// não existir.
  Future<ExerciseModel?> buscarPorId(String id);

  /// Todo o catálogo — usado pelas telas de busca/navegação
  /// (Biblioteca de Exercícios, seletor ao montar treino).
  Future<List<ExerciseModel>> buscarTodos();
}

/// Lê a Biblioteca Oficial de Exercícios (ExerciseDB Mobile) empacotada
/// como asset do app — funciona 100% offline, como decidido. Mescla no
/// mesmo índice os exercícios novos da Vital Animations (vídeo como
/// mídia primária, sem GIF) e anexa vídeo aos exercícios já existentes
/// que também ganharam demonstração em vídeo — ver
/// [vitalAnimationsAssetPath]/[videosVitalAnimationsAssetPath].
///
/// O parse dos arquivos (o principal tem ~13 MB, ~1.400 exercícios)
/// roda uma única vez por processo, num isolate separado (via
/// `compute()`, pra não travar a UI), e fica memoizado a **nível de
/// classe** — não de instância. Assim, mesmo que várias telas
/// construam `LocalExerciseRepository()` por conveniência (é o valor
/// padrão), todas compartilham o mesmo índice em memória em vez de
/// reparsear os arquivos inteiros de novo.
class LocalExerciseRepository implements ExerciseRepository {
  const LocalExerciseRepository({
    this.assetPath = _assetPadrao,
    this.traducoesAssetPath = _traducoesPadrao,
    this.vitalAnimationsAssetPath = _vitalAnimationsPadrao,
    this.videosVitalAnimationsAssetPath = _videosVitalAnimationsPadrao,
  });

  static const _assetPadrao = 'assets/exercicios/biblioteca_exercicios.json';
  static const _traducoesPadrao = 'assets/exercicios/traducoes_pt.json';
  static const _vitalAnimationsPadrao = 'assets/exercicios/exercicios_vital_animations.json';
  static const _videosVitalAnimationsPadrao = 'assets/exercicios/videos_vital_animations.json';

  final String assetPath;

  /// Nome/instruções em PT-BR (ver `TraducoesBiblioteca`) — arquivo
  /// separado do dataset original, carregado à parte.
  final String traducoesAssetPath;

  /// Exercícios novos da Vital Animations que não existem na ExerciseDB
  /// (mesmo schema de [assetPath], ids fora da faixa 0001-5201 usada
  /// pela ExerciseDB pra nunca colidir) — mesclados no mesmo índice, sem
  /// GIF (só vídeo).
  final String vitalAnimationsAssetPath;

  /// Mapa id -> caminho do vídeo da Vital Animations (ver
  /// `exercicios_vital_animations.json` e os 6 exercícios já existentes
  /// que também ganharam vídeo) — usado pra popular
  /// `ExerciseModel.videoUrl` de qualquer exercício do índice, venha ele
  /// de [assetPath] ou de [vitalAnimationsAssetPath].
  final String videosVitalAnimationsAssetPath;

  static Future<Map<String, ExerciseModel>>? _indicePorId;

  Future<Map<String, ExerciseModel>> _indice() {
    return _indicePorId ??= _carregarEIndexar();
  }

  Future<Map<String, ExerciseModel>> _carregarEIndexar() async {
    final jsonString = await rootBundle.loadString(assetPath);
    final traducoesString = await rootBundle.loadString(traducoesAssetPath);
    final vitalAnimationsString = await rootBundle.loadString(vitalAnimationsAssetPath);
    final videosString = await rootBundle.loadString(videosVitalAnimationsAssetPath);
    // O decode do JSON (a parte cara, ~13 MB de texto) roda num isolate
    // separado — só objetos "transferíveis" (Map/List/primitivos)
    // atravessam essa fronteira; montar os ExerciseModel a partir deles
    // é rápido o bastante pra rodar na isolate principal sem travar UI.
    final bruto = await compute(_decodificarJson, jsonString);
    final brutoVitalAnimations = await compute(_decodificarJson, vitalAnimationsString);
    final traducoes = await compute(_decodificarTraducoes, traducoesString);
    final videosPorId = await compute(_decodificarVideos, videosString);
    return {
      for (final item in bruto)
        (item['id'] as String): ExerciseModel.fromExerciseDbJson(
          item,
          traducoes: traducoes,
          videosPorId: videosPorId,
        ),
      for (final item in brutoVitalAnimations)
        (item['id'] as String): ExerciseModel.fromExerciseDbJson(
          item,
          traducoes: traducoes,
          temGif: false,
          videosPorId: videosPorId,
        ),
    };
  }

  @override
  Future<ExerciseModel?> buscarPorId(String id) async {
    final indice = await _indice();
    return indice[id];
  }

  @override
  Future<List<ExerciseModel>> buscarTodos() async {
    final indice = await _indice();
    return indice.values.toList(growable: false);
  }
}

List<Map<String, dynamic>> _decodificarJson(String jsonString) {
  final lista = json.decode(jsonString) as List<dynamic>;
  return lista.cast<Map<String, dynamic>>();
}

TraducoesBiblioteca _decodificarTraducoes(String jsonString) {
  return TraducoesBiblioteca.fromJson(json.decode(jsonString) as Map<String, dynamic>);
}

Map<String, String> _decodificarVideos(String jsonString) {
  return Map<String, String>.from(json.decode(jsonString) as Map);
}
