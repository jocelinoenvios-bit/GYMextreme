import 'package:cloud_firestore/cloud_firestore.dart';

/// Situação de um [Caixa]. Cada abertura é o seu próprio documento — não
/// existe um "caixa único" reaberto/reciclado; fechar um e abrir outro
/// depois cria um novo registro, preservando o histórico de cada sessão.
enum StatusCaixa {
  aberto,
  fechado;

  String get label => this == StatusCaixa.aberto ? 'Aberto' : 'Fechado';

  static StatusCaixa fromFirestoreValue(String? value) {
    return value == StatusCaixa.fechado.name
        ? StatusCaixa.fechado
        : StatusCaixa.aberto;
  }
}

/// Uma sessão de caixa (coleção `caixas`, nível de academia — não
/// pertence a nenhum aluno) — da abertura ao fechamento, com as
/// movimentações vivendo em `caixas/{id}/movimentacoes`.
///
/// Só existe UM [Caixa] com `status == aberto` por vez em toda a academia
/// (ver `CaixaService.abrirCaixa`, que bloqueia a abertura de um segundo).
/// Depois de fechado (`CaixaService.fecharCaixa`), os campos de fechamento
/// nunca mais mudam — é um retrato imutável do que foi contado naquele
/// momento.
class Caixa {
  const Caixa({
    this.id,
    required this.valorInicial,
    this.status = StatusCaixa.aberto,
    required this.abertoPorUid,
    required this.abertoPorNome,
    this.abertoEm,
    this.valorContado,
    this.valorEsperadoNoFechamento,
    this.diferenca,
    this.fechadoPorUid,
    this.fechadoPorNome,
    this.fechadoEm,
    this.observacaoFechamento,
  });

  final String? id;
  final double valorInicial;
  final StatusCaixa status;
  final String abertoPorUid;
  final String abertoPorNome;
  final DateTime? abertoEm;

  /// Preenchidos só no fechamento (`CaixaService.fecharCaixa`) — nulos
  /// enquanto o caixa está aberto. [valorEsperadoNoFechamento] é um
  /// retrato (`valorInicial` + soma das movimentações no instante do
  /// fechamento), não recalculado depois.
  final double? valorContado;
  final double? valorEsperadoNoFechamento;

  /// `valorContado - valorEsperadoNoFechamento`. Positivo = sobra,
  /// negativo = falta.
  final double? diferenca;

  final String? fechadoPorUid;
  final String? fechadoPorNome;
  final DateTime? fechadoEm;
  final String? observacaoFechamento;

  factory Caixa.fromFirestore(String id, Map<String, dynamic> data) {
    final abertoEm = data['abertoEm'];
    final fechadoEm = data['fechadoEm'];
    return Caixa(
      id: id,
      valorInicial: (data['valorInicial'] as num?)?.toDouble() ?? 0,
      status: StatusCaixa.fromFirestoreValue(data['status'] as String?),
      abertoPorUid: data['abertoPorUid'] as String? ?? '',
      abertoPorNome: data['abertoPorNome'] as String? ?? '',
      abertoEm: abertoEm is Timestamp ? abertoEm.toDate() : null,
      valorContado: (data['valorContado'] as num?)?.toDouble(),
      valorEsperadoNoFechamento: (data['valorEsperadoNoFechamento'] as num?)
          ?.toDouble(),
      diferenca: (data['diferenca'] as num?)?.toDouble(),
      fechadoPorUid: data['fechadoPorUid'] as String?,
      fechadoPorNome: data['fechadoPorNome'] as String?,
      fechadoEm: fechadoEm is Timestamp ? fechadoEm.toDate() : null,
      observacaoFechamento: data['observacaoFechamento'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'valorInicial': valorInicial,
      'status': status.name,
      'abertoPorUid': abertoPorUid,
      'abertoPorNome': abertoPorNome,
      'abertoEm': abertoEm != null
          ? Timestamp.fromDate(abertoEm!)
          : FieldValue.serverTimestamp(),
      'valorContado': valorContado,
      'valorEsperadoNoFechamento': valorEsperadoNoFechamento,
      'diferenca': diferenca,
      'fechadoPorUid': fechadoPorUid,
      'fechadoPorNome': fechadoPorNome,
      'fechadoEm': fechadoEm != null ? Timestamp.fromDate(fechadoEm!) : null,
      'observacaoFechamento': observacaoFechamento,
    };
  }
}
