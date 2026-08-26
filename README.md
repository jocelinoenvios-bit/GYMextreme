# GymExtreme

App da academia GymExtreme: substitui aos poucos o sistema de gestao
atual (MEGA). Construido em Flutter para gerar, do mesmo codigo, o app
Android nativo (Play Store) e a versao Web usada como PWA no iOS
(o aluno acessa pelo Safari e adiciona a tela inicial).

Este repositorio esta nos **Modulos 1, 2 e 3 — Base do projeto + Login,
Cadastro/Ficha do aluno, e Biblioteca de exercicios**.

## O que ja existe

### Modulo 1 — Base + Login
- Projeto Flutter `gymextreme_app` com suporte a Android e Web.
- Identidade visual preto/dourado (`lib/theme`) e um icone/wordmark
  placeholder (`lib/widgets/gymextreme_logo.dart`,
  `assets/branding/`) — troque pelo logo oficial (leao dourado) assim
  que o arquivo estiver disponivel, veja "Trocar o icone" abaixo.
- Login por e-mail/senha com Firebase Authentication.
- 3 niveis de acesso via campo `role` na colecao `usuarios` do Firestore:
  `adm`, `personal`, `aluno` (`lib/models/user_role.dart`).
- Telas: login, esqueci minha senha, e uma tela de boas-vindas que
  prova que o `role` esta sendo lido corretamente
  (`lib/screens/welcome_screen.dart`).
- `codemagic.yaml` para build automatico do Android (APK + AAB).
- PWA configurado (`web/manifest.json`, `web/index.html`) para o
  "adicionar a tela de inicio" funcionar no Safari/iOS.

### Modulo 2 — Cadastro digital completo do aluno
Substitui 100% a ficha em papel "GYM XTREME" (dados cadastrais +
anamnese + regulamento/termo de responsabilidade + avaliacao fisica +
ficha de treino). Acessivel pela tela de boas-vindas, botao
**"Gerenciar alunos"** (`lib/screens/alunos/`):

- **Cadastro guiado (`NovoAlunoWizardScreen`)** — fluxo em etapas
  (Dados → Anamnese → Regulamento → Avaliacao fisica → opcao de ja
  prescrever o Treino), reaproveitando os mesmos widgets usados depois
  na ficha do aluno ja cadastrado. Dados pessoais completos: foto
  (Firebase Storage), sexo, data de nascimento (idade calculada
  automaticamente), CPF/RG, telefone/WhatsApp, endereco, contato de
  emergencia, observacoes, alem do login (Firebase Auth) e vinculo com
  a academia (data de inicio, dia de vencimento).
- **Anamnese** — as 13 perguntas da ficha em papel, ponto a ponto
  (`AnamneseTab`).
- **Termo de responsabilidade** — as 15 regras do "REGULAMENTO" em
  papel, com aceite digital (nome, data/hora, responsavel opcional pra
  menores de idade e qual funcionario da recepcao registrou o aceite)
  no lugar da assinatura manuscrita (`TermoTab`).
- **Avaliacao fisica** — peso, altura (IMC calculado e classificado
  automaticamente) e as 16 medidas de circunferencia da ficha, com
  historico completo ao longo do tempo, nunca apagado
  (`AvaliacoesTab` + `AvaliacaoFisicaFormScreen`).
- **Ficha de treino (`TreinosTab` + `TreinoFormScreen`)** — treinos
  A-F, cada um com lista de exercicios (sempre referenciando a
  biblioteca do Modulo 3, nunca digitados a mao): series, repeticoes,
  carga, descanso, observacoes e ordem. Da pra criar, editar, excluir,
  duplicar e copiar um treino pronto de outro aluno. Aba visivel so
  com a permissao `prescricaoTreinos`; criar/editar exige
  `criarTreinos`/`editarTreinos` (checado ate no Firestore, nao so na
  UI).

Quem preenche e o staff (ADM/Recepcionista/Personal, conforme a
permissao de cada um) — o aluno ainda nao tem area propria no app,
isso fica para um modulo futuro de auto-atendimento.

**Pontos que assumi e que valem uma conferencia sua:**
- `lib/constants/regulamento.dart` tem um `regulamentoToleranciaDias =
  5` (regra 3, "tolerancia de ___ dias") — na ficha em papel esse
  numero fica em branco pra preencher a caneta; usei 5 como placeholder
  razoavel, mas confirme o valor oficial antes de ir pra producao.
- O texto do regulamento foi digitado a partir da foto; vale uma
  conferencia final antes de publicar (principalmente se ele tiver
  qualquer validade juridica formal).
- Graficos/fotos de evolucao (peso, medidas, carga ao longo do tempo)
  ainda nao tem tela — o banco ja esta preparado (`AvaliacaoFisica.
  fotoUrls`, historico por data), fica pra um proximo modulo.
