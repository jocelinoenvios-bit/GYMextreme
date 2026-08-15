# Cloud Functions — GYM XTREME

Duas funções, implementando a arquitetura de controle de acesso já definida:

- **`solicitarAutorizacaoAcesso`** — recebida do módulo de identificação (facial,
  biometria, QR, NFC...), decide se o aluno pode entrar e grava o resultado em
  `academias/{academiaId}/autorizacoesAcesso`, onde o serviço local escuta.
- **`enviarNotificacoesMensalidade`** — roda todo dia às 8h (horário de
  Brasília) e, pra cada aluno com matrícula ativa, identifica quem está
  próximo do vencimento ou já vencido (7/3/0 dias antes, avisos de
  tolerância, bloqueio) e processa a notificação correspondente
  (`processarNotificacaoMensalidade`, em `index.js`):
  1. **Identifica** o status da mensalidade (`calcularStatusAcesso`) e a
     mensagem do dia (`mensagemNotificacaoMensalidade`) — se não houver
     mensagem devida hoje, não faz nada.
  2. **Registra** a notificação em
     `alunos/{alunoUid}/notificacoesMensalidade/{AAAA-MM-DD}` (fuso São
     Paulo) — auditoria de toda notificação gerada, mesmo quando não há
     token pra entregar de verdade (`erro: 'sem_token_fcm'`). O id por dia
     torna o job idempotente: reexecutar no mesmo dia nunca duplica nem
     reenvia.
  3. **Envia o push**, só se houver `usuarios/{alunoUid}.fcmTokens`, via
     Firebase Cloud Messaging.

A lógica de datas (`lib/status-acesso.js`) é a mesma de
`lib/utils/status_acesso.dart` no app Flutter — os dois têm que ficar
idênticos. O registro da notificação (`lib/notificacao-mensalidade.js`) é
puro (sem Firestore/Messaging) pelo mesmo motivo: dá pra testar sem
credencial nenhuma.

```
npm install
npm test
```

### Testando o fluxo de notificação contra o Firestore Emulator

`npm test` só cobre a lógica pura (datas, mensagens, montagem do registro).
Pra validar de verdade a escrita em `notificacoesMensalidade` e a
idempotência (sem NUNCA chamar o Firebase Messaging — só exercita o caminho
sem token FCM), suba o Firestore Emulator com um projeto fake e rode:

```
npm run test:emulator
```

Isso não faz deploy nem exige `firebase login` — `firebase emulators:exec`
sobe e derruba o emulador sozinho, contra um projeto local (`demo-*`).

### Testando `firestore.rules` (permissões de ADM/aluno/deslogado)

`test/firestore-rules-admin.emulator.js` comprova, com
`@firebase/rules-unit-testing` contra o Firestore Emulator (não bypassa
regra nenhuma — autentica de verdade como cada papel), que:

- **ADM** lê e grava nos 5 módulos administrativos (planos, produtos,
  contas a pagar, contas a receber, controle de caixa), usando exatamente
  os formatos de documento que `PlanoService`/`ProdutoService`/
  `ContaPagarService`/`AlunoService`/`CaixaService` enviam de verdade —
  inclusive o recebimento de uma cobrança com um caixa aberto
  (`CaixaService.registrarRecebimentoContaReceber`, que também grava
  `movimentacaoCaixaId`).
- **Aluno/usuário comum** continua bloqueado nesses mesmos 5 módulos, e só
  lê a própria `contasReceber` (nunca a de outro aluno, nem via
  `collectionGroup`).
- **Visitante deslogado** não lê nada.

```
npm run test:rules
```

## Antes de implantar (ainda não implantado)

1. **Plano Blaze do Firebase** — `enviarNotificacoesMensalidade` é uma função
   agendada, o que exige o plano pago (cobra só pelo uso). Confirme isso no
   Firebase Console antes de implantar.
2. **`usuarios/{uid}.fcmTokens`** já é preenchido pelo app
   (`NotificacaoService.registrarTokenDoAparelho`, chamado a cada login) —
   falta testar em um dispositivo/aparelho real (e, pro PWA/iOS, configurar
   uma VAPID key + service worker do FCM pra Web) antes das notificações
   realmente chegarem.
3. **Coleção `credenciais`** precisa ser populada conforme o método de
   identificação escolhido (QR Code, biometria, facial, NFC).

## Implantar

```
npm install
firebase deploy --only functions
```

Requer `firebase login` com uma conta que tenha acesso ao projeto.
