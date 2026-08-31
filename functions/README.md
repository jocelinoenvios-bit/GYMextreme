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
  - `access-control-provider.js` — só documentação (JSDoc) do contrato
    `AccessControlProvider`: o que qualquer integração de identificação
    (Control iD, um leitor de QR Code, outra marca de catraca...) precisa
    expor pra se plugar no resto do domínio sem que nada fora do adaptador
    conheça o formato de um fabricante específico.
  - `control-id-adapter.js` — `ControlIdAccessProvider`: implementação
    concreta do contrato acima pro Control iD. Traduz o payload pro
    formato interno e monta a resposta de volta (`event: 7` liberado /
    `event: 6` negado). A lista `actions` (ações de abertura do relé) só
    vem preenchida se a variável de ambiente `CONTROLID_ACAO_ABERTURA_JSON`
    estiver configurada — **por padrão vem sempre vazia**, de propósito:
    o comando exato do relé não foi confirmado (nem na documentação, nem
    no equipamento) e não deve ser assumido antes da Fase de validação
    física.
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
    serve pro sentido contrário, Gym Xtreme → iDFace — ver
    `device-sync-service.js`).
  - `rate-limit.js` — guard-rail opcional (desligado por padrão) contra
    chamadas rápidas demais do mesmo dispositivo — liga configurando
    `CONTROLID_INTERVALO_MINIMO_MS`.
  - `access-request-handler.js` — orquestra os módulos acima pra cada
    requisição: valida o payload (400 se não for utilizável), resolve o
    dispositivo, aplica o rate limit, resolve o aluno, decide e registra.
    Recebe o `AccessControlProvider` por parâmetro (usa
    `controlIdAccessProvider` por padrão) — o resto do domínio nunca
    depende do Control iD diretamente.
  - `device-sync-service.js` — `DeviceSyncService`, ver seção própria
    abaixo.
  - `motivos.js`/`mensagens.js` — motivos de negativa padronizados (ver
    seção 11 do briefing, mais `RATE_LIMITED`) e o texto curto mostrado na
    tela do aparelho.

  Exposto via Firebase Hosting em
  `/api/integrations/controlid/events/new-user-identified` (rewrite em
  `firebase.json`). Vários detalhes de baixo nível (nome exato da ação de
  abertura do relé, se o "Modo Pro/Online" do aparelho aceita header HTTP
  customizado) estão marcados **A CONFIRMAR NO EQUIPAMENTO** no código —
  a documentação oficial da Control iD (controlid.com.br) não pôde ser
  acessada da máquina onde isso foi implementado (bloqueio de rede do
  ambiente), então esses pontos não foram assumidos: ficam pra Fase de
  validação física, com o aparelho em mãos.

### `DeviceSyncService` — o que já é real e o que ainda não é

`lib/access/device-sync-service.js` tem dois tipos de método, de propósito:

- **Reais e testados hoje** (só mexem no nosso Firestore, nunca falam com
  o aparelho): `cadastrarDispositivo` (gera o token, grava só o hash),
  `desativarDispositivo`, `vincularCredencial`/`desvincularCredencial`
  (mapeamento `user_id` do aparelho ↔ `alunoUid`).
- **Não implementados de propósito** (`sincronizarUsuarioNoDispositivo`,
  `removerUsuarioDoDispositivo`): dependem de criar usuário/cadastrar
  rosto na própria Access API do iDFace, algo que não foi possível
  confirmar sem o equipamento físico nem acesso à documentação primária.
  Chamar qualquer um dos dois hoje sempre lança um erro explícito — nunca
  fingem funcionar.

Até esses dois últimos serem implementados, vincular um aluno a um
dispositivo é manual: gere o token com `cadastrarDispositivo`, configure-o
no aparelho, cadastre o usuário/rosto pela interface do próprio iDFace, e
chame `vincularCredencial` com o `user_id` que ele recebeu lá.
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

Mesmo padrão dos dois de cima, em `test/access/`:

