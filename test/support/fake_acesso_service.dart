import 'package:gymextreme_app/models/evento_acesso.dart';
import 'package:gymextreme_app/services/acesso_service.dart';

/// Dublê de teste do [AcessoService] — mesmo padrão de
/// [FakeAlunoService]: implementa a mesma interface pública sem tocar o
/// Firestore de verdade.
class FakeAcessoService implements AcessoService {
  FakeAcessoService({this.eventos = const []});

  List<EventoAcesso> eventos;

  @override
  Stream<List<EventoAcesso>> watchEventosAcesso(String alunoUid, {int limite = 50}) {
    final filtrados = eventos.where((e) => e.alunoUid == alunoUid).take(limite).toList();
    return Stream.value(filtrados);
  }
}
