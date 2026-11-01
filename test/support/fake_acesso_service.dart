import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/catraca.dart';
import 'package:gymextreme_app/models/evento_acesso.dart';
import 'package:gymextreme_app/services/acesso_service.dart';

/// Dublê de teste do [AcessoService] — mesmo padrão de
/// [FakeAlunoService]: implementa a mesma interface pública sem tocar o
/// Firestore de verdade.
class FakeAcessoService implements AcessoService {
  FakeAcessoService({this.eventos = const [], this.dispositivos = const []});

  List<EventoAcesso> eventos;
  List<DispositivoAcesso> dispositivos;

  /// dispositivoId -> (código -> alunoUid)
  final Map<String, Map<String, String>> credenciais = {};

  @override
  Future<CatracaDoAluno> carregarCatraca(String alunoUid) async {
    return CatracaDoAluno(
      dispositivos: dispositivos,
      vinculos: [
        for (final d in dispositivos)
          for (final e in (credenciais[d.id] ?? const <String, String>{}).entries)
            if (e.value == alunoUid) VinculoCatraca(dispositivo: d, codigo: e.key),
      ],
    );
  }

  @override
  Future<void> vincularCodigo({
    required String dispositivoId,
    required String codigo,
    required String alunoUid,
    required AppUser staff,
  }) async {
    final doLeitor = credenciais.putIfAbsent(dispositivoId, () => {});
    final dono = doLeitor[codigo];
    if (dono != null && dono != alunoUid) {
      throw AcessoServiceException('O código $codigo já está vinculado a outro aluno neste leitor.');
    }
    doLeitor[codigo] = alunoUid;
  }

  @override
  Future<void> desvincularCodigo({required String dispositivoId, required String codigo}) async {
    credenciais[dispositivoId]?.remove(codigo);
  }

  @override
  Stream<List<EventoAcesso>> watchEventosAcesso(String alunoUid, {int limite = 50}) {
    final filtrados = eventos.where((e) => e.alunoUid == alunoUid).take(limite).toList();
    return Stream.value(filtrados);
  }
}