```
npm run test:emulator:access   # fluxo completo: aluno em dia, atrasado,
                                # nunca sincronizado, unidade errada,
                                # dispositivo não autorizado, evento duplicado
                                # + DeviceSyncService (cadastro/vínculo real)
npm run test:rules:access      # regras das coleções dispositivosAcesso,
                                # eventosAcesso e unidades
```

Os arquivos sem sufixo `.emulator.js` (`access-authorization-service.test.js`,
`control-id-adapter.test.js`, `control-id-adapter-acoes.test.js`,
`access-event-service.test.js`, `device-auth.test.js`, `rate-limit.test.js`,
`access-request-handler.test.js`, `device-sync-service.test.js`) são
unitários puros e já rodam no `npm test` normal — cobrem os testes 1 a 8
do roteiro de integração (item por item, com comentário `// Teste N` no
código), mais payload malformado, injeção do `AccessControlProvider` e
validação de parâmetros do `DeviceSyncService`.

### Simulando o iDFace Pro sem o equipamento físico

```
npm run mock:idface
```

Sobe o Firestore Emulator, semeia um dispositivo e quatro alunos
(em dia, atrasado, bloqueado, de outra unidade) e dispara
`processarEventoIdentificacao` pra cada cenário — incluindo `user_id`
nunca sincronizado, token de dispositivo errado e payload malformado —
imprimindo a resposta completa (`event`, `message`, `actions`) que o
dispositivo receberia. Não abre nenhuma conexão de rede real; serve pra
ver o fluxo inteiro funcionando antes do equipamento chegar.

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
   depender disso: (a) cadastrar o dispositivo com
   `DeviceSyncService.cadastrarDispositivo` e configurar o token gerado no
   aparelho; (b) cadastrar cada usuário/rosto pela própria interface do
   iDFace e, com o `user_id` que ele atribuir, chamar
   `DeviceSyncService.vincularCredencial` (sincronização automática —
   `sincronizarUsuarioNoDispositivo` — ainda não implementada, ver seção
   acima); (c) fazer a Fase de validação física (próxima seção) antes de
   confiar na integração com alunos de verdade.

## Fase de validação física (com o iDFace Pro em mãos)

Nada disto dá pra confirmar sem o equipamento — é o próximo passo depois
do deploy, antes de ligar a solenoide de verdade:

- [ ] IP do aparelho na rede da academia, alcançável a partir de onde as
      Cloud Functions rodam (ou algum túnel/VPN, se a rede for fechada).
- [ ] Login (`login.fcgi`) e sessão — confirmar o fluxo real da Access API
      (seção 15 do briefing; ainda não implementado neste projeto, pois é
      só necessário pro sentido Gym Xtreme → iDFace).
- [ ] Configurar o "Modo Pro/Online" pra apontar pro endpoint
      `/api/integrations/controlid/events/new-user-identified` e confirmar
      se dá pra anexar o `X-Device-Token` como header HTTP customizado ou
      se precisa ir como `?token=` na própria URL (o endpoint aceita os
      dois — ver `device-auth.js`).
- [ ] Payload real de um evento de identificação — comparar com o que
      `control-id-adapter.js` espera (`device_id`, `user_id`, `uuid`
      etc.) e ajustar se algum nome de campo vier diferente do
      documentado.
- [ ] Resposta: confirmar que o aparelho aceita o formato
      `{result: {event, user_id, user_name, portal_id, actions, message}}`
      tal como está sendo enviado.
- [ ] Ação de abertura do relé: descobrir o `action`/`parameters` corretos
      (testar SEM a solenoide conectada primeiro) e configurar em
      `CONTROLID_ACAO_ABERTURA_JSON`.
- [ ] Tempo de acionamento do relé e comunicação com o módulo externo
      (MAE), se for o caso.
- [ ] Só depois de tudo acima validado: ligação da solenoide 12 V.

## Implantar

```
npm install
firebase deploy --only functions
```

Requer `firebase login` com uma conta que tenha acesso ao projeto.
