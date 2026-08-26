/// Liga aos emuladores locais do Firebase (Auth/Firestore/Storage) em vez
/// do projeto real (gymextreme-42c98) — só pra testar fluxos ponta a ponta
/// sem tocar dados de produção.
///
/// `flutter run --dart-define=USE_EMULATOR=true`. Nunca ativo por padrão —
/// build normal/produção não muda.
const usarEmulador = bool.fromEnvironment('USE_EMULATOR');
