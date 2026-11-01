import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado de uma tentativa de identificação no controle de acesso
/// físico (catraca/iDFace) — mesmos dois valores gravados pela Cloud
/// Function (`functions/lib/access/motivos.js`, `RESULTADO`).
enum ResultadoAcesso {
  autorizado,
  negado;

  static ResultadoAcesso fromFirestore(String? valor) {
    return valor == 'ALLOW' ? ResultadoAcesso.autorizado : ResultadoAcesso.negado;
  }
}

/// Um registro de tentativa de acesso físico (coleção `eventosAcesso`,
/// gravada só pela Cloud Function do pipeline do Control iDFace — ver
/// `functions/lib/access/access-event-service.js`). Este model é
/// SOMENTE LEITURA: nada no app grava aqui, nem staff nem aluno —
/// `firestore.rules` já bloqueia qualquer escrita do cliente
/// (`allow write: if false`), e não existe nenhum método de escrita
/// correspondente em `AcessoService` de propósito.
///
/// Deliberadamente SEPARADO de `HistoricoTreino`: acesso físico (entrar
/// na academia) e presença de treino (cumprir a ficha prescrita) são
/// conceitos diferentes, gravados em coleções diferentes, só combinados
/// visualmente na aba "Frequência" (ver `FrequenciaTab`).
class EventoAcesso {
  const EventoAcesso({
    required this.id,
    this.deviceId,
    this.unidadeId,
    this.alunoUid,
    this.userIdDispositivo,
    this.userName,
    this.metodo,
    required this.resultado,
    this.motivo,
    this.confidence,
    this.portalId,
    this.tempoProcessamentoMs,
    this.erro,
    this.criadoEm,
  });

  final String id;
  final String? deviceId;
  final String? unidadeId;
  final String? alunoUid;
  final String? userIdDispositivo;
  final String? userName;

  /// 'FACE' | 'CARD' | 'QRCODE' | 'UNKNOWN' — ver
  /// `functions/lib/access/control-id-adapter.js`.
  final String? metodo;

  final ResultadoAcesso resultado;

  /// Um dos valores de `MOTIVO_NEGACAO` (`functions/lib/access/motivos.js`),
  /// nunca texto livre — nulo quando `resultado == autorizado`. Use
  /// [motivoLabel] pra exibir, nunca este campo bruto na UI.
  final String? motivo;

  final double? confidence;
  final String? portalId;
  final int? tempoProcessamentoMs;
  final String? erro;
  final DateTime? criadoEm;

  bool get autorizado => resultado == ResultadoAcesso.autorizado;

  /// Texto amigável do motivo — espelha exatamente
  /// `functions/lib/access/mensagens.js` (`mensagemParaMotivo`), nunca
  /// expõe detalhe financeiro específico (ex.: nunca "vencida há 12
  /// dias", só "Mensalidade em atraso"). Mesma ideia de
  /// `lib/utils/status_acesso.dart` espelhando `status-acesso.js`: as
  /// duas linguagens têm que ficar sincronizadas manualmente.
  String get motivoLabel {
    switch (motivo) {
      case 'STUDENT_NOT_FOUND':
      case 'INVALID_CREDENTIAL':
        return 'Cadastro não encontrado';
      case 'STUDENT_INACTIVE':
        return 'Matrícula inativa';
      case 'STUDENT_BLOCKED':
        return 'Acesso bloqueado';
      case 'PLAN_EXPIRED':
        return 'Plano expirado';
      case 'PAYMENT_OVERDUE':
        return 'Mensalidade em atraso';
      case 'OUTSIDE_ALLOWED_HOURS':
        return 'Fora do horário permitido';
      case 'UNIT_NOT_ALLOWED':
        return 'Acesso não permitido nesta unidade';
      case 'DEVICE_NOT_AUTHORIZED':
        return 'Dispositivo não autorizado';
      case 'RATE_LIMITED':
        return 'Chamadas rápidas demais do dispositivo';
      case 'SYSTEM_ERROR':
        return 'Erro no sistema';
      default:
        return autorizado ? 'Acesso liberado' : 'Acesso negado';
    }
  }

  factory EventoAcesso.fromFirestore(String id, Map<String, dynamic> data) {
    final criadoEm = data['criadoEm'];
    return EventoAcesso(
      id: id,
      deviceId: data['deviceId'] as String?,
      unidadeId: data['unidadeId'] as String?,
      alunoUid: data['alunoUid'] as String?,
      userIdDispositivo: data['userIdDispositivo'] as String?,
      userName: data['userName'] as String?,
      metodo: data['metodo'] as String?,
      resultado: ResultadoAcesso.fromFirestore(data['resultado'] as String?),
      motivo: data['motivo'] as String?,
      confidence: (data['confidence'] as num?)?.toDouble(),
      portalId: data['portalId'] as String?,
      tempoProcessamentoMs: (data['tempoProcessamentoMs'] as num?)?.toInt(),
      erro: data['erro'] as String?,
      criadoEm: _timestampOrNull(criadoEm),
    );
  }

  static DateTime? _timestampOrNull(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    return null;
  }
}