- Foto do aluno exige `firebase_storage` configurado no projeto
  (bucket ja existe, `storage.rules` novo neste commit — publique
  manualmente no Firebase Console, mesmo processo ja usado pro
  `firestore.rules`).

### Modulo 3 — Biblioteca de exercicios
Tela somente leitura (`lib/screens/exercicios/`) que le a colecao
`exercicios` do Firestore, com busca por nome e filtro por grupo
muscular. Acessivel pela tela de boas-vindas de ADM/Personal, botao
**"Biblioteca de exercicios"**.

O filtro de grupo muscular e **montado dinamicamente** a partir dos
valores que existirem nos dados (nao fica preso a taxonomia de
nenhuma API especifica) — `lib/constants/grupos_musculares.dart` so
traduz pra portugues os valores conhecidos da fonte atual
(`back`/`chest`/`upper legs`/etc.), e mostra o valor original quando
nao reconhece. Isso porque a fonte dos exercicios deve trocar em
breve (API paga, ainda a definir) — quando isso acontecer, so o
script/import que popula a colecao `exercicios` precisa mudar; a tela
continua funcionando sem alteracao, desde que os documentos guardem
os campos `nome`, `grupoMuscular`, `alvo`, `equipamento`, `nivel`
(opcional), `instrucoes` (lista de strings) e `gifUrl`.

Cadastro/edicao de exercicios continua fora do app (script com
credencial de admin) — as regras do Firestore bloqueiam qualquer
escrita de `exercicios` pelo cliente.

## Estrutura de pastas

```
lib/
  app/            # widget raiz (GymExtremeApp) e AuthGate (login x logado)
  constants/      # circunferenciaFields, texto do regulamento, grupos musculares
  models/         # AppUser, UserRole, Aluno, Anamnese, TermoAceite, AvaliacaoFisica, Exercicio
  screens/        # LoginScreen, ForgotPasswordScreen, WelcomeScreen
    alunos/       # lista, cadastro, ficha (abas: dados/anamnese/termo/avaliacoes)
    exercicios/   # biblioteca de exercicios (lista + detalhe)
  services/       # AuthService, UserService, AlunoService, ExercicioService
  theme/          # cores e ThemeData da marca
  utils/          # calculo e classificacao de IMC
  widgets/        # GymExtremeLogo
  firebase_options.dart   # config do Firebase por plataforma (ver abaixo)
  main.dart
```

## 1. Pre-requisitos na sua maquina (Windows)

- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (canal stable)
- [Android Studio](https://developer.android.com/studio) com o Android SDK (para rodar/testar o app Android localmente; o build de release roda no Codemagic)
- Node.js so e necessario se for mexer nos scripts separados (`seed-alunos-teste.js`, `functions/`, `catraca-servico-local/`) — nao fazem parte do app Flutter

Depois de clonar o repositorio:

```bash
flutter pub get
```

## 2. Firebase (gymextreme-42c98)

`lib/firebase_options.dart` e `android/app/google-services.json` ja
tem as chaves reais do projeto `gymextreme-42c98` (apps Web e Android
cadastrados via `flutterfire configure`). Ambos os arquivos **nao
contem segredos** (sao chaves publicas de cliente, restritas por
regras do Firebase), por isso ficam versionados no Git normalmente —
o que nunca deve ir para o repositorio e o `firebase-key.json`
(service account, usado pelos scripts Node como `seed-alunos-teste.js`),
que ja esta no `.gitignore`.

Se o projeto Firebase mudar (nova chave, novo app), regenere assim:

```bash
# uma vez, se ainda nao tiver a Firebase CLI e a FlutterFire CLI:
npm install -g firebase-tools
dart pub global activate flutterfire_cli

firebase login
flutterfire configure --project=gymextreme-42c98 --platforms=android,web
```

No Firebase Console, confirme que **Authentication > Sign-in method >
E-mail/senha** esta habilitado.

## 3. Criar os usuarios de teste (ADM, Personal, Aluno)

O ADM e o Personal ainda sao criados manualmente (nao ha tela de
"cadastrar funcionario" — isso e administrativo, nao autoatendimento):

1. Firebase Console > Authentication > Users > **Add user** — crie um
   usuario com e-mail/senha para ADM e outro para Personal.
2. Firebase Console > Firestore Database > colecao **usuarios** >
   crie um documento com o **ID igual ao UID** do usuario criado no
   passo 1, com os campos:
   ```json
   {
     "nome": "Nome de teste",
     "email": "mesmo e-mail do Authentication",
     "role": "adm",       // ou "personal"
     "criadoEm": <timestamp atual>
   }
   ```

Ja o **aluno** de teste pode ser criado direto pelo app: logue como
ADM ou Personal, toque em "Gerenciar alunos" > botao **+** > preencha
nome/e-mail/senha inicial — o app cria a conta e o cadastro sozinho.

As regras em `firestore.rules` liberam leitura do proprio perfil pra
qualquer usuario logado, e leitura/escrita de `usuarios` e `alunos`
(cadastro, anamnese, termo, avaliacoes) apenas pra quem tem role `adm`
ou `personal` — aplique-as em Firestore Database > Regras, ou via
`firebase deploy --only firestore:rules`.

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

Criterio de pronto do Modulo 1: logar com cada um dos 3 usuarios de
teste, no Android e pelo navegador, e ver a mensagem "Bem-vindo,
ADM" / "Bem-vindo, Personal" / "Bem-vindo, Aluno" correspondente, com
a identidade visual preto/dourado.

Criterio de pronto do Modulo 2: logado como ADM ou Personal, cadastrar
um aluno novo, preencher a anamnese, aceitar o termo de
responsabilidade e registrar uma avaliacao fisica — e tudo isso
aparecer salvo ao reabrir a ficha do aluno.

Criterio de pronto do Modulo 3: a Biblioteca Oficial de Exercicios
(ExerciseDB, 1.394 exercicios com GIFs 180/360, 100% local/offline —
sem colecao no Firestore) ja vem empacotada com o app. Logado como ADM
ou Personal, abrir "Biblioteca de exercicios", buscar por nome, filtrar
por grupo muscular e abrir o detalhe de um exercicio (gif, instrucoes).

### Testar "adicionar a tela de inicio" no iPhone

1. Rode `flutter build web --release` e publique `build/web` em
   algum lugar acessivel por HTTPS (obrigatorio para PWA — pode ser
   Firebase Hosting, por exemplo).
2. Abra o link no Safari do iPhone.
3. Toque em Compartilhar > **Adicionar a Tela de Inicio**.
4. O icone e o nome "GymExtreme" devem aparecer corretamente.

Notificacao push de mensalidade (Cloud Function `enviarNotificacoesMensalidade`
+ `NotificacaoService` no app) ja esta preparada para Android — falta so
o dispositivo real de teste, ver `functions/README.md`. No PWA do iOS a
notificacao push so funciona a partir do iOS 16.4 e somente depois que o
usuario adicionou o app a tela inicial, e ainda precisa de uma VAPID key +
service worker do FCM pra Web — isso continua pendente, fora do escopo
desta primeira versao.

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
APK/AAB de release a cada push na branch `claude/chave-aqui-esta-u505zg`
(branch principal deste repositorio). Sem uma configuracao de
assinatura (grupo `gymextreme_keystore` com as variaveis de
keystore), o build sai assinado com a chave de debug — suficiente
para testar internamente, mas nao para publicar na Play Store. Quando
for publicar de verdade, configure a assinatura de release seguindo o
guia do Codemagic para Flutter/Android.

Build iOS nao e necessario no Codemagic: o iOS roda como PWA pelo
navegador, nao como app compilado nativo.

## 7. APK de debug pra testar no celular (GitHub Actions)

`.github/workflows/android-debug-apk.yml` builda um APK de **debug**
(assinado com a chave de debug padrao do Android, so pra instalar e
testar — nao serve pra Play Store) toda vez que:

- alguem faz push na branch `claude/chave-aqui-esta-u505zg`, ou
- voce dispara manualmente em **GitHub > Aba "Actions" > "Android
  debug APK" > "Run workflow"**.

O APK fica disponivel de duas formas:

1. **Artefato do workflow**: na execucao (Actions > clique na run >
   "Artifacts", embaixo) — baixa um `.zip` com o APK dentro, expira em
   30 dias.
2. **Release "debug-latest"**: em **GitHub > Releases > debug-latest**
   — link fixo, sempre aponta pro build mais recente, baixa o `.apk`
   direto (mais facil de abrir no navegador do celular e instalar).

No Android, pra instalar um APK baixado fora da Play Store e preciso
permitir "Instalar apps de fontes desconhecidas" pro navegador/gerenciador
de arquivos usado — o proprio Android pede essa permissao na hora de
abrir o arquivo, se ainda nao estiver liberada.

## Proximos modulos (fora do escopo deste)

- Sistema de treino (inclui a tabela "GRUPO MUSCULAR INFERIOR" da
  ficha em papel), chat, notificacoes, auditoria, painel completo do
  ADM, area propria do aluno (hoje o cadastro e todo feito pelo
  ADM/Personal).
- Catalogo de equipamentos fisicos da academia (esteiras, maquinas
  etc.) como algo separado do exercicio em si — nao entrou neste
  modulo; hoje o "equipamento" e so um campo dentro de cada exercicio.
- Enriquecer a Biblioteca Oficial com a API V2 (ExerciseDB) quando
  houver internet — arquitetura ja preparada
  (`RemoteExerciseRepository`/`HybridExerciseRepository`, ainda nao
  implementadas), local continua sendo a fonte principal.
