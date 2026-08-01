# GymExtreme

App da academia GymExtreme: substitui aos poucos o sistema de gestao
atual (MEGA). Construido em Flutter para gerar, do mesmo codigo, o app
Android nativo (Play Store) e a versao Web usada como PWA no iOS
(o aluno acessa pelo Safari e adiciona a tela inicial).

Este repositorio esta no **Modulo 1 — Base do projeto + Login**.

## O que ja existe neste modulo

- Projeto Flutter `gymextreme_app` com suporte a Android e Web.
- Identidade visual preto/dourado (`lib/theme`) e um icone/wordmark
  placeholder (`lib/widgets/gymextreme_logo.dart`,
  `assets/branding/`) — troque pelo logo oficial (leao dourado) assim
  que o arquivo estiver disponivel, veja "Trocar o icone" abaixo.
- Login por e-mail/senha com Firebase Authentication.
- 3 niveis de acesso via campo `role` na colecao `usuarios` do Firestore:
  `adm`, `personal`, `aluno` (`lib/models/user_role.dart`).
- Telas: login, esqueci minha senha, e uma tela de boas-vindas que so
  prova que o `role` esta sendo lido corretamente
  (`lib/screens/welcome_screen.dart`). As telas de verdade de cada
  perfil vem nos proximos modulos.
- `codemagic.yaml` para build automatico do Android (APK + AAB).
- PWA configurado (`web/manifest.json`, `web/index.html`) para o
  "adicionar a tela de inicio" funcionar no Safari/iOS.

## Estrutura de pastas

```
lib/
  app/            # widget raiz (GymExtremeApp) e AuthGate (login x logado)
  models/         # AppUser, UserRole
  screens/        # LoginScreen, ForgotPasswordScreen, WelcomeScreen
  services/       # AuthService (Firebase Auth), UserService (Firestore)
  theme/          # cores e ThemeData da marca
  widgets/        # GymExtremeLogo
  firebase_options.dart   # config do Firebase por plataforma (ver abaixo)
  main.dart
```

## 1. Pre-requisitos na sua maquina (Windows)

- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (canal stable)
- [Android Studio](https://developer.android.com/studio) com o Android SDK (para rodar/testar o app Android localmente; o build de release roda no Codemagic)
- Node.js so e necessario se for mexer no `importar-exercicios.js` (script separado, nao faz parte do app Flutter)

Depois de clonar o repositorio:

```bash
flutter pub get
```

## 2. Conectar ao Firebase real (gymextreme-42c98)

O `lib/firebase_options.dart` e o `android/app/google-services.json`
deste repositorio contem **valores de placeholder** (nao apontam para
o projeto real). Isso e proposital: gerar os valores reais exige login
com a conta Google/Firebase do cliente, que so pode ser feito na sua
maquina, nunca por mim.

Para configurar de verdade:

```bash
# uma vez, se ainda nao tiver a Firebase CLI e a FlutterFire CLI:
npm install -g firebase-tools
dart pub global activate flutterfire_cli

firebase login
flutterfire configure --project=gymextreme-42c98 --platforms=android,web
```

O comando `flutterfire configure`:
- sobrescreve `lib/firebase_options.dart` com as chaves reais;
- baixa/atualiza `android/app/google-services.json` com as chaves reais.

Ambos os arquivos **nao contem segredos** (sao chaves publicas de
cliente), por isso ficam versionados no Git normalmente — o que nunca
deve ir para o repositorio e o `firebase-key.json` (service account,
usado so pelo script Node `importar-exercicios.js`), que ja esta no
`.gitignore`.

No Firebase Console, confirme que **Authentication > Sign-in method >
E-mail/senha** esta habilitado.

## 3. Criar os 3 usuarios de teste (ADM, Personal, Aluno)

Ainda nao ha tela de cadastro (vem no Modulo 2). Para testar o login
com os 3 perfis:

1. Firebase Console > Authentication > Users > **Add user** — crie um
   usuario com e-mail/senha para cada perfil (adm, personal, aluno).
2. Firebase Console > Firestore Database > colecao **usuarios** >
   crie um documento com o **ID igual ao UID** do usuario criado no
   passo 1, com os campos:
   ```json
   {
     "nome": "Nome de teste",
     "email": "mesmo e-mail do Authentication",
     "role": "adm",       // ou "personal" ou "aluno"
     "criadoEm": <timestamp atual>
   }
   ```
3. Repita para os 3 perfis.

As regras sugeridas em `firestore.rules` deixam cada usuario ler
apenas o proprio documento (necessario para a tela de boas-vindas
funcionar) e bloqueiam escrita pelo app — aplique-as em Firestore
Database > Regras, ou via `firebase deploy --only firestore:rules`.

## 4. Rodar e testar

```bash
flutter analyze
flutter test

# Web (simula o uso no iOS via navegador)
flutter run -d chrome
# ou gerar o build de producao e servir localmente:
flutter build web --release
cd build/web && python3 -m http.server 8080

# Android (com um emulador ou celular conectado)
flutter run -d <device-id>
```

Criterio de pronto do modulo: logar com cada um dos 3 usuarios de
teste, no Android e pelo navegador, e ver a mensagem "Bem-vindo,
ADM" / "Bem-vindo, Personal" / "Bem-vindo, Aluno" correspondente, com
a identidade visual preto/dourado.

### Testar "adicionar a tela de inicio" no iPhone

1. Rode `flutter build web --release` e publique `build/web` em
   algum lugar acessivel por HTTPS (obrigatorio para PWA — pode ser
   Firebase Hosting, por exemplo).
2. Abra o link no Safari do iPhone.
3. Toque em Compartilhar > **Adicionar a Tela de Inicio**.
4. O icone e o nome "GymExtreme" devem aparecer corretamente.

Lembrete para modulos futuros: notificacao push via PWA no iOS so
funciona a partir do iOS 16.4 e somente depois que o usuario adicionou
o app a tela inicial — nao ha nada disso implementado ainda.

## 5. Trocar o icone pelo logo oficial

O icone atual (`assets/branding/app_icon.png`) e um placeholder preto/
dourado gerado localmente, nao o logo real (leao dourado) do cliente.
Quando o arquivo do logo estiver disponivel:

1. Substitua `assets/branding/app_icon.png` (1024x1024, fundo solido)
   e `assets/branding/app_icon_foreground.png` (mesmo logo com margem
   de seguranca, fundo transparente, para o icone adaptativo do
   Android).
2. Rode:
   ```bash
   dart run flutter_launcher_icons
   ```
   Isso atualiza os icones do Android (`android/app/src/main/res/mipmap-*`)
   e do Web/PWA (`web/icons/`, `web/favicon.png`) de uma vez.

## 6. Build para a Play Store (Codemagic)

O `codemagic.yaml` roda `flutter analyze`, `flutter test` e gera o
APK/AAB de release a cada push na branch `main`. Sem uma configuracao
de assinatura (grupo `gymextreme_keystore` com as variaveis de
keystore), o build sai assinado com a chave de debug — suficiente
para testar internamente, mas nao para publicar na Play Store. Quando
for publicar de verdade, configure a assinatura de release seguindo o
guia do Codemagic para Flutter/Android.

Build iOS nao e necessario no Codemagic: o iOS roda como PWA pelo
navegador, nao como app compilado nativo.

## Proximos modulos (fora do escopo deste)

- Modulo 2: cadastro completo de aluno, ficha de avaliacao, anamnese,
  termo de responsabilidade.
- Modulo 3: catalogo de equipamentos e biblioteca de exercicios.
- Modulos seguintes: sistema de treino, chat, notificacoes, auditoria,
  painel completo do ADM.
