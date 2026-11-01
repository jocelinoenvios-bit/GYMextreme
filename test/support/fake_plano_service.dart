import 'dart:async';

import 'package:gymextreme_app/models/plano.dart';
import 'package:gymextreme_app/services/plano_service.dart';

/// Dublê de teste do [PlanoService] — mesmo padrão de [FakeAlunoService]:
/// implementa a mesma interface pública sem tocar o Firestore de verdade.
class FakePlanoService implements PlanoService {
  FakePlanoService({this.planos = const []});

  List<Plano> planos;
  Plano? ultimoPlanoSalvo;
  String? ultimoPlanoExcluidoId;

  final _atualizacoes = StreamController<List<Plano>>.broadcast();

  /// Como o Firestore: emite a lista atual e de novo a cada mudança.
  @override
  Stream<List<Plano>> watchPlanos() async* {
    yield planos;
    yield* _atualizacoes.stream;
  }

  @override
  Future<Plano?> buscarPlano(String id) async {
    for (final plano in planos) {
      if (plano.id == id) return plano;
    }
    return null;
  }

  @override
  Future<String> salvarPlano(Plano plano) async {
    final id = plano.id ?? 'novo-plano';
    final salvo = Plano(
      id: id,
      nome: plano.nome,
      descricao: plano.descricao,
      valor: plano.valor,
      duracaoDias: plano.duracaoDias,
      ativo: plano.ativo,
    );
    ultimoPlanoSalvo = salvo;
    planos = [...planos.where((p) => p.id != id), salvo];
    return id;
  }

  @override
  Future<void> excluirPlano(String id) async {
    ultimoPlanoExcluidoId = id;
    planos = [
      for (final plano in planos)
        if (plano.id == id)
          Plano(
            id: plano.id,
            nome: plano.nome,
            valor: plano.valor,
            duracaoDias: plano.duracaoDias,
            ativo: false,
            excluido: true,
          )
        else
          plano,
    ];
    _atualizacoes.add(planos);
  }
}
