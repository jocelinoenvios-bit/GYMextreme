import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Prepara o aparelho pra receber as notificações push de mensalidade
/// (Cloud Function agendada `enviarNotificacoesMensalidade`): pede
/// permissão, obtém o token FCM do aparelho e mantém
/// `usuarios/{uid}.fcmTokens` atualizado — sem isso a Cloud Function nunca
/// tem pra quem mandar o push (ver `functions/README.md`).
///
/// Um mesmo usuário pode logar em mais de um aparelho, por isso
/// `fcmTokens` é um array (`arrayUnion`/`arrayRemove`), nunca um campo
/// único.
class NotificacaoService {
  NotificacaoService({FirebaseFirestore? firestore, FirebaseMessaging? messaging})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  /// Evita inscrever `onTokenRefresh` mais de uma vez se
  /// [registrarTokenDoAparelho] for chamado de novo pro mesmo aparelho
  /// (ex.: `AuthGate` reconstruindo) — a inscrição em si só precisa
  /// acontecer uma vez por instância deste serviço.
  bool _onTokenRefreshInscrito = false;

  DocumentReference<Map<String, dynamic>> _usuario(String uid) =>
      _firestore.collection('usuarios').doc(uid);

  /// Pede permissão de notificação (se ainda não decidida) e salva o token
  /// FCM do aparelho atual no documento do usuário logado. Chamado a cada
  /// login (ver `AuthGate`) — seguro de chamar mais de uma vez pro mesmo
  /// usuário: salvar o mesmo token de novo não duplica (`arrayUnion`).
  ///
  /// Nunca lança: permissão negada, aparelho sem Google Play Services, ou
  /// Web/PWA sem VAPID key configurada (`getToken` do plugin web exige uma)
  /// apenas encerram a função em silêncio — isso nunca deve travar o login.
  Future<void> registrarTokenDoAparelho(String uid) async {
    try {
      final configuracao = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (configuracao.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token != null) await _salvarToken(uid, token);

      if (!_onTokenRefreshInscrito) {
        _onTokenRefreshInscrito = true;
        // O token pode mudar sem o usuário deslogar (reinstalação, limpeza
        // de dados do app) — sem isso o token antigo continuaria salvo (a
        // Cloud Function tentaria mandar push pra um token morto) e o novo
        // nunca seria adicionado.
        _messaging.onTokenRefresh.listen((novoToken) => _salvarToken(uid, novoToken));
      }
    } catch (_) {
      // Ver docstring: qualquer falha aqui é motivo pra so nao ter push
      // preparado ainda neste aparelho, nunca pra travar o login.
    }
  }

  /// Remove o token do aparelho atual do usuário que está saindo — evita
  /// que a próxima pessoa a logar neste mesmo aparelho continue recebendo
  /// as notificações do usuário anterior. Chamar ANTES de
  /// `AuthService.signOut()`: depois de deslogado o Firestore já não
  /// autoriza mais a escrita (regra exige `request.auth.uid == uid`). Nunca
  /// lança (mesmo motivo de [registrarTokenDoAparelho]) — uma falha aqui
  /// nunca deve impedir o logout de continuar.
  Future<void> removerTokenDoAparelho(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _usuario(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ver docstring.
    }
  }

  Future<void> _salvarToken(String uid, String token) {
    return _usuario(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }
}
