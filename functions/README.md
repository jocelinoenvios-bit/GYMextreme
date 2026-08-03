# Cloud Functions — GYM XTREME

Duas funções, implementando a arquitetura de controle de acesso já definida:

- **`solicitarAutorizacaoAcesso`** — recebida do módulo de identificação (facial,
  biometria, QR, NFC...), decide se o aluno pode entrar e grava o resultado em
  `academias/{academiaId}/autorizacoesAcesso`, onde o serviço local escuta.
- **`enviarNotificacoesMensalidade`** — roda todo dia às 8h (horário de
  Brasília) e manda a notificação certa pra cada aluno, conforme o fluxo
  combinado (7/3/0 dias antes do vencimento, avisos de tolerância, bloqueio).

A lógica de datas (`lib/status-acesso.js`) é a mesma de
`lib/utils/status_acesso.dart` no app Flutter — os dois têm que ficar
idênticos. Testada isoladamente, sem precisar de credencial nenhuma:

```
npm test
```

## Antes de implantar (ainda não implantado)

1. **Plano Blaze do Firebase** — `enviarNotificacoesMensalidade` é uma função
   agendada, o que exige o plano pago (cobra só pelo uso). Confirme isso no
   Firebase Console antes de implantar.
2. **`usuarios/{uid}.fcmTokens`** ainda não é preenchido pelo app — falta
   adicionar `firebase_messaging` no Flutter e testar em um dispositivo real
   antes das notificações realmente chegarem no celular do aluno.
3. **Coleção `credenciais`** precisa ser populada conforme o método de
   identificação escolhido (QR Code, biometria, facial, NFC).

## Implantar

```
npm install
firebase deploy --only functions
```

Requer `firebase login` com uma conta que tenha acesso ao projeto.
