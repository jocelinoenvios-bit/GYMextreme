# Cloud Functions — GYM XTREME

Três funções:

- **`solicitarAutorizacaoAcesso`** — recebida do módulo de identificação (facial,
  biometria, QR, NFC...), decide se o aluno pode entrar e grava o resultado em
  `academias/{academiaId}/autorizacoesAcesso`, onde o serviço local escuta.
  Desenho antigo, pra solenoide genérico controlado por um computador local
  (`catraca-servico-local/`) — não é o caminho usado pela integração com o
  iDFace Pro (ver `controlIdNewUserIdentified` abaixo), que fala HTTP direto
  com o dispositivo, sem PC intermediário.
- **`controlIdNewUserIdentified`** — endpoint chamado pelo terminal facial
  Control iD iDFace Pro a cada identificação (evento `new_user_identified`
  da Access API). Ver `lib/access/` pra toda a arquitetura:
  - `control-id-adapter.js` — `ControlIdAccessProvider`: traduz o payload do
    Control iD pro formato interno e monta a resposta de volta (`event: 7`
    liberado / `event: 6` negado, com as ações de abertura). Único arquivo
    que conhece o formato específico deste fabricante.
  - `access-authorization-service.js` — `AccessAuthorizationService`: decide
    ALLOW/DENY (aluno existe/ativo/bloqueado, plano vigente, mensalidade em
    dia — reaproveita `lib/status-acesso.js` —, unidade permitida). Puro,
    sem Firestore, testável isolado (`test/access/access-authorization-service.test.js`,
    cobre os 8 primeiros testes do roteiro de integração).
  - `access-event-service.js` — `AccessEventService`: registra cada
    tentativa (liberada ou negada) em `eventosAcesso`, idempotente pelo
    `uuid` do dispositivo (evento reenviado não duplica).
  - `device-auth.js` — resolve e valida o dispositivo que chamou, por um
    token secreto próprio (`dispositivosAcesso/{id}.tokenHash`) — não tem
    nada a ver com o login/senha do próprio iDFace na Access API (esse
    serve pro sentido contrário, Gym Xtreme → iDFace, ainda não
    implementado — `DeviceSyncService`).
  - `access-request-handler.js` — orquestra os quatro acima pra cada
    requisição.
  - `motivos.js`/`mensagens.js` — motivos de negativa padronizados (ver
    seção 11 do briefing) e o texto curto mostrado na tela do aparelho.

  Exposto via Firebase Hosting em
  `/api/integrations/controlid/events/new-user-identified` (rewrite em
  `firebase.json`). **Pendências antes de funcionar de ponta a ponta** (ver
  seção "Antes de implantar" abaixo): cadastrar o dispositivo em
  `dispositivosAcesso` e popular `dispositivosAcesso/{id}/credenciais` (isso
  é o `DeviceSyncService`, Fase 6 do roteiro — ainda não implementado, hoje
  só a leitura desse mapeamento existe). Vários detalhes de baixo nível
  (nome exato da ação de abertura do relé, se o "Modo Pro/Online" do
  aparelho aceita header HTTP customizado) estão marcados **A CONFIRMAR NO
  EQUIPAMENTO** no código — a documentação oficial da Control iD
  (controlid.com.br) não pôde ser acessada da máquina onde isso foi
  implementado (bloqueio de rede do ambiente), então esses pontos vieram só
  de buscas, não do texto primário.
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

### Testando a integração com o iDFace Pro (Control iD)

Mesmo padrão dos dois de cima, dois arquivos novos em `test/access/`:

```
npm run test:emulator:access   # fluxo completo: aluno em dia, atrasado,
                                # nunca sincronizado, unidade errada,
                                # dispositivo não autorizado, evento duplicado
npm run test:rules:access      # regras das coleções dispositivosAcesso,
                                # eventosAcesso e unidades
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
4. **Integração com o iDFace Pro** — antes de qualquer aluno de verdade
   depender disso: (a) cadastrar manualmente o dispositivo em
   `dispositivosAcesso/{id}` (`unidadeId`, `tipo`, `tokenHash` — gerar um
   token aleatório e gravar só o hash SHA-256 dele, `hashToken` em
   `lib/access/device-auth.js`) e configurar esse mesmo token no aparelho;
   (b) popular `dispositivosAcesso/{id}/credenciais/{userIdNoAparelho}` com
   o `alunoUid` de cada aluno sincronizado — nenhuma tela faz isso ainda
   (é o `DeviceSyncService`, Fase 6 do roteiro, não implementado); (c)
   confirmar no equipamento físico os pontos marcados "A CONFIRMAR NO
   EQUIPAMENTO" no código (nome da ação de abertura do relé, header HTTP
   customizado vs. token na URL).

## Implantar

```
npm install
firebase deploy --only functions
```

Requer `firebase login` com uma conta que tenha acesso ao projeto.
