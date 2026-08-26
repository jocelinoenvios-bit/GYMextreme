# Serviço local da catraca — GYM XTREME

Roda no computador da academia. É o **único** componente do sistema que fala
com o hardware da catraca — o app Flutter e a Cloud Function de autorização
nunca acionam o solenoide diretamente.

Escuta `academias/{academiaId}/autorizacoesAcesso` em tempo real (autenticado
como uma conta de staff dedicada, sujeita às mesmas regras de segurança do
resto do app — não usa credencial de administrador). Quando chega uma
autorização nova: valida que não expirou, aciona (ou não) o pulso, e marca
como consumida.

## Antes de usar

1. **Escolher o hardware** — rele USB, Arduino/ESP32 por serial, GPIO de um
   Raspberry Pi etc. `acionarSolenoide()` em `index.js` está com um `TODO`
   explícito nesse ponto — é a única função que precisa mudar.
2. **Criar a conta de staff dedicada** — pela tela "Gerenciar funcionários"
   do app, um cargo sem nenhuma permissão de tela (só precisa ser
   reconhecida como staff). Nunca reaproveitar a conta de um funcionário de
   verdade.
3. Copiar `.env.example` para `.env` e preencher.

## Rodar

```
npm install
npm start
```

## Segurança

- Autorizações têm validade curta (10s) — uma tentativa de reaproveitar uma
  autorização antiga (replay) é ignorada.
- Este serviço só pode marcar uma autorização como `consumida` — nunca cria
  uma autorização nem decide se ela é aprovada (isso é sempre a Cloud
  Function `solicitarAutorizacaoAcesso`, ver `firestore.rules`).
- Recomendado: além do temporizador por software (~1s) já aplicado aqui,
  usar também um corte por hardware (relé/timer monostável) — assim, mesmo
  que este processo trave ou caia no meio do pulso, o solenoide nunca fica
  energizado além da conta.
