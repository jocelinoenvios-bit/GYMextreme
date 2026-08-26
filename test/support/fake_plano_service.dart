import 'package:gymextreme_app/models/plano.dart';
import 'package:gymextreme_app/services/plano_service.dart';

/// Dublê de teste do [PlanoService] — mesmo padrão de [FakeAlunoService]:
/// implementa a mesma interface pública sem tocar o Firestore de verdade.
class FakePlanoService implements PlanoService {
  FakePlanoService({this.planos = const []});

  List<Plano> planos;
  Plano? ultimoPlanoSalvo;
  String? ultimoPlanoExcluidoId;

  @override
  Stream<List<Plano>> watchPlanos() => Stream.value(planos);

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
        if (plano.id == id) plano.copyWith(ativo: false) else plano,
    ];
  }
}
